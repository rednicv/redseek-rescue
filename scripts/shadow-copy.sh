#!/usr/bin/env bash
# Copyright (c) 2026 rednicv
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - shadow-copy.sh
# Identifică și montează Volume Shadow Copies (puncte de restaurare)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

WIN_PART=""
for p in $(lsblk -lno NAME,FSTYPE | awk '$2=="ntfs" {print "/dev/"$1}'); do
    WIN_PART="$p"; break
done

if [ -z "$WIN_PART" ]; then
    log_error "Partiția NTFS brută nu a fost găsită."
    exit 1
fi

VSS_DIR="/mnt/vss"
VSS_MOUNT="/mnt/shadow_mount"
mkdir -p "$VSS_DIR" "$VSS_MOUNT"

log_info "Analiză Volume Shadow Copies pe $WIN_PART..."
vshadowinfo "$WIN_PART" || { log_error "Nu există snapshot-uri disponibile."; exit 1; }

log_info "Se montează metastructura VSS..."
vshadowmount "$WIN_PART" "$VSS_DIR"

log_info "Snapshot-uri disponibile:"
ls -l "$VSS_DIR"

if [ -f "${VSS_DIR}/vss1" ]; then
    log_info "Se montează vss1..."
    ntfs-3g "${VSS_DIR}/vss1" "$VSS_MOUNT" -o ro,ignore_case
    log_success "Snapshot 1 disponibil la $VSS_MOUNT"
fi
