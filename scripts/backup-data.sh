#!/usr/bin/env bash
# Copyright (c) 2026 rednicv
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - backup-data.sh
# Copiază profilele utilizatorilor pe un mediu extern înainte de intervenții

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

MOUNT_BASE="/mnt/windows"
BACKUP_TARGET=""

log_info "Identificare medii externe USB..."
for dev in $(lsblk -dno NAME,RM | awk '$2==1 {print "/dev/"$1}'); do
    if ! grep -q "$dev" /proc/mounts; then
        BACKUP_TARGET="/mnt/external_usb"
        mkdir -p "$BACKUP_TARGET"
        mount "${dev}1" "$BACKUP_TARGET" 2>/dev/null && break
    fi
done

if [ -z "$BACKUP_TARGET" ] || ! mountpoint -q "$BACKUP_TARGET"; then
    log_error "Nu s-a detectat un stick sau HDD extern USB."
    exit 1
fi

log_info "Se copiază documentele utilizatorilor..."
rsync -av --progress --exclude="AppData" "$MOUNT_BASE/Users/" "$BACKUP_TARGET/RedSeek_Backups/"

log_success "Salvare completă pe mediul extern."
