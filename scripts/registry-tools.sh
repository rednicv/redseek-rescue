#!/usr/bin/env bash
# Copyright (c) 2026 rednicv
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - registry-tools.sh
# Dezactivează Fast Startup (Hiberboot) offline prin hivex

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root
require_snapshot

MOUNT_BASE="/mnt/windows"
SYSTEM_HIVE=$(find_ci "$MOUNT_BASE" "Windows/System32/config/SYSTEM")

if [ -z "$SYSTEM_HIVE" ] || [ ! -f "$SYSTEM_HIVE" ]; then
    log_error "Fișierul de registru SYSTEM nu a fost găsit."
    exit 1
fi

log_info "Bypass Fast Startup în registrul offline..."
python3 -c "
import hivex
h = hivex.Hivex('$SYSTEM_HIVE', write=True)
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
