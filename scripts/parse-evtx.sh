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

# Check and install python-evtx safely
if ! python3 -c "import Evtx" 2>/dev/null; then
  echo "[!] python-evtx not installed. Attempting installation..." | tee -a "${LOGS_DIR}/parse-evtx.log"
  pip install python-evtx --break-system-packages 2>/dev/null && echo "    ✅ Installed" || echo "    ❌ Failed to install (check internet or pip availability)"
fi

# Parse key event logs: System, Application, Security
for logname in System Application Security; do
  EVTX_FILE="${EVTX_DIR}/${logname}.evtx"
  JSON_OUT="${OUTPUT_DIR}/${logname}.json"
  
  if [ ! -f "${EVTX_FILE}" ]; then
    echo "[!] ${logname}.evtx not found" | tee -a "${LOGS_DIR}/parse-evtx.log"
    continue
  fi
  
  echo "" | tee -a "${LOGS_DIR}/parse-evtx.log"
  echo "--- ${logname}.evtx ($(stat -c%s "${EVTX_FILE}") bytes) ---" | tee -a "${LOGS_DIR}/parse-evtx.log"
  
  # Extract errors and warnings safely via inline python
  python3 -c "
import json
import sys
import re
from Evtx.Evtx import Evtx

evtx_file = '${EVTX_FILE}'
try:
    with Evtx(evtx_file) as log:
        errors = []
        count = 0
        
        for record in log.records():
            count += 1
            xml = record.xml()
            
            # Regex — works on FULL XML, not truncated
            level_match = re.search(r'<Level>([123])</Level>', xml)
            is_error_str = 'Error' in xml or 'Critical' in xml
            
            if level_match or is_error_str:
                # Pull EventID from the complete XML string
                evt_id_match = re.search(r'<EventID.*?>(.*?)</EventID>', xml)
                evt_id = evt_id_match.group(1) if evt_id_match else '?'
                
                # Gather up to 3 context data points
                data_points = re.findall(r'<Data.*?>(.*?)</Data>', xml)[:3]
                cleaned_data = [d.strip() for d in data_points if len(d.strip()) < 80]
                
                errors.append({
                    'id': count,
                    'event_id': evt_id,
                    'data': cleaned_data,
                    'snippet': xml[:400].replace('\n', ' ').strip()
                })
                
            if count > 50000:  # Circuit breaker
                break
        
        print(f'    Total records scanned: {count}')
        print(f'    Errors/Warnings found: {len(errors)}')
        
        # Save to JSON
        with open('${JSON_OUT}', 'w') as f:
            json.dump(errors, f, indent=2)
            
        # Display last 10 errors
        if errors:
            print('\n    Last 10 errors/warnings:')
            for e in errors[-10:]:
                print(f'      Event ID {e[\"event_id\"]} (record {e[\"id\"]})')
                for d in e['data']:
                    print(f'        -> {d}')
                print('')
except Exception as ex:
    print(f'    Error parsing: {ex}')
" 2>&1 | tee -a "${LOGS_DIR}/parse-evtx.log"
done

echo "" | tee -a "${LOGS_DIR}/parse-evtx.log"
echo "=== Summary ===" | tee -a "${LOGS_DIR}/parse-evtx.log"
echo "JSON outputs saved to: ${OUTPUT_DIR}/" | tee -a "${LOGS_DIR}/parse-evtx.log"
echo "Analysis completely finished." | tee -a "${LOGS_DIR}/parse-evtx.log"
