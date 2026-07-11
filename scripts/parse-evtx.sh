#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - parse-evtx.sh
# Extrage și parsează loguri .evtx în XML prin python-evtx

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

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
    python3 - "$SYS_EVTX" "${OUT_DIR}/system_critical.xml" <<'PYEOF'
import sys, evtx
evtx_path = sys.argv[1]
out_path = sys.argv[2]
with evtx.Evtx(evtx_path) as log:
    count = 0
    with open(out_path, 'w') as out:
        for record in log.records():
            node = record.lxml()
            if 'EventID' in (node.text or '') or count < 50:
                out.write(record.xml() + '\n')
            count += 1
PYEOF
    true  # nu crapăm dacă parsarea eșuează
    log_success "Loguri salvate în ${OUT_DIR}/system_critical.xml"
else
    log_error "System.evtx lipsă."
fi

# --- Sanitizare date confidențiale înainte de analiză ---
log_info "Se curăță datele sensibile din jurnale..."

# 1. IP-uri reale (exclus versiuni de sistem gen 10.0.19041.546)
#    Folosește Perl PCRE cu lookarounds + validare matematică octet 0-255
perl -pi -e 's/(?<!\d)(?<!\d\.)\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b(?!\.\d)/X.X.X.X/g' "${OUT_DIR}"/* 2>/dev/null || true

# 2. Căi utilizator Windows (C:\Users\Vasile → C:\Users\ANONYMOUS_USER)
sed -i -E 's/([cC]:\\[uU]sers\\)([^\\]+)/\1ANONYMOUS_USER/g' "${OUT_DIR}"/* 2>/dev/null || true

# 3. SID-uri utilizator (S-1-5-21-... → S-1-5-21-ANONYMOUS-SID)
sed -i -E 's/S-1-5-21-[0-9]+-[0-9]+-[0-9]+-[0-9]+/S-1-5-21-ANONYMOUS-SID/g' "${OUT_DIR}"/* 2>/dev/null || true

log_success "Jurnale sanitizate — pregătite pentru analiză."
