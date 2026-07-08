#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - mount-windows.sh
# Detectare automată partiție Windows, bypass Fast Startup, suport BitLocker

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

MOUNT_BASE="/mnt/windows"
BITLOCKER_DIR="/mnt/bitlocker"
mkdir -p "$MOUNT_BASE" "$BITLOCKER_DIR"

log_info "Identificare partiții NTFS/BitLocker..."
WIN_PART=""

for part in $(lsblk -lno NAME,FSTYPE | awk '$2=="ntfs" || $2=="BitLocker" {print "/dev/"$1}'); do
    FSTYPE=$(blkid -o value -s TYPE "$part" 2>/dev/null || echo "ntfs")

    if [ "$FSTYPE" = "BitLocker" ]; then
        log_warn "Partiție BitLocker detectată pe $part!"
        echo -n "Introduceți cheia de recuperare BitLocker (48 cifre): "
        read -r BK_KEY
        if dislocker-fuse -V "$part" -p"$BK_KEY" -- "$BITLOCKER_DIR"; then
            part="${BITLOCKER_DIR}/dislocker-file"
            log_success "BitLocker decriptat cu succes."
        else
            log_error "Cheie incorectă."
            continue
        fi
    fi

    tmp_mnt=$(mktemp -d)
    if mount -t ntfs-3g -o ro,ignore_case "$part" "$tmp_mnt" 2>/dev/null; then
        if [ -d "${tmp_mnt}/Windows" ] || [ -d "${tmp_mnt}/windows" ]; then
            WIN_PART="$part"
            umount "$tmp_mnt" && rmdir "$tmp_mnt"
            break
        fi
        umount "$tmp_mnt"
    fi
    rmdir "$tmp_mnt" || true
done

if [ -z "$WIN_PART" ]; then
    log_error "Nicio partiție Windows validă nu a fost găsită."
    exit 1
fi

log_info "Se montează R/W partiția $WIN_PART..."
if ntfs-3g "$WIN_PART" "$MOUNT_BASE" -o remove_hiberfile,ignore_case,windows_names; then
    log_success "Montat complet R/W la $MOUNT_BASE"
else
    log_warn "Eroare la eliminarea hiberfile. Forțăm montare Read-Only..."
    ntfs-3g "$WIN_PART" "$MOUNT_BASE" -o ro,ignore_case,windows_names
    log_success "Montat în modul Safe Read-Only."
fi
