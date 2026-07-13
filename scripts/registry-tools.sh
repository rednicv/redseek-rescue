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
fi

SYSTEM_HIVE=$(find_ci "$MOUNT_BASE" "Windows/System32/config/SYSTEM")
if [ -z "$SYSTEM_HIVE" ]; then
    log_error "Fișierul de registry SYSTEM nu a fost găsit."
    exit 1
fi


# Verificare tranzacții de registru pendinte (fișiere .LOG)
# Dacă Windows a crash-uit cu tranzacții neaplicate, hivex scrie în hive-ul
# vechi, iar la repornire Windows face rollback — corupând modificările.
# Verificăm atât uppercase cât și lowercase (NTFS case-insensitive)
HIVE_DIR=$(dirname "$SYSTEM_HIVE")
HIVE_NAME=$(basename "$SYSTEM_HIVE")
PENDING_TX=false
PENDING_FILES=""
for ext in .LOG .LOG1 .LOG2 .log .log1 .log2; do
    logfile="${HIVE_DIR}/${HIVE_NAME}${ext}"
    if [ -f "$logfile" ] && [ -s "$logfile" ] && [ "$logfile" -nt "$SYSTEM_HIVE" ]; then
        log_warn "Tranzacție de registru pendinte: ${logfile} (mai nou decât hive-ul)"
        PENDING_TX=true
        PENDING_FILES="${PENDING_FILES} $(basename "$logfile")"
    fi
done

if $PENDING_TX && ! $FORCE_MODE; then
    log_error "REGISTRUL ARE TRANZACȚII NEAPLICATE:${PENDING_FILES}"
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

if $PENDING_TX && $FORCE_MODE; then
    log_warn "ATENȚIE: Jurnale active detectate (${PENDING_FILES## }) — se modifică forțat."
fi

log_info "Bypass Fast Startup în registrul offline..."
python3 - "$SYSTEM_HIVE" <<'PYEOF'
import sys
import hivex

hive_path = sys.argv[1]

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
                h.node_set_value(power, {'key': 'HiberbootEnabled', 'type': 4, 'value': b'\x00\x00\x00\x00'})
                h.commit(None)
                print('[✓] HiberbootEnabled setat pe 0 offline.')
            else:
                print('[!] Cheia Power nu a fost găsită.', file=sys.stderr)
                sys.exit(1)
PYEOF
if [ $? -ne 0 ]; then
    log_error "Eroare la modificarea hivex."
fi

