#!/usr/bin/env bash
# diagnose.sh — System diagnostics (run manually or from Hermes)
# Usage: ./diagnose.sh [--quick|--full]
#
# --quick: SMART, partitions, memory, basic Windows checks
# --full:  everything above + boot drivers, registry backups, deeper analysis

set -e
RESCUE_DIR="/opt/rescue"
LOGS_DIR="${RESCUE_DIR}/logs"
mkdir -p "${LOGS_DIR}"

MODE="${1:---quick}"
REPORT="${LOGS_DIR}/diagnostic-report.txt"

echo "RedSeek Rescue Diagnostic Report" > "${REPORT}"
echo "================================" >> "${REPORT}"
echo "Date: $(date)" >> "${REPORT}"
echo "Mode: ${MODE}" >> "${REPORT}"
echo "" >> "${REPORT}"

# === System info ===
echo "--- System Information ---" | tee -a "${REPORT}"
uname -a >> "${REPORT}"
echo "" >> "${REPORT}"

# === Disk info (SMART) ===
echo "--- Disk Health (SMART) ---" | tee -a "${REPORT}"
# Use /sys/block for robust detection (catches nvme0n1, nvme1n1, sda, etc.)
for disk_name in $(ls /sys/block/ 2>/dev/null | grep -E '^sd|^nvme|^vd'); do
  disk="/dev/${disk_name}"
  [ -b "${disk}" ] || continue
  echo "Disk: ${disk}" >> "${REPORT}"
  
  # Capture full SMART output to avoid broken pipe logic
  SMART_OUT=$(smartctl -H "${disk}" 2>/dev/null || true)
  if echo "${SMART_OUT}" | grep -qE "SMART|PASSED|FAILED|OK"; then
    echo "${SMART_OUT}" | grep -E "overall-health|Status|PASSED|FAILED|OK|result" >> "${REPORT}"
  else
    echo "  SMART not supported or drive sleeping" >> "${REPORT}"
  fi
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
  
  # Case-insensitive search for registry hive
  SOFT_HIVE=$(find /mnt/windows/[Ww]indows/[Ss]ystem32/config/ -maxdepth 1 -iname "software" 2>/dev/null | head -n1)
  if [ -n "${SOFT_HIVE}" ]; then
    echo "Windows registry hive found: ${SOFT_HIVE}" >> "${REPORT}"
  fi
  
  # Check minidumps (case-insensitive)
  DUMP_DIR=$(find /mnt/windows/[Ww]indows/ -maxdepth 1 -iname "minidump" 2>/dev/null | head -n1)
  if [ -n "${DUMP_DIR}" ] && [ -d "${DUMP_DIR}" ]; then
    DUMPS=$(find "${DUMP_DIR}" -maxdepth 1 -iname "*.dmp" 2>/dev/null | wc -l)
    echo "BSOD minidumps found: ${DUMPS}" >> "${REPORT}"
  fi
  
  # Boot configuration (BCD) — case-insensitive search
  BCD_FILE=$(find /mnt/windows/[Ww]indows/[Ss]ystem32/ -maxdepth 2 -iname "bcd" 2>/dev/null | head -n1)
  if [ -n "${BCD_FILE}" ]; then
    echo "BCD file present at: ${BCD_FILE}" >> "${REPORT}"
  fi

  # === FULL MODE — deep software diagnostics ===
  if [ "${MODE}" == "--full" ]; then
    echo "" >> "${REPORT}"
    echo "--- Deep Software Diagnostics (Full Mode) ---" >> "${REPORT}"
    
    # Count boot drivers
    for drivers_dir in /mnt/windows/[Ww]indows/[Ss]ystem32/drivers /mnt/windows/[Ww]indows/[Ss]ystem32/drivers/etc; do
      if [ -d "${drivers_dir}" ]; then
        echo "Boot drivers in ${drivers_dir}: $(ls "${drivers_dir}" 2>/dev/null | wc -l)" >> "${REPORT}"
      fi
    done
    
    # Check for registry backups (RegBack)
    for regback_dir in /mnt/windows/[Ww]indows/[Ss]ystem32/config/RegBack /mnt/windows/[Ww]indows/[Ss]ystem32/config/regback; do
      if [ -d "${regback_dir}" ]; then
        echo "RegBack folder is present (potential registry restore available)" >> "${REPORT}"
        break
      fi
    done
    
    # Check pending updates / stuck reboot flags
    for pending in /mnt/windows/[Ww]indows/WinSxS/pending.xml /mnt/windows/[Ww]indows/SoftwareDistribution; do
      if [ -f "${pending}" ] || [ -d "${pending}" ]; then
        echo "Pending updates or deployment detected: ${pending}" >> "${REPORT}"
      fi
    done
  fi
  
  echo "" >> "${REPORT}"
  echo "Windows partition usage:" >> "${REPORT}"
  df -h /mnt/windows >> "${REPORT}"
fi

echo "" >> "${REPORT}"
echo "=== Report saved to ${REPORT} ==="
cat "${REPORT}"
