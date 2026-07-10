#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - shadow-copy.sh
# Identifică și montează Volume Shadow Copies (puncte de restaurare) în mod sigur

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

# Selectăm cea mai MARE partiție NTFS (evită WinRE/Recovery ~500MB)
WIN_PART=$(lsblk -bno NAME,FSTYPE,SIZE | awk '$2=="ntfs" {print $3, "/dev/"$1}' | sort -nr | head -n1 | awk '{print $2}')

if [ -z "$WIN_PART" ]; then
    log_error "Partiția NTFS principală nu a fost găsită."
    exit 1
fi

VSS_DIR="/mnt/vss"
VSS_MOUNT="/mnt/shadow_mount"
mkdir -p "$VSS_DIR" "$VSS_MOUNT"

# Demontare temporară dacă partția e deja montată (vshadowmount cere acces exclusiv)
WAS_MOUNTED=false
if mountpoint -q /mnt/windows; then
    log_warn "Partiția $WIN_PART este montată activ. Se demontează temporar pentru acces VSS..."
    umount /mnt/windows || { log_error "Nu s-a putut elibera lock-ul pe partiție."; exit 1; }
    WAS_MOUNTED=true
fi

log_info "Analiză Volume Shadow Copies pe $WIN_PART..."
if ! vshadowinfo "$WIN_PART" &>/dev/null; then
    log_error "Nu există snapshot-uri VSS disponibile pe această partiție."
    $WAS_MOUNTED && ntfs-3g "$WIN_PART" /mnt/windows -o remove_hiberfile,ignore_case,windows_names
    exit 1
fi

log_info "Se montează metastructura VSS..."
vshadowmount -o allow_other "$WIN_PART" "$VSS_DIR"

log_info "Snapshot-uri disponibile:"
ls -l "$VSS_DIR"

# Primul snapshot valid (dinamic, nu hardcoded vss1)
FIRST_VSS=$(ls "${VSS_DIR}"/vss* 2>/dev/null | head -n1 || true)

if [ -n "$FIRST_VSS" ] && [ -f "$FIRST_VSS" ]; then
    log_info "Se montează folderul de restaurare ($(basename "$FIRST_VSS"))..."
    ntfs-3g "$FIRST_VSS" "$VSS_MOUNT" -o ro,ignore_case,allow_other
    log_success "Punctul de restaurare este disponibil la: $VSS_MOUNT"
    log_warn "Datele sunt în mod Read-Only. Poți copia fișiere vechi pentru restaurare."
else
    log_error "Metastructura s-a montat, dar nu s-au găsit fișiere vss."
fi
