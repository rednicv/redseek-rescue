#!/usr/bin/env bash
# verify-files.sh — Verify Windows system file signatures offline
# Checks if critical system files are tampered with (malware often replaces them)
set -e

MOUNT="/mnt/windows"
LOGS_DIR="/opt/rescue/logs"
OUTPUT="${LOGS_DIR}/file-verify.txt"

echo "=== Windows File Integrity Check ===" | tee "${OUTPUT}"
echo "Date: $(date)" | tee -a "${OUTPUT}"
echo "" | tee -a "${OUTPUT}"

if ! mountpoint -q "${MOUNT}"; then
  echo "[!] Windows not mounted." | tee -a "${OUTPUT}"
  exit 1
fi

# Critical files to check
CRITICAL_FILES=(
  "/Windows/System32/ntoskrnl.exe"
  "/Windows/System32/winload.exe"
  "/Windows/System32/winload.efi"
  "/Windows/System32/hal.dll"
  "/Windows/System32/kernel32.dll"
  "/Windows/System32/ntdll.dll"
  "/Windows/System32/user32.dll"
  "/Windows/System32/gdi32.dll"
  "/Windows/System32/cmd.exe"
  "/Windows/System32/taskmgr.exe"
  "/Windows/System32/regedit.exe"
  "/Windows/System32/rundll32.exe"
  "/Windows/System32/services.exe"
  "/Windows/System32/svchost.exe"
  "/Windows/System32/explorer.exe"
)

echo "--- Checking critical system files ---" | tee -a "${OUTPUT}"
echo "" | tee -a "${OUTPUT}"

for relpath in "${CRITICAL_FILES[@]}"; do
  FULL_PATH="${MOUNT}${relpath}"
  if [ ! -f "${FULL_PATH}" ]; then
    echo "[❌] MISSING: ${relpath}" | tee -a "${OUTPUT}"
    continue
  fi
  
  SIZE=$(stat -c%s "${FULL_PATH}" 2>/dev/null || echo 0)
  HASH=$(sha256sum "${FULL_PATH}" | cut -d' ' -f1)
  
  # Try signature verification via osslsigncode
  if command -v osslsigncode &>/dev/null; then
    SIGN_INFO=$(osslsigncode verify -in "${FULL_PATH}" 2>&1 | grep -E "Subject|Issuer|Serial|Verified|error" | head -5 || true)
    if echo "${SIGN_INFO}" | grep -q "Microsoft"; then
      echo "[✅] ${relpath} — ${SIZE} bytes — signed by Microsoft" | tee -a "${OUTPUT}"
    elif echo "${SIGN_INFO}" | grep -q "Verified"; then
      echo "[⚠️] ${relpath} — ${SIZE} bytes — signed (not Microsoft?)" | tee -a "${OUTPUT}"
    else
      echo "[⚠️] ${relpath} — ${SIZE} bytes — unsigned or cannot verify" | tee -a "${OUTPUT}"
      echo "      ${SIGN_INFO}" | tee -a "${OUTPUT}"
    fi
  else
    # Fallback: just show hash
    echo "[i] ${relpath} — ${SIZE} bytes — SHA256: ${HASH:0:16}..." | tee -a "${OUTPUT}"
  fi
done

echo "" | tee -a "${OUTPUT}"
echo "--- Suspicious files in system32 (not Microsoft signed) ---" | tee -a "${OUTPUT}"
SYSTEM32="${MOUNT}/Windows/System32"
# Find recently modified .exe and .dll files in system32 (excluding subdirs)
if command -v osslsigncode &>/dev/null; then
  find "${SYSTEM32}" -maxdepth 1 -name "*.exe" -newer "${SYSTEM32}/ntoskrnl.exe" -mtime -30 2>/dev/null | head -20 | while read f; do
    FNAME=$(basename "${f}")
    SIGN_INFO=$(osslsigncode verify -in "${f}" 2>&1 | grep -E "Subject|error" | head -3 || true)
    if ! echo "${SIGN_INFO}" | grep -q "Microsoft"; then
      echo "[⚠️] New/unsigned: ${FNAME} (modified within 30 days)" | tee -a "${OUTPUT}"
      echo "      ${SIGN_INFO}" | tee -a "${OUTPUT}"
    fi
  done
fi

echo "" | tee -a "${OUTPUT}"
echo "=== Check complete ===" | tee -a "${OUTPUT}"
echo "Check: ${OUTPUT}" | tee -a "${OUTPUT}"
