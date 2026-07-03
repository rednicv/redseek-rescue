#!/usr/bin/env bash
# backup-data.sh — Backup user data from broken Windows to external USB or cloud
set -e

MOUNT="/mnt/windows"
LOGS_DIR="/opt/rescue/logs"
BACKUP_TARGET=""
USE_RCLONE=false

echo "=== Windows Data Backup ===" | tee "${LOGS_DIR}/backup.log"
echo "Date: $(date)" | tee -a "${LOGS_DIR}/backup.log"
echo "" | tee -a "${LOGS_DIR}/backup.log"

if ! mountpoint -q "${MOUNT}"; then
  echo "[!] Windows not mounted." | tee -a "${LOGS_DIR}/backup.log"
  exit 1
fi

# Detect a second USB drive for backup
detect_usb() {
  # Find removable drives that are NOT the current boot device
  for dev in /dev/sd[a-z][0-9]; do
    [ -b "${dev}" ] || continue
    MOUNTED=$(findmnt -n -o TARGET "${dev}" 2>/dev/null || true)
    if [ -n "${MOUNTED}" ] && [ "${MOUNTED}" != "${MOUNT}" ] && [ "${MOUNTED}" != "/run/live/medium" ]; then
      echo "${MOUNTED}"
      return
    fi
  done
  echo ""
}

usage() {
  echo "Usage:"
  echo "  ./backup-data.sh usb               — Backup to second USB drive"
  echo "  ./backup-data.sh cloud             — Backup to cloud (rclone config required)"
  echo "  ./backup-data.sh /mnt/usb2         — Backup to specific path"
  echo ""
  echo "Backs up: Desktop, Documents, Pictures, Downloads from all users"
}

# Key user folders to back up
FOLDERS=("Desktop" "Documents" "Downloads" "Pictures" "Music" "Videos" "OneDrive")

backup_to_path() {
  DEST="$1"
  mkdir -p "${DEST}/windows-backup"
  
  echo "[+] Backing up to: ${DEST}/windows-backup" | tee -a "${LOGS_DIR}/backup.log"
  
  USERS_DIR="${MOUNT}/Users"
  for userdir in "${USERS_DIR}"/*; do
    USERNAME=$(basename "${userdir}")
    [ "${USERNAME}" = "Public" ] || [ "${USERNAME}" = "All Users" ] || [ "${USERNAME}" = "Default" ] || [ "${USERNAME}" = "Default User" ] && continue
    [ ! -d "${userdir}" ] && continue
    
    echo "" | tee -a "${LOGS_DIR}/backup.log"
    echo "  User: ${USERNAME}" | tee -a "${LOGS_DIR}/backup.log"
    
    for folder in "${FOLDERS[@]}"; do
      SRC="${userdir}/${folder}"
      if [ -d "${SRC}" ]; then
        SIZE=$(du -sh "${SRC}" 2>/dev/null | cut -f1)
        echo "    📁 ${folder} (${SIZE})..." | tee -a "${LOGS_DIR}/backup.log"
        
        DEST_USER="${DEST}/windows-backup/${USERNAME}"
        mkdir -p "${DEST_USER}"
        
        # Copy with progress
        rsync -ah --progress "${SRC}/" "${DEST_USER}/${folder}/" 2>&1 | tail -1 | tee -a "${LOGS_DIR}/backup.log"
      fi
    done
  done
  
  echo "" | tee -a "${LOGS_DIR}/backup.log"
  echo "[✅] Backup complete to ${DEST}/windows-backup" | tee -a "${LOGS_DIR}/backup.log"
  du -sh "${DEST}/windows-backup" 2>/dev/null | tee -a "${LOGS_DIR}/backup.log"
}

backup_cloud() {
  if ! command -v rclone &>/dev/null; then
    echo "[!] rclone not installed." | tee -a "${LOGS_DIR}/backup.log"
    exit 1
  fi
  
  # Check for existing rclone config
  if [ ! -f "/root/.config/rclone/rclone.conf" ]; then
    echo "[!] No rclone config found." | tee -a "${LOGS_DIR}/backup.log"
    echo "    To set up: rclone config" | tee -a "${LOGS_DIR}/backup.log"
    echo "    Or backup to USB instead." | tee -a "${LOGS_DIR}/backup.log"
    exit 1
  fi
  
  # List available remotes
  echo "[!] Available rclone remotes:" | tee -a "${LOGS_DIR}/backup.log"
  rclone listremotes 2>/dev/null | tee -a "${LOGS_DIR}/backup.log"
  echo "" | tee -a "${LOGS_DIR}/backup.log"
  echo "    To backup: rclone copy ${MOUNT}/Users/Name/Desktop remote:backup/Name/" | tee -a "${LOGS_DIR}/backup.log"
}

# === MAIN ===
case "${1:-help}" in
  usb)
    USB_PATH=$(detect_usb)
    if [ -z "${USB_PATH}" ]; then
      echo "[!] No secondary USB detected." | tee -a "${LOGS_DIR}/backup.log"
      echo "    Insert a second USB stick and try again." | tee -a "${LOGS_DIR}/backup.log"
      echo "    Or specify path: ./backup-data.sh /path/to/dest" | tee -a "${LOGS_DIR}/backup.log"
      exit 1
    fi
    backup_to_path "${USB_PATH}"
    ;;
  cloud)
    backup_cloud
    ;;
  *)
    if [ -n "${1}" ] && [ -d "${1}" ]; then
      backup_to_path "${1}"
    else
      usage
    fi
    ;;
esac
