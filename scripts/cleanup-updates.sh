#!/usr/bin/env bash
# Copyright (c) 2026 rednicv
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - cleanup-updates.sh
# Elimină actualizări blocate care provoacă bucle infinite de boot

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

MOUNT_BASE="/mnt/windows"
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
fi
