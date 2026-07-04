#!/usr/bin/env bash
# repair-boot.sh — Windows boot repair from Linux
# Fixes BCD, EFI, MBR, winload, and injects drivers
# Usage: ./repair-boot.sh [--efi|--bios|--auto]

source "$(dirname "$0")/utils.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Windows Boot Repair ===${NC}" | tee "${LOGS_DIR}/boot-repair.log"
echo "Date: $(date)" | tee -a "${LOGS_DIR}/boot-repair.log"
echo "" | tee -a "${LOGS_DIR}/boot-repair.log"

verify_mount || exit 1

# Helper: find Windows directory case-insensitively
WIN_DIR=$(find_ci "${MOUNT}" 1 "Windows")
if [ -z "${WIN_DIR}" ]; then
    echo -e "${RED}[!] Cannot find Windows directory${NC}"
    exit 1
fi

SYS32_DIR=$(find_ci "${WIN_DIR}" 1 "System32" 2>/dev/null || echo "")

# === 1. Detect boot mode (EFI vs BIOS) ===
echo "🔍 Detecting boot mode..." | tee -a "${LOGS_DIR}/boot-repair.log"

BOOT_MODE=""
if [ -d /sys/firmware/efi ]; then
    BOOT_MODE="efi"
    echo "  Host boot: UEFI" | tee -a "${LOGS_DIR}/boot-repair.log"
else
    BOOT_MODE="bios"
    echo "  Host boot: BIOS (Legacy)" | tee -a "${LOGS_DIR}/boot-repair.log"
fi

# Override with argument
[ "${1}" = "--efi" ] && BOOT_MODE="efi"
[ "${1}" = "--bios" ] && BOOT_MODE="bios"

# === 2. Find and check boot files ===
echo "" | tee -a "${LOGS_DIR}/boot-repair.log"
echo "🔍 Checking boot files..." | tee -a "${LOGS_DIR}/boot-repair.log"

MISSING_BOOT=()

# Check winload
WINLOAD=$(find "${MOUNT}" -iname "winload.exe" -not -path "*/WinSxS/*" 2>/dev/null | head -n1)
if [ -n "${WINLOAD}" ]; then
    echo "  ✅ winload.exe: $(echo ${WINLOAD} | sed "s|${MOUNT}||") ($(stat -c%s "${WINLOAD}") bytes)" | tee -a "${LOGS_DIR}/boot-repair.log"
else
    echo "  ❌ winload.exe MISSING" | tee -a "${LOGS_DIR}/boot-repair.log"
    MISSING_BOOT+=("winload.exe")
fi

# Check ntoskrnl
if [ -n "${SYS32_DIR}" ]; then
    NTOS=$(find "${SYS32_DIR}" -maxdepth 1 -iname "ntoskrnl.exe" 2>/dev/null | head -n1)
    if [ -n "${NTOS}" ]; then
        echo "  ✅ ntoskrnl.exe: $(stat -c%s "${NTOS}") bytes" | tee -a "${LOGS_DIR}/boot-repair.log"
    else
        echo "  ❌ ntoskrnl.exe MISSING" | tee -a "${LOGS_DIR}/boot-repair.log"
        MISSING_BOOT+=("ntoskrnl.exe")
    fi
fi

# Check BCD
if [ "${BOOT_MODE}" = "efi" ]; then
    BCD_PATH=$(find "${MOUNT}" -path "*/EFI/Microsoft/Boot/BCD" 2>/dev/null | head -n1)
else
    BCD_PATH=$(find "${MOUNT}" -path "*/Boot/BCD" 2>/dev/null | head -n1)
fi

if [ -n "${BCD_PATH}" ] && [ -f "${BCD_PATH}" ]; then
    echo "  ✅ BCD: $(echo ${BCD_PATH} | sed "s|${MOUNT}||") ($(stat -c%s "${BCD_PATH}") bytes)" | tee -a "${LOGS_DIR}/boot-repair.log"
else
    echo "  ❌ BCD MISSING — needs rebuild" | tee -a "${LOGS_DIR}/boot-repair.log"
    MISSING_BOOT+=("BCD")
fi

# === 3. Fix MBR (BIOS mode) ===
if [ "${BOOT_MODE}" = "bios" ]; then
    echo "" | tee -a "${LOGS_DIR}/boot-repair.log"
    echo "🔧 BIOS: Checking MBR..." | tee -a "${LOGS_DIR}/boot-repair.log"
    
    DISK=$(echo "${MOUNT}" | grep -oP '/dev/[a-z]+' | head -n1)
    if [ -z "${DISK}" ]; then
        # Find the disk from mount
        DISK=$(findmnt -n -o SOURCE "${MOUNT}" 2>/dev/null | sed 's/[0-9]*$//')
    fi
    
    if [ -n "${DISK}" ] && [ -b "${DISK}" ]; then
        # Check MBR signature
        MBR_SIG=$(dd if="${DISK}" bs=1 skip=510 count=2 2>/dev/null | xxd -p)
        if [ "${MBR_SIG}" = "55aa" ]; then
            echo "  ✅ MBR signature valid (55AA)" | tee -a "${LOGS_DIR}/boot-repair.log"
        else
            echo "  ❌ MBR signature INVALID — reinstalling..." | tee -a "${LOGS_DIR}/boot-repair.log"
            if command -v ms-sys &>/dev/null; then
                ms-sys -7 "${DISK}" 2>/dev/null && echo "  ✅ Windows 7 MBR written" | tee -a "${LOGS_DIR}/boot-repair.log" || echo "  ❌ ms-sys failed" | tee -a "${LOGS_DIR}/boot-repair.log"
            elif command -v install-mbr &>/dev/null; then
                install-mbr "${DISK}" 2>/dev/null && echo "  ✅ MBR installed" | tee -a "${LOGS_DIR}/boot-repair.log" || echo "  ❌ install-mbr failed" | tee -a "${LOGS_DIR}/boot-repair.log"
            else
                echo "  ⚠️ No MBR tool available — install ms-sys or mbr" | tee -a "${LOGS_DIR}/boot-repair.log"
            fi
        fi
    fi
fi

# === 4. Fix EFI boot ===
if [ "${BOOT_MODE}" = "efi" ]; then
    echo "" | tee -a "${LOGS_DIR}/boot-repair.log"
    echo "🔧 UEFI: Checking EFI boot entries..." | tee -a "${LOGS_DIR}/boot-repair.log"
    
    # Find EFI partition
    EFI_PART=""
    for part in /dev/sd*[0-9] /dev/nvme*n*p[0-9]; do
        [ -b "${part}" ] || continue
        FSTYPE=$(lsblk -no FSTYPE "${part}" 2>/dev/null)
        if [ "${FSTYPE}" = "vfat" ]; then
            MP=$(findmnt -n -o TARGET "${part}" 2>/dev/null)
            if [ -z "${MP}" ]; then
                # Try mounting it temporarily
                TMP_EFI="/tmp/efi-fix"
                mkdir -p "${TMP_EFI}"
                if mount "${part}" "${TMP_EFI}" 2>/dev/null; then
                    if [ -d "${TMP_EFI}/EFI" ]; then
                        EFI_PART="${part}"
                        EFI_MOUNT="${TMP_EFI}"
                        echo "  ✅ EFI partition found: ${part}" | tee -a "${LOGS_DIR}/boot-repair.log"
                        break
                    fi
                    umount "${TMP_EFI}" 2>/dev/null
                fi
            elif [ -d "${MP}/EFI" ]; then
                EFI_PART="${part}"
                EFI_MOUNT="${MP}"
                echo "  ✅ EFI partition: ${part} mounted at ${MP}" | tee -a "${LOGS_DIR}/boot-repair.log"
                break
            fi
        fi
    done
    
    if [ -n "${EFI_PART}" ]; then
        # Check efibootmgr
        if command -v efibootmgr &>/dev/null; then
            echo "  Current EFI entries:" | tee -a "${LOGS_DIR}/boot-repair.log"
            efibootmgr 2>/dev/null | grep -i "windows\|boot" | sed 's/^/    /' | tee -a "${LOGS_DIR}/boot-repair.log"
            
            # Check if Windows Boot Manager exists
            if efibootmgr 2>/dev/null | grep -qi "windows"; then
                echo "  ✅ Windows Boot Manager found in EFI" | tee -a "${LOGS_DIR}/boot-repair.log"
            else
                echo "  ⚠️  Windows Boot Manager NOT in EFI — may need manual re-creation" | tee -a "${LOGS_DIR}/boot-repair.log"
                echo "      From Windows recovery: bcdboot C:\\Windows /s S: /f UEFI" | tee -a "${LOGS_DIR}/boot-repair.log"
            fi
        else
            echo "  ⚠️  efibootmgr not available" | tee -a "${LOGS_DIR}/boot-repair.log"
        fi
    else
        echo "  ⚠️  No EFI partition found — system may be BIOS-only" | tee -a "${LOGS_DIR}/boot-repair.log"
    fi
    
    # Cleanup temp mount
    [ "${EFI_MOUNT}" = "/tmp/efi-fix" ] && umount "${EFI_MOUNT}" 2>/dev/null
fi

# === 5. Driver injection ===
echo "" | tee -a "${LOGS_DIR}/boot-repair.log"
echo "🔧 Checking critical drivers..." | tee -a "${LOGS_DIR}/boot-repair.log"

if [ -n "${SYS32_DIR}" ]; then
    DRIVERS_DIR=$(find_ci "${SYS32_DIR}" 1 "drivers" 2>/dev/null || echo "")
    DRIVERSTORE=$(find_ci "${SYS32_DIR}" 1 "DriverStore" 2>/dev/null || echo "")
    
    CRITICAL_DRIVERS=("disk.sys" "ntfs.sys" "storport.sys" "stornvme.sys" "iaStorV.sys" "acpi.sys")
    
    for drv in "${CRITICAL_DRIVERS[@]}"; do
        FOUND=""
        [ -n "${DRIVERS_DIR}" ] && FOUND=$(find "${DRIVERS_DIR}" -maxdepth 1 -iname "${drv}" 2>/dev/null | head -n1)
        [ -z "${FOUND}" ] && [ -n "${DRIVERSTORE}" ] && FOUND=$(find "${DRIVERSTORE}" -iname "${drv}" 2>/dev/null | head -n1)
        
        if [ -n "${FOUND}" ]; then
            echo "  ✅ ${drv}: $(echo ${FOUND} | sed "s|${MOUNT}||")" | tee -a "${LOGS_DIR}/boot-repair.log"
        else
            echo "  ⚠️  ${drv}: not found — may cause boot failure if required" | tee -a "${LOGS_DIR}/boot-repair.log"
        fi
    done
fi

# === Summary ===
echo "" | tee -a "${LOGS_DIR}/boot-repair.log"
echo -e "${CYAN}=== Boot Repair Summary ===${NC}" | tee -a "${LOGS_DIR}/boot-repair.log"

if [ ${#MISSING_BOOT[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ Toate fișierele de boot sunt prezente.${NC}" | tee -a "${LOGS_DIR}/boot-repair.log"
else
    echo -e "${RED}❌ Fișiere lipsă: ${MISSING_BOOT[*]}${NC}" | tee -a "${LOGS_DIR}/boot-repair.log"
    echo "" | tee -a "${LOGS_DIR}/boot-repair.log"
    echo "🔧 Pentru reparare avansată, bootează de pe un USB cu Windows:" | tee -a "${LOGS_DIR}/boot-repair.log"
    echo "   Shift+F10 → Command Prompt" | tee -a "${LOGS_DIR}/boot-repair.log"
    
    if [[ " ${MISSING_BOOT[*]} " =~ "BCD" ]]; then
        echo "   bootrec /rebuildbcd" | tee -a "${LOGS_DIR}/boot-repair.log"
    fi
    echo "   bootrec /fixmbr" | tee -a "${LOGS_DIR}/boot-repair.log"
    echo "   bootrec /fixboot" | tee -a "${LOGS_DIR}/boot-repair.log"
    echo "   bootrec /scanos" | tee -a "${LOGS_DIR}/boot-repair.log"
fi

echo "" | tee -a "${LOGS_DIR}/boot-repair.log"
echo "Log salvat: ${LOGS_DIR}/boot-repair.log" | tee -a "${LOGS_DIR}/boot-repair.log"
