#!/usr/bin/env bash
# backup-data.sh — Backup user data from broken Windows to external USB or cloud
set -e

MOUNT="/mnt/windows"
LOGS_DIR="/opt/rescue/logs"
mkdir -p "${LOGS_DIR}"

BACKUP_LOG="${LOGS_DIR}/backup.log"

echo "=== Windows Data Backup ===" | tee "${BACKUP_LOG}"
echo "Date: $(date)" | tee -a "${BACKUP_LOG}"
echo "" | tee -a "${BACKUP_LOG}"

if ! mountpoint -q "${MOUNT}"; then
  echo "[!] Windows not mounted. Run mount-windows.sh first." | tee -a "${BACKUP_LOG}"
  exit 1
fi

# Detect a second USB drive for backup
detect_usb() {
  for dev in /dev/sd[a-z][0-9] /dev/nvme[0-9]n[0-9]p[0-9]; do
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
  echo "  ./backup-data.sh cloud             — Backup to cloud (automated rclone)"
  echo "  ./backup-data.sh /mnt/usb2         — Backup to specific path"
  echo ""
  echo "Backs up: Desktop, Documents, Pictures, Downloads, Music, Videos, OneDrive"
}

FOLDERS=("Desktop" "Documents" "Downloads" "Pictures" "Music" "Videos" "OneDrive")
USERS_DIR="${MOUNT}/Users"

backup_to_path() {
  DEST="$1"
  mkdir -p "${DEST}/windows-backup"
  
  echo "[+] Backing up to local path: ${DEST}/windows-backup" | tee -a "${BACKUP_LOG}"
  
  for userdir in "${USERS_DIR}"/*; do
    USERNAME=$(basename "${userdir}")
    
    # Skip Windows system folders
    case "${USERNAME}" in
        Public|"All Users"|Default|"Default User"|desktop.ini) continue ;;
    esac
    [ ! -d "${userdir}" ] && continue
    
    echo "" | tee -a "${BACKUP_LOG}"
    echo "👤 Processing user: ${USERNAME}" | tee -a "${BACKUP_LOG}"
    
    for folder in "${FOLDERS[@]}"; do
      # Case-insensitive search (Desktop vs desktop)
      SRC=$(find "${userdir}" -maxdepth 1 -iname "${folder}" 2>/dev/null | head -n1)
      
      if [ -n "${SRC}" ] && [ -d "${SRC}" ]; then
        SIZE=$(du -sh "${SRC}" 2>/dev/null | cut -f1)
        echo "  --> 📁 ${folder} (${SIZE})..." | tee -a "${BACKUP_LOG}"
        
        DEST_USER="${DEST}/windows-backup/${USERNAME}/${folder}"
        mkdir -p "${DEST_USER}"
        
        # Live progress — user sees what's happening
        rsync -ah --info=progress2 "${SRC}/" "${DEST_USER}/"
      fi
    done
  done
  
  echo "" | tee -a "${BACKUP_LOG}"
  echo "[✅] Backup complete to ${DEST}/windows-backup" | tee -a "${BACKUP_LOG}"
}

backup_cloud() {
  if ! command -v rclone &>/dev/null; then
    echo "[!] rclone is not installed." | tee -a "${BACKUP_LOG}"
    exit 1
  fi
  
  if [ ! -f "/root/.config/rclone/rclone.conf" ] && [ ! -f "/home/rescue/.config/rclone/rclone.conf" ]; then
    echo "[!] No rclone configuration found." | tee -a "${BACKUP_LOG}"
    echo "    Please open a terminal and run: rclone config"
    exit 1
  fi
  
  echo "[*] Available cloud remotes:"
  REMOTES=$(rclone listremotes 2>/dev/null)
  if [ -z "${REMOTES}" ]; then
    echo "    No remotes configured. Run 'rclone config' first."
    exit 1
  fi
  echo "${REMOTES}"
  
  read -p "Enter the remote name you want to use (e.g. gdrive): " TARGET_REMOTE
  TARGET_REMOTE=$(echo "${TARGET_REMOTE}" | tr -d ':')
  
  echo "[+] Starting automated Cloud Backup to ${TARGET_REMOTE}:rescue-backup" | tee -a "${BACKUP_LOG}"
  
  for userdir in "${USERS_DIR}"/*; do
    USERNAME=$(basename "${userdir}")
    case "${USERNAME}" in
        Public|"All Users"|Default|"Default User"|desktop.ini) continue ;;
    esac
    [ ! -d "${userdir}" ] && continue
    
    for folder in "${FOLDERS[@]}"; do
      SRC=$(find "${userdir}" -maxdepth 1 -iname "${folder}" 2>/dev/null | head -n1)
      if [ -n "${SRC}" ] && [ -d "${SRC}" ]; then
        echo "☁️ Uploading ${USERNAME} -> ${folder}..."
        rclone copy "${SRC}" "${TARGET_REMOTE}:rescue-backup/${USERNAME}/${folder}" --progress
      fi
    done
  done
  echo "[✅] Cloud backup finished successfully!"
}

# === MAIN ===
case "${1:-help}" in
  usb)
    USB_PATH=$(detect_usb)
    if [ -z "${USB_PATH}" ]; then
      echo "[!] No secondary/mounted USB detected." | tee -a "${BACKUP_LOG}"
      echo "    Make sure the target USB is inserted and mounted." | tee -a "${BACKUP_LOG}"
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
