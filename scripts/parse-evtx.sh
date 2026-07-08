#!/usr/bin/env bash
# Copyright (c) 2026 rednicv
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - parse-evtx.sh
# Extrage și parsează loguri .evtx în XML prin python-evtx

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

MOUNT_BASE="/mnt/windows"
SYSTEM_LOGS=$(find_ci "$MOUNT_BASE" "Windows/System32/winevt/Logs")

if [ -z "$SYSTEM_LOGS" ] || [ ! -d "$SYSTEM_LOGS" ]; then
    log_error "Directorul de loguri Windows nu a fost găsit."
    exit 1
fi

OUT_DIR="/tmp/parsed_logs"
mkdir -p "$OUT_DIR"

log_info "Se extrag evenimentele critice de sistem (System.evtx)..."
SYS_EVTX="${SYSTEM_LOGS}/System.evtx"

if [ -f "$SYS_EVTX" ]; then
    python3 -c "
import evtx
with evtx.Evtx('$SYS_EVTX') as log:
    count = 0
    for record in log.records():
        node = record.lxml()
        if 'EventID' in (node.text or '') or count < 50:
            print(record.xml())
        count += 1
" > "${OUT_DIR}/system_critical.xml" 2>/dev/null || true
    log_success "Loguri salvate în ${OUT_DIR}/system_critical.xml"
else
    log_error "System.evtx lipsă."
fi
