#!/usr/bin/env bash
# RedSeek Rescue by rednic — Build script v1.4.3
# ⚠️ NO API key embedded in ISO — user provides at first boot
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${ROOT_DIR}/output"
ISO_OVERLAY="${ROOT_DIR}/iso-overlay"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
CONFIG_DIR="${ROOT_DIR}/config"
CHROOT_CUSTOM="${ROOT_DIR}/chroot-custom"
BUILD_DIR="${ROOT_DIR}/build"

# Read version from VERSION file, fallback to hardcoded
if [ -f "${ROOT_DIR}/VERSION" ]; then
  ISO_VERSION=$(head -1 "${ROOT_DIR}/VERSION")
else
  ISO_VERSION="1.4.3"
fi
ISO_NAME="redseek-rescue-v${ISO_VERSION}"

echo "=== RedSeek Rescue by rednic ==="
echo ""

# Validate project structure
if [ ! -d "${SCRIPTS_DIR}" ]; then
  echo "[!] scripts/ directory not found. Run from repo root."
  exit 1
fi

# Copy config example if missing — NO API key injection
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
  --mode ubuntu \
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

# Create our package list (removed firmware-b43-installer — not in Ubuntu Noble)
cat > config/package-lists/deepseekrescue.list.chroot << 'PKGLIST'
# Core
openssh-server
curl
wget
git

# WiFi firmware (Intel, Atheros — Broadcom pulled automatically by linux-firmware)
linux-firmware

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

# Hermes install script (runs as chroot hook during build)
cat > "${BUILD_DIR}/config/hooks/chroot/01-install-hermes.chroot" << 'HERMES'
#!/usr/bin/env bash
# Installs Hermes Agent into the ISO — runs inside chroot during build
# Installs to /usr/local so rescue user can find it
set -euo pipefail

# Install hermes-agent system-wide (pinned version for reproducibility)
pip install --no-cache-dir hermes-agent==0.18.0

# Also install python-evtx in the same environment
pip install --no-cache-dir python-evtx 2>/dev/null || true

echo "[✓] Hermes Agent installed"
HERMES

chmod +x "${BUILD_DIR}/config/hooks/chroot/01-install-hermes.chroot"

# SSH hardening: disable password auth, only key-based (live ISO, no default password)
mkdir -p "${BUILD_DIR}/config/includes.chroot/etc/ssh"
cat > "${BUILD_DIR}/config/includes.chroot/etc/ssh/sshd_config.d/99-rescue.conf" << 'SSHCFG'
PasswordAuthentication no
PermitRootLogin no
SSHCFG

# Auto-start Hermes on login via .profile (with crash guard)
cat > "${BUILD_DIR}/config/includes.chroot/home/rescue/.profile" << 'PROFILE'
#!/bin/bash
CRASH_COUNT=0
MAX_CRASHES=3
CRASH_WINDOW=10  # seconds — if 3 crashes within this window, drop to shell

while true; do
    clear
    echo "╔═══════════════════════════════════════════╗"
    echo "║      RedSeek Rescue by rednic            ║"
    echo "║      AI-powered system rescue tool       ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""
    echo "Starting AI rescue agent..."
    echo ""

    START_TIME=$(date +%s)
    hermes run /opt/rescue/config/rescue-prompt.txt
    EXIT_CODE=$?

    NOW=$(date +%s)
    if [ $((NOW - START_TIME)) -lt "$CRASH_WINDOW" ] && [ "$EXIT_CODE" -ne 0 ]; then
        CRASH_COUNT=$((CRASH_COUNT + 1))
    else
        CRASH_COUNT=0
    fi

    if [ "$CRASH_COUNT" -ge "$MAX_CRASHES" ]; then
        clear
        echo "╔═══════════════════════════════════════════╗"
        echo "║  Hermes crashed $CRASH_COUNT times in a row.  ║"
        echo "║  Dropping to shell...                    ║"
        echo "╚═══════════════════════════════════════════╝"
        exec bash --login
    fi

    clear
    echo ""
    echo "╔═══════════════════════════════════════════╗"
    echo "║  Hermes has stopped.                     ║"
    echo "╚═══════════════════════════════════════════╝"
    echo "  Type 'hermes'   → restart AI assistant"
    echo "  Type 'manual'   → drop to shell"
    read -p "hermes/manual> " choice
    case "$choice" in
        manual) exec bash --login ;;
        *) echo "Restarting..." ; CRASH_COUNT=0 ;;
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

# ⚠️ Disable set -e temporarily so retry logic actually works
set +e
lb build 2>&1 | tee "${ROOT_DIR}/build.log"
BUILD_EXIT=${PIPESTATUS[0]}  # Get lb build's exit code, not tee's
set -e

if [ "${BUILD_EXIT}" -ne 0 ]; then
  echo "[!] lb build failed. Retrying with sudo..."
  set +e
  sudo lb build 2>&1 | tee -a "${ROOT_DIR}/build.log"
  BUILD_EXIT=${PIPESTATUS[0]}
  set -e
  sudo chown -R "$(whoami):$(whoami)" "${BUILD_DIR}" 2>/dev/null || true
fi

if [ "${BUILD_EXIT}" -ne 0 ]; then
  echo "=== ❌ Build failed. Check build.log ==="
  exit 1
fi

# Find the ISO (only match the hybrid one, not any leftovers)
ISO_SOURCE=""
for candidate in \
  "${BUILD_DIR}/live-image-amd64.hybrid.iso" \
  "${BUILD_DIR}/binary.hybrid.iso"; do
  if [ -f "$candidate" ]; then
    ISO_SOURCE="$candidate"
    break
  fi
done

# Fallback: first .iso file (less reliable, but backup)
if [ -z "${ISO_SOURCE}" ]; then
  ISO_SOURCE=$(ls -1 "${BUILD_DIR}"/*.iso 2>/dev/null | head -1)
fi

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

# Copy result + generate checksum
mkdir -p "${OUTPUT_DIR}"
cp "${ISO_SOURCE}" "${OUTPUT_DIR}/${ISO_NAME}.iso"
sha256sum "${OUTPUT_DIR}/${ISO_NAME}.iso" > "${OUTPUT_DIR}/${ISO_NAME}.iso.sha256"
echo ""
echo "=== ✅ ISO ready: ${OUTPUT_DIR}/${ISO_NAME}.iso ==="
echo "    SHA256: $(cat "${OUTPUT_DIR}/${ISO_NAME}.iso.sha256")"
ls -lh "${OUTPUT_DIR}/${ISO_NAME}.iso"
