#!/usr/bin/env bash
# mount-windows.sh — Detect and mount Windows partitions (with BitLocker support)
set -e

RESCUE_DIR="/opt/rescue"
MOUNT_POINT="/mnt/windows"
LOGS_DIR="${RESCUE_DIR}/logs"
BITLOCKER_MOUNT="/mnt/bitlocker"
mkdir -p "${MOUNT_POINT}" "${LOGS_DIR}" "${BITLOCKER_MOUNT}"

echo "[$(date)] Scanning for Windows partitions..." | tee "${LOGS_DIR}/mount.log"

# Find all partitions
lsblk -o NAME,FSTYPE,LABEL,SIZE,MODEL -n -l > /tmp/all-parts.txt 2>/dev/null
cat /tmp/all-parts.txt | tee -a "${LOGS_DIR}/mount.log"

# Check for BitLocker encrypted partitions
BITLOCKER_PARTS=$(blkid | grep -i "FVE_FS\|BitLocker" | awk -F: '{print $1}' || true)

if [ -n "${BITLOCKER_PARTS}" ]; then
  echo "[!] BitLocker encrypted partition detected!" | tee -a "${LOGS_DIR}/mount.log"
  echo "    ${BITLOCKER_PARTS}" | tee -a "${LOGS_DIR}/mount.log"
  echo "" | tee -a "${LOGS_DIR}/mount.log"
  echo "    To unlock, you need the BitLocker Recovery Key." | tee -a "${LOGS_DIR}/mount.log"
  echo "    Run: dislocker -V /dev/sdX# -u<RECOVERY_KEY> -- ${BITLOCKER_MOUNT}" | tee -a "${LOGS_DIR}/mount.log"
  echo "    Then: mount -o loop ${BITLOCKER_MOUNT}/dislocker-file ${MOUNT_POINT}" | tee -a "${LOGS_DIR}/mount.log"
  echo "    Or ask Hermes to handle it." | tee -a "${LOGS_DIR}/mount.log"
  
  # Save info for Hermes
  echo "${BITLOCKER_PARTS}" > "${RESCUE_DIR}/config/bitlocker-detected.txt"
  exit 0  # Don't fail, just report
fi

# Find NTFS partitions (regular)
NTFS_PARTS=$(lsblk -o NAME,FSTYPE,LABEL,SIZE,MODEL -n -l | grep ntfs | awk '{print $1}')

if [ -z "${NTFS_PARTS}" ]; then
  echo "[!] No NTFS partitions found." | tee -a "${LOGS_DIR}/mount.log"
  # Try to find any Windows-related partition
  WIN_PARTS=$(lsblk -o NAME,LABEL -n -l | grep -iE "windows|win|system|boot|os" | awk '{print $1}' || true)
  if [ -n "${WIN_PARTS}" ]; then
    echo "    But found potential Windows partitions: ${WIN_PARTS}" | tee -a "${LOGS_DIR}/mount.log"
  fi
  exit 1
fi

echo "[+] Found NTFS partitions:" | tee -a "${LOGS_DIR}/mount.log"

# Try to mount the first suitable NTFS partition (prefer the largest or labeled Windows)
FIRST_PART=$(echo "${NTFS_PARTS}" | head -1)
echo "[+] Mounting /dev/${FIRST_PART} to ${MOUNT_POINT}..." | tee -a "${LOGS_DIR}/mount.log"

mount -t ntfs3 "/dev/${FIRST_PART}" "${MOUNT_POINT}" 2>/dev/null || \
mount -t ntfs-3g "/dev/${FIRST_PART}" "${MOUNT_POINT}" 2>/dev/null || {
  echo "[!] Failed to mount. Trying read-only..." | tee -a "${LOGS_DIR}/mount.log"
  mount -t ntfs-3g -o ro "/dev/${FIRST_PART}" "${MOUNT_POINT}" 2>/dev/null || {
    echo "[!] Cannot mount Windows partition." | tee -a "${LOGS_DIR}/mount.log"
    echo "    Possible reasons: hibernated, BitLocker, or corrupted." | tee -a "${LOGS_DIR}/mount.log"
    exit 1
  }
}

echo "[✅] Windows mounted at ${MOUNT_POINT}" | tee -a "${LOGS_DIR}/mount.log"
echo "     Contents: $(ls -1 ${MOUNT_POINT} | wc -l) files/dirs" | tee -a "${LOGS_DIR}/mount.log"

# Save mount info for Hermes context
cat > "${RESCUE_DIR}/config/windows-info.txt" << INFO
Windows partition mounted at: ${MOUNT_POINT}
Partition device: /dev/${FIRST_PART}
Windows directory: ${MOUNT_POINT}/Windows
System32: ${MOUNT_POINT}/Windows/System32
Event logs: ${MOUNT_POINT}/Windows/System32/winevt/Logs
Minidumps: ${MOUNT_POINT}/Windows/minidump
Registry files: ${MOUNT_POINT}/Windows/System32/config
Users directory: ${MOUNT_POINT}/Users
INFO
