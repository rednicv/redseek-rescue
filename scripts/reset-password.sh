#!/usr/bin/env bash
# Copyright (c) 2026 rednicv
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - reset-password.sh
# Resetează parolele utilizatorilor locali prin alterarea bazei SAM cu rollback automat

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root
require_snapshot

MOUNT_BASE="/mnt/windows"
SAM_HIVE=$(find_ci "$MOUNT_BASE" "Windows/System32/config/SAM")

if [ -z "$SAM_HIVE" ]; then
    log_error "Baza de date SAM nu a fost găsită."
    exit 1
fi

log_info "Se creează backup preventiv pentru SAM..."
cp -a "$SAM_HIVE" "${SAM_HIVE}.redseek.bak"

log_info "Se pornește interfața interactivă chntpw..."
set +e
chntpw -i "$SAM_HIVE"
STATUS=$?
set -e

if [ $STATUS -eq 0 ]; then
    log_success "Parola modificată cu succes."
else
    log_warn "Procesul chntpw a fost anulat sau a generat o eroare."
fi
