#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - cleanup-updates.sh
# Elimină actualizări blocate care provoacă bucle infinite de boot (RO-aware)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

# --- Verificare RO-Aware (previne crash set -e pe mount read-only) ---
if ! touch "$MOUNT_BASE/.ro_write_test" 2>/dev/null; then
    log_error "EROARE: Partiția Windows este montată în mod Read-Only!"
    log_error "Actualizările blocate nu pot fi curățate fără drepturi de scriere."
    log_warn "Rulează mai întâi mount-windows.sh cu opțiunea de curățare a hibernării."
    exit 3
fi
rm -f "$MOUNT_BASE/.ro_write_test"

SDF_DIR=$(find_ci "$MOUNT_BASE" "Windows/SoftwareDistribution/Download")
if [ -n "$SDF_DIR" ] && [ -d "$SDF_DIR" ]; then
    log_info "Curățare cache SoftwareDistribution..."
    rm -rf "${SDF_DIR:?}"/*
    log_success "Cache șters."
fi

PENDING_XML=$(find_ci "$MOUNT_BASE" "Windows/WinSxS/pending.xml")
if [ -n "$PENDING_XML" ] && [ -f "$PENDING_XML" ]; then
    log_warn "Detectat pending.xml blocat. Se renumerează..."
    mv "$PENDING_XML" "${PENDING_XML}.bak"
    log_success "Buclele de instalare WinSxS au fost dezamorsate."
    log_warn "NOTA: S-a aplicat hard-bypass. Windows poate raporta CBS_E_PENDING_VIOLATION la următorul boot."
fi
