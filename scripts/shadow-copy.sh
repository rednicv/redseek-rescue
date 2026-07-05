#!/usr/bin/env bash
# shadow-copy.sh — Access Windows Volume Shadow Copies (restore points) from Linux
# Uses libvshadow to list and mount restore points
set -euo pipefail

MOUNT="/mnt/windows"
LOGS_DIR="/opt/rescue/logs"
SHADOW_MOUNT="/mnt/shadow"
mkdir -p "${LOGS_DIR}" "${SHADOW_MOUNT}"

echo "=== Volume Shadow Copy (Restore Points) ===" | tee "${LOGS_DIR}/shadow-copy.log}"
echo "Date: $(date)" | tee -a "${LOGS_DIR}/shadow-copy.log"
echo "" | tee -a "${LOGS_DIR}/shadow-copy.log"

if ! mountpoint -q "${MOUNT}"; then
  echo "[!] Windows not mounted." | tee -a "${LOGS_DIR}/shadow-copy.log"
  exit 1
fi

# Find the Windows system drive device
WIN_DEV=$(findmnt -n -o SOURCE "${MOUNT}" 2>/dev/null | sed 's/[0-9]*$//' || echo "")
if [ -z "${WIN_DEV}" ]; then
  # Try to find it manually
  WIN_DEV=$(lsblk -o NAME,MOUNTPOINT -n -l | grep "${MOUNT}" | awk '{print $1}' | sed 's/[0-9]*$//' | xargs -I{} echo /dev/{})
fi

echo "[+] Windows device: ${WIN_DEV}" | tee -a "${LOGS_DIR}/shadow-copy.log"

# Check for shadow copies
echo "[+] Scanning for Volume Shadow Copies..." | tee -a "${LOGS_DIR}/shadow-copy.log"
vshadowinfo "${WIN_DEV}" 2>/dev/null > "${LOGS_DIR}/shadow-info.txt" || {
  echo "    No shadow copies found (or tool not available)" | tee -a "${LOGS_DIR}/shadow-copy.log"
  echo "    libvshadow tools may not be installed." | tee -a "${LOGS_DIR}/shadow-copy.log"
  exit 0
}

cat "${LOGS_DIR}/shadow-info.txt" | tee -a "${LOGS_DIR}/shadow-copy.log"

# Count shadow copies
SHADOW_COUNT=$(grep -c "Store:" "${LOGS_DIR}/shadow-info.txt" 2>/dev/null || echo 0)
echo "" | tee -a "${LOGS_DIR}/shadow-copy.log"
echo "[+] Found ${SHADOW_COUNT} shadow copy store(s)" | tee -a "${LOGS_DIR}/shadow-copy.log"

# If shadow copies exist, try to mount the latest one
if [ "${SHADOW_COUNT}" -gt 0 ]; then
  echo "" | tee -a "${LOGS_DIR}/shadow-copy.log"
  echo "    To mount a shadow copy manually:" | tee -a "${LOGS_DIR}/shadow-copy.log"
  echo "    vshadowmount ${WIN_DEV} ${SHADOW_MOUNT}" | tee -a "${LOGS_DIR}/shadow-copy.log"
  echo "    mount -o loop,ro ${SHADOW_MOUNT}/shadowX /mnt/shadow-data" | tee -a "${LOGS_DIR}/shadow-copy.log"
  echo "" | tee -a "${LOGS_DIR}/shadow-copy.log"
  echo "    Then you can copy registry/backups from restore point:" | tee -a "${LOGS_DIR}/shadow-copy.log"
  echo "    cp /mnt/shadow-data/Windows/System32/config/SYSTEM /opt/rescue/registry-backup/" | tee -a "${LOGS_DIR}/shadow-copy.log"
fi
