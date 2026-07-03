#!/usr/bin/env bash
# diagnose.sh — Quick system diagnostics (run manually or from Hermes)
# Usage: ./diagnose.sh [--quick|--full]

set -e
RESCUE_DIR="/opt/rescue"
LOGS_DIR="${RESCUE_DIR}/logs"
mkdir -p "${LOGS_DIR}"

MODE="${1:-quick}"
REPORT="${LOGS_DIR}/diagnostic-report.txt"

echo "deepseekrescue Diagnostic Report" > "${REPORT}"
echo "================================" >> "${REPORT}"
echo "Date: $(date)" >> "${REPORT}"
echo "Mode: ${MODE}" >> "${REPORT}"
echo "" >> "${REPORT}"

# === System info ===
echo "--- System Information ---" | tee -a "${REPORT}"
uname -a >> "${REPORT}"
echo "" >> "${REPORT}"

# === Disk info ===
echo "--- Disk Health (SMART) ---" | tee -a "${REPORT}"
for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
  [ -b "${disk}" ] || continue
  echo "Disk: ${disk}" >> "${REPORT}"
  smartctl -H "${disk}" 2>/dev/null | grep -E "SMART overall-health|SMART Health Status|PASSED|FAILED" >> "${REPORT}" || echo "  SMART not supported" >> "${REPORT}"
done
echo "" >> "${REPORT}"

# === Partition table ===
echo "--- Partition Table ---" | tee -a "${REPORT}"
lsblk -o NAME,FSTYPE,LABEL,SIZE,FSAVAIL,FSUSE%,MOUNTPOINT,MODEL >> "${REPORT}"
echo "" >> "${REPORT}"

# === Memory ===
echo "--- Memory ---" | tee -a "${REPORT}"
free -h >> "${REPORT}"
echo "" >> "${REPORT}"

# === Network ===
echo "--- Network ---" | tee -a "${REPORT}"
ip addr show | grep -E "inet |link/" >> "${REPORT}" || true
echo "" >> "${REPORT}"

# === Windows-specific (if mounted) ===
if mountpoint -q /mnt/windows; then
  echo "--- Windows Info ---" | tee -a "${REPORT}"
  
  # Check Windows version
  if [ -f /mnt/windows/Windows/System32/config/SOFTWARE ]; then
    echo "Windows registry hive found" >> "${REPORT}"
  fi
  
  # Check minidumps
  if [ -d /mnt/windows/Windows/minidump ]; then
    DUMPS=$(ls /mnt/windows/Windows/minidump/*.dmp 2>/dev/null | wc -l)
    echo "BSOD minidumps found: ${DUMPS}" >> "${REPORT}"
  fi
  
  # Check disk usage of Windows partition
  echo "Windows partition usage:" >> "${REPORT}"
  df -h /mnt/windows >> "${REPORT}"
  
  # Boot configuration
  if [ -f /mnt/windows/Windows/System32/bcd ]; then
    echo "BCD file present" >> "${REPORT}"
  fi
fi

echo "" >> "${REPORT}"
echo "=== Report saved to ${REPORT} ==="
cat "${REPORT}"
