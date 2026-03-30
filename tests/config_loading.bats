#!/usr/bin/env bats

# Tests for config file loading (safe_load_config)

setup() {
    source "$BATS_TEST_DIRNAME/test_helper.bash"
    TEST_TMPDIR=$(mktemp -d)

    # Reset globals that safe_load_config checks before setting values
    CLI_MODEL_SET=""
    CLI_SPEC_SET=""
    CLI_PLAN_SET=""
    CLI_PROGRESS_SET=""
    CLI_PUSH_SET=""
    CLI_MAX_SET=""
    CLI_PIPELINE_BUFFER_SET=""
    CLI_LOG_DIR_SET=""
    CLI_LOG_FORMAT_SET=""
    CLI_SOURCE_SET=""
    CLI_WEBHOOK_SET=""
    UNLIMITED=""
    MAX_ITERATIONS_CONFIGURED=""

    # Clear values so config can set them (safe_load_config skips non-empty values)
    MODEL_OVERRIDE=""
    MAX_ITERATIONS=""
    SPEC_FILE=""
    PLAN_FILE=""
    PUSH_ENABLED=""
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

@test "safe_load_config: sets MODEL from config" {
    echo 'MODEL=sonnet' > "$TEST_TMPDIR/test.conf"
    safe_load_config "$TEST_TMPDIR/test.conf" 2>/dev/null || true
    [[ "$MODEL_OVERRIDE" == "sonnet" ]]
}

@test "safe_load_config: sets MAX_ITERATIONS from config" {
    echo 'MAX_ITERATIONS=20' > "$TEST_TMPDIR/test.conf"
    safe_load_config "$TEST_TMPDIR/test.conf" 2>/dev/null || true
    [[ "$MAX_ITERATIONS" == "20" ]]
}

@test "safe_load_config: skips comments and blank lines" {
    cat > "$TEST_TMPDIR/test.conf" << 'EOF'
# This is a comment
MODEL=haiku

# Another comment
EOF
    safe_load_config "$TEST_TMPDIR/test.conf" 2>/dev/null || true
    [[ "$MODEL_OVERRIDE" == "haiku" ]]
}

@test "safe_load_config: warns on unknown key" {
    echo 'UNKNOWN_KEY=value' > "$TEST_TMPDIR/test.conf"
    run safe_load_config "$TEST_TMPDIR/test.conf"
    [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"unknown"* ]] || [[ "$output" == *"Warning"* ]]
}

@test "safe_load_config: rejects shell injection" {
    echo 'SPEC_FILE=$(rm -rf /)' > "$TEST_TMPDIR/test.conf"
    safe_load_config "$TEST_TMPDIR/test.conf" 2>/dev/null || true
    # SPEC_FILE should NOT be set to the injection payload
    [[ "$SPEC_FILE" != '$(rm -rf /)' ]]
}

@test "safe_load_config: missing file is a no-op" {
    run safe_load_config "/nonexistent/file.conf"
    [[ "$status" -eq 0 ]]
}

@test "safe_load_config: strips quotes from values" {
    echo 'MODEL="opus"' > "$TEST_TMPDIR/test.conf"
    safe_load_config "$TEST_TMPDIR/test.conf" 2>/dev/null || true
    [[ "$MODEL_OVERRIDE" == "opus" ]]
}

@test "safe_load_config: PUSH_ENABLED boolean" {
    echo 'PUSH_ENABLED=false' > "$TEST_TMPDIR/test.conf"
    safe_load_config "$TEST_TMPDIR/test.conf" 2>/dev/null || true
    [[ "$PUSH_ENABLED" == "false" ]]
}
