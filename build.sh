#!/usr/bin/env bash
# RedSeek Rescue by rednic — Build script
# ⚠️ NO API key embedded in ISO — user provides at first boot
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${ROOT_DIR}/output"
ISO_OVERLAY="${ROOT_DIR}/iso-overlay"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
CONFIG_DIR="${ROOT_DIR}/config"
CHROOT_CUSTOM="${ROOT_DIR}/chroot-custom"
BUILD_DIR="${ROOT_DIR}/build"
ISO_NAME="redseek-rescue-v1.4.2"

echo "=== RedSeek Rescue by rednic ==="
echo ""

# Validate project structure
if [ ! -d "${SCRIPTS_DIR}" ]; then
  echo "[!] scripts/ directory not found. Run from repo root."
  exit 1
fi

# Copy config example if missing — NO API key injection
# Key is user-provided at first boot via rescue-prompt.txt (safe Python, not sed)
if [ ! -f "${CONFIG_DIR}/hermes-config.yaml" ]; then
  echo "[*] Creating config/hermes-config.yaml from example..."
  cp "${CONFIG_DIR}/hermes-config.yaml.example" "${CONFIG_DIR}/hermes-config.yaml"
  echo "[!] Edit config/hermes-config.yaml and add your DeepSeek API key before boot."
fi
echo ""

# Check+install build host dependencies
echo "[*] Checking build host dependencies..."
MISSING=""
for pkg in mtools xorriso isolinux syslinux-utils; do
  dpkg -s "$pkg" &>/dev/null || MISSING="$MISSING $pkg"
done
if [ -n "$MISSING" ]; then
  echo "[*] Installing missing packages:$MISSING"
  sudo apt-get install -y $MISSING || echo "[!] Some packages failed. Build may continue."
fi
echo ""

# Clean previous build
rm -rf "${BUILD_DIR}" "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

# Init live-build config
cd "${BUILD_DIR}"

lb config \
  --distribution noble \
  --architectures amd64 \
  --archive-areas "main universe multiverse restricted" \
  --binary-images iso-hybrid \
  --bootloader grub-pc,grub-efi \
  --bootappend-live "boot=live components locales=ro_RO.UTF-8 keyboard-layouts=ro username=rescue user-fullname=Rescue" \
  --debian-installer false \
  --memtest none \
  --firmware-binary false \
  --win32-loader false

echo ""
echo "=== Config created ==="
echo ""

# Create our package list
cat > config/package-lists/deepseekrescue.list.chroot << 'PKGLIST'
# Core
openssh-server
curl
wget
git

# WiFi firmware (Broadcom, Atheros, Intel)
linux-firmware
firmware-b43-installer

# Filesystem tools (Windows NTFS)
ntfs-3g
exfatprogs
fuse3

# Disk diagnostics
smartmontools
hdparm
gddrescue
testdisk
parted
gdisk
dosfstools
e2fsprogs
mtools
xorriso

# BitLocker decryption
dislocker

# Volume Shadow Copy (Windows restore points)
libvshadow-utils

# Hardware diagnostics
memtester
stress-ng
lm-sensors

# File signature verification
osslsigncode

# Cloud backup
rclone

# Antivirus & security (Linux-native scan of Windows partitions)
clamav
clamav-daemon
chkrootkit
rkhunter

# System tools
psmisc
lsof
strace
htop
iotop
pv
dialog
unzip
zip
p7zip-full
bzip2
xz-utils
rfkill
wireless-tools
wpasupplicant
network-manager

# Boot repair
grub-pc-bin
grub-efi-amd64-bin
efibootmgr

# Python / Hermes
python3
python3-pip
python3-venv
python3-hivex
python3-evtx
chntpw
pipx
wine64

# Misc
nano
vim
tree
jq
screen
PKGLIST

# Include our custom overlay (scripts, configs)
mkdir -p "${BUILD_DIR}/config/includes.chroot/opt/rescue"
cp -r "${SCRIPTS_DIR}" "${BUILD_DIR}/config/includes.chroot/opt/rescue/scripts"
cp -r "${CONFIG_DIR}" "${BUILD_DIR}/config/includes.chroot/opt/rescue/config"
mkdir -p "${BUILD_DIR}/config/includes.chroot/home/rescue"
cp -r "${ISO_OVERLAY}/"* "${BUILD_DIR}/config/includes.chroot/" 2>/dev/null || true

# Create Hermes install script that runs on first boot
cat > "${BUILD_DIR}/config/includes.chroot/opt/rescue/install-hermes.sh" << 'HERMES'
#!/usr/bin/env bash
# Installs Hermes Agent on first boot — NO API key embedded
set -euo pipefail

RESCUE_DIR="/opt/rescue"
CONFIG_FILE="${RESCUE_DIR}/config/hermes-config.yaml"

pipx install hermes-agent
pip install python-evtx 2>/dev/null || true

mkdir -p /home/rescue/.hermes
cp "${CONFIG_FILE}" /home/rescue/.hermes/config.yaml
echo ""
echo "⚠️  IMPORTANT: Edit /home/rescue/.hermes/config.yaml"
echo "   and add your DeepSeek API key before using Hermes."
echo "   Get one at: https://platform.deepseek.com/api_keys"
echo ""

mkdir -p /home/rescue/.hermes/skills
if [ -d "${RESCUE_DIR}/config/skills" ]; then
  cp -r "${RESCUE_DIR}/config/skills/"* /home/rescue/.hermes/skills/
fi
chown -R rescue:rescue /home/rescue/.hermes
HERMES

chmod +x "${BUILD_DIR}/config/includes.chroot/opt/rescue/install-hermes.sh"
mkdir -p "${BUILD_DIR}/config/hooks/chroot"
mv "${BUILD_DIR}/config/includes.chroot/opt/rescue/install-hermes.sh" \
   "${BUILD_DIR}/config/hooks/chroot/01-install-hermes.chroot"
chmod +x "${BUILD_DIR}/config/hooks/chroot/01-install-hermes.chroot"

# Auto-start Hermes on login via .profile
cat > "${BUILD_DIR}/config/includes.chroot/home/rescue/.profile" << 'PROFILE'
#!/bin/bash
while true; do
    clear
    echo "╔═══════════════════════════════════════════╗"
    echo "║      RedSeek Rescue by rednic            ║"
    echo "║      AI-powered system rescue tool       ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""
    echo "Starting AI rescue agent..."
    echo ""
    hermes run /opt/rescue/config/rescue-prompt.txt
    clear
    echo ""; echo "╔═══════════════════════════════════════════╗"
    echo "║  Hermes has stopped.                     ║"
    echo "╚═══════════════════════════════════════════╝"
    echo "  Type 'hermes'   → restart AI assistant"
    echo "  Type 'manual'   → drop to shell"
    read -p "hermes/manual> " choice
    case "$choice" in
        manual) exec bash --login ;;
        *) echo "Restarting..." ;;
    esac
done
PROFILE

# Boot splash
mkdir -p "${BUILD_DIR}/config/includes.chroot/etc/update-motd.d"
cat > "${BUILD_DIR}/config/includes.chroot/etc/update-motd.d/99-redseek-rescue" << 'MOTD'
#!/bin/sh
echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║      RedSeek Rescue by rednic            ║"
echo "╚═══════════════════════════════════════════╝"
echo "  Hermes AI rescue agent starts automatically."
echo "  If you need the terminal, press Ctrl+C."
echo ""
MOTD
chmod +x "${BUILD_DIR}/config/includes.chroot/etc/update-motd.d/99-redseek-rescue"

# Build the ISO
echo ""
echo "=== Building ISO (this takes a while) ==="
echo ""

cd "${BUILD_DIR}"
lb build 2>&1 | tee "${ROOT_DIR}/build.log"
BUILD_EXIT=$?

if [ "${BUILD_EXIT}" -ne 0 ]; then
  echo "[!] lb build failed. Retrying with sudo..."
  sudo lb build 2>&1 | tee "${ROOT_DIR}/build.log"
  BUILD_EXIT=$?
  sudo chown -R "$(whoami):$(whoami)" "${BUILD_DIR}/config" 2>/dev/null || true
fi

if [ "${BUILD_EXIT}" -ne 0 ]; then
  echo "=== ❌ Build failed. Check build.log ==="
  exit 1
fi

# Find the ISO
ISO_SOURCE=""
for candidate in \
  "${BUILD_DIR}/live-image-amd64.hybrid.iso" \
  "${BUILD_DIR}/binary.hybrid.iso" \
  "${BUILD_DIR}"/*.iso; do
  if [ -f "$candidate" ]; then
    ISO_SOURCE="$candidate"
    break
  fi
done

if [ -z "${ISO_SOURCE}" ]; then
  echo "=== ❌ Build failed — no ISO found. Check build.log ==="
  exit 1
fi

# Verify ISO is bootable
echo ""
echo "=== Verifying ISO bootability ==="
if xorriso -indev "${ISO_SOURCE}" -report_el_torito plain 2>&1 | grep -q "El Torito"; then
  echo "[✅] ISO is bootable (El Torito found)"
else
  echo "[!] ISO missing El Torito boot record. Applying isohybrid..."
  sudo isohybrid "${ISO_SOURCE}" 2>/dev/null && echo "[✅] isohybrid applied" || echo "[!] isohybrid failed — UEFI-only ISO"
fi

# Copy result
mkdir -p "${OUTPUT_DIR}"
cp "${ISO_SOURCE}" "${OUTPUT_DIR}/${ISO_NAME}.iso"
echo ""
echo "=== ✅ ISO ready: ${OUTPUT_DIR}/${ISO_NAME}.iso ==="
ls -lh "${OUTPUT_DIR}/${ISO_NAME}.iso"