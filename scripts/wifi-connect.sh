#!/usr/bin/env bash
# wifi-connect.sh — Simplified WiFi connection for rescue USB
# Usage: ./wifi-connect.sh                       (interactive menu)
#        ./wifi-connect.sh SSID [password]        (quick connect)
# Password is never passed as CLI arg — uses stdin to avoid /proc/cmdline leak

set -euo pipefail
LOGS_DIR="/opt/rescue/logs"
mkdir -p "${LOGS_DIR}"

WIFI_IFACE=""

find_iface() {
  WIFI_IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
  if [ -z "${WIFI_IFACE}" ]; then
    WIFI_IFACE=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | grep wifi | cut -d: -f1 | head -1)
  fi
}

ensure_nm() {
  nmcli radio wifi on 2>/dev/null || true
  sleep 1
}

nm_connect() {
  local ssid="$1"
  local pass="$2"
  if [ -n "${pass}" ]; then
    # Pass password via stdin — never as CLI arg (avoids leak to ps aux / /proc/cmdline)
    printf '%s\n' "${pass}" | nmcli --ask device wifi connect "${ssid}" 2>&1
  else
    nmcli device wifi connect "${ssid}" 2>&1
  fi
}

# === MAIN ===
find_iface

if [ -z "${WIFI_IFACE}" ]; then
  echo "[!] No WiFi interface found."
  echo "    Check if adapter is detected: iwconfig"
  echo "    Or use ethernet via USB-C adapter."
  exit 1
fi

echo "[+] WiFi interface: ${WIFI_IFACE}"
ensure_nm

if [ $# -ge 1 ]; then
  # Quick connect mode — password passed via pipe, not CLI
  SSID="$1"
  PASSWORD="${2:-}"
  nm_connect "${SSID}" "${PASSWORD}" | tee "${LOGS_DIR}/wifi-connect.log"
else
  # Interactive mode
  echo "=== Scanning for networks ==="
  nmcli device wifi list 2>/dev/null || {
    nmcli device wifi rescan
    sleep 3
    nmcli device wifi list
  }
  echo ""
  read -p "SSID: " SSID
  read -sp "Password (leave empty for open network): " PASSWORD
  echo ""
  nm_connect "${SSID}" "${PASSWORD}" | tee "${LOGS_DIR}/wifi-connect.log"
fi

# Check result
if nmcli -t -f DEVICE,STATE device status 2>/dev/null | grep "${WIFI_IFACE}:connected" &>/dev/null; then
  IP=$(ip -4 addr show "${WIFI_IFACE}" 2>/dev/null | grep inet | awk '{print $2}' | head -1)
  echo "[✅] WiFi connected to: ${SSID:-}"
  [ -n "${IP}" ] && echo "    IP: ${IP}"
else
  echo "[❌] WiFi failed. Check password or signal strength."
fi
