#!/usr/bin/env bash
# rescue-playbook.sh — Intelligent symptom-to-fix orchestrator
# Maps user-described symptoms to the correct repair scripts automatically.
# Usage: ./rescue-playbook.sh [symptom]

source "$(dirname "$0")/utils.sh"
verify_mount || exit 1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║     🔧 RedSeek Rescue Playbook      ║"
    echo "  ║   Spune ce simptom ai — eu repar    ║"
    echo "  ╚══════════════════════════════════════╝"
    echo -e "${NC}"
}

# Playbook: symptom → scripts to run (in order)
declare -A PLAYBOOK

PLAYBOOK["boot_loop"]="mount-windows.sh cleanup-updates.sh repair-boot.sh"
PLAYBOOK["nu_porneste"]="mount-windows.sh check-windows.sh repair-boot.sh diagnose.sh"
PLAYBOOK["bluescreen"]="mount-windows.sh check-windows.sh parse-evtx.sh diagnose.sh"
PLAYBOOK["virus"]="mount-windows.sh scan-windows.sh download-antivirus.sh"
PLAYBOOK["update_blocat"]="mount-windows.sh cleanup-updates.sh"
PLAYBOOK["parola_uitata"]="mount-windows.sh reset-password.sh"
PLAYBOOK["lent"]="mount-windows.sh check-windows.sh diagnose.sh hardware-diagnostics.sh"
PLAYBOOK["disc_stricat"]="mount-windows.sh diagnose.sh hardware-diagnostics.sh"
PLAYBOOK["date_pierdute"]="mount-windows.sh shadow-copy.sh backup-data.sh"
PLAYBOOK["registry_stricat"]="mount-windows.sh registry-tools.sh"
PLAYBOOK["nu_detecteaza_hdd"]="mount-windows.sh hardware-diagnostics.sh"
PLAYBOOK["bitlocker"]="mount-windows.sh"

# Human-readable descriptions
declare -A DESCRIPTIONS
DESCRIPTIONS["boot_loop"]="Windows se restartează la infinit (boot loop / 'Getting Windows ready')"
DESCRIPTIONS["nu_porneste"]="Windows nu pornește deloc — ecran negru sau eroare"
DESCRIPTIONS["bluescreen"]="Blue Screen of Death (BSOD) — eroare cu cod"
DESCRIPTIONS["virus"]="Bănuiesc virus/malware — comportament ciudat, popup-uri"
DESCRIPTIONS["update_blocat"]="Windows s-a blocat la update — 'Working on updates' infinit"
DESCRIPTIONS["parola_uitata"]="Am uitat parola de Windows — nu pot să mă loghez"
DESCRIPTIONS["lent"]="Windows merge foarte încet — freeze-uri, lag"
DESCRIPTIONS["disc_stricat"]="Discul face zgomote ciudate — suspect defect hardware"
DESCRIPTIONS["date_pierdute"]="Am șters fișiere importante — vreau să le recuperez"
DESCRIPTIONS["registry_stricat"]="Registry corupt — erori la pornirea aplicațiilor"
DESCRIPTIONS["nu_detecteaza_hdd"]="Windows nu mai vede hard disk-ul / SSD-ul"
DESCRIPTIONS["bitlocker"]="Partiția e criptată cu BitLocker — am recovery key"

# === Fast path: symptom provided as argument ===
if [ -n "${1}" ]; then
    SYMPTOM="${1}"
    if [ -n "${PLAYBOOK[${SYMPTOM}]}" ]; then
        echo -e "${GREEN}▶ Playbook: ${CYAN}${DESCRIPTIONS[${SYMPTOM}]}${NC}"
        SCRIPTS="${PLAYBOOK[${SYMPTOM}]}"
    else
        echo -e "${RED}[!] Simptom necunoscut: ${SYMPTOM}${NC}"
        echo "Simptoame disponibile: ${!PLAYBOOK[*]}"
        exit 1
    fi
else
    # === Interactive mode ===
    banner
    echo "Alege simptomul (tastează numărul sau cuvântul cheie):"
    echo ""
    
    KEYS=(${!PLAYBOOK[@]})
    for i in "${!KEYS[@]}"; do
        key="${KEYS[$i]}"
        num=$((i + 1))
        printf "  ${GREEN}%2d)${NC} %-18s → ${DESCRIPTIONS[${key}]}\n" "$num" "$key"
    done
    
    echo ""
    echo -e "  ${GREEN} 0)${NC} Diagnosticare completă (rulează tot)"
    echo ""
    read -p "Alegerea ta: " CHOICE
    
    # Check if choice is a number
    if [[ "${CHOICE}" =~ ^[0-9]+$ ]]; then
        if [ "${CHOICE}" -eq 0 ]; then
            echo -e "${YELLOW}▶ Diagnosticare completă...${NC}"
            SCRIPTS="mount-windows.sh diagnose.sh check-windows.sh hardware-diagnostics.sh parse-evtx.sh scan-windows.sh"
        elif [ "${CHOICE}" -ge 1 ] && [ "${CHOICE}" -le ${#KEYS[@]} ]; then
            idx=$((CHOICE - 1))
            SYMPTOM="${KEYS[$idx]}"
            echo -e "${GREEN}▶ ${DESCRIPTIONS[${SYMPTOM}]}${NC}"
            SCRIPTS="${PLAYBOOK[${SYMPTOM}]}"
        else
            echo -e "${RED}[!] Număr invalid${NC}"
            exit 1
        fi
    else
        # Choice is a keyword
        if [ -n "${PLAYBOOK[${CHOICE}]}" ]; then
            SYMPTOM="${CHOICE}"
            SCRIPTS="${PLAYBOOK[${SYMPTOM}]}"
        else
            echo -e "${RED}[!] Simptom necunoscut: ${CHOICE}${NC}"
            exit 1
        fi
    fi
fi

# === Run playbook ===
SCRIPT_DIR="$(dirname "$0")"
FAILED=0
TOTAL=0

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

for script in ${SCRIPTS}; do
    TOTAL=$((TOTAL + 1))
    SCRIPT_PATH="${SCRIPT_DIR}/${script}"
    
    if [ ! -f "${SCRIPT_PATH}" ]; then
        echo -e "  ${YELLOW}⊘${NC} ${script} — nu există, sărit"
        continue
    fi
    
    echo -e "${GREEN}▶${NC} Rulare: ${script}..."
    
    if bash "${SCRIPT_PATH}" 2>&1 | sed 's/^/  │ /'; then
        echo -e "  ${GREEN}✅${NC} ${script} — OK"
    else
        echo -e "  ${RED}❌${NC} ${script} — EȘUAT (exit code: ${PIPESTATUS[0]})"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Rulate: ${TOTAL} | ${GREEN}Reușite: $((TOTAL - FAILED))${NC} | ${RED}Eșuate: ${FAILED}${NC}"

if [ "${FAILED}" -eq 0 ]; then
    echo -e "${GREEN}  ✅ Playbook complet! Repornește și testează Windows.${NC}"
else
    echo -e "${YELLOW}  ⚠️  Unele scripturi au eșuat. Vezi log-urile în /opt/rescue/logs/${NC}"
fi
