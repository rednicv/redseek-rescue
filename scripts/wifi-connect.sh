#!/usr/bin/env bash
# RedSeek Rescue - wifi-connect.sh
# Conectare securizată la rețea WiFi prin nmcli

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

require_root

log_info "Se activează interfețele wireless..."
rfkill unblock wifi || true

IFACE=$(ip link | awk '/wlan|wlp/ {print $2}' | tr -d ':')
if [ -n "$IFACE" ]; then
    ip link set dev "$IFACE" up 2>/dev/null || true
fi

log_info "Rețele WiFi disponibile:"
nmcli dev wifi list || true

echo -n "Introduceți SSID-ul rețelei: "
read -r SSID
echo -n "Introduceți parola rețelei (lasă gol pentru rețea deschisă): "
read -s PASSWORD
echo ""

if [ -z "$PASSWORD" ]; then
    nmcli dev wifi connect "$SSID"
else
    nmcli dev wifi connect "$SSID" password "$PASSWORD"
fi

if ping -c 2 8.8.8.8 &>/dev/null; then
    log_success "Conexiune la internet realizată cu succes."
else
    log_error "Conexiunea a eșuat. Verificați credențialele."
    exit 1
fi
