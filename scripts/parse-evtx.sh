#!/usr/bin/env bash
# parse-evtx.sh — Parse Windows Event Log files (.evtx) from Linux
# Uses python-evtx to extract and analyze event logs
set -e

MOUNT="/mnt/windows"
LOGS_DIR="/opt/rescue/logs"
EVTX_DIR="${MOUNT}/Windows/System32/winevt/Logs"
OUTPUT_DIR="${LOGS_DIR}/event-logs"
mkdir -p "${OUTPUT_DIR}" "${LOGS_DIR}"

echo "=== Windows Event Log Parser ===" | tee "${LOGS_DIR}/parse-evtx.log"
echo "Date: $(date)" | tee -a "${LOGS_DIR}/parse-evtx.log"
echo "" | tee -a "${LOGS_DIR}/parse-evtx.log"

if ! mountpoint -q "${MOUNT}"; then
  echo "[!] Windows not mounted." | tee -a "${LOGS_DIR}/parse-evtx.log"
  exit 1
fi

if [ ! -d "${EVTX_DIR}" ]; then
  echo "[!] Event log directory not found: ${EVTX_DIR}" | tee -a "${LOGS_DIR}/parse-evtx.log"
  exit 1
fi

echo "[+] Found event logs in ${EVTX_DIR}" | tee -a "${LOGS_DIR}/parse-evtx.log"

# Check python-evtx
if ! python3 -c "import Evtx" 2>/dev/null; then
  echo "[!] python-evtx not installed. Installing..." | tee -a "${LOGS_DIR}/parse-evtx.log"
  pip install python-evtx 2>/dev/null && echo "    ✅ Installed" || echo "    ❌ Failed to install"
fi

# Parse key event logs: System, Application, Security
for logname in System Application Security; do
  EVTX_FILE="${EVTX_DIR}/${logname}.evtx"
  JSON_OUT="${OUTPUT_DIR}/${logname}.json"
  CSV_OUT="${OUTPUT_DIR}/${logname}-errors.csv"
  
  if [ ! -f "${EVTX_FILE}" ]; then
    echo "[!] ${logname}.evtx not found" | tee -a "${LOGS_DIR}/parse-evtx.log"
    continue
  fi
  
  echo "" | tee -a "${LOGS_DIR}/parse-evtx.log"
  echo "--- ${logname}.evtx ($(stat -c%s "${EVTX_FILE}") bytes) ---" | tee -a "${LOGS_DIR}/parse-evtx.log"
  
  # Extract errors and warnings
  python3 -c "
import json, sys
from Evtx.Evtx import Evtx

evtx_file = '${EVTX_FILE}'
try:
    with Evtx(evtx_file) as log:
        errors = []
        other = []
        count = 0
        for record in log.records():
            count += 1
            xml = record.xml()
            # Simple extraction: check for Error/Warning levels
            if 'Level' in xml and ('2' in xml.split('Level')[1][:5] or '3' in xml.split('Level')[1][:5]) or \
               'Error' in xml or 'Critical' in xml:
                errors.append({'id': count, 'xml': xml[:300]})
            if count > 50000:
                break
        
        print(f'    Total records: {count}')
        print(f'    Errors/Warnings: {len(errors)}')
        
        # Save errors to JSON
        with open('${JSON_OUT}', 'w') as f:
            json.dump(errors[:200], f, indent=2)
        
        # Print last 10 errors
        print('')
        print('    Last 10 errors/warnings:')
        for e in errors[-10:]:
            # Extract event ID and basic info
            xml = e['xml']
            evt_id = '?'
            if '<EventID' in xml:
                evt_id = xml.split('<EventID')[1].split('>')[1].split('<')[0]
            print(f'      Event ID {evt_id} (record {e[\"id\"]})')
            # Try to extract message
            if '<Data' in xml:
                data = xml.split('<Data')[1:]
                for d in data[:3]:
                    val = d.split('>')[1].split('<')[0] if '>' in d else ''
                    if val and len(val) < 80:
                        print(f'        → {val}')
            print('')
except Exception as ex:
    print(f'    Error parsing: {ex}')
" 2>&1 | tee -a "${LOGS_DIR}/parse-evtx.log"
done

echo "" | tee -a "${LOGS_DIR}/parse-evtx.log"
echo "=== Summary ===" | tee -a "${LOGS_DIR}/parse-evtx.log"
echo "JSON output: ${OUTPUT_DIR}/" | tee -a "${LOGS_DIR}/parse-evtx.log"
echo "Errors saved, ready for AI analysis." | tee -a "${LOGS_DIR}/parse-evtx.log"
