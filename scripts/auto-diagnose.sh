#!/usr/bin/env bash
# auto-diagnose.sh — Intelligent problem detection from EventLog + minidump + SMART
# Analyzes available data and generates a hypothesis with confidence score.
# Usage: ./auto-diagnose.sh
set -euo pipefail

source "$(dirname "$0")/utils.sh"

OUTPUT="${LOGS_DIR}/auto-diagnose.txt"
mkdir -p "${LOGS_DIR}"

echo "=== RedSeek Auto-Diagnosis ===" > "${OUTPUT}"
echo "Date: $(date)" >> "${OUTPUT}"
echo "" >> "${OUTPUT}"

verify_mount || { echo "[!] Windows not mounted — limited analysis." >> "${OUTPUT}"; }

# Scoring system
declare -A SCORES
SCORES["driver_fault"]=0
SCORES["disk_failing"]=0
SCORES["memory_fault"]=0
SCORES["boot_corrupt"]=0
SCORES["registry_corrupt"]=0
SCORES["malware"]=0
SCORES["update_stuck"]=0
SCORES["filesystem_corrupt"]=0

# Evidence tracking
declare -A EVIDENCE

add_evidence() {
    local problem="$1" weight="$2" detail="$3"
    SCORES["${problem}"]=$((SCORES["${problem}"] + weight))
    EVIDENCE["${problem}"]="${EVIDENCE["${problem}"]}  • ${detail}\n"
}

# === 1. Check SMART (disk health) ===
echo "🔍 Checking disk health (SMART)..." | tee -a "${OUTPUT}"
for dev in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
    [ -b "${dev}" ] || continue
    SMART_OUT=$(smartctl -H "${dev}" 2>/dev/null || true)
    
    if echo "${SMART_OUT}" | grep -q "PASSED"; then
        echo "  ✅ ${dev}: SMART OK" >> "${OUTPUT}"
    elif echo "${SMART_OUT}" | grep -q "FAILED\|FAILING_NOW"; then
        add_evidence "disk_failing" 30 "SMART FAILED on ${dev}"
        echo "  ❌ ${dev}: SMART FAILED!" >> "${OUTPUT}"
    else
        echo "  ⊘ ${dev}: SMART not available" >> "${OUTPUT}"
    fi
    
    # Check reallocated sectors
    REALLOC=$(smartctl -A "${dev}" 2>/dev/null | grep -i "Reallocated_Sector" | awk '{print $NF}' || echo "0")
    if [[ "${REALLOC}" =~ ^[0-9]+$ ]] && [ "${REALLOC}" -gt 10 ]; then
        add_evidence "disk_failing" 15 "${dev}: ${REALLOC} sectoare realocate"
    fi
done
echo "" >> "${OUTPUT}"

# === 2. Check minidumps (BSOD) ===
echo "🔍 Checking minidumps..." | tee -a "${OUTPUT}"
WIN_DIR=$(find_ci "${MOUNT}" 1 "Windows" 2>/dev/null || echo "")
if [ -n "${WIN_DIR}" ]; then
    DUMP_DIR=$(find_ci "${WIN_DIR}" 1 "Minidump" 2>/dev/null || echo "")
    if [ -n "${DUMP_DIR}" ] && [ -d "${DUMP_DIR}" ]; then
        shopt -s nullglob
        DUMPS=("${DUMP_DIR}"/*.dmp)
        DUMP_COUNT=${#DUMPS[@]}
        if [ "${DUMP_COUNT}" -gt 0 ]; then
            add_evidence "driver_fault" $((DUMP_COUNT * 5)) "${DUMP_COUNT} minidump-uri găsite → BSOD recurent"
            echo "  ⚠️  ${DUMP_COUNT} BSOD minidump(s) found" >> "${OUTPUT}"
            
            # Try to extract basic info from latest dump
            LATEST=$(ls -t "${DUMP_DIR}"/*.dmp 2>/dev/null | head -n1)
            if [ -f "${LATEST}" ]; then
                echo "  Latest: $(basename "${LATEST}") ($(stat -c%s "${LATEST}") bytes)" >> "${OUTPUT}"
            fi
        else
            echo "  ✅ No recent BSODs" >> "${OUTPUT}"
        fi
    fi
fi
echo "" >> "${OUTPUT}"

# === 3. Check Event Log for critical errors ===
echo "🔍 Scanning Event Log for patterns..." | tee -a "${OUTPUT}"
EVTX_FOUND=0
if [ -n "${WIN_DIR}" ]; then
    SYS32_DIR=$(find_ci "${WIN_DIR}" 1 "System32" 2>/dev/null || echo "")
    if [ -n "${SYS32_DIR}" ]; then
        EVTX_DIR=$(find_ci "${SYS32_DIR}" 2 "Logs" 2>/dev/null || echo "")
        if [ -n "${EVTX_DIR}" ] && [ -d "${EVTX_DIR}" ]; then
            for log in System Application; do
                EVTX_FILE="${EVTX_DIR}/${log}.evtx"
                [ -f "${EVTX_FILE}" ] || continue
                EVTX_FOUND=1
                
                # Quick grep for known error patterns (works on raw EVTX)
                ERRORS=$(strings "${EVTX_FILE}" 2>/dev/null | grep -ciE "disk|ntfs|chkdsk|bad block" || echo 0)
                DRIVERS=$(strings "${EVTX_FILE}" 2>/dev/null | grep -ciE "driver|\.sys.*fail|DRIVER_" || echo 0)
                MEMORY=$(strings "${EVTX_FILE}" 2>/dev/null | grep -ciE "memory|MEMORY_MANAGEMENT|page fault" || echo 0)
                BOOT=$(strings "${EVTX_FILE}" 2>/dev/null | grep -ciE "boot|winload|bcd|bootmgr" || echo 0)
                
                [[ "${ERRORS}" =~ ^[0-9]+$ && "${ERRORS}" -gt 5 ]] && add_evidence "filesystem_corrupt" 10 "${log}.evtx: ${ERRORS} NTFS/disk errors"
                [[ "${DRIVERS}" =~ ^[0-9]+$ && "${DRIVERS}" -gt 3 ]] && add_evidence "driver_fault" 10 "${log}.evtx: ${DRIVERS} driver failures"
                [[ "${MEMORY}" =~ ^[0-9]+$ && "${MEMORY}" -gt 2 ]] && add_evidence "memory_fault" 10 "${log}.evtx: ${MEMORY} memory errors"
                [[ "${BOOT}" =~ ^[0-9]+$ && "${BOOT}" -gt 3 ]] && add_evidence "boot_corrupt" 10 "${log}.evtx: ${BOOT} boot errors"
            done
        fi
    fi
fi
[ "${EVTX_FOUND}" -eq 0 ] && echo "  ⊘ No event logs accessible" >> "${OUTPUT}"
echo "" >> "${OUTPUT}"

# === 4. Check for stuck updates ===
echo "🔍 Checking for stuck updates..." | tee -a "${OUTPUT}"
if [ -n "${WIN_DIR}" ]; then
    WINSXS_DIR=$(find_ci "${WIN_DIR}" 1 "WinSxS" 2>/dev/null || echo "")
    if [ -n "${WINSXS_DIR}" ]; then
        if find "${WINSXS_DIR}" -maxdepth 1 -iname "pending.xml" 2>/dev/null | grep -q .; then
            add_evidence "update_stuck" 20 "pending.xml găsit în WinSxS — update blocat"
            echo "  ⚠️  Stuck update detected (pending.xml)" >> "${OUTPUT}"
        fi
    fi
fi
echo "" >> "${OUTPUT}"

# === 5. Check boot files ===
echo "🔍 Checking boot files..." | tee -a "${OUTPUT}"
if [ -n "${WIN_DIR}" ] && [ -n "${SYS32_DIR}" ]; then
    for f in winload.exe ntoskrnl.exe; do
        FOUND=$(find "${SYS32_DIR}" -maxdepth 1 -iname "${f}" 2>/dev/null | head -n1)
        if [ -z "${FOUND}" ]; then
            add_evidence "boot_corrupt" 25 "${f} lipsește din System32!"
        fi
    done
fi

# Check BCD
BCD_FOUND=$(find "${MOUNT}" -path "*/Boot/BCD" -o -path "*/EFI/Microsoft/Boot/BCD" 2>/dev/null | head -n1)
if [ -z "${BCD_FOUND}" ]; then
    add_evidence "boot_corrupt" 25 "BCD (Boot Configuration Data) lipsește!"
fi
echo "" >> "${OUTPUT}"

# === 6. Check registry hives ===
echo "🔍 Checking registry hives..." | tee -a "${OUTPUT}"
if [ -n "${SYS32_DIR}" ]; then
    CONFIG_DIR=$(find_ci "${SYS32_DIR}" 1 "config" 2>/dev/null || echo "")
    if [ -n "${CONFIG_DIR}" ]; then
        for hive in SOFTWARE SYSTEM SAM SECURITY DEFAULT; do
            if [ ! -f "${CONFIG_DIR}/${hive}" ]; then
                add_evidence "registry_corrupt" 20 "Hive registry ${hive} lipsește"
            fi
        done
    fi
fi
echo "" >> "${OUTPUT}"

# === FINAL DIAGNOSIS ===
echo "========================================" >> "${OUTPUT}"
echo "  DIAGNOZĂ AUTOMATĂ" >> "${OUTPUT}"
echo "========================================" >> "${OUTPUT}"
echo "" >> "${OUTPUT}"

# Sort by score
RESULTS=""
for problem in "${!SCORES[@]}"; do
    score="${SCORES[${problem}]}"
    [ "${score}" -gt 0 ] 2>/dev/null && RESULTS+="${score} ${problem}\n"
done

if [ -z "${RESULTS}" ]; then
    echo "✅ Nu s-au detectat probleme evidente." >> "${OUTPUT}"
    echo "   Windows pare sănătos din ce pot vedea din Linux." >> "${OUTPUT}"
    echo "   Dacă ai simptome specifice, folosește rescue-playbook.sh" >> "${OUTPUT}"
else
    RANK=1
    echo -e "${RESULTS}" | sort -rn | while read score problem; do
        [ -z "${score}" ] && continue
        pct=$((score * 100 / 130))  # Normalize to ~100%
        [ "${pct}" -gt 100 ] && pct=100
        
        case "${problem}" in
            driver_fault)    LABEL="Driver defect / incompatibil" ;;
            disk_failing)    LABEL="Disc dur în curs de defectare" ;;
            memory_fault)    LABEL="Problemă de memorie RAM" ;;
            boot_corrupt)    LABEL="Bootloader corupt (BCD/winload)" ;;
            registry_corrupt) LABEL="Registry corupt" ;;
            malware)         LABEL="Infecție cu malware/virus" ;;
            update_stuck)    LABEL="Windows Update blocat" ;;
            filesystem_corrupt) LABEL="Sistem de fișiere corupt (NTFS)" ;;
            *)               LABEL="${problem}" ;;
        esac
        
        echo "#${RANK} [${pct}%] ${LABEL}" >> "${OUTPUT}"
        echo -e "${EVIDENCE[${problem}]}" >> "${OUTPUT}"
        echo "" >> "${OUTPUT}"
        RANK=$((RANK + 1))
    done
    
    echo "────────────────────────────────────" >> "${OUTPUT}"
    echo "🎯 RECOMANDARE: Rulează rescue-playbook.sh cu simptomul #1" >> "${OUTPUT}"
fi

echo "" >> "${OUTPUT}"
echo "=== Raport salvat în ${OUTPUT} ==="
cat "${OUTPUT}"
