#!/usr/bin/env bash
# RedSeek Rescue by rednic — Build script
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${ROOT_DIR}/output"
ISO_OVERLAY="${ROOT_DIR}/iso-overlay"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
CONFIG_DIR="${ROOT_DIR}/config"
CHROOT_CUSTOM="${ROOT_DIR}/chroot-custom"
BUILD_DIR="${ROOT_DIR}/build"
ISO_NAME="redseek-rescue-v1.0"

echo "=== RedSeek Rescue by rednic ==="
echo ""

# Auto-inject DeepSeek API key from current active config
echo "[*] Reading DeepSeek API key from active Hermes config..."

# If hermes-config.yaml doesn't exist (fresh clone), create from example
if [ ! -f "${CONFIG_DIR}/hermes-config.yaml" ]; then
  echo "[*] Creating config/hermes-config.yaml from example..."
  cp "${CONFIG_DIR}/hermes-config.yaml.example" "${CONFIG_DIR}/hermes-config.yaml"
fi
DEEPSEEK_KEY=$(python3 -c "
import yaml
with open('/home/ubuntu/.hermes/config.yaml') as f:
    c = yaml.safe_load(f)
print(c['providers']['deepseek']['api_key'])
" 2>/dev/null || echo "")

if [ -z "${DEEPSEEK_KEY}" ]; then
  echo "[!] Could not read key. Placeholder left."
  echo "    Edit config/hermes-config.yaml before build."
else
  sed -i "s|DEEPSEEK_API_KEY_HERE|${DEEPSEEK_KEY}|" "${CONFIG_DIR}/hermes-config.yaml"
  echo "[✅] Key auto-injected from current config."
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
  --archive-areas "main,universe,multiverse" \
  --bootappend-live "boot=live components locales=ro_RO.UTF-8 keyboard-layouts=ro username=rescue user-fullname=Rescue" \
  --debian-installer false \
  --memtest none \
  --firmware-binary false \
  --win32-loader false

echo ""
echo "=== Config created ==="
echo ""

# Now we customize the packages
echo "live-task-recommends" >> config/package-lists/desktop.list.chroot
echo "live-task-standard" >> config/package-lists/desktop.list.chroot

# Create our package list
cat > config/package-lists/deepseekrescue.list.chroot << 'PKGLIST'
# Core
openssh-server
curl
wget
git

# Filesystem tools (Windows NTFS)
ntfs-3g
ntfsprogs
exfatprogs
fuse3

# Disk diagnostics
smartmontools
hdparm
ddrescue
testdisk
parted
gdisk
dosfstools
e2fsprogs

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
wine
wine32

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
# Installs Hermes Agent on first boot
set -e

RESCUE_DIR="/opt/rescue"
CONFIG_FILE="${RESCUE_DIR}/config/hermes-config.yaml"

# Install Hermes
pipx install hermes-agent

# Install additional Python packages for rescue tools
pip install python-evtx 2>/dev/null || true

# Create .hermes config directory
mkdir -p /home/rescue/.hermes
cp "${CONFIG_FILE}" /home/rescue/.hermes/config.yaml

# Set up skills directory for rescue-specific skills
mkdir -p /home/rescue/.hermes/skills

# Fix permissions
chown -R rescue:rescue /home/rescue/.hermes
HERMES

chmod +x "${BUILD_DIR}/config/includes.chroot/opt/rescue/install-hermes.sh"

# Auto-start Hermes on login via .profile
cat > "${BUILD_DIR}/config/includes.chroot/home/rescue/.profile" << 'PROFILE'
#!/bin/bash
# RedSeek Rescue — auto-start Hermes with rescue prompt
clear
echo "╔═══════════════════════════════════════════╗"
echo "║      RedSeek Rescue by rednic            ║"
echo "║      AI-powered system rescue tool       ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "Starting AI rescue agent..."
echo ""
exec hermes run /opt/rescue/config/rescue-prompt.txt
PROFILE
chown rescue:rescue "${BUILD_DIR}/config/includes.chroot/home/rescue/.profile"

# Boot splash
mkdir -p "${BUILD_DIR}/config/includes.chroot/etc/update-motd.d"
cat > "${BUILD_DIR}/config/includes.chroot/etc/update-motd.d/99-redseek-rescue" << 'MOTD'
#!/bin/sh
echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║      RedSeek Rescue by rednic            ║"
echo "║      AI-powered system rescue tool       ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
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
sudo lb build 2>&1 | tee "${ROOT_DIR}/build.log"

# Copy result
if [ -f "${BUILD_DIR}/live-image-amd64.hybrid.iso" ]; then
  cp "${BUILD_DIR}/live-image-amd64.hybrid.iso" "${OUTPUT_DIR}/${ISO_NAME}.iso"
  echo ""
  echo "=== ✅ ISO ready: ${OUTPUT_DIR}/${ISO_NAME}.iso ==="
  ls -lh "${OUTPUT_DIR}/${ISO_NAME}.iso"
else
  echo "=== ❌ Build failed. Check build.log ==="
  exit 1
fi
