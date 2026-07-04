#!/usr/bin/env bash
# snapshot-system.sh — Backup critical Windows files before repairs, with rollback
# Creates timestamped snapshots of registry hives, BCD, and boot files.
# Usage: ./snapshot-system.sh [snapshot|rollback|list]

source "$(dirname "$0")/utils.sh"

SNAPSHOT_DIR="/opt/rescue/snapshots"
SNAPSHOT_LOG="${LOGS_DIR}/snapshot.log"

mkdir -p "${SNAPSHOT_DIR}" "${LOGS_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Files to snapshot (relative to MOUNT)
CRITICAL_FILES=(
    "Windows/System32/config/SOFTWARE"
    "Windows/System32/config/SYSTEM"
    "Windows/System32/config/SAM"
    "Windows/System32/config/SECURITY"
    "Windows/System32/config/DEFAULT"
    "Boot/BCD"
    "EFI/Microsoft/Boot/BCD"
)

print_snapshots() {
    echo -e "${CYAN}=== Snapshots disponibile ===${NC}"
    if [ -d "${SNAPSHOT_DIR}" ] && [ "$(ls -A "${SNAPSHOT_DIR}" 2>/dev/null)" ]; then
        for snap in "${SNAPSHOT_DIR}"/*/; do
            name=$(basename "${snap}")
            count=$(find "${snap}" -type f | wc -l)
            size=$(du -sh "${snap}" 2>/dev/null | cut -f1)
            echo -e "  ${GREEN}▶${NC} ${name} (${count} fișiere, ${size})"
        done
    else
        echo "  (niciun snapshot)"
    fi
}

# === CREATE SNAPSHOT ===
do_snapshot() {
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    SNAP_PATH="${SNAPSHOT_DIR}/${TIMESTAMP}"
    mkdir -p "${SNAP_PATH}"
    
    echo -e "${CYAN}📸 Creare snapshot: ${TIMESTAMP}${NC}" | tee -a "${SNAPSHOT_LOG}"
    echo "" | tee -a "${SNAPSHOT_LOG}"
    
    verify_mount || exit 1
    
    COPIED=0
    MISSING=0
    
    for rel_path in "${CRITICAL_FILES[@]}"; do
        # Case-insensitive find
        dir=$(dirname "${MOUNT}/${rel_path}")
        fname=$(basename "${rel_path}")
        
        # Search case-insensitively
        FOUND=$(find "${MOUNT}" -path "*/${fname}" -not -path "*/snapshots/*" 2>/dev/null | grep -i "$(echo "${rel_path}" | sed 's|/|.*/|g')" | head -n1)
        
        if [ -z "${FOUND}" ] || [ ! -f "${FOUND}" ]; then
            echo "  ⊘ ${rel_path} — negăsit" | tee -a "${SNAPSHOT_LOG}"
            MISSING=$((MISSING + 1))
            continue
        fi
        
        # Preserve directory structure in snapshot
        REL_DIR=$(dirname "${rel_path}")
        mkdir -p "${SNAP_PATH}/${REL_DIR}"
        cp -a "${FOUND}" "${SNAP_PATH}/${REL_DIR}/" 2>/dev/null
        
        SIZE=$(stat -c%s "${FOUND}" 2>/dev/null || echo 0)
        echo "  ✅ ${rel_path} (${SIZE} bytes)" | tee -a "${SNAPSHOT_LOG}"
        COPIED=$((COPIED + 1))
    done
    
    echo "" | tee -a "${SNAPSHOT_LOG}"
    echo -e "  ${GREEN}Snapshot salvat: ${COPIED} fișiere, ${MISSING} negăsite${NC}" | tee -a "${SNAPSHOT_LOG}"
    echo -e "  📁 ${SNAP_PATH}" | tee -a "${SNAPSHOT_LOG}"
}

# === ROLLBACK ===
do_rollback() {
    if [ -z "${1}" ]; then
        print_snapshots
        echo ""
        read -p "Numele snapshot-ului pentru rollback: " SNAP_NAME
    else
        SNAP_NAME="${1}"
    fi
    
    SNAP_PATH="${SNAPSHOT_DIR}/${SNAP_NAME}"
    
    if [ ! -d "${SNAP_PATH}" ]; then
        echo -e "${RED}[!] Snapshot-ul '${SNAP_NAME}' nu există.${NC}"
        print_snapshots
        exit 1
    fi
    
    verify_mount || exit 1
    
    echo -e "${YELLOW}⚠️  ROLLBACK — se restaurează fișierele din snapshot-ul ${SNAP_NAME}${NC}"
    echo -e "${YELLOW}   Fișierele curente vor fi SUPRASCRISE.${NC}"
    echo ""
    read -p "Ești sigur? (da/nu): " CONFIRM
    
    if [ "${CONFIRM}" != "da" ]; then
        echo "Rollback anulat."
        exit 0
    fi
    
    RESTORED=0
    
    for rel_path in "${CRITICAL_FILES[@]}"; do
        SRC="${SNAP_PATH}/${rel_path}"
        
        if [ ! -f "${SRC}" ]; then
            continue
        fi
        
        # Find the actual destination (case-insensitive)
        fname=$(basename "${rel_path}")
        DEST=$(find "${MOUNT}" -path "*/${fname}" -not -path "*/snapshots/*" 2>/dev/null | grep -i "$(echo "${rel_path}" | sed 's|/|.*/|g')" | head -n1)
        
        if [ -z "${DEST}" ]; then
            echo "  ⊘ ${rel_path} — destinația nu există pe disc"
            continue
        fi
        
        cp -a "${SRC}" "${DEST}" 2>/dev/null
        echo "  ↩  ${rel_path} — restaurat"
        RESTORED=$((RESTORED + 1))
    done
    
    echo ""
    echo -e "${GREEN}✅ Rollback complet: ${RESTORED} fișiere restaurate${NC}"
    echo -e "${YELLOW}   Repornește pentru a testa. Dacă ceva nu merge, ai snapshot-ul intact.${NC}"
}

# === MAIN ===
case "${1:-snapshot}" in
    snapshot|save|backup)
        do_snapshot
        ;;
    rollback|restore)
        do_rollback "${2}"
        ;;
    list|ls)
        print_snapshots
        ;;
    *)
        echo "Usage:"
        echo "  ./snapshot-system.sh snapshot     — creează backup"
        echo "  ./snapshot-system.sh rollback     — restaurează ultimul snapshot"
        echo "  ./snapshot-system.sh list         — listează snapshot-urile"
        ;;
esac
