#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - repair-boot.sh
# Inspectează partiția EFI și validează integritatea BCD

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root
require_snapshot

log_info "Scanare partiții de sistem EFI..."

# Folder temporar unic, creat o singură dată în afara buclei
TMP_EFI=$(mktemp -d)
trap 'rmdir "$TMP_EFI" 2>/dev/null' EXIT

EFI_FOUND=false

for part in $(lsblk -lno NAME,FSTYPE | awk '$2=="vfat" {print "/dev/"$1}'); do
    mount "$part" "$TMP_EFI" 2>/dev/null || continue

    if [ -d "$TMP_EFI/EFI/Microsoft" ]; then
        EFI_FOUND=true
        log_success "Tabelă de boot Microsoft detectată pe $part"
        log_info "Verificare BCD..."

        if [ -f "$TMP_EFI/EFI/Microsoft/Boot/BCD" ]; then
            log_success "Fișierul BCD este prezent și accesibil pe $part."
            ls -la "$TMP_EFI/EFI/Microsoft/Boot/BCD"
        else
            log_error "CRITIC: Fișierul BCD lipsește sau este corupt pe $part!"
            log_warn "RedSeek recomandă reconstrucția manuală a BCD-ului."
        fi
    fi

    umount "$TMP_EFI" 2>/dev/null || true
done

if [ "$EFI_FOUND" = false ]; then
    log_warn "Nu a fost detectată nicio partiție EFI validă cu structură Microsoft."
fi
