#!/bin/bash
# RedSeek Rescue — Build ISO hibrid (BIOS + UEFI) cu xorriso
# Rulează DUPĂ live-build (care produce binary staging)
set -euo pipefail

BUILD="${1:-build/chroot}"
ISO_OUT="${2:-redseek-rescue.iso}"
ISO_DIR="/tmp/iso-staging"

rm -rf "$ISO_DIR"
mkdir -p "$ISO_DIR/boot/grub"
mkdir -p "$ISO_DIR/EFI/BOOT"

echo "📦 Copying live files from $BUILD/binary/..."
cp -a "$BUILD/binary/." "$ISO_DIR/"

echo "📝 Creating GRUB config..."
cat > "$ISO_DIR/boot/grub/grub.cfg" << 'GRUBEOF'
set timeout=10
set default=0
menuentry "RedSeek Rescue (Live)" {
    linux /casper/vmlinuz boot=casper live-media-path=/casper quiet splash ---
    initrd /casper/initrd.img
}
menuentry "RedSeek Rescue (Safe Graphics)" {
    linux /casper/vmlinuz boot=casper live-media-path=/casper nomodeset quiet splash ---
    initrd /casper/initrd.img
}
GRUBEOF

echo "🔨 Building GRUB EFI image..."
grub-mkstandalone -O x86_64-efi -o "$ISO_DIR/EFI/BOOT/BOOTx64.EFI" \
    "boot/grub/grub.cfg=$ISO_DIR/boot/grub/grub.cfg"

echo "🔨 Building GRUB BIOS image..."
grub-mkimage -O i386-pc -o /tmp/core.img -p "(cd)/boot/grub" \
    biosdisk iso9660 ext2 fat ntfs part_msdos part_gpt normal linux configfile search

cp /tmp/core.img "$ISO_DIR/boot/grub/core.img"

echo "💿 Building hybrid ISO with xorriso..."
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "REDSEEK_RESCUE" \
    -appid "RedSeek Rescue" \
    -publisher "rednic" \
    -eltorito-boot boot/grub/core.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e EFI/BOOT/BOOTx64.EFI \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "$ISO_OUT" \
    "$ISO_DIR"

echo ""
echo "✅ ISO created: $ISO_OUT"
ls -lh "$ISO_OUT"
file "$ISO_OUT"
echo ""
echo "📋 El Torito boot catalog:"
xorriso -indev "$ISO_OUT" -report_el_torito plain 2>&1 | grep -E "Boot record|El Torito|boot img"
