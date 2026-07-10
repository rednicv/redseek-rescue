#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - registry-tools.sh
# Dezactivează Fast Startup (Hiberboot) offline prin hivex

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root
require_snapshot

FORCE_MODE=false
if [ "${1:-}" = "--force" ]; then
    FORCE_MODE=true
    log_warn "FORȚAT: Se sare peste verificările de siguranță."
fi

MOUNT_BASE="/mnt/windows"
SYSTEM_HIVE=$(find_ci "$MOUNT_BASE" "Windows/System32/config/SYSTEM")

if [ -z "$SYSTEM_HIVE" ] || [ ! -f "$SYSTEM_HIVE" ]; then
    log_error "Fișierul de registru SYSTEM nu a fost găsit."
    exit 1
fi

# Verificare tranzacții de registru pendinte (fișiere .LOG)
# Dacă Windows a crash-uit cu tranzacții neaplicate, hivex scrie în hive-ul
# vechi, iar la repornire Windows face rollback — corupând modificările.
HIVE_DIR=$(dirname "$SYSTEM_HIVE")
HIVE_NAME=$(basename "$SYSTEM_HIVE")
PENDING_TX=false
for logfile in "${HIVE_DIR}/${HIVE_NAME}.LOG" "${HIVE_DIR}/${HIVE_NAME}.LOG1" "${HIVE_DIR}/${HIVE_NAME}.LOG2"; do
    if [ -f "$logfile" ] && [ "$logfile" -nt "$SYSTEM_HIVE" ]; then
        log_warn "Tranzacție de registru pendinte: ${logfile} (mai nou decât hive-ul)"
        PENDING_TX=true
    fi
done

if $PENDING_TX && ! $FORCE_MODE; then
    log_error "REGISTRUL ARE TRANZACȚII NEAPLICATE."
    log_error "Modificarea acum cu hivex va corupe stupul de regiștri."
    log_error ""
    log_error "Pași recomandați:"
    log_error "  1. Repornește în Windows și lasă-l să finalizeze tranzacțiile"
    log_error "  2. Sau rulează 'chkdsk /f' din recovery environment"
    log_error "  3. Apoi revino în RedSeek Rescue și reîncearcă"
    log_error ""
    log_error "Dacă înțelegi riscul, poți forța cu: registry-tools.sh --force"
    exit 2
fi

log_info "Bypass Fast Startup în registrul offline..."
export FORCE_MODE
python3 -c "
import os
import sys
import hivex

hive_path = '$SYSTEM_HIVE'
force_mode = os.environ.get('FORCE_MODE', 'false').lower() == 'true'

# --- Verificare tranzacții pendinte (dirty hive) ---
# Windows folosește .LOG, .LOG1, .LOG2 (uppercase și lowercase pe NTFS)
log_extensions = ['.LOG', '.LOG1', '.LOG2', '.log', '.log1', '.log2']
active_logs = []
for ext in log_extensions:
    log_file = hive_path + ext
    if os.path.exists(log_file) and os.path.getsize(log_file) > 0:
        active_logs.append(os.path.basename(log_file))

if active_logs:
    if not force_mode:
        print(f'  ERROR [RedSeek]: Stupul de registru ({os.path.basename(hive_path)}) este DIRTY!', file=sys.stderr)
        print(f'Fișiere jurnal active detectate: {active_logs}', file=sys.stderr)
        print('Modificarea directă cu hivex va corupe regiștrii Windows.', file=sys.stderr)
        print('Dacă vrei să riști, rulează scriptul cu --force.', file=sys.stderr)
        sys.exit(2)
    else:
        print(f'  ATENȚIE: {len(active_logs)} jurnale active — se modifică forțat ({", ".join(active_logs)})', file=sys.stderr)

h = hivex.Hivex(hive_path, write=True)
key = h.root()
control_set = h.node_get_child(key, 'ControlSet001')
if control_set:
    control = h.node_get_child(control_set, 'Control')
    if control:
        session_mgr = h.node_get_child(control, 'Session Manager')
        if session_mgr:
            power = h.node_get_child(session_mgr, 'Power')
            if power:
                val = h.node_get_value(power, 'HiberbootEnabled')
                h.node_set_value(power, {'key': 'HiberbootEnabled', 'type': 4, 'value': b'\\x00\\x00\\x00\\x00'})
                h.commit(None)
                print('[✓] HiberbootEnabled setat pe 0 offline.')
" || log_error "Eroare la modificarea hivex."
