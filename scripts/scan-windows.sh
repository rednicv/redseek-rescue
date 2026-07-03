#!/usr/bin/env bash
# scan-windows.sh — Scan mounted Windows partition for malware from Linux
# Uses ClamAV (open source, runs on Linux, scans Windows files)
set -e

MOUNT="/mnt/windows"
LOGS_DIR="/opt/rescue/logs"
SCAN_LOG="${LOGS_DIR}/clamav-scan.log"

# Ensure the log directory actually exists before writing to it
mkdir -p "${LOGS_DIR}"

echo "=== ClamAV Windows Scan ===" | tee "${SCAN_LOG}"
echo "Date: $(date)" | tee -a "${SCAN_LOG}"
echo "" | tee -a "${SCAN_LOG}"

# Update virus definitions first
echo "[1/3] Updating virus definitions..." | tee -a "${SCAN_LOG}"
freshclam --quiet 2>&1 || echo "  ⚠️  Update failed, using existing definitions" | tee -a "${SCAN_LOG}"

# Scan Windows partition
echo "[2/3] Scanning Windows files (this may take a while)..." | tee -a "${SCAN_LOG}"
echo "      Scanning: ${MOUNT}" | tee -a "${SCAN_LOG}"
echo "      (Only infected files will stream below)" | tee -a "${SCAN_LOG}"
echo "" | tee -a "${SCAN_LOG}"

# Temporarily allow exit codes 0 and 1 — ClamAV returns 1 when it finds malware
set +e
clamscan -r "${MOUNT}" \
  --log="${SCAN_LOG}.detailed" \
  --infected \
  --exclude-dir="^${MOUNT}/Windows/WinSxS" \
  --exclude-dir="^${MOUNT}/Windows/Installer" \
  --max-files=100000 \
  --max-scansize=2000M \
  --bell 2>&1 | tee -a "${SCAN_LOG}"
set -e

# Summary
echo "" | tee -a "${SCAN_LOG}"
echo "[3/3] Scan complete" | tee -a "${SCAN_LOG}"

# Parse the detailed log for the final report
INFECTED=$(grep -c "FOUND" "${SCAN_LOG}.detailed" 2>/dev/null || echo 0)
SCANNED=$(grep "Scanned files:" "${SCAN_LOG}.detailed" 2>/dev/null | awk '{print $NF}' || echo "?")

echo "  Files scanned: ${SCANNED}" | tee -a "${SCAN_LOG}"
echo "  Infections found: ${INFECTED}" | tee -a "${SCAN_LOG}"

if [ "${INFECTED}" -gt 0 ]; then
  echo "" | tee -a "${SCAN_LOG}"
  echo "=== INFECTED FILES ===" | tee -a "${SCAN_LOG}"
  grep "FOUND" "${SCAN_LOG}.detailed" | tee -a "${SCAN_LOG}"
  echo "" | tee -a "${SCAN_LOG}"
  echo "To quarantine: clamscan --move=/opt/rescue/quarantine --infected [file]" | tee -a "${SCAN_LOG}"
  echo "To delete:     clamscan --remove --infected [file]" | tee -a "${SCAN_LOG}"
fi

echo "" | tee -a "${SCAN_LOG}"
echo "=== Full log: ${SCAN_LOG}.detailed ===" | tee -a "${SCAN_LOG}"
