# Ralph Loop Improvements - Implementation Plan

**Spec:** `./specs/ralph-improvements.json`
**Branch:** `ralph/resilience-and-dx`
**Version:** 2.0.0

## Overview

Transform ralph.sh from a functional automation tool into a production-ready system with resilience, observability, and improved developer experience. All changes must pass shellcheck and maintain backward compatibility.

## Dependency Graph

```
US-001 (Pre-flight checks) ──────────────────────────────────────────────────┐
US-002 (Session state) ──────┬─► US-003 (Retry logic)                        │
                             ├─► US-004 (Session resume)                     │
                             └─► US-011 (Summary report)                     │
US-005 (Persistent logs) ────────────────────────────────────────────────────┤
US-006 (Env vars) ───────────────────────────────────────────────────────────┤
US-007 (Safe config) ────────┬─► US-008 (Global config)                      │
                             │                                               │
US-009 (JSON logging) ───────┤                                               │
US-010 (Webhooks) ───────────┤                                               │
US-012 (Test mode) ──────────┤                                               │
US-013 (Interactive) ────────┤                                               │
US-014 (Verbose) ────────────┤                                               │
US-015 (Shell completion) ───┤                                               │
                             ▼                                               │
US-016 (Documentation) ◄─────────────────────────────────────────────────────┘
```

## Implementation Checklist

### Phase 1: Resilience & Recovery

#### Task 1.1: US-001 Pre-flight Dependency Checks
**Priority:** 1 | **Effort:** Small | **Depends on:** None

- [x] 1.1.1 Create `preflight_checks()` function after CONFIGURATION section (~line 75)
- [x] 1.1.2 Add check: `command -v claude >/dev/null` with installation instructions
- [x] 1.1.3 Add check: `claude --version 2>/dev/null` for authentication validation
- [x] 1.1.4 Add check: `command -v jq >/dev/null` with installation instructions
- [x] 1.1.5 Add check: `command -v git >/dev/null` and `git rev-parse --git-dir 2>/dev/null`
- [x] 1.1.6 Add `--skip-checks` flag to argument parsing section
- [x] 1.1.7 Call `preflight_checks` before `print_header` in main flow (unless --skip-checks)
- [x] 1.1.8 Use existing color/symbol conventions for error messages
- [x] 1.1.9 Run `shellcheck ralph.sh` and fix any issues
- [x] 1.1.10 Test: `./ralph.sh --help`, `./ralph.sh --dry-run`

**Acceptance criteria:**
- Clear error message with install instructions if claude/jq/git missing
- Auth check catches unauthenticated claude CLI
- --skip-checks bypasses all validation
- shellcheck passes

---

#### Task 1.2: US-002 Structured Session State File
**Priority:** 2 | **Effort:** Medium | **Depends on:** None

- [x] 1.2.1 Define session state schema (session_id, start_time, mode, model, etc.)
- [x] 1.2.2 Create `init_session_state()` function - creates `.ralph-session.json` with initial state
- [x] 1.2.3 Generate unique session_id: `$(date +%Y%m%d_%H%M%S)_$$`
- [x] 1.2.4 Create `update_session_state()` function - called after each iteration
- [x] 1.2.5 Add iteration_history array with per-iteration metadata (duration, exit_code, files_modified)
- [x] 1.2.6 Create `finalize_session_state()` function - sets final status, archives or cleans up
- [x] 1.2.7 Call `init_session_state` after config loading, before main loop
- [x] 1.2.8 Call `update_session_state` at end of each iteration with metrics
- [x] 1.2.9 Call `finalize_session_state` in cleanup() and at loop end
- [x] 1.2.10 On normal completion: archive session file to log directory
- [x] 1.2.11 On error/interrupt: preserve session file for debugging
- [x] 1.2.12 Run `shellcheck ralph.sh` and fix any issues

**Session state schema:**
```json
{
  "session_id": "20260203_143000_12345",
  "start_time": "2026-02-03T14:30:00Z",
  "mode": "build",
  "model": "opus",
  "prompt_file": "./prompts/PROMPT_build.md",
  "current_iteration": 3,
  "max_iterations": 10,
  "branch": "ralph/resilience-and-dx",
  "status": "in_progress",
  "iteration_history": [
    {"iteration": 1, "duration": 45, "exit_code": 0, "files_modified": 2},
    {"iteration": 2, "duration": 60, "exit_code": 0, "files_modified": 1}
  ]
}
```

**Acceptance criteria:**
- .ralph-session.json created at session start
- Updated after each iteration
- Archived on success, preserved on failure
- shellcheck passes

---

#### Task 1.3: US-003 Retry Logic for Transient Failures
**Priority:** 3 | **Effort:** Medium | **Depends on:** US-002

- [x] 1.3.1 Add `--no-retry` flag to argument parsing
- [x] 1.3.2 Add `--max-retries N` flag (default 3)
- [x] 1.3.3 Define retryable error patterns: rate_limit, timeout, connection_error, 529
- [x] 1.3.4 Define fatal error patterns: auth failure, bad prompt, permission denied
- [x] 1.3.5 Create `is_retryable_error()` function - parses JSON/exit code to classify
- [x] 1.3.6 Create `run_with_retry()` function wrapping claude invocation
- [x] 1.3.7 Implement exponential backoff: 5s, 15s, 45s (configurable)
- [x] 1.3.8 Display retry countdown with reason: "Rate limited. Retrying in 15s..."
- [x] 1.3.9 Log retry attempts to session state (update_session_state)
- [x] 1.3.10 Replace direct claude call in main loop with `run_with_retry`
- [x] 1.3.11 Run `shellcheck ralph.sh` and fix any issues

**Acceptance criteria:**
- Retries on rate limit, timeout, connection errors
- Exponential backoff with countdown display
- Fatal errors fail immediately
- --no-retry disables retry logic
- Retry attempts logged to session state
- shellcheck passes

---

#### Task 1.4: US-004 Session Resume Capability
**Priority:** 4 | **Effort:** Medium | **Depends on:** US-002

- [x] 1.4.1 Add `--resume` flag to argument parsing
- [x] 1.4.2 Add `--list-sessions` flag to show resumable sessions
- [x] 1.4.3 Create `list_sessions()` function - finds .ralph-session.json files
- [x] 1.4.4 Create `validate_session()` function - checks file exists, branch matches, not completed
- [x] 1.4.5 Create `restore_session()` function - loads state, sets variables
- [x] 1.4.6 Add session age check - warn if >24h old
- [x] 1.4.7 Display resume summary before continuing
- [x] 1.4.8 If session was already completed, error with helpful message
- [x] 1.4.9 Restore: mode, model, prompt_file, iteration count, branch
- [x] 1.4.10 Run `shellcheck ralph.sh` and fix any issues

**Acceptance criteria:**
- --resume reads .ralph-session.json and continues
- --list-sessions shows available sessions
- Branch mismatch errors clearly
- Old sessions (>24h) show warning
- Completed sessions can't be resumed
- shellcheck passes

---

#### Task 1.5: US-005 Persistent Log Directory
**Priority:** 5 | **Effort:** Small | **Depends on:** None

- [x] 1.5.1 Define default log directory: `~/.ralph/logs/`
- [x] 1.5.2 Create directory if not exists: `mkdir -p ~/.ralph/logs`
- [x] 1.5.3 Add `--log-dir PATH` flag to argument parsing
- [x] 1.5.4 Add `RALPH_LOG_DIR` environment variable support
- [x] 1.5.5 Add `--log-file PATH` flag for explicit file path
- [x] 1.5.6 Update LOG_FILE assignment with precedence: --log-file > --log-dir > RALPH_LOG_DIR > config > default
- [x] 1.5.7 Log filename format: `{mode}_{branch}_{timestamp}.log`
- [x] 1.5.8 Create symlink: `~/.ralph/logs/latest.log` pointing to current log
- [x] 1.5.9 Display log path in print_config()
- [x] 1.5.10 Run `shellcheck ralph.sh` and fix any issues

**Acceptance criteria:**
- Logs saved to ~/.ralph/logs/ by default
- --log-dir and --log-file override
- RALPH_LOG_DIR environment variable works
- latest.log symlink updated
- Log path shown in session summary
- shellcheck passes

---

### Phase 2: Configuration & Environment

#### Task 2.1: US-006 Environment Variable Support
**Priority:** 6 | **Effort:** Small | **Depends on:** None

- [x] 2.1.1 Add env var reading after defaults, before config file loading
- [x] 2.1.2 Support `RALPH_MODEL` (opus|sonnet|haiku)
- [x] 2.1.3 Support `RALPH_MAX_ITERATIONS` (number)
- [x] 2.1.4 Support `RALPH_PUSH_ENABLED` (true|false)
- [x] 2.1.5 Support `RALPH_SPEC_FILE`, `RALPH_PLAN_FILE`, `RALPH_PROGRESS_FILE`
- [x] 2.1.6 Support `RALPH_LOG_DIR`, `RALPH_LOG_FORMAT`
- [x] 2.1.7 Support `RALPH_NOTIFY_WEBHOOK`
- [x] 2.1.8 Ensure precedence: CLI > env var > config file > defaults
- [x] 2.1.9 Document all env vars in show_help() output
- [x] 2.1.10 Run `shellcheck ralph.sh` and fix any issues

**Pattern:** `VARIABLE=${RALPH_X:-$VARIABLE}`

**Acceptance criteria:**
- All RALPH_* environment variables respected
- Correct precedence order
- --help shows env var documentation
- shellcheck passes

---

#### Task 2.2: US-007 Safe Config File Parsing
**Priority:** 7 | **Effort:** Medium | **Depends on:** None

- [x] 2.2.1 Create whitelist of allowed config keys
- [x] 2.2.2 Create `safe_load_config()` function replacing `source ralph.conf`
- [x] 2.2.3 Read config file line by line
- [x] 2.2.4 Regex match `KEY=VALUE` pattern (no shell expansion)
- [x] 2.2.5 Validate key against whitelist
- [x] 2.2.6 Validate value types (model must be opus|sonnet|haiku, etc.)
- [x] 2.2.7 Reject lines with shell commands or variable expansion
- [x] 2.2.8 Display warning if config has unexpected keys
- [x] 2.2.9 Log parsed config values in verbose mode (deferred to US-014)
- [x] 2.2.10 Replace `load_ralph_config()` with safe version
- [x] 2.2.11 Run `shellcheck ralph.sh` and fix any issues

**Whitelist:**
```
SPEC_FILE, PLAN_FILE, PROGRESS_FILE, SOURCE_DIR, MODEL,
MAX_ITERATIONS, PUSH_ENABLED, PRODUCT_CONTEXT_DIR,
PRODUCT_OUTPUT_DIR, ARTIFACT_SPEC_FILE, LOG_DIR, LOG_FORMAT,
NOTIFY_WEBHOOK
```

**Acceptance criteria:**
- Config file parsed safely without `source`
- Unknown keys generate warnings
- Shell commands rejected
- Value types validated
- shellcheck passes

---

#### Task 2.3: US-008 Global Config File Support
**Priority:** 8 | **Effort:** Small | **Depends on:** US-007

- [x] 2.3.1 Check `~/.ralph/config` if it exists
- [x] 2.3.2 Update config loading order: global first, then project
- [x] 2.3.3 Project ralph.conf overrides global config
- [x] 2.3.4 CLI args override both
- [x] 2.3.5 Create `~/.ralph/` directory on first run if doesn't exist
- [x] 2.3.6 Add `--global-config PATH` flag to specify alternate global config
- [x] 2.3.7 Display which config files were loaded in --dry-run output
- [x] 2.3.8 Run `shellcheck ralph.sh` and fix any issues

**Precedence:** CLI > project ralph.conf > ~/.ralph/config > defaults

**Acceptance criteria:**
- Global config at ~/.ralph/config respected
- Project config overrides global
- --dry-run shows loaded config files
- shellcheck passes

---

### Phase 3: Observability

#### Task 3.1: US-009 Structured JSON Logging Option
**Priority:** 9 | **Effort:** Medium | **Depends on:** None

- [x] 3.1.1 Add `--log-format` flag: text (default) | json
- [x] 3.1.2 Add `RALPH_LOG_FORMAT` environment variable support
- [x] 3.1.3 Create `log_event()` function for structured logging
- [x] 3.1.4 Define events: session_start, iteration_start, tool_call, iteration_end, error, session_end
- [x] 3.1.5 JSON format: `{"timestamp":"...","session_id":"...","event":"...","data":{...}}`
- [x] 3.1.6 Include session_id in all entries for correlation
- [x] 3.1.7 Integrate log_event() calls throughout code
- [x] 3.1.8 Maintain human-readable terminal output regardless of log format
- [x] 3.1.9 Run `shellcheck ralph.sh` and fix any issues

**Acceptance criteria:**
- --log-format json produces valid JSON logs
- Each line is a complete JSON object
- session_id correlates all events
- Terminal output unchanged
- shellcheck passes

---

#### Task 3.2: US-010 Webhook Notifications
**Priority:** 10 | **Effort:** Small | **Depends on:** None

- [x] 3.2.1 Add `--notify-webhook URL` flag
- [x] 3.2.2 Add `RALPH_NOTIFY_WEBHOOK` environment variable support
- [x] 3.2.3 Create `send_webhook()` function using curl
- [x] 3.2.4 Support events: session_complete, session_failed, session_interrupted
- [x] 3.2.5 Payload: session_id, status, iterations, duration, branch, summary
- [x] 3.2.6 Support basic auth via URL (https://user:pass@host/path)
- [x] 3.2.7 Set timeout to 10s, don't block session on failure
- [x] 3.2.8 Log webhook response status
- [x] 3.2.9 Call send_webhook in cleanup() and at session end
- [x] 3.2.10 Run `shellcheck ralph.sh` and fix any issues

**Acceptance criteria:**
- Webhook POSTs on complete/fail/interrupt
- 10s timeout, non-blocking on failure
- Basic auth supported
- Response logged
- shellcheck passes

---

#### Task 3.3: US-011 Session Summary Report
**Priority:** 11 | **Effort:** Medium | **Depends on:** US-002

- [ ] 3.3.1 Create `generate_summary()` function
- [ ] 3.3.2 Generate `{session_id}_summary.md` in log directory
- [ ] 3.3.3 Include session metadata (mode, model, branch, duration)
- [ ] 3.3.4 Include iteration summaries from session state
- [ ] 3.3.5 Include files modified list
- [ ] 3.3.6 Include commits made list
- [ ] 3.3.7 Include errors encountered
- [ ] 3.3.8 Include timing breakdown per iteration
- [ ] 3.3.9 Link to full log file
- [ ] 3.3.10 Add `--no-summary` flag to disable
- [ ] 3.3.11 For failed sessions: include last error and suggested fixes
- [ ] 3.3.12 Call generate_summary in finalize_session_state()
- [ ] 3.3.13 Run `shellcheck ralph.sh` and fix any issues

**Acceptance criteria:**
- Markdown summary generated after session
- All iteration data included
- --no-summary disables
- Failed sessions include troubleshooting
- shellcheck passes

---

### Phase 4: Developer Experience

#### Task 4.1: US-012 Single Iteration Test Mode
**Priority:** 12 | **Effort:** Small | **Depends on:** None

- [ ] 4.1.1 Add `--test` or `-1` flag to argument parsing
- [ ] 4.1.2 When set: MAX_ITERATIONS=1, PUSH_ENABLED=false
- [ ] 4.1.3 Add TEST_MODE variable for display
- [ ] 4.1.4 Display 'TEST MODE' banner in print_header()
- [ ] 4.1.5 Skip completion marker detection (always exit after 1 iteration)
- [ ] 4.1.6 Can combine with --dry-run for config-only preview
- [ ] 4.1.7 Run `shellcheck ralph.sh` and fix any issues

**Acceptance criteria:**
- --test runs single iteration without push
- TEST MODE banner shown
- Completion marker ignored
- shellcheck passes

---

#### Task 4.2: US-013 Interactive Confirmation Mode
**Priority:** 13 | **Effort:** Medium | **Depends on:** None

- [ ] 4.2.1 Add `--interactive` or `-i` flag to argument parsing
- [ ] 4.2.2 Add `--interactive-timeout N` flag (default 300 seconds)
- [ ] 4.2.3 Create `prompt_continue()` function
- [ ] 4.2.4 After each iteration, prompt: 'Continue to next iteration? [Y/n/s]'
- [ ] 4.2.5 'Y' continues, 'n' exits, 's' shows git diff then asks again
- [ ] 4.2.6 Add timeout with read -t
- [ ] 4.2.7 Display iteration summary before prompt
- [ ] 4.2.8 Check for TTY: `[ -t 0 ]` - if non-TTY, skip interactive or error
- [ ] 4.2.9 Run `shellcheck ralph.sh` and fix any issues

**Acceptance criteria:**
- --interactive prompts between iterations
- Y/n/s options work correctly
- Timeout after 5 minutes (configurable)
- Non-TTY environments handled
- shellcheck passes

---

#### Task 4.3: US-014 Verbose Mode with Prompt Preview
**Priority:** 14 | **Effort:** Small | **Depends on:** None

- [ ] 4.3.1 Add `--verbose` or `-v` flag (distinct from Claude's --verbose)
- [ ] 4.3.2 Add VERBOSE variable
- [ ] 4.3.3 Create `verbose_log()` function with DIM color and '[verbose]' prefix
- [ ] 4.3.4 Display resolved prompt content (after template substitution) before sending
- [ ] 4.3.5 Show config precedence (which value came from where)
- [ ] 4.3.6 Display session state updates
- [ ] 4.3.7 Show retry logic decisions
- [ ] 4.3.8 Verbose output clearly marked/indented
- [ ] 4.3.9 Run `shellcheck ralph.sh` and fix any issues

**Acceptance criteria:**
- -v shows prompt content before send
- Config source attribution shown
- Session state changes logged
- Output clearly distinguished
- shellcheck passes

---

#### Task 4.4: US-015 Shell Completion Scripts
**Priority:** 15 | **Effort:** Medium | **Depends on:** None

- [ ] 4.4.1 Create `completions/` directory
- [ ] 4.4.2 Create `completions/ralph.bash` for bash completion
- [ ] 4.4.3 Create `completions/ralph.zsh` for zsh completion
- [ ] 4.4.4 Complete presets: plan, build, product
- [ ] 4.4.5 Complete all flags: --model, --file, --prompt, etc.
- [ ] 4.4.6 Complete model names: opus, sonnet, haiku
- [ ] 4.4.7 Complete file paths for -f, -s, -l flags
- [ ] 4.4.8 Add installation instructions to show_help() or docs
- [ ] 4.4.9 Run `shellcheck completions/ralph.bash` and fix any issues

**Acceptance criteria:**
- Tab completion for bash and zsh
- Presets, flags, models complete
- File paths complete for relevant flags
- Install instructions documented
- shellcheck passes on completion scripts

---

#### Task 4.5: US-016 Update Documentation
**Priority:** 16 | **Effort:** Medium | **Depends on:** All above

- [ ] 4.5.1 Update docs/RALPH_LOOP_REF.md with all new flags
- [ ] 4.5.2 Add "Environment Variables" section to docs
- [ ] 4.5.3 Add "Session Resume" section to docs
- [ ] 4.5.4 Add "Retry Logic" section to docs
- [ ] 4.5.5 Add "Webhooks" section to docs
- [ ] 4.5.6 Add "Structured Logging" section to docs
- [ ] 4.5.7 Add "Troubleshooting" section for common issues
- [ ] 4.5.8 Update show_help() output with new options
- [ ] 4.5.9 Update ralph.conf with commented examples of new options
- [ ] 4.5.10 Add examples for CI/CD usage
- [ ] 4.5.11 Verify all code examples in docs still work
- [ ] 4.5.12 Update header comments in ralph.sh

**Acceptance criteria:**
- All new features documented
- Environment variables documented
- CI/CD examples provided
- All examples verified working
- Help output complete

---

## Milestones

### M1: Resilience MVP (v2.0.0-alpha)
Tasks: 1.1, 1.2, 1.3, 1.4, 1.5
**Goal:** Can resume sessions and retry on failures

### M2: CI/CD Ready (v2.0.0-beta)
Tasks: 2.1, 2.2, 2.3
**Goal:** Environment variable support and safe config for pipelines

### M3: Observable (v2.0.0-rc1)
Tasks: 3.1, 3.2, 3.3
**Goal:** Structured logging and notifications for monitoring

### M4: Developer Friendly (v2.0.0)
Tasks: 4.1, 4.2, 4.3, 4.4, 4.5
**Goal:** Quality of life improvements for development

---

## Verification Commands

After each task, run:
```bash
shellcheck ralph.sh
./ralph.sh --help
./ralph.sh --dry-run
./ralph.sh -p 'echo test' --model haiku 1
```

## Notes

- All changes must maintain backward compatibility with existing CLI
- Single bash script (no external dependencies beyond jq, git, claude)
- Preserve existing prompt files and template variable system
- Use existing color/symbol conventions
