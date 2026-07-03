#!/usr/bin/env bash
# check-windows.sh — Deep Windows diagnostics from terminal
# Checks Event Log equivalents, boot status, critical files

MOUNT="/mnt/windows"
LOGS_DIR="/opt/rescue/logs"
OUTPUT="${LOGS_DIR}/windows-check.txt"

echo "=== Windows Deep Check ===" > "${OUTPUT}"
echo "Date: $(date)" >> "${OUTPUT}"
echo "" >> "${OUTPUT}"

if ! mountpoint -q "${MOUNT}"; then
  echo "[!] Windows not mounted." | tee -a "${OUTPUT}"
  exit 1
fi

# 1. Boot files
echo "--- Boot Configuration ---" >> "${OUTPUT}"
[ -f "${MOUNT}/Windows/System32/winload.exe" ] && echo "winload.exe: ✅" >> "${OUTPUT}" || echo "winload.exe: ❌ MISSING" >> "${OUTPUT}"
[ -f "${MOUNT}/Windows/System32/ntoskrnl.exe" ] && echo "ntoskrnl.exe: ✅" >> "${OUTPUT}" || echo "ntoskrnl.exe: ❌ MISSING" >> "${OUTPUT}"

# 2. Critical system files (check sizes)
echo "" >> "${OUTPUT}"
echo "--- Critical File Sizes ---" >> "${OUTPUT}"
for f in ntoskrnl.exe winload.exe hal.dll kernel32.dll ntdll.dll; do
  FILE="${MOUNT}/Windows/System32/${f}"
  if [ -f "${FILE}" ]; then
    SIZE=$(stat -c%s "${FILE}" 2>/dev/null || echo 0)
    echo "${f}: ${SIZE} bytes" >> "${OUTPUT}"
  else
    echo "${f}: NOT FOUND" >> "${OUTPUT}"
  fi
done

# 3. Check registry hives exist
echo "" >> "${OUTPUT}"
echo "--- Registry Hives ---" >> "${OUTPUT}"
for hive in SOFTWARE SYSTEM SAM SECURITY DEFAULT; do
  HIVE_FILE="${MOUNT}/Windows/System32/config/${hive}"
  if [ -f "${HIVE_FILE}" ]; then
    echo "${hive}: ✅ $(stat -c%s "${HIVE_FILE}") bytes" >> "${OUTPUT}"
  else
    echo "${hive}: ❌ MISSING" >> "${OUTPUT}"
  fi
done

# 4. Check for known virus patterns in startup
echo "" >> "${OUTPUT}"
echo "--- Autorun Scan (suspicious entries) ---" >> "${OUTPUT}"
STARTUP_DIR="${MOUNT}/Users/*/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup"
for f in ${STARTUP_DIR}/*; do
  [ -f "${f}" ] || continue
  SUSPICIOUS=$(file "${f}" | grep -iE "powershell|vbs|js|exe" || true)
  if [ -n "${SUSPICIOUS}" ]; then
    echo "⚠️  ${f}" >> "${OUTPUT}"
    echo "   ${SUSPICIOUS}" >> "${OUTPUT}"
  fi
done

# 5. Minidumps
echo "" >> "${OUTPUT}"
echo "--- BSOD Minidumps ---" >> "${OUTPUT}"
DUMP_DIR="${MOUNT}/Windows/minidump"
if [ -d "${DUMP_DIR}" ]; then
  DUMP_COUNT=$(ls "${DUMP_DIR}"/*.dmp 2>/dev/null | wc -l)
  if [ "${DUMP_COUNT}" -gt 0 ]; then
    echo "${DUMP_COUNT} dump file(s) found:" >> "${OUTPUT}"
    ls -lh "${DUMP_DIR}"/*.dmp 2>/dev/null >> "${OUTPUT}"
  else
    echo "No minidumps." >> "${OUTPUT}"
  fi
fi

# 6. Disk corruption check hint
echo "" >> "${OUTPUT}"
echo "--- Next steps ---" >> "${OUTPUT}"
echo "Run chkdsk: ntfsfix -d ${MOUNT}  OR  chkdsk C: /f from Windows recovery" >> "${OUTPUT}"
echo "Check SFC: sfc /scannow from Windows recovery" >> "${OUTPUT}"
echo "For BSOD analysis, ask Hermes about the latest .dmp file" >> "${OUTPUT}"
echo "" >> "${OUTPUT}"
echo "=== Report saved to ${OUTPUT} ==="
cat "${OUTPUT}"
