#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - rescue-playbook.sh
# Secvență automată completă: mount → diagnose → check → registry → cleanup → unmount
# --offline: mod fără AI, cu raport JSON și sumar în TTY

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

OFFLINE_MODE=false
if [ "${1:-}" = "--offline" ]; then
    OFFLINE_MODE=true
fi

REPORT_FILE="/tmp/redseek_offline_report.json"
RESULTS=""

# Wrapper care rulează un script și adună rezultatul
run_step() {
    local name="$1"
    local script="$2"
    shift 2

    log_info "▶ $name..."
    set +e
    output=$("${SCRIPT_DIR}/${script}" "$@" 2>&1)
    local rc=$?
    set -e

    if [ $rc -eq 0 ]; then
        log_success "$name — reușit"
        RESULTS="${RESULTS}\n  ✅ $name"
    else
        log_warn "$name — atenție (cod $rc)"
        RESULTS="${RESULTS}\n  ⚠️  $name — exit $rc"
    fi

    echo "$output"
}

if $OFFLINE_MODE; then
    echo ""
    echo "╔═══════════════════════════════════════════╗"
    echo "║   RedSeek Rescue — Mod Offline           ║"
    echo "║   Reparare automată fără AI              ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""

    run_step "Montare partiție Windows" "mount-windows.sh"
    run_step "Diagnoză SMART + sistem"  "diagnose.sh"
    run_step "Verificare integritate"   "check-windows.sh"
    run_step "Dezactivare Fast Startup" "registry-tools.sh"
    run_step "Curățare actualizări"     "cleanup-updates.sh"
    run_step "Demontare sigură"         "unmount-windows.sh"

    # Generează raport JSON
    cat > "$REPORT_FILE" << JSONEOF
{
    "tool": "RedSeek Rescue",
    "version": "1.5.0",
    "mode": "offline",
    "timestamp": "$(date -Iseconds)",
    "results": $(echo -e "$RESULTS" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))" 2>/dev/null || echo '"completat"')
}
JSONEOF

    echo ""
    echo "╔═══════════════════════════════════════════╗"
    echo "║   Rezumat Operațiuni                     ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "$RESULTS" | while IFS= read -r line; do
        [ -n "$line" ] && echo " $line"
    done
    echo ""
    echo -e "${GREEN}[✓] Raport salvat: ${REPORT_FILE}${NC}"
    echo ""
    echo " Pentru reparații avansate, reconectează la internet și rulează:"
    echo "   hermes"
    echo ""
else
    # Mod normal — secvență cu AI
    "${SCRIPT_DIR}/mount-windows.sh"
    "${SCRIPT_DIR}/diagnose.sh"
    "${SCRIPT_DIR}/check-windows.sh"
    "${SCRIPT_DIR}/registry-tools.sh"
    "${SCRIPT_DIR}/cleanup-updates.sh"
    "${SCRIPT_DIR}/unmount-windows.sh"

    echo -e "${GREEN}[✓] Toate etapele din Playbook au fost finalizate defensiv.${NC}"
fi
