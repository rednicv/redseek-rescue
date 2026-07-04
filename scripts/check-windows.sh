#!/usr/bin/env bash
# check-windows.sh — Deep Windows diagnostics from terminal
# Checks Event Log equivalents, boot status, critical files (case-insensitive)

source "$(dirname "$0")/utils.sh"

OUTPUT="${LOGS_DIR}/windows-check.txt"
mkdir -p "${LOGS_DIR}"

echo "=== Windows Deep Check ===" > "${OUTPUT}"
echo "Date: $(date)" >> "${OUTPUT}"
echo "" >> "${OUTPUT}"

verify_mount || exit 1

# Resolve the real Windows/System32 path (case-insensitive)
WIN_DIR=$(find_ci "${MOUNT}" 1 "Windows")
SYS32_DIR=""
if [ -n "${WIN_DIR}" ]; then
    SYS32_DIR=$(find_ci "${WIN_DIR}" 1 "System32")
fi
if [ -z "${SYS32_DIR}" ]; then
    echo "[!] Cannot find Windows/System32 directory (even case-insensitive)." | tee -a "${OUTPUT}"
    exit 1
fi
echo "[+] Resolved System32: ${SYS32_DIR}" >> "${OUTPUT}"

# 1. Boot files
echo "--- Boot Configuration ---" >> "${OUTPUT}"
for f in winload.exe ntoskrnl.exe; do
    FOUND=$(find "${SYS32_DIR}" -maxdepth 1 -iname "${f}" 2>/dev/null | head -n1)
    if [ -n "${FOUND}" ] && [ -f "${FOUND}" ]; then
        echo "${f}: ✅ (${FOUND})" >> "${OUTPUT}"
    else
        echo "${f}: ❌ MISSING" >> "${OUTPUT}"
    fi
done

# 2. Critical system files (check sizes)
echo "" >> "${OUTPUT}"
echo "--- Critical File Sizes ---" >> "${OUTPUT}"
for f in ntoskrnl.exe winload.exe hal.dll kernel32.dll ntdll.dll; do
    FOUND=$(find "${SYS32_DIR}" -maxdepth 1 -iname "${f}" 2>/dev/null | head -n1)
    if [ -n "${FOUND}" ] && [ -f "${FOUND}" ]; then
        SIZE=$(stat -c%s "${FOUND}" 2>/dev/null || echo 0)
        echo "${f}: ${SIZE} bytes" >> "${OUTPUT}"
    else
        echo "${f}: NOT FOUND" >> "${OUTPUT}"
    fi
done

# 3. Check registry hives exist
echo "" >> "${OUTPUT}"
echo "--- Registry Hives ---" >> "${OUTPUT}"
CONFIG_DIR=$(find_ci "${SYS32_DIR}" 1 "config")
if [ -z "${CONFIG_DIR}" ]; then
    echo "[!] Cannot find registry config directory." >> "${OUTPUT}"
else
    for hive in SOFTWARE SYSTEM SAM SECURITY DEFAULT; do
        HIVE_FILE="${CONFIG_DIR}/${hive}"
        if [ -f "${HIVE_FILE}" ]; then
            echo "${hive}: ✅ $(stat -c%s "${HIVE_FILE}") bytes" >> "${OUTPUT}"
        else
            echo "${hive}: ❌ MISSING" >> "${OUTPUT}"
        fi
    done
fi

# 4. Check for known virus patterns in startup
echo "" >> "${OUTPUT}"
echo "--- Autorun Scan (suspicious entries) ---" >> "${OUTPUT}"
for f in "${MOUNT}"/Users/*/AppData/Roaming/Microsoft/Windows/Start\ Menu/Programs/Startup/*; do
    [ -f "${f}" ] || continue
    SUSPICIOUS=$(file "${f}" | grep -iE "powershell|vbs|js|exe" || true)
    if [ -n "${SUSPICIOUS}" ]; then
        echo "⚠️  $(basename "${f}") (in $(dirname "${f}"))" >> "${OUTPUT}"
        echo "   ${SUSPICIOUS}" >> "${OUTPUT}"
    fi
done

# 5. Minidumps — case-insensitive
echo "" >> "${OUTPUT}"
echo "--- BSOD Minidumps ---" >> "${OUTPUT}"
DUMP_DIR=$(find_ci "${WIN_DIR}" 1 "Minidump")
if [ -n "${DUMP_DIR}" ] && [ -d "${DUMP_DIR}" ]; then
    DUMPS=("${DUMP_DIR}"/*.dmp)
    if [ -f "${DUMPS[0]}" ]; then
        echo "${#DUMPS[@]} dump file(s) found:" >> "${OUTPUT}"
        ls -lh "${DUMP_DIR}"/*.dmp 2>/dev/null >> "${OUTPUT}"
    else
        echo "No minidumps." >> "${OUTPUT}"
    fi
else
    echo "Minidump directory not found." >> "${OUTPUT}"
fi

# 6. Disk corruption check hint
echo "" >> "${OUTPUT}"
echo "--- Next steps ---" >> "${OUTPUT}"
echo "Run chkdsk: ntfsfix -d ${MOUNT}  OR  chkdsk C: /f from Windows recovery" >> "${OUTPUT}"
echo "Check SFC: sfc /scannow from Windows recovery" >> "${OUTPUT}"
echo "For BSOD analysis, run 'clr-dump' or a similar tool on the latest .dmp file" >> "${OUTPUT}"
echo "" >> "${OUTPUT}"
echo "=== Report saved to ${OUTPUT} ==="
cat "${OUTPUT}"
