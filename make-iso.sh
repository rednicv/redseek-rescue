#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
OUTPUT_DIR="${ROOT_DIR}/output"
ISO_NAME="${1:-redseek-rescue-v1.0}"
ISO_OUT="${OUTPUT_DIR}/${ISO_NAME}.iso"

echo "=== Building bootable ISO (xorriso manual) ==="
echo ""

# Check dependencies
sudo apt-get install -y mtools xorriso isolinux syslinux-utils grub-pc-bin grub-efi-amd64-bin 2>/dev/null || true

STAGING_DIR=$(mktemp -d "${BUILD_DIR}/staging-XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT

# Find source files
SRC=""
for d in "${BUILD_DIR}/chroot/binary" "${BUILD_DIR}/binary" "${BUILD_DIR}/chroot"; do
  [ -d "$d" ] && SRC="$d" && break
done

if [ -z "$SRC" ]; then
  echo "❌ No build artifacts found in ${BUILD_DIR}"
  exit 1
fi

echo "[*] Source: $SRC"

# Copy all files to staging
cp -a "$SRC/." "$STAGING_DIR"/

# Rename kernel/initrd to generic names if versioned
for f in "$STAGING_DIR"/casper/vmlinuz-*; do
  [ -f "$f" ] && mv "$f" "$STAGING_DIR"/casper/vmlinuz && break
done 2>/dev/null || true

for f in "$STAGING_DIR"/casper/initrd*; do
  [ -f "$f" ] && mv "$f" "$STAGING_DIR"/casper/initrd.img && break
done 2>/dev/null || true

# Also check root level
for f in "$STAGING_DIR"/vmlinuz-*; do
  [ -f "$f" ] && mkdir -p "$STAGING_DIR"/casper && mv "$f" "$STAGING_DIR"/casper/vmlinuz && break
done 2>/dev/null || true

for f in "$STAGING_DIR"/initrd*; do
  [ -f "$f" ] && mkdir -p "$STAGING_DIR"/casper && mv "$f" "$STAGING_DIR"/casper/initrd.img && break
done 2>/dev/null || true

# Verify
if [ ! -f "$STAGING_DIR"/casper/vmlinuz ]; then
  echo "❌ vmlinuz not found"
  find "$STAGING_DIR" -name "vmlinuz*" -o -name "initrd*" 2>/dev/null
  exit 1
fi

if [ ! -f "$STAGING_DIR"/casper/filesystem.squashfs ]; then
  echo "❌ filesystem.squashfs not found"
  find "$STAGING_DIR" -name "*.squashfs" 2>/dev/null
  exit 1
fi

# Create GRUB config
mkdir -p "$STAGING_DIR"/boot/grub
cat > "$STAGING_DIR"/boot/grub/grub.cfg << 'GRUBEOF'
set timeout=10
set default=0

menuentry "RedSeek Rescue (Live)" {
  linux /casper/vmlinuz boot=casper live-media-path=/casper username=rescue user-fullname=Rescue locales=ro_RO.UTF-8 keyboard-layouts=ro quiet splash ---
  initrd /casper/initrd.img
}

menuentry "RedSeek Rescue (Debug)" {
  linux /casper/vmlinuz boot=casper live-media-path=/casper username=rescue user-fullname=Rescue locales=ro_RO.UTF-8 keyboard-layouts=ro ---
  initrd /casper/initrd.img
}

menuentry "RedSeek Rescue (Safe Graphics)" {
  linux /casper/vmlinuz boot=casper live-media-path=/casper username=rescue user-fullname=Rescue locales=ro_RO.UTF-8 keyboard-layouts=ro nomodeset quiet splash ---
  initrd /casper/initrd.img
}
GRUBEOF

# ─── Auto-login as rescue on TTY1 ───
mkdir -p "$STAGING_DIR"/etc/systemd/system/getty@tty1.service.d
cat > "$STAGING_DIR"/etc/systemd/system/getty@tty1.service.d/autologin.conf << 'GETTYEOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o "-p -f rescue" --noclear --autologin rescue --keep-baud tty1 115200,38400,9600 $TERM
GETTYEOF

# ─── Set password "rescue" for user rescue at boot ───
mkdir -p "$STAGING_DIR"/etc/systemd/system/sysinit.target.wants
cat > "$STAGING_DIR"/etc/systemd/system/set-rescue-password.service << 'SERVICEOF'
[Unit]
Description=Set rescue user password
Before=getty@tty1.service
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo "rescue:rescue" | chpasswd'
ExecStartPost=/bin/systemctl disable set-rescue-password.service
RemainAfterExit=no

[Install]
WantedBy=sysinit.target
SERVICEOF
ln -sf /etc/systemd/system/set-rescue-password.service "$STAGING_DIR"/etc/systemd/system/sysinit.target.wants/

# ==========================================
# 1. Build GRUB EFI & FAT Image for UEFI
# ==========================================
echo "[*] Building GRUB EFI..."
mkdir -p "$STAGING_DIR"/EFI/BOOT
GRUB_EFI="$STAGING_DIR/EFI/BOOT/grubx64.efi"
grub-mkstandalone -O x86_64-efi -o "$GRUB_EFI" \
  "boot/grub/grub.cfg=$STAGING_DIR/boot/grub/grub.cfg"

# Secure Boot support: sign GRUB with MOK, use shim as bootloade
SECURE_BOOT=false
if command -v sbsign &>/dev/null && [ -f /usr/lib/shim/shimx64.efi.signed ]; then
    echo "[*] Secure Boot detected — signing GRUB..."
    MOK_DIR="$STAGING_DIR/EFI/BOOT/mok"
    mkdir -p "$MOK_DIR"

    # Generate MOK key pair (one-time per build)
    openssl req -new -x509 -newkey rsa:2048 -keyout "$MOK_DIR/MOK.key" \
        -out "$MOK_DIR/MOK.crt" -days 3650 -nodes \
        -subj "/CN=RedSeek Rescue/" 2>/dev/null

    # Sign GRUB EFI with MOK
    sbsign --key "$MOK_DIR/MOK.key" --cert "$MOK_DIR/MOK.crt" \
        --output "$GRUB_EFI" "$GRUB_EFI" 2>/dev/null

    # Shim-signed (Microsoft-trusted) acts as BOOTx64.EFI
    cp /usr/lib/shim/shimx64.efi.signed "$STAGING_DIR"/EFI/BOOT/BOOTx64.EFI
    echo "[✓] Secure Boot enabled — shim + signed GRUB"
    SECURE_BOOT=true
else
    echo "[*] Secure Boot not available (install shim-signed + sbsigntool)"
    cp "$GRUB_EFI" "$STAGING_DIR"/EFI/BOOT/BOOTx64.EFI
fi

# UEFI firmware requires a FAT image via El Torito, not a raw .EFI
echo "[*] Creating UEFI FAT image (efiboot.img)..."
dd if=/dev/zero of="$STAGING_DIR"/boot/grub/efiboot.img bs=1M count=16 status=none
mformat -i "$STAGING_DIR"/boot/grub/efiboot.img -F ::
mmd -i "$STAGING_DIR"/boot/grub/efiboot.img ::/EFI
mmd -i "$STAGING_DIR"/boot/grub/efiboot.img ::/EFI/BOOT
mcopy -i "$STAGING_DIR"/boot/grub/efiboot.img "$STAGING_DIR"/EFI/BOOT/BOOTx64.EFI ::/EFI/BOOT/BOOTx64.EFI
mcopy -i "$STAGING_DIR"/boot/grub/efiboot.img "$STAGING_DIR"/EFI/BOOT/grubx64.efi ::/EFI/BOOT/grubx64.efi
if $SECURE_BOOT; then
    mmd -i "$STAGING_DIR"/boot/grub/efiboot.img ::/EFI/BOOT/mok
    mcopy -i "$STAGING_DIR"/boot/grub/efiboot.img "$MOK_DIR/MOK.crt" ::/EFI/BOOT/mok/MOK.crt
fi

# ==========================================
# 2. Build GRUB BIOS with El Torito boot secto
# ==========================================
echo "[*] Building GRUB BIOS..."
grub-mkimage -O i386-pc -o /tmp/core.img -p "(cd)/boot/grub" \
  biosdisk iso9660 ext2 fat ntfs part_msdos part_gpt normal linux configfile search ls test

# BIOS boot record requires cdboot.img prepended to core.img
cat /usr/lib/grub/i386-pc/cdboot.img /tmp/core.img > "$STAGING_DIR"/boot/grub/bios.img

# ==========================================
# 3. Build hybrid ISO (xorriso)
# ==========================================
echo "[*] Building ISO with xorriso..."
xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "REDSEEK_RESCUE" \
  -eltorito-boot boot/grub/bios.img \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efiboot.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -o "$ISO_OUT" "$STAGING_DIR"

echo ""
echo "=== ISO created ==="
ls -lh "$ISO_OUT"
file "$ISO_OUT"
echo ""
echo "=== El Torito ==="
xorriso -indev "$ISO_OUT" -report_el_torito plain 2>&1 | grep -E "Boot record|El Torito|boot img|img path"
