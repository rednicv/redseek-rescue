#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - list-users.sh
# Listează utilizatorii locali Windows din registry SAM

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

SAM_HIVE=$(find_ci "$MOUNT_BASE" "Windows/System32/config/SAM")

if [ -z "$SAM_HIVE" ]; then
    log_error "Fișierul SAM nu a fost găsit. Este Windows-ul montat?"
    exit 1
fi

log_info "Utilizatori locali Windows:"
chntpw -l "$SAM_HIVE" 2>&1
