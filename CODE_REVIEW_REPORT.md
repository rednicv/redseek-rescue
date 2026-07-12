# RedSeek Rescue — Code Review Report

**Date:** 2026-07-05  
**Branches analyzed:** `main` (c320cc9), `origin/v1.4.1-fixes`  
**Files analyzed:** 33 source files (17 scripts, 2 config files, 7 docs, 3 GitHub templates, 2 build files, 1 SKILL.md, 1 .gitignore)  

---

## CRITICAL (8 issues — must fix)

### C1. Shell syntax error: Mismatched closing delimiter in `reset-password.sh`
**File:** `scripts/reset-password.sh` (main branch, not fixed in v1.4.1-fixes)  
**Lines:** 65, 69, 112  
```bash
65:  echo "    1. Select '1'..." | tee -a "${LOGS_DIR}/reset-password.log}"    # } instead of "
69:  echo "" | tee -a "${LOGS_DIR}/reset-password.log}                         # } instead of "
112: echo "    2. A cmd prompt opens as SYSTEM" | tee -a "${LOGS_DIR}/reset-password.log}  # } instead of "
```
These three lines end with `log}"` instead of `log"`. This is a **literal syntax error** — bash will try to interpret the `}` and may break the script or produce garbled output. The `reset_password()` and `utilman_hack()` functions are affected.

### C2. Shell syntax error: Missing closing quote in `reset-password.sh` lines 69, 112
**File:** `scripts/reset-password.sh` (main branch, not fixed in v1.4.1-fixes)  
**Lines:** 69, 112  
```bash
69:  echo "" | tee -a "${LOGS_DIR}/reset-password.log}        # missing closing " before }
112: echo "    2. A cmd prompt opens as SYSTEM" | tee -a "${LOGS_DIR}/reset-password.log}  # same bug
```
Both lines lack the closing `"` before the `}`. Line 69's missing quote cascades into line 111, causing a parse error (`unexpected EOF`). `bash -n` confirms: `syntax error near unexpected token '('` at line 111 (because the unclosed string bleeds into the next function).

### C3. Shell injection via `SERVICE_NAME` in `registry-tools.sh`
**File:** `scripts/registry-tools.sh`, lines 77, 149, 216 (main branch)  
**Severity:** Security — arbitrary code execution

The `SERVICE_NAME` command-line argument is interpolated directly into an inline Python script via `'${SERVICE_NAME}'`:
```python
svc_name = '${SERVICE_NAME}'.lower()
```
An attacker with terminal access (the live USB has a shell!) could pass a service name like:
```
'; import os; os.system('rm -rf /mnt/windows/Windows') #
```
This would execute arbitrary Python. While the rescue environment is already root, this undermines the safety promises made to users. **Fix:** Pass `SERVICE_NAME` via environment variable or JSON stdin.

### C4. `utilman.exe` hack doesn't handle case-insensitive NTFS paths
**File:** `scripts/reset-password.sh`, lines 95-100, 119-121 (main branch)  
The `utilman_hack()` function uses hardcoded paths:
```bash
SYSTEM32="${MOUNT}/Windows/System32"
```
On a system where Windows is installed as "WINDOWS" or "windows", this path won't exist, but `cmd.exe` and `utilman.exe` are there. The script should use `find_ci` from `utils.sh`.

### C5. `sudo lb config` creates root-owned files that break subsequent non-sudo operations
**File:** `build.sh` (v1.4.1-fixes, line 68 — `sudo lb config`)  
When `lb config` runs as root (via `sudo`), it creates config files under `config/` owned by root. Subsequent operations — copying scripts, creating hooks — may fail if the user is not root. In main branch, `lb config` runs as user (if user has write perms in build/). The v1.4.1-fixes diff adds `sudo lb config` but may create a permission mismatch for later `cp -r` operations.

### C6. `detect_usb` subshell/pipeline bug in `backup-data.sh` (v1.4.1-fixes)
**File:** `scripts/backup-data.sh` (v1.4.1-fixes), `detect_usb()` function  
The function pipes `lsblk ... | while read` — the `while` loop runs in a subshell, so variables set inside (`echo "${mp}"`) will print but a `return` inside the loop won't propagate out properly. The function may output multiple lines or fail to exit early. This is a well-known bash pitfall.

### C7. Credential exposure: API key in `build.sh` Python code
**File:** `build.sh`, lines 25-31 (main), v1.4.1-fixes lines 25-37  
The Python snippet that extracts the DeepSeek API key is embedded in the build script. If `build.sh` is shared or accidentally committed with logging output, the key appears in `build.log`. While `.gitignore` protects `hermes-config.yaml`, the key is echoed through the sed operation in main branch. The v1.4.1-fixes version uses Python `replace()` to substitute — safer but still writes the key into `config/hermes-config.yaml` which, while `.gitignore`d, lives on disk raw.

### C8. `make-iso.sh` assumes `/usr/lib/ISOLINUX/isohdpfx.bin` exists
**File:** `make-iso.sh` (v1.4.1-fixes), line 73  
```bash
-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin
```
This path is Debian/Ubuntu specific. On other distros (Arch: `/usr/lib/syslinux/bios/mbr.bin`, Fedora: `/usr/share/syslinux/...`), the build will fail. The script should check if the file exists and search alternate locations.

---

## WARNING (14 issues — should fix)

### W1. Only 2 scripts comply with project's own `set -euo pipefail` standard
**CONTRIBUTING.md** mandates `set -euo pipefail`. Compliance:
- ✅ `build.sh`, `registry-tools.sh`
- ❌ `backup-data.sh`, `cleanup-updates.sh`, `diagnose.sh`, `download-antivirus.sh`, `hardware-diagnostics.sh`, `mount-windows.sh`, `parse-evtx.sh`, `reset-password.sh`, `scan-windows.sh`, `shadow-copy.sh`, `unmount-windows.sh`, `verify-files.sh`, `wifi-connect.sh`
- ❌ `make-iso.sh` (v1.4.1-fixes), all new v1.4.1-fixes scripts

All 13 scripts use bare `set -e` only. Without `-u`, uninitialized variables silently expand to empty. Without `-o pipefail`, a command like `grep ... | head` can succeed even if `grep` fails.

### W2. `rescue-prompt.txt` instructs insecure `sed` for API key injection
**File:** `config/rescue-prompt.txt`, line 36:
```
sed -i "s|DEEPSEEK_API_KEY_HERE|<the_key>|" /home/rescue/.hermes/config.yaml
```
Same vulnerability as the old `build.sh` (which v1.4.1-fixes fixed). If the key contains `|` or special chars, `sed` breaks. Should use Python `replace()` like v1.4.1-fixes `build.sh`.

### W3. API key stored in cleartext on live system
**Files:** `build.sh` (creates `config/hermes-config.yaml` with real key), `install-hermes.sh` chroot hook (copies to `/home/rescue/.hermes/config.yaml`)  
The key lives in plaintext at two paths. The SECURITY.md acknowledges this ("ephemeral — no persistence between boots"). Acceptable for a live USB but worth documenting more visibly in the README.

### W4. `is_readonly()` in `utils.sh` uses fragile file-based parsing
**File:** `scripts/utils.sh` (v1.4.1-fixes), line 27:
```bash
is_readonly() {
    if [ -f "${STATUS_FILE}" ]; then
        grep -q "ro" "${STATUS_FILE}" 2>/dev/null && return 0
    fi
    return 1
}
```
`grep -q "ro"` matches any line containing `ro` — including partial matches like "error" or "zero". Should use `grep -qx "ro"` or better yet, read from `mount`/`findmnt` output which is structural.

### W5. `verify_mount()` uses `return 1` under `set -e` — may not work as expected
**File:** `scripts/utils.sh` (v1.4.1-fixes), `verify_mount()`  
When called as `verify_mount || exit 1`, it works. But when called as `verify_mount || { echo ...; }` the function's `return 1` under scripts that lack `set +e` locally may cause unexpected termination before reaching `||`.

### W6. `rescue-gui.sh` (v1.4.1-fixes) pipes all script output through zenity — errors swallowed
**File:** `scripts/rescue-gui.sh`, lines 103-160  
Every repair action pipes through `zenity --text-info`. If a script fails, the user sees "Rulare..." with no diagnostic. Error codes are silently discarded. Should check `${PIPESTATUS[0]}` and show error dialogs.

### W7. `scan-windows.sh`: `clamscan --infected` only reports — doesn't quarantine/delete
**File:** `scripts/scan-windows.sh`, lines 31-37  
The scan uses `--infected` (flag means "only print infected files"), but doesn't `--remove` or `--move`. The user manual step at line 55 suggests doing it manually. For a rescue tool, offering auto-quarantine would be better UX.

### W8. `hardware-diagnostics.sh`: `memtester` exit code unchecked
**File:** `scripts/hardware-diagnostics.sh`, line 34:
```bash
memtester "${TEST_SIZE}M" 1 2>&1 | tee -a "${OUTPUT}" || echo "⚠️ Memory test FAILED"
```
With `set -e` active, if `memtester` returns non-zero (which it does when finding errors), the script will exit on the `||` because `echo` always succeeds — but the user never sees the failure message. Need `set +e`/`|| true` guard.

### W9. `scan-windows.sh`: `set +e` / `set -e` toggle fragile around `clamscan`
**File:** `scripts/scan-windows.sh`, lines 28, 37:
```bash
set +e
clamscan ... | tee ...
set -e
```
If the `tee` fails (e.g., disk full), `set -e` never gets re-enabled. Use subshell or trap. Also the `set -e` on line 37 conflicts with the pipe.

### W10. `make-iso.sh`: Kernel rename uses glob that may match multiple files
**File:** `make-iso.sh` (v1.4.1-fixes), lines 26-28:
```bash
if ls "$ISO_DIR/$KERNEL_DIR"/vmlinuz-* &>/dev/null; then
    mv "$ISO_DIR/$KERNEL_DIR"/vmlinuz-* "$ISO_DIR/$KERNEL_DIR/vmlinuz"
fi
```
If multiple kernel versions exist, `mv` will fail (target is not a directory). Should use `head -n1` logic.

### W11. `rescue-playbook.sh` (v1.4.1-fixes): `${PIPESTATUS[0]}` accessed incorrectly
**File:** `scripts/rescue-playbook.sh`, line with `${PIPESTATUS[0]}`
```bash
if bash "${SCRIPT_PATH}" 2>&1 | sed 's/^/  │ /'; then
    ...
else
    echo "... (exit code: ${PIPESTATUS[0]})"
```
`${PIPESTATUS[0]}` gives the exit code of `bash "${SCRIPT_PATH}"` but only if accessed immediately after the pipeline. Inside `else`, it may already be lost. The `if` check itself uses the pipeline's exit status (`sed` success), not the script's. Should save `$?` explicitly.

### W12. `download-antivirus.sh`: Downloaded EXE files not hash-verified
**File:** `scripts/download-antivirus.sh`  
Three antivirus EXEs are downloaded via `curl -sL` with no hash verification. A compromised mirror or MITM could serve malware. Should use `curl --pinnedpubkey` or at minimum document expected SHA256 hashes.

### W13. `mount-windows.sh` (main): `DEV` extraction fragile for NVMe
**File:** `scripts/shadow-copy.sh`, line 21:
```bash
WIN_DEV=$(findmnt -n -o SOURCE "${MOUNT}" | sed 's/[0-9]*$//')
```
For `/dev/nvme0n1p3`, this yields `/dev/nvme0n1p` (the `p` remains). The `vshadowinfo` call on a non-existent device will fail silently. The backup path on line 24 also doesn't handle NVMe naming correctly.

### W14. `rescue-prompt.txt` references scripts not in v1.4.1-fixes tree
**File:** `config/rescue-prompt.txt`  
References `diagnose.sh --quick` and `diagnose.sh --full` as separate modes, but the actual `diagnose.sh` script only supports `--quick` and `--full` as arguments. The prompt's manual mode lists `diagnose.sh` without args — fine but the AI flow uses `--quick` correctly.

---

## INFO (18 items — suggestions for improvement)

### I1. No CI/CD pipeline (GitHub Actions)
Zero `.github/workflows/` files. Should have:
- Shell syntax check: `bash -n` on every script
- Lint: `shellcheck` on all `.sh` files
- Build test: Attempt `lb config` (dry-run) to validate package names exist for `noble`
- ISO boot test: Boot the ISO in QEMU and verify Hermes starts

### I2. ISO_NAME hardcoded as `v1.0` even in v1.4.1-fixes
**File:** `build.sh`, line 12 (both branches):
```bash
ISO_NAME="redseek-rescue-v1.0"
```
Should be auto-derived from `git describe --tags` or at minimum updated for each release.

### I3. README badges show version `1.0` — stale in v1.4.1-fixes
**File:** `README.md`, line 1 (v1.4.1-fixes):
```markdown
[![Version](https://img.shields.io/badge/version-1.0-blue.svg)]
```
The v1.4.1-fixes CHANGELOG describes versions 1.0.2, 1.1.0, 1.3.0 but the badge still says 1.0.

### I4. `README.md` (v1.4.1-fixes) removed Contributing, Security, and Code of Conduct sections
The v1.4.1-fixes README removed the bottom sections that linked to `CONTRIBUTING.md`, `SECURITY.md`, and `CODE_OF_CONDUCT.md`. These links exist in the files but users can't find them from the main README anymore.

### I5. `CHANGELOG.md` has inconsistent formatting between branches
- `main`: lists 1.0.0 and 1.0.1 with detailed itemized entries
- `v1.4.1-fixes`: lists 1.0.0 through 1.3.0 with sketchier entries for 1.0.0 (collapsed into one line)  
The v1.4.1-fixes version mentions 1.0.2 and 1.1.0 but no 1.2.0 or 1.4.0 in the changelog — yet GitHub has releases for 1.2.0, 1.3.0, 1.4.0.

### I6. `chroot-custom/` directory exists but is empty
**File:** Directory referenced as `${CHROOT_CUSTOM}` in `build.sh` but contains no files. Either populate it or remove the variable.

### I7. `iso-overlay/` appears empty
**File:** Referenced at line 168: `cp -r "${ISO_OVERLAY}/"* ...` with `|| true` fallback. If empty, remove the cp or populate it.

### I8. `build.log` checked into git (main branch)
**File:** `/home/ubuntu/deepseekrescue/build.log`  
A build log file is present in the repo (not gitignored — `.gitignore` only lists `build.log` in root but apparently it exists). Contains potentially sensitive build output including partial paths.

### I9. Mixed languages in scripts
Some scripts use Romanian strings mixed with English:
- `diagnose.sh` — English
- `cleanup-updates.sh` — English
- `rescue-playbook.sh` — Romanian symptoms + English commands
- `download-antivirus.sh` — Romanian  
Consistency would help maintainers. Pick one language for command output.

### I10. `rescue-gui.sh` (v1.4.1-fixes) uses `apt-get` in a live environment
```bash
apt-get update -qq && apt-get install -y -qq zenity
```
On a live USB without internet, this hangs. Should check connectivity first and offer fallback. Also, `apt-get` needs `sudo`.

### I11. `auto-diagnose.sh` (v1.4.1-fixes) scoring math has a bug
**File:** `scripts/auto-diagnose.sh`, line ~175:
```bash
pct=$((score * 100 / 130))  # Normalize to ~100%
```
If `score` can exceed 130 (possible if multiple problems compound), `pct` exceeds 100 — the code handles this with `[ "${pct}" -gt 100 ] && pct=100`, but the normalization factor of 130 is arbitrary and undocumented.

### I12. `install-hermes.sh` chroot hook uses bare `pip install`
**File:** build.sh interior heredoc, both branches:
```bash
pip install python-evtx 2>/dev/null || true    # main
python3 -m pip install python-evtx 2>/dev/null || true  # v1.4.1-fixes
```
The v1.4.1-fixes version uses `python3 -m pip` (correct for pipx-managed Python) but still uses `--break-system-packages` implicitly on newer pip. Should add `--break-system-packages` explicitly for Ubuntu 24.04.

### I13. `wifi-connect.sh`: Password visible in process list
**File:** `scripts/wifi-connect.sh`, lines 41, 60:
```bash
nmcli device wifi connect "${SSID}" password "${PASSWORD}"
```
The WiFi password is passed as a command-line argument and visible in `/proc/*/cmdline` to any user on the live system. Should use `nmcli connection modify` or `wpa_passphrase` + `wpa_supplicant` to avoid exposing the password.

### I14. Missing `--no-install-recommends` in `lb config`
**File:** `build.sh`, lines 54-64 (both branches)  
The `lb config` doesn't pass `--apt-options "--no-install-recommends"`. The package list includes heavyweight packages (`wine64`, `clamav-daemon`) that pull in many recommended dependencies, bloating the ISO.

### I15. No `scripts/test/` or test framework
No shell script tests. At minimum, `bash -n` on all scripts would catch C1 and C2. A `bats` test suite would be ideal for the rescue scripts.

### I16. `SECURITY.md` lists "coming soon" for private vulnerability reporting
**File:** `SECURITY.md`, line 9: "Open a private vulnerability report (coming soon)"  
GitHub has supported private vulnerability reporting for years. Enable it.

### I17. `.gitignore` excludes `*.iso` but `output/redseek-rescue-v1.0.iso` exists in the repo
**File:** `.gitignore` lists `*.iso` but the file `output/redseek-rescue-v1.0.iso` was committed. Either the `.gitignore` was added after the file was tracked, or `output/` exclusion should cover it. Needs `git rm --cached`.

### I18. `make-iso.sh` has no help/usage mode
**File:** `make-iso.sh` (v1.4.1-fixes)  
Running with zero args shows an error because `${1:-build/chroot}` assumes `build/chroot` exists. Should show usage: `./make-iso.sh <chroot_dir> <output.iso>`.

---

## Summary by File

| File | CRITICAL | WARNING | INFO |
|------|----------|---------|------|
| `build.sh` (main) | C7 | W1 | I2, I3, I6, I7, I8 |
| `build.sh` (v1.4.1-fixes) | C5, C7 | W1 | I2, I3, I12 |
| `make-iso.sh` (v1.4.1-fixes) | C8 | W10 | I18 |
| `scripts/reset-password.sh` | C1, C2, C4 | W1 | — |
| `scripts/shadow-copy.sh` | — | W1, W13 | Filename typo: line 11 writes to `*.log}` |
| `scripts/registry-tools.sh` | C3 | W1 | — |
| `scripts/backup-data.sh` (v1.4.1-fixes) | C6 | W1 | — |
| `scripts/mount-windows.sh` (v1.4.1-fixes) | — | W1 | — |
| `scripts/cleanup-updates.sh` (v1.4.1-fixes) | — | W1 | — |
| `scripts/check-windows.sh` (v1.4.1-fixes) | — | W1 | — |
| `scripts/parse-evtx.sh` (v1.4.1-fixes) | — | W1 | — |
| `scripts/hardware-diagnostics.sh` | — | W1, W8 | — |
| `scripts/scan-windows.sh` | — | W1, W7, W9 | — |
| `scripts/rescue-gui.sh` (v1.4.1-fixes) | — | W6 | I10 |
| `scripts/rescue-playbook.sh` (v1.4.1-fixes) | — | W11 | — |
| `scripts/auto-diagnose.sh` (v1.4.1-fixes) | — | — | I11 |
| `scripts/wifi-connect.sh` | — | W1 | I13 |
| `scripts/download-antivirus.sh` | — | W1, W12 | — |
| `scripts/utils.sh` (v1.4.1-fixes) | — | W4, W5 | — |
| `config/rescue-prompt.txt` | — | W2, W14 | — |
| `config/hermes-config.yaml.example` | — | W3 | — |
| `.gitignore` | — | — | I17 |
| `README.md` | — | — | I3, I4 |
| `CHANGELOG.md` | — | — | I5 |
| `SECURITY.md` | — | — | I16 |
| `.github/` | — | — | I1 |

---

## Top 5 Actions (Priority Order)

1. **Fix C1, C2** — The syntax errors in `reset-password.sh` (lines 65, 69, 112) break password reset and utilman hack functions entirely
2. **Fix C3** — The shell injection in `registry-tools.sh` is a real security issue even in a rescue environment
3. **Add CI** — A simple GitHub Action running `shellcheck` + `bash -n` on all scripts would catch C1, C2, W1, and many more
4. **Standardize on `set -euo pipefail`** — all 13 non-compliant scripts should be updated; add `source utils.sh` to every script that duplicates MOUNT/LOGS_DIR paths
5. **Fix C4, C5, C6** — the remaining criticals (case-insensitive paths, sudo permission mismatch, subshell bug)
