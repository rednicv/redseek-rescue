#!/usr/bin/env bash
# RedSeek Rescue - verify-files.sh
# Verifică semnăturile digitale ale binarelor esențiale Windows

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

MOUNT_BASE="/mnt/windows"
UTILMAN=$(find_ci "$MOUNT_BASE" "Windows/System32/utilman.exe")

if [ -n "$UTILMAN" ] && [ -f "$UTILMAN" ]; then
    log_info "Verificare integritate semnătură utilman.exe..."
    if osslsigncode verify "$UTILMAN" &>/dev/null; then
        log_success "utilman.exe este semnat valid de Microsoft."
    else
        log_warn "ATENȚIE: Semnătură invalidă sau lipsă pe utilman.exe! Posibil backdoor."
    fi
fi
