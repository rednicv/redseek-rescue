#!/usr/bin/env bash
# Copyright (c) 2026 rednicv
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - hardware-diagnostics.sh
# Teste de stres pe memorie și monitorizare temperatură

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_info "Se pornește testul de stres pentru memorie (memtester)..."
memtester 128M 1 || log_warn "Memoria a raportat erori fizice!"

log_info "Monitorizare senzori de temperatură..."
sensors 2>/dev/null || log_warn "lm-sensors nu este configurat."
