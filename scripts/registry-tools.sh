#!/usr/bin/env bash
# registry-tools.sh — Windows registry manipulation via python3-hivex
# Read, backup, edit offline registry hives from Linux
set -e

MOUNT="/mnt/windows"
LOGS_DIR="/opt/rescue/logs"
BACKUP_DIR="/opt/rescue/registry-backup"
REG_DIR="${MOUNT}/Windows/System32/config"
mkdir -p "${LOGS_DIR}" "${BACKUP_DIR}"

REG_HIVES="SYSTEM SOFTWARE SAM SECURITY DEFAULT"

echo "=== Registry Tools ===" | tee "${LOGS_DIR}/registry-tools.log"
echo "Date: $(date)" | tee -a "${LOGS_DIR}/registry-tools.log"
echo "" | tee -a "${LOGS_DIR}/registry-tools.log"

if ! mountpoint -q "${MOUNT}"; then
  echo "[!] Windows not mounted. Run mount-windows.sh first." | tee -a "${LOGS_DIR}/registry-tools.log"
  exit 1
fi

# Check hivex is available
if ! python3 -c "import hivex" 2>/dev/null; then
  echo "[!] python3-hivex not installed." | tee -a "${LOGS_DIR}/registry-tools.log"
  echo "    Install: pip install python-hivex" | tee -a "${LOGS_DIR}/registry-tools.log"
  echo "    Falling back to chntpw..." | tee -a "${LOGS_DIR}/registry-tools.log"
fi

usage() {
  echo "Usage:"
  echo "  ./registry-tools.sh backup           — Backup all registry hives"
  echo "  ./registry-tools.sh list-services    — List all services (from SYSTEM)"
  echo "  ./registry-tools.sh disable SERVICE  — Disable a service by name"
  echo "  ./registry-tools.sh enable SERVICE   — Enable a service by name"
  echo "  ./registry-tools.sh info HIVE        — Show info about a hive file"
  echo "  ./registry-tools.sh restore          — Restore from backup"
  echo ""
  echo "Backup location: ${BACKUP_DIR}"
}

backup_hives() {
  echo "[+] Backing up registry hives..." | tee -a "${LOGS_DIR}/registry-tools.log"
  for hive in ${REG_HIVES}; do
    SRC="${REG_DIR}/${hive}"
    if [ -f "${SRC}" ]; then
      cp "${SRC}" "${BACKUP_DIR}/${hive}.bak"
      echo "    ✅ ${hive} ($(stat -c%s "${SRC}") bytes)" | tee -a "${LOGS_DIR}/registry-tools.log"
    fi
  done
  echo "    Backup location: ${BACKUP_DIR}" | tee -a "${LOGS_DIR}/registry-tools.log"
}

restore_hives() {
  echo "[+] Restoring registry hives from backup..." | tee -a "${LOGS_DIR}/registry-tools.log"
  for hive in ${REG_HIVES}; do
    BAK="${BACKUP_DIR}/${hive}.bak"
    if [ -f "${BAK}" ]; then
      cp "${BAK}" "${REG_DIR}/${hive}"
      echo "    ✅ ${hive} restored" | tee -a "${LOGS_DIR}/registry-tools.log"
    fi
  done
}

disable_service() {
  SERVICE_NAME="$1"
  if [ -z "${SERVICE_NAME}" ]; then
    echo "[!] Specify service name to disable." | tee -a "${LOGS_DIR}/registry-tools.log"
    exit 1
  fi
  
  echo "[+] Disabling service: ${SERVICE_NAME}" | tee -a "${LOGS_DIR}/registry-tools.log"
  python3 -c "
import hivex, sys, os

hive_path = '${REG_DIR}/SYSTEM'
svc_name = '${SERVICE_NAME}'.lower()

if not os.path.exists(hive_path):
    print('[!] SYSTEM hive not found at', hive_path)
    sys.exit(1)

h = hivex.Hivex(hive_path, write=True)
# Navigate to CurrentControlSet\Services\SERVICE_NAME
current = h.root()
for key in ['Select']:
    for node in h.node_children(current):
        if h.node_name(node) == key:
            current = node
            break

# Get Current value
current_val = None
for val in h.node_values(current):
    if h.value_key(val) == 'Current':
        current_val = int.from_bytes(h.value_value(val)[1], 'little')
        break

if current_val is None:
    print('[!] Could not determine CurrentControlSet')
    sys.exit(1)

control_set = 'ControlSet{:03d}'.format(current_val)
print('[+] Using', control_set)

# Navigate to Services
current = h.root()
for key in [control_set, 'Services', svc_name]:
    found = False
    for node in h.node_children(current):
        if h.node_name(node).lower() == key:
            current = node
            found = True
            break
    if not found:
        print('[!] Service', svc_name, 'not found')
        sys.exit(1)

# Set Start to 4 (Disabled)
for val in h.node_values(current):
    if h.value_key(val) == 'Start':
        old_val = int.from_bytes(h.value_value(val)[1], 'little')
        h.node_set_value(current, hivex.HivexValue(label='Start', 
                           value=(old_val, 4).to_bytes(4, 'little')))
        print('[✅] Service', svc_name, 'disabled (Start:', old_val, '→ 4)')
        break

h.commit(None)
" 2>&1 | tee -a "${LOGS_DIR}/registry-tools.log"
}

enable_service() {
  SERVICE_NAME="$1"
  if [ -z "${SERVICE_NAME}" ]; then
    echo "[!] Specify service name to enable." | tee -a "${LOGS_DIR}/registry-tools.log"
    exit 1
  fi
  
  echo "[+] Enabling service: ${SERVICE_NAME}" | tee -a "${LOGS_DIR}/registry-tools.log}"
  python3 -c "
import hivex, sys, os

hive_path = '${REG_DIR}/SYSTEM'
svc_name = '${SERVICE_NAME}'.lower()

if not os.path.exists(hive_path):
    print('[!] SYSTEM hive not found')
    sys.exit(1)

h = hivex.Hivex(hive_path, write=True)
current = h.root()

# Get Current value
current_val = None
for val in h.node_values(current):
    if h.value_key(val) == 'Current':
        current_val = int.from_bytes(h.value_value(val)[1], 'little')
        break

control_set = 'ControlSet{:03d}'.format(current_val)

# Navigate to service
current = h.root()
for key in [control_set, 'Services', svc_name]:
    found = False
    for node in h.node_children(current):
        if h.node_name(node).lower() == key:
            current = node
            found = True
            break
    if not found:
        print('[!] Service', svc_name, 'not found')
        sys.exit(1)

# Set Start to 2 (Automatic) or 3 (Manual)
for val in h.node_values(current):
    if h.value_key(val) == 'Start':
        old_val = int.from_bytes(h.value_value(val)[1], 'little')
        new_val = 2 if old_val == 4 else old_val  # Only enable if disabled
        if old_val == 4:
            h.node_set_value(current, hivex.HivexValue(label='Start',
                               value=(new_val).to_bytes(4, 'little')))
            print('[✅] Service', svc_name, 'enabled (Start:', old_val, '→', new_val, ')')
        else:
            print('[i] Service', svc_name, 'already enabled (Start:', old_val, ')')
        break

h.commit(None)
" 2>&1 | tee -a "${LOGS_DIR}/registry-tools.log"
}

list_services() {
  echo "[+] Listing all Windows services..." | tee -a "${LOGS_DIR}/registry-tools.log}"
  python3 -c "
import hivex, os

hive_path = '${REG_DIR}/SYSTEM'

h = hivex.Hivex(hive_path)
current = h.root()

# Get Current control set
current_val = None
for val in h.node_values(current):
    if h.value_key(val) == 'Current':
        current_val = int.from_bytes(h.value_value(val)[1], 'little')
        break

control_set = 'ControlSet{:03d}'.format(current_val)

# Navigate to Services
current = h.root()
for key in [control_set, 'Services']:
    for node in h.node_children(current):
        if h.node_name(node) == key:
            current = node
            break

services = []
for node in h.node_children(current):
    name = h.node_name(node)
    start_val = 3  # default manual
    for val in h.node_values(node):
        if h.value_key(val) == 'Start':
            start_val = int.from_bytes(h.value_value(val)[1], 'little')
            break
    
    start_names = {0: 'BOOT', 1: 'SYSTEM', 2: 'AUTO', 3: 'MANUAL', 4: 'DISABLED'}
    services.append((start_val, name, start_names.get(start_val, str(start_val))))

# Sort by start type
services.sort()
for s in services:
    print(f'  [{s[2]:7}] {s[1]}')
" 2>&1 | tee -a "${LOGS_DIR}/registry-tools.log"
}

info_hive() {
  HIVE_NAME="$1"
  HIVE_PATH="${REG_DIR}/${HIVE_NAME}"
  
  if [ ! -f "${HIVE_PATH}" ]; then
    echo "[!] Hive ${HIVE_NAME} not found at ${HIVE_PATH}" | tee -a "${LOGS_DIR}/registry-tools.log"
    echo "    Available: ${REG_HIVES}" | tee -a "${LOGS_DIR}/registry-tools.log"
    exit 1
  fi
  
  echo "[+] Hive: ${HIVE_NAME} ($(stat -c%s "${HIVE_PATH}") bytes)" | tee -a "${LOGS_DIR}/registry-tools.log"
  python3 -c "
import hivex
h = hivex.Hivex('${HIVE_PATH}')
root = h.root()
count = 0
def count_nodes(node):
    global count
    count += 1
    for child in h.node_children(node):
        count_nodes(child)
count_nodes(root)
print(f'    Total keys: {count}')
" 2>&1 | tee -a "${LOGS_DIR}/registry-tools.log"
}

# === MAIN ===
case "${1:-help}" in
  backup)
    backup_hives
    ;;
  restore)
    restore_hives
    ;;
  disable)
    disable_service "$2"
    ;;
  enable)
    enable_service "$2"
    ;;
  list-services)
    list_services
    ;;
  info)
    info_hive "$2"
    ;;
  *)
    usage
    ;;
esac
