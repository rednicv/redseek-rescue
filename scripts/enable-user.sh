#!/usr/bin/env bash
# RedSeek Rescue - enable-user.sh
# Activează un cont de utilizator Windows dezactivat

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

if [ $# -lt 1 ]; then
    log_error "Specifică numele utilizatorului: enable-user.sh USERNAME"
    exit 1
fi

USERNAME="$1"
MOUNT_BASE="/mnt/windows"
SAM_HIVE=$(find_ci "$MOUNT_BASE" "Windows/System32/config/SAM")

if [ -z "$SAM_HIVE" ]; then
    log_error "Fișierul SAM nu a fost găsit."
    exit 1
fi

log_info "Activez contul: ${USERNAME}..."
chntpw -e "$USERNAME" "$SAM_HIVE" 2>&1
log_success "Operațiune finalizată."
