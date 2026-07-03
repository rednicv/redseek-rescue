#!/usr/bin/env bash
# cleanup-updates.sh — Clean stuck Windows updates that cause boot loops
# Fixes "Getting Windows ready, don't turn off your computer" infinite loop
set -e

MOUNT="/mnt/windows"
LOGS_DIR="/opt/rescue/logs"
BACKUP_DIR="/opt/rescue/update-cleanup-backup"
CLEANUP_LOG="${LOGS_DIR}/cleanup-updates.log"

mkdir -p "${LOGS_DIR}" "${BACKUP_DIR}"

echo "=== Windows Update Cleanup ===" | tee "${CLEANUP_LOG}"
echo "Date: $(date)" | tee -a "${CLEANUP_LOG}"
echo "" | tee -a "${CLEANUP_LOG}"

if ! mountpoint -q "${MOUNT}"; then
  echo "[!] Windows not mounted. Run mount-windows.sh first." | tee -a "${CLEANUP_LOG}"
  exit 1
fi

# Helper: case-insensitive find (handles Windows/System32 vs windows/system32)
find_ci() {
    find "$1" -maxdepth "$2" -iname "$3" 2>/dev/null | head -n1
}

# 1. Check and clean pending.xml (in WinSxS)
WINSXS_DIR=$(find_ci "${MOUNT}/Windows" 1 "WinSxS")
PENDING_XML=""
if [ -n "${WINSXS_DIR}" ]; then
    PENDING_XML=$(find_ci "${WINSXS_DIR}" 1 "pending.xml")
fi

if [ -n "${PENDING_XML}" ] && [ -f "${PENDING_XML}" ]; then
  SIZE=$(stat -c%s "${PENDING_XML}")
  echo "[1] Found pending.xml (${SIZE} bytes) at ${PENDING_XML}" | tee -a "${CLEANUP_LOG}"
  echo "    Backing up to ${BACKUP_DIR}/pending.xml..." | tee -a "${CLEANUP_LOG}"
  cp "${PENDING_XML}" "${BACKUP_DIR}/" 2>/dev/null
  rm -f "${PENDING_XML}" 2>/dev/null && echo "    ✅ pending.xml removed" | tee -a "${CLEANUP_LOG}" || echo "    ❌ Could not remove (permissions?)" | tee -a "${CLEANUP_LOG}"
else
  echo "[1] No pending.xml found in WinSxS" | tee -a "${CLEANUP_LOG}"
fi

# 2. Clean SoftwareDistribution download folder
SD_DIR=$(find_ci "${MOUNT}/Windows" 1 "SoftwareDistribution")
SD_DOWNLOAD=""
if [ -n "${SD_DIR}" ]; then
    SD_DOWNLOAD=$(find_ci "${SD_DIR}" 1 "Download")
fi

if [ -n "${SD_DOWNLOAD}" ] && [ -d "${SD_DOWNLOAD}" ]; then
  COUNT=$(ls -1 "${SD_DOWNLOAD}" | wc -l)
  echo "" | tee -a "${CLEANUP_LOG}"
  echo "[2] SoftwareDistribution/Download: ${COUNT} items found" | tee -a "${CLEANUP_LOG}"
  
  ITEMS=$(ls "${SD_DOWNLOAD}" 2>/dev/null | head -10 | tr '\n' ' ')
  echo "    Contents snippet: ${ITEMS}" | tee -a "${CLEANUP_LOG}"
  
  echo "    Clearing download cache..." | tee -a "${CLEANUP_LOG}"
  # Safe delete: only contents, not the directory itself
  find "${SD_DOWNLOAD}" -mindepth 1 -delete 2>/dev/null && echo "    ✅ Download cache cleared" | tee -a "${CLEANUP_LOG}" || echo "    ❌ Could not clear completely (permissions?)" | tee -a "${CLEANUP_LOG}"
else
  echo "[2] SoftwareDistribution/Download folder not found" | tee -a "${CLEANUP_LOG}"
fi

# 3. Check for .regtrans-ms transaction files
REG_DIR=$(find_ci "${MOUNT}/Windows/System32" 1 "config")
if [ -n "${REG_DIR}" ]; then
  TXN_FILES=$(find "${REG_DIR}" -type f \( -iname "*.regtrans-ms" -o -iname "*.blf" \) 2>/dev/null | head -5)
  if [ -n "${TXN_FILES}" ]; then
    echo "" | tee -a "${CLEANUP_LOG}"
    echo "[3] Registry transaction files found in config:" | tee -a "${CLEANUP_LOG}"
    echo "${TXN_FILES}" | tee -a "${CLEANUP_LOG}"
    echo "    These are normal — only remove if registry is confirmed corrupted." | tee -a "${CLEANUP_LOG}"
  fi
fi

# 4. Check CBS (Component-Based Servicing) pending
CBS_DIR=$(find_ci "${MOUNT}/Windows" 2 "servicing")
if [ -n "${CBS_DIR}" ]; then
    CBS_PENDING=$(find_ci "${CBS_DIR}" 2 "pending.xml")
    if [ -n "${CBS_PENDING}" ] && [ -f "${CBS_PENDING}" ]; then
      echo "" | tee -a "${CLEANUP_LOG}"
      echo "[4] CBS pending.xml found at: ${CBS_PENDING}" | tee -a "${CLEANUP_LOG}"
      echo "    Contains component installation operations." | tee -a "${CLEANUP_LOG}"
    fi
fi

echo "" | tee -a "${CLEANUP_LOG}"
echo "=== Cleanup complete ===" | tee -a "${CLEANUP_LOG}"
echo "Backup saved to: ${BACKUP_DIR}" | tee -a "${CLEANUP_LOG}"
echo "Try booting Windows now." | tee -a "${CLEANUP_LOG}"
