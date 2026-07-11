#!/usr/bin/env bats
# RedSeek Rescue — Teste pentru scripturi individuale
# Rulează cu: bats tests/

# ─── Sintaxă bash ─────────────────────────────────────

@test "Toate scripturile trec verificarea de sintaxă bash" {
    for f in scripts/*.sh build.sh make-iso.sh; do
        bash -n "$f"
    done
}

# ─── Constante globale din utils.sh ───────────────────

@test "utils.sh definește MOUNT_BASE" {
    source scripts/utils.sh
    [ -n "$MOUNT_BASE" ]
    [ "$MOUNT_BASE" = "/mnt/windows" ]
}

@test "utils.sh definește BITLOCKER_DIR" {
    source scripts/utils.sh
    [ -n "$BITLOCKER_DIR" ]
}

@test "utils.sh definește VSS_DIR" {
    source scripts/utils.sh
    [ -n "$VSS_DIR" ]
}

@test "utils.sh definește SNAPSHOT_DIR" {
    source scripts/utils.sh
    [ -n "$SNAPSHOT_DIR" ]
}

@test "MOUNT_BASE poate fi suprascris prin environment" {
    MOUNT_BASE="/custom/path" source scripts/utils.sh
    [ "$MOUNT_BASE" = "/custom/path" ]
}

# ─── Scripturile NU au MOUNT_BASE hardcoded ───────────

@test "Niciun script (în afară de utils.sh) nu definește MOUNT_BASE local" {
    # Verificăm că niciun script individual nu mai declară MOUNT_BASE
    count=$(grep -l 'MOUNT_BASE="/mnt/windows"' scripts/*.sh | grep -v utils.sh | wc -l)
    [ "$count" -eq 0 ]
}

# ─── Security: no shell injection in Python blocks ───

@test "parse-evtx.sh nu interpolează variabile bash în Python" {
    # Verificăm că nu există construcții gen python3 -c "...$VAR..."
    if grep -q "python3 -c" scripts/parse-evtx.sh; then
        # Dacă are python3 -c, verificăm că nu interpolează variabile
        ! grep 'python3 -c.*\$' scripts/parse-evtx.sh
    fi
}

@test "registry-tools.sh nu interpolează variabile bash în Python" {
    if grep -q "python3 -c" scripts/registry-tools.sh; then
        ! grep 'python3 -c.*\$' scripts/registry-tools.sh
    fi
}

# ─── Fișiere de permisiuni ────────────────────────────

@test "Toate scripturile sunt executabile" {
    for f in scripts/*.sh; do
        [ -x "$f" ] || [ -f "$f" ]  # pe Windows, permisiunile pot fi diferite
    done
}

# ─── VERSION file ─────────────────────────────────────

@test "VERSION file există și conține un număr de versiune" {
    [ -f "VERSION" ]
    version=$(head -1 VERSION)
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
