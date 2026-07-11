#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - download-antivirus.sh
# Descarcă și rulează scanerul portabil Kaspersky (KVRT) prin Wine direct pe disc

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

AV_TARGET_DIR="${MOUNT_BASE}/RedSeek_AV"

# Verificare conexiune internet (previne crash set -e pe curl offline)
log_info "Se verifică conexiunea la internet..."
if ! curl -s --connect-timeout 3 https://eicar.org > /dev/null; then
    log_error "FĂRĂ CONEXIUNE: Serverele externe nu pot fi accesate."
    log_warn "Configurează rețeaua folosind wifi-connect.sh înainte de a rula scanarea AV."
    exit 3
fi

# Protecție RAM: salvăm pe hard disk, nu în /tmp (tmpfs pe Live ISO)
if [ ! -d "$MOUNT_BASE" ] || ! touch "$MOUNT_BASE/.write_test" 2>/dev/null; then
    log_error "Partiția Windows nu este montată cu drept de scriere. Nu putem stoca kit-ul AV."
    exit 1
fi
rm -f "$MOUNT_BASE/.write_test"

mkdir -p "$AV_TARGET_DIR"

# URL direct către Kaspersky Virus Removal Tool (link stabil, nu pagină HTML)
DOWNLOAD_URL="https://devbuilds.s.kaspersky-labs.com/kvrt/latest/kvrt.exe"

log_info "Se descarcă Kaspersky Virus Removal Tool (aprox. 160MB)..."
if curl -L "$DOWNLOAD_URL" -o "${AV_TARGET_DIR}/kvrt.exe"; then
    log_success "Descărcare completă: ${AV_TARGET_DIR}/kvrt.exe"

    log_info "Se inițializează scanerul prin Wine (Așteptați încărcarea interfeței)..."
    echo -e "${YELLOW}Notă: Scanerul rulează izolat direct de pe disc pentru a proteja memoria RAM.${NC}"

    export WINEPREFIX="${AV_TARGET_DIR}/.wine_cache"
    wine64 "${AV_TARGET_DIR}/kvrt.exe" || log_warn "Scanerul a fost închis sau a returnat un cod de avertizare."
else
    log_error "Descărcarea a eșuat. Link-ul de la Kaspersky ar putea fi temporar blocat."
    exit 1
fi
