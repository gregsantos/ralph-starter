# Ralph Loop

Autonomous Claude Code runner for iterative development workflows.

## Overview

Ralph Loop (`ralph.sh`) is a bash script that runs Claude Code in headless mode, iterating through development tasks automatically. It's designed for autonomous coding sessions where Claude reads a prompt file and works through tasks, committing and pushing changes after each iteration.

## Features

- **Multiple prompt sources**: Named presets, custom files, or inline prompts
- **Model selection**: Choose between opus, sonnet, or haiku with smart defaults
- **Iteration limits**: Default 10 iterations to prevent runaway sessions (override with `--unlimited`)
- **Push control**: Enable or disable automatic git push after iterations
- **Clean logging**: Parses Claude's JSON output to show only relevant tool calls
- **Session management**: Tracks iterations, duration, and saves logs to `~/.ralph/logs/`
- **Session resume**: Resume interrupted sessions with `--resume`
- **Retry logic**: Automatic retry with exponential backoff for transient failures
- **Environment variables**: Configure via `RALPH_*` env vars for CI/CD
- **Global config**: User-wide defaults at `~/.ralph/config`
- **Safe config parsing**: Config files are parsed safely (no shell execution)

## Installation

The script is self-contained. Ensure you have:

- `claude` CLI installed and authenticated
- `jq` for JSON parsing
- `git` for version control operations

Ralph automatically runs pre-flight checks to verify these dependencies. Use `--skip-checks` to bypass if needed.

### Shell Completion

Tab completion is available for bash and zsh shells.

**Bash:**

```bash
# Option 1: Source directly in your shell config
echo 'source /path/to/ralph-starter/completions/ralph.bash' >> ~/.bashrc

# Option 2: Copy to system completions directory
sudo cp completions/ralph.bash /etc/bash_completion.d/ralph

# Option 3: Copy to user completions directory
mkdir -p ~/.local/share/bash-completion/completions
cp completions/ralph.bash ~/.local/share/bash-completion/completions/ralph.sh
```

**Zsh:**

```bash
# Option 1: Add completions directory to fpath (BEFORE compinit in ~/.zshrc)
fpath=(/path/to/ralph-starter/completions $fpath)
autoload -Uz compinit && compinit

# Option 2: Copy to a directory already in fpath
cp completions/ralph.zsh ~/.zsh/completions/_ralph
compinit

# Option 3: Copy to system completions (requires sudo)
sudo cp completions/ralph.zsh /usr/local/share/zsh/site-functions/_ralph
```

After installation, restart your shell or run `source ~/.bashrc` (bash) or `source ~/.zshrc` (zsh).

**What's Completed:**

- Presets: `plan`, `build`, `product`
- All flags: `--model`, `--file`, `--spec`, `--log-format`, etc.
- Model names: `opus`, `sonnet`, `haiku`
- Log formats: `text`, `json`
- File paths for flags that accept them (`-f`, `-s`, `-l`, `--log-file`, etc.)
- Directory paths for flags that accept them (`--log-dir`, `--source`, `--context`, `--output`)

## Usage

### Basic Commands

```bash
# Default: build mode, opus, 10 iterations
./ralph.sh

# Plan mode (10 iterations default)
./ralph.sh plan

# Specify iterations
./ralph.sh build 5
./ralph.sh plan 3
./ralph.sh -n 20                    # Explicit max flag

# Unlimited iterations (use with caution!)
./ralph.sh --unlimited
./ralph.sh build --unlimited
```

### Custom Prompts

```bash
# Use a custom prompt file
./ralph.sh -f ./prompts/review.md
./ralph.sh --file ~/my-prompts/refactor.md

# Inline prompt (creates temp file)
./ralph.sh -p "Fix all TypeScript errors and run tests"
./ralph.sh --prompt "Add dark mode support to the settings page"
```

### Spec and Plan Files

```bash
# Use custom spec file (plan automatically derived)
./ralph.sh -s ./specs/my-feature.json
# → Plan: ./plans/my-feature_PLAN.md (auto-derived from spec name)

# Also works with markdown specs
./ralph.sh -s ./specs/my-feature.md
# → Plan: ./plans/my-feature_PLAN.md

# Override the derived plan if needed
./ralph.sh -s ./specs/my-feature.json -l ./plans/custom_PLAN.md build 5
```

### Pre-flight Checks

```bash
# Skip dependency checks (advanced users)
./ralph.sh --skip-checks build
```

### Session Resume

```bash
# Resume an interrupted session
./ralph.sh --resume

# List all resumable sessions
./ralph.sh --list-sessions
```

Session state is saved to `.ralph-session.json` during execution. On successful completion, it's archived to `~/.ralph/logs/`. On interrupt or failure, it's preserved for resume.

### Retry Logic

```bash
# Disable automatic retry (fail immediately on errors)
./ralph.sh --no-retry build

# Set custom max retries (default: 3)
./ralph.sh --max-retries 5 build
```

Retry uses exponential backoff (5s → 15s → 45s) for transient errors like rate limits (429), server errors (500, 502, 503, 504), and network issues. Fatal errors (auth failures, 401, 403) are not retried.

### Log Directory

```bash
# Use custom log directory
./ralph.sh --log-dir /path/to/logs build

# Use explicit log file path
./ralph.sh --log-file /path/to/session.log build
```

Default log location: `~/.ralph/logs/{mode}_{branch}_{timestamp}.log`

A symlink `~/.ralph/logs/latest.log` always points to the current session log.

### Global Config

```bash
# Use custom global config file
./ralph.sh --global-config ~/.config/ralph.conf build
```

Default global config: `~/.ralph/config` (loaded before project `ralph.conf`)

### Dry Run

```bash
# Preview config without running Claude
./ralph.sh -s ./specs/my-feature.md --dry-run
```

### Test Mode

```bash
# Single iteration, no push, ignore completion marker
./ralph.sh --test
./ralph.sh -1                    # Short flag

# Combine with other options
./ralph.sh --test --model haiku  # Test with haiku
./ralph.sh --test --dry-run      # Preview test config
```

Test mode is ideal for:
- Validating prompts before committing to full loops
- Debugging configuration issues
- Quick one-off tasks without affecting remote branches

### Interactive Mode

```bash
# Prompt for confirmation between iterations
./ralph.sh --interactive
./ralph.sh -i                    # Short flag

# Set custom timeout (default: 300 seconds / 5 minutes)
./ralph.sh -i --interactive-timeout 60

# Combine with other options
./ralph.sh -i --model sonnet     # Interactive with sonnet
./ralph.sh -i --test             # Effectively same as --test (1 iteration)
```

When interactive mode is enabled, after each iteration Ralph will:
1. Display an iteration summary (duration, status, files changed)
2. Prompt: `Continue to next iteration? [Y/n/s]`
   - **Y** (or Enter): Continue to next iteration
   - **n**: Stop the session gracefully
   - **s**: Show git diff, then prompt again
3. Auto-continue after timeout (default 5 minutes)

Interactive mode is ideal for:
- Learning how Ralph works by watching each iteration
- Reviewing changes before continuing
- Cautious sessions where you want control between iterations
- Long-running sessions where you want periodic check-ins

**Non-TTY environments**: If Ralph detects it's not running in an interactive terminal (e.g., CI/CD, cron, piped input), the interactive prompt is skipped with a warning and iterations continue automatically.

### Verbose Mode

```bash
# Enable verbose output for debugging
./ralph.sh --verbose
./ralph.sh -v                    # Short flag

# Combine with other options
./ralph.sh -v --dry-run          # Preview config with precedence details
./ralph.sh -v --test             # Verbose test mode
```

When verbose mode is enabled, Ralph provides detailed debugging information:

1. **Configuration Precedence**: Shows where each config value came from
   - `(cli)` - Set via command line flag
   - `(env)` - Set via environment variable
   - `(config)` - Set via config file
   - `(default)` - Using built-in default
   - `(derived from spec)` - Computed from another value

2. **Prompt Preview**: Shows the resolved prompt content (first 20 lines) before sending to Claude, including all template variable substitutions

3. **Session State Updates**: Logs session initialization, iteration updates, and finalization

4. **Retry Logic Decisions**: Shows when retries are attempted, skipped, or exhausted

**Example verbose output:**

```
  [verbose] ┌─────────────────────────────────────────┐
  [verbose] │ Configuration Precedence                │
  [verbose] │ (cli > env > config > default)          │
  [verbose] └─────────────────────────────────────────┘
  [verbose] MODEL = sonnet (env)
  [verbose] MAX_ITERATIONS = 10 (default)
  [verbose] PUSH_ENABLED = false (cli)
  [verbose] SPEC_FILE = ./specs/feature.json (cli)
  [verbose] PLAN_FILE = ./plans/feature_PLAN.md (derived from spec)
  [verbose] Config files loaded:
  [verbose]   • ~/.ralph/config
  [verbose]   • ./ralph.conf
```

Verbose mode is ideal for:
- Debugging configuration issues
- Understanding where settings come from
- Verifying prompt content before execution
- Troubleshooting retry behavior

### Product Mode

```bash
# Generate product artifacts (default paths)
./ralph.sh product

# Custom product paths
./ralph.sh product --context ./my-context/ --output ./my-output/

# Custom artifact spec
./ralph.sh product --artifact-spec ./docs/MY_SPEC.md

# Combined options
./ralph.sh product --context ./input/ --output ./output/ --model sonnet 5
```

### Model Selection

```bash
# Override default model
./ralph.sh build --model sonnet
./ralph.sh -p "Quick fix" --model haiku
./ralph.sh -f complex-task.md --model opus
```

### Push Control

```bash
# Disable automatic push (useful for local experimentation)
./ralph.sh build --no-push

# Explicitly enable push (default behavior)
./ralph.sh plan --push
```

### Combined Options

```bash
# Custom file, sonnet model, 5 iterations, no push
./ralph.sh -f ./prompts/refactor.md --model sonnet --no-push 5

# Inline prompt with haiku, 3 iterations
./ralph.sh -p "Add unit tests for the auth module" --model haiku 3
```

## Model Defaults

| Mode          | Default Model | Rationale                                    |
| ------------- | ------------- | -------------------------------------------- |
| `plan`        | opus          | Complex reasoning for architecture decisions |
| `build`       | opus          | Quality implementation with full context     |
| `product`     | opus          | Comprehensive product artifact generation    |
| `inline` (-p) | sonnet        | Faster for quick, focused tasks              |
| `custom` (-f) | opus          | Assumes complex task unless specified        |

## Prompt Files

### Preset Prompts

The script looks for these files in the `prompts/` directory:

- `prompts/PROMPT_plan.md` - Planning and architecture tasks
- `prompts/PROMPT_build.md` - Implementation and coding tasks
- `prompts/PROMPT_product.md` - Product artifact generation

### Creating Custom Prompts

Create a markdown file with instructions for Claude:

```markdown
# Task: Review and Refactor

Review the authentication module for:

1. Security vulnerabilities
2. Code duplication
3. Missing error handling

For each issue found:

- Explain the problem
- Implement the fix
- Add tests if applicable

Run `pnpm test` and `pnpm typecheck` after changes.
```

## Output

### Terminal Output

The script displays:

- Session header with configuration
- Iteration markers with timestamps
- Tool calls (Read, Write, Edit, Bash, Task, etc.)
- Git status after each iteration
- Push status
- Session summary

Example:

```
╔════════════════════════════════════════════════════════════════╗
║                      RALPH LOOP                              ║
╚════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────┐
│ Mode     → build
│ Model    → opus
│ Prompt   → PROMPT_build.md
│ Branch   → feature/auth
│ Push     → enabled
│ Log      → /tmp/ralph_build_20260118_143632.log
└─────────────────────────────────────────┘

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚙ ITERATION 1  14:36:32
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  🔍 Read src/lib/auth.ts
  🔍 Glob src/**/*.test.ts
  ✎ Edit src/lib/auth.ts
  ⚙ 🧪 Running tests
  ⚙ ⎇ Committing

  ─────────────────────────────────────────
  Summary
     Tool calls: 5
     Files modified: 1
     🧪 Tests: ran
     ⎇ Commits made

  ⎇ Git Status
     1 staged
     Last commit: Fix auth token validation

  ✓ Pushed to feature/auth
  ✓ Iteration 1 complete (45s)
```

### Log Files

Full session logs are saved to `~/.ralph/logs/{mode}_{branch}_{timestamp}.log` by default. These contain the raw JSON stream from Claude for debugging.

A `latest.log` symlink in the log directory always points to the current/most recent session log for quick access.

### Structured JSON Logging

For log aggregation systems (ELK, Datadog, Splunk, etc.), enable JSON logging:

```bash
# Enable JSON logging
./ralph.sh --log-format json build

# Or via environment variable
RALPH_LOG_FORMAT=json ./ralph.sh build
```

JSON log entries include:

- `timestamp` - ISO 8601 timestamp (UTC)
- `session_id` - Unique session identifier for correlation
- `event` - Event type (see below)
- `data` - Event-specific details

**Event Types:**

| Event             | Description                   | Data Fields                                                       |
| ----------------- | ----------------------------- | ----------------------------------------------------------------- |
| `session_start`   | Session begins                | mode, model, branch, max_iterations, prompt_file, push_enabled    |
| `iteration_start` | Iteration begins              | iteration, max                                                    |
| `tool_call`       | Claude uses a tool            | tool, detail                                                      |
| `error`           | Error occurred                | message, code                                                     |
| `iteration_end`   | Iteration completes           | iteration, duration, exit_code, status                            |
| `session_end`     | Session ends                  | status, total_duration, iterations_completed, failed_iterations   |

**Example JSON log entries:**

```json
{"timestamp":"2026-02-03T22:30:00Z","session_id":"20260203_223000_12345","event":"session_start","data":{"mode":"build","model":"opus","branch":"feature/auth"}}
{"timestamp":"2026-02-03T22:30:01Z","session_id":"20260203_223000_12345","event":"iteration_start","data":{"iteration":"1","max":"10"}}
{"timestamp":"2026-02-03T22:30:15Z","session_id":"20260203_223000_12345","event":"tool_call","data":{"tool":"Read","detail":"src/lib/auth.ts"}}
{"timestamp":"2026-02-03T22:31:00Z","session_id":"20260203_223000_12345","event":"iteration_end","data":{"iteration":"1","duration":"59","exit_code":"0","status":"success"}}
```

Terminal output remains human-readable regardless of log format.

### Webhook Notifications

Ralph can send webhook notifications on session completion, failure, or interrupt. This enables integration with Slack, Discord, Teams, or custom monitoring systems.

```bash
# Send notifications to a webhook endpoint
./ralph.sh --notify-webhook "https://hooks.slack.com/services/xxx/yyy/zzz" build

# Or via environment variable
RALPH_NOTIFY_WEBHOOK="https://example.com/webhook" ./ralph.sh build

# Basic auth is supported via URL (credentials redacted in display)
./ralph.sh --notify-webhook "https://user:pass@example.com/webhook" build
```

**Events:**

| Event                      | Description                                      |
| -------------------------- | ------------------------------------------------ |
| `session_complete`         | Session finished with completion marker detected |
| `session_max_iterations`   | Session ended due to iteration limit             |
| `session_interrupted`      | Session interrupted by Ctrl+C or signal          |

**Payload:**

Webhooks send a JSON POST request with:

```json
{
  "event": "session_complete",
  "session_id": "20260203_143000_12345",
  "status": "session_complete",
  "iterations": 5,
  "failed_iterations": 0,
  "duration_seconds": 300,
  "duration_human": "5m 0s",
  "branch": "feature/auth",
  "mode": "build",
  "model": "opus",
  "summary": "All tasks complete after 5 iteration(s)",
  "last_commit": "feat: add user authentication",
  "timestamp": "2026-02-03T14:35:00Z"
}
```

**Behavior:**

- 10-second timeout per request
- Non-blocking: failures don't stop session cleanup
- Basic auth supported via URL (`https://user:pass@host/path`)
- Response status logged to session log file

**Integration Examples:**

```bash
# Slack Incoming Webhook
./ralph.sh --notify-webhook "https://hooks.slack.com/services/T00/B00/xxx" build

# Discord Webhook
./ralph.sh --notify-webhook "https://discord.com/api/webhooks/xxx/yyy" build

# Custom endpoint with auth
./ralph.sh --notify-webhook "https://api:secret@monitoring.example.com/ralph" build
```

### Session Summary Reports

After each session, Ralph generates a markdown summary report with detailed information about what was accomplished.

```bash
# Summary reports are generated by default
./ralph.sh build

# Disable summary generation
./ralph.sh --no-summary build
```

**Location:** `~/.ralph/logs/{session_id}_summary.md`

**Contents:**

The summary report includes:

| Section | Description |
|---------|-------------|
| **Session Overview** | Status, session ID, mode, model, branch, duration, iterations |
| **Configuration** | Spec, plan, progress, and log file paths |
| **Iteration Details** | Per-iteration table with duration, exit code, files modified, commit message |
| **Timing Breakdown** | Total time, average per iteration, overhead |
| **Files Modified** | List of all files changed during the session |
| **Commits Made** | Git log of commits made during the session |
| **Troubleshooting** | For failed/interrupted sessions: error details and suggested actions |
| **Related Files** | Links to log file, session state, progress, and plan |

**Example output:**

```markdown
# Ralph Session Summary

## Session Overview

| Property | Value |
|----------|-------|
| **Status** | ✅ Complete |
| **Session ID** | `20260204_143000_12345` |
| **Mode** | build |
| **Model** | opus |
| **Branch** | `feature/auth` |
| **Started** | 2026-02-04T14:30:00Z |
| **Duration** | 5m 30s |
| **Iterations** | 3/10 |

## Iteration Details

| # | Duration | Exit | Files | Commit |
|---|----------|------|-------|--------|
| 1 | 95s | 0 | 2 | Add user authentication module |
| 2 | 110s | 0 | 3 | Implement login flow |
| 3 | 125s | 0 | 1 | Add unit tests for auth |

### Timing Breakdown

- **Total iteration time:** 330s
- **Average per iteration:** 110s
- **Overhead:** 0s
```

**Use cases:**

- Post-session review of what was accomplished
- Debugging failed sessions (troubleshooting section)
- Documentation of autonomous work for team visibility
- Comparing session efficiency across runs

## Architecture

```
ralph.sh
├── Argument parsing (presets, flags, positional args)
├── Prompt resolution (preset → file → inline)
├── Validation (file exists, valid model)
├── Main loop
│   ├── Run Claude with stream-json output
│   ├── Parse JSON → display tool calls
│   ├── Show git status
│   ├── Push changes (if enabled)
│   └── Increment iteration
└── Cleanup (temp files, summary)
```

### Key Components

1. **Argument Parser**: Handles short/long flags, presets, and positional arguments
2. **JSON Stream Parser**: Filters verbose Claude output to show only tool invocations
3. **Git Integration**: Automatic status checks, push with branch creation fallback
4. **Signal Handling**: Clean shutdown on Ctrl+C with session summary

## Future Improvements

### Near-term

1. **Parallel Execution**: Run multiple independent tasks in parallel

```bash
./ralph.sh -f task1.md -f task2.md --parallel
```

### Medium-term

4. **Web Dashboard**: Real-time monitoring UI for long-running sessions

5. **Template System**: Parameterized prompts with variable substitution

```bash
./ralph.sh -f templates/fix-issue.md --var issue=123
```

### Long-term

6. **Multi-Agent Orchestration**: Coordinate multiple Claude instances

7. **Learning Mode**: Capture successful patterns for future reference

## Troubleshooting

### "Error: Prompt file not found"

Ensure the prompt file exists at the specified path. For presets, check that `PROMPT_plan.md` or `PROMPT_build.md` exists in the project root.

### No tool calls showing

Check that `jq` is installed. The parser requires it for JSON processing:

```bash
brew install jq  # macOS
apt install jq   # Ubuntu/Debian
```

### Claude not running / 0 tool calls

The script requires `--verbose` with `--output-format=stream-json`. If you've modified the script, ensure both flags are present.

### Push failing

Check that:

- You have push access to the remote repository
- The branch exists or can be created
- Git is properly configured with credentials

### Viewing full logs

Full session output is saved to `~/.ralph/logs/`:

```bash
# View recent logs
ls -la ~/.ralph/logs/

# View the latest session log
tail -f ~/.ralph/logs/latest.log

# Search for errors in recent logs
grep -i error ~/.ralph/logs/*.log
```

### Session was interrupted

If your session was interrupted (Ctrl+C, network drop, laptop sleep), you can resume:

```bash
# Check if a session can be resumed
./ralph.sh --list-sessions

# Resume the interrupted session
./ralph.sh --resume
```

Note: The session file `.ralph-session.json` is preserved on interrupt. It's only archived after successful completion.

## Command Line Examples

### Quick Reference

```bash
# Show help
./ralph.sh --help
./ralph.sh -h

# Presets (default: 10 iterations)
./ralph.sh                    # Build mode, opus, 10 iterations
./ralph.sh plan               # Plan mode, opus, 10 iterations
./ralph.sh build 5            # Build mode, 5 iterations
./ralph.sh plan 3             # Plan mode, 3 iterations
./ralph.sh -n 20              # Explicit max iterations
./ralph.sh --unlimited        # Remove limit (careful!)

# Custom files
./ralph.sh -f prompts/review.md
./ralph.sh --file ./tasks/refactor-auth.md
./ralph.sh -f ~/global-prompts/security-audit.md 3

# Inline prompts
./ralph.sh -p "Fix the failing tests"
./ralph.sh --prompt "Add error handling to all API routes"
./ralph.sh -p "Refactor duplicate code in src/lib" 2

# Model selection
./ralph.sh --model sonnet                    # Faster, cheaper
./ralph.sh --model haiku                     # Fastest, cheapest
./ralph.sh --model opus                      # Most capable (default)
./ralph.sh -m sonnet                         # Short flag

# Push control
./ralph.sh --no-push                         # Don't push changes
./ralph.sh build --no-push 5                 # Local only, 5 iterations
./ralph.sh --push                            # Explicit push (default)

# Session management
./ralph.sh --resume                          # Resume interrupted session
./ralph.sh --list-sessions                   # List resumable sessions

# Retry control
./ralph.sh --no-retry                        # Disable automatic retry
./ralph.sh --max-retries 5                   # Custom retry limit (default: 3)

# Logging
./ralph.sh --log-dir /custom/logs            # Custom log directory
./ralph.sh --log-file /path/to/session.log   # Explicit log file
./ralph.sh --log-format json                 # Structured JSON logging

# Test mode (single iteration, no push, ignore completion marker)
./ralph.sh --test                            # Test mode
./ralph.sh -1                                # Short flag for test mode
./ralph.sh --test --dry-run                  # Preview test mode config

# Interactive mode (prompt between iterations)
./ralph.sh --interactive                     # Enable interactive mode
./ralph.sh -i                                # Short flag
./ralph.sh -i --interactive-timeout 60       # Custom timeout (default: 300s)

# Verbose mode (debugging output)
./ralph.sh --verbose                         # Enable verbose mode
./ralph.sh -v                                # Short flag
./ralph.sh -v --dry-run                      # Verbose dry run (config sources)

# Configuration
./ralph.sh --global-config ~/.config/ralph   # Custom global config
./ralph.sh --skip-checks                     # Skip pre-flight checks
./ralph.sh --dry-run                         # Preview config, don't run
./ralph.sh --no-summary                      # Disable summary report generation

# Shell completion (see Installation section for setup)
ralph<TAB>                                   # Complete presets and options
./ralph.sh --m<TAB>                          # Complete to --model, --max, etc.
./ralph.sh --model <TAB>                     # Complete opus, sonnet, haiku
./ralph.sh --log-format <TAB>                # Complete text, json
./ralph.sh -s <TAB>                          # Complete file paths

# Combined examples
./ralph.sh build --model sonnet --no-push 3
./ralph.sh -f review.md -m haiku 10
./ralph.sh -p "Add tests" --model sonnet --no-push 1
./ralph.sh plan --model opus 5
```

### Common Workflows

```bash
# Quick bug fix (fast model, single iteration, no push)
./ralph.sh -p "Fix the null pointer in UserCard component" --model haiku --no-push 1

# Code review (custom prompt, multiple passes)
./ralph.sh -f prompts/code-review.md --model sonnet 3

# Architecture planning (opus for complex reasoning)
./ralph.sh plan --model opus 2

# Continuous development (build mode, auto-push)
./ralph.sh build 20

# Local experimentation (no push, unlimited)
./ralph.sh build --no-push

# Security audit (thorough, no auto-push for review)
./ralph.sh -f prompts/security-audit.md --model opus --no-push

# Quick refactor (inline, fast)
./ralph.sh -p "Extract the validation logic into a separate utility" --model sonnet 1

# Test writing session
./ralph.sh -p "Add comprehensive tests for src/lib/storage.ts" --model sonnet 5

# Documentation pass
./ralph.sh -p "Add JSDoc comments to all exported functions in src/lib" --model haiku 3
```

### Running in Background

```bash
# Run with nohup for long sessions
nohup ./ralph.sh build 50 > ralph_output.log 2>&1 &

# Check progress
tail -f ralph_output.log

# Or use screen/tmux
screen -S ralph
./ralph.sh build 100
# Ctrl+A, D to detach
# screen -r ralph to reattach
```

## Environment Variables

Ralph supports environment variables for CI/CD integration and user defaults. Precedence: CLI > env var > config file > defaults.

| Variable               | Description                             | Example                       |
| ---------------------- | --------------------------------------- | ----------------------------- |
| `RALPH_MODEL`          | Default model (opus, sonnet, haiku)     | `RALPH_MODEL=sonnet`          |
| `RALPH_MAX_ITERATIONS` | Maximum iterations limit                | `RALPH_MAX_ITERATIONS=20`     |
| `RALPH_PUSH_ENABLED`   | Git push toggle (true/false/yes/no/1/0) | `RALPH_PUSH_ENABLED=false`    |
| `RALPH_SPEC_FILE`      | Path to spec file                       | `RALPH_SPEC_FILE=./spec.json` |
| `RALPH_PLAN_FILE`      | Path to plan file                       | `RALPH_PLAN_FILE=./plan.md`   |
| `RALPH_PROGRESS_FILE`  | Path to progress file                   | `RALPH_PROGRESS_FILE=log.txt` |
| `RALPH_LOG_DIR`        | Log directory path                      | `RALPH_LOG_DIR=/tmp/logs`     |
| `RALPH_LOG_FORMAT`     | Log format (text/json)                  | `RALPH_LOG_FORMAT=json`       |
| `RALPH_NOTIFY_WEBHOOK` | Webhook URL for session notifications   | `RALPH_NOTIFY_WEBHOOK=...`    |

### Example: CI/CD Usage

```bash
# GitHub Actions example
RALPH_MODEL=sonnet \
RALPH_MAX_ITERATIONS=5 \
RALPH_PUSH_ENABLED=false \
./ralph.sh build
```

## Exit Codes

| Code | Meaning                                                        |
| ---- | -------------------------------------------------------------- |
| 0    | Task complete (`<ralph>COMPLETE</ralph>` marker detected)      |
| 1    | Max iterations reached (check progress.txt for remaining work) |
| 130  | Interrupted (Ctrl+C)                                           |

## Template Variables

Prompts support these placeholders (automatically substituted):

### Build/Plan Mode

| Variable            | Default                          | Description                              |
| ------------------- | -------------------------------- | ---------------------------------------- |
| `{{SPEC_FILE}}`     | `./specs/IMPLEMENTATION_PLAN.md` | Feature specification (the "what & why") |
| `{{PLAN_FILE}}`     | `./plans/IMPLEMENTATION_PLAN.md` | Implementation checklist (the "how")     |
| `{{PROGRESS_FILE}}` | `progress.txt`                   | Iteration history log                    |
| `{{SOURCE_DIR}}`    | `src/*`                          | Source code location                     |

### Product Mode

| Variable                  | Default                           | Description                       |
| ------------------------- | --------------------------------- | --------------------------------- |
| `{{PRODUCT_CONTEXT_DIR}}` | `./product-input/`                | Product context/input directory   |
| `{{PRODUCT_OUTPUT_DIR}}`  | `./product-output/`               | Product artifact output directory |
| `{{ARTIFACT_SPEC_FILE}}`  | `./docs/PRODUCT_ARTIFACT_SPEC.md` | Artifact specification file       |
| `{{PROGRESS_FILE}}`       | `progress.txt`                    | Iteration history log             |

## Configuration File

Ralph supports configuration files for default settings. Configuration precedence: CLI > environment variables > project config > global config > defaults.

### Config File Locations

1. **Global config**: `~/.ralph/config` (user-wide defaults)
2. **Project config**: `./ralph.conf` (project-specific overrides)

Use `--global-config PATH` to specify an alternate global config location.

### Example `ralph.conf`

```bash
# Ralph Loop Configuration
# Use standard KEY=VALUE syntax (no shell execution for security)

# Path Configuration
SPEC_FILE=./specs/IMPLEMENTATION_PLAN.md
PLAN_FILE=./plans/IMPLEMENTATION_PLAN.md
ARTIFACT_SPEC_FILE=./docs/PRODUCT_ARTIFACT_SPEC.md
PROGRESS_FILE=progress.txt
SOURCE_DIR=src/*

# Execution Settings
MODEL=opus
MAX_ITERATIONS=10
PUSH_ENABLED=true

# Logging
LOG_DIR=~/.ralph/logs
```

### Supported Settings

| Setting              | Description                                  | Default                           |
| -------------------- | -------------------------------------------- | --------------------------------- |
| `SPEC_FILE`          | Path to feature specification                | `./specs/IMPLEMENTATION_PLAN.md`  |
| `PLAN_FILE`          | Path to implementation checklist             | `./plans/IMPLEMENTATION_PLAN.md`  |
| `ARTIFACT_SPEC_FILE` | Path to product artifact spec (product mode) | `./docs/PRODUCT_ARTIFACT_SPEC.md` |
| `PROGRESS_FILE`      | Path to iteration history log                | `progress.txt`                    |
| `SOURCE_DIR`         | Source code directory                        | `src/*`                           |
| `MODEL`              | Default model (opus, sonnet, haiku)          | varies by mode                    |
| `MAX_ITERATIONS`     | Maximum iterations limit                     | `10`                              |
| `PUSH_ENABLED`       | Auto-push after iterations                   | `true`                            |
| `LOG_DIR`            | Log file directory                           | `~/.ralph/logs`                   |
| `LOG_FORMAT`         | Log format (text/json)                       | `text`                            |
| `NOTIFY_WEBHOOK`     | Notification webhook URL                     | (none)                            |

### Security

Config files are parsed safely using a whitelist approach:

- Only allowed keys are accepted (unknown keys trigger warnings)
- Values are type-validated (e.g., MODEL must be opus/sonnet/haiku)
- Shell command patterns (`$()`, backticks, `&&`, `||`, `;`) are rejected
- No arbitrary code execution from config files

## Branch-Change Archiving

When you switch git branches, Ralph automatically archives the previous branch's state:

- Copies spec, plan, and progress files to `archive/YYYY-MM-DD-branchname/`
- Resets `progress.txt` for the new branch
- Preserves work context for when you return to the branch

This prevents confusion when working on multiple features and ensures iteration history is branch-specific.

## File Structure

### Project Files

```
project-root/
├── product-input/                  # Product context files (Step 0)
│   ├── vision.md                   # Product vision and goals
│   ├── research.md                 # User research, market data
│   └── requirements.md             # High-level requirements
├── product-output/                 # Generated product artifacts (Step 0)
│   ├── 1_executive_summary.md
│   ├── 7_prd.md                    # Use to inform specs
│   └── ... (12 total)
├── specs/                          # Feature specifications (Step 1)
│   ├── INDEX.md                    # Feature catalog
│   ├── {feature}.json              # JSON specs (recommended)
│   └── {feature}.md                # Markdown specs (alternative)
├── plans/                          # Implementation checklists (Step 2)
│   ├── IMPLEMENTATION_PLAN.md      # Default active plan
│   └── {feature}_PLAN.md           # Feature-specific plans
├── prompts/
│   ├── PROMPT_plan.md              # Planning mode instructions
│   ├── PROMPT_build.md             # Build mode instructions
│   └── PROMPT_product.md           # Product artifact generation
├── docs/
│   └── PRODUCT_ARTIFACT_SPEC.md    # Product artifact specifications
├── .claude/
│   └── skills/
│       └── writing-ralph-specs/    # Skill for creating JSON specs
├── archive/                        # Auto-archived branch state on branch change
├── ralph.sh                        # The loop script
├── ralph.conf                      # Project configuration file
├── .ralph-session.json             # Active session state (gitignored)
└── progress.txt                    # Iteration history
```

### User Files

```
~/.ralph/
├── config                          # Global configuration file
└── logs/
    ├── latest.log                  # Symlink to current session
    ├── {session_id}_session.json   # Archived session states
    ├── {session_id}_summary.md     # Session summary reports
    └── {mode}_{branch}_{ts}.log    # Session logs
```

## Complete Workflow: Product → Spec → Plan → Build

The full workflow for implementing features with Ralph:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│           PRODUCT (optional) → SPEC → PLAN → BUILD                          │
│                                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ Product  │ -> │  Create  │ -> │   Plan   │ -> │  Build   │              │
│  │   Mode   │    │   Spec   │    │   Mode   │    │   Mode   │              │
│  │(discover)│    │  (JSON)  │    │ (analyze)│    │ (execute)│              │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘              │
│       │               │               │               │                     │
│  product-output/  specs/*.json   plans/*_PLAN.md   Code changes            │
│  12 artifacts     "what & why"    "how"           Implementation           │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Step 0: Product Discovery (Optional)

For new projects or major features, start with product mode:

```bash
# 1. Add context files to product-input/
mkdir -p product-input
# Add: vision.md, research.md, requirements.md, competitive-analysis.md, etc.

# 2. Run product mode to generate 12 structured artifacts
./ralph.sh product
#    → product-output/1_executive_summary.md
#    → product-output/2_charter.md
#    → product-output/3_market_analysis.md
#    → product-output/4_personas.md
#    → product-output/5_journey_map.md
#    → product-output/6_positioning.md
#    → product-output/7_prd.md              ← Use this to inform your spec
#    → product-output/8_product_roadmap.md
#    → product-output/9_solution_architecture.md
#    → product-output/10_metrics_framework.md
#    → product-output/11_risk_assessment.md
#    → product-output/12_go_to_market.md

# 3. Review artifacts, especially 7_prd.md, to inform spec creation
```

See `docs/PRODUCT_ARTIFACT_SPEC.md` for full artifact specifications.

### Step 1: Create a Spec

Use insights from product artifacts (or create directly for smaller features):

```bash
# Create a JSON spec with user stories and acceptance criteria
# (use the writing-ralph-specs skill or create manually)
#    → specs/my-feature.json

# Example minimal spec:
cat > specs/my-feature.json << 'EOF'
{
  "project": "My Feature",
  "branchName": "feature/my-feature",
  "description": "Feature description from PRD",
  "userStories": [
    {
      "id": "US-001",
      "title": "First task",
      "acceptanceCriteria": ["Criterion 1", "Criterion 2"],
      "priority": 1,
      "passes": false
    }
  ]
}
EOF
```

### Step 2: Run Plan Mode

Plan mode analyzes the spec and codebase, then creates a task checklist:

```bash
./ralph.sh plan -s ./specs/my-feature.json
#    → plans/my-feature_PLAN.md (auto-derived from spec name)
```

### Step 3: Run Build Mode

Build mode executes the plan one task at a time:

```bash
./ralph.sh build -s ./specs/my-feature.json
#    → Implementation complete
#    → spec.passes updated to true for completed stories
```

### Quick Reference Commands

```bash
# Full workflow from product discovery to implementation
./ralph.sh product                           # Step 0: Generate product artifacts
# (manually create spec from product output)  # Step 1: Create spec
./ralph.sh plan -s ./specs/my-feature.json   # Step 2: Create plan
./ralph.sh build -s ./specs/my-feature.json  # Step 3: Execute plan

# Skip product mode for smaller features
./ralph.sh plan -s ./specs/my-feature.json   # Create plan from existing spec
./ralph.sh build -s ./specs/my-feature.json  # Execute plan
```

JSON specs provide structured user stories with acceptance criteria that plan mode uses to create detailed checklists. Build mode updates the `passes` field in each user story when all acceptance criteria are met, providing story-level completion tracking.

See `specs/ralph-improvements.json` for a comprehensive spec example.

## Related Files

### Prompts

- `prompts/PROMPT_plan.md` - Planning mode prompt
- `prompts/PROMPT_build.md` - Build mode prompt
- `prompts/PROMPT_product.md` - Product artifact generation prompt

### Product Mode

- `product-input/` - Context files for product discovery (vision, research, requirements)
- `product-output/` - Generated product artifacts (12 documents)
- `docs/PRODUCT_ARTIFACT_SPEC.md` - Artifact specifications

### Specs & Plans

- `specs/INDEX.md` - Feature catalog
- `specs/*.json` - JSON specs (recommended)
- `plans/*_PLAN.md` - Implementation checklists
- `.claude/skills/writing-ralph-specs/` - Skill for creating JSON specs

### Configuration

- `ralph.conf` - Project configuration file
- `~/.ralph/config` - Global configuration file

### Session & Logs

- `~/.ralph/logs/` - Session logs directory
- `~/.ralph/logs/latest.log` - Symlink to current session log
- `.ralph-session.json` - Active session state (preserved on interrupt)
