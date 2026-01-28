#!/bin/bash
# Ralph Loop - Autonomous Claude Code runner
#
# Usage: ./ralph.sh [preset|options] [max_iterations]
#
# Presets:
#   plan              Use PROMPT_plan.md (default model: opus)
#   build             Use PROMPT_build.md (default model: opus)
#
# Options:
#   -f, --file PATH   Use custom prompt file
#   -p, --prompt STR  Use inline prompt string
#   -m, --model MODEL Model: opus, sonnet, haiku (default varies by mode)
#   -n, --max N       Max iterations (default: 10)
#   --unlimited       Remove iteration limit (use with caution)
#   --dry-run         Show config and exit without running Claude
#   --push            Enable git push after iterations (default)
#   --no-push         Disable git push
#   -s, --spec PATH   Spec file (default: ./specs/IMPLEMENTATION_PLAN.md)
#   -l, --plan PATH   Plan file (derived from spec, or ./plans/IMPLEMENTATION_PLAN.md)
#   --progress PATH   Progress file (default: progress.txt)
#   --source PATH     Source directory (default: src/*)
#   -h, --help        Show this help
#
# Examples:
#   ./ralph.sh                           # Build mode, 10 iterations
#   ./ralph.sh plan 5                    # Plan mode, 5 iterations
#   ./ralph.sh build --model sonnet      # Build with sonnet
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

# Iteration Status Tracking
ITERATION_STATUS_FILE=$(mktemp /tmp/ralph_status_XXXXXX)
ITERATION_REASON_FILE=$(mktemp /tmp/ralph_reason_XXXXXX)

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
    echo ""
    echo -e "${BOLD}Options:${RESET}"
    echo "  -f, --file PATH   Use custom prompt file"
    echo "  -p, --prompt STR  Use inline prompt string"
    echo "  -m, --model MODEL Model: opus, sonnet, haiku"
    echo "  -n, --max N       Max iterations (default: 10)"
    echo "  --unlimited       Remove iteration limit (use with caution)"
    echo "  --dry-run         Show config and exit without running Claude"
    echo "  --push            Enable git push after iterations (default)"
    echo "  --no-push         Disable git push"
    echo "  -s, --spec PATH   Spec file (default: ./specs/IMPLEMENTATION_PLAN.md)"
    echo "  -l, --plan PATH   Plan file (derived from spec if not set, or ./plans/IMPLEMENTATION_PLAN.md)"
    echo "  --progress PATH   Progress file (default: progress.txt)"
    echo "  --source PATH     Source directory (default: src/*)"
    echo "  -h, --help        Show this help"
    echo ""
    echo -e "${BOLD}Examples:${RESET}"
    echo "  ./ralph.sh                           # Build mode, 10 iterations (default)"
    echo "  ./ralph.sh plan 5                    # Plan mode, 5 iterations"
    echo "  ./ralph.sh build --model sonnet      # Build with sonnet, 10 iterations"
    echo "  ./ralph.sh -f ./prompts/review.md    # Custom prompt file"
    echo "  ./ralph.sh -p \"Fix lint errors\" 3    # Inline prompt, 3 iterations"
    echo "  ./ralph.sh build --unlimited         # Unlimited iterations (careful!)"
    echo "  ./ralph.sh -s ./specs/feature.md -l ./plans/feature_PLAN.md  # Custom spec+plan"
    echo ""
    echo -e "${BOLD}Defaults:${RESET}"
    echo "  Iterations: 10 (prevents runaway sessions)"
    echo "  Model:      opus (plan/build), sonnet (inline)"
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
TEMP_PROMPT_FILE=""

# Template variable defaults (CLI args override, then config, then these)
SPEC_FILE=""
PLAN_FILE=""
PROGRESS_FILE=""
SOURCE_DIR=""

# Track CLI-explicit flags (set during arg parsing)
CLI_SPEC_SET=false
CLI_PLAN_SET=false

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
            shift 2
            ;;
        --push)
            PUSH_ENABLED=true
            shift
            ;;
        --no-push)
            PUSH_ENABLED=false
            shift
            ;;
        -n|--max)
            MAX_ITERATIONS="$2"
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
            shift 2
            ;;
        --source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        plan|build)
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

# Process positional args - last numeric arg is max_iterations
ITERATIONS_SET=false
for arg in "${POSITIONAL_ARGS[@]}"; do
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS=$arg
        ITERATIONS_SET=true
    fi
done

# Handle unlimited flag (overrides everything)
if [ "$UNLIMITED" = true ]; then
    MAX_ITERATIONS=0
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

ITERATION=0
FAILED_ITERATIONS=0
CURRENT_BRANCH=$(git branch --show-current)
START_TIME=$(date +%s)
LOG_FILE="/tmp/ralph_${MODE}_$(date +%Y%m%d_%H%M%S).log"

# Cleanup temp files on exit
cleanup_temp() {
    [ -n "$TEMP_PROMPT_FILE" ] && [ -f "$TEMP_PROMPT_FILE" ] && rm -f "$TEMP_PROMPT_FILE"
    [ -n "$COMPLETION_FILE" ] && [ -f "$COMPLETION_FILE" ] && rm -f "$COMPLETION_FILE"
    [ -n "$ITERATION_STATUS_FILE" ] && [ -f "$ITERATION_STATUS_FILE" ] && rm -f "$ITERATION_STATUS_FILE"
    [ -n "$ITERATION_REASON_FILE" ] && [ -f "$ITERATION_REASON_FILE" ] && rm -f "$ITERATION_REASON_FILE"
}
trap cleanup_temp EXIT

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION LOADING
# ═══════════════════════════════════════════════════════════════════════════════

load_ralph_config() {
    local config_file="${SCRIPT_DIR}/ralph.conf"
    if [ -f "$config_file" ]; then
        # Temporarily save CLI values before sourcing config
        local cli_spec="$SPEC_FILE"
        local cli_plan="$PLAN_FILE"
        local cli_progress="$PROGRESS_FILE"
        local cli_source="$SOURCE_DIR"
        local cli_model="$MODEL_OVERRIDE"
        local cli_max="$MAX_ITERATIONS"
        local cli_push="$PUSH_ENABLED"
        local cli_unlimited="$UNLIMITED"

        # Source config file
        source "$config_file"

        # CLI args take precedence over config file
        [ -n "$cli_spec" ] && SPEC_FILE="$cli_spec"
        [ -n "$cli_plan" ] && PLAN_FILE="$cli_plan"
        [ -n "$cli_progress" ] && PROGRESS_FILE="$cli_progress"
        [ -n "$cli_source" ] && SOURCE_DIR="$cli_source"
        [ -n "$cli_model" ] && MODEL_OVERRIDE="$cli_model"
        # Only restore CLI max if it was explicitly set (not the default)
        [ "$cli_unlimited" = true ] && UNLIMITED=true
        [ -n "$cli_push" ] && PUSH_ENABLED="$cli_push"
    fi
}

substitute_template() {
    local content="$1"
    content="${content//\{\{SPEC_FILE\}\}/$SPEC_FILE}"
    content="${content//\{\{PLAN_FILE\}\}/$PLAN_FILE}"
    content="${content//\{\{PROGRESS_FILE\}\}/$PROGRESS_FILE}"
    content="${content//\{\{SOURCE_DIR\}\}/$SOURCE_DIR}"
    echo "$content"
}

# Load config file (CLI args override config values)
load_ralph_config

# Apply defaults for any values not set by CLI or config
SPEC_FILE="${SPEC_FILE:-./specs/IMPLEMENTATION_PLAN.md}"
PROGRESS_FILE="${PROGRESS_FILE:-progress.txt}"
SOURCE_DIR="${SOURCE_DIR:-src/*}"

# Derive plan file from spec file if spec was set via CLI but plan wasn't
# e.g., ./specs/feature.md → ./plans/feature_PLAN.md
if [ "$CLI_SPEC_SET" = "true" ] && [ "$CLI_PLAN_SET" != "true" ]; then
    spec_basename=$(basename "$SPEC_FILE" .md)
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
    echo -e "${CYAN}${BOLD}║${RESET}                      ${BOLD}RALPH LOOP${RESET}                              ${CYAN}${BOLD}║${RESET}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}\n"
}

print_config() {
    echo -e "${DIM}┌─────────────────────────────────────────┐${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Mode${RESET}     ${SYM_ARROW} ${GREEN}$MODE${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Model${RESET}    ${SYM_ARROW} ${CYAN}$MODEL${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Prompt${RESET}   ${SYM_ARROW} ${BLUE}$PROMPT_FILE${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Spec${RESET}     ${SYM_ARROW} ${DIM}$SPEC_FILE${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Plan${RESET}     ${SYM_ARROW} ${DIM}$PLAN_FILE${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Progress${RESET} ${SYM_ARROW} ${DIM}$PROGRESS_FILE${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Source${RESET}   ${SYM_ARROW} ${DIM}$SOURCE_DIR${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Branch${RESET}   ${SYM_ARROW} ${MAGENTA}$CURRENT_BRANCH${RESET}"
    if [ $MAX_ITERATIONS -eq 0 ]; then
        echo -e "${DIM}│${RESET} ${BOLD}Max${RESET}      ${SYM_ARROW} ${RED}unlimited${RESET}"
    else
        echo -e "${DIM}│${RESET} ${BOLD}Max${RESET}      ${SYM_ARROW} ${YELLOW}$MAX_ITERATIONS iterations${RESET}"
    fi
    echo -e "${DIM}│${RESET} ${BOLD}Push${RESET}     ${SYM_ARROW} ${DIM}$( [ "$PUSH_ENABLED" = true ] && echo "enabled" || echo "disabled" )${RESET}"
    echo -e "${DIM}│${RESET} ${BOLD}Log${RESET}      ${SYM_ARROW} ${DIM}$LOG_FILE${RESET}"
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

        # Check for completion marker in any line (text or JSON)
        if [[ "$line" == *"$COMPLETION_MARKER"* ]]; then
            completion_detected=true
            echo -e "\n  ${GREEN}${BOLD}${SYM_CHECK} Completion marker detected!${RESET}"
            # Write to completion file to signal main loop
            echo "COMPLETE" > "$COMPLETION_FILE"
        fi

        # Skip empty lines or non-JSON
        [ -z "$line" ] && continue
        [[ "$line" != "{"* ]] && continue

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
            fi
        fi

        # Check for tool errors in result messages
        if [[ "$line" == *'"type":"tool_result"'* ]] && [[ "$line" == *'"is_error":true'* ]]; then
            local tool_error=$(echo "$line" | jq -r '.content // empty' 2>/dev/null)
            if [ -n "$tool_error" ]; then
                echo -e "  ${RED}${SYM_CROSS} Tool error:${RESET} ${tool_error:0:60}"
                failure_reasons+=("Tool error: ${tool_error:0:200}")
            fi
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
}

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

cleanup() {
    echo -e "\n\n${YELLOW}Interrupted. Cleaning up...${RESET}"
    pkill -P $$ 2>/dev/null

    # Clean up temp prompt file if exists
    [ -n "$TEMP_PROMPT_FILE" ] && [ -f "$TEMP_PROMPT_FILE" ] && rm -f "$TEMP_PROMPT_FILE"

    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))

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

print_header
print_config

# Show inline prompt preview if applicable
if [ "$MODE" = "inline" ]; then
    echo -e "${DIM}Prompt: ${PROMPT_CONTENT:0:100}...${RESET}\n"
fi

# Exit early if dry-run
if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}${SYM_CHECK} Dry run complete. Config shown above.${RESET}\n"
    exit 0
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

    # Run Claude and parse output
    # --verbose is required for stream-json, parser filters the noise
    # substitute_template replaces {{SPEC_FILE}}, {{PROGRESS_FILE}}, {{SOURCE_DIR}}
    # Use pipefail to catch claude command failures
    set -o pipefail
    substitute_template "$(cat "$PROMPT_FILE")" | claude -p \
        --dangerously-skip-permissions \
        --output-format=stream-json \
        --model "$MODEL" \
        --verbose \
        2>&1 | parse_claude_output
    claude_exit_code=${PIPESTATUS[1]}
    set +o pipefail

    # Check if Claude command itself failed
    if [ "$claude_exit_code" -ne 0 ]; then
        echo "failed" > "$ITERATION_STATUS_FILE"
        echo "Claude CLI exited with code $claude_exit_code" >> "$ITERATION_REASON_FILE"
        echo -e "  ${RED}${SYM_CROSS} Claude CLI exited with code ${claude_exit_code}${RESET}"
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
    if [ "$iter_status" = "failed" ]; then
        FAILED_ITERATIONS=$((FAILED_ITERATIONS + 1))
    fi

    print_iteration_end $ITERATION $iter_duration

    # Check for completion marker
    if [ -f "$COMPLETION_FILE" ] && [ "$(cat "$COMPLETION_FILE" 2>/dev/null)" = "COMPLETE" ]; then
        echo -e "\n${GREEN}${BOLD}${SYM_CHECK} All tasks complete!${RESET}"
        EXIT_STATUS=0
        EXIT_REASON="complete"
        ITERATION=$((ITERATION + 1))
        break
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

# Final summary
end_time=$(date +%s)
total_duration=$((end_time - START_TIME))
minutes=$((total_duration / 60))
seconds=$((total_duration % 60))

echo -e "\n${CYAN}${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
if [ "$EXIT_REASON" = "complete" ]; then
    echo -e "${CYAN}${BOLD}║${RESET}              ${GREEN}${BOLD}${SYM_CHECK} ALL TASKS COMPLETE${RESET}                        ${CYAN}${BOLD}║${RESET}"
else
    echo -e "${CYAN}${BOLD}║${RESET}              ${YELLOW}${BOLD}${SYM_DOT} MAX ITERATIONS REACHED${RESET}                     ${CYAN}${BOLD}║${RESET}"
fi
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
