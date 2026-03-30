#!/usr/bin/env bats

# Integration tests — invoke ralph.sh as a subprocess with --dry-run
# These do NOT use the test helper; they run the full script.

setup() {
    RALPH_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    # Force standalone mode so tests work regardless of parent git structure
    export RALPH_HOST_ROOT=""
}

@test "build --dry-run exits 0" {
    run "$RALPH_DIR/ralph.sh" build --dry-run --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Dry run complete"* ]]
}

@test "dev --dry-run shows dev mode" {
    run "$RALPH_DIR/ralph.sh" dev --dry-run -p "test feature" --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"dev"* ]]
}

@test "--help exits 0 with usage" {
    run "$RALPH_DIR/ralph.sh" --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"usage"* ]]
}

@test "review --dry-run shows push disabled" {
    run "$RALPH_DIR/ralph.sh" review --dry-run --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"disabled"* ]]
}

@test "spec --dry-run exits 0" {
    run "$RALPH_DIR/ralph.sh" spec --dry-run -p "test" --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Dry run complete"* ]]
}

@test "--full-product flag shows deprecation error" {
    run "$RALPH_DIR/ralph.sh" --full-product --dry-run --skip-checks
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"no longer supported"* ]] || [[ "$output" == *"Use 'dev'"* ]] || [[ "$output" == *"deprecated"* ]] || [[ "$output" == *"Error"* ]]
}
