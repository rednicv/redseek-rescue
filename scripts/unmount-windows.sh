#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - unmount-windows.sh
# Demontare sigură cu golire cache și curățare loopback

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

log_info "Se golește cache-ul de scriere (sync)..."
sync

if mountpoint -q "$MOUNT_BASE"; then
    log_info "Se demontează $MOUNT_BASE..."
    umount -l "$MOUNT_BASE"
fi

if mountpoint -q "$BITLOCKER_DIR"; then
    log_info "Se demontează containerul BitLocker..."
    umount -l "$BITLOCKER_DIR"
fi

log_success "Sistemul de fișiere deblocat și demontat în siguranță."
