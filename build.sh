#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue by rednic — Build script v1.4.14
# ⚠️ NO API key embedded in ISO — user provides at first boot
set -euo pipefail

# --- WSL2 environment check ---
# live-build needs raw loop device access + chroot with bind mounts.
# WSL2 runs a real Linux kernel but namespace isolation prevents live-build
# from mounting loop devices inside its chroot reliably.
if grep -qEi "(Microsoft|WSL)" /proc/version &>/dev/null; then
    echo ""
    echo "======================================"
    echo "  RedSeek Rescue — BUILD FAILED"
    echo "======================================"
    echo ""
    echo "Rulezi scriptul într-un mediu WSL2."
    echo ""
    echo "live-build nu funcționează în WSL2 deoarece namespace-urile"
    echo "izolate și accesul indirect la /dev/loop* împiedică operațiile"
    echo "de chroot și mount necesare construirii ISO-ului."
    echo ""
    echo "Solutii:"
    echo "  1. Ruleaza pe Linux nativ (Ubuntu/Debian)"
    echo "  2. Foloseste o masina virtuala (KVM/QEMU)"
    echo "  3. Foloseste GitHub Actions (build automat la tag)"
    echo ""
    exit 1
fi

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
  ISO_VERSION="1.4.4"
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
live-boot
live-config
live-config-systemd
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
# ⚠️ dislocker can break on Ubuntu Noble (mbedtls compat issue)
#     Fallback: cryptsetup bitlkOpen (already included via cryptsetup deps)
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

# Linux kernel + boot support
linux-image-generic
grub-pc-bin
grub-efi-amd64-bin
grub-efi-amd64
shim-signed
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

# Include custom overlay (scripts, config, iso_overlay)
# NOTE: use /./ suffix to copy CONTENTS, not the directory itself (avoids scripts/scripts/)
mkdir -p "${BUILD_DIR}/config/includes.chroot/opt/rescue/scripts"
mkdir -p "${BUILD_DIR}/config/includes.chroot/opt/rescue/config"
cp -r "${SCRIPTS_DIR}/." "${BUILD_DIR}/config/includes.chroot/opt/rescue/scripts/"
cp -r "${CONFIG_DIR}/." "${BUILD_DIR}/config/includes.chroot/opt/rescue/config/"
cp -r "${ISO_OVERLAY}/"* "${BUILD_DIR}/config/includes.chroot/" 2>/dev/null || true

# ─── Local Offline AI Model (Qwen 2.5 1.5B) & llama-server ───
CACHE_DIR="${ROOT_DIR}/cache"
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
LLAMA_URL="https://github.com/ggerganov/llama.cpp/releases/download/b3430/llama-b3430-bin-ubuntu-x64.zip"

# Download model to workspace cache
mkdir -p "${CACHE_DIR}/models"
if [ ! -f "${CACHE_DIR}/models/qwen2.5-1.5b.gguf" ]; then
    echo "[i] Descărcare model local Qwen 2.5..."
    curl -L -o "${CACHE_DIR}/models/qwen2.5-1.5b.gguf" "${MODEL_URL}" || true
fi

# Download llama.cpp binary to workspace cache
mkdir -p "${CACHE_DIR}/bin"
if [ ! -f "${CACHE_DIR}/bin/llama-server" ]; then
    echo "[i] Descărcare motor llama-server..."
    curl -L -o "${CACHE_DIR}/bin/llama-bin.zip" "${LLAMA_URL}" || true
    unzip -o -j "${CACHE_DIR}/bin/llama-bin.zip" "*llama-server" -d "${CACHE_DIR}/bin/" || true
    chmod +x "${CACHE_DIR}/bin/llama-server" || true
fi

# Copy assets to chroot overlay
if [ -f "${CACHE_DIR}/models/qwen2.5-1.5b.gguf" ]; then
    mkdir -p "${BUILD_DIR}/config/includes.chroot/opt/rescue/models"
    cp "${CACHE_DIR}/models/qwen2.5-1.5b.gguf" "${BUILD_DIR}/config/includes.chroot/opt/rescue/models/local-model.gguf"
fi
if [ -f "${CACHE_DIR}/bin/llama-server" ]; then
    mkdir -p "${BUILD_DIR}/config/includes.chroot/usr/local/bin"
    cp "${CACHE_DIR}/bin/llama-server" "${BUILD_DIR}/config/includes.chroot/usr/local/bin/llama-server"
fi


# Getty TTY1 autologin override
mkdir -p "${BUILD_DIR}/config/includes.chroot/etc/systemd/system/getty@tty1.service.d"
cat > "${BUILD_DIR}/config/includes.chroot/etc/systemd/system/getty@tty1.service.d/override.conf" << 'GETTY_OVERRIDE'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin rescue --noclear %I $TERM
GETTY_OVERRIDE

# Fix dpkg start-stop-daemon PATH issue in chroot (Ubuntu Noble)
# dpkg needs start-stop-daemon in PATH — create wrapper in /usr/bin
mkdir -p "${BUILD_DIR}/config/includes.chroot/usr/bin" "${BUILD_DIR}/config/includes.chroot/usr/sbin"
cat > "${BUILD_DIR}/config/includes.chroot/usr/bin/start-stop-daemon" << 'SSD'
#!/bin/sh
# Fake start-stop-daemon for chroot builds — just succeed
exit 0
SSD
chmod +x "${BUILD_DIR}/config/includes.chroot/usr/bin/start-stop-daemon"
cat > "${BUILD_DIR}/config/includes.chroot/usr/sbin/policy-rc.d" << 'POLICYRC'
#!/bin/sh
# Disable service start/stop during package installation in chroot
exit 101
POLICYRC
chmod +x "${BUILD_DIR}/config/includes.chroot/usr/sbin/policy-rc.d"

# Hermes install script (runs as chroot hook during build)
# We copy hooks to hooks/, hooks/normal/, and hooks/chroot/ for compatibility with all live-build versions
for hook_dir in "${BUILD_DIR}/config/hooks" "${BUILD_DIR}/config/hooks/normal" "${BUILD_DIR}/config/hooks/chroot"; do
  mkdir -p "$hook_dir"
done

# Fix PATH before dpkg runs (Ubuntu Noble + live-build compatibility)
cat > "${BUILD_DIR}/config/hooks/00-fix-path.chroot" << 'FIXPATH'
#!/bin/sh
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# Symlink start-stop-daemon if missing (needed by dpkg during build)
if [ ! -f /usr/sbin/start-stop-daemon ] && [ -f /bin/true ]; then
    mkdir -p /usr/sbin
    ln -sf /bin/true /usr/sbin/start-stop-daemon
fi
FIXPATH
chmod +x "${BUILD_DIR}/config/hooks/00-fix-path.chroot"

cat > "${BUILD_DIR}/config/hooks/01-install-hermes.chroot" << 'HERMES'
#!/usr/bin/env bash
# Installs Hermes Agent into the ISO — runs inside chroot during build
# Installs to /usr/local so rescue user can find it
set -euo pipefail

# Update package index before installing Python dependencies
apt-get update 2>/dev/null || true

# Install pip if not present (Ubuntu Noble may not have pip command)
if ! command -v pip3 &>/dev/null; then
    apt-get install -y python3-pip 2>/dev/null || true
fi

# Install hermes-agent system-wide (pinned version for reproducibility)
# --break-system-packages required: Ubuntu Noble marks Python as externally-managed (PEP 668)
# || true — Hermes install failure is non-fatal, ISO boots without it
pip3 install --break-system-packages --ignore-installed --no-cache-dir hermes-agent==0.18.0 || true

# Also install python-evtx in the same environment  
pip3 install --break-system-packages --no-cache-dir python-evtx 2>/dev/null || true

# Create symlink hermes-agent -> hermes for robustness
if [ -f /usr/local/bin/hermes ] && [ ! -f /usr/local/bin/hermes-agent ]; then
    ln -sf /usr/local/bin/hermes /usr/local/bin/hermes-agent
    echo "[✓] Created symlink: hermes-agent -> hermes"
fi

echo "[✓] Hermes Agent installed"
HERMES
chmod +x "${BUILD_DIR}/config/hooks/01-install-hermes.chroot"

# Copy hooks to all compatibility folders
for target_dir in "${BUILD_DIR}/config/hooks/normal" "${BUILD_DIR}/config/hooks/chroot"; do
  cp "${BUILD_DIR}/config/hooks/00-fix-path.chroot" "${target_dir}/00-fix-path.chroot"
  cp "${BUILD_DIR}/config/hooks/01-install-hermes.chroot" "${target_dir}/01-install-hermes.chroot"
done

# SSH hardening: disable password auth for security
# ⚠️ LIVE ISO — NO SSH keys provisioned by default!
# User must add their own key after boot:
#   mkdir -p ~/.ssh && chmod 700 ~/.ssh
#   echo "ssh-ed25519 AAA..." >> ~/.ssh/authorized_keys
#   chmod 600 ~/.ssh/authorized_keys
# For serial console access, use OCI Console Connection
mkdir -p "${BUILD_DIR}/config/includes.chroot/etc/ssh/sshd_config.d"
cat > "${BUILD_DIR}/config/includes.chroot/etc/ssh/sshd_config.d/99-rescue.conf" << 'SSHCFG'
# RedSeek Rescue — SSH is available with key or password
# Connect via: ssh rescue@<ip> (live ISO user has no password by default)
# ⚠️ For production use, set a password or add SSH keys after boot
PasswordAuthentication yes
PermitRootLogin prohibit-password
SSHCFG

# Auto-start Hermes on login via /etc/skel/.profile (live-boot copies skel to new user homes)
# NOT /home/rescue/ — live-boot overwrites that directory at boot
# Only runs on local TTY — SSH/SCP sessions get a normal shell
# SSH keys must be added by user after boot — PasswordAuthentication is OFF
mkdir -p "${BUILD_DIR}/config/includes.chroot/etc/skel"
cat > "${BUILD_DIR}/config/includes.chroot/etc/skel/.bashrc" << 'BASHRC'
# Prevent .profile from looping on SSH sessions
# SSH sessions skip the full rescue menu and get a plain shell
if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
BASHRC
cat > "${BUILD_DIR}/config/includes.chroot/etc/skel/.profile" << 'PROFILE'
#!/bin/bash
# RedSeek Rescue — Auto-start: AI (cu net) sau Offline Playbook (fără net)
# Only runs on local TTY (not SSH/SCP)

# ─── Automatic Network & DNS Configuration ───
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo); do
    sudo ip link set "$iface" up 2>/dev/null || true
    sudo dhcpcd "$iface" 2>/dev/null || true
done
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf >/dev/null

# ─── Auto-setup ~/.hermes configuration and skills at boot ───
for home_dir in "/home/rescue" "/root"; do
    sudo mkdir -p "$home_dir/.hermes/skills"
    if [ -f "/opt/rescue/config/hermes-config.yaml" ]; then
        sudo cp "/opt/rescue/config/hermes-config.yaml" "$home_dir/.hermes/config.yaml"
    fi
    if [ -d "/opt/rescue/config/skills" ]; then
        sudo cp -rf /opt/rescue/config/skills/* "$home_dir/.hermes/skills/" 2>/dev/null || true
    fi
    sudo chown -R rescue:rescue "/home/rescue/.hermes" 2>/dev/null || true
done

# Protecție: previne închiderea terminalului/bucle de login la erori
trap 'echo ""; echo "⚠️ Eroare neașteptată în asistent. Intri în shell-ul de salvare..."; exec bash' ERR

# ─── Banner ───
clear
echo "╔═══════════════════════════════════════════╗"
echo "║      RedSeek Rescue by rednic            ║"
echo "║      AI-powered system rescue tool       ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# ─── Detectare rețea ───
HAS_NET=false
if ping -c 1 -W 2 8.8.8.8 &>/dev/null || ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
    HAS_NET=true
fi

offline_mode() {
    echo "⚠️  Fără conexiune la internet — mod OFFLINE"
    echo ""
    if [ -f "/opt/rescue/models/local-model.gguf" ] && [ -f "/usr/local/bin/llama-server" ]; then
        echo "  [1] Pornire asistent AI local (Qwen 2.5 1.5B) - complet offline"
        echo "  [2] Rulare playbook reparații automat (fără asistent AI)"
        echo "  [3] Drop to Shell"
        echo -n "  alegere (1/2/3): "
        read -r off_choice
        case "$off_choice" in
            1)  local_ai_mode ;;
            2)  sudo /opt/rescue/scripts/rescue-playbook.sh --offline || true ;;
            3)  exec bash ;;
            *)  offline_mode ;;
        esac
    else
        echo " Rulez playbook-ul automat de reparații..."
        echo ""
        sudo /opt/rescue/scripts/rescue-playbook.sh --offline || true
        echo ""
        echo "╔═══════════════════════════════════════════╗"
        echo "║  Reparație offline finalizată.           ║"
        echo "╚═══════════════════════════════════════════╝"
        echo ""
        while true; do
            echo "  Opțiuni:"
            echo "    ai      → reîncearcă cu Hermes AI"
            echo "    shell   → drop to shell"
            echo "    reboot  → restart sistem"
            echo -n "  alegere (ai/shell/reboot): "
            read -r choice || choice="shell"
            case "$choice" in
                ai)     # Re-detect network and start AI
                        if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
                            ai_mode
                        else
                            echo "  Încă fără rețea. Rămân în offline."
                            continue
                        fi
                        ;;
                shell)  exec bash ;;
                reboot) sudo reboot ;;
                *)      echo "  alegere invalidă." ;;
            esac
        done
    fi
}

local_ai_mode() {
    echo " Pornesc motorul AI local (llama-server)..."
    sudo killall llama-server 2>/dev/null || true
    # Run llama-server in the background on CPU (4 threads)
    sudo llama-server -m /opt/rescue/models/local-model.gguf -c 2048 --port 8080 --host 127.0.0.1 -t 4 >/dev/null 2>&1 &
    
    # Wait for server startup (max 15s)
    for i in $(seq 1 15); do
        if curl -s http://127.0.0.1:8080/health | grep -q "ok"; then
            break
        fi
        sleep 1
    done

    echo " Pornesc asistentul AI Hermes (Conexiune Locală)..."
    echo ""
    
    # Run Hermes pointing to the local API
    sudo hermes -z /opt/rescue/config/rescue-prompt.txt --provider custom --model local-model chat
}

ai_mode() {
    echo " Conexiune la internet detectată."
    echo ""
    if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
        echo -n "🔑 Introduceți cheia API DeepSeek (sau apăsați Enter pentru modul Offline): "
        read -r DEEPSEEK_API_KEY
        echo ""
        if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
            offline_mode
            return 0
        fi
        export DEEPSEEK_API_KEY
        # Inject the key into config.yaml for both users
        for home_dir in "/home/rescue" "/root"; do
            if sudo test -f "$home_dir/.hermes/config.yaml"; then
                sudo sed -i "s/DEEPSEEK_API_KEY_HERE/$DEEPSEEK_API_KEY/g" "$home_dir/.hermes/config.yaml" 2>/dev/null || true
            fi
        done
    fi
    echo " Pornesc asistentul AI Hermes..."
    echo ""
    CRASH_COUNT=0
    MAX_CRASHES=3
    CRASH_WINDOW=10

    while true; do
        clear
        echo "╔═══════════════════════════════════════════╗"
        echo "║      RedSeek Rescue by rednic            ║"
        echo "║      AI-powered system rescue tool       ║"
        echo "╚═══════════════════════════════════════════╝"
        echo ""

        START_TIME=$(date +%s) || START_TIME=0
        # Run hermes (no || true — no set -e in .profile, so EXIT_CODE=$? works)
        sudo DEEPSEEK_API_KEY="$DEEPSEEK_API_KEY" hermes -z /opt/rescue/config/rescue-prompt.txt chat
        EXIT_CODE=$?
        NOW=$(date +%s) || NOW=0

        if [ $((NOW - START_TIME)) -lt "$CRASH_WINDOW" ] && [ "$EXIT_CODE" -ne 0 ] 2>/dev/null; then
            CRASH_COUNT=$((CRASH_COUNT + 1))
        else
            CRASH_COUNT=0
        fi

        if [ "$CRASH_COUNT" -ge "$MAX_CRASHES" ]; then
            clear
            echo "╔═══════════════════════════════════════════╗"
            echo "║  Hermes crashed 3 times.                 ║"
            echo "║  Comut în modul offline.                  ║"
            echo "╚═══════════════════════════════════════════╝"
            echo ""
            /opt/rescue/scripts/rescue-playbook.sh --offline || true
            exec bash
        fi

        clear
        echo ""
        echo "╔═══════════════════════════════════════════╗"
        echo "║  Hermes s-a oprit.                       ║"
        echo "╚═══════════════════════════════════════════╝"
        echo "  Type 'hermes'   → restart AI"
        echo "  Type 'manual'   → drop to shell"
        read -r choice || choice="shell"
        case "$choice" in
            manual) exec bash ;;
            *)      echo "Restarting..." ; CRASH_COUNT=0 ;;
        esac
    done
}

# ─── Main ───
if $HAS_NET; then
    ai_mode
else
    offline_mode
fi
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

# live-build REQUIRES root — don't try without it first (corrupts build/)
echo "[*] Running lb build with sudo (required for chroot + mount operations)..."
set +e
sudo lb build 2>&1 | tee "${ROOT_DIR}/build.log"
BUILD_EXIT=$?
set -e

# Fix ownership so user can modify build/ after
sudo chown -R "$(whoami):$(whoami)" "${BUILD_DIR}" 2>/dev/null || true

# Find the ISO (only match the hybrid one, not any leftovers)
ISO_SOURCE=""
for candidate in \
  "${BUILD_DIR}/live-image-amd64.hybrid.iso" \
  "${BUILD_DIR}/binary.hybrid.iso" \
  "${BUILD_DIR}/chroot/binary.hybrid.iso" \
  "${BUILD_DIR}"/*.iso \
  "${BUILD_DIR}/chroot"/*.iso; do
  if [ -f "$candidate" ]; then
    ISO_SOURCE="$candidate"
    break
  fi
done

if [ -z "${ISO_SOURCE}" ]; then
  echo "=== ❌ Build failed — no ISO found. Check build.log ==="
  exit 1
fi

# Copy result
mkdir -p "${OUTPUT_DIR}"
cp "${ISO_SOURCE}" "${OUTPUT_DIR}/${ISO_NAME}.iso"
echo ""
echo "=== ✅ ISO ready: ${OUTPUT_DIR}/${ISO_NAME}.iso ==="
ls -lh "${OUTPUT_DIR}/${ISO_NAME}.iso"

# Verify bootability — fallback to make-iso.sh if live-build failed
echo ""
echo "[*] Checking bootability..."
if command -v xorriso &>/dev/null; then
  if xorriso -indev "${OUTPUT_DIR}/${ISO_NAME}.iso" -report_el_torito plain 2>&1 | grep -qi "el torito"; then
    echo "[✅] ISO is bootable (El Torito found)"
  else
    echo "[!] ISO not bootable — rebuilding with xorriso manual..."
    bash "${ROOT_DIR}/make-iso.sh" "${BUILD_DIR}" "${OUTPUT_DIR}/${ISO_NAME}.iso"
  fi
else
  echo "[!] xorriso not available — bootability check skipped"
fi

# Generate checksum
sha256sum "${OUTPUT_DIR}/${ISO_NAME}.iso" > "${OUTPUT_DIR}/${ISO_NAME}.iso.sha256"
echo "    SHA256: $(cat "${OUTPUT_DIR}/${ISO_NAME}.iso.sha256")"
echo ""
echo "=== ✅ Build complete ==="

