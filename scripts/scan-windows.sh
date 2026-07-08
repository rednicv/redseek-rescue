#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - scan-windows.sh
# Scanare antivirus cu ClamAV peste directoarele utilizatorilor

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

MOUNT_BASE="/mnt/windows"

log_info "Se pornește actualizarea bazei de date malware ClamAV..."
freshclam || log_warn "Nu s-a putut face update la semnături (fără net)."

log_info "Se scanează folderul Users..."
clamscan -r --infected --log=/tmp/clamscan_results.log "$MOUNT_BASE/Users" || true

log_success "Scanare finalizată. Log salvat în /tmp/clamscan_results.log"
