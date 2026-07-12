#!/usr/bin/env bash
# Copyright (c) 2026 Rednic Vasile
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - auto-diagnose.sh
# Mod nesupravegheat (Zero-Click) — colectează loguri și exportă JSON

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${SCRIPT_DIR}/utils.sh"

require_root

RESCUE_VERSION=$(head -1 "${SCRIPT_DIR}/../VERSION" 2>/dev/null || echo "unknown")

REPORT_FILE="/tmp/redseek_report.json"
echo "{\"status\":\"running\",\"version\":\"${RESCUE_VERSION}\"}" > "$REPORT_FILE"

set +e
"${SCRIPT_DIR}/diagnose.sh" &>/dev/null
DIAG_RC=$?
set -e

if [ $DIAG_RC -eq 0 ]; then
    echo "{\"status\":\"completed\",\"diagnostics\":\"success\",\"version\":\"${RESCUE_VERSION}\"}" > "$REPORT_FILE"
    log_success "Raport automat exportat în $REPORT_FILE"
else
    echo "{\"status\":\"completed\",\"diagnostics\":\"failed\",\"version\":\"${RESCUE_VERSION}\"}" > "$REPORT_FILE"
    log_warn "Diagnoza a raportat erori sau avertismente. Raport salvat în $REPORT_FILE"
fi
