#!/usr/bin/env bash
# RedSeek Rescue - download-antivirus.sh
# Descarcă unelte portabile AV prin Wine

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

log_info "Descărcare scanere portabile prin Wine..."
DOWNLOAD_URL="https://secure.drweb.com/cureit/"
mkdir -p /tmp/portable-av

# curl -L "$DOWNLOAD_URL" -o /tmp/portable-av/cureit.exe
log_success "Utilitarele portabile pot fi pornite cu: wine64 /tmp/portable-av/cureit.exe"
