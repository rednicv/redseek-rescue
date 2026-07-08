#!/usr/bin/env bash
# RedSeek Rescue - rescue-playbook.sh
# Secvență automată completă: mount → diagnose → check → registry → cleanup → unmount

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

"${SCRIPT_DIR}/mount-windows.sh"
"${SCRIPT_DIR}/diagnose.sh"
"${SCRIPT_DIR}/check-windows.sh"
"${SCRIPT_DIR}/registry-tools.sh"
"${SCRIPT_DIR}/cleanup-updates.sh"
"${SCRIPT_DIR}/unmount-windows.sh"

echo -e "\033[0;32m[✓] Toate etapele din Playbook au fost finalizate defensiv.\033[0m"
