#!/usr/bin/env bash
# mount-windows.sh — Detect and mount Windows partitions (with BitLocker support)
# Usage: ./mount-windows.sh [--remove-hiberfile]
set -e

RESCUE_DIR="/opt/rescue"
MOUNT_POINT="/mnt/windows"
LOGS_DIR="${RESCUE_DIR}/logs"
BITLOCKER_MOUNT="/mnt/bitlocker"
STATUS_FILE="${RESCUE_DIR}/config/mount-status.txt"

REMOVE_HIBER=false
if [ "${1}" = "--remove-hiberfile" ] || [ "${1}" = "-r" ]; then
    REMOVE_HIBER=true
fi

mkdir -p "${MOUNT_POINT}" "${LOGS_DIR}" "${BITLOCKER_MOUNT}"
rm -f "${STATUS_FILE}"

echo "[$(date)] Scanning for Windows partitions..." | tee "${LOGS_DIR}/mount.log"

lsblk -o NAME,FSTYPE,LABEL,SIZE,MODEL -n -l > /tmp/all-parts.txt 2>/dev/null
cat /tmp/all-parts.txt | tee -a "${LOGS_DIR}/mount.log"

# Check for BitLocker encrypted partitions
BITLOCKER_PARTS=$(blkid | grep -i "FVE_FS\\|BitLocker" | awk -F: '{print $1}' || true)

if [ -n "${BITLOCKER_PARTS}" ]; then
  echo "[!] BitLocker encrypted partition detected: ${BITLOCKER_PARTS}" | tee -a "${LOGS_DIR}/mount.log"
  echo "${BITLOCKER_PARTS}" > "${RESCUE_DIR}/config/bitlocker-detected.txt"
fi

# Find REAL NTFS partitions strictly by FSTYPE column
NTFS_PARTS=$(lsblk -o NAME,FSTYPE -n -l | awk '$2 == "ntfs" {print $1}')

if [ -z "${NTFS_PARTS}" ]; then
  echo "[!] No NTFS partitions found." | tee -a "${LOGS_DIR}/mount.log"
  if [ -n "${BITLOCKER_PARTS}" ]; then
    echo "[*] System relies on BitLocker. Ask Hermes to unlock it." | tee -a "${LOGS_DIR}/mount.log"
    exit 0
  fi
  exit 1
fi

# Select the largest NTFS partition
FIRST_PART=$(lsblk -o NAME,FSTYPE,SIZE -n -l | awk '$2 == "ntfs" {print $1,$3}' | sort -k2 -h | tail -n1 | awk '{print $1}')
echo "[+] Selected partition /dev/${FIRST_PART} as primary target." | tee -a "${LOGS_DIR}/mount.log"

# If --remove-hiberfile, try to remove hiberfil.sys before mount
if [ "${REMOVE_HIBER}" = true ]; then
    echo "[*] --remove-hiberfile flag set. Attempting to delete hiberfil.sys first..." | tee -a "${LOGS_DIR}/mount.log"
    
    TMP_MOUNT="/tmp/win-hiberfix"
    mkdir -p "${TMP_MOUNT}"
    
    # ntfs-3g has a 'remove_hiberfile' mount option
    if mount -t ntfs-3g -o remove_hiberfile "/dev/${FIRST_PART}" "${TMP_MOUNT}" 2>/dev/null; then
        echo "[✅] Removed hiberfil.sys successfully." | tee -a "${LOGS_DIR}/mount.log"
        umount "${TMP_MOUNT}" 2>/dev/null || true
    else
        echo "[!] Could not remove hiberfil.sys automatically." | tee -a "${LOGS_DIR}/mount.log"
        echo "    Try booting Windows once and shutting down fully (NOT restart/hibernate)." | tee -a "${LOGS_DIR}/mount.log"
    fi
    rmdir "${TMP_MOUNT}" 2>/dev/null || true
fi

echo "[+] Attempting Read-Write mount..." | tee -a "${LOGS_DIR}/mount.log"
if mount -t ntfs3 "/dev/${FIRST_PART}" "${MOUNT_POINT}" 2>/dev/null || \
   mount -t ntfs-3g "/dev/${FIRST_PART}" "${MOUNT_POINT}" 2>/dev/null; then
    echo "rw" > "${STATUS_FILE}"
    echo "[✅] Windows mounted in READ-WRITE mode at ${MOUNT_POINT}" | tee -a "${LOGS_DIR}/mount.log"
else
    echo "[!] Read-Write failed. Trying Read-Only (Windows might be hibernated)..." | tee -a "${LOGS_DIR}/mount.log"
    if mount -t ntfs-3g -o ro "/dev/${FIRST_PART}" "${MOUNT_POINT}" 2>/dev/null; then
        echo "ro" > "${STATUS_FILE}"
        echo "[⚠️] Windows mounted in READ-ONLY mode. Repairs involving writes will fail." | tee -a "${LOGS_DIR}/mount.log"
        echo "     To fix: boot Windows once, shut down fully, then re-run:" | tee -a "${LOGS_DIR}/mount.log"
        echo "     ./mount-windows.sh --remove-hiberfile" | tee -a "${LOGS_DIR}/mount.log"
    else
        echo "[❌] Cannot mount Windows partition. Corrupted or locked." | tee -a "${LOGS_DIR}/mount.log"
        exit 1
    fi
fi

# Save detailed info for Hermes context
cat > "${RESCUE_DIR}/config/windows-info.txt" << INFO
Windows partition mounted at: ${MOUNT_POINT}
Partition device: /dev/${FIRST_PART}
Mount Mode: $(cat ${STATUS_FILE})
Windows directory: ${MOUNT_POINT}/Windows
System32: ${MOUNT_POINT}/Windows/System32
Event logs: ${MOUNT_POINT}/Windows/System32/winevt/Logs
Minidumps: ${MOUNT_POINT}/Windows/minidump
Registry files: ${MOUNT_POINT}/Windows/System32/config
Users directory: ${MOUNT_POINT}/Users
INFO

echo "[📋] System info saved. Mount mode: $(cat ${STATUS_FILE})" | tee -a "${LOGS_DIR}/mount.log"
