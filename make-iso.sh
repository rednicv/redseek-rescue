#!/usr/bin/env bash
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

rm -rf /tmp/iso-staging
mkdir -p /tmp/iso-staging

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
cp -a "$SRC/." /tmp/iso-staging/

# Rename kernel/initrd to generic names if versioned
for f in /tmp/iso-staging/casper/vmlinuz-*; do
  [ -f "$f" ] && mv "$f" /tmp/iso-staging/casper/vmlinuz && break
done 2>/dev/null || true

for f in /tmp/iso-staging/casper/initrd*; do
  [ -f "$f" ] && mv "$f" /tmp/iso-staging/casper/initrd.img && break
done 2>/dev/null || true

# Also check root level (some live-build versions put them there)
for f in /tmp/iso-staging/vmlinuz-*; do
  [ -f "$f" ] && mkdir -p /tmp/iso-staging/casper && mv "$f" /tmp/iso-staging/casper/vmlinuz && break
done 2>/dev/null || true

for f in /tmp/iso-staging/initrd*; do
  [ -f "$f" ] && mkdir -p /tmp/iso-staging/casper && mv "$f" /tmp/iso-staging/casper/initrd.img && break
done 2>/dev/null || true

# Verify kernel exists
if [ ! -f /tmp/iso-staging/casper/vmlinuz ]; then
  echo "❌ vmlinuz not found in casper/"
  find /tmp/iso-staging -name "vmlinuz*" -o -name "initrd*" 2>/dev/null
  exit 1
fi

# Create GRUB config
mkdir -p /tmp/iso-staging/boot/grub
cat > /tmp/iso-staging/boot/grub/grub.cfg << 'GRUBEOF'
set timeout=10
set default=0

menuentry "RedSeek Rescue (Live)" {
  linux /casper/vmlinuz boot=live live-media-path=/casper quiet splash ---
  initrd /casper/initrd.img
}

menuentry "RedSeek Rescue (Safe Graphics)" {
  linux /casper/vmlinuz boot=live live-media-path=/casper nomodeset quiet splash ---
  initrd /casper/initrd.img
}
GRUBEOF

# Build GRUB EFI
echo "[*] Building GRUB EFI..."
mkdir -p /tmp/iso-staging/EFI/BOOT
grub-mkstandalone -O x86_64-efi -o /tmp/iso-staging/EFI/BOOT/BOOTx64.EFI "boot/grub/grub.cfg=/tmp/iso-staging/boot/grub/grub.cfg"

# Build GRUB BIOS core.img with all needed modules
echo "[*] Building GRUB BIOS..."
grub-mkimage -O i386-pc -o /tmp/core.img -p "(cd)/boot/grub" \
  biosdisk iso9660 ext2 fat ntfs part_msdos part_gpt normal linux configfile search ls

cp /tmp/core.img /tmp/iso-staging/boot/grub/core.img

# Build hybrid ISO — NO isohybrid-gpt-basdat (causes LBA64 errors on some BIOS)
echo "[*] Building ISO with xorriso..."
xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -volid "REDSEEK_RESCUE" \
  -eltorito-boot boot/grub/core.img \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e EFI/BOOT/BOOTx64.EFI \
  -no-emul-boot \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -o "$ISO_OUT" /tmp/iso-staging

echo ""
echo "=== ✅ ISO created ==="
ls -lh "$ISO_OUT"
file "$ISO_OUT"
echo ""
echo "=== El Torito ==="
xorriso -indev "$ISO_OUT" -report_el_torito plain 2>&1 | grep -E "Boot record|El Torito|boot img|img path"
