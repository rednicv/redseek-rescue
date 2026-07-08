#!/usr/bin/env bash
# Copyright (c) 2026 rednicv
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

# RedSeek Rescue - rescue-gui.sh
# Interfață grafică Zenity pentru operații comune

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

if ! command -v zenity &>/dev/null; then
    log_error "Zenity nu este instalat."
    exit 1
fi

while true; do
    CHOICE=$(zenity --list --title="RedSeek Rescue AI Dashboard" \
        --column="Opțiune" --column="Descriere" \
        "1_WiFi" "Configurare conexiune WiFi" \
        "2_Mount" "Montare automată partiție Windows" \
        "3_Pass" "Resetare parolă cont Windows" \
        "4_Reg" "Reparație Registry (Fast Startup)" \
        "5_Scan" "Scanare Antivirus ClamAV" \
        "6_Exit" "Ieșire" 2>/dev/null) || break

    case "$CHOICE" in
        "1_WiFi") "${SCRIPT_DIR}/wifi-connect.sh" 2>&1 | zenity --text-info --title="WiFi" --width=500 --height=400 ;;
        "2_Mount") "${SCRIPT_DIR}/mount-windows.sh" 2>&1 | zenity --text-info --title="Mount" --width=500 --height=400 ;;
        "3_Pass") "${SCRIPT_DIR}/reset-password.sh" 2>&1 | zenity --text-info --title="Reset Password" --width=500 --height=400 ;;
        "4_Reg") "${SCRIPT_DIR}/registry-tools.sh" 2>&1 | zenity --text-info --title="Registry Fix" --width=500 --height=400 ;;
        "5_Scan") "${SCRIPT_DIR}/scan-windows.sh" 2>&1 | zenity --text-info --title="Antivirus Scan" --width=500 --height=400 ;;
        *) break ;;
    esac
done
