#!/usr/bin/env bash
# RedSeek Rescue - check-windows.sh
# Verifică integritatea fișierelor vitale Windows

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

MOUNT_BASE="/mnt/windows"

if [ ! -d "$MOUNT_BASE/Windows" ] && [ ! -d "$MOUNT_BASE/windows" ]; then
    log_error "Windows nu este montat corect la $MOUNT_BASE"
    exit 1
fi

log_info "Verificare structură esențială de sistem..."
for dir in "Windows/System32" "Windows/System32/config" "Users" "Program Files"; do
    REAL_PATH=$(find_ci "$MOUNT_BASE" "$dir")
    if [ -n "$REAL_PATH" ]; then
        log_success "Găsit: $dir -> $REAL_PATH"
    else
        log_error "LIPSĂ CRITICĂ: $dir"
    fi
done
