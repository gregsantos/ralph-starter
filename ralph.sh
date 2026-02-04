#!/bin/bash
# Ralph Loop - Autonomous Claude Code runner
#
# Usage: ./ralph.sh [preset|options] [max_iterations]
#
# Presets:
#   plan              Use PROMPT_plan.md (default model: opus)
#   build             Use PROMPT_build.md (default model: opus)
#   product           Use PROMPT_product.md for product artifact generation
#
# Options:
#   -f, --file PATH   Use custom prompt file
#   -p, --prompt STR  Use inline prompt string
#   -m, --model MODEL Model: opus, sonnet, haiku (default varies by mode)
#   -n, --max N       Max iterations (default: 10)
#   --unlimited       Remove iteration limit (use with caution)
#   --dry-run         Show config and exit without running Claude
#   --test, -1        Test mode: single iteration, no push, ignore completion marker
#   --interactive, -i Prompt for confirmation between iterations
#   --interactive-timeout N  Timeout for interactive prompt (default: 300s)
#   --push            Enable git push after iterations (default)
#   --no-push         Disable git push
#   -s, --spec PATH   Spec file (default: ./specs/IMPLEMENTATION_PLAN.md)
#   -l, --plan PATH   Plan file (derived from spec, or ./plans/IMPLEMENTATION_PLAN.md)
#   --progress PATH   Progress file (default: progress.txt)
#   --source PATH     Source directory (default: src/*)
#   --context PATH    Product context directory (product mode, default: ./product-input/)
#   --output PATH     Product output directory (product mode, default: ./product-output/)
#   --artifact-spec PATH  Artifact spec file (product mode, default: ./docs/PRODUCT_ARTIFACT_SPEC.md)
#   -h, --help        Show this help
#
# Examples:
#   ./ralph.sh                           # Build mode, 10 iterations
#   ./ralph.sh plan 5                    # Plan mode, 5 iterations
#   ./ralph.sh build --model sonnet      # Build with sonnet
#   ./ralph.sh product                   # Product artifact generation
#   ./ralph.sh product --context ./my-context/ --output ./my-output/
#   ./ralph.sh -f ./prompts/review.md    # Custom prompt file
#   ./ralph.sh -p "Fix lint errors" 3    # Inline prompt, 3 iterations
#   ./ralph.sh --unlimited               # Unlimited (careful!)

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Colors
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
BLUE='\033[34m'
MAGENTA='\033[35m'

# Symbols
SYM_CHECK="✓"
SYM_CROSS="✗"
SYM_ARROW="→"
SYM_DOT="•"
SYM_GEAR="⚙"
SYM_FILE="📄"
SYM_EDIT="✎"
SYM_SEARCH="🔍"
SYM_TEST="🧪"
SYM_GIT="⎇"

# Completion Detection
# Claude outputs this marker when all tasks are complete
COMPLETION_MARKER="<ralph>COMPLETE</ralph>"
TASK_COMPLETE=false
COMPLETION_FILE=$(mktemp /tmp/ralph_complete_XXXXXX)

# Retry Configuration
RETRY_ENABLED=true
MAX_RETRIES=3
RETRY_BACKOFF_BASE=5   # Base delay in seconds (5s, 15s, 45s)

# Logging Configuration
DEFAULT_LOG_DIR="${HOME}/.ralph/logs"
LOG_DIR=""                # Set by --log-dir or RALPH_LOG_DIR
LOG_FILE_OVERRIDE=""      # Set by --log-file
LOG_FORMAT="text"         # text or json (set by --log-format or RALPH_LOG_FORMAT)

# Config File Tracking
GLOBAL_CONFIG_FILE=""     # Path to global config file (default: ~/.ralph/config)
LOADED_CONFIG_FILES=()    # Array of config files that were loaded

# Iteration Status Tracking
ITERATION_STATUS_FILE=$(mktemp /tmp/ralph_status_XXXXXX)
ITERATION_REASON_FILE=$(mktemp /tmp/ralph_reason_XXXXXX)

# ═══════════════════════════════════════════════════════════════════════════════
# PRE-FLIGHT CHECKS
# Verify all dependencies are available before starting
# ═══════════════════════════════════════════════════════════════════════════════

SKIP_CHECKS=false

preflight_checks() {
    local has_errors=false

    # Check for claude CLI
    if ! command -v claude >/dev/null 2>&1; then
        echo -e "${RED}${SYM_CROSS} Error: claude CLI not found${RESET}"
        echo -e "  ${DIM}Install:${RESET} npm install -g @anthropic-ai/claude-code"
        echo -e "  ${DIM}Or visit:${RESET} https://docs.anthropic.com/claude-code"
        has_errors=true
    else
        # Check if claude is authenticated (non-destructive check)
        if ! claude --version >/dev/null 2>&1; then
            echo -e "${RED}${SYM_CROSS} Error: claude CLI not authenticated or misconfigured${RESET}"
            echo -e "  ${DIM}Run:${RESET} claude auth login"
            has_errors=true
        fi
    fi

    # Check for jq
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}${SYM_CROSS} Error: jq not found${RESET}"
        echo -e "  ${DIM}Install (macOS):${RESET} brew install jq"
        echo -e "  ${DIM}Install (Ubuntu):${RESET} apt-get install jq"
        echo -e "  ${DIM}Install (other):${RESET} https://jqlang.github.io/jq/download/"
        has_errors=true
    fi

    # Check for git and that we're in a git repository
    if ! command -v git >/dev/null 2>&1; then
        echo -e "${RED}${SYM_CROSS} Error: git not found${RESET}"
        echo -e "  ${DIM}Install:${RESET} https://git-scm.com/downloads"
        has_errors=true
    elif ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "${RED}${SYM_CROSS} Error: not a git repository${RESET}"
        echo -e "  ${DIM}Run:${RESET} git init"
        has_errors=true
    fi

    if [ "$has_errors" = true ]; then
        echo -e "\n${YELLOW}${SYM_DOT} Use --skip-checks to bypass pre-flight validation${RESET}"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION STATE MANAGEMENT
# Maintains structured JSON state file for session tracking and resume capability
# ═══════════════════════════════════════════════════════════════════════════════

SESSION_FILE=".ralph-session.json"
SESSION_ID=""
SESSION_START_ISO=""

# Initialize session state file at session start
# Creates .ralph-session.json with initial metadata
init_session_state() {
    SESSION_ID="$(date +%Y%m%d_%H%M%S)_$$"
    SESSION_START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Create initial session state
    jq -n \
        --arg session_id "$SESSION_ID" \
        --arg start_time "$SESSION_START_ISO" \
        --arg mode "$MODE" \
        --arg model "$MODEL" \
        --arg prompt_file "$PROMPT_FILE" \
        --argjson current_iteration 0 \
        --argjson max_iterations "$MAX_ITERATIONS" \
        --arg branch "$CURRENT_BRANCH" \
        --arg status "in_progress" \
        --arg spec_file "$SPEC_FILE" \
        --arg plan_file "$PLAN_FILE" \
        --arg progress_file "$PROGRESS_FILE" \
        '{
            session_id: $session_id,
            start_time: $start_time,
            mode: $mode,
            model: $model,
            prompt_file: $prompt_file,
            current_iteration: $current_iteration,
            max_iterations: $max_iterations,
            branch: $branch,
            status: $status,
            spec_file: $spec_file,
            plan_file: $plan_file,
            progress_file: $progress_file,
            iteration_history: []
        }' > "$SESSION_FILE"

    echo -e "  ${DIM}Session:${RESET} ${SESSION_ID}"

    # Log session start for structured logging
    log_session_start
}

# Update session state after each iteration
# Arguments: iteration_number, duration_seconds, exit_code
update_session_state() {
    local iteration="$1"
    local duration="$2"
    local exit_code="$3"

    [ ! -f "$SESSION_FILE" ] && return 0

    # Count files modified in this iteration
    # Compare current HEAD to iteration start, or count uncommitted changes if no commit was made
    local files_modified=0
    local current_head
    current_head=$(git rev-parse HEAD 2>/dev/null || echo "")
    
    if [ -n "$ITERATION_START_HEAD" ] && [ -n "$current_head" ] && [ "$current_head" != "$ITERATION_START_HEAD" ]; then
        # Commit was made - count files changed since iteration start
        files_modified=$(git diff --name-only "$ITERATION_START_HEAD" "$current_head" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    else
        # No commit made - count staged + modified files
        files_modified=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    fi

    # Get last commit message if there was a commit
    local last_commit_msg=""
    last_commit_msg=$(git log -1 --pretty=format:"%s" 2>/dev/null || echo "")

    # Create iteration entry
    local iteration_entry
    iteration_entry=$(jq -n \
        --argjson iteration "$iteration" \
        --argjson duration "$duration" \
        --argjson exit_code "$exit_code" \
        --argjson files_modified "$files_modified" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg commit_msg "$last_commit_msg" \
        '{
            iteration: $iteration,
            duration: $duration,
            exit_code: $exit_code,
            files_modified: $files_modified,
            timestamp: $timestamp,
            commit_message: $commit_msg
        }')

    # Update session file with new iteration and current_iteration counter
    local updated
    updated=$(jq \
        --argjson iter "$iteration" \
        --argjson entry "$iteration_entry" \
        '.current_iteration = $iter | .iteration_history += [$entry]' \
        "$SESSION_FILE" 2>/dev/null)

    # Only write if jq succeeded and output is non-empty (prevents data loss)
    # Use atomic write (temp file + rename) to prevent corruption on interrupt
    if [ -n "$updated" ] && [ "$updated" != "null" ]; then
        local tmp_file
        tmp_file=$(mktemp "${SESSION_FILE}.XXXXXX")
        echo "$updated" > "$tmp_file"
        mv "$tmp_file" "$SESSION_FILE"
    else
        echo -e "${YELLOW}Warning: Failed to update session state${RESET}" >&2
    fi
}

# Finalize session state - set final status and optionally archive
# Arguments: final_status (complete|failed|interrupted|max_iterations)
finalize_session_state() {
    local final_status="$1"

    [ ! -f "$SESSION_FILE" ] && return 0

    local end_time
    end_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Calculate total duration
    local total_duration=$(($(date +%s) - START_TIME))

    # Update final status
    local updated
    updated=$(jq \
        --arg status "$final_status" \
        --arg end_time "$end_time" \
        --argjson total_duration "$total_duration" \
        '.status = $status | .end_time = $end_time | .total_duration = $total_duration' \
        "$SESSION_FILE" 2>/dev/null)

    # Only write if jq succeeded and output is non-empty (prevents data loss)
    # Use atomic write (temp file + rename) to prevent corruption on interrupt
    if [ -n "$updated" ] && [ "$updated" != "null" ]; then
        local tmp_file
        tmp_file=$(mktemp "${SESSION_FILE}.XXXXXX")
        echo "$updated" > "$tmp_file"
        mv "$tmp_file" "$SESSION_FILE"
    else
        echo -e "${YELLOW}Warning: Failed to finalize session state${RESET}" >&2
    fi

    # Generate session summary report (if not disabled)
    generate_summary "$final_status"

    # Archive on successful completion, preserve on failure/interrupt for debugging
    if [ "$final_status" = "complete" ]; then
        # Create log directory if needed
        local log_dir="${HOME}/.ralph/logs"
        mkdir -p "$log_dir"

        # Archive session file
        local archive_path="${log_dir}/${SESSION_ID}_session.json"
        cp "$SESSION_FILE" "$archive_path"
        rm -f "$SESSION_FILE"

        echo -e "  ${DIM}Session archived:${RESET} ${archive_path}"
    else
        # Keep session file for debugging/resume
        echo -e "  ${DIM}Session preserved:${RESET} ${SESSION_FILE}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION RESUME
# Resume interrupted sessions from .ralph-session.json
# ═══════════════════════════════════════════════════════════════════════════════

RESUME_SESSION=false
LIST_SESSIONS=false

# List all resumable sessions (in current directory and ~/.ralph/logs/)
list_sessions() {
    local found_any=false

    echo -e "${BOLD}Resumable Sessions${RESET}\n"

    # Check current directory for active session
    if [ -f ".ralph-session.json" ]; then
        local status
        status=$(jq -r '.status // "unknown"' ".ralph-session.json" 2>/dev/null)

        if [ "$status" != "complete" ]; then
            found_any=true
            local session_id start_time mode model branch current_iter max_iter
            session_id=$(jq -r '.session_id // "unknown"' ".ralph-session.json")
            start_time=$(jq -r '.start_time // "unknown"' ".ralph-session.json")
            mode=$(jq -r '.mode // "unknown"' ".ralph-session.json")
            model=$(jq -r '.model // "unknown"' ".ralph-session.json")
            branch=$(jq -r '.branch // "unknown"' ".ralph-session.json")
            current_iter=$(jq -r '.current_iteration // 0' ".ralph-session.json")
            max_iter=$(jq -r '.max_iterations // 0' ".ralph-session.json")

            echo -e "${GREEN}${SYM_DOT} Active session (current directory)${RESET}"
            echo -e "   ${BOLD}Session:${RESET}  $session_id"
            echo -e "   ${BOLD}Started:${RESET}  $start_time"
            echo -e "   ${BOLD}Mode:${RESET}     $mode"
            echo -e "   ${BOLD}Model:${RESET}    $model"
            echo -e "   ${BOLD}Branch:${RESET}   $branch"
            echo -e "   ${BOLD}Progress:${RESET} ${current_iter}/${max_iter} iterations"
            echo -e "   ${BOLD}Status:${RESET}   ${YELLOW}${status}${RESET}"
            echo -e "   ${DIM}Resume with: ./ralph.sh --resume${RESET}"
            echo ""
        fi
    fi

    # Check for interrupted sessions in log directory
    local log_dir="${HOME}/.ralph/logs"
    if [ -d "$log_dir" ]; then
        # Use while read to handle filenames with spaces correctly
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            local status
            status=$(jq -r '.status // "unknown"' "$file" 2>/dev/null)

            # Only show non-complete sessions
            if [ "$status" != "complete" ] && [ "$status" != "unknown" ]; then
                found_any=true
                local session_id start_time mode branch
                session_id=$(jq -r '.session_id // "unknown"' "$file")
                start_time=$(jq -r '.start_time // "unknown"' "$file")
                mode=$(jq -r '.mode // "unknown"' "$file")
                branch=$(jq -r '.branch // "unknown"' "$file")

                echo -e "${YELLOW}${SYM_DOT} Archived session${RESET}"
                echo -e "   ${BOLD}File:${RESET}     $file"
                echo -e "   ${BOLD}Session:${RESET}  $session_id"
                echo -e "   ${BOLD}Started:${RESET}  $start_time"
                echo -e "   ${BOLD}Mode:${RESET}     $mode"
                echo -e "   ${BOLD}Branch:${RESET}   $branch"
                echo -e "   ${BOLD}Status:${RESET}   ${RED}${status}${RESET}"
                echo ""
            fi
        done < <(find "$log_dir" -name "*_session.json" -type f 2>/dev/null | head -10)
    fi

    if [ "$found_any" = false ]; then
        echo -e "${DIM}No resumable sessions found.${RESET}"
        echo -e "${DIM}Sessions are preserved when interrupted or failed.${RESET}"
    fi
}

# Validate session file for resume
# Arguments: session_file_path
# Returns: 0 if valid, 1 if invalid (with error message)
validate_session() {
    local session_file="$1"

    # Check file exists
    if [ ! -f "$session_file" ]; then
        echo -e "${RED}${SYM_CROSS} Error: Session file not found: ${session_file}${RESET}"
        echo -e "  ${DIM}Run ./ralph.sh --list-sessions to see available sessions${RESET}"
        return 1
    fi

    # Check it's valid JSON
    if ! jq empty "$session_file" 2>/dev/null; then
        echo -e "${RED}${SYM_CROSS} Error: Invalid session file (not valid JSON)${RESET}"
        return 1
    fi

    # Check status - can't resume completed sessions
    local status
    status=$(jq -r '.status // "unknown"' "$session_file")
    if [ "$status" = "complete" ]; then
        echo -e "${RED}${SYM_CROSS} Error: Cannot resume completed session${RESET}"
        echo -e "  ${DIM}Session was already successfully completed.${RESET}"
        echo -e "  ${DIM}Start a new session with: ./ralph.sh${RESET}"
        return 1
    fi

    # Check branch matches current branch
    local session_branch
    session_branch=$(jq -r '.branch // ""' "$session_file")
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)

    # Validate session has branch information
    if [ -z "$session_branch" ]; then
        echo -e "${RED}${SYM_CROSS} Error: Session file missing branch information${RESET}"
        echo -e "  ${DIM}The session file may be corrupted. Delete it to start fresh:${RESET}"
        echo -e "    rm ${session_file}"
        return 1
    fi

    if [ "$session_branch" != "$current_branch" ]; then
        echo -e "${RED}${SYM_CROSS} Error: Branch mismatch${RESET}"
        echo -e "  ${BOLD}Session branch:${RESET} ${session_branch}"
        echo -e "  ${BOLD}Current branch:${RESET} ${current_branch}"
        echo -e "\n  ${DIM}Either switch to the session branch:${RESET}"
        echo -e "    git checkout ${session_branch}"
        echo -e "  ${DIM}Or delete the session file to start fresh:${RESET}"
        echo -e "    rm ${session_file}"
        return 1
    fi

    # Check session age (warn if > 24 hours)
    local start_time
    start_time=$(jq -r '.start_time // ""' "$session_file")
    if [ -n "$start_time" ]; then
        local session_epoch now_epoch age_hours
        # Convert ISO timestamp to epoch (works on macOS and Linux)
        if date --version >/dev/null 2>&1; then
            # GNU date (Linux)
            session_epoch=$(date -d "$start_time" +%s 2>/dev/null || echo "0")
        else
            # BSD date (macOS)
            # Convert ISO 8601 to a format BSD date understands
            local converted_time
            converted_time=$(echo "$start_time" | sed 's/T/ /; s/Z//')
            session_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$converted_time" +%s 2>/dev/null || echo "0")
        fi
        now_epoch=$(date +%s)

        if [ "$session_epoch" -gt 0 ]; then
            age_hours=$(( (now_epoch - session_epoch) / 3600 ))
            if [ "$age_hours" -ge 24 ]; then
                echo -e "${YELLOW}${SYM_DOT} Warning: Session is ${age_hours} hours old${RESET}"
                echo -e "  ${DIM}Consider starting fresh if significant time has passed.${RESET}"
                echo ""
            fi
        fi
    fi

    return 0
}

# Restore session state from session file
# Arguments: session_file_path
# Sets global variables for mode, model, iteration count, etc.
restore_session() {
    local session_file="$1"

    # Read session values
    SESSION_ID=$(jq -r '.session_id // ""' "$session_file")
    local saved_mode saved_model saved_prompt_file saved_iteration saved_max
    local saved_branch saved_spec saved_plan saved_progress
    saved_mode=$(jq -r '.mode // "build"' "$session_file")
    saved_model=$(jq -r '.model // "opus"' "$session_file")
    saved_prompt_file=$(jq -r '.prompt_file // ""' "$session_file")
    saved_iteration=$(jq -r '.current_iteration // 0' "$session_file")
    saved_max=$(jq -r '.max_iterations // 10' "$session_file")
    saved_branch=$(jq -r '.branch // ""' "$session_file")
    saved_spec=$(jq -r '.spec_file // ""' "$session_file")
    saved_plan=$(jq -r '.plan_file // ""' "$session_file")
    saved_progress=$(jq -r '.progress_file // ""' "$session_file")

    # Display resume summary
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}${BOLD}║${RESET}                    ${BOLD}RESUMING SESSION${RESET}                          ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}\n"

    echo -e "${DIM}┌─────────────────────────────────────────┐${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Session${RESET}  ${SYM_ARROW} ${GREEN}${SESSION_ID}${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Mode${RESET}     ${SYM_ARROW} ${saved_mode}"
    echo -e "${DIM}│${RESET} ${BOLD}Model${RESET}    ${SYM_ARROW} ${saved_model}"
    echo -e "${DIM}│${RESET} ${BOLD}Branch${RESET}   ${SYM_ARROW} ${MAGENTA}${saved_branch}${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Progress${RESET} ${SYM_ARROW} ${YELLOW}Resuming at iteration $((saved_iteration + 1))/${saved_max}${RESET}"
    echo -e "${DIM}└─────────────────────────────────────────┘${RESET}\n"

    # Show iteration history summary
    local history_count
    history_count=$(jq '.iteration_history | length' "$session_file" 2>/dev/null || echo "0")
    if [ "$history_count" -gt 0 ]; then
        echo -e "${DIM}Previous iterations:${RESET}"
        jq -r '.iteration_history[] | "  \(.iteration). \(.duration)s - \(.commit_message // "no commit")[0:40]"' "$session_file" 2>/dev/null | head -5
        if [ "$history_count" -gt 5 ]; then
            echo -e "  ${DIM}... and $((history_count - 5)) more${RESET}"
        fi
        echo ""
    fi

    # Restore global variables
    MODE="$saved_mode"
    MODEL="$saved_model"
    ITERATION="$saved_iteration"
    MAX_ITERATIONS="$saved_max"
    CURRENT_BRANCH="$saved_branch"

    # Restore file paths if they were saved
    [ -n "$saved_spec" ] && SPEC_FILE="$saved_spec"
    [ -n "$saved_plan" ] && PLAN_FILE="$saved_plan"
    [ -n "$saved_progress" ] && PROGRESS_FILE="$saved_progress"

    # Restore prompt file - verify it exists
    if [ -n "$saved_prompt_file" ] && [ -f "$saved_prompt_file" ]; then
        PROMPT_FILE="$saved_prompt_file"
    else
        # Fall back to preset prompt file
        PROMPT_FILE="${SCRIPT_DIR}/prompts/PROMPT_${MODE}.md"
    fi

    # Update session status to in_progress (was interrupted/failed)
    local updated
    updated=$(jq '.status = "in_progress"' "$session_file" 2>/dev/null)
    
    # Only write if jq succeeded and output is non-empty (prevents data loss)
    # Use atomic write (temp file + rename) to prevent corruption on interrupt
    if [ -n "$updated" ] && [ "$updated" != "null" ]; then
        local tmp_file
        tmp_file=$(mktemp "${session_file}.XXXXXX")
        echo "$updated" > "$tmp_file"
        mv "$tmp_file" "$session_file"
    else
        echo -e "${YELLOW}Warning: Failed to update session status${RESET}" >&2
    fi

    echo -e "${GREEN}${SYM_CHECK} Session restored. Continuing...${RESET}\n"
}

# ═══════════════════════════════════════════════════════════════════════════════
# RETRY LOGIC
# Automatic retry for transient failures with exponential backoff
# ═══════════════════════════════════════════════════════════════════════════════

# Retryable error patterns (transient failures that may succeed on retry)
RETRYABLE_PATTERNS=(
    "rate_limit"
    "rate limit"
    "429"
    "529"
    "overloaded"
    "timeout"
    "timed out"
    "connection_error"
    "connection refused"
    "ECONNRESET"
    "ETIMEDOUT"
    "network error"
    "temporarily unavailable"
    "service unavailable"
    "503"
    "502"
    "504"
)

# Fatal error patterns (unrecoverable, don't retry)
FATAL_PATTERNS=(
    "authentication"
    "auth failure"
    "unauthorized"
    "401"
    "403"
    "forbidden"
    "permission denied"
    "invalid api key"
    "invalid_api_key"
    "bad request"
    "invalid prompt"
    "malformed"
    "quota exceeded"
)

# Temp file for capturing claude output during retry
RETRY_OUTPUT_FILE=$(mktemp /tmp/ralph_retry_XXXXXX)

# Check if an error message indicates a retryable failure
# Arguments: error_message, exit_code
# Returns: 0 if retryable, 1 if fatal
is_retryable_error() {
    local error_msg="$1"
    local exit_code="$2"
    local error_lower
    error_lower=$(echo "$error_msg" | tr '[:upper:]' '[:lower:]')

    # First check for fatal errors - these should never be retried
    for pattern in "${FATAL_PATTERNS[@]}"; do
        if [[ "$error_lower" == *"$pattern"* ]]; then
            return 1  # Fatal error, don't retry
        fi
    done

    # Check for retryable patterns
    for pattern in "${RETRYABLE_PATTERNS[@]}"; do
        if [[ "$error_lower" == *"$pattern"* ]]; then
            return 0  # Retryable
        fi
    done

    # Exit codes that indicate transient failures
    # 1 = general error (could be transient)
    # Signal-related codes (128+) are not retryable
    if [ "$exit_code" -ge 128 ]; then
        return 1  # Signal, not retryable
    fi

    # Default: not retryable (be conservative)
    return 1
}

# Display retry countdown with reason
# Arguments: delay_seconds, attempt_number, max_attempts, reason
show_retry_countdown() {
    local delay="$1"
    local attempt="$2"
    local max="$3"
    local reason="$4"

    echo -e "\n${YELLOW}${BOLD}  ⏳ Retry ${attempt}/${max}${RESET} - ${reason}"
    echo -ne "     ${DIM}Waiting: "

    for ((i=delay; i>0; i--)); do
        echo -ne "${i}s "
        sleep 1
    done

    echo -e "${RESET}"
}

# Log retry attempt to session state
# Arguments: attempt_number, delay, reason, success
log_retry_attempt() {
    local attempt="$1"
    local delay="$2"
    local reason="$3"
    local success="$4"

    [ ! -f "$SESSION_FILE" ] && return 0

    # Create retry entry
    local retry_entry
    retry_entry=$(jq -n \
        --argjson attempt "$attempt" \
        --argjson delay "$delay" \
        --arg reason "$reason" \
        --arg success "$success" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            attempt: $attempt,
            delay: $delay,
            reason: $reason,
            success: ($success == "true"),
            timestamp: $timestamp
        }')

    # Add to current iteration's retry_attempts array
    local updated
    updated=$(jq \
        --argjson entry "$retry_entry" \
        'if .current_retry_attempts == null then .current_retry_attempts = [] else . end | .current_retry_attempts += [$entry]' \
        "$SESSION_FILE" 2>/dev/null)

    # Only write if jq succeeded and output is non-empty (prevents data loss)
    # Use atomic write (temp file + rename) to prevent corruption on interrupt
    if [ -n "$updated" ] && [ "$updated" != "null" ]; then
        local tmp_file
        tmp_file=$(mktemp "${SESSION_FILE}.XXXXXX")
        echo "$updated" > "$tmp_file"
        mv "$tmp_file" "$SESSION_FILE"
    fi
}

# Clear retry attempts from session (called after iteration completes)
clear_retry_attempts() {
    [ ! -f "$SESSION_FILE" ] && return 0

    local updated
    updated=$(jq 'del(.current_retry_attempts)' "$SESSION_FILE" 2>/dev/null)
    
    # Only write if jq succeeded and output is non-empty (prevents data loss)
    # Use atomic write (temp file + rename) to prevent corruption on interrupt
    if [ -n "$updated" ] && [ "$updated" != "null" ]; then
        local tmp_file
        tmp_file=$(mktemp "${SESSION_FILE}.XXXXXX")
        echo "$updated" > "$tmp_file"
        mv "$tmp_file" "$SESSION_FILE"
    else
        echo -e "${YELLOW}Warning: Failed to clear retry attempts from session${RESET}" >&2
    fi
}

# Run claude with retry logic
# Arguments: prompt_content
# Returns: exit code from claude (or last attempt)
# Sets: LAST_CLAUDE_OUTPUT (path to output file), LAST_ERROR_MSG
LAST_CLAUDE_OUTPUT=""
LAST_ERROR_MSG=""

run_with_retry() {
    local prompt_content="$1"
    local attempt=0
    local exit_code=0
    local delay=0

    LAST_CLAUDE_OUTPUT="$RETRY_OUTPUT_FILE"
    LAST_ERROR_MSG=""

    while true; do
        attempt=$((attempt + 1))

        # Run claude and capture output
        : > "$RETRY_OUTPUT_FILE"  # Clear output file

        # Run pipeline - parse_claude_output writes status to ITERATION_STATUS_FILE
        echo "$prompt_content" | claude -p \
            --dangerously-skip-permissions \
            --output-format=stream-json \
            --model "$MODEL" \
            --verbose \
            2>&1 | tee "$RETRY_OUTPUT_FILE" | parse_claude_output
        
        # Capture PIPESTATUS immediately (it's overwritten by next command)
        # PIPESTATUS array: [0]=echo, [1]=claude, [2]=tee, [3]=parse_claude_output
        local pipeline_status=("${PIPESTATUS[@]}")
        local claude_exit="${pipeline_status[1]}"
        
        # Determine exit code from two separate concerns:
        # 1. Claude CLI failure (network, auth, rate limit at CLI level) - infrastructure
        # 2. Detected errors in output (tool errors, session errors) - application
        if [ "$claude_exit" -ne 0 ]; then
            # Claude CLI itself failed - use its exit code for retry classification
            exit_code="$claude_exit"
        elif [ "$(cat "$ITERATION_STATUS_FILE" 2>/dev/null)" = "failed" ]; then
            # Claude completed but parse_claude_output detected errors in the JSON stream
            # Use exit code 1 to indicate failure (error details in LAST_ERROR_MSG)
            exit_code=1
        else
            exit_code=0
        fi

        # Success - no retry needed
        if [ "$exit_code" -eq 0 ]; then
            # Clear any pending retry attempts from session
            clear_retry_attempts
            return 0
        fi

        # Extract error message from output for classification
        LAST_ERROR_MSG=$(grep -i '"error"' "$RETRY_OUTPUT_FILE" | head -1 | jq -r '.error.message // .message // empty' 2>/dev/null || echo "Unknown error (exit code $exit_code)")

        # Check if retry is disabled
        if [ "$RETRY_ENABLED" = false ]; then
            echo -e "  ${YELLOW}${SYM_DOT} Retry disabled (--no-retry)${RESET}"
            return "$exit_code"
        fi

        # Check if we've exhausted retries
        if [ "$attempt" -gt "$MAX_RETRIES" ]; then
            echo -e "  ${RED}${SYM_CROSS} Max retries ($MAX_RETRIES) exhausted${RESET}"
            log_retry_attempt "$attempt" 0 "$LAST_ERROR_MSG" "false"
            return "$exit_code"
        fi

        # Check if error is retryable
        if ! is_retryable_error "$LAST_ERROR_MSG" "$exit_code"; then
            echo -e "  ${RED}${SYM_CROSS} Fatal error (not retryable):${RESET} ${LAST_ERROR_MSG:0:60}"
            return "$exit_code"
        fi

        # Calculate exponential backoff: 5s, 15s, 45s (base * 3^(attempt-1))
        delay=$((RETRY_BACKOFF_BASE * (3 ** (attempt - 1))))

        # Log retry attempt to session state
        log_retry_attempt "$attempt" "$delay" "$LAST_ERROR_MSG" "false"

        # Show countdown
        show_retry_countdown "$delay" "$attempt" "$MAX_RETRIES" "${LAST_ERROR_MSG:0:40}"
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# HELP
# ═══════════════════════════════════════════════════════════════════════════════

show_help() {
    echo -e "${BOLD}Ralph Loop${RESET} - Autonomous Claude Code runner"
    echo ""
    echo -e "${BOLD}Usage:${RESET} ./ralph.sh [preset|options] [max_iterations]"
    echo ""
    echo -e "${BOLD}Presets:${RESET}"
    echo "  plan              Use PROMPT_plan.md (default model: opus)"
    echo "  build             Use PROMPT_build.md (default model: opus)"
    echo "  product           Use PROMPT_product.md for product artifact generation"
    echo ""
    echo -e "${BOLD}Options:${RESET}"
    echo "  -f, --file PATH   Use custom prompt file"
    echo "  -p, --prompt STR  Use inline prompt string"
    echo "  -m, --model MODEL Model: opus, sonnet, haiku"
    echo "  -n, --max N       Max iterations (default: 10)"
    echo "  --unlimited       Remove iteration limit (use with caution)"
    echo "  --dry-run         Show config and exit without running Claude"
    echo "  --test, -1        Test mode: single iteration, no push, ignore completion marker"
    echo "  --interactive, -i Prompt for confirmation between iterations"
    echo "  --interactive-timeout N  Timeout for interactive prompt (default: 300s)"
    echo "  --push            Enable git push after iterations (default)"
    echo "  --no-push         Disable git push"
    echo "  --skip-checks     Skip pre-flight dependency checks"
    echo "  --no-retry        Disable retry on transient failures"
    echo "  --max-retries N   Max retry attempts (default: 3)"
    echo "  --resume          Resume interrupted session from .ralph-session.json"
    echo "  --list-sessions   List all resumable sessions"
    echo "  --log-dir PATH    Log directory (default: ~/.ralph/logs/)"
    echo "  --log-file PATH   Explicit log file path (overrides --log-dir)"
    echo "  --log-format FMT  Log format: text (default) or json"
    echo "  --notify-webhook URL  Webhook URL for session notifications"
    echo "  --no-summary      Disable session summary report generation"
    echo "  --global-config PATH  Global config file (default: ~/.ralph/config)"
    echo "  -s, --spec PATH   Spec file (default: ./specs/IMPLEMENTATION_PLAN.md)"
    echo "  -l, --plan PATH   Plan file (derived from spec if not set, or ./plans/IMPLEMENTATION_PLAN.md)"
    echo "  --progress PATH   Progress file (default: progress.txt)"
    echo "  --source PATH     Source directory (default: src/*)"
    echo ""
    echo -e "${BOLD}Product Mode Options:${RESET}"
    echo "  --context PATH       Product context directory (default: ./product-input/)"
    echo "  --output PATH        Product output directory (default: ./product-output/)"
    echo "  --artifact-spec PATH Artifact spec file (default: ./docs/PRODUCT_ARTIFACT_SPEC.md)"
    echo ""
    echo "  -h, --help        Show this help"
    echo ""
    echo -e "${BOLD}Examples:${RESET}"
    echo "  ./ralph.sh                           # Build mode, 10 iterations (default)"
    echo "  ./ralph.sh plan 5                    # Plan mode, 5 iterations"
    echo "  ./ralph.sh build --model sonnet      # Build with sonnet, 10 iterations"
    echo "  ./ralph.sh product                   # Product artifact generation"
    echo "  ./ralph.sh product --context ./ctx/ --output ./out/  # Custom product paths"
    echo "  ./ralph.sh -f ./prompts/review.md    # Custom prompt file"
    echo "  ./ralph.sh -p \"Fix lint errors\" 3    # Inline prompt, 3 iterations"
    echo "  ./ralph.sh build --unlimited         # Unlimited iterations (careful!)"
    echo "  ./ralph.sh --test                     # Test mode: 1 iteration, no push"
    echo "  ./ralph.sh --interactive              # Interactive: confirm between iterations"
    echo "  ./ralph.sh -i --interactive-timeout 60  # Interactive with 60s timeout"
    echo "  ./ralph.sh -s ./specs/feature.md -l ./plans/feature_PLAN.md  # Custom spec+plan"
    echo ""
    echo -e "${BOLD}Environment Variables:${RESET}"
    echo "  All environment variables can be used instead of CLI flags."
    echo "  Precedence: CLI flags > env vars > config file > defaults"
    echo ""
    echo "  RALPH_MODEL            Model to use (opus, sonnet, haiku)"
    echo "  RALPH_MAX_ITERATIONS   Maximum iterations (number)"
    echo "  RALPH_PUSH_ENABLED     Enable git push (true/false)"
    echo "  RALPH_SPEC_FILE        Spec file path"
    echo "  RALPH_PLAN_FILE        Plan file path"
    echo "  RALPH_PROGRESS_FILE    Progress file path"
    echo "  RALPH_LOG_DIR          Log directory path"
    echo "  RALPH_LOG_FORMAT       Log format: text (default) or json"
    echo "  RALPH_NOTIFY_WEBHOOK   Webhook URL for notifications"
    echo ""
    echo -e "${BOLD}Defaults:${RESET}"
    echo "  Iterations: 10 (prevents runaway sessions)"
    echo "  Model:      opus (plan/build/product), sonnet (inline)"
    echo "  Push:       enabled"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ARGUMENT PARSING
# ═══════════════════════════════════════════════════════════════════════════════

# Get script directory for resolving relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
PROMPT_SOURCE="preset"    # preset, file, or inline
PROMPT_CONTENT=""         # file path or inline string
PRESET_NAME="build"       # plan, build
MODEL=""                  # set after parsing based on mode
MODEL_OVERRIDE=""         # user-specified model
PUSH_ENABLED=true
MAX_ITERATIONS=10         # Default limit to prevent runaway sessions
UNLIMITED=false           # Explicit flag for unlimited iterations
DRY_RUN=false             # Show config without running Claude
TEST_MODE=false           # Single iteration test mode (no push, ignore completion marker)
INTERACTIVE_MODE=false    # Prompt for confirmation between iterations
INTERACTIVE_TIMEOUT=300   # Timeout in seconds for interactive prompt (default: 5 minutes)
TEMP_PROMPT_FILE=""

# Template variable defaults (CLI args override, then config, then these)
SPEC_FILE=""
PLAN_FILE=""
PROGRESS_FILE=""
SOURCE_DIR=""

# Product mode specific variables
PRODUCT_CONTEXT_DIR=""
PRODUCT_OUTPUT_DIR=""
ARTIFACT_SPEC_FILE=""

# Track CLI-explicit flags (set during arg parsing)
CLI_SPEC_SET=false
CLI_PLAN_SET=false

# Track which values were set via CLI (for precedence tracking)
CLI_MODEL_SET=false
CLI_MAX_SET=false
CLI_PUSH_SET=false
CLI_LOG_DIR_SET=false
CLI_LOG_FILE_SET=false
CLI_LOG_FORMAT_SET=false
CLI_PROGRESS_SET=false
CLI_WEBHOOK_SET=false

# Parse arguments
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--file)
            PROMPT_SOURCE="file"
            PROMPT_CONTENT="$2"
            shift 2
            ;;
        -p|--prompt)
            PROMPT_SOURCE="inline"
            PROMPT_CONTENT="$2"
            shift 2
            ;;
        -m|--model)
            MODEL_OVERRIDE="$2"
            CLI_MODEL_SET=true
            shift 2
            ;;
        --push)
            PUSH_ENABLED=true
            CLI_PUSH_SET=true
            shift
            ;;
        --no-push)
            PUSH_ENABLED=false
            CLI_PUSH_SET=true
            shift
            ;;
        -n|--max)
            MAX_ITERATIONS="$2"
            CLI_MAX_SET=true
            shift 2
            ;;
        --unlimited)
            UNLIMITED=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --test|-1)
            TEST_MODE=true
            shift
            ;;
        --interactive|-i)
            INTERACTIVE_MODE=true
            shift
            ;;
        --interactive-timeout)
            if [[ "$2" =~ ^[0-9]+$ ]]; then
                INTERACTIVE_TIMEOUT="$2"
            else
                echo -e "${RED}${SYM_CROSS} Error: --interactive-timeout must be a positive integer (seconds)${RESET}"
                exit 1
            fi
            shift 2
            ;;
        --skip-checks)
            SKIP_CHECKS=true
            shift
            ;;
        --no-retry)
            RETRY_ENABLED=false
            shift
            ;;
        --max-retries)
            if [[ "$2" =~ ^[0-9]+$ ]]; then
                MAX_RETRIES="$2"
            else
                echo -e "${RED}${SYM_CROSS} Error: --max-retries must be a positive integer${RESET}"
                exit 1
            fi
            shift 2
            ;;
        --resume)
            RESUME_SESSION=true
            shift
            ;;
        --list-sessions)
            LIST_SESSIONS=true
            shift
            ;;
        --log-dir)
            LOG_DIR="$2"
            CLI_LOG_DIR_SET=true
            shift 2
            ;;
        --log-file)
            LOG_FILE_OVERRIDE="$2"
            CLI_LOG_FILE_SET=true
            shift 2
            ;;
        --log-format)
            LOG_FORMAT="$2"
            CLI_LOG_FORMAT_SET=true
            shift 2
            ;;
        --global-config)
            GLOBAL_CONFIG_FILE="$2"
            shift 2
            ;;
        --notify-webhook)
            NOTIFY_WEBHOOK="$2"
            CLI_WEBHOOK_SET=true
            shift 2
            ;;
        --no-summary)
            GENERATE_SUMMARY=false
            shift
            ;;
        -s|--spec)
            SPEC_FILE="$2"
            CLI_SPEC_SET=true
            shift 2
            ;;
        -l|--plan)
            PLAN_FILE="$2"
            CLI_PLAN_SET=true
            shift 2
            ;;
        --progress)
            PROGRESS_FILE="$2"
            CLI_PROGRESS_SET=true
            shift 2
            ;;
        --source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        --context)
            PRODUCT_CONTEXT_DIR="$2"
            shift 2
            ;;
        --output)
            PRODUCT_OUTPUT_DIR="$2"
            shift 2
            ;;
        --artifact-spec)
            ARTIFACT_SPEC_FILE="$2"
            shift 2
            ;;
        plan|build|product)
            PROMPT_SOURCE="preset"
            PRESET_NAME="$1"
            shift
            ;;
        *)
            # Collect positional arguments (for max_iterations)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Handle --list-sessions early (before other processing)
if [ "$LIST_SESSIONS" = true ]; then
    list_sessions
    exit 0
fi

# Process positional args - last numeric arg is max_iterations
for arg in "${POSITIONAL_ARGS[@]}"; do
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS=$arg
        CLI_MAX_SET=true
    fi
done

# Handle unlimited flag (overrides everything)
if [ "$UNLIMITED" = true ]; then
    MAX_ITERATIONS=0
fi

# Handle test mode (single iteration, no push)
if [ "$TEST_MODE" = true ]; then
    MAX_ITERATIONS=1
    PUSH_ENABLED=false
fi

# ═══════════════════════════════════════════════════════════════════════════════
# ENVIRONMENT VARIABLES
# Precedence: CLI > env var > config file > defaults
# Read env vars before config file so config can override defaults but not env vars
# ═══════════════════════════════════════════════════════════════════════════════

# RALPH_MODEL: Model to use (opus, sonnet, haiku)
if [ -n "${RALPH_MODEL:-}" ] && [ "$CLI_MODEL_SET" != "true" ]; then
    MODEL_OVERRIDE="$RALPH_MODEL"
fi

# RALPH_MAX_ITERATIONS: Maximum iterations
if [ -n "${RALPH_MAX_ITERATIONS:-}" ] && [ "$CLI_MAX_SET" != "true" ]; then
    if [[ "$RALPH_MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$RALPH_MAX_ITERATIONS"
    else
        echo -e "${YELLOW}Warning: RALPH_MAX_ITERATIONS must be a number, ignoring: $RALPH_MAX_ITERATIONS${RESET}"
    fi
fi

# RALPH_PUSH_ENABLED: Enable/disable git push (true/false)
if [ -n "${RALPH_PUSH_ENABLED:-}" ] && [ "$CLI_PUSH_SET" != "true" ]; then
    case "$RALPH_PUSH_ENABLED" in
        true|TRUE|1|yes|YES)
            PUSH_ENABLED=true
            ;;
        false|FALSE|0|no|NO)
            PUSH_ENABLED=false
            ;;
        *)
            echo -e "${YELLOW}Warning: RALPH_PUSH_ENABLED must be true/false, ignoring: $RALPH_PUSH_ENABLED${RESET}"
            ;;
    esac
fi

# RALPH_SPEC_FILE: Spec file path
if [ -n "${RALPH_SPEC_FILE:-}" ] && [ "$CLI_SPEC_SET" != "true" ]; then
    SPEC_FILE="$RALPH_SPEC_FILE"
fi

# RALPH_PLAN_FILE: Plan file path
if [ -n "${RALPH_PLAN_FILE:-}" ] && [ "$CLI_PLAN_SET" != "true" ]; then
    PLAN_FILE="$RALPH_PLAN_FILE"
fi

# RALPH_PROGRESS_FILE: Progress file path
if [ -n "${RALPH_PROGRESS_FILE:-}" ] && [ "$CLI_PROGRESS_SET" != "true" ]; then
    PROGRESS_FILE="$RALPH_PROGRESS_FILE"
fi

# RALPH_LOG_DIR: Log directory (already partially supported, formalize here)
if [ -n "${RALPH_LOG_DIR:-}" ] && [ "$CLI_LOG_DIR_SET" != "true" ]; then
    LOG_DIR="$RALPH_LOG_DIR"
fi

# RALPH_LOG_FORMAT: Log format (text or json)
if [ -n "${RALPH_LOG_FORMAT:-}" ] && [ "$CLI_LOG_FORMAT_SET" != "true" ]; then
    case "$RALPH_LOG_FORMAT" in
        text|json)
            LOG_FORMAT="$RALPH_LOG_FORMAT"
            ;;
        *)
            echo -e "${YELLOW}Warning: RALPH_LOG_FORMAT must be text or json, ignoring: $RALPH_LOG_FORMAT${RESET}"
            ;;
    esac
fi

# RALPH_NOTIFY_WEBHOOK: Webhook URL for notifications
if [ -n "${RALPH_NOTIFY_WEBHOOK:-}" ] && [ "$CLI_WEBHOOK_SET" != "true" ]; then
    NOTIFY_WEBHOOK="${RALPH_NOTIFY_WEBHOOK}"
elif [ -z "${NOTIFY_WEBHOOK:-}" ]; then
    NOTIFY_WEBHOOK=""
fi

# Resolve prompt file based on source
case $PROMPT_SOURCE in
    preset)
        PROMPT_FILE="${SCRIPT_DIR}/prompts/PROMPT_${PRESET_NAME}.md"
        MODE="$PRESET_NAME"
        # Default model for presets
        MODEL="${MODEL_OVERRIDE:-opus}"
        ;;
    file)
        PROMPT_FILE="$PROMPT_CONTENT"
        MODE="custom"
        # Default model for custom files
        MODEL="${MODEL_OVERRIDE:-opus}"
        ;;
    inline)
        # Create temp file for inline prompt
        TEMP_PROMPT_FILE=$(mktemp /tmp/ralph_prompt_XXXXXX.md)
        echo "$PROMPT_CONTENT" > "$TEMP_PROMPT_FILE"
        PROMPT_FILE="$TEMP_PROMPT_FILE"
        MODE="inline"
        # Default model for inline (faster)
        MODEL="${MODEL_OVERRIDE:-sonnet}"
        ;;
esac

# Validate prompt file exists
if [ ! -f "$PROMPT_FILE" ]; then
    echo -e "${RED}${SYM_CROSS} Error: Prompt file not found: $PROMPT_FILE${RESET}"
    exit 1
fi

# Validate model
case $MODEL in
    opus|sonnet|haiku) ;;
    *)
        echo -e "${RED}${SYM_CROSS} Error: Invalid model '$MODEL'. Use: opus, sonnet, haiku${RESET}"
        exit 1
        ;;
esac

# Validate log format
case $LOG_FORMAT in
    text|json) ;;
    *)
        echo -e "${RED}${SYM_CROSS} Error: Invalid log format '$LOG_FORMAT'. Use: text, json${RESET}"
        exit 1
        ;;
esac

ITERATION=0
FAILED_ITERATIONS=0
ITERATION_START_HEAD=""
# Get current branch with fallback for non-git environments or errors
# This runs before pre-flight checks, so handle gracefully
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null) || CURRENT_BRANCH=""
[ -z "$CURRENT_BRANCH" ] && CURRENT_BRANCH="unknown"
START_TIME=$(date +%s)

# ═══════════════════════════════════════════════════════════════════════════════
# LOG FILE SETUP
# Precedence: --log-file > --log-dir > RALPH_LOG_DIR > config > default
# ═══════════════════════════════════════════════════════════════════════════════

setup_log_file() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    # Sanitize branch name for filename (replace / with -)
    local safe_branch
    safe_branch=$(echo "$CURRENT_BRANCH" | tr '/' '-')

    # Log filename format: {mode}_{branch}_{timestamp}.log
    local log_filename="${MODE}_${safe_branch}_${timestamp}.log"

    # Determine log file path with precedence
    if [ -n "$LOG_FILE_OVERRIDE" ]; then
        # --log-file takes highest precedence
        LOG_FILE="$LOG_FILE_OVERRIDE"
    else
        # Determine log directory with precedence: --log-dir > RALPH_LOG_DIR > config > default
        local effective_log_dir
        if [ -n "$LOG_DIR" ]; then
            effective_log_dir="$LOG_DIR"
        elif [ -n "${RALPH_LOG_DIR:-}" ]; then
            effective_log_dir="$RALPH_LOG_DIR"
        else
            effective_log_dir="$DEFAULT_LOG_DIR"
        fi

        # Create log directory if it doesn't exist
        if [ ! -d "$effective_log_dir" ]; then
            mkdir -p "$effective_log_dir"
        fi

        LOG_FILE="${effective_log_dir}/${log_filename}"
    fi

    # Create parent directory if needed (for explicit --log-file paths)
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
    fi

    # Create/update latest.log symlink in ~/.ralph/logs/
    if [ -d "$DEFAULT_LOG_DIR" ] || mkdir -p "$DEFAULT_LOG_DIR"; then
        local latest_link="${DEFAULT_LOG_DIR}/latest.log"
        # Convert to absolute path to ensure symlink works from any location
        local abs_log_file
        abs_log_file=$(cd "$(dirname "$LOG_FILE")" && pwd)/$(basename "$LOG_FILE")
        # Use ln -sf for atomic symlink replacement (avoids race condition)
        ln -sf "$abs_log_file" "$latest_link"
    fi
}

# NOTE: setup_log_file is called AFTER load_ralph_config (see below)
# to ensure LOG_DIR from config files is respected

# ═══════════════════════════════════════════════════════════════════════════════
# STRUCTURED LOGGING
# Provides JSON logging option for log aggregation systems (ELK, Datadog, etc.)
# ═══════════════════════════════════════════════════════════════════════════════

# Log a structured event to the log file
# Arguments: event_type, [additional JSON data as key=value pairs]
# Event types: session_start, iteration_start, tool_call, iteration_end, error, session_end
#
# Usage:
#   log_event "session_start"
#   log_event "iteration_start" "iteration=1" "max=10"
#   log_event "tool_call" "tool=Read" "file=/path/to/file"
#   log_event "error" "message=Something failed" "code=1"
#
# When LOG_FORMAT=text, this does nothing (raw output goes to log via parse_claude_output)
# When LOG_FORMAT=json, this outputs structured JSON to the log file
log_event() {
    # Only output JSON when format is json
    [ "$LOG_FORMAT" != "json" ] && return 0

    local event_type="$1"
    shift

    local timestamp
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Build JSON data object from key=value pairs
    local data_json="{}"
    for pair in "$@"; do
        local key="${pair%%=*}"
        local value="${pair#*=}"
        # Escape special characters in value for JSON
        value=$(printf '%s' "$value" | jq -Rs '.')
        # Build data object
        data_json=$(echo "$data_json" | jq --arg k "$key" --argjson v "$value" '. + {($k): $v}')
    done

    # Build complete log entry
    local log_entry
    log_entry=$(jq -nc \
        --arg timestamp "$timestamp" \
        --arg session_id "${SESSION_ID:-}" \
        --arg event "$event_type" \
        --argjson data "$data_json" \
        '{
            timestamp: $timestamp,
            session_id: $session_id,
            event: $event,
            data: $data
        }')

    # Append to log file
    echo "$log_entry" >> "$LOG_FILE"
}

# Log session start event with full configuration
log_session_start() {
    log_event "session_start" \
        "mode=$MODE" \
        "model=$MODEL" \
        "branch=$CURRENT_BRANCH" \
        "max_iterations=$MAX_ITERATIONS" \
        "prompt_file=$PROMPT_FILE" \
        "spec_file=${SPEC_FILE:-}" \
        "plan_file=${PLAN_FILE:-}" \
        "push_enabled=$PUSH_ENABLED" \
        "retry_enabled=$RETRY_ENABLED" \
        "log_format=$LOG_FORMAT"
}

# Log session resume event (called when --resume is used)
# Logs session metadata for log correlation in resumed sessions
log_session_resume() {
    local resumed_iteration="$1"
    log_event "session_resume" \
        "mode=$MODE" \
        "model=$MODEL" \
        "branch=$CURRENT_BRANCH" \
        "max_iterations=$MAX_ITERATIONS" \
        "resumed_at_iteration=$resumed_iteration" \
        "prompt_file=$PROMPT_FILE" \
        "spec_file=${SPEC_FILE:-}" \
        "plan_file=${PLAN_FILE:-}" \
        "push_enabled=$PUSH_ENABLED" \
        "retry_enabled=$RETRY_ENABLED" \
        "log_format=$LOG_FORMAT"
}

# Log iteration start event
# Arguments: iteration_number, max_iterations
log_iteration_start() {
    local iteration="$1"
    local max="$2"
    log_event "iteration_start" \
        "iteration=$iteration" \
        "max=$max"
}

# Log iteration end event
# Arguments: iteration_number, duration_seconds, exit_code, status
log_iteration_end() {
    local iteration="$1"
    local duration="$2"
    local exit_code="$3"
    local status="$4"
    log_event "iteration_end" \
        "iteration=$iteration" \
        "duration=$duration" \
        "exit_code=$exit_code" \
        "status=$status"
}

# Log tool call event
# Arguments: tool_name, detail
log_tool_call() {
    local tool="$1"
    local detail="$2"
    log_event "tool_call" \
        "tool=$tool" \
        "detail=$detail"
}

# Log error event
# Arguments: message, [code]
log_error() {
    local message="$1"
    local code="${2:-1}"
    log_event "error" \
        "message=$message" \
        "code=$code"
}

# Log session end event
# Arguments: status, total_duration, iterations_completed, failed_iterations
log_session_end() {
    local status="$1"
    local duration="$2"
    local completed="$3"
    local failed="$4"
    log_event "session_end" \
        "status=$status" \
        "total_duration=$duration" \
        "iterations_completed=$completed" \
        "failed_iterations=$failed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# WEBHOOK NOTIFICATIONS
# Send POST requests on session completion/failure/interrupt
# ═══════════════════════════════════════════════════════════════════════════════

# Send webhook notification
# Arguments: event_type (session_complete|session_failed|session_interrupted)
# Non-blocking: 10s timeout, failures don't block session
send_webhook() {
    local event_type="$1"

    # Skip if no webhook configured
    [ -z "${NOTIFY_WEBHOOK:-}" ] && return 0

    # Calculate duration
    local total_duration=$(($(date +%s) - START_TIME))
    local minutes=$((total_duration / 60))
    local seconds=$((total_duration % 60))

    # Get last commit summary if available
    local last_commit=""
    last_commit=$(git log -1 --pretty=format:"%s" 2>/dev/null || echo "")

    # Build summary message based on event type
    local summary=""
    case "$event_type" in
        session_complete)
            summary="All tasks complete after ${ITERATION} iteration(s)"
            ;;
        session_failed)
            summary="Session failed after ${ITERATION} iteration(s)"
            ;;
        session_interrupted)
            summary="Session interrupted after ${ITERATION} iteration(s)"
            ;;
        session_max_iterations)
            summary="Reached max iterations (${MAX_ITERATIONS})"
            ;;
        *)
            summary="Session ended: $event_type"
            ;;
    esac

    # Build JSON payload
    local payload
    payload=$(jq -nc \
        --arg event "$event_type" \
        --arg session_id "${SESSION_ID:-unknown}" \
        --arg status "$event_type" \
        --argjson iterations "${ITERATION:-0}" \
        --argjson failed "${FAILED_ITERATIONS:-0}" \
        --argjson duration "$total_duration" \
        --arg duration_human "${minutes}m ${seconds}s" \
        --arg branch "${CURRENT_BRANCH:-unknown}" \
        --arg mode "${MODE:-unknown}" \
        --arg model "${MODEL:-unknown}" \
        --arg summary "$summary" \
        --arg last_commit "$last_commit" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            event: $event,
            session_id: $session_id,
            status: $status,
            iterations: $iterations,
            failed_iterations: $failed,
            duration_seconds: $duration,
            duration_human: $duration_human,
            branch: $branch,
            mode: $mode,
            model: $model,
            summary: $summary,
            last_commit: $last_commit,
            timestamp: $timestamp
        }')

    # Send webhook with 10s timeout, non-blocking on failure
    # Run in background to not block cleanup
    (
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            --connect-timeout 5 \
            --max-time 10 \
            -X POST \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$NOTIFY_WEBHOOK" 2>/dev/null)

        # Log result (only to log file, not terminal during cleanup)
        if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
            echo "  [webhook] Notification sent (HTTP $http_code)" >> "${LOG_FILE:-/dev/null}" 2>/dev/null
        else
            echo "  [webhook] Notification failed (HTTP $http_code)" >> "${LOG_FILE:-/dev/null}" 2>/dev/null
        fi
    ) &

    # Wait briefly for webhook to start, but don't block
    sleep 0.1 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION SUMMARY REPORT
# Generates markdown summary after each session
# ═══════════════════════════════════════════════════════════════════════════════

GENERATE_SUMMARY=true

# Generate session summary report
# Arguments: final_status (complete|failed|interrupted|max_iterations)
# Outputs: {session_id}_summary.md in log directory
generate_summary() {
    local final_status="$1"

    # Skip if disabled
    [ "$GENERATE_SUMMARY" != true ] && return 0

    # Skip if no session file exists
    [ ! -f "$SESSION_FILE" ] && return 0

    # Determine log directory
    local log_dir
    log_dir=$(dirname "${LOG_FILE:-${DEFAULT_LOG_DIR}/session.log}")
    mkdir -p "$log_dir" 2>/dev/null || log_dir="$DEFAULT_LOG_DIR"

    local summary_file="${log_dir}/${SESSION_ID}_summary.md"

    # Calculate total duration
    local total_duration=$(($(date +%s) - START_TIME))
    local duration_min=$((total_duration / 60))
    local duration_sec=$((total_duration % 60))

    # Get session data from session file
    local mode model branch start_time iter_count max_iter
    mode=$(jq -r '.mode // "unknown"' "$SESSION_FILE" 2>/dev/null)
    model=$(jq -r '.model // "unknown"' "$SESSION_FILE" 2>/dev/null)
    branch=$(jq -r '.branch // "unknown"' "$SESSION_FILE" 2>/dev/null)
    start_time=$(jq -r '.start_time // "unknown"' "$SESSION_FILE" 2>/dev/null)
    iter_count=$(jq -r '.current_iteration // 0' "$SESSION_FILE" 2>/dev/null)
    max_iter=$(jq -r '.max_iterations // 0' "$SESSION_FILE" 2>/dev/null)

    # Get spec and plan files
    local spec_file plan_file progress_file
    spec_file=$(jq -r '.spec_file // ""' "$SESSION_FILE" 2>/dev/null)
    plan_file=$(jq -r '.plan_file // ""' "$SESSION_FILE" 2>/dev/null)
    progress_file=$(jq -r '.progress_file // ""' "$SESSION_FILE" 2>/dev/null)

    # Determine status emoji and text
    local status_emoji status_text
    case "$final_status" in
        complete)
            status_emoji="✅"
            status_text="Complete"
            ;;
        failed)
            status_emoji="❌"
            status_text="Failed"
            ;;
        interrupted)
            status_emoji="⚠️"
            status_text="Interrupted"
            ;;
        max_iterations)
            status_emoji="🔄"
            status_text="Max Iterations Reached"
            ;;
        *)
            status_emoji="❓"
            status_text="Unknown ($final_status)"
            ;;
    esac

    # Start writing summary
    {
        echo "# Ralph Session Summary"
        echo ""
        echo "## Session Overview"
        echo ""
        echo "| Property | Value |"
        echo "|----------|-------|"
        echo "| **Status** | ${status_emoji} ${status_text} |"
        echo "| **Session ID** | \`${SESSION_ID}\` |"
        echo "| **Mode** | ${mode} |"
        echo "| **Model** | ${model} |"
        echo "| **Branch** | \`${branch}\` |"
        echo "| **Started** | ${start_time} |"
        echo "| **Duration** | ${duration_min}m ${duration_sec}s |"
        echo "| **Iterations** | ${iter_count}/${max_iter} |"
        echo ""

        # Configuration section
        echo "## Configuration"
        echo ""
        echo "| File | Path |"
        echo "|------|------|"
        [ -n "$spec_file" ] && echo "| Spec | \`${spec_file}\` |"
        [ -n "$plan_file" ] && echo "| Plan | \`${plan_file}\` |"
        [ -n "$progress_file" ] && echo "| Progress | \`${progress_file}\` |"
        echo "| Log | \`${LOG_FILE:-N/A}\` |"
        echo ""

        # Iteration Details section
        echo "## Iteration Details"
        echo ""

        local iteration_count
        iteration_count=$(jq '.iteration_history | length' "$SESSION_FILE" 2>/dev/null || echo "0")

        if [ "$iteration_count" -gt 0 ]; then
            echo "| # | Duration | Exit | Files | Commit |"
            echo "|---|----------|------|-------|--------|"

            # Use jq to format iteration history
            jq -r '.iteration_history[] | "| \(.iteration) | \(.duration)s | \(.exit_code) | \(.files_modified) | \(.commit_message // "-")[0:50] |"' "$SESSION_FILE" 2>/dev/null
            echo ""

            # Timing breakdown
            echo "### Timing Breakdown"
            echo ""
            local total_iter_time avg_iter_time
            total_iter_time=$(jq '[.iteration_history[].duration] | add // 0' "$SESSION_FILE" 2>/dev/null)
            if [ "$iteration_count" -gt 0 ]; then
                avg_iter_time=$((total_iter_time / iteration_count))
            else
                avg_iter_time=0
            fi
            echo "- **Total iteration time:** ${total_iter_time}s"
            echo "- **Average per iteration:** ${avg_iter_time}s"
            echo "- **Overhead:** $((total_duration - total_iter_time))s"
            echo ""
        else
            echo "*No iterations completed*"
            echo ""
        fi

        # Files Modified section
        echo "## Files Modified"
        echo ""
        local files_modified
        files_modified=$(git diff --name-only HEAD~"${iter_count}" HEAD 2>/dev/null | head -30)
        if [ -n "$files_modified" ]; then
            echo '```'
            echo "$files_modified"
            echo '```'
            local file_count
            file_count=$(echo "$files_modified" | wc -l | tr -d ' ')
            if [ "$file_count" -ge 30 ]; then
                echo "*... and possibly more (showing first 30)*"
            fi
        else
            echo "*No file changes detected or unable to determine*"
        fi
        echo ""

        # Commits Made section
        echo "## Commits Made"
        echo ""
        local commits
        commits=$(git log --oneline HEAD~"${iter_count}"..HEAD 2>/dev/null | head -20)
        if [ -n "$commits" ]; then
            echo '```'
            echo "$commits"
            echo '```'
        else
            echo "*No commits detected or unable to determine*"
        fi
        echo ""

        # Errors section (for failed/interrupted sessions)
        if [ "$final_status" = "failed" ] || [ "$final_status" = "interrupted" ]; then
            echo "## Troubleshooting"
            echo ""

            # Check for failed iterations
            local failed_iters
            failed_iters=$(jq '[.iteration_history[] | select(.exit_code != 0)] | length' "$SESSION_FILE" 2>/dev/null || echo "0")

            if [ "$failed_iters" -gt 0 ]; then
                echo "### Failed Iterations"
                echo ""
                jq -r '.iteration_history[] | select(.exit_code != 0) | "- **Iteration \(.iteration):** exit code \(.exit_code)"' "$SESSION_FILE" 2>/dev/null
                echo ""
            fi

            echo "### Suggested Actions"
            echo ""
            case "$final_status" in
                failed)
                    echo "1. Check the log file for detailed error messages:"
                    echo "   \`\`\`"
                    echo "   tail -100 ${LOG_FILE:-'~/.ralph/logs/latest.log'}"
                    echo "   \`\`\`"
                    echo "2. Review the last iteration output for specific errors"
                    echo "3. Check if API rate limits were exceeded"
                    echo "4. Verify the spec/plan files are valid"
                    ;;
                interrupted)
                    echo "1. Resume the session with: \`./ralph.sh --resume\`"
                    echo "2. Check \`.ralph-session.json\` for session state"
                    echo "3. Review progress.txt for completed work"
                    ;;
            esac
            echo ""
        fi

        # Links section
        echo "## Related Files"
        echo ""
        echo "- **Full Log:** [\`${LOG_FILE:-N/A}\`](${LOG_FILE:-})"
        echo "- **Session State:** [\`.ralph-session.json\`](.ralph-session.json) (if preserved)"
        [ -n "$progress_file" ] && echo "- **Progress:** [\`${progress_file}\`](${progress_file})"
        [ -n "$plan_file" ] && echo "- **Plan:** [\`${plan_file}\`](${plan_file})"
        echo ""

        # Footer
        echo "---"
        echo "*Generated by ralph.sh at $(date -u +%Y-%m-%dT%H:%M:%SZ)*"

    } > "$summary_file"

    echo -e "  ${DIM}Summary:${RESET} ${summary_file}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INTERACTIVE CONFIRMATION MODE
# Prompts user for confirmation between iterations
# ═══════════════════════════════════════════════════════════════════════════════

# Display iteration summary before interactive prompt
# Arguments: iteration_number, duration, exit_code
show_iteration_summary() {
    local iteration="$1"
    local duration="$2"
    local exit_code="$3"

    echo -e "\n${CYAN}${BOLD}┌─────────────────────────────────────────┐${RESET}"
    echo -e "${CYAN}${BOLD}│${RESET}      ${BOLD}Iteration $iteration Summary${RESET}               ${CYAN}${BOLD}│${RESET}"
    echo -e "${CYAN}${BOLD}├─────────────────────────────────────────┤${RESET}"
    echo -e "${CYAN}${BOLD}│${RESET}  Duration: ${duration}s                          ${CYAN}${BOLD}│${RESET}"

    if [ "$exit_code" -eq 0 ]; then
        echo -e "${CYAN}${BOLD}│${RESET}  Status:   ${GREEN}${SYM_CHECK} Success${RESET}                      ${CYAN}${BOLD}│${RESET}"
    else
        echo -e "${CYAN}${BOLD}│${RESET}  Status:   ${RED}${SYM_CROSS} Had errors${RESET}                   ${CYAN}${BOLD}│${RESET}"
    fi

    # Show files changed
    local files_changed=0
    files_changed=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    echo -e "${CYAN}${BOLD}│${RESET}  Files:    ${files_changed} changed                        ${CYAN}${BOLD}│${RESET}"

    echo -e "${CYAN}${BOLD}└─────────────────────────────────────────┘${RESET}"
}

# Prompt user to continue to next iteration
# Returns: 0 to continue, 1 to stop, 2 to show diff then prompt again
# Arguments: timeout_seconds
prompt_continue() {
    local timeout="$1"

    # Check if running in a TTY
    if [ ! -t 0 ]; then
        echo -e "${YELLOW}Warning: Interactive mode requires a TTY. Continuing automatically...${RESET}"
        return 0
    fi

    echo -e "\n${YELLOW}${BOLD}Continue to next iteration?${RESET} [${GREEN}Y${RESET}/n/s] (timeout: ${timeout}s)"
    echo -e "  ${DIM}Y = continue, n = stop, s = show git diff${RESET}"
    echo -n "> "

    local response
    if read -r -t "$timeout" response; then
        case "${response,,}" in  # Convert to lowercase
            ""|y|yes)
                return 0  # Continue
                ;;
            n|no)
                return 1  # Stop
                ;;
            s|show|diff)
                return 2  # Show diff
                ;;
            *)
                echo -e "${YELLOW}Unknown option '${response}'. Continuing...${RESET}"
                return 0
                ;;
        esac
    else
        # Timeout - continue by default
        echo -e "\n${DIM}Timeout reached. Continuing to next iteration...${RESET}"
        return 0
    fi
}

# Handle interactive confirmation between iterations
# Arguments: iteration_number, duration, exit_code
# Returns: 0 to continue, 1 to stop
handle_interactive_confirmation() {
    local iteration="$1"
    local duration="$2"
    local exit_code="$3"

    # Show iteration summary first
    show_iteration_summary "$iteration" "$duration" "$exit_code"

    while true; do
        prompt_continue "$INTERACTIVE_TIMEOUT"
        local result=$?

        case $result in
            0)  # Continue
                return 0
                ;;
            1)  # Stop
                echo -e "\n${YELLOW}${SYM_DOT} User requested stop. Ending session...${RESET}"
                return 1
                ;;
            2)  # Show diff
                echo -e "\n${CYAN}${BOLD}Git Diff:${RESET}"
                echo -e "${DIM}───────────────────────────────────────${RESET}"
                git diff --stat 2>/dev/null || echo "  (no changes)"
                echo -e "${DIM}───────────────────────────────────────${RESET}"
                echo ""
                # Loop back to prompt again
                ;;
        esac
    done
}

# Cleanup temp files on exit
cleanup_temp() {
    [ -n "$TEMP_PROMPT_FILE" ] && [ -f "$TEMP_PROMPT_FILE" ] && rm -f "$TEMP_PROMPT_FILE"
    [ -n "$COMPLETION_FILE" ] && [ -f "$COMPLETION_FILE" ] && rm -f "$COMPLETION_FILE"
    [ -n "$ITERATION_STATUS_FILE" ] && [ -f "$ITERATION_STATUS_FILE" ] && rm -f "$ITERATION_STATUS_FILE"
    [ -n "$ITERATION_REASON_FILE" ] && [ -f "$ITERATION_REASON_FILE" ] && rm -f "$ITERATION_REASON_FILE"
    [ -n "$RETRY_OUTPUT_FILE" ] && [ -f "$RETRY_OUTPUT_FILE" ] && rm -f "$RETRY_OUTPUT_FILE"
}
trap cleanup_temp EXIT

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION LOADING (SAFE)
# Parses config files without using source to prevent arbitrary code execution
# ═══════════════════════════════════════════════════════════════════════════════

# Whitelist of allowed configuration keys
# These are the only keys accepted from ralph.conf files
ALLOWED_CONFIG_KEYS=(
    "SPEC_FILE"
    "PLAN_FILE"
    "PROGRESS_FILE"
    "SOURCE_DIR"
    "MODEL"
    "MAX_ITERATIONS"
    "PUSH_ENABLED"
    "PRODUCT_CONTEXT_DIR"
    "PRODUCT_OUTPUT_DIR"
    "ARTIFACT_SPEC_FILE"
    "LOG_DIR"
    "LOG_FORMAT"
    "NOTIFY_WEBHOOK"
)

# Check if a key is in the allowed whitelist
# Arguments: key_name
# Returns: 0 if allowed, 1 if not allowed
is_allowed_config_key() {
    local key="$1"
    for allowed in "${ALLOWED_CONFIG_KEYS[@]}"; do
        if [ "$key" = "$allowed" ]; then
            return 0
        fi
    done
    return 1
}

# Validate config value based on key type
# Arguments: key, value
# Returns: 0 if valid, 1 if invalid (prints warning)
validate_config_value() {
    local key="$1"
    local value="$2"

    case "$key" in
        MODEL)
            # MODEL must be opus, sonnet, or haiku
            case "$value" in
                opus|sonnet|haiku) return 0 ;;
                *)
                    echo -e "${YELLOW}Warning: Invalid MODEL value '${value}' in config (expected: opus, sonnet, haiku)${RESET}" >&2
                    return 1
                    ;;
            esac
            ;;
        MAX_ITERATIONS)
            # MAX_ITERATIONS must be a positive integer
            if [[ "$value" =~ ^[0-9]+$ ]]; then
                return 0
            else
                echo -e "${YELLOW}Warning: Invalid MAX_ITERATIONS value '${value}' in config (expected: positive integer)${RESET}" >&2
                return 1
            fi
            ;;
        PUSH_ENABLED)
            # PUSH_ENABLED must be true/false
            case "$value" in
                true|false|TRUE|FALSE|1|0|yes|no|YES|NO) return 0 ;;
                *)
                    echo -e "${YELLOW}Warning: Invalid PUSH_ENABLED value '${value}' in config (expected: true/false)${RESET}" >&2
                    return 1
                    ;;
            esac
            ;;
        LOG_FORMAT)
            # LOG_FORMAT must be text or json
            case "$value" in
                text|json|TEXT|JSON) return 0 ;;
                *)
                    echo -e "${YELLOW}Warning: Invalid LOG_FORMAT value '${value}' in config (expected: text, json)${RESET}" >&2
                    return 1
                    ;;
            esac
            ;;
        *)
            # Path-based config values - check for shell command patterns
            # These are dangerous: $(...), `...`, ${...}, $((...)), ||, &&, ;, |
            if [[ "$value" =~ \$\( ]] || \
               [[ "$value" =~ \` ]] || \
               [[ "$value" =~ \$\{ ]] || \
               [[ "$value" =~ \|\| ]] || \
               [[ "$value" =~ \&\& ]] || \
               [[ "$value" =~ \; ]] || \
               [[ "$value" =~ [^/]\|[^/] ]]; then
                echo -e "${YELLOW}Warning: Suspicious shell pattern in config value for ${key}: '${value:0:30}...'${RESET}" >&2
                return 1
            fi
            return 0
            ;;
    esac
}

# Safely parse a config file line by line
# Arguments: config_file_path
# Sets global variables based on config file contents
safe_load_config() {
    local config_file="$1"
    local line_num=0
    local warnings_shown=false

    # Skip if file doesn't exist
    [ ! -f "$config_file" ] && return 0

    # Read file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))

        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        # Remove leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Match KEY=VALUE pattern (no spaces around =, value can be quoted or unquoted)
        # Pattern: KEY=VALUE or KEY="VALUE" or KEY='VALUE'
        if [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Remove surrounding quotes if present
            if [[ "$value" =~ ^\"(.*)\"$ ]] || [[ "$value" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi

            # Check if key is in whitelist
            if ! is_allowed_config_key "$key"; then
                echo -e "${YELLOW}Warning: Unknown config key '${key}' at line ${line_num} (ignored)${RESET}" >&2
                warnings_shown=true
                continue
            fi

            # Validate value based on key type
            if ! validate_config_value "$key" "$value"; then
                warnings_shown=true
                continue
            fi

            # Set the variable (only if not already set by CLI/env)
            case "$key" in
                SPEC_FILE)
                    [ "$CLI_SPEC_SET" != "true" ] && [ -z "$SPEC_FILE" ] && SPEC_FILE="$value"
                    ;;
                PLAN_FILE)
                    [ "$CLI_PLAN_SET" != "true" ] && [ -z "$PLAN_FILE" ] && PLAN_FILE="$value"
                    ;;
                PROGRESS_FILE)
                    [ "$CLI_PROGRESS_SET" != "true" ] && [ -z "$PROGRESS_FILE" ] && PROGRESS_FILE="$value"
                    ;;
                SOURCE_DIR)
                    [ -z "$SOURCE_DIR" ] && SOURCE_DIR="$value"
                    ;;
                MODEL)
                    [ "$CLI_MODEL_SET" != "true" ] && [ -z "$MODEL_OVERRIDE" ] && MODEL_OVERRIDE="$value"
                    ;;
                MAX_ITERATIONS)
                    [ "$CLI_MAX_SET" != "true" ] && [ "$UNLIMITED" != "true" ] && MAX_ITERATIONS="$value"
                    ;;
                PUSH_ENABLED)
                    if [ "$CLI_PUSH_SET" != "true" ]; then
                        case "$value" in
                            true|TRUE|1|yes|YES) PUSH_ENABLED=true ;;
                            false|FALSE|0|no|NO) PUSH_ENABLED=false ;;
                        esac
                    fi
                    ;;
                PRODUCT_CONTEXT_DIR)
                    [ -z "$PRODUCT_CONTEXT_DIR" ] && PRODUCT_CONTEXT_DIR="$value"
                    ;;
                PRODUCT_OUTPUT_DIR)
                    [ -z "$PRODUCT_OUTPUT_DIR" ] && PRODUCT_OUTPUT_DIR="$value"
                    ;;
                ARTIFACT_SPEC_FILE)
                    [ -z "$ARTIFACT_SPEC_FILE" ] && ARTIFACT_SPEC_FILE="$value"
                    ;;
                LOG_DIR)
                    [ "$CLI_LOG_DIR_SET" != "true" ] && [ -z "$LOG_DIR" ] && LOG_DIR="$value"
                    ;;
                LOG_FORMAT)
                    # Normalize to lowercase (validation accepts TEXT/JSON but rest of script expects lowercase)
                    # Only override if CLI wasn't used AND env var wasn't set
                    # (checking env var presence ensures explicit RALPH_LOG_FORMAT=text isn't overridden)
                    local normalized_format
                    normalized_format=$(echo "$value" | tr '[:upper:]' '[:lower:]')
                    [ "$CLI_LOG_FORMAT_SET" != "true" ] && [ -z "${RALPH_LOG_FORMAT:-}" ] && LOG_FORMAT="$normalized_format"
                    ;;
                NOTIFY_WEBHOOK)
                    # Only override if CLI wasn't used (respects --notify-webhook "" to disable)
                    [ "$CLI_WEBHOOK_SET" != "true" ] && [ -z "$NOTIFY_WEBHOOK" ] && NOTIFY_WEBHOOK="$value"
                    ;;
            esac
        elif [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
            # Line doesn't match KEY=VALUE pattern and isn't empty/comment
            echo -e "${YELLOW}Warning: Malformed config line ${line_num}: '${line:0:40}...'${RESET}" >&2
            warnings_shown=true
        fi
    done < "$config_file"

    # Add a blank line after warnings for readability
    [ "$warnings_shown" = true ] && echo "" >&2
}

# Load config files safely (CLI args override config values)
# Precedence: CLI > project ralph.conf > ~/.ralph/config > defaults
load_ralph_config() {
    local global_config
    local project_config="${SCRIPT_DIR}/ralph.conf"

    # Determine global config path (CLI --global-config > default location)
    if [ -n "$GLOBAL_CONFIG_FILE" ]; then
        global_config="$GLOBAL_CONFIG_FILE"
    else
        global_config="${HOME}/.ralph/config"
    fi

    # Create ~/.ralph/ directory if it doesn't exist (for first run)
    if [ ! -d "${HOME}/.ralph" ]; then
        mkdir -p "${HOME}/.ralph"
    fi

    # Load global config first (lowest precedence after defaults)
    if [ -f "$global_config" ]; then
        safe_load_config "$global_config"
        LOADED_CONFIG_FILES+=("$global_config")
    fi

    # Load project config second (overrides global)
    if [ -f "$project_config" ]; then
        safe_load_config "$project_config"
        LOADED_CONFIG_FILES+=("$project_config")
    fi
}

substitute_template() {
    local content="$1"
    content="${content//\{\{SPEC_FILE\}\}/$SPEC_FILE}"
    content="${content//\{\{PLAN_FILE\}\}/$PLAN_FILE}"
    content="${content//\{\{PROGRESS_FILE\}\}/$PROGRESS_FILE}"
    content="${content//\{\{SOURCE_DIR\}\}/$SOURCE_DIR}"
    # Product mode variables
    content="${content//\{\{PRODUCT_CONTEXT_DIR\}\}/$PRODUCT_CONTEXT_DIR}"
    content="${content//\{\{PRODUCT_OUTPUT_DIR\}\}/$PRODUCT_OUTPUT_DIR}"
    content="${content//\{\{ARTIFACT_SPEC_FILE\}\}/$ARTIFACT_SPEC_FILE}"
    echo "$content"
}

# Load config file (CLI args override config values)
load_ralph_config

# Set up log file AFTER config is loaded so LOG_DIR from config is respected
# Precedence: --log-file > --log-dir > RALPH_LOG_DIR > config LOG_DIR > default
setup_log_file

# Apply defaults for any values not set by CLI or config
SPEC_FILE="${SPEC_FILE:-./specs/IMPLEMENTATION_PLAN.md}"
PROGRESS_FILE="${PROGRESS_FILE:-progress.txt}"
SOURCE_DIR="${SOURCE_DIR:-src/*}"

# Product mode defaults
PRODUCT_CONTEXT_DIR="${PRODUCT_CONTEXT_DIR:-./product-input/}"
PRODUCT_OUTPUT_DIR="${PRODUCT_OUTPUT_DIR:-./product-output/}"
ARTIFACT_SPEC_FILE="${ARTIFACT_SPEC_FILE:-./docs/PRODUCT_ARTIFACT_SPEC.md}"

# Derive plan file from spec file if spec was set via CLI but plan wasn't
# e.g., ./specs/feature.md → ./plans/feature_PLAN.md
# e.g., ./specs/feature.json → ./plans/feature_PLAN.md
if [ "$CLI_SPEC_SET" = "true" ] && [ "$CLI_PLAN_SET" != "true" ]; then
    spec_basename=$(basename "$SPEC_FILE")
    spec_basename="${spec_basename%.md}"    # Strip .md if present
    spec_basename="${spec_basename%.json}"  # Strip .json if present
    PLAN_FILE="./plans/${spec_basename}_PLAN.md"
else
    PLAN_FILE="${PLAN_FILE:-./plans/IMPLEMENTATION_PLAN.md}"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# BRANCH-CHANGE ARCHIVING
# Archives previous branch's specs and progress when switching branches
# ═══════════════════════════════════════════════════════════════════════════════

LAST_BRANCH_FILE="${SCRIPT_DIR}/.ralph-last-branch"
ARCHIVE_DIR="${SCRIPT_DIR}/archive"

archive_branch_state() {
    local previous_branch="$1"
    local archive_subdir="${ARCHIVE_DIR}/$(date +%Y-%m-%d)-${previous_branch}"

    # Check if there's anything to archive
    local has_content=false
    [ -f "$SPEC_FILE" ] && has_content=true
    [ -f "$PLAN_FILE" ] && has_content=true
    [ -f "$PROGRESS_FILE" ] && has_content=true

    if [ "$has_content" = false ]; then
        return 0
    fi

    echo -e "\n${MAGENTA}${BOLD}  📦 Archiving previous branch: ${previous_branch}${RESET}"

    # Create archive directory
    mkdir -p "$archive_subdir"

    # Archive spec file if exists
    if [ -f "$SPEC_FILE" ]; then
        cp "$SPEC_FILE" "$archive_subdir/"
        echo -e "     ${DIM}→${RESET} Archived $(basename "$SPEC_FILE")"
    fi

    # Archive plan file if exists
    if [ -f "$PLAN_FILE" ]; then
        cp "$PLAN_FILE" "$archive_subdir/"
        echo -e "     ${DIM}→${RESET} Archived $(basename "$PLAN_FILE")"
    fi

    # Archive progress file if exists
    if [ -f "$PROGRESS_FILE" ]; then
        cp "$PROGRESS_FILE" "$archive_subdir/"
        echo -e "     ${DIM}→${RESET} Archived $(basename "$PROGRESS_FILE")"
        # Reset progress file for new branch
        echo "# Progress for branch: $CURRENT_BRANCH" > "$PROGRESS_FILE"
        echo "# Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$PROGRESS_FILE"
        echo "" >> "$PROGRESS_FILE"
        echo -e "     ${DIM}→${RESET} Reset progress.txt for new branch"
    fi

    echo -e "     ${GREEN}${SYM_CHECK}${RESET} Archived to: ${DIM}${archive_subdir}${RESET}\n"
}

check_branch_change() {
    local current="$CURRENT_BRANCH"

    # Read last branch if file exists
    if [ -f "$LAST_BRANCH_FILE" ]; then
        local last_branch=$(cat "$LAST_BRANCH_FILE" 2>/dev/null)

        # Check if branch changed
        if [ -n "$last_branch" ] && [ "$last_branch" != "$current" ]; then
            archive_branch_state "$last_branch"
        fi
    fi

    # Update last branch file
    echo "$current" > "$LAST_BRANCH_FILE"
}

# Check for branch change and archive if needed
check_branch_change

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

print_header() {
    echo -e "\n${CYAN}${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
    if [ "$TEST_MODE" = true ]; then
        echo -e "${CYAN}${BOLD}║${RESET}                 ${YELLOW}${BOLD}⚠ TEST MODE${RESET} ${BOLD}RALPH LOOP${RESET}                       ${CYAN}${BOLD}║${RESET}"
    elif [ "$INTERACTIVE_MODE" = true ]; then
        echo -e "${CYAN}${BOLD}║${RESET}              ${YELLOW}${BOLD}⚡ INTERACTIVE${RESET} ${BOLD}RALPH LOOP${RESET}                     ${CYAN}${BOLD}║${RESET}"
    else
        echo -e "${CYAN}${BOLD}║${RESET}                      ${BOLD}RALPH LOOP${RESET}                              ${CYAN}${BOLD}║${RESET}"
    fi
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}\n"
}

print_config() {
    echo -e "${DIM}┌─────────────────────────────────────────┐${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Mode${RESET}     ${SYM_ARROW} ${GREEN}$MODE${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Model${RESET}    ${SYM_ARROW} ${CYAN}$MODEL${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Prompt${RESET}   ${SYM_ARROW} ${BLUE}$PROMPT_FILE${RESET}"
    if [ "$MODE" = "product" ]; then
        # Product mode specific config
        echo -e "${DIM}│${RESET} ${BOLD}Context${RESET}  ${SYM_ARROW} ${DIM}$PRODUCT_CONTEXT_DIR${RESET}"
        echo -e "${DIM}│${RESET} ${BOLD}Output${RESET}   ${SYM_ARROW} ${DIM}$PRODUCT_OUTPUT_DIR${RESET}"
        echo -e "${DIM}│${RESET} ${BOLD}ArtSpec${RESET}  ${SYM_ARROW} ${DIM}$ARTIFACT_SPEC_FILE${RESET}"
    else
        # Build/plan mode config
        echo -e "${DIM}│${RESET} ${BOLD}Spec${RESET}     ${SYM_ARROW} ${DIM}$SPEC_FILE${RESET}"
        echo -e "${DIM}│${RESET} ${BOLD}Plan${RESET}     ${SYM_ARROW} ${DIM}$PLAN_FILE${RESET}"
        echo -e "${DIM}│${RESET} ${BOLD}Source${RESET}   ${SYM_ARROW} ${DIM}$SOURCE_DIR${RESET}"
    fi
    echo -e "${DIM}│${RESET} ${BOLD}Progress${RESET} ${SYM_ARROW} ${DIM}$PROGRESS_FILE${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Branch${RESET}   ${SYM_ARROW} ${MAGENTA}$CURRENT_BRANCH${RESET}"
    if [ $MAX_ITERATIONS -eq 0 ]; then
        echo -e "${DIM}│${RESET} ${BOLD}Max${RESET}      ${SYM_ARROW} ${RED}unlimited${RESET}"
    else
        echo -e "${DIM}│${RESET} ${BOLD}Max${RESET}      ${SYM_ARROW} ${YELLOW}$MAX_ITERATIONS iterations${RESET}"
    fi
    if [ "$TEST_MODE" = true ]; then
        echo -e "${DIM}│${RESET} ${BOLD}Test${RESET}     ${SYM_ARROW} ${YELLOW}enabled${RESET} (1 iter, no push, no marker check)"
    fi
    if [ "$INTERACTIVE_MODE" = true ]; then
        echo -e "${DIM}│${RESET} ${BOLD}Interact${RESET} ${SYM_ARROW} ${YELLOW}enabled${RESET} (prompt between iters, timeout ${INTERACTIVE_TIMEOUT}s)"
    fi
    echo -e "${DIM}│${RESET} ${BOLD}Push${RESET}     ${SYM_ARROW} ${DIM}$( [ "$PUSH_ENABLED" = true ] && echo "enabled" || echo "disabled" )${RESET}"
    if [ "$RETRY_ENABLED" = true ]; then
        echo -e "${DIM}│${RESET} ${BOLD}Retry${RESET}    ${SYM_ARROW} ${DIM}enabled (max ${MAX_RETRIES}, backoff ${RETRY_BACKOFF_BASE}s)${RESET}"
    else
        echo -e "${DIM}│${RESET} ${BOLD}Retry${RESET}    ${SYM_ARROW} ${DIM}disabled${RESET}"
    fi
    echo -e "${DIM}│${RESET} ${BOLD}Log${RESET}      ${SYM_ARROW} ${DIM}$LOG_FILE${RESET}"
    if [ "$LOG_FORMAT" = "json" ]; then
        echo -e "${DIM}│${RESET} ${BOLD}LogFmt${RESET}   ${SYM_ARROW} ${CYAN}json${RESET} (structured)"
    fi
    if [ -n "${NOTIFY_WEBHOOK:-}" ]; then
        # Show abbreviated webhook URL (hide potential auth info)
        local webhook_display="${NOTIFY_WEBHOOK}"
        # Strip basic auth from display if present
        if [[ "$webhook_display" == *"@"* ]]; then
            webhook_display=$(echo "$webhook_display" | sed 's|://[^@]*@|://***@|')
        fi
        # Truncate long URLs
        if [ ${#webhook_display} -gt 40 ]; then
            webhook_display="${webhook_display:0:37}..."
        fi
        echo -e "${DIM}│${RESET} ${BOLD}Webhook${RESET}  ${SYM_ARROW} ${CYAN}${webhook_display}${RESET}"
    fi
    # Show loaded config files in dry-run output
    if [ "$DRY_RUN" = true ] && [ ${#LOADED_CONFIG_FILES[@]} -gt 0 ]; then
        echo -e "${DIM}│${RESET}"
        echo -e "${DIM}│${RESET} ${BOLD}Config files loaded:${RESET}"
        for config_file in "${LOADED_CONFIG_FILES[@]}"; do
            echo -e "${DIM}│${RESET}   ${DIM}${SYM_DOT}${RESET} ${config_file}"
        done
    fi
    echo -e "${DIM}└─────────────────────────────────────────┘${RESET}\n"
}

print_iteration_start() {
    local iter=$1
    local max=$2
    local progress=""

    if [ $max -gt 0 ]; then
        progress=" (${iter}/${max})"
    fi

    echo -e "\n${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${YELLOW}${BOLD}  ${SYM_GEAR} ITERATION $((iter + 1))${progress}${RESET}  ${DIM}$(date '+%H:%M:%S')${RESET}"
    echo -e "${YELLOW}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"

    # Log for structured logging
    log_iteration_start "$((iter + 1))" "$max"
}

print_iteration_end() {
    local iter=$1
    local duration=$2
    echo -e "\n${GREEN}${BOLD}  ${SYM_CHECK} Iteration $((iter + 1)) complete${RESET} ${DIM}(${duration}s)${RESET}\n"
}

print_tool_call() {
    local tool=$1
    local detail=$2

    case $tool in
        Read|Glob|Grep)
            echo -e "  ${BLUE}${SYM_SEARCH}${RESET} ${DIM}$tool${RESET} ${detail}"
            ;;
        Write|Edit)
            echo -e "  ${MAGENTA}${SYM_EDIT}${RESET} ${DIM}$tool${RESET} ${detail}"
            ;;
        Bash)
            echo -e "  ${YELLOW}${SYM_GEAR}${RESET} ${DIM}Bash${RESET} ${detail}"
            ;;
        Task)
            echo -e "  ${CYAN}${SYM_DOT}${RESET} ${DIM}Task${RESET} ${detail}"
            ;;
        *)
            echo -e "  ${DIM}${SYM_DOT} $tool${RESET} ${detail}"
            ;;
    esac
}

print_git_status() {
    echo -e "\n${MAGENTA}${BOLD}  ${SYM_GIT} Git Status${RESET}"

    # Get changed files
    local staged=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    local modified=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    local untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

    [ "$staged" -gt 0 ] && echo -e "     ${GREEN}$staged staged${RESET}"
    [ "$modified" -gt 0 ] && echo -e "     ${YELLOW}$modified modified${RESET}"
    [ "$untracked" -gt 0 ] && echo -e "     ${DIM}$untracked untracked${RESET}"

    # Get last commit if any new commits
    local last_commit=$(git log -1 --pretty=format:"%s" 2>/dev/null)
    if [ -n "$last_commit" ]; then
        echo -e "     ${DIM}Last commit:${RESET} ${last_commit:0:50}"
    fi
}

print_push_status() {
    local success=$1
    if [ "$success" = "true" ]; then
        echo -e "  ${GREEN}${SYM_CHECK}${RESET} Pushed to ${MAGENTA}$CURRENT_BRANCH${RESET}"
    else
        echo -e "  ${RED}${SYM_CROSS}${RESET} Push failed"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# JSON STREAM PARSER
# Parse stream-json output and display meaningful information
# Requires: --verbose flag with --output-format=stream-json
# ═══════════════════════════════════════════════════════════════════════════════

parse_claude_output() {
    local tool_count=0
    local files_modified=0
    local files_read=0
    local tests_run=false
    local test_passed=false
    local build_run=false
    local build_passed=false
    local commit_made=false
    local commands_run=0
    local error_count=0
    local last_tool_id=""
    local completion_detected=false
    local last_error_msg=""
    local session_result=""
    local failure_reasons=()
    local modified_files=()
    local commits=()

    # Reset status files
    echo "success" > "$ITERATION_STATUS_FILE"
    > "$ITERATION_REASON_FILE"

    # Process JSON stream line by line
    while IFS= read -r line; do
        # Save ALL raw output to log file for debugging
        echo "$line" >> "$LOG_FILE"

        # Skip empty lines or non-JSON for marker detection
        [ -z "$line" ] && continue
        [[ "$line" != "{"* ]] && continue

        # Check for completion marker ONLY in assistant text output (not tool results/file contents)
        # Assistant text has: {"type":"assistant","message":{"content":[{"type":"text","text":"..."}]}}
        if [[ "$line" == *"$COMPLETION_MARKER"* ]] && [[ "$line" == *'"type":"assistant"'* ]] && [[ "$line" == *'"type":"text"'* ]]; then
            completion_detected=true
            echo -e "\n  ${GREEN}${BOLD}${SYM_CHECK} Completion marker detected!${RESET}"
            # Write to completion file to signal main loop
            echo "COMPLETE" > "$COMPLETION_FILE"
        fi

        # Check for tool_use in assistant messages
        # Format: {"type":"assistant","message":{"content":[{"type":"tool_use","name":"..."}]}}
        if [[ "$line" == *'"tool_use"'* ]] && [[ "$line" == *'"name"'* ]]; then
            # Extract tool name and id using jq
            local tool_info=$(echo "$line" | jq -r '.message.content[]? | select(.type=="tool_use") | "\(.id)|\(.name)|\(.input.file_path // .input.pattern // .input.command // .input.description // "")"' 2>/dev/null)

            if [ -n "$tool_info" ]; then
                # Process each tool (there may be multiple in parallel)
                while IFS= read -r info; do
                    [ -z "$info" ] && continue
                    local tool_id=$(echo "$info" | cut -d'|' -f1)
                    local tool_name=$(echo "$info" | cut -d'|' -f2)
                    local tool_detail=$(echo "$info" | cut -d'|' -f3-)

                    # Skip if we've already shown this tool
                    [[ "$last_tool_id" == *"$tool_id"* ]] && continue
                    last_tool_id="$last_tool_id $tool_id"

                    tool_count=$((tool_count + 1))

                    # Truncate detail
                    [ ${#tool_detail} -gt 50 ] && tool_detail="${tool_detail:0:47}..."

                    case "$tool_name" in
                        Read)
                            files_read=$((files_read + 1))
                            echo -e "  ${BLUE}${SYM_SEARCH}${RESET} Read ${DIM}${tool_detail}${RESET}"
                            ;;
                        Glob)
                            echo -e "  ${BLUE}${SYM_SEARCH}${RESET} Glob ${DIM}${tool_detail}${RESET}"
                            ;;
                        Grep)
                            echo -e "  ${BLUE}${SYM_SEARCH}${RESET} Grep ${DIM}${tool_detail}${RESET}"
                            ;;
                        Write)
                            files_modified=$((files_modified + 1))
                            [[ ! " ${modified_files[*]} " =~ " ${tool_detail} " ]] && modified_files+=("$tool_detail")
                            echo -e "  ${MAGENTA}${SYM_EDIT}${RESET} Write ${DIM}${tool_detail}${RESET}"
                            ;;
                        Edit)
                            files_modified=$((files_modified + 1))
                            [[ ! " ${modified_files[*]} " =~ " ${tool_detail} " ]] && modified_files+=("$tool_detail")
                            echo -e "  ${MAGENTA}${SYM_EDIT}${RESET} Edit ${DIM}${tool_detail}${RESET}"
                            ;;
                        Bash)
                            commands_run=$((commands_run + 1))
                            # Check for specific commands
                            if [[ "$tool_detail" == *"test"* ]] || [[ "$tool_detail" == *"jest"* ]] || [[ "$tool_detail" == *"vitest"* ]]; then
                                tests_run=true
                                echo -e "  ${YELLOW}${SYM_GEAR}${RESET} ${SYM_TEST} Running tests"
                            elif [[ "$tool_detail" == *"git commit"* ]]; then
                                commit_made=true
                                # Extract commit message if possible
                                local commit_msg=$(echo "$tool_detail" | grep -oP '(?<=-m ")[^"]*' | head -1)
                                [ -n "$commit_msg" ] && commits+=("$commit_msg")
                                echo -e "  ${YELLOW}${SYM_GEAR}${RESET} ${SYM_GIT} Committing"
                            elif [[ "$tool_detail" == *"build"* ]] || [[ "$tool_detail" == *"pnpm build"* ]] || [[ "$tool_detail" == *"npm run build"* ]]; then
                                build_run=true
                                echo -e "  ${YELLOW}${SYM_GEAR}${RESET} Building"
                            elif [[ "$tool_detail" == *"lint"* ]]; then
                                echo -e "  ${YELLOW}${SYM_GEAR}${RESET} Linting"
                            elif [[ "$tool_detail" == *"typecheck"* ]] || [[ "$tool_detail" == *"tsc"* ]]; then
                                echo -e "  ${YELLOW}${SYM_GEAR}${RESET} Type checking"
                            else
                                echo -e "  ${YELLOW}${SYM_GEAR}${RESET} Bash ${DIM}${tool_detail}${RESET}"
                            fi
                            ;;
                        Task)
                            echo -e "  ${CYAN}${SYM_DOT}${RESET} Task ${DIM}${tool_detail}${RESET}"
                            ;;
                        TodoWrite)
                            echo -e "  ${CYAN}${SYM_DOT}${RESET} ${DIM}Updating tasks${RESET}"
                            ;;
                        *)
                            echo -e "  ${DIM}${SYM_DOT} $tool_name${RESET}"
                            ;;
                    esac

                    # Log tool call for structured logging
                    log_tool_call "$tool_name" "$tool_detail"
                done <<< "$tool_info"
            fi
        fi

        # Check for final result
        if [[ "$line" == *'"type":"result"'* ]]; then
            local is_error=$(echo "$line" | jq -r '.is_error // false' 2>/dev/null)
            session_result=$(echo "$line" | jq -r '.result // empty' 2>/dev/null)
            if [ "$is_error" = "true" ]; then
                error_count=$((error_count + 1))
                echo -e "  ${RED}${SYM_CROSS} Session ended with error${RESET}"
                local result_error=$(echo "$line" | jq -r '.error // .result // empty' 2>/dev/null)
                if [ -n "$result_error" ]; then
                    failure_reasons+=("Session error: ${result_error:0:200}")
                    echo "failed" > "$ITERATION_STATUS_FILE"
                fi
            fi
        fi

        # Check for errors
        if [[ "$line" == *'"type":"error"'* ]]; then
            error_count=$((error_count + 1))
            local error_msg=$(echo "$line" | jq -r '.error.message // .message // empty' 2>/dev/null)
            if [ -n "$error_msg" ]; then
                echo -e "  ${RED}${SYM_CROSS} Error:${RESET} ${error_msg:0:60}"
                last_error_msg="$error_msg"
                failure_reasons+=("Error: ${error_msg:0:200}")
                echo "failed" > "$ITERATION_STATUS_FILE"
                # Log error for structured logging
                log_error "$error_msg"
            fi
        fi

        # Check for tool errors in result messages
        if [[ "$line" == *'"type":"tool_result"'* ]] && [[ "$line" == *'"is_error":true'* ]]; then
            error_count=$((error_count + 1))
            local tool_error=$(echo "$line" | jq -r '.content // empty' 2>/dev/null)
            # Always display error and set failure status, even if content extraction fails
            if [ -n "$tool_error" ]; then
                echo -e "  ${RED}${SYM_CROSS} Tool error:${RESET} ${tool_error:0:60}"
                failure_reasons+=("Tool error: ${tool_error:0:200}")
            else
                echo -e "  ${RED}${SYM_CROSS} Tool error:${RESET} (error content unavailable)"
                failure_reasons+=("Tool error: (content extraction failed)")
            fi
            echo "failed" > "$ITERATION_STATUS_FILE"
        fi

        # Check for system errors or rate limits
        if [[ "$line" == *'"error"'* ]] && [[ "$line" == *'"type":"'* ]]; then
            local sys_error=$(echo "$line" | jq -r '.error.type // empty' 2>/dev/null)
            local sys_msg=$(echo "$line" | jq -r '.error.message // empty' 2>/dev/null)
            if [ -n "$sys_error" ] && [ "$sys_error" != "null" ]; then
                echo -e "  ${RED}${SYM_CROSS} System error (${sys_error}):${RESET} ${sys_msg:0:50}"
                failure_reasons+=("System error ($sys_error): ${sys_msg:0:200}")
                echo "failed" > "$ITERATION_STATUS_FILE"
            fi
        fi
    done

    # Write failure reasons to file
    if [ ${#failure_reasons[@]} -gt 0 ]; then
        printf '%s\n' "${failure_reasons[@]}" > "$ITERATION_REASON_FILE"
    fi

    # Print accomplishment summary
    echo -e "\n"
    echo -e "${DIM}  ─────────────────────────────────────────${RESET}"
    echo -e "  ${BOLD}Iteration Accomplishments${RESET}"

    # Activity stats
    echo -e "     ${DIM}Activity:${RESET} ${tool_count} tool calls, ${commands_run} commands"

    # Files touched
    if [ $files_modified -gt 0 ] || [ $files_read -gt 0 ]; then
        echo -e "     ${DIM}Files:${RESET} ${files_read} read, ${files_modified} modified"
    fi

    # List modified files
    if [ ${#modified_files[@]} -gt 0 ]; then
        echo -e "     ${MAGENTA}${SYM_EDIT} Modified:${RESET}"
        for f in "${modified_files[@]}"; do
            echo -e "        ${DIM}→${RESET} ${f}"
        done
    fi

    # Validation status
    if [ "$tests_run" = true ] || [ "$build_run" = true ]; then
        echo -e "     ${DIM}Validation:${RESET}"
        [ "$tests_run" = true ] && echo -e "        ${SYM_TEST} Tests ran"
        [ "$build_run" = true ] && echo -e "        ${SYM_GEAR} Build ran"
    fi

    # Commits made
    if [ "$commit_made" = true ]; then
        echo -e "     ${SYM_GIT} ${GREEN}Committed${RESET}"
        for c in "${commits[@]}"; do
            echo -e "        ${DIM}→${RESET} ${c:0:50}"
        done
    fi

    # Errors encountered
    if [ $error_count -gt 0 ]; then
        echo -e "     ${RED}${SYM_CROSS} Errors: ${error_count}${RESET}"
        for reason in "${failure_reasons[@]}"; do
            echo -e "        ${RED}→${RESET} ${reason:0:50}"
        done
    fi

    # Completion status
    if [ "$completion_detected" = true ]; then
        echo -e "\n  ${GREEN}${BOLD}${SYM_CHECK} TASK COMPLETE${RESET}"
    else
        echo -e "\n  ${DIM}Session ended - more work remains${RESET}"
    fi

    # Ensure error_count is reflected in status file (fallback for unrecognized patterns)
    # This catches cases where errors were detected but status wasn't explicitly set
    if [ "$error_count" -gt 0 ] && [ "$(cat "$ITERATION_STATUS_FILE" 2>/dev/null)" != "failed" ]; then
        echo "failed" > "$ITERATION_STATUS_FILE"
    fi
    
    # Always return 0 - this function's job is to parse and write status to files.
    # The caller (run_with_retry) checks ITERATION_STATUS_FILE for detected errors
    # and PIPESTATUS for claude CLI failures - these are separate concerns.
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

cleanup() {
    echo -e "\n\n${YELLOW}Interrupted. Cleaning up...${RESET}"
    pkill -P $$ 2>/dev/null

    # Clean up temp prompt file if exists
    [ -n "$TEMP_PROMPT_FILE" ] && [ -f "$TEMP_PROMPT_FILE" ] && rm -f "$TEMP_PROMPT_FILE"

    # Finalize session state (preserves for debugging)
    finalize_session_state "interrupted"

    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))

    # Log session end for structured logging
    log_session_end "interrupted" "$total_duration" "$ITERATION" "$FAILED_ITERATIONS"

    # Send webhook notification (non-blocking)
    send_webhook "session_interrupted"

    echo -e "\n${DIM}┌─────────────────────────────────────────┐${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Session Summary${RESET}"
    echo -e "${DIM}│${RESET}   Iterations: $ITERATION"
    echo -e "${DIM}│${RESET}   Duration: ${total_duration}s"
    echo -e "${DIM}│${RESET}   Log: $LOG_FILE"
    echo -e "${DIM}└─────────────────────────────────────────┘${RESET}"

    exit 130
}

trap cleanup INT TERM

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════════════

# Run pre-flight checks (unless skipped)
if [ "$SKIP_CHECKS" = false ]; then
    preflight_checks
fi

# Handle session resume
if [ "$RESUME_SESSION" = true ]; then
    # Validate and restore session
    if ! validate_session "$SESSION_FILE"; then
        exit 1
    fi
    restore_session "$SESSION_FILE"
    # Skip normal print_header/print_config - restore_session shows its own summary
else
    print_header
    print_config
fi

# Show inline prompt preview if applicable
if [ "$MODE" = "inline" ]; then
    echo -e "${DIM}Prompt: ${PROMPT_CONTENT:0:100}...${RESET}\n"
fi

# Exit early if dry-run
if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}${SYM_CHECK} Dry run complete. Config shown above.${RESET}\n"
    exit 0
fi

# Initialize session state (after config, before main loop)
# Skip if resuming - session state was already restored
if [ "$RESUME_SESSION" != true ]; then
    init_session_state
else
    # Log session resume event for JSON log completeness
    # This ensures resumed sessions have metadata for log correlation
    log_session_resume "$ITERATION"
fi

# Track exit status
EXIT_STATUS=1  # Default: max iterations reached
EXIT_REASON="max_iterations"

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo -e "\n${YELLOW}${SYM_DOT} Reached max iterations: $MAX_ITERATIONS${RESET}"
        EXIT_STATUS=1
        EXIT_REASON="max_iterations"
        break
    fi

    iter_start=$(date +%s)
    print_iteration_start $ITERATION $MAX_ITERATIONS
    
    # Capture HEAD at iteration start for accurate files_modified count
    ITERATION_START_HEAD=$(git rev-parse HEAD 2>/dev/null || echo "")

    # Run Claude with retry logic for transient failures
    # --verbose is required for stream-json, parser filters the noise
    # substitute_template replaces {{SPEC_FILE}}, {{PROGRESS_FILE}}, {{SOURCE_DIR}}
    prompt_content=$(substitute_template "$(cat "$PROMPT_FILE")")
    run_with_retry "$prompt_content"
    claude_exit_code=$?

    # Check if Claude command itself failed after all retries
    if [ "$claude_exit_code" -ne 0 ]; then
        echo "failed" > "$ITERATION_STATUS_FILE"
        echo "Claude CLI exited with code $claude_exit_code (after retries)" >> "$ITERATION_REASON_FILE"
        echo -e "  ${RED}${SYM_CROSS} Claude CLI failed with code ${claude_exit_code}${RESET}"
        log_error "Claude CLI exited with code $claude_exit_code (after retries)" "$claude_exit_code"
    fi

    iter_end=$(date +%s)
    iter_duration=$((iter_end - iter_start))

    # Show git status
    print_git_status

    # Push changes after each iteration (if enabled and there are commits)
    if [ "$PUSH_ENABLED" = true ]; then
        echo -e "\n${MAGENTA}${BOLD}  ${SYM_GIT} Pushing...${RESET}"
        if git rev-parse HEAD >/dev/null 2>&1; then
            if git push origin "$CURRENT_BRANCH" 2>/dev/null; then
                print_push_status "true"
            else
                echo -e "  ${YELLOW}${SYM_DOT}${RESET} Creating remote branch..."
                if git push -u origin "$CURRENT_BRANCH" 2>/dev/null; then
                    print_push_status "true"
                else
                    print_push_status "false"
                fi
            fi
        else
            echo -e "  ${DIM}No commits yet, skipping push${RESET}"
        fi
    else
        echo -e "\n  ${DIM}Push disabled (--no-push)${RESET}"
    fi

    # Track failed iterations
    iter_status=$(cat "$ITERATION_STATUS_FILE" 2>/dev/null || echo "unknown")
    iter_exit_code=0
    if [ "$iter_status" = "failed" ]; then
        FAILED_ITERATIONS=$((FAILED_ITERATIONS + 1))
        iter_exit_code=1
    fi

    # Update session state with iteration metrics
    update_session_state "$((ITERATION + 1))" "$iter_duration" "$iter_exit_code"

    print_iteration_end $ITERATION $iter_duration

    # Log iteration end for structured logging
    log_iteration_end "$((ITERATION + 1))" "$iter_duration" "$iter_exit_code" "$iter_status"

    # Check for completion marker (skip in test mode - always exit after 1 iteration)
    if [ "$TEST_MODE" != true ] && [ -f "$COMPLETION_FILE" ] && [ "$(cat "$COMPLETION_FILE" 2>/dev/null)" = "COMPLETE" ]; then
        echo -e "\n${GREEN}${BOLD}${SYM_CHECK} All tasks complete!${RESET}"
        EXIT_STATUS=0
        EXIT_REASON="complete"
        ITERATION=$((ITERATION + 1))
        break
    fi

    # Interactive confirmation mode - prompt before next iteration
    if [ "$INTERACTIVE_MODE" = true ]; then
        if ! handle_interactive_confirmation "$((ITERATION + 1))" "$iter_duration" "$iter_exit_code"; then
            EXIT_STATUS=0
            EXIT_REASON="user_stopped"
            ITERATION=$((ITERATION + 1))
            break
        fi
    fi

    ITERATION=$((ITERATION + 1))

    # Clear completion file for next iteration
    > "$COMPLETION_FILE"

    # Show status before starting next iteration
    if [ "$iter_status" = "failed" ] && [ -s "$ITERATION_REASON_FILE" ]; then
        # Had errors - show them
        echo -e "\n${YELLOW}${BOLD}┌─────────────────────────────────────────┐${RESET}"
        echo -e "${YELLOW}${BOLD}│${RESET} ${RED}${BOLD}Iteration had errors${RESET}                    ${YELLOW}${BOLD}│${RESET}"
        echo -e "${YELLOW}${BOLD}├─────────────────────────────────────────┤${RESET}"
        while IFS= read -r reason; do
            echo -e "${YELLOW}${BOLD}│${RESET}  ${RED}→${RESET} ${reason:0:38}"
        done < "$ITERATION_REASON_FILE"
        echo -e "${YELLOW}${BOLD}└─────────────────────────────────────────┘${RESET}"
    fi
    echo -e "${CYAN}${BOLD}  ↻ Starting next iteration...${RESET}\n"
done

# Finalize session state based on exit reason
finalize_session_state "$EXIT_REASON"

# Final summary
end_time=$(date +%s)
total_duration=$((end_time - START_TIME))

# Log session end for structured logging
log_session_end "$EXIT_REASON" "$total_duration" "$ITERATION" "$FAILED_ITERATIONS"

# Send webhook notification based on exit reason
case "$EXIT_REASON" in
    complete)
        send_webhook "session_complete"
        ;;
    user_stopped)
        send_webhook "session_user_stopped"
        ;;
    *)
        send_webhook "session_max_iterations"
        ;;
esac

minutes=$((total_duration / 60))
seconds=$((total_duration % 60))

echo -e "\n${CYAN}${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
case "$EXIT_REASON" in
    complete)
        echo -e "${CYAN}${BOLD}║${RESET}              ${GREEN}${BOLD}${SYM_CHECK} ALL TASKS COMPLETE${RESET}                        ${CYAN}${BOLD}║${RESET}"
        ;;
    user_stopped)
        echo -e "${CYAN}${BOLD}║${RESET}              ${YELLOW}${BOLD}${SYM_DOT} STOPPED BY USER${RESET}                           ${CYAN}${BOLD}║${RESET}"
        ;;
    *)
        echo -e "${CYAN}${BOLD}║${RESET}              ${YELLOW}${BOLD}${SYM_DOT} MAX ITERATIONS REACHED${RESET}                     ${CYAN}${BOLD}║${RESET}"
        ;;
esac
echo -e "${CYAN}${BOLD}╠════════════════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}                                                                ${CYAN}${BOLD}║${RESET}"
if [ "$EXIT_STATUS" -eq 0 ]; then
    echo -e "${CYAN}${BOLD}║${RESET}   ${GREEN}Status${RESET}       ${SYM_ARROW} ${GREEN}${BOLD}SUCCESS${RESET}                                   ${CYAN}${BOLD}║${RESET}"
else
    echo -e "${CYAN}${BOLD}║${RESET}   ${YELLOW}Status${RESET}       ${SYM_ARROW} ${YELLOW}Check progress.txt for remaining work${RESET}    ${CYAN}${BOLD}║${RESET}"
fi
echo -e "${CYAN}${BOLD}║${RESET}   ${BOLD}Iterations${RESET}   ${SYM_ARROW} ${ITERATION} of $([ $MAX_ITERATIONS -eq 0 ] && echo "unlimited" || echo "$MAX_ITERATIONS")                                      ${CYAN}${BOLD}║${RESET}"
if [ $FAILED_ITERATIONS -gt 0 ]; then
    echo -e "${CYAN}${BOLD}║${RESET}   ${RED}Failed${RESET}       ${SYM_ARROW} ${RED}${FAILED_ITERATIONS} iteration(s)${RESET}                                  ${CYAN}${BOLD}║${RESET}"
fi
echo -e "${CYAN}${BOLD}║${RESET}   ${BOLD}Duration${RESET}     ${SYM_ARROW} ${minutes}m ${seconds}s                                       ${CYAN}${BOLD}║${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}   ${BOLD}Mode${RESET}         ${SYM_ARROW} ${MODE}                                          ${CYAN}${BOLD}║${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}   ${BOLD}Model${RESET}        ${SYM_ARROW} ${MODEL}                                         ${CYAN}${BOLD}║${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}                                                                ${CYAN}${BOLD}║${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}   ${DIM}Log: $LOG_FILE${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}                                                                ${CYAN}${BOLD}║${RESET}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}\n"

exit $EXIT_STATUS
