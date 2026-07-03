#!/usr/bin/env bash
# hardware-diagnostics.sh — Test RAM, CPU, disk health from Linux live USB
# Run this if Windows symptoms suggest hardware failure
set -e

LOGS_DIR="/opt/rescue/logs"
OUTPUT="${LOGS_DIR}/hardware-diagnostics.txt"

echo "=== Hardware Diagnostics ===" | tee "${OUTPUT}"
echo "Date: $(date)" | tee -a "${OUTPUT}"
echo "" | tee -a "${OUTPUT}"

# 1. CPU Info & Temperature
echo "--- CPU ---" | tee -a "${OUTPUT}"
cat /proc/cpuinfo | grep "model name" | head -1 | tee -a "${OUTPUT}"
echo "Cores: $(nproc)" | tee -a "${OUTPUT}"

if command -v sensors &>/dev/null; then
  echo "Temperatures:" | tee -a "${OUTPUT}"
  sensors 2>/dev/null | grep -E "Core|Package|temp" | head -10 | tee -a "${OUTPUT}" || echo "  (no sensors detected)" | tee -a "${OUTPUT}"
fi

echo "" | tee -a "${OUTPUT}"

# 2. Memory test (quick, non-destructive)
echo "--- RAM Quick Test ---" | tee -a "${OUTPUT}"
TOTAL_RAM=$(free -m | grep Mem | awk '{print $2}')
echo "Total RAM: ${TOTAL_RAM} MB" | tee -a "${OUTPUT}"

if command -v memtester &>/dev/null; then
  TEST_SIZE=$((TOTAL_RAM / 4))
  [ "${TEST_SIZE}" -gt 2048 ] && TEST_SIZE=2048
  echo "Running memtester ${TEST_SIZE}M (1 iteration)..." | tee -a "${OUTPUT}"
  memtester "${TEST_SIZE}M" 1 2>&1 | tee -a "${OUTPUT}" || echo "⚠️  Memory test FAILED - possible bad RAM" | tee -a "${OUTPUT}"
else
  echo "memtester not installed" | tee -a "${OUTPUT}"
fi

echo "" | tee -a "${OUTPUT}"

# 3. Disk stress test (read-only)
echo "--- Disk Read Test ---" | tee -a "${OUTPUT}"
for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
  [ -b "${disk}" ] || continue
  DISK_NAME=$(basename "${disk}")
  echo "Testing: ${disk}" | tee -a "${OUTPUT}"
  
  # Quick read test
  dd if="${disk}" of=/dev/null bs=1M count=100 2>&1 | tail -1 | tee -a "${OUTPUT}" || echo "  ⚠️  Read error on ${disk}" | tee -a "${OUTPUT}"
done

echo "" | tee -a "${OUTPUT}"

# 4. SMART status
echo "--- SMART Status ---" | tee -a "${OUTPUT}"
for disk in /dev/sd[a-z] /dev/nvme[0-9]n[0-9]; do
  [ -b "${disk}" ] || continue
  if smartctl -H "${disk}" 2>/dev/null | grep -q "PASSED"; then
    echo "  ✅ ${disk}: HEALTHY" | tee -a "${OUTPUT}"
    smartctl -A "${disk}" 2>/dev/null | grep -E "Reallocated_Sector|Current_Pending|Uncorrectable|Temperature_Celsius|Wear_Leveling|Media_Wearout" | tee -a "${OUTPUT}" || true
  elif smartctl -H "${disk}" 2>/dev/null | grep -q "FAILED"; then
    echo "  ❌ ${disk}: FAILING!" | tee -a "${OUTPUT}"
  else
    echo "  ⚠️  ${disk}: SMART not available" | tee -a "${OUTPUT}"
  fi
done

echo "" | tee -a "${OUTPUT}"

# 5. CPU stress test (optional, 2 min)
echo "--- CPU Stress Test (2 min) ---" | tee -a "${OUTPUT}"
if command -v stress-ng &>/dev/null; then
  echo "  Running stress-ng for 120s (CPU only)..." | tee -a "${OUTPUT}"
  echo "  Watch temps above. If system shuts down = overheating." | tee -a "${OUTPUT}"
  timeout 120 stress-ng --cpu 1 --timeout 120s --metrics-brief 2>&1 | tail -3 | tee -a "${OUTPUT}" || echo "  ⚠️  Stress test stopped (overheat?)" | tee -a "${OUTPUT}"
else
  echo "  stress-ng not installed" | tee -a "${OUTPUT}"
fi

echo "" | tee -a "${OUTPUT}"
echo "=== Diagnostics Complete ===" | tee -a "${OUTPUT}"
echo "Report: ${OUTPUT}" | tee -a "${OUTPUT}"
