# Native Ralph Plugin — Foundation Implementation Plan (Plan 1 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the working core of the `ralph` Claude Code plugin: feasibility spikes, plugin scaffold, the deterministic evidence script, builder/verifier agents, and the `/ralph:build`, `/ralph:go`, and `/ralph:status` commands — proven against a sandbox repo.

**Architecture:** A Claude Code plugin in `plugin/` whose build command runs as a `/goal`-driven orchestrator in the main session, dispatching one fresh-context `ralph-builder` subagent per spec task, with completion judged by a deterministic evidence script and gated by an adversarial `ralph-verifier` agent before a single push + PR. Spec: `docs/superpowers/specs/2026-07-19-native-ralph-port-design.md`.

**Tech Stack:** Claude Code plugin system (commands/agents as markdown), bash + jq (evidence script), BATS (tests), gh CLI (PRs).

**Follow-on plans (not in this document):** Plan 2 = `/ralph:spec` + `/ralph:dev` + writing-ralph-specs port. Plan 3 = `/ralph:review` + findings backlog + `/ralph:improve` (headless worktree ticks + routine template) + gitignore migration + parity gate.

## Global Constraints

(from the design spec — every task implicitly includes these)

- **PR-gated autonomy:** agents push only `ralph/*` branches, exactly once, at PR time; **never merge**; never write on the default branch.
- **Caps everywhere:** every goal condition includes `or stop after {2×task_count} turns or 2 hours`; no uncapped loops; `--unlimited` is not ported.
- **Non-empty `context.verificationCommands` is a hard preflight requirement** — builds refuse to start without it.
- **Author ≠ evaluator ≠ verifier:** builder and verifier are separate agent contexts; orchestrator never edits source files (hard prompt rule); never weaken tests or CI.
- **Plugin scripts are referenced as `${CLAUDE_PLUGIN_ROOT}/scripts/...`** — bare relative paths won't exist in host repos.
- **POSIX shell required** (macOS/Linux/WSL/git-bash); pure Windows unsupported in v1.
- **Model routing:** `/ralph:go` → sonnet; builder inherits session model; verifier never weaker than builder.
- **Evidence block format is frozen** by Task 4's tests — commands must reference it exactly.
- **No Claude attribution in commit messages.**

## Preconditions

- Base the implementation branch on `add-test-suite` (BATS infra lives there; `main` predates it): `git checkout -b feature/native-ralph-plugin add-test-suite`. If `add-test-suite` has merged by execution time, branch off `main` instead.
- `bats`, `shellcheck`, `jq`, `gh` installed (`brew install bats-core shellcheck jq gh`).

## File Structure

```
.claude-plugin/marketplace.json          # local marketplace so this repo can serve the plugin (Task 3)
plugin/
├── .claude-plugin/plugin.json           # manifest (Task 3)
├── commands/
│   ├── goal-spike.md                    # throwaway spike command (Task 1; deleted in Task 10)
│   ├── status.md                        # /ralph:status (Task 3 stub, Task 12 full)
│   ├── go.md                            # /ralph:go (Task 9)
│   └── build.md                         # /ralph:build (Task 10)
├── agents/
│   ├── ralph-builder.md                 # fresh-context task executor (Task 7)
│   └── ralph-verifier.md                # adversarial completion reviewer (Task 8)
├── scripts/
│   └── ralph-evidence.sh                # deterministic evidence printer (Tasks 4–5)
└── hooks/                               # only if Spike 1 fails (fallback documented in Task 1)
tests/
├── plugin_evidence.bats                 # evidence script tests (Tasks 4–5)
└── make_sandbox.sh                      # throwaway sandbox repo generator (Task 6)
docs/superpowers/spikes/
└── 2026-07-goal-arming.md               # spike outcomes + decisions (Tasks 1–2)
.claude/ralph.json                       # example host config for this repo (Task 13)
plugin/README.md                         # install/config/migration docs (Task 13)
Makefile                                 # lint line gains the evidence script (Task 5)
```

---

### Task 1: Spike — can a plugin command arm `/goal`?

The design's §4 hinges on this. Resolve it before building anything else.

**Files:**
- Create: `plugin/.claude-plugin/plugin.json` (minimal, replaced properly in Task 3)
- Create: `plugin/commands/goal-spike.md`
- Create: `.claude-plugin/marketplace.json` (minimal, finalized in Task 3)
- Create: `docs/superpowers/spikes/2026-07-goal-arming.md`

**Interfaces:**
- Produces: a recorded GO/FALLBACK decision that Task 10 consumes (`build.md` arming mechanism).

- [ ] **Step 1: Create the minimal plugin manifest and marketplace**

`plugin/.claude-plugin/plugin.json`:
```json
{
  "name": "ralph",
  "version": "0.0.1",
  "description": "Native Ralph Loop plugin (spike scaffold)"
}
```

`.claude-plugin/marketplace.json` (repo root):
```json
{
  "name": "ralph-starter",
  "owner": { "name": "Greg Santos" },
  "plugins": [
    { "name": "ralph", "source": "./plugin", "description": "Native Ralph Loop plugin" }
  ]
}
```

- [ ] **Step 2: Write the spike command**

`plugin/commands/goal-spike.md`:
```markdown
---
description: "Spike: verify a command can arm the /goal evaluator"
---
# Goal-arming spike

Arm a session goal now, using the /goal mechanism, with exactly this condition:

"The transcript shows the output of `cat SPIKE_DONE.txt` printing the text
spike-ok — or stop after 3 turns."

After arming it, do NOT create the file this turn. End the turn by saying
"spike armed". On the next turn (if the evaluator drives one), create
SPIKE_DONE.txt containing "spike-ok" and print it with `cat SPIKE_DONE.txt`.
```

- [ ] **Step 3: Run the spike in a scratch session**

```bash
mkdir -p /tmp/ralph-spike && cd /tmp/ralph-spike && git init -q
claude   # interactive scratch session in /tmp/ralph-spike
```
In the session:
```
/plugin marketplace add /Users/g8s/Dev/ralph-starter
/plugin install ralph@ralph-starter
/ralph:goal-spike
```
Observe, then run `/goal` (no args) to check status.

**Success criteria (all three):** `/goal` shows an active goal after the command; the evaluator drives a second turn without user input; the goal clears after `cat SPIKE_DONE.txt` output appears.

- [ ] **Step 4: Record the outcome and decision**

Write `docs/superpowers/spikes/2026-07-goal-arming.md` with: what was run, verbatim observed behavior, and the decision:
- **GO:** Task 10 writes `build.md` to arm `/goal` directly (primary path below).
- **FALLBACK:** Task 10 uses the plugin Stop-hook variant instead — add `plugin/hooks/hooks.json`:
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "If the file .ralph-goal exists in the repo root, read it: it contains a completion condition for an active Ralph build. Judge whether the condition is demonstrated in the transcript. If NOT met, block stopping and state what remains. If met (or no .ralph-goal file exists), allow stopping."
          }
        ]
      }
    ]
  }
}
```
…and `build.md`'s arming step becomes "write the goal condition to `.ralph-goal`; delete the file on completion." Verify the exact prompt-hook schema against current hooks docs during this step and correct the JSON if it differs — record the working form in the spike doc.

- [ ] **Step 5: Commit**

```bash
git add plugin/ .claude-plugin/ docs/superpowers/spikes/
git commit -m "spike: verify plugin command can arm /goal"
```

---

### Task 2: Spike — does the evaluator distinguish tool output from printed text?

Decides whether the evidence contract needs Stop-hook hardening (design §4.4).

**Files:**
- Modify: `docs/superpowers/spikes/2026-07-goal-arming.md` (append findings)

**Interfaces:**
- Produces: recorded HONEST/HARDEN decision consumed by Task 10 (build.md evidence wording) and Plan 3.

- [ ] **Step 1: In the same scratch session, arm a goal keyed to the evidence block**

```
/goal The transcript shows a block starting with === RALPH EVIDENCE === in which
every listed task shows [passed] — or stop after 4 turns.
```

- [ ] **Step 2: Print a fabricated evidence block as plain assistant text (no tool call) and end the turn.** Record whether the evaluator accepts it.

- [ ] **Step 3: Clear and re-arm the same goal; produce the same block via a real tool call** (`echo` heredoc through Bash). Record whether behavior differs.

- [ ] **Step 4: Append both observations and the decision to the spike doc**

- **HONEST (expected):** evaluator can't tell the difference → v1 keeps the prompt contract ("the block must come from running the script") + verifier cross-check; Stop-hook evidence emission goes to Plan 3 hardening.
- **HARDEN:** evaluator does distinguish → note the mechanism; Task 10 wording requires tool-emitted evidence.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/spikes/2026-07-goal-arming.md
git commit -m "spike: record evaluator evidence-discrimination findings"
```

---

### Task 3: Plugin scaffold with `/ralph:status` stub

**Files:**
- Modify: `plugin/.claude-plugin/plugin.json`
- Create: `plugin/commands/status.md` (stub; full version in Task 12)

**Interfaces:**
- Produces: installable plugin namespace `ralph`; commands appear as `/ralph:<name>`.

- [ ] **Step 1: Finalize the manifest**

`plugin/.claude-plugin/plugin.json`:
```json
{
  "name": "ralph",
  "version": "0.1.0",
  "description": "Native Ralph Loop: goal-driven autonomous builds with fresh-context builders, PR-gated autonomy, and deterministic completion evidence.",
  "author": { "name": "Greg Santos" }
}
```

- [ ] **Step 2: Write the status stub**

`plugin/commands/status.md`:
```markdown
---
description: Show Ralph state — active goal, spec progress, open ralph/* PRs
---
# /ralph:status (stub)

Report: "ralph plugin installed — status command not yet implemented (Task 12)".
Then print the plugin version from ${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json.
```

- [ ] **Step 3: Smoke test**

In the `/tmp/ralph-spike` scratch session (or a fresh one): `/plugin install ralph@ralph-starter` (or reinstall), run `/ralph:status`.
Expected: the stub message + version `0.1.0`.

- [ ] **Step 4: Commit**

```bash
git add plugin/
git commit -m "feat(plugin): scaffold ralph plugin manifest and status stub"
```

---

### Task 4: Evidence script — status mode (TDD)

The one deterministic component. Output format frozen here; `build.md` and the goal condition depend on it verbatim.

**Files:**
- Create: `tests/plugin_evidence.bats`
- Create: `plugin/scripts/ralph-evidence.sh`

**Interfaces:**
- Produces: `ralph-evidence.sh <spec.json>` → evidence block on stdout, exit 0. Exit 2 = missing/invalid spec. Exit 3 = missing/empty `context.verificationCommands`. Task 5 adds `--full`.

**Frozen output format (status mode):**
```
=== RALPH EVIDENCE ===
spec: <path-as-given>
tasks: <N> total | <n> passed | <n> in_progress | <n> pending | <n> blocked
T-001 [passed] <title>
T-002 [in_progress] <title>
verifier: <PASS|FAIL|PENDING>
=== END RALPH EVIDENCE ===
```
Task lines: `passed` when `passes == true`, else the task's `status`. When total > 12: print `passed tasks omitted: <n>` instead of the passed task lines; always print non-passed lines. `verifier:` reads top-level `.verifier.verdict // "PENDING"`.

- [ ] **Step 1: Write the failing tests**

`tests/plugin_evidence.bats`:
```bash
#!/usr/bin/env bats

# Tests for plugin/scripts/ralph-evidence.sh (status mode)

EVIDENCE="$BATS_TEST_DIRNAME/../plugin/scripts/ralph-evidence.sh"

make_spec() {
    # make_spec <path> <tasks-json-array> [verifier-json]
    local path="$1" tasks="$2" verifier="${3:-null}"
    jq -n --argjson tasks "$tasks" --argjson verifier "$verifier" '{
        project: "fixture",
        context: { verificationCommands: ["true"] },
        tasks: $tasks
    } + (if $verifier != null then {verifier: $verifier} else {} end)' > "$path"
}

setup() {
    SPEC="$BATS_TEST_TMPDIR/spec.json"
    make_spec "$SPEC" '[
        {"id":"T-001","title":"First","status":"complete","passes":true},
        {"id":"T-002","title":"Second","status":"in_progress","passes":false},
        {"id":"T-003","title":"Third","status":"pending","passes":false},
        {"id":"T-004","title":"Fourth","status":"blocked","passes":false}
    ]'
}

@test "evidence: prints frozen header and footer" {
    run "$EVIDENCE" "$SPEC"
    [[ "$status" -eq 0 ]]
    [[ "${lines[0]}" == "=== RALPH EVIDENCE ===" ]]
    # last-line check without negative indices (macOS default bash is 3.2)
    last_line=$(echo "$output" | tail -n 1)
    [[ "$last_line" == "=== END RALPH EVIDENCE ===" ]]
}

@test "evidence: counts by state" {
    run "$EVIDENCE" "$SPEC"
    [[ "$output" == *"tasks: 4 total | 1 passed | 1 in_progress | 1 pending | 1 blocked"* ]]
}

@test "evidence: one line per task when total <= 12" {
    run "$EVIDENCE" "$SPEC"
    [[ "$output" == *"T-001 [passed] First"* ]]
    [[ "$output" == *"T-002 [in_progress] Second"* ]]
    [[ "$output" == *"T-004 [blocked] Fourth"* ]]
}

@test "evidence: omits passed task lines when total > 12" {
    BIG="$BATS_TEST_TMPDIR/big.json"
    tasks=$(jq -n '[range(0;13) | {id: ("T-" + (. | tostring)), title: "t", status: (if . < 11 then "complete" else "pending" end), passes: (. < 11)}]')
    make_spec "$BIG" "$tasks"
    run "$EVIDENCE" "$BIG"
    [[ "$output" == *"passed tasks omitted: 11"* ]]
    [[ "$output" != *"T-3 [passed]"* ]]
    [[ "$output" == *"T-12 [pending]"* ]]
}

@test "evidence: verifier PENDING when absent, PASS when set" {
    run "$EVIDENCE" "$SPEC"
    [[ "$output" == *"verifier: PENDING"* ]]
    make_spec "$SPEC" '[{"id":"T-001","title":"First","status":"complete","passes":true}]' '{"verdict":"PASS"}'
    run "$EVIDENCE" "$SPEC"
    [[ "$output" == *"verifier: PASS"* ]]
}

@test "evidence: exit 2 on missing or invalid spec" {
    run "$EVIDENCE" "$BATS_TEST_TMPDIR/nope.json"
    [[ "$status" -eq 2 ]]
    echo "not json" > "$BATS_TEST_TMPDIR/bad.json"
    run "$EVIDENCE" "$BATS_TEST_TMPDIR/bad.json"
    [[ "$status" -eq 2 ]]
}

@test "evidence: exit 3 when verificationCommands missing or empty" {
    jq '.context.verificationCommands = []' "$SPEC" > "$BATS_TEST_TMPDIR/empty.json"
    run "$EVIDENCE" "$BATS_TEST_TMPDIR/empty.json"
    [[ "$status" -eq 3 ]]
    jq 'del(.context)' "$SPEC" > "$BATS_TEST_TMPDIR/nocontext.json"
    run "$EVIDENCE" "$BATS_TEST_TMPDIR/nocontext.json"
    [[ "$status" -eq 3 ]]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/plugin_evidence.bats`
Expected: all tests FAIL (script not found / not executable).

- [ ] **Step 3: Implement status mode**

`plugin/scripts/ralph-evidence.sh`:
```bash
#!/usr/bin/env bash
# ralph-evidence.sh — deterministic evidence block for the Ralph goal evaluator.
# Usage: ralph-evidence.sh <spec.json> [--full]
# Exit: 0 evidence printed; 2 missing/invalid spec; 3 no verificationCommands.
set -euo pipefail

SPEC="${1:-}"
MODE="${2:-}"

fail() { echo "ralph-evidence: $2" >&2; exit "$1"; }

[[ -n "$SPEC" && -f "$SPEC" ]] || fail 2 "spec not found: ${SPEC:-<missing>}"
jq empty "$SPEC" 2>/dev/null || fail 2 "spec is not valid JSON: $SPEC"

VERIFY_COUNT=$(jq '(.context.verificationCommands // []) | length' "$SPEC")
[[ "$VERIFY_COUNT" -gt 0 ]] || fail 3 "context.verificationCommands is missing or empty — builds are unverifiable without it"

TOTAL=$(jq '.tasks | length' "$SPEC")
PASSED=$(jq '[.tasks[] | select(.passes == true)] | length' "$SPEC")
IN_PROGRESS=$(jq '[.tasks[] | select(.passes != true and .status == "in_progress")] | length' "$SPEC")
PENDING=$(jq '[.tasks[] | select(.passes != true and .status == "pending")] | length' "$SPEC")
BLOCKED=$(jq '[.tasks[] | select(.passes != true and .status == "blocked")] | length' "$SPEC")

echo "=== RALPH EVIDENCE ==="
echo "spec: $SPEC"
echo "tasks: $TOTAL total | $PASSED passed | $IN_PROGRESS in_progress | $PENDING pending | $BLOCKED blocked"

task_line='.tasks[] | (.id + " [" + (if .passes == true then "passed" else .status end) + "] " + .title)'
if [[ "$TOTAL" -le 12 ]]; then
    jq -r "$task_line" "$SPEC"
else
    echo "passed tasks omitted: $PASSED"
    jq -r ".tasks[] | select(.passes != true) | (.id + \" [\" + .status + \"] \" + .title)" "$SPEC"
fi

# --full verification runs are added in Task 5.

echo "verifier: $(jq -r '.verifier.verdict // "PENDING"' "$SPEC")"
echo "=== END RALPH EVIDENCE ==="
```

Then: `chmod +x plugin/scripts/ralph-evidence.sh`

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/plugin_evidence.bats`
Expected: all 7 PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/plugin_evidence.bats plugin/scripts/ralph-evidence.sh
git commit -m "feat(plugin): evidence script status mode with frozen output format"
```

---

### Task 5: Evidence script — `--full` verification mode (TDD)

**Files:**
- Modify: `tests/plugin_evidence.bats` (append tests)
- Modify: `plugin/scripts/ralph-evidence.sh`
- Modify: `Makefile` (lint line)

**Interfaces:**
- Produces: `ralph-evidence.sh <spec> --full` → additionally one `verify: <cmd> -> exit <code>` line per verification command (all commands run even after a failure; script still exits 0 — failures are data for the evaluator, not script errors).

- [ ] **Step 1: Append failing tests**

Append to `tests/plugin_evidence.bats`:
```bash
@test "evidence --full: reports real exit codes and runs all commands" {
    FULLSPEC="$BATS_TEST_TMPDIR/full.json"
    jq -n '{
        project: "fixture",
        context: { verificationCommands: ["true", "false", "echo hi"] },
        tasks: [{"id":"T-001","title":"First","status":"complete","passes":true}]
    }' > "$FULLSPEC"
    run "$EVIDENCE" "$FULLSPEC" --full
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"verify: true -> exit 0"* ]]
    [[ "$output" == *"verify: false -> exit 1"* ]]
    [[ "$output" == *"verify: echo hi -> exit 0"* ]]
}

@test "evidence --full: verify lines appear before verifier line" {
    FULLSPEC="$BATS_TEST_TMPDIR/full.json"
    jq -n '{
        context: { verificationCommands: ["true"] },
        tasks: []
    }' > "$FULLSPEC"
    run "$EVIDENCE" "$FULLSPEC" --full
    verify_line=$(echo "$output" | grep -n "verify: true" | cut -d: -f1)
    verifier_line=$(echo "$output" | grep -n "verifier:" | cut -d: -f1)
    [[ "$verify_line" -lt "$verifier_line" ]]
}

@test "evidence: status mode runs no verification commands" {
    SLOWSPEC="$BATS_TEST_TMPDIR/slow.json"
    MARKER="$BATS_TEST_TMPDIR/ran-verify"
    jq -n --arg cmd "touch $MARKER" '{
        context: { verificationCommands: [$cmd] },
        tasks: []
    }' > "$SLOWSPEC"
    run "$EVIDENCE" "$SLOWSPEC"
    [[ ! -f "$MARKER" ]]
}
```

- [ ] **Step 2: Run to verify the new tests fail**

Run: `bats tests/plugin_evidence.bats`
Expected: 3 new FAIL, 7 existing PASS.

- [ ] **Step 3: Implement `--full`**

In `ralph-evidence.sh`, replace the `# --full verification runs are added in Task 5.` comment with:
```bash
if [[ "$MODE" == "--full" ]]; then
    while IFS= read -r cmd; do
        code=0
        bash -c "$cmd" >/dev/null 2>&1 || code=$?
        echo "verify: $cmd -> exit $code"
    done < <(jq -r '.context.verificationCommands[]' "$SPEC")
fi
```

- [ ] **Step 4: Run tests to verify all pass**

Run: `bats tests/plugin_evidence.bats`
Expected: 10 PASS.

- [ ] **Step 5: Add the script to lint and run the full check**

Makefile lint target becomes:
```makefile
lint:
	shellcheck -x -s bash ralph.sh plugin/scripts/ralph-evidence.sh
```
Run: `make check`
Expected: shellcheck clean, all BATS suites pass.

- [ ] **Step 6: Commit**

```bash
git add tests/plugin_evidence.bats plugin/scripts/ralph-evidence.sh Makefile
git commit -m "feat(plugin): evidence script --full verification mode"
```

---

### Task 6: Sandbox repo generator

Supervised smoke tests must never run against a real repo (prove against a throwaway target first). This script makes one.

**Files:**
- Create: `tests/make_sandbox.sh`

**Interfaces:**
- Produces: `tests/make_sandbox.sh [dir]` → creates a git repo (default `/tmp/ralph-sandbox`) with `main` as default branch, a trivial project, a 2-task spec at `specs/sandbox.json`, and a working `verify.sh`. Prints the path. Tasks 7–11 consume it.

- [ ] **Step 1: Write the generator**

`tests/make_sandbox.sh`:
```bash
#!/usr/bin/env bash
# Creates a throwaway sandbox repo for supervised ralph plugin smoke tests.
set -euo pipefail
DIR="${1:-/tmp/ralph-sandbox}"
rm -rf "$DIR"
mkdir -p "$DIR/specs"
cd "$DIR"
git init -q -b main

cat > greeting.sh <<'EOF'
#!/usr/bin/env bash
# Prints a greeting. Tasks in specs/sandbox.json extend this file.
echo "hello"
EOF
chmod +x greeting.sh

cat > verify.sh <<'EOF'
#!/usr/bin/env bash
# Verification: greeting.sh must support default and --shout modes as tasks complete.
set -euo pipefail
[[ "$(./greeting.sh)" == "hello" ]] || { echo "FAIL: default greeting"; exit 1; }
if grep -q 'shout' greeting.sh 2>/dev/null; then
    [[ "$(./greeting.sh --shout)" == "HELLO" ]] || { echo "FAIL: shout mode"; exit 1; }
fi
echo "verify OK"
EOF
chmod +x verify.sh

cat > specs/sandbox.json <<'EOF'
{
  "project": "Sandbox greeting",
  "context": {
    "currentState": "greeting.sh prints hello",
    "targetState": "greeting.sh supports --shout and --name flags",
    "constraints": ["bash only", "no new files except tests"],
    "verificationCommands": ["./verify.sh"]
  },
  "tasks": [
    {
      "id": "T-001",
      "title": "Add --shout flag",
      "description": "greeting.sh --shout prints HELLO (uppercase).",
      "acceptanceCriteria": ["./greeting.sh --shout outputs HELLO", "./greeting.sh still outputs hello"],
      "dependsOn": [],
      "status": "pending",
      "passes": false,
      "effort": "small",
      "notes": ""
    },
    {
      "id": "T-002",
      "title": "Add --name flag",
      "description": "greeting.sh --name X prints hello X. Combined with --shout prints HELLO X.",
      "acceptanceCriteria": ["./greeting.sh --name Sam outputs 'hello Sam'"],
      "dependsOn": ["T-001"],
      "status": "pending",
      "passes": false,
      "effort": "small",
      "notes": ""
    }
  ]
}
EOF

git add -A && git commit -qm "init: sandbox project with 2-task spec"
echo "$DIR"
```

- [ ] **Step 2: Verify it works**

Run: `bash tests/make_sandbox.sh && cd /tmp/ralph-sandbox && ./verify.sh && plugin_path=/Users/g8s/Dev/ralph-starter/plugin && "$plugin_path/scripts/ralph-evidence.sh" specs/sandbox.json`
Expected: `verify OK`, then an evidence block showing `2 total | 0 passed | 0 in_progress | 2 pending | 0 blocked`.

- [ ] **Step 3: Commit**

```bash
cd /Users/g8s/Dev/ralph-starter
git add tests/make_sandbox.sh
git commit -m "test: add sandbox repo generator for plugin smoke tests"
```

---

### Task 7: `ralph-builder` agent

**Files:**
- Create: `plugin/agents/ralph-builder.md`

**Interfaces:**
- Consumes: a task card (rendered by `build.md`, Task 10) with fields: task JSON, spec context block, branch name, repo conventions pointer.
- Produces: exactly one commit `feat(<task-id>): <title>` on the current branch; final report format `BUILDER REPORT` (below) that `build.md` parses.

- [ ] **Step 1: Write the agent**

`plugin/agents/ralph-builder.md`:
```markdown
---
name: ralph-builder
description: Fresh-context executor for exactly one Ralph spec task. Implements, verifies, commits, reports. Dispatched by /ralph:build — do not invoke for general work.
---

You are a Ralph builder: you execute EXACTLY ONE task from a spec, then stop.
You receive a task card containing the task JSON (id, title, description,
acceptanceCriteria), the spec's context block, the working branch, and a
pointer to repo conventions (CLAUDE.md). You have no other history — the
task card and the repository state on disk are your entire truth.

Rules — non-negotiable:
1. ONE task only. Do not start other tasks, refactor unrelated code, or fix
   unrelated issues you notice (note them in your report instead).
2. FULL implementation. No stubs, placeholders, TODOs, or minimal versions.
   If the task cannot be fully implemented, say so and fail honestly.
3. Never weaken verification: do not delete, skip, or loosen tests, lint
   rules, or CI config. If an existing test conflicts with the task's
   acceptance criteria, stop and report the conflict.
4. Search before you build: confirm the task isn't already implemented; if
   it is, verify it against the acceptance criteria and report accordingly.
5. Test-first when the repo has a test harness; otherwise verify by
   executing the acceptance criteria literally.
6. Exactly one commit: `feat(<task-id>): <title>` staging only files you
   changed. No attribution lines. Do not push. Do not touch the spec file —
   the orchestrator owns spec state.
7. Verify before claiming: run every acceptance criterion and show real
   output. Evidence before assertions.

End your final message with exactly this block:

BUILDER REPORT
task: <task-id>
result: DONE | FAILED
commit: <short-sha or "none">
verified: <one line per acceptance criterion: PASS/FAIL + the command run>
notes: <conflicts found, follow-ups, anything the orchestrator must know>
```

- [ ] **Step 2: Smoke test in the sandbox**

Run `bash tests/make_sandbox.sh`, open a Claude session in `/tmp/ralph-sandbox`, install the plugin (as in Task 1 Step 3), create a work branch `git checkout -b ralph/sandbox`, then dispatch via the Agent tool with subagent type `ralph-builder` (verify the registered name with the plugin's agent list — record the exact namespaced form, e.g. `ralph:ralph-builder`, in the spike doc) and a task card for T-001 from `specs/sandbox.json`.

Expected: one commit `feat(T-001): Add --shout flag`; `./verify.sh` passes; `./greeting.sh --shout` prints `HELLO`; final message ends with a well-formed `BUILDER REPORT` (result: DONE).

- [ ] **Step 3: Commit**

```bash
git add plugin/agents/ralph-builder.md
git commit -m "feat(plugin): ralph-builder fresh-context task executor agent"
```

---

### Task 8: `ralph-verifier` agent

**Files:**
- Create: `plugin/agents/ralph-verifier.md`

**Interfaces:**
- Consumes: spec path + base ref (dispatched by `build.md` with both).
- Produces: final report format `VERIFIER REPORT` with `verdict: PASS | FAIL`; on PASS the orchestrator writes `{"verifier": {"verdict": "PASS", ...}}` into the spec.

- [ ] **Step 1: Write the agent**

`plugin/agents/ralph-verifier.md`:
```markdown
---
name: ralph-verifier
description: Adversarial completion reviewer for a Ralph build. Tries to REFUTE that the spec is truly complete. Dispatched by /ralph:build — read-only on source.
---

You are the Ralph verifier. A build claims completion. Your job is to REFUTE
that claim. You are not the author; assume the author cut corners until the
diff proves otherwise. You receive a spec path and a base git ref.

Procedure:
1. Read the spec. Diff the branch against the base ref (`git diff <base>...HEAD`).
2. For EVERY task, check each acceptance criterion against the actual diff
   and by executing the criterion where executable. Quote file:line evidence.
3. Hunt the classic frauds: stub/placeholder implementations, hardcoded
   expected outputs, tests deleted/skipped/loosened, verification commands
   modified, acceptance criteria "met" only in comments or docs.
4. Check commit hygiene: every commit touching source files must be a
   builder commit (`feat(T-xxx): ...`). Spec/backlog metadata commits by the
   orchestrator are expected and exempt. Flag anything else.
5. Run the spec's context.verificationCommands yourself; report real exit codes.

You MUST NOT edit any file. You only read, run read-only/verification
commands, and report.

Default to FAIL when uncertain — a false PASS ships broken work behind a
green light; a false FAIL costs one fix turn.

End your final message with exactly this block:

VERIFIER REPORT
verdict: PASS | FAIL
checked: <n> tasks, <n> acceptance criteria
findings: <numbered list: severity, file:line, what is wrong — or "none">
commands: <each verificationCommand -> exit code>
```

- [ ] **Step 2: Smoke test in the sandbox**

In the sandbox session from Task 7 (T-001 built): manually set T-001 `passes:true, status:complete` in the spec, then dispatch `ralph-verifier` with spec path + base ref `main`.
Expected: `VERIFIER REPORT` with `verdict: FAIL` findings mentioning T-002 not implemented — or, if dispatched with a task-scoped instruction to check only T-001, `verdict: PASS`. Both behaviors observed and sane; record any prompt adjustments needed.

- [ ] **Step 3: Commit**

```bash
git add plugin/agents/ralph-verifier.md
git commit -m "feat(plugin): ralph-verifier adversarial completion reviewer agent"
```

---

### Task 9: `/ralph:go` — one-off task command

**Files:**
- Create: `plugin/commands/go.md`

**Interfaces:**
- Consumes: `.claude/ralph.json` `verificationCommands` if present (Task 13 documents the file; the command works without it).
- Produces: a local `ralph/go-<slug>` branch with committed work; `--pr` variant pushes once and opens a PR.

- [ ] **Step 1: Write the command**

`plugin/commands/go.md`:
```markdown
---
description: One-off Ralph task — branch-first, implement, verify, commit; --pr to open a PR
argument-hint: "<what to do>" [--pr]
model: sonnet
---
# /ralph:go — one-off task

Execute this one-off task autonomously: $ARGUMENTS

Procedure — deviations are failures:
1. Preflight: `git status` must be clean; you must NOT be on the default
   branch when committing. Create `ralph/go-<slug>` (slug: lowercase task
   summary, hyphenated, ≤5 words) from the current HEAD.
2. Implement the task fully. No stubs. Follow repo conventions (CLAUDE.md).
   Never weaken tests, lint, or CI.
3. Verify: if `.claude/ralph.json` exists and has `verificationCommands`,
   run them all and show real output. Otherwise run the repo's documented
   test/lint commands. Failures = fix and re-verify, don't report success.
4. Commit `feat: <summary>` (or `fix:`/`chore:` as appropriate). No
   attribution lines. DO NOT push.
5. Only if `--pr` was passed: push the branch once (`git push -u origin
   <branch>`) and `gh pr create` with a body summarizing what/why/how
   verified. Never merge.
6. Report: branch name, commit sha, verification output summary, PR URL if
   created. If you could not complete the task, say exactly what's missing —
   never claim partial work as done.
```

- [ ] **Step 2: Smoke test in the sandbox**

Fresh sandbox (`bash tests/make_sandbox.sh`), session in `/tmp/ralph-sandbox`, plugin installed: `/ralph:go "make greeting.sh exit 2 with usage message on unknown flags"`.
Expected: new branch `ralph/go-...`; `./verify.sh` still passes; one commit; no push (verify: `git log origin/main..HEAD` errors — no remote — and command reported no push attempted).

- [ ] **Step 3: Commit**

```bash
git add plugin/commands/go.md
git commit -m "feat(plugin): /ralph:go one-off task command"
```

---

### Task 10: `/ralph:build` — the goal-driven build engine

The heart. Encodes design §4 verbatim: preflight, goal contract (verifier folded in), turn contract, failure path, completion.

**Files:**
- Create: `plugin/commands/build.md`
- Delete: `plugin/commands/goal-spike.md`

**Interfaces:**
- Consumes: spec JSON (schema per design §1 decision 4); `ralph-evidence.sh` (Tasks 4–5, frozen format); `ralph-builder` + `ralph-verifier` agents and their report blocks (Tasks 7–8); the goal-arming mechanism decided in Task 1.
- Produces: `ralph/<slug>` branch, updated spec (passes/status/attempts/verifier fields), one push + PR (draft `ralph:partial` on terminal stop).

- [ ] **Step 1: Write the command**

`plugin/commands/build.md` (if Task 1 decided FALLBACK, replace the "Arm the goal" step with the `.ralph-goal` file mechanism recorded in the spike doc — everything else is identical):
```markdown
---
description: Goal-driven build from a Ralph spec — one fresh builder per task, verifier-gated PR
argument-hint: <path/to/spec.json> [--continue-branch]
---
# /ralph:build — orchestrator

You are the Ralph build ORCHESTRATOR for the spec at: $ARGUMENTS

You coordinate; you NEVER edit source files yourself. Builders build,
the verifier verifies, you manage state. The only files you may write are
the spec JSON and progress.txt.

## Phase 1 — Preflight (all hard requirements; abort with a clear message on any failure)
1. `git status` clean.
2. Current branch is NOT the default branch, or you create
   `ralph/<slug-from-spec-project>` now. If the branch already exists:
   abort unless `--continue-branch` was passed (then check it out and
   resume — tasks with passes:true are skipped naturally).
3. Spec parses and has a non-empty tasks array.
4. Run `${CLAUDE_PLUGIN_ROOT}/scripts/ralph-evidence.sh <spec>` once.
   Exit 3 means verificationCommands is empty: ABORT — unverifiable
   builds don't run. Exit 2: ABORT — invalid spec.
5. Compute TURN_CAP = 2 × (number of tasks).

## Phase 2 — Arm the goal
Arm /goal with exactly this condition (fill in the values):
"The most recent RALPH EVIDENCE block in the transcript was produced by
running ralph-evidence.sh with --full, shows every task in <spec-path>
passed, every verify line exiting 0, and verifier: PASS — or stop after
<TURN_CAP> turns or 2 hours."

## Phase 3 — Turn contract (repeat every turn until the goal clears)
1. Tree check: if `git status` is dirty (a builder crashed), stash with
   message `ralph-crash-<task-id>` and include the stash reference in the
   next builder's task card as recovery context.
2. Select the next task: status != blocked, passes != true, and every id
   in dependsOn has passes == true. If none exists and not all tasks pass:
   go to Phase 5 (terminal stop).
3. Set the task's status to in_progress in the spec; commit the spec change
   (`chore(<task-id>): start`).
4. Dispatch ONE ralph-builder subagent SYNCHRONOUSLY (never in the
   background — you must not end your turn while a builder runs). Task
   card = task JSON + spec context block + branch name + "conventions:
   CLAUDE.md". Wait for its BUILDER REPORT.
5. On result DONE: verify the builder's commit exists, set passes: true,
   status: complete, copy its notes; commit the spec change
   (`chore(<task-id>): complete`).
   On result FAILED (or a malformed report): increment the task's attempts
   field; if attempts >= 2, set status: blocked with the failure reason in
   notes; commit the spec change.
6. End the turn by running
   `${CLAUDE_PLUGIN_ROOT}/scripts/ralph-evidence.sh <spec>` — with
   `--full` ONLY when the status table would show all tasks passed
   (a completion claim). Print its output verbatim. Do not hand-write
   this block; the goal condition requires it to come from the script.

## Phase 4 — Completion (first turn where all tasks pass)
1. Dispatch ralph-verifier (spec path + base ref = default branch).
2. verdict FAIL: for each finding, treat it as a fix task — dispatch a
   builder per finding (findings count against remaining turns). Then
   re-verify. Never argue with the verifier; fix or surface.
3. verdict PASS: write {"verifier": {"verdict": "PASS", "date": <today>,
   "summary": <one line>}} into the spec; commit; run the evidence script
   with --full; print it.
4. Rebase onto the default branch. Conflicts: STOP — push and open a
   draft PR titled "ralph: <project> (conflicts)" describing them. Never
   auto-resolve.
5. Clean rebase: push ONCE (`git push -u origin <branch>`), then
   `gh pr create` — title "ralph: <project>", body = evidence block +
   task table + verifier summary. NEVER merge. Report the PR URL.

## Phase 5 — Terminal stop (cap hit, or all remaining tasks blocked)
Push the branch once and open a DRAFT PR labeled `ralph:partial` — title
"ralph: <project> (partial)", body = the latest evidence block + which
tasks are blocked/pending and why. Partial work is always surfaced, never
abandoned. Report honestly: this is a partial result, not a completion.
```

- [ ] **Step 2: Delete the spike command**

```bash
git rm plugin/commands/goal-spike.md
```

- [ ] **Step 3: Commit**

```bash
git add plugin/commands/build.md
git commit -m "feat(plugin): /ralph:build goal-driven orchestrator command"
```

---

### Task 11: Supervised end-to-end smoke run of `/ralph:build`

**Files:** none created in this repo (sandbox only; observations appended to the spike doc)

- [ ] **Step 1: Happy path.** Fresh sandbox with a remote: `bash tests/make_sandbox.sh && cd /tmp/ralph-sandbox && git remote add origin "$(mktemp -d)" && git init -q --bare "$(git remote get-url origin)"`. Session in the sandbox, plugin installed, run `/ralph:build specs/sandbox.json`. Success checklist (all must hold):
  - Both tasks completed by builder subagents (two `feat(T-00x):` commits + spec `chore` commits).
  - Evidence block printed by the script every turn; `--full` only on the completion turn.
  - Verifier dispatched; verdict PASS written into the spec.
  - Exactly one push, at PR time (`git -C "$(git remote get-url origin)" log ralph/sandbox-greeting --oneline` shows history only after completion; gh pr create fails against a local bare remote — expect the command to report the PR step attempted and surface the gh error honestly, not claim success).
  - Zero writes on `main` (`git log main` unchanged).

- [ ] **Step 2: Failure path.** Regenerate the sandbox; edit `specs/sandbox.json` to make T-002 unsatisfiable (acceptance criterion: `./greeting.sh --name Sam outputs 'goodbye Sam'` while constraints forbid changing "hello" semantics — contradiction). Run `/ralph:build specs/sandbox.json`. Checklist:
  - T-001 completes; T-002 fails twice → `status: blocked`, attempts 2, reason in notes.
  - Terminal stop → draft/partial PR path attempted with the evidence table; no completion claim anywhere in the transcript.

- [ ] **Step 3: Record observations** (append to `docs/superpowers/spikes/2026-07-goal-arming.md`): turn counts, evaluator behavior, any prompt adjustments made to build.md/agents — then commit those adjustments:

```bash
git add plugin/ docs/superpowers/spikes/
git commit -m "test: e2e sandbox smoke runs of /ralph:build; prompt adjustments"
```

---

### Task 12: `/ralph:status` — full implementation

**Files:**
- Modify: `plugin/commands/status.md`

**Interfaces:**
- Consumes: evidence script; `gh` CLI; specs directory.

- [ ] **Step 1: Replace the stub**

`plugin/commands/status.md`:
```markdown
---
description: Show Ralph state — active goal, spec progress, open ralph/* PRs, worktrees
---
# /ralph:status

Report Ralph state, read-only (change nothing):

1. Goal: report the active goal if any (via /goal status).
2. Specs: for each specs/*.json (skip example.json), run
   `${CLAUDE_PLUGIN_ROOT}/scripts/ralph-evidence.sh <spec>` and show the
   counts line. Note: exit 3 means the spec lacks verificationCommands —
   report it as "unbuildable (no verificationCommands)".
3. PRs: `gh pr list --state open --json headRefName,title,url,isDraft`
   filtered to branches starting with ralph/ (report "gh unavailable" if
   the command fails; don't guess).
4. Branches/worktrees: `git branch --list 'ralph/*'` and
   `git worktree list` entries containing "ralph".
Summarize in a short table. No recommendations unless something is stuck
(blocked tasks, draft partial PRs, conflicts).
```

- [ ] **Step 2: Smoke test** — in this repo's session: `/ralph:status`. Expected: reports no active goal, `specs/example.json` skipped, whatever `ralph/*` branches/PRs exist (likely none), no errors.

- [ ] **Step 3: Commit**

```bash
git add plugin/commands/status.md
git commit -m "feat(plugin): /ralph:status full implementation"
```

---

### Task 13: Config example + README

**Files:**
- Create: `.claude/ralph.json`
- Create: `plugin/README.md`

**Interfaces:**
- Produces: the host-config contract consumed by `/ralph:go` (Task 9) and, in Plans 2–3, by spec/improve commands.

- [ ] **Step 1: Write this repo's own config**

`.claude/ralph.json`:
```json
{
  "verificationCommands": ["make check"],
  "sourceDirs": ["ralph.sh", "plugin/"],
  "defaultBudgets": {
    "buildTurnsFactor": 2,
    "buildHours": 2,
    "improveTurns": 15,
    "improveHours": 1,
    "improveUsd": 10
  },
  "reviewFocus": ["code-quality", "test-coverage", "architecture", "security", "bug"],
  "models": { "go": "sonnet", "builder": "inherit", "verifier": "inherit" },
  "artifactPaths": { "specs": "specs", "reviewOutput": "review-output" }
}
```
Note: `.gitignore` currently ignores `.claude/*` except skills — add `!.claude/ralph.json` beneath the existing `!.claude/skills/**` lines.

- [ ] **Step 2: Write the README**

`plugin/README.md` — sections, each 3–10 lines, content drawn from the design spec (§2 command table, §7 artifact tracking table, §8 config/migration):
1. What it is (one paragraph: native port of the Ralph Loop; bash `ralph.sh` remains until the parity gate passes).
2. Install: `/plugin marketplace add <this-repo-path-or-url>` then `/plugin install ralph@ralph-starter`.
3. Commands: table of `/ralph:go|build|status` with one-line descriptions (mark spec/dev/review/improve "coming in Plans 2–3").
4. Config: the `.claude/ralph.json` fields above, one line each; `verificationCommands` called out as required for builds.
5. Artifact tracking: specs and findings must be git-tracked (worktrees and fresh clones only see tracked files); gitignore migration one-liner for host repos.
6. Guardrails: PR-gated, branch-first, caps, never merges; POSIX shell required (no pure-Windows support in v1).

- [ ] **Step 3: Update .gitignore for the config file**

Append after the `!.claude/skills/**` line:
```
!.claude/ralph.json
```
Verify: `git check-ignore -v .claude/ralph.json` returns nothing (not ignored).

- [ ] **Step 4: Run the full check**

Run: `make check`
Expected: lint clean, all BATS suites pass.

- [ ] **Step 5: Commit**

```bash
git add .claude/ralph.json plugin/README.md .gitignore
git commit -m "feat(plugin): host config example, README, gitignore exception"
```

---

## Self-review notes (completed during planning)

- **Spec coverage:** §4 preflight/goal/turn/failure/completion → Task 10; §4.4 evidence → Tasks 4–5; agents → Tasks 7–8; `/ralph:go`/`status` → Tasks 9/12; §9 spikes → Tasks 1–2; sandbox-first proving → Tasks 6/11. §5 improve, §7 full gitignore migration, spec/dev commands, routine template, parity gate → Plans 2–3 by scope decision.
- **Consistency:** evidence format identical in Task 4 tests, Task 4 implementation, and Task 10's goal condition; report block names (`BUILDER REPORT`/`VERIFIER REPORT`) match between Tasks 7/8 and Task 10; `attempts`/`verifier` spec fields consistent across Tasks 8/10 and the evidence script.
- **Known open point carried from the spec:** exact namespaced agent-type string for plugin agents is discovered and recorded in Task 7 Step 2 (spike doc), consumed by Task 10.
