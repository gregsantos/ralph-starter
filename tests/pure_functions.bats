#!/usr/bin/env bats

# Unit tests for pure functions in ralph.sh

setup() {
    source "$BATS_TEST_DIRNAME/test_helper.bash"
}

# ─────────────────────────────────────────────────────────────────────────────
# slugify_text
# ─────────────────────────────────────────────────────────────────────────────

@test "slugify_text: lowercases input" {
    result=$(slugify_text "Add Dark Mode")
    [[ "$result" == "add-dark-mode" ]]
}

@test "slugify_text: strips special characters" {
    result=$(slugify_text "Hello World!!!")
    [[ "$result" == "hello-world" ]]
}

@test "slugify_text: removes leading and trailing hyphens" {
    result=$(slugify_text "  spaced out  ")
    [[ "$result" == "spaced-out" ]]
}

@test "slugify_text: empty input returns app" {
    result=$(slugify_text "")
    [[ "$result" == "app" ]]
}

@test "slugify_text: preserves numbers" {
    result=$(slugify_text "phase 2 launch")
    [[ "$result" == "phase-2-launch" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# is_retryable_error
# ─────────────────────────────────────────────────────────────────────────────

@test "is_retryable_error: rate_limit is retryable" {
    run is_retryable_error "rate_limit exceeded" 1
    [[ "$status" -eq 0 ]]
}

@test "is_retryable_error: 429 is retryable" {
    run is_retryable_error "HTTP 429 too many requests" 1
    [[ "$status" -eq 0 ]]
}

@test "is_retryable_error: overloaded is retryable" {
    run is_retryable_error "server overloaded" 1
    [[ "$status" -eq 0 ]]
}

@test "is_retryable_error: timeout is retryable" {
    run is_retryable_error "connection timeout" 1
    [[ "$status" -eq 0 ]]
}

@test "is_retryable_error: 503 is retryable" {
    run is_retryable_error "503 service unavailable" 1
    [[ "$status" -eq 0 ]]
}

@test "is_retryable_error: connection refused is retryable" {
    run is_retryable_error "connection refused" 1
    [[ "$status" -eq 0 ]]
}

@test "is_retryable_error: authentication is fatal" {
    run is_retryable_error "authentication failed" 1
    [[ "$status" -ne 0 ]]
}

@test "is_retryable_error: invalid api key is fatal" {
    run is_retryable_error "invalid api key" 1
    [[ "$status" -ne 0 ]]
}

@test "is_retryable_error: quota exceeded is fatal" {
    run is_retryable_error "quota exceeded" 1
    [[ "$status" -ne 0 ]]
}

@test "is_retryable_error: unknown error is not retryable" {
    run is_retryable_error "something weird happened" 1
    [[ "$status" -ne 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# is_allowed_config_key
# ─────────────────────────────────────────────────────────────────────────────

@test "is_allowed_config_key: MODEL is valid" {
    run is_allowed_config_key "MODEL"
    [[ "$status" -eq 0 ]]
}

@test "is_allowed_config_key: MAX_ITERATIONS is valid" {
    run is_allowed_config_key "MAX_ITERATIONS"
    [[ "$status" -eq 0 ]]
}

@test "is_allowed_config_key: PUSH_ENABLED is valid" {
    run is_allowed_config_key "PUSH_ENABLED"
    [[ "$status" -eq 0 ]]
}

@test "is_allowed_config_key: RANDOM_KEY is invalid" {
    run is_allowed_config_key "RANDOM_KEY"
    [[ "$status" -ne 0 ]]
}

@test "is_allowed_config_key: empty string is invalid" {
    run is_allowed_config_key ""
    [[ "$status" -ne 0 ]]
}

@test "is_allowed_config_key: lowercase model is invalid" {
    run is_allowed_config_key "model"
    [[ "$status" -ne 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# validate_config_value
# ─────────────────────────────────────────────────────────────────────────────

@test "validate_config_value: MODEL opus is valid" {
    run validate_config_value "MODEL" "opus"
    [[ "$status" -eq 0 ]]
}

@test "validate_config_value: MODEL sonnet is valid" {
    run validate_config_value "MODEL" "sonnet"
    [[ "$status" -eq 0 ]]
}

@test "validate_config_value: MODEL gpt4 is invalid" {
    run validate_config_value "MODEL" "gpt4"
    [[ "$status" -ne 0 ]]
}

@test "validate_config_value: MAX_ITERATIONS 10 is valid" {
    run validate_config_value "MAX_ITERATIONS" "10"
    [[ "$status" -eq 0 ]]
}

@test "validate_config_value: MAX_ITERATIONS abc is invalid" {
    run validate_config_value "MAX_ITERATIONS" "abc"
    [[ "$status" -ne 0 ]]
}

@test "validate_config_value: PUSH_ENABLED true is valid" {
    run validate_config_value "PUSH_ENABLED" "true"
    [[ "$status" -eq 0 ]]
}

@test "validate_config_value: PUSH_ENABLED false is valid" {
    run validate_config_value "PUSH_ENABLED" "false"
    [[ "$status" -eq 0 ]]
}

@test "validate_config_value: PUSH_ENABLED maybe is invalid" {
    run validate_config_value "PUSH_ENABLED" "maybe"
    [[ "$status" -ne 0 ]]
}

@test "validate_config_value: rejects shell injection with dollar-paren" {
    run validate_config_value "SPEC_FILE" '$(rm -rf /)'
    [[ "$status" -ne 0 ]]
}

@test "validate_config_value: rejects backtick injection" {
    run validate_config_value "SPEC_FILE" '`rm -rf /`'
    [[ "$status" -ne 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# rebase_path
# ─────────────────────────────────────────────────────────────────────────────

@test "rebase_path: standalone mode returns path unchanged" {
    RALPH_SUBDIR=""
    result=$(rebase_path "./specs/foo.json")
    [[ "$result" == "./specs/foo.json" ]]
}

@test "rebase_path: submodule mode rebases relative dot-path" {
    RALPH_SUBDIR="ralph-starter"
    result=$(rebase_path "./specs/foo.json")
    [[ "$result" == "./ralph-starter/specs/foo.json" ]]
}

@test "rebase_path: absolute path unchanged in submodule mode" {
    RALPH_SUBDIR="ralph-starter"
    result=$(rebase_path "/tmp/specs/foo.json")
    [[ "$result" == "/tmp/specs/foo.json" ]]
}

@test "rebase_path: already-rebased path unchanged" {
    RALPH_SUBDIR="ralph-starter"
    result=$(rebase_path "./ralph-starter/specs/foo.json")
    [[ "$result" == "./ralph-starter/specs/foo.json" ]]
}

@test "rebase_path: bare relative path gets rebased" {
    RALPH_SUBDIR="ralph-starter"
    result=$(rebase_path "specs/foo.json")
    [[ "$result" == "./ralph-starter/specs/foo.json" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# substitute_template
# ─────────────────────────────────────────────────────────────────────────────

@test "substitute_template: replaces SPEC_FILE placeholder" {
    SPEC_FILE="./specs/my-feature.json"
    result=$(substitute_template "Read {{SPEC_FILE}} for tasks")
    [[ "$result" == "Read ./specs/my-feature.json for tasks" ]]
}

@test "substitute_template: replaces multiple placeholders" {
    SPEC_FILE="./specs/test.json"
    PLAN_FILE="./plans/test_PLAN.md"
    result=$(substitute_template "spec={{SPEC_FILE}} plan={{PLAN_FILE}}")
    [[ "$result" == "spec=./specs/test.json plan=./plans/test_PLAN.md" ]]
}

@test "substitute_template: leaves unknown placeholder as-is" {
    result=$(substitute_template "Hello {{UNKNOWN_VAR}} world")
    [[ "$result" == "Hello {{UNKNOWN_VAR}} world" ]]
}

@test "substitute_template: empty content returns empty" {
    result=$(substitute_template "")
    [[ "$result" == "" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# get_pipeline_input_seed
# ─────────────────────────────────────────────────────────────────────────────

@test "get_pipeline_input_seed: returns inline prompt when set" {
    CLI_INLINE_PROMPT="Add dark mode toggle"
    CLI_FILE_PATH=""
    result=$(get_pipeline_input_seed)
    [[ "$result" == "Add dark mode toggle" ]]
}

@test "get_pipeline_input_seed: returns file basename without extension" {
    CLI_INLINE_PROMPT=""
    CLI_FILE_PATH="/path/to/my-feature.md"
    result=$(get_pipeline_input_seed)
    [[ "$result" == "my-feature" ]]
}

@test "get_pipeline_input_seed: returns app as fallback" {
    CLI_INLINE_PROMPT=""
    CLI_FILE_PATH=""
    result=$(get_pipeline_input_seed)
    [[ "$result" == "app" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# has_meaningful_product_context
# ─────────────────────────────────────────────────────────────────────────────

@test "has_meaningful_product_context: large md file returns 0" {
    local tmpdir
    tmpdir=$(mktemp -d)
    # Create a file with >200 non-whitespace chars
    python3 -c "print('x' * 250)" > "$tmpdir/vision.md"
    run has_meaningful_product_context "$tmpdir"
    rm -rf "$tmpdir"
    [[ "$status" -eq 0 ]]
}

@test "has_meaningful_product_context: small file returns 1" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo "tiny" > "$tmpdir/vision.md"
    run has_meaningful_product_context "$tmpdir"
    rm -rf "$tmpdir"
    [[ "$status" -eq 1 ]]
}

@test "has_meaningful_product_context: missing dir returns 1" {
    run has_meaningful_product_context "/nonexistent/path"
    [[ "$status" -eq 1 ]]
}

@test "has_meaningful_product_context: large txt file returns 0" {
    local tmpdir
    tmpdir=$(mktemp -d)
    python3 -c "print('y' * 250)" > "$tmpdir/notes.txt"
    run has_meaningful_product_context "$tmpdir"
    rm -rf "$tmpdir"
    [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# calculate_pipeline_build_iterations
# ─────────────────────────────────────────────────────────────────────────────

@test "calculate_pipeline_build_iterations: 5 tasks + buffer 5 = 10" {
    PIPELINE_BUFFER=5
    local tmpfile
    tmpfile=$(mktemp)
    echo '{"tasks":[{},{},{},{},{}]}' > "$tmpfile"
    result=$(calculate_pipeline_build_iterations "$tmpfile")
    rm -f "$tmpfile"
    [[ "$result" == "10" ]]
}

@test "calculate_pipeline_build_iterations: 1 task clamps to minimum 5" {
    PIPELINE_BUFFER=2
    local tmpfile
    tmpfile=$(mktemp)
    echo '{"tasks":[{}]}' > "$tmpfile"
    result=$(calculate_pipeline_build_iterations "$tmpfile")
    rm -f "$tmpfile"
    [[ "$result" == "5" ]]
}

@test "calculate_pipeline_build_iterations: clamps to max 200" {
    PIPELINE_BUFFER=5
    local tmpfile
    tmpfile=$(mktemp)
    # Create JSON with 196 tasks
    python3 -c "import json; print(json.dumps({'tasks': [{} for _ in range(196)]}))" > "$tmpfile"
    result=$(calculate_pipeline_build_iterations "$tmpfile")
    rm -f "$tmpfile"
    [[ "$result" == "200" ]]
}

@test "calculate_pipeline_build_iterations: 0 tasks returns error" {
    PIPELINE_BUFFER=5
    local tmpfile
    tmpfile=$(mktemp)
    echo '{"tasks":[]}' > "$tmpfile"
    run calculate_pipeline_build_iterations "$tmpfile"
    rm -f "$tmpfile"
    [[ "$status" -ne 0 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# load_pipeline_resume_state
# ─────────────────────────────────────────────────────────────────────────────

@test "load_pipeline_resume_state: valid JSON file returns 0" {
    local tmpfile
    tmpfile=$(mktemp)
    echo '{"status":"in_progress","branch":"feature/test"}' > "$tmpfile"
    PIPELINE_SESSION_FILE="$tmpfile"
    run load_pipeline_resume_state
    rm -f "$tmpfile"
    [[ "$status" -eq 0 ]]
}

@test "load_pipeline_resume_state: invalid JSON returns 1" {
    local tmpfile
    tmpfile=$(mktemp)
    echo 'not valid json {{{' > "$tmpfile"
    PIPELINE_SESSION_FILE="$tmpfile"
    run load_pipeline_resume_state
    rm -f "$tmpfile"
    [[ "$status" -eq 1 ]]
}

@test "load_pipeline_resume_state: missing file returns 1" {
    PIPELINE_SESSION_FILE="/nonexistent/path/session.json"
    run load_pipeline_resume_state
    [[ "$status" -eq 1 ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# resolve_pipeline_spec_output_file
# ─────────────────────────────────────────────────────────────────────────────

@test "resolve_pipeline_spec_output_file: returns SPEC_OUTPUT_FILE when set" {
    SPEC_OUTPUT_FILE="/custom/path/spec.json"
    result=$(resolve_pipeline_spec_output_file)
    [[ "$result" == "/custom/path/spec.json" ]]
}

@test "resolve_pipeline_spec_output_file: generates path from inline prompt" {
    SPEC_OUTPUT_FILE=""
    CLI_INLINE_PROMPT="Add dark mode"
    CLI_FILE_PATH=""
    local old_script_dir="$SCRIPT_DIR"
    SCRIPT_DIR=$(mktemp -d)
    result=$(resolve_pipeline_spec_output_file)
    [[ "$result" == "${SCRIPT_DIR}/specs/add-dark-mode.json" ]]
    rm -rf "$SCRIPT_DIR"
    SCRIPT_DIR="$old_script_dir"
}

@test "resolve_pipeline_spec_output_file: appends timestamp when file exists" {
    SPEC_OUTPUT_FILE=""
    CLI_INLINE_PROMPT="existing feature"
    CLI_FILE_PATH=""
    local old_script_dir="$SCRIPT_DIR"
    SCRIPT_DIR=$(mktemp -d)
    mkdir -p "${SCRIPT_DIR}/specs"
    touch "${SCRIPT_DIR}/specs/existing-feature.json"
    result=$(resolve_pipeline_spec_output_file)
    # Should NOT be the plain name (that file exists)
    [[ "$result" != "${SCRIPT_DIR}/specs/existing-feature.json" ]]
    # Should still be in the specs dir with the slug prefix
    [[ "$result" == "${SCRIPT_DIR}/specs/existing-feature-"*".json" ]]
    rm -rf "$SCRIPT_DIR"
    SCRIPT_DIR="$old_script_dir"
}

# ─────────────────────────────────────────────────────────────────────────────
# resolve_pipeline_branch_name
# ─────────────────────────────────────────────────────────────────────────────

@test "resolve_pipeline_branch_name: generates feature/ prefix" {
    CLI_INLINE_PROMPT="new feature"
    CLI_FILE_PATH=""
    # Use a temp git repo so show-ref won't find existing branches
    local tmpdir
    tmpdir=$(mktemp -d)
    git -C "$tmpdir" init --quiet
    result=$(git -C "$tmpdir" -c advice.detachedHead=false checkout --orphan main 2>/dev/null; cd "$tmpdir" && resolve_pipeline_branch_name)
    rm -rf "$tmpdir"
    [[ "$result" == "feature/new-feature" ]]
}
