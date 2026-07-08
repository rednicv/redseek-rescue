#!/usr/bin/env bash
# Copyright (c) 2026 rednicv
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - repair-boot.sh
# Reconstruiește fișierele de boot și inspectează partiția EFI

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root
require_snapshot

log_info "Scanare partiții de sistem EFI..."
for part in $(lsblk -lno NAME,FSTYPE | awk '$2=="vfat" {print "/dev/"$1}'); do
    tmp_efi=$(mktemp -d)
    mount "$part" "$tmp_efi" 2>/dev/null || continue
    if [ -d "$tmp_efi/EFI/Microsoft" ]; then
        log_success "Tabelă de boot Microsoft detectată pe $part"
        log_info "Verificare BCD..."
        ls -la "$tmp_efi/EFI/Microsoft/Boot/BCD" || log_error "BCD lipsește pe $part!"
    fi
    umount "$tmp_efi" && rmdir "$tmp_efi"
done
