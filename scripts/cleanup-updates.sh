#!/usr/bin/env bash
# cleanup-updates.sh — Clean stuck Windows updates that cause boot loops
# Fixes "Getting Windows ready, don't turn off your computer" infinite loop
set -e

MOUNT="/mnt/windows"
LOGS_DIR="/opt/rescue/logs"
BACKUP_DIR="/opt/rescue/update-cleanup-backup"
mkdir -p "${LOGS_DIR}" "${BACKUP_DIR}"

echo "=== Windows Update Cleanup ===" | tee "${LOGS_DIR}/cleanup-updates.log"
echo "Date: $(date)" | tee -a "${LOGS_DIR}/cleanup-updates.log"
echo "" | tee -a "${LOGS_DIR}/cleanup-updates.log"

if ! mountpoint -q "${MOUNT}"; then
  echo "[!] Windows not mounted. Run mount-windows.sh first." | tee -a "${LOGS_DIR}/cleanup-updates.log"
  exit 1
fi

# 1. Check and clean pending.xml
PENDING_XML="${MOUNT}/Windows/WinSxS/pending.xml"
if [ -f "${PENDING_XML}" ]; then
  SIZE=$(stat -c%s "${PENDING_XML}")
  echo "[1] Found pending.xml (${SIZE} bytes)" | tee -a "${LOGS_DIR}/cleanup-updates.log"
  echo "    Backing up to ${BACKUP_DIR}/pending.xml..." | tee -a "${LOGS_DIR}/cleanup-updates.log"
  cp "${PENDING_XML}" "${BACKUP_DIR}/" 2>/dev/null
  rm -f "${PENDING_XML}" 2>/dev/null && echo "    ✅ pending.xml removed" | tee -a "${LOGS_DIR}/cleanup-updates.log" || echo "    ❌ Could not remove (permissions?)" | tee -a "${LOGS_DIR}/cleanup-updates.log"
else
  echo "[1] No pending.xml found" | tee -a "${LOGS_DIR}/cleanup-updates.log"
fi

# 2. Clean SoftwareDistribution download folder
SD_DIR="${MOUNT}/Windows/SoftwareDistribution/Download"
if [ -d "${SD_DIR}" ]; then
  COUNT=$(ls -1 "${SD_DIR}" | wc -l)
  echo "" | tee -a "${LOGS_DIR}/cleanup-updates.log"
  echo "[2] SoftwareDistribution/Download: ${COUNT} items" | tee -a "${LOGS_DIR}/cleanup-updates.log"
  
  ITEMS=$(ls "${SD_DIR}" 2>/dev/null | head -10)
  echo "    Contents: ${ITEMS}" | tee -a "${LOGS_DIR}/cleanup-updates.log"
  
  echo "    Clearing download cache..." | tee -a "${LOGS_DIR}/cleanup-updates.log}"
  rm -rf "${SD_DIR:?}/"* 2>/dev/null && echo "    ✅ Download cache cleared" | tee -a "${LOGS_DIR}/cleanup-updates.log" || echo "    ❌ Could not clear (permissions?)" | tee -a "${LOGS_DIR}/cleanup-updates.log"
else
  echo "[2] SoftwareDistribution/Download not found" | tee -a "${LOGS_DIR}/cleanup-updates.log"
fi

# 3. Check for .regtrans-ms transaction files
REG_DIR="${MOUNT}/Windows/System32/config"
TXN_FILES=$(find "${REG_DIR}" -name "*.regtrans-ms" -o -name "*.blf" -o -name "*.TM.blf" 2>/dev/null | head -10)
if [ -n "${TXN_FILES}" ]; then
  echo "" | tee -a "${LOGS_DIR}/cleanup-updates.log"
  echo "[3] Registry transaction files found:" | tee -a "${LOGS_DIR}/cleanup-updates.log}"
  echo "    ${TXN_FILES}" | tee -a "${LOGS_DIR}/cleanup-updates.log"
  echo "    These are normal - only remove if update is stuck." | tee -a "${LOGS_DIR}/cleanup-updates.log"
fi

# 4. Check CBS (Component-Based Servicing) pending
CBS_PENDING="${MOUNT}/Windows/servicing/CBS/pending.xml"
if [ -f "${CBS_PENDING}" ]; then
  echo "" | tee -a "${LOGS_DIR}/cleanup-updates.log"
  echo "[4] CBS pending.xml found (Component Based Servicing)" | tee -a "${LOGS_DIR}/cleanup-updates.log"
  echo "    Contains install operations to complete." | tee -a "${LOGS_DIR}/cleanup-updates.log"
fi

# 5. Check for reboot pending marker
REBOOT_FILE="${MOUNT}/Windows/System32/config/DOSREBOOT.REQ"
if [ -f "${REBOOT_FILE}" ]; then
  echo "" | tee -a "${LOGS_DIR}/cleanup-updates.log"
  echo "[5] Reboot pending marker found" | tee -a "${LOGS_DIR}/cleanup-updates.log"
fi

echo "" | tee -a "${LOGS_DIR}/cleanup-updates.log"
echo "=== Cleanup complete ===" | tee -a "${LOGS_DIR}/cleanup-updates.log"
echo "Backup saved to: ${BACKUP_DIR}" | tee -a "${LOGS_DIR}/cleanup-updates.log"
echo "Try booting Windows now." | tee -a "${LOGS_DIR}/cleanup-updates.log"
