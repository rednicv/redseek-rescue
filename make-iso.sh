#!/bin/bash
# RedSeek Rescue — Build ISO hibrid (BIOS + UEFI) cu xorriso
set -euo pipefail

BUILD="${1:-build/chroot}"
ISO_OUT="${2:-redseek-rescue.iso}"
ISO_DIR="/tmp/iso-staging"

rm -rf "$ISO_DIR"
mkdir -p "$ISO_DIR/boot/grub"
mkdir -p "$ISO_DIR/EFI/BOOT"

echo "📦 Copying live files from $BUILD/binary/..."
cp -a "$BUILD/binary/." "$ISO_DIR/"

# Detectare cale kernel (live/ pentru Debian, casper/ pentru Ubuntu)
KERNEL_DIR="live"
if [ -d "$ISO_DIR/live" ] && ls "$ISO_DIR/live"/vmlinuz* &>/dev/null; then
    KERNEL_DIR="live"
elif [ -d "$ISO_DIR/casper" ] && ls "$ISO_DIR/casper"/vmlinuz* &>/dev/null; then
    KERNEL_DIR="casper"
elif ls "$ISO_DIR"/vmlinuz* &>/dev/null; then
    KERNEL_DIR="."
fi
echo "🔍 Kernel found in /$KERNEL_DIR/"

# Redenumire fișiere versiune
if ls "$ISO_DIR/$KERNEL_DIR"/vmlinuz-* &>/dev/null; then
    mv "$ISO_DIR/$KERNEL_DIR"/vmlinuz-* "$ISO_DIR/$KERNEL_DIR/vmlinuz"
fi
if ls "$ISO_DIR/$KERNEL_DIR"/initrd* &>/dev/null; then
    mv "$ISO_DIR/$KERNEL_DIR"/initrd* "$ISO_DIR/$KERNEL_DIR/initrd.img"
fi

echo "📝 Creating GRUB config (kernel: /$KERNEL_DIR/)..."
cat > "$ISO_DIR/boot/grub/grub.cfg" << GRUBEOF
set timeout=10
set default=0
menuentry "RedSeek Rescue (Live)" {
    linux /$KERNEL_DIR/vmlinuz boot=live live-media-path=/$KERNEL_DIR quiet splash ---
    initrd /$KERNEL_DIR/initrd.img
}
menuentry "RedSeek Rescue (Safe Graphics)" {
    linux /$KERNEL_DIR/vmlinuz boot=live live-media-path=/$KERNEL_DIR nomodeset quiet splash ---
    initrd /$KERNEL_DIR/initrd.img
}
GRUBEOF

echo "🔨 Building GRUB EFI image..."
grub-mkstandalone -O x86_64-efi -o "$ISO_DIR/EFI/BOOT/BOOTx64.EFI" \
    "boot/grub/grub.cfg=$ISO_DIR/boot/grub/grub.cfg"

echo "🔨 Building GRUB BIOS image..."
grub-mkimage -O i386-pc -o /tmp/core.img -p "(cd)/boot/grub" \
    biosdisk iso9660 ext2 fat ntfs part_msdos normal linux configfile search

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
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -partition_type 0x00 \
    -o "$ISO_OUT" \
    "$ISO_DIR"

echo ""
echo "✅ ISO created: $ISO_OUT"
ls -lh "$ISO_OUT"
file "$ISO_OUT"
echo ""
echo "📋 El Torito:"
xorriso -indev "$ISO_OUT" -report_el_torito plain 2>&1 | grep -E "Boot record|El Torito|boot img"
echo ""
echo "📋 Partition:"
xorriso -indev "$ISO_OUT" -toc 2>&1 | grep -i partition
