#!/usr/bin/env bash
# download-antivirus.sh — Download portable antivirus + run via Wine
# Totul din USB, fără să bootezi Windows
set -e

LOGS_DIR="/opt/rescue/logs"
TOOLS_DIR="/opt/rescue/portable-av"
mkdir -p "${TOOLS_DIR}" "${LOGS_DIR}"

echo "=== Portable Antivirus Tools (run via Wine from USB) ===" | tee "${LOGS_DIR}/antivirus-download.log"
echo "" | tee -a "${LOGS_DIR}/antivirus-download.log"

# 1. MalwareBytes AdWCleaner
echo "[1/3] MalwareBytes AdwCleaner (portable)..." | tee -a "${LOGS_DIR}/antivirus-download.log"
if curl -sL -o "${TOOLS_DIR}/adwcleaner.exe" \
  "https://downloads.malwarebytes.com/file/adwcleaner" 2>/dev/null; then
  echo "  ✅ AdwCleaner: $(stat -c%s "${TOOLS_DIR}/adwcleaner.exe" 2>/dev/null || echo 0) bytes" | tee -a "${LOGS_DIR}/antivirus-download.log"
  echo "  Run: wine ${TOOLS_DIR}/adwcleaner.exe" | tee -a "${LOGS_DIR}/antivirus-download.log"
else
  echo "  ⚠️  Download eșuat (fără net?)" | tee -a "${LOGS_DIR}/antivirus-download.log"
fi

# 2. KVRT (Kaspersky Virus Removal Tool)
echo "[2/3] Kaspersky Virus Removal Tool..." | tee -a "${LOGS_DIR}/antivirus-download.log"
if curl -sL -o "${TOOLS_DIR}/kvrt.exe" \
  "https://devbuilds.s.kaspersky-labs.com/devbuilds/KVRT/latest/full/KVRT.exe" 2>/dev/null; then
  echo "  ✅ KVRT: $(stat -c%s "${TOOLS_DIR}/kvrt.exe" 2>/dev/null || echo 0) bytes" | tee -a "${LOGS_DIR}/antivirus-download.log"
  echo "  Run: wine ${TOOLS_DIR}/kvrt.exe" | tee -a "${LOGS_DIR}/antivirus-download.log"
else
  echo "  ⚠️  Download eșuat" | tee -a "${LOGS_DIR}/antivirus-download.log"
fi

# 3. Emsisoft Emergency Kit
echo "[3/3] Emsisoft Emergency Kit..." | tee -a "${LOGS_DIR}/antivirus-download.log"
if curl -sL -o "${TOOLS_DIR}/eek.exe" \
  "https://dl.emsisoft.com/EmsisoftEmergencyKit.exe" 2>/dev/null; then
  echo "  ✅ Emsisoft: $(stat -c%s "${TOOLS_DIR}/eek.exe" 2>/dev/null || echo 0) bytes" | tee -a "${LOGS_DIR}/antivirus-download.log"
  echo "  Run: wine ${TOOLS_DIR}/eek.exe" | tee -a "${LOGS_DIR}/antivirus-download.log"
else
  echo "  ⚠️  Download eșuat" | tee -a "${LOGS_DIR}/antivirus-download.log"
fi

echo "" | tee -a "${LOGS_DIR}/antivirus-download.log"
echo "=== Gata ===" | tee -a "${LOGS_DIR}/antivirus-download.log"
echo "Rulezi din USB cu: wine /opt/rescue/portable-av/NUME.exe" | tee -a "${LOGS_DIR}/antivirus-download.log"
echo "Scanează direct partiția Windows montată la /mnt/windows/" | tee -a "${LOGS_DIR}/antivirus-download.log"
