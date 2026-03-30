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

# ─────────────────────────────────────────────────────────────────────────────
# Additional mode dry-run tests
# ─────────────────────────────────────────────────────────────────────────────

@test "launch --dry-run shows pipeline preview" {
    run "$RALPH_DIR/ralph.sh" launch --dry-run -p "test" --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"launch"* ]]
    [[ "$output" == *"Pipeline"* ]] || [[ "$output" == *"pipeline"* ]]
}

@test "plan --dry-run exits 0" {
    run "$RALPH_DIR/ralph.sh" plan --dry-run --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"plan"* ]]
}

@test "product --dry-run exits 0" {
    run "$RALPH_DIR/ralph.sh" product --dry-run --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"product"* ]]
}

@test "inline mode via -p --dry-run shows inline mode" {
    run "$RALPH_DIR/ralph.sh" -p "quick fix" --dry-run --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"inline"* ]]
}

@test "inline mode uses sonnet model by default" {
    run "$RALPH_DIR/ralph.sh" -p "quick fix" --dry-run --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"sonnet"* ]]
}

@test "bare --dry-run defaults to build mode" {
    run "$RALPH_DIR/ralph.sh" --dry-run --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"build"* ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Flag behavior tests
# ─────────────────────────────────────────────────────────────────────────────

@test "--test flag sets max iterations to 1" {
    run "$RALPH_DIR/ralph.sh" --test --dry-run --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"1 iteration"* ]]
}

@test "--test flag shows TEST MODE banner" {
    run "$RALPH_DIR/ralph.sh" --test --dry-run --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"TEST MODE"* ]]
}

@test "review mode disables push even with --push" {
    run "$RALPH_DIR/ralph.sh" review --dry-run --push --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"disabled"* ]]
}

@test "--max flag sets iteration count" {
    run "$RALPH_DIR/ralph.sh" --dry-run -n 25 --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"25 iteration"* ]]
}

@test "--no-push flag disables push" {
    run "$RALPH_DIR/ralph.sh" --dry-run --no-push --skip-checks
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"disabled"* ]]
}
