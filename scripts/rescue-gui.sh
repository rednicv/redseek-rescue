#!/usr/bin/env bash
# rescue-gui.sh — Graphical interface for RedSeek Rescue (Zenity)
# One-Click Health Check + visual menu for all repair tools
# Requires: zenity (apt install zenity)

source "$(dirname "$0")/utils.sh"
SCRIPT_DIR="$(dirname "$0")"

# Check if zenity is available
if ! command -v zenity &>/dev/null; then
    echo "Installing zenity..."
    apt-get update -qq && apt-get install -y -qq zenity 2>/dev/null || {
        echo "[!] Zenity not available — falling back to terminal mode"
        echo "    Run rescue-playbook.sh for terminal version"
        exit 1
    }
fi

# === One-Click Health Check ===
health_check() {
    (
        echo "10"; echo "# Montare partiție Windows..."
        bash "${SCRIPT_DIR}/mount-windows.sh" 2>/dev/null
        
        echo "30"; echo "# Verificare disc (SMART)..."
        bash "${SCRIPT_DIR}/diagnose.sh" --quick 2>/dev/null
        
        echo "50"; echo "# Verificare fișiere sistem..."
        bash "${SCRIPT_DIR}/check-windows.sh" 2>/dev/null
        
        echo "70"; echo "# Analiză Event Log..."
        bash "${SCRIPT_DIR}/parse-evtx.sh" 2>/dev/null
        
        echo "90"; echo "# Scanare virus..."
        bash "${SCRIPT_DIR}/scan-windows.sh" 2>/dev/null
        
        echo "100"; echo "# Finalizat."
        sleep 1
    ) | zenity --progress \
        --title="RedSeek Rescue — Health Check" \
        --text="Rulez diagnosticare completă..." \
        --percentage=0 \
        --auto-close \
        --width=500 2>/dev/null
    
    # Show report
    if [ -f "${LOGS_DIR}/windows-check.txt" ]; then
        zenity --text-info \
            --title="Raport Health Check" \
            --filename="${LOGS_DIR}/windows-check.txt" \
            --width=700 --height=500 \
            --ok-label="OK" 2>/dev/null
    else
        zenity --info --text="Health Check complet.\nVezi log-urile în /opt/rescue/logs/" \
            --title="RedSeek Rescue" --width=400 2>/dev/null
    fi
}

# === Main Menu ===
main_menu() {
    while true; do
        CHOICE=$(zenity --list \
            --title="🔧 RedSeek Rescue" \
            --text="<b>Ce problemă ai?</b>\n\nAlege o categorie sau rulează diagnosticarea automată." \
            --column="Acțiune" --column="Descriere" \
            --width=650 --height=500 \
            --ok-label="Rulează" --cancel-label="Ieși" \
            "🩺 Health Check" "Diagnosticare completă automată (One-Click)" \
            "🔄 Boot Loop" "Windows se restartează la infinit" \
            "💀 Nu pornește" "Ecran negru, eroare la boot" \
            "🔵 Blue Screen" "BSOD — ecran albastru cu eroare" \
            "🦠 Antivirus" "Scanare viruși și malware" \
            "🔐 Parolă uitată" "Resetează parola Windows" \
            "📦 Backup date" "Salvează datele pe USB sau cloud" \
            "⏳ Update blocat" "Windows blocat la 'Working on updates'" \
            "💾 Disc defect" "Verificare hardware disc" \
            "📋 Event Log" "Parsează event log-urile Windows" \
            "🔧 Registry" "Editor offline de registry" \
            "📸 Snapshot" "Backup/Rollback fișiere sistem" \
            2>/dev/null)
        
        [ $? -ne 0 ] && exit 0  # Cancel pressed
        
        case "${CHOICE}" in
            "🩺 Health Check")
                health_check
                ;;
            "🔄 Boot Loop")
                bash "${SCRIPT_DIR}/rescue-playbook.sh" boot_loop 2>&1 | \
                    zenity --text-info --title="Boot Loop Repair" --width=700 --height=500 2>/dev/null
                ;;
            "💀 Nu pornește")
                bash "${SCRIPT_DIR}/rescue-playbook.sh" nu_porneste 2>&1 | \
                    zenity --text-info --title="Boot Repair" --width=700 --height=500 2>/dev/null
                ;;
            "🔵 Blue Screen")
                bash "${SCRIPT_DIR}/rescue-playbook.sh" bluescreen 2>&1 | \
                    zenity --text-info --title="BSOD Analysis" --width=700 --height=500 2>/dev/null
                ;;
            "🦠 Antivirus")
                bash "${SCRIPT_DIR}/rescue-playbook.sh" virus 2>&1 | \
                    zenity --text-info --title="Antivirus Scan" --width=700 --height=500 2>/dev/null
                ;;
            "🔐 Parolă uitată")
                bash "${SCRIPT_DIR}/rescue-playbook.sh" parola_uitata 2>&1 | \
                    zenity --text-info --title="Password Reset" --width=700 --height=500 2>/dev/null
                ;;
            "📦 Backup date")
                TARGET=$(zenity --file-selection --directory --title="Alege destinația pentru backup" 2>/dev/null)
                [ -n "${TARGET}" ] && bash "${SCRIPT_DIR}/backup-data.sh" "${TARGET}" 2>&1 | \
                    zenity --text-info --title="Backup Date" --width=700 --height=500 2>/dev/null
                ;;
            "⏳ Update blocat")
                bash "${SCRIPT_DIR}/rescue-playbook.sh" update_blocat 2>&1 | \
                    zenity --text-info --title="Update Cleanup" --width=700 --height=500 2>/dev/null
                ;;
            "💾 Disc defect")
                bash "${SCRIPT_DIR}/rescue-playbook.sh" disc_stricat 2>&1 | \
                    zenity --text-info --title="Hardware Diagnostics" --width=700 --height=500 2>/dev/null
                ;;
            "📋 Event Log")
                bash "${SCRIPT_DIR}/parse-evtx.sh" 2>&1 | \
                    zenity --text-info --title="Event Log Parser" --width=700 --height=500 2>/dev/null
                ;;
            "🔧 Registry")
                bash "${SCRIPT_DIR}/registry-tools.sh" 2>&1 | \
                    zenity --text-info --title="Registry Editor" --width=700 --height=500 2>/dev/null
                ;;
            "📸 Snapshot")
                SNAP_CHOICE=$(zenity --list \
                    --title="Snapshot System" \
                    --text="Ce vrei să faci?" \
                    --column="Acțiune" \
                    "Creează snapshot" "Restaurează snapshot" \
                    --width=400 --height=200 2>/dev/null)
                if [ "${SNAP_CHOICE}" = "Creează snapshot" ]; then
                    bash "${SCRIPT_DIR}/snapshot-system.sh" snapshot 2>&1 | \
                        zenity --text-info --title="Snapshot" --width=600 --height=400 2>/dev/null
                elif [ "${SNAP_CHOICE}" = "Restaurează snapshot" ]; then
                    bash "${SCRIPT_DIR}/snapshot-system.sh" rollback 2>&1 | \
                        zenity --text-info --title="Rollback" --width=600 --height=400 2>/dev/null
                fi
                ;;
            *)
                ;;
        esac
    done
}

# === Start ===
# Check if Windows is mounted, offer to mount if not
if ! mountpoint -q "${MOUNT}" 2>/dev/null; then
    zenity --question \
        --title="RedSeek Rescue" \
        --text="Partiția Windows nu e montată.\nVrei să o montez acum?" \
        --width=400 2>/dev/null
    
    if [ $? -eq 0 ]; then
        bash "${SCRIPT_DIR}/mount-windows.sh" 2>&1 | \
            zenity --text-info --title="Montare Windows" --width=600 --height=400 --auto-scroll 2>/dev/null
    fi
fi

main_menu
