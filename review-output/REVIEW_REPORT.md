# Codebase Review Report

**Project:** ralph-starter  
**Review date:** 2026-07-21  
**Scope:** ralph.sh, plugin/ (from sourceDirs) — focus: code-quality, test-coverage, architecture, security, bug

## Summary

| Severity | Count |
|----------|-------|
| critical | 0 |
| high | 5 |
| medium | 22 |
| low | 16 |
| info | 4 |
| **total** | **47** |

## High (5)

### F-007 [high] check_branch_change runs unguarded during tests, corrupts real repo state

**File:** `ralph.sh:3198`  
**Category:** test-coverage  
**Effort:** medium  
**Status:** open

The top-level call `if [ "$DRY_RUN" != true ]; then check_branch_change; fi` at ralph.sh:3198 sits outside all RALPH_TESTING guards, so it executes every time tests/test_helper.bash sources ralph.sh (Guard B, which normally sets CURRENT_BRANCH, is skipped under RALPH_TESTING=true, leaving CURRENT_BRANCH empty). This is not theoretical: in this exact working tree, .ralph-last-branch currently contains an empty string (verified via `od -c`) even though `git branch --show-current` reports `feature/ralph-plugin-plan-3`, and the file's mtime (today) lines up with a prior bats/make test run overwriting it with the empty CURRENT_BRANCH seen during sourcing. Separately, archive_branch_state() (ralph.sh:3134-3177) does not check the exit status of its cp calls before unconditionally truncating/resetting PROGRESS_FILE — a partial archive failure would still wipe progress notes. Neither the guard gap nor the missing cp error handling has any test.

**Suggestion:** Wrap the check_branch_change call (and any other top-level statements in that region) in the same RALPH_TESTING guard used elsewhere, or make test_helper.bash isolate LAST_BRANCH_FILE/ARCHIVE_DIR to a scratch dir before sourcing. Add bats tests for check_branch_change (no branch file, matching branch, changed branch) and for archive_branch_state that assert progress.txt is only reset when every cp actually succeeds. Also restore the current .ralph-last-branch file from the real branch name to undo the corruption already present.

### F-008 [high] parse_claude_output has zero tests; error heuristics can false-positive

**File:** `ralph.sh:3800`  
**Category:** test-coverage  
**Effort:** medium  
**Status:** open

parse_claude_output (ralph.sh:3800-4056) is the sole function that classifies each iteration as success/failure by scanning raw stream-json lines with unanchored substring matches, and it has no unit tests at all despite driving retry/backoff (run_with_retry) and session status. The broadest check, `[[ "$line" == *'"error"'* ]] && [[ "$line" == *'"type":"'* ]]` (line 3979), is not scoped to a specific message type — it fires on ANY stream-json line containing the literal substring `"error"` plus any `"type":"` field, which is present on nearly every line. A benign Read/Grep tool_result whose file content includes JSON with an error key (e.g. an API fixture, or source showing `{error: "Invalid request"}`), or assistant text quoting the word "error", would trip this branch and mark ITERATION_STATUS_FILE as "failed", triggering unnecessary retries/backoff for a perfectly successful iteration. Cross-category note: the code-quality and architecture reviews independently flagged this same function's 257-line size, mixed jq/substring parsing, and parsing/rendering/state-write coupling as the structural root cause of its untestability — decomposition and test coverage are one unit of work.

**Suggestion:** Add bats tests that pipe synthetic stream-json lines (one JSON object per line) into parse_claude_output and assert the resulting ITERATION_STATUS_FILE/ITERATION_REASON_FILE contents, covering: tool_use, type:result with is_error true/false, type:error, type:tool_result with is_error:true, completion marker detection, and adversarial lines (tool_result content containing "error" as part of unrelated file content) to confirm no false failure classification. Tighten the generic error-substring check to only fire on recognized message types; extract per-event-type handlers (pure classifier vs renderer vs state writes) so the classifier is unit-testable.

### F-020 [high] Reviewed-code text flows unsanitized into autonomous Bash-capable builders

**File:** `plugin/skills/reviewing-codebase/SKILL.md`  
**Category:** security  
**Effort:** medium  
**Status:** open

The review→fix pipeline treats natural-language text derived from arbitrary reviewed source files as trusted instructions for downstream tool-using agents, with no sanitization boundary at any hop. /ralph:review dispatches subagents that read target files and emit findings whose title/description/suggestion are free-form text (plugin/skills/reviewing-codebase/SKILL.md schema). /ralph:spec --from-findings turns each finding's `suggestion` directly into task `acceptanceCriteria` (plugin/skills/writing-ralph-specs/SKILL.md, 'Fix-specs from review findings', step 4). ralph-builder.md then instructs the builder to treat acceptance criteria as literal commands to execute when no test harness exists ('verify by executing the acceptance criteria literally'), and it runs with Bash access. In /ralph:improve (plugin/commands/improve.md), this entire chain runs headlessly and unattended with `--permission-mode acceptEdits --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep"`. Concretely: a crafted comment or string in reviewed source (e.g. from a malicious PR, vendored dependency, or contributor-supplied file) that a review subagent faithfully paraphrases into a finding's `suggestion` field can become a shell command an unattended builder later executes with Bash — before any human sees a PR diff.

**Suggestion:** Treat finding/suggestion text as data, not instructions: have build.md/ralph-builder.md require that any acceptance criterion resembling a shell command be matched against an allow-list of the repo's own documented verification commands (the same discipline spec.md already applies when sourcing context.verificationCommands) rather than executed verbatim from LLM-authored prose. Alternatively, require /ralph:improve's Phase I-3 fix-spec step to quote suggestion text into task descriptions/notes only (informational) and derive acceptanceCriteria solely from the builder's own analysis of the cited file, never by directly transcribing untrusted-review-agent prose into an executable criterion.

### F-023 [high] Missing-value option (e.g. trailing -p) hangs the CLI in an infinite loop

**File:** `ralph.sh:1200`  
**Category:** bug  
**Effort:** small  
**Status:** open

Every value-taking CLI option (-f, -p, -m, -n, --log-dir, --log-file, --global-config, --diff-base, etc.) does `shift 2` unconditionally inside the `while [[ $# -gt 0 ]]` argument-parsing loop. When the flag is the last argument with no value, `shift 2` fails (only 1 positional arg remains), does not shift, and `$1` stays the same flag forever. Reproduced by extracting the same case-statement pattern into a standalone script: running it with a trailing `-p` and no value spins forever, `$1` still `-p` and `$#` still 1 after unbounded iterations. Running `./ralph.sh -p` with nothing after it (forgotten/empty argument) hangs the process indefinitely with no error message and no timeout; the only way out is Ctrl-C.

**Suggestion:** After parsing each value-taking flag, check `[ $# -ge 2 ]` (or use `${2:?missing value for $1}`) before `shift 2`, and print a usage error + `exit 1` when the value is absent.

### F-024 [high] -n/--max value skips numeric validation, silently disabling the iteration cap

**File:** `ralph.sh:1224`  
**Category:** bug  
**Effort:** small  
**Status:** open

`RALPH_MAX_ITERATIONS` (env var, validated with `^[0-9]+$` at line 1562) and `MAX_ITERATIONS` from the config file (validated near line 2630) both reject non-numeric values, but the `-n|--max` CLI flag assigns `MAX_ITERATIONS="$2"` with no such check. `./ralph.sh -n abc` (typo, or a variable that expanded to empty/garbage) leaves `MAX_ITERATIONS=abc`. The loop guard `[ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]` at line 4156 then fails with `integer expression expected: abc` on every iteration (verified directly), the comparison evaluates to false, and the loop behaves as if `--unlimited` was passed — the exact runaway-session outcome `MAX_ITERATIONS` exists to prevent — while only printing a terse stderr line that's easy to miss in the loop's verbose output.

**Suggestion:** Validate `$2` against `^[0-9]+$` in the `-n|--max` case branch (mirroring the RALPH_MAX_ITERATIONS/config validation) and exit 1 with a clear error on a non-numeric value.

## Medium (22)

### F-001 [medium] safe_load_config's per-key override logic repeats the same 3-line pattern 9 times

**File:** `ralph.sh:2727`  
**Category:** code-quality  
**Effort:** medium  
**Status:** open

The case statement inside safe_load_config (lines 2728-2796) repeats an almost identical guard for nearly every config key: `if [ "$CLI_X_SET" != "true" ] && [ -z "${RALPH_X:-}" ]; then { [ -z "$VAR" ] || [ "$force" = "true" ]; } && VAR="$value"; fi`, varying only the variable/env names (SPEC_FILE, PLAN_FILE, PROGRESS_FILE, MODEL, MAX_ITERATIONS, LOG_DIR, PIPELINE_BUFFER, LOG_FORMAT, NOTIFY_WEBHOOK, plus SOURCE_DIR/PRODUCT_CONTEXT_DIR/PRODUCT_OUTPUT_DIR/ARTIFACT_SPEC_FILE without the CLI/env guard). Any future config key needs the same boilerplate re-typed, and the subtle variations between keys (some check CLI_SET, some don't) are easy to introduce inconsistently by copy-paste.

**Suggestion:** Drive this from a small table (associative array or parallel arrays) mapping config key -> target variable name, CLI-set flag name, and env var name, then apply the precedence check in one loop/helper instead of one case arm per key.

### F-002 [medium] Atomic JSON-file write (mktemp + echo + mv) is hand-duplicated across 6 functions

**File:** `ralph.sh:794`  
**Category:** code-quality  
**Effort:** medium  
**Status:** open

The same 4-line pattern — `updated=$(jq ... "$FILE" 2>/dev/null); if [ -n "$updated" ] && [ "$updated" != "null" ]; then tmp_file=$(mktemp "${FILE}.XXXXXX"); echo "$updated" > "$tmp_file"; mv "$tmp_file" "$FILE"; fi` — is repeated verbatim in update_session_state (line 296), finalize_session_state (line 331), restore_session (line 646), log_retry_attempt (line 794), clear_retry_attempts (line 811), and set_pipeline_state_field (line 3334). Each copy independently re-typed the 'prevents data loss / atomic write' comment, and any future fix to the write logic (e.g. adding file locking) has to be applied in 6 places.

**Suggestion:** Extract a helper, e.g. `atomic_json_update <file> <jq-filter> [jq-args...]`, that runs jq, validates non-null output, and does the mktemp/mv atomic swap once, then call it from all 6 sites.

### F-003 [medium] run_pipeline's spec-phase branches duplicate identical error-handling around varying args

**File:** `ralph.sh:3560`  
**Category:** code-quality  
**Effort:** small  
**Status:** open

In run_pipeline (lines 3560-3575), the if/elif/else over `input_type` (product/file/prompt) repeats the same three-line failure block three times: `if ! run_pipeline_phase_command "spec" 5 <different-args>; then set_pipeline_state_field '.status = "failed" | .phases.spec.status = "failed" | .failure_reason = "spec_phase_failed"'; return 1; fi` — only the argument list passed to run_pipeline_phase_command differs between branches.

**Suggestion:** Build the argument list into an array (`case "$input_type" in product) spec_args=(...);; file) spec_args=(...);; *) spec_args=(...);; esac`) and call run_pipeline_phase_command with the array once, followed by a single shared failure-handling block.

### F-009 [medium] Session state/resume functions (init/update/finalize/validate/restore) untested

**File:** `ralph.sh:196`  
**Category:** test-coverage  
**Effort:** medium  
**Status:** open

init_session_state, update_session_state, finalize_session_state, validate_session, and restore_session (ralph.sh:196-654) back the documented --resume and --list-sessions CLI features and are defined outside any RALPH_TESTING guard, so — like the pure functions already covered in tests/pure_functions.bats — they are directly sourceable and testable via test_helper.bash. None of them has a single test. This leaves untested: the atomic-write guard (`[ -n "$updated" ] && [ "$updated" != "null" ]`) meant to prevent session-file corruption on jq failure, the branch-mismatch abort in validate_session, the reject-completed-session check, and the BSD-vs-GNU date parsing branch used for session-age warnings (macOS `date -j -f` vs GNU `date -d`).

**Suggestion:** Add bats tests for validate_session (missing file, invalid JSON, status=complete, branch mismatch, missing branch field, stale start_time on both date-parsing branches) and for update_session_state/finalize_session_state/restore_session using fixture session JSON files, asserting the resulting file contents rather than just exit codes.

### F-010 [medium] dev/launch pipeline orchestration only smoke-tested via --dry-run text

**File:** `ralph.sh:3450`  
**Category:** test-coverage  
**Effort:** large  
**Status:** open

run_pipeline, the non-dry-run branch of create_or_switch_pipeline_branch, run_pipeline_phase_command, init_pipeline_state, and set_pipeline_state_field (ralph.sh:3291-3616+) implement the entire dev/launch pipeline (branch creation, phase-command argument assembly, JSON pipeline-state persistence). The only coverage is tests/integration_dryrun.bats, which asserts loose substrings like *"Pipeline"* on --dry-run output — a mode that explicitly short-circuits create_or_switch_pipeline_branch (`if [ "$DRY_RUN" = true ]; then ... return 0; fi`) before any of the real logic runs. The actual branch switch/create, phase-command construction (flag propagation for --push/--no-push, --model, --max-retries, --verbose, --log-format, --notify-webhook), and pipeline-state JSON transitions are never exercised by any test.

**Suggestion:** Add tests that run these functions directly against a throwaway git repo (similar to tests/make_sandbox.sh) with DRY_RUN=false: assert create_or_switch_pipeline_branch actually creates/switches branches, assert run_pipeline_phase_command builds the expected argv array for representative flag combinations, and assert init_pipeline_state/set_pipeline_state_field produce the expected JSON shape and survive atomic writes.

### F-014 [medium] Phase 4 fix-task dispatch has no defined task-card schema

**File:** `plugin/commands/build.md:143`  
**Category:** architecture  
**Effort:** small  
**Status:** open

The verifier-driven fix loop tells the orchestrator to 'treat each finding as a fix task' and dispatch a ralph-builder, but never specifies what the dispatched task card looks like, unlike Phase 3.6, which explicitly defines it as 'task JSON + spec context block + branch name'. ralph-builder.md's contract assumes a task card with id/title/description/acceptanceCriteria fields and mandates the commit message 'feat(<task-id>): <title>' (rule 6). A verifier finding is free-text ('numbered list: severity, file:line, what is wrong'), not a task object, so the orchestrator has no specified id to put in that commit message or to record attempts/notes against. Two orchestrator runs could construct different ad hoc task-id conventions for the same kind of fix, and nothing would catch the drift since there's no test around this cross-file contract.

**Suggestion:** Add an explicit sub-step to Phase 4 step 3 specifying how to turn a verifier finding into a task card (e.g., a synthetic id like 'FIX-<n>', title/description/acceptanceCriteria derived from the finding text) so the dispatched card satisfies ralph-builder.md's stated input contract and commit-message rule.

### F-015 [medium] /ralph:go is the only autonomous command with no turn or wall-clock cap

**File:** `plugin/commands/go.md`  
**Category:** architecture  
**Effort:** small  
**Status:** open

build.md, dev.md, improve.md, and improve-cycle.md all compute and enforce an explicit TURN_CAP/HOURS_CAP or improveTurns/improveUsd budget before dispatching work, and the plugin README states 'Caps everywhere — every goal carries turn and wall-clock stop clauses... There is no --unlimited' as a blanket guardrail (README.md line 158). go.md is the outlier: it defines a multi-step autonomous procedure (branch, implement, verify, commit, optional PR) with no turn count, no wall-clock limit, and no reference to CLAUDE_PLUGIN_ROOT or any config-driven budget (it's also the only command file that skips both). A headless invocation of /ralph:go on an underspecified or open-ended task has no internal stop clause of its own to fall back on, unlike every other multi-turn entry point in the plugin, contradicting the README's stated invariant that every goal carries a stop clause.

**Suggestion:** Either give go.md its own small turn/wall-clock cap (consistent with the other commands, sourced from .claude/ralph.json's defaultBudgets the same way build.md does), or narrow the README's guardrail claim to the commands it actually applies to.

### F-016 [medium] BUILDER/VERIFIER REPORT marker parsing is an untested cross-file string contract

**File:** `plugin/commands/build.md:116`  
**Category:** architecture  
**Effort:** small  
**Status:** open

build.md (Phase 3 step 7, Phase 4 step 2) locates subagent results by string-searching for a literal 'BUILDER REPORT' or 'VERIFIER REPORT' marker line and then reading fixed-name fields (result/commit/verified/notes, verdict/checked/findings/commands) out of free text that follows. The exact block format is defined independently in plugin/agents/ralph-builder.md and plugin/agents/ralph-verifier.md, with no schema or test tying the three files together. A future wording edit to either agent file (e.g. renaming 'verified:' to 'verification:', or changing capitalization of the marker line) would silently break the orchestrator's parsing with no compile-time or test-time signal — the only stated fallback is treating an unmatched report as malformed, which degrades a real success into a spurious FAILED/attempts-incremented outcome.

**Suggestion:** Since these are prose files rather than code, add a lightweight fixture-based check (even a bats test that greps the three files for the exact marker/field strings they depend on) so a drift is caught before it reaches a live build.

### F-021 [medium] Spec verificationCommands executed via bash -c with no provenance check

**File:** `plugin/scripts/ralph-evidence.sh:39`  
**Category:** security  
**Effort:** small  
**Status:** open

ralph-evidence.sh runs every entry of `.context.verificationCommands` from the spec JSON with `bash -c "$cmd"` (line 39), and this script is invoked by /ralph:build, /ralph:spec, and /ralph:status against whatever spec path is given. ralph-verifier.md also independently re-runs the spec's verificationCommands. While plugin/commands/spec.md constrains freshly-generated specs to only use commands already documented in the target repo (never inventing commands), nothing at the execution layer verifies that a spec file passed to `/ralph:build <path>` (or discovered by /ralph:status) actually came from that trusted generation path — a spec obtained from an external PR, a shared file, or hand-edited by another contributor is executed exactly the same way, with full shell semantics (pipes, redirects, command substitution all work inside the bash -c string).

**Suggestion:** Before ralph-evidence.sh or ralph-verifier.md execute verificationCommands from a spec that wasn't generated by the current /ralph:spec run, surface the raw command list to the operator and require explicit confirmation (or at minimum print the commands prominently before running them), similar to the trust prompts common in build tools that execute repo-declared scripts (e.g. `pnpm approve-builds`).

### F-025 [medium] Evidence script crashes with an undocumented exit code on a tasks-less spec

**File:** `plugin/scripts/ralph-evidence.sh:18`  
**Category:** bug  
**Effort:** small  
**Status:** open

`ralph-evidence.sh` documents exit codes 0 (evidence printed), 2 (missing/invalid spec), 3 (no verificationCommands) — but `TOTAL=$(jq '.tasks | length' "$SPEC")` followed by `.tasks[] | select(...)` under `set -euo pipefail` aborts with jq's own exit code when `.tasks` is absent/null (e.g. a spec using only the legacy `userStories` array, which the top-level CLAUDE.md documents as still supported). Reproduced directly: a valid-JSON spec with `context.verificationCommands` set and only a `userStories` array (no `tasks` key) makes the script print `jq: error (...): Cannot iterate over null (null)` and exit 5, not 0/2/3. `/ralph:build`'s Phase 1 step 4 happens to check for a non-empty `tasks` array before ever calling this script, so the build path is shielded, but `/ralph:status` (plugin/commands/status.md step 2) calls `ralph-evidence.sh` on every `specs/*.json` unconditionally and only special-cases exit 3, so a legacy or hand-authored tasks-less spec sitting in `specs/` makes `/ralph:status` surface a raw jq crash instead of a clean report line.

**Suggestion:** Guard the tasks-derived lines with a check for `.tasks == null` (e.g. `jq '(.tasks // []) | length'`) or add a documented exit code for "no tasks array", and have status.md handle it the same way it already handles exit 3.

### F-026 [medium] grep -oP (PCRE) used for commit-message extraction fails on BSD grep

**File:** `ralph.sh:3903`  
**Category:** bug  
**Effort:** small  
**Status:** open

`local commit_msg=$(echo "$tool_detail" | grep -oP '(?<=-m ")[^"]*' | head -1)` relies on GNU grep's `-P` (PCRE) flag. Stock macOS ships BSD grep, which does not support `-P`. Verified with `bash -c 'echo ... | /usr/bin/grep -oP ...'` on this machine's actual `/usr/bin/grep` (BSD grep 2.6.0-FreeBSD, the binary a `#!/bin/bash` script gets unless the user has GNU grep earlier on PATH): it prints `grep: invalid option -- P` to stderr and exits 2. Inside ralph.sh this means every `git commit` tool call detected during a build iteration leaks that grep error to the terminal/log, and `commit_msg` always resolves empty, so the iteration summary's "Committed" list never shows a commit message even though commits happened. (The code-quality review independently flagged this same line — one root cause, recorded once here.)

**Suggestion:** Replace with a portable extraction, e.g. `grep -oE -- '-m "[^"]*"' | sed -E 's/^-m "//; s/"$//'`, or `sed -E 's/.*-m "([^"]*)".*/\1/'` — both work under BSD and GNU grep/sed. Add stderr suppression consistent with the rest of the function.

### F-027 [medium] Temp files created before the EXIT trap is registered leak on every early exit

**File:** `ralph.sh:2573`  
**Category:** bug  
**Effort:** small  
**Status:** open

`COMPLETION_FILE`, `ITERATION_STATUS_FILE`, and `ITERATION_REASON_FILE` are created via `mktemp` at lines 110/130-131, but `trap cleanup_temp EXIT` isn't registered until line 2573. Roughly twenty `exit` calls occur in between (argument-validation errors, `setup` mode's `exit 0` at line 1517, `--interactive-timeout`/`--max-retries` validation failures, etc.). Any of those early exits — including the documented `setup` mode, which always exits 0 right after printing usage instructions — leaves 3 empty temp files behind in `/tmp` (`ralph_complete_*`, `ralph_status_*`, `ralph_reason_*`) with no cleanup, since the EXIT trap that would remove them was never installed for that process.

**Suggestion:** Move `trap cleanup_temp EXIT` to immediately after the three mktemp calls (or right after the `RALPH_TESTING` guard at the top of the file) so it covers every subsequent exit path.

### F-028 [medium] No guard against two concurrent ralph.sh runs sharing the same session state

**File:** `ralph.sh:196`  
**Category:** bug  
**Effort:** medium  
**Status:** open

`init_session_state()` unconditionally overwrites `.ralph-session.json` (a fixed, non-PID-namespaced path) with no check for an already-running session, and there is no lock file anywhere in the script guarding `.ralph-session.json` or `PROGRESS_FILE` against concurrent writers. Two `./ralph.sh` invocations started in the same working directory (e.g. one left running in a background terminal, a second started manually, or a crashed process whose session file was never cleaned up) both call `init_session_state()`/`update_session_state()` against the same `.ralph-session.json`; the second process's `init_session_state` uses a plain `>` redirect (not the mktemp+mv atomic pattern used elsewhere in the file) so it can clobber the first run's session mid-write, and both loops independently push/commit against the same branch, interleaving iteration state and git operations unpredictably.

**Suggestion:** Take a simple lock (e.g. `mkdir .ralph-session.lock` or `flock` on a sentinel file) at startup and abort with a clear message if a live session is already using the same session file, releasing it in the existing cleanup/finalize paths.

### F-029 [medium] Autonomous loop pushes current branch with no default-branch guard

**File:** `ralph.sh:4205`  
**Category:** security  
**Effort:** small  
**Status:** open

After every iteration the main loop runs 'git push origin "$CURRENT_BRANCH"' (and 'git push -u' as a fallback) whenever PUSH_ENABLED is true, which is the default. There is no check that CURRENT_BRANCH is not the repository's default branch (main/master). Because the loop drives Claude fully unattended and push is on by default, running ralph.sh while checked out on main will push unreviewed, machine-generated commits straight to the default branch on origin after each iteration. The plugin command layer (go.md/build.md) explicitly enforces branch-first and 'never the default branch', but the standalone bash runner enforces no such protection.

**Suggestion:** Before pushing, resolve the repo's default branch (e.g. 'git symbolic-ref refs/remotes/origin/HEAD' or a configurable DEFAULT_BRANCH) and refuse to push when CURRENT_BRANCH matches it, aborting with a clear message that autonomous runs must operate on a non-default branch. Alternatively require an explicit --allow-default-branch-push opt-in.

### F-030 [medium] All modes (incl. read-only 'review') run under --dangerously-skip-permissions

**File:** `ralph.sh:843`  
**Category:** security  
**Effort:** medium  
**Status:** open

run_with_retry invokes 'claude -p --dangerously-skip-permissions ...' unconditionally for every mode. This bypasses all tool-permission prompts, granting the agent unrestricted Bash/Write/Edit for the entire session with no allowlist or sandbox. Notably 'review' mode is documented and presented as read-only analysis (PUSH is disabled for it at line 1540), yet the agent still runs fully permission-skipped and can execute arbitrary Bash and modify files. This also amplifies the impact of the spec/product input paths (lines 2947-2984), where the contents of a -f requirements file or product-output/*.md artifacts are concatenated verbatim into the prompt.

**Suggestion:** Do not use --dangerously-skip-permissions unconditionally. For review mode, pass a read-only tool allowlist (e.g. Read/Grep/Glob only) so the documented read-only contract is enforced. For build/spec/product modes prefer an explicit --allowedTools allowlist over blanket permission-skipping, and treat -f/product-artifact content as untrusted data.

### F-033 [medium] ${response,,} lowercase expansion breaks on bash 3.2 (macOS default)

**File:** `ralph.sh:2414`  
**Category:** bug  
**Effort:** low  
**Status:** open

prompt_continue() uses the bash 4.0+ case-conversion expansion 'case "${response,,}" in'. The script's shebang is '#!/bin/bash', which on macOS (the documented darwin target) resolves to bash 3.2, where ${var,,} is an unsupported 'bad substitution' runtime error. The rest of the codebase deliberately uses the portable 'tr [:upper:] [:lower:]' (e.g. is_retryable_error line 711). When a user runs in --interactive mode on stock macOS bash, the first confirmation prompt triggers a bad-substitution error that aborts the run mid-session.

**Suggestion:** Lowercase with a portable construct instead, e.g. 'resp_lc=$(printf %s "$response" | tr [:upper:] [:lower:]); case "$resp_lc" in ...', matching the approach used elsewhere in the script.

### F-034 [medium] Task with missing .status or .title crashes jq string concatenation under set -e

**File:** `plugin/scripts/ralph-evidence.sh:28`  
**Category:** bug  
**Effort:** low  
**Status:** open

The task-line formatter concatenates fields with '+': '.tasks[] | (.id + " [" + (if .passes == true then "passed" else .status end) + "] " + .title)' (line 28, reused at line 33). In jq, adding a string to null throws 'string and null cannot be added'. If any task object lacks a status or title key (or has them null) — plausible for a freshly-added task before the builder fills it in — jq exits non-zero, and because the script runs under 'set -euo pipefail', the whole evidence generation aborts with an opaque jq exit code. Distinct from a tasks-less spec: it triggers on well-formed .tasks arrays containing one malformed entry. (Fixing this also closes the corresponding untested-error-path coverage gap.)

**Suggestion:** Guard the fields with defaults, e.g. '(.id // "?") + " [" + (if .passes == true then "passed" else (.status // "unknown") end) + "] " + (.title // "(no title)")', in both the <=12 branch (line 28) and the >12 branch (line 33). Add a bats case feeding a task with missing title/status.

### F-036 [medium] parse_claude_output is a ~256-line function mixing five concerns

**File:** `ralph.sh:3800`  
**Category:** code-quality  
**Effort:** medium  
**Status:** open

parse_claude_output (lines 3800-4056) spans roughly 256 lines and interleaves five distinct responsibilities: raw-log persistence, completion-marker detection, per-tool dispatch/rendering (the large case block 3864-3926), multi-branch error detection (result/error/tool_result/system errors), and the final accomplishment-summary rendering (3995-4044). It far exceeds CLAUDE.md's 'under 30 lines' guidance and the category's ~50 LOC threshold, and the nested while-read-inside-while-read plus inline jq/cut extraction makes the control flow hard to follow and test.

**Suggestion:** Extract cohesive helpers: e.g. handle_tool_use_line (the tool_use parse + case dispatch), detect_stream_errors (the four error branches that all write 'failed' to ITERATION_STATUS_FILE), and render_iteration_summary (the accomplishment block). The top-level loop then reads as a dispatcher, and each concern becomes independently testable.

### F-040 [medium] run_with_retry orchestration (backoff, max-retry boundary, branches) untested

**File:** `ralph.sh:826`  
**Category:** test-coverage  
**Effort:** medium  
**Status:** open

is_retryable_error is unit-tested in isolation, but the retry loop that consumes it in run_with_retry has zero coverage. Untested logic includes: the exponential backoff formula delay=RETRY_BACKOFF_BASE*(3**(attempt-1)); the max-retry boundary 'attempt > MAX_RETRIES' (allows MAX_RETRIES+1 total attempts — an off-by-one worth locking down); the RETRY_ENABLED=false short-circuit; the fatal-vs-transient branch that returns immediately on non-retryable errors; and the LAST_ERROR_MSG extraction. The retry-attempt persistence helpers log_retry_attempt/clear_retry_attempts (atomic jq write + rename) are also uncovered.

**Suggestion:** Extract the classification/backoff decision (given error msg, exit_code, attempt, MAX_RETRIES, RETRY_ENABLED -> retry|give-up|abort + delay) into a pure helper and add bats cases: retryable transient retries with correct delays, exhaustion at the boundary, --no-retry short-circuit, and fatal-error abort. Test log_retry_attempt/clear_retry_attempts against a temp SESSION_FILE asserting the resulting JSON.

### F-041 [medium] Dry-run mode tests assert on generic mode-name substrings, not resolved MODE

**File:** `tests/integration_dryrun.bats:59`  
**Category:** test-coverage  
**Effort:** low  
**Status:** open

Most mode dry-run tests (plan/product/launch/dev/build/inline) assert only that the bare mode word appears somewhere in verbose output. These words also appear in banners, the preset list, and config echoes, so the assertions can pass even if arg parsing routed to the wrong preset. They verify 'the script printed a common word' rather than 'MODE/PRESET_NAME resolved to the expected value'. Broader instance than the known push-disabled-substring issue (F-013).

**Suggestion:** Have --dry-run emit a stable, unambiguous line such as 'resolved-mode: <preset>' (or assert on the config-precedence block that prints the concrete MODE) and match that exact token, so a routing regression fails the test.

### F-043 [medium] Worktree pid-sidecar state model reimplemented in three files

**File:** `plugin/commands/improve.md:19`  
**Category:** architecture  
**Effort:** medium  
**Status:** open

The convention for improve-tick runtime state — pid at <path>.pid, log at <path>.log, scratch at <path>.selected.json, all SIDECARS next to (never inside) the worktree — plus the RUNNING/CRASHED/FINISHED classification derived from pid-sidecar presence and 'kill -0' liveness, is independently re-specified in improve.md (Busy checks 1), status.md (step 5), and consumed again in improve-cycle.md (Cleanup steps 1-2). No single file owns this contract; a change to the sidecar naming or the liveness/cleanup semantics must be mirrored across all three or the launcher, dashboard, and cycle silently disagree about whether a tick is alive.

**Suggestion:** Define the sidecar layout and the RUNNING/CRASHED/FINISHED state machine once (a short shared reference section, or a helper script the three commands invoke) and have improve.md, status.md, and improve-cycle.md cite it rather than each restating the paths and liveness rules.

### F-044 [medium] Composing commands couple to build.md's internal phase/step numbers

**File:** `plugin/commands/build.md:37`  
**Category:** architecture  
**Effort:** small  
**Status:** open

Because a slash command cannot invoke another, dev.md and improve-cycle.md compose build.md by reading it and executing its procedure — and both reference build.md's internal structure by number: dev.md Phase B says the spec is committed 'via its Phase 1 step 3a', improve-cycle.md Phase I-4 says the same 'Phase 1 step 3a', and improve.md refers to 'build.md's clean-tree preflight'. These cross-file references treat build.md's phase/step numbering as a stable public API. Renumbering or restructuring build.md's phases leaves these pointers dangling with no compiler or test to catch the drift.

**Suggestion:** Give the load-bearing behaviors stable named anchors (e.g. a 'spec-commit' or 'clean-tree preflight' labeled step) and have dev.md/improve-cycle.md/improve.md reference the name rather than 'Phase 1 step 3a'.

## Low (16)

### F-004 [low] init_pipeline_state takes 6 positional string params including a buried boolean

**File:** `ralph.sh:3340`  
**Category:** code-quality  
**Effort:** small  
**Status:** open

init_pipeline_state(branch_name, input_type, input_hint, input_value, run_product, spec_output_file) has six same-typed positional string arguments, two of which (input_hint, input_value) are easy to transpose at a call site, plus a boolean (run_product) passed positionally in the middle rather than as a named flag — the pattern the repo's own review-category guidance calls out as a complexity smell ('boolean-flag parameters'). Currently there is only one call site so it hasn't caused a bug, but the shape invites one if a second caller is added.

**Suggestion:** Pass a small associative array or a set of named `key=value` arguments instead of six positionals, or at minimum reorder so the boolean and file-path arguments aren't adjacent to two same-typed string arguments.

### F-005 [low] Nightly routine hardcodes improve-cycle caps that live elsewhere as config defaults

**File:** `plugin/routines/improve-nightly.md:30`  
**Category:** code-quality  
**Effort:** small  
**Status:** open

The routine's fallback launch command (line 30) hardcodes `--max-turns 50 --max-budget-usd 10`. These are the same numbers documented in commands/improve.md's Launch step 1 as the *default* fallback when `.claude/ralph.json` doesn't define `defaultBudgets.improveTurns`/`improveUsd` — but improve.md's launcher actually reads the config file first, while this routine's fallback path never reads `.claude/ralph.json` at all; it just repeats the current default values as a literal. If the defaults in improve.md (or a host's config) ever change, this routine silently keeps using the old numbers with no mechanism to notice the drift.

**Suggestion:** Have the fallback branch read `.claude/ralph.json` -> defaultBudgets.improveTurns/improveUsd with jq (falling back to 50/10 only if the file or fields are absent), mirroring improve.md's Launch step 1, instead of hardcoding the current defaults.

### F-011 [low] Config precedence layering (load_ralph_config) has no coverage

**File:** `ralph.sh:2810`  
**Category:** test-coverage  
**Effort:** small  
**Status:** open

tests/config_loading.bats thoroughly unit-tests the single-file parser safe_load_config, but load_ralph_config (ralph.sh:2810-2851) — which implements the documented precedence "global < project ralph.conf < host ralph.conf < CLI/env" by calling safe_load_config three times in order — has no test verifying that a later source actually overrides an earlier one. A reordering bug in load_ralph_config would not be caught by any existing test.

**Suggestion:** Add a test that creates fixture global/project/host config files with conflicting values for the same key and asserts the final resolved value matches the documented precedence order.

### F-012 [low] Evidence task-count buckets silently drop tasks with unrecognized status

**File:** `plugin/scripts/ralph-evidence.sh:20`  
**Category:** test-coverage  
**Effort:** small  
**Status:** open

The in_progress/pending/blocked counts (ralph-evidence.sh:20-22) only match tasks where .passes != true AND .status is exactly "in_progress", "pending", or "blocked". A task with passes:false and any other status value (e.g. "complete" set without passes:true, or a missing/typo'd status field) is counted in TOTAL but falls into none of the four buckets, so the printed breakdown line silently stops summing to TOTAL. tests/plugin_evidence.bats has a golden exact-output test and several substring tests, but none constructs this mismatched-state fixture, so a regression here (or the underlying spec-authoring bug it would reveal) would go unnoticed by the evidence the goal-evaluator relies on.

**Suggestion:** Add a bats case with a task whose status is an unrecognized value (or missing) while passes is false/absent, and assert either that the counts still reconcile to TOTAL or that the script surfaces an explicit 'unknown status' bucket instead of silently dropping the task from the tally.

### F-013 [low] Push-disable dry-run tests assert on a generic 'disabled' substring

**File:** `tests/integration_dryrun.bats:105`  
**Category:** test-coverage  
**Effort:** small  
**Status:** open

"--no-push flag disables push" (line 117), "review mode disables push even with --push" (line 105), and the related push-status checks all assert only `[[ "$output" == *"disabled"* ]]` without pinning to the specific config/push line or the reason shown. Because the word "disabled" could plausibly appear elsewhere in --dry-run output (e.g. a future "retry disabled" or "summary disabled" line), a regression that made push always print "disabled" for the wrong reason, or that broke the actual --push-override-in-review-mode behavior while some other line still contained "disabled", could pass all three tests undetected.

**Suggestion:** Anchor these assertions to the specific config output line (e.g. grep for a line matching a Push: field) rather than a bare substring match anywhere in the full --dry-run output.

### F-017 [low] 'Deterministic completion evidence' claim is undercut by an LLM-judged Stop hook

**File:** `plugin/.claude-plugin/plugin.json:4`  
**Category:** architecture  
**Effort:** small  
**Status:** open

plugin.json markets the plugin as providing 'deterministic completion evidence,' but the actual stop-gating mechanism (plugin/hooks/hooks.json) is a prompt-type hook where a haiku model freely judges, from prose, whether the transcript satisfies the .ralph-goal condition. The README itself documents this leaking: it says the hook 'has been observed to spuriously block with insufficient evidence' and that running `ls .ralph-goal` is a required workaround to satisfy it. The 'deterministic' framing sets an expectation (evidence-based, reproducible pass/fail) that the implementation doesn't fully deliver — the actual enforcement is a probabilistic LLM read of the transcript, which is why a manual workaround already had to be documented for spurious blocking.

**Suggestion:** Soften plugin.json's description (e.g. 'evidence-anchored' rather than 'deterministic'), or note in the README/plugin.json that the Stop hook's judgment layer is LLM-based and the deterministic part is only the ralph-evidence.sh script's output, not the gating decision itself.

### F-018 [low] generate_summary mixes data-fetch, status-mapping, and report rendering

**File:** `ralph.sh:2153`  
**Category:** architecture  
**Effort:** medium  
**Status:** open

This 210-line function (lines 2153-2363) performs jq queries against the session file, maps final_status onto emoji/text pairs via a case statement, and builds a Markdown summary document — three distinct responsibilities in one function, with no bats coverage. A change to the session-file schema (e.g. renaming a jq field) or to the summary's Markdown layout both require editing and manually re-verifying the same function, since there's no seam separating 'what happened' from 'how it's rendered.'

**Suggestion:** Extract a small session-data-loading helper and a status-label lookup, leaving generate_summary to only assemble the final Markdown from already-computed inputs.

### F-022 [low] Predictable temp-file and worktree paths in shared /tmp

**File:** `ralph.sh`  
**Category:** security  
**Effort:** small  
**Status:** open

Several code paths create files/directories under the shared, world-writable /tmp using predictable naming rather than a private per-run directory: ralph.sh's `mktemp /tmp/ralph_complete_XXXXXX`, `/tmp/ralph_status_XXXXXX`, `/tmp/ralph_reason_XXXXXX`, `/tmp/ralph_retry_XXXXXX`, and `/tmp/ralph_prompt_XXXXXX.md` (lines 110, 130-131, 701, 1779) all use a fixed, guessable prefix, and RETRY_OUTPUT_FILE captures the full stream-json output of each `claude` invocation (potentially including file contents or other session data). Separately, plugin/commands/improve.md and plugin/routines/improve-nightly.md build worktree paths as plain string concatenation — `WT=/tmp/ralph-improve-$TS` with only second-resolution timestamps, no mktemp/random suffix — before calling `git worktree add "$WT" ...`. On a shared multi-user host, an attacker who pre-creates or symlinks a matching /tmp path ahead of time could redirect where output is written or interfere with worktree creation (classic /tmp race/symlink class of issue), and any local user can enumerate active ralph runs by prefix.

**Suggestion:** Use `mktemp -d` to create a private, randomly-named directory per run and place all sidecar files (retry output, completion markers, worktrees) inside it, rather than composing predictable paths directly under the shared /tmp root.

### F-031 [low] Webhook URL unvalidated; session metadata and commit messages exfiltrated

**File:** `ralph.sh:2123`  
**Category:** security  
**Effort:** small  
**Status:** open

send_webhook POSTs a JSON payload to NOTIFY_WEBHOOK (settable via --notify-webhook, RALPH_NOTIFY_WEBHOOK, or ralph.conf). The payload includes branch name, mode/model, and the last commit subject. The URL is never validated to be https, so an http:// endpoint sends this repository metadata in cleartext, and no host allowlisting exists, so a misconfigured or attacker-supplied config value silently forwards internal branch/commit information to an arbitrary destination.

**Suggestion:** Reject non-https webhook URLs (or warn loudly), and consider omitting the commit subject from the payload or making its inclusion opt-in. Optionally support a host allowlist for the notification endpoint.

### F-035 [low] jq [0:N] slice placed outside interpolation prints literal '[0:40]' instead of truncating

**File:** `ralph.sh:611`  
**Category:** bug  
**Effort:** low  
**Status:** open

Two jq format strings intend to truncate the commit message but place the slice outside the \(...) interpolation: '... \(.commit_message // "no commit")[0:40]' (line 611, resume history) and '... \(.commit_message // "-")[0:50] |' (line 2255, summary markdown table). Because [0:40]/[0:50] sits in the literal portion of the string rather than inside the interpolation, jq emits the full untruncated commit message followed by the literal text '[0:40]'/'[0:50]'. Long commit messages are not truncated, and summary table rows are polluted with a stray '[0:50]'.

**Suggestion:** Move the slice inside the interpolation and apply it to the string value, e.g. '\((.commit_message // "no commit")[0:40])' and '\((.commit_message // "-")[0:50])'. Affects 2 locations (lines 611 and 2255).

### F-037 [low] Pipeline phase iteration caps are magic numbers duplicated across preview and invocation

**File:** `ralph.sh:3517`  
**Category:** code-quality  
**Effort:** small  
**Status:** open

run_pipeline hardcodes phase iteration caps as bare literals in two places that must stay in sync: the DRY_RUN preview prints 'run (max 15)' for product and 'run (max 5)' for spec (lines 3517, 3526), while the real invocations pass 15 (line 3545) and 5 (lines 3561/3566/3571). calculate_pipeline_build_iterations similarly hardcodes guardrail bounds 5 and 200 (lines 3438-3439). CLAUDE.md's Code Style says avoid magic numbers. Changing the product cap requires editing both the preview string and the invocation, an easy drift bug.

**Suggestion:** Introduce named readonly constants (e.g. PRODUCT_PHASE_MAX_ITER=15, SPEC_PHASE_MAX_ITER=5, BUILD_ITER_MIN=5, BUILD_ITER_MAX=200) near the other config defaults and reference them in both the preview and the invocation.

### F-038 [low] validate_config_value repeats the warning-echo + return-1 block across four arms

**File:** `ralph.sh:2615`  
**Category:** code-quality  
**Effort:** small  
**Status:** open

validate_config_value has four case arms (MODEL, MAX_ITERATIONS/PIPELINE_BUFFER, PUSH_ENABLED, LOG_FORMAT) that each end in a near-identical two-line pattern: echo a yellow Warning to stderr and return 1. Only the 'expected' hint differs. This is low-grade duplication of the same rejection idiom four times.

**Suggestion:** Extract a small helper, e.g. reject_config_value(key, value, expected) that emits the standardized warning and returns 1, so each arm becomes a single validate-or-reject line and the message format lives in one place.

### F-039 [low] is_retryable_error carries a misleading comment about exit code 1

**File:** `ralph.sh:727`  
**Category:** code-quality  
**Effort:** small  
**Status:** open

In is_retryable_error the comment block (lines 727-729) states '1 = general error (could be transient)', implying exit code 1 might be retried, but no code acts on that: after the FATAL/RETRYABLE pattern loops, only exit_code >= 128 is handled explicitly and everything else (including 1) falls through to 'Default: not retryable'. The comment describes behavior the function does not implement.

**Suggestion:** Delete or correct the exit-code-1 comment so it matches the conservative default (retryability is decided by message-pattern matching, not by exit code 1), leaving only the accurate note about signal codes 128+.

### F-042 [low] send_webhook payload construction and HTTP classification untested

**File:** `ralph.sh:2052`  
**Category:** test-coverage  
**Effort:** low  
**Status:** open

send_webhook builds a JSON payload with jq and maps event_type -> summary, then classifies success as 2xx. None of this is covered. '--argjson iterations' and '--argjson failed' will make jq fail if those globals are ever non-numeric, and the event->summary case mapping and the 200-299 success boundary are unverified.

**Suggestion:** Refactor the payload-building and event->summary mapping into a pure function that takes explicit args and returns JSON; add bats cases asserting the JSON for each event_type and that numeric fields are emitted as numbers. Optionally test the 2xx/non-2xx branch by injecting a stub curl.

### F-045 [low] review.md restates the finding schema the skill already owns

**File:** `plugin/commands/review.md:46`  
**Category:** architecture  
**Effort:** small  
**Status:** open

review.md step 3 spells out the subagent output contract as an inline field list (category/severity/file/line?/title/description/suggestion/effort/references?, minus id/addressed). The reviewing-codebase SKILL.md already defines the authoritative Findings JSON Schema table, and review.md step 1 instructs reading that skill 'exactly'. The schema now lives in two places; adding or renaming a finding field requires editing both, and they can silently diverge.

**Suggestion:** Have review.md's subagent instructions point at the skill's Findings JSON Schema (noting only the two orchestrator-assigned exclusions, id and addressed) instead of re-enumerating the fields, keeping the schema single-sourced in the skill.

### F-046 [low] Evidence script's 12-task display truncation leaks into goal-condition design

**File:** `plugin/scripts/ralph-evidence.sh:29`  
**Category:** architecture  
**Effort:** small  
**Status:** open

ralph-evidence.sh serves two audiences at once: a human-readable report and the machine completion signal the Stop-hook goal evaluates. Its presentation choice to omit per-task lines above 12 tasks (line 29) is load-bearing for correctness — build.md Phase 2 must key its goal condition on the summary counts line precisely because per-task lines vanish at scale. A rendering tweak to the script (changing the 12 threshold, reordering, or altering the summary line wording) can silently break the goal condition's ability to detect completion.

**Suggestion:** Treat the summary counts line as an explicit, stable machine contract — document it as such in the script header and keep it invariant regardless of task-count display mode — or add a dedicated --summary machine mode the goal keys on.

## Info (4)

### F-006 [info] Safety-critical instructions (no-attribution, never-merge, caps) repeat consistently and without drift

**File:** `plugin/commands/build.md`  
**Category:** code-quality  
**Effort:** small  
**Status:** open

The 'no attribution lines' / 'never merge' / cap-check wording is repeated verbatim across plugin/commands/build.md, go.md, dev.md, and improve-cycle.md — deliberately, since each file is executed standalone by a fresh headless agent with no shared memory. Checked all four for wording drift: they match. This is the correct call for this architecture (a DRY refactor here would require a shared include mechanism plugin commands don't have, and would risk one file silently going stale relative to the others).

**Suggestion:** No action needed; worth preserving this discipline as new commands are added — diff new safety-instruction copies against build.md's wording before merging.

### F-019 [info] Script-level control flow is four global RALPH_TESTING guard blocks, not a main entrypoint

**File:** `ralph.sh`  
**Category:** architecture  
**Effort:** large  
**Status:** open

Roughly 1,500 of the file's 4,341 lines (arg parsing ~1058-1835, config/path setup ~2876-3033, the main loop ~4097-4341) execute at global scope inside four separately-named 'Guard A/B/C1/C2/D' if-blocks gated on RALPH_TESTING, interleaved with the ~60 function definitions tests/*.bats can source in isolation. This causes no direct failure — bats tests already work around it by sourcing the file with RALPH_TESTING=true, a reasonable pattern. It's evidence that the testability retrofit happened around the monolith rather than the monolith being decomposed, which is the root cause behind why the large functions flagged above (parse_claude_output, generate_summary) remain untested: they aren't reachable as isolated units the guard-block pattern was built to test.

**Suggestion:** If ralph.sh is maintained further before the parity gate, consider extracting the argument-parsing and main-loop bodies into their own functions (main(), parse_args()) so the RALPH_TESTING guards wrap function calls instead of raw script bodies — makes the existing test harness able to reach more of the file directly.

### F-032 [info] Positive: config files parsed with a safe whitelist parser, not sourced

**File:** `ralph.sh:2681`  
**Category:** security  
**Effort:** small  
**Status:** open

safe_load_config parses ralph.conf / ~/.ralph/config line-by-line against an explicit ALLOWED_CONFIG_KEYS whitelist and rejects path values containing shell-command patterns in validate_config_value, rather than sourcing the file. This correctly prevents arbitrary code execution from configuration files.

**Suggestion:** Keep this pattern; when adding new config keys, add matching type/shell-pattern validation and avoid ever eval/source-ing config content.

### F-047 [info] Good pattern: ephemeral runtime state kept as sidecars outside the tracked tree

**File:** `plugin/commands/improve-cycle.md:43`  
**Category:** architecture  
**Effort:** small  
**Status:** open

The improve pipeline consistently isolates ephemeral runtime state from the git working tree so build.md's strict clean-tree preflight stays satisfiable: the selected-findings scratch file is written to $(pwd).selected.json outside the worktree, and pid/log live as <path>.pid/<path>.log sidecars beside the worktree rather than in it.

**Suggestion:** No change needed — preserve this boundary if the sidecar convention is ever consolidated; keep scratch and runtime state out of the worktree.

---

**Open vs addressed:** 47 open, 0 addressed.
