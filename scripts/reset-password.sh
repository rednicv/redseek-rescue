#!/usr/bin/env bash
# reset-password.sh — Reset/remove Windows passwords offline from Linux USB
set -euo pipefail

MOUNT="/mnt/windows"
LOGS_DIR="/opt/rescue/logs"
BACKUP_DIR="/opt/rescue/registry-backup"
mkdir -p "${LOGS_DIR}" "${BACKUP_DIR}"

# Case-insensitive path resolver for Windows directories
find_win_path() {
  local base="$1"
  local target="$2"
  find "${base}" -maxdepth 1 -iname "${target}" -print 2>/dev/null | head -1 || echo "${base}/${target}"
}

echo "=== Windows Password Recovery ===" | tee "${LOGS_DIR}/reset-password.log"
echo "Date: $(date)" | tee -a "${LOGS_DIR}/reset-password.log"
echo "" | tee -a "${LOGS_DIR}/reset-password.log"

if ! mountpoint -q "${MOUNT}"; then
  echo "[!] Windows not mounted. Run mount-windows.sh first." | tee -a "${LOGS_DIR}/reset-password.log"
  exit 1
fi

# Detect Windows directory (case-insensitive)
WIN_DIR="$(find_win_path "${MOUNT}" "Windows")"
SYSTEM32="$(find_win_path "${WIN_DIR}" "System32")"
CONFIG_DIR="$(find_win_path "${SYSTEM32}" "config")"

usage() {
  echo "Usage:"
  echo "  ./reset-password.sh list-users           — list local users"
  echo "  ./reset-password.sh reset USER           — blank password for USER"
  echo "  ./reset-password.sh enable USER          — enable disabled account"
  echo "  ./reset-password.sh utilman              — enable utilman cmd hack"
  echo "  ./reset-password.sh undo-utilman         — restore original utilman"
  echo ""
}

# 1. List users via chntpw
list_users() {
  SAM="${CONFIG_DIR}/SAM"
  if [ ! -f "${SAM}" ]; then
    echo "[!] SAM registry hive not found." | tee -a "${LOGS_DIR}/reset-password.log"
    exit 1
  fi
  
  echo "[+] Local Windows users:" | tee -a "${LOGS_DIR}/reset-password.log"
  chntpw -l "${SAM}" 2>&1 | tee -a "${LOGS_DIR}/reset-password.log"
}

# 2. Reset password for a user (blank it)
reset_password() {
  USERNAME="$1"
  if [ -z "${USERNAME}" ]; then
    echo "[!] Specify username to reset." | tee -a "${LOGS_DIR}/reset-password.log"
    exit 1
  fi
  
  SAM="${CONFIG_DIR}/SAM"
  SYSTEM="${CONFIG_DIR}/SYSTEM"
  
  if [ ! -f "${SAM}" ] || [ ! -f "${SYSTEM}" ]; then
    echo "[!] SAM or SYSTEM hive not found." | tee -a "${LOGS_DIR}/reset-password.log"
    exit 1
  fi
  
  # Backup SAM first
  cp "${SAM}" "${BACKUP_DIR}/SAM.bak"
  cp "${SYSTEM}" "${BACKUP_DIR}/SYSTEM.bak"
  echo "[+] Backed up SAM + SYSTEM to ${BACKUP_DIR}" | tee -a "${LOGS_DIR}/reset-password.log"
  
  echo "[+] Resetting password for: ${USERNAME}" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "    Interactive mode. Follow instructions:" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "    1. Select '1' for 'Edit user data and passwords'" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "    2. Enter RID number for ${USERNAME}" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "    3. Select '1' to blank password" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "    4. Type '!' to quit, then 'y' to save" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "" | tee -a "${LOGS_DIR}/reset-password.log"
  
  # Run chntpw interactively
  chntpw -u "${USERNAME}" "${SAM}" 2>&1 | tee -a "${LOGS_DIR}/reset-password.log"
  
  echo "" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "[✅] Done. ${USERNAME} should now have blank password." | tee -a "${LOGS_DIR}/reset-password.log"
  echo "    Boot Windows and just press Enter at login." | tee -a "${LOGS_DIR}/reset-password.log"
}

# 3. Enable disabled account
enable_user() {
  USERNAME="$1"
  if [ -z "${USERNAME}" ]; then
    echo "[!] Specify username to enable." | tee -a "${LOGS_DIR}/reset-password.log"
    exit 1
  fi
  
  SAM="${CONFIG_DIR}/SAM"
  echo "[+] Enabling account: ${USERNAME}" | tee -a "${LOGS_DIR}/reset-password.log"
  chntpw -e "${USERNAME}" "${SAM}" 2>&1 | tee -a "${LOGS_DIR}/reset-password.log"
}

# 4. Utilman.exe hack — replace accessibility button with cmd.exe
# At login screen, click Ease of Access → gets you a SYSTEM cmd prompt
utilman_hack() {
  if [ ! -f "${SYSTEM32}/utilman.exe" ]; then
    echo "[!] utilman.exe not found." | tee -a "${LOGS_DIR}/reset-password.log"
    exit 1
  fi
  
  # Backup original
  cp "${SYSTEM32}/utilman.exe" "${BACKUP_DIR}/utilman.exe.bak"
  echo "[+] Backed up original utilman.exe" | tee -a "${LOGS_DIR}/reset-password.log"
  
  # Copy cmd.exe as utilman.exe
  cp "${SYSTEM32}/cmd.exe" "${SYSTEM32}/utilman.exe"
  echo "[✅] Replaced utilman.exe with cmd.exe" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "    At Windows login screen:" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "    1. Click the Ease of Access icon (accessibility)" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "    2. A cmd prompt opens as SYSTEM" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "    3. Type: net user USERNAME \"\"" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "    4. Or: net user USERNAME newpass" | tee -a "${LOGS_DIR}/reset-password.log"
  echo "    5. Close cmd, log in with blank password" | tee -a "${LOGS_DIR}/reset-password.log"
}

# 5. Restore original utilman.exe
undo_utilman() {
  if [ -f "${BACKUP_DIR}/utilman.exe.bak" ]; then
    cp "${BACKUP_DIR}/utilman.exe.bak" "${SYSTEM32}/utilman.exe"
    echo "[✅] Original utilman.exe restored." | tee -a "${LOGS_DIR}/reset-password.log"
  else
    echo "[!] No backup found." | tee -a "${LOGS_DIR}/reset-password.log"
  fi
}

# === MAIN ===
case "${1:-help}" in
  list-users)
    list_users
    ;;
  reset)
    reset_password "$2"
    ;;
  enable)
    enable_user "$2"
    ;;
  utilman)
    utilman_hack
    ;;
  undo-utilman)
    undo_utilman
    ;;
  *)
    usage
    ;;
esac
