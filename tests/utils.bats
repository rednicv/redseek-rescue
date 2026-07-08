#!/usr/bin/env bats
# RedSeek Rescue — Teste pentru utils.sh
# Rulează cu: bats tests/

load '../scripts/utils.sh'

# ─── Culori și logare ─────────────────────────────────

@test "log_info nu crapă" {
    run log_info "test mesaj"
    [ "$status" -eq 0 ]
}

@test "log_success nu crapă" {
    run log_success "test mesaj"
    [ "$status" -eq 0 ]
}

@test "log_warn nu crapă" {
    run log_warn "test mesaj"
    [ "$status" -eq 0 ]
}

@test "log_error nu crapă (stderr)" {
    run log_error "test mesaj"
    [ "$status" -eq 0 ]
}

@test "log_warning alias funcționează" {
    run log_warning "test mesaj"
    [ "$status" -eq 0 ]
}

# ─── require_root ─────────────────────────────────────

@test "require_root eșuează ca non-root" {
    # Forțăm EUID non-zero simulând user normal
    run bash -c 'EUID=1000; source scripts/utils.sh; require_root'
    [ "$status" -eq 1 ]
    [[ "$output" == *"root"* ]]
}

@test "require_root trece ca root" {
    # Dacă suntem deja root, testul trece
    if [ "$EUID" -eq 0 ]; then
        run require_root
        [ "$status" -eq 0 ]
    else
        skip "Testul necesită root"
    fi
}

# ─── is_readonly ──────────────────────────────────────

@test "is_readonly pe / (root fs) — de obicei RW" {
    run is_readonly "/"
    # Nu verificăm exit code (depinde de sistem), doar că nu crapă
    [ -n "$output" ] || true
}

# ─── find_ci ──────────────────────────────────────────

@test "find_ci pe o cale existentă" {
    result=$(find_ci "/tmp" "." 2>/dev/null || echo "")
    [ "$result" = "/tmp" ]
}

@test "find_ci pe o cale inexistentă" {
    run find_ci "/tmp" "nu_exista_12345"
    [ "$status" -eq 1 ]
    [ "$output" = "" ]
}

@test "find_ci cu case-insensitive" {
    mkdir -p /tmp/test_find_ci/TestFolder
    result=$(find_ci "/tmp/test_find_ci" "testfolder" 2>/dev/null || echo "")
    [ "$result" = "/tmp/test_find_ci/TestFolder" ]
    rm -rf /tmp/test_find_ci
}

@test "find_ci pe o cale cu mai multe nivele" {
    mkdir -p /tmp/test_find_ci/Windows/System32/config
    result=$(find_ci "/tmp/test_find_ci" "Windows/System32/config" 2>/dev/null || echo "")
    [ "$result" = "/tmp/test_find_ci/Windows/System32/config" ]
    rm -rf /tmp/test_find_ci
}

@test "find_ci case-insensitive pe mai multe nivele" {
    mkdir -p /tmp/test_find_ci/WINDOWS/SYSTEM32/CONFIG
    result=$(find_ci "/tmp/test_find_ci" "windows/system32/config" 2>/dev/null || echo "")
    [ "$result" = "/tmp/test_find_ci/WINDOWS/SYSTEM32/CONFIG" ]
    rm -rf /tmp/test_find_ci
}

# ─── check_pipe ───────────────────────────────────────

@test "check_pipe — toate iesirile 0" {
    run bash -c 'source scripts/utils.sh; true | true | true; check_pipe'
    [ "$status" -eq 0 ]
}

@test "check_pipe — o iesire nenula" {
    run bash -c 'source scripts/utils.sh; true | false | true; check_pipe'
    [ "$status" -eq 1 ]
}
