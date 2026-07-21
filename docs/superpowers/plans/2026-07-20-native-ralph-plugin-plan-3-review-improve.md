# Native Ralph Plugin — Review & Improve Flywheel Implementation Plan (Plan 3 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the auto-improve flywheel — `/ralph:review` (parallel category subagents → tracked findings backlog), `/ralph:improve` (headless, worktree-isolated review→select→fix-spec→mini-build→PR cycles with local `/loop` and cloud routine triggers) — plus the gitignore migration and the design-§9 parity gate evidence.

**Architecture:** `/ralph:review` fans one read-only subagent per focus category out in parallel and merges results into `review-output/findings.json` (schema + `addressed` field) with a regenerated report. `/ralph:improve` is a *launcher*: busy-checks, creates a fresh `/tmp` worktree on a `ralph/improve-<ts>` branch, carries the Stop-hook settings duplicate in, and spawns a capped headless `claude -p "/ralph:improve-cycle"` inside it. The inner cycle composes shipped machinery by reference — review.md → selection → spec.md `--from-findings` → build.md (already on the work branch, spec committed by step 3a) — then reconciles the backlog into the PR. Spec: `docs/superpowers/specs/2026-07-19-native-ralph-port-design.md` §5, §7, §9.

**Tech Stack:** Claude Code plugin system (commands/skills as markdown), git worktrees, bash + jq, plain-`&` capped headless spawns, gh CLI, BATS/shellcheck (`make check`).

## Global Constraints

(from the design spec, the Plans 2–3 handoff platform facts, and Plans 1–2 execution — every task implicitly includes these)

- **PR-gated autonomy:** agents push only `ralph/*` branches; **never merge**; never write on the default branch. No attribution lines in commits or PR titles/bodies.
- **Single push at PR time**, with exactly one sanctioned exception introduced by this plan (approved at plan sign-off): the improve cycle's backlog-reconciliation commit is pushed to the *already-open* PR branch as a documented one-commit follow-up (Task 6, Phase I-5). Nothing else ever pushes twice.
- **Caps on every headless spawn:** `--max-turns` AND `--max-budget-usd`, always. The improve tier defaults are 15 turns / $10 (config `defaultBudgets.improveTurns`/`improveUsd`); `improveHours` is documented as approximated by the turn cap (no wall-clock CLI flag exists).
- **No orphanable processes** (user directive 2026-07-20 — orphaned `ralph.sh` background runs under subagents would not die and kept committing/pushing): never `nohup`, `disown`, or `setsid` — in commands, docs, or smoke tests. Background execution uses the harness's managed background facility (a plain `&` child at most), every spawn's PID is recorded in its sidecar, `/ralph:status` can see it, `kill <pid>` can stop it, and smoke tasks kill anything still alive before finishing. Prefer native primitives (`/loop`, `/schedule`, `/goal`, worktrees, subagents) over hand-rolled process machinery wherever they fit.
- **The improve cycle never runs in a user's checkout:** it aborts unless the current branch matches `ralph/improve-*`; the launcher fails a tick that can't get its worktree — no fallback to the session's checkout.
- **Never auto-delete a crashed tick's work:** a worktree with a pid file whose process is dead is surfaced with inspect/remove instructions, never removed automatically. Only a *finished* tick's worktree (no pid file, clean `git status`) may be auto-pruned.
- **All smoke tests run in throwaway sandboxes** created by `tests/make_sandbox.sh` — never headless `claude` against ralph-starter itself (the one exception, Task 10, requires an explicit user go-ahead recorded at execution time). Never `--dangerously-skip-permissions`.
- **Proven headless invocation shape** (platform facts 3–4): `--plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project --permission-mode acceptEdits --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep"` (drop `Agent` for runs that must not dispatch subagents).
- **Plugin hooks do not fire under `--setting-sources project`** (platform fact 2, re-confirmed 2026-07-20): every headless context must carry the Stop-hook duplicate in `.claude/settings.json` — the sandbox generator copies it, Task 2 tracks it in this repo, the improve launcher copies it into worktrees that lack it.
- **Evaluator provenance is opt-in** (platform fact 5): never weaken the `.ralph-goal` condition wording; the verifier cross-check stays mandatory.
- **Slash commands cannot be invoked from assistant output** (platform fact 1): composition = Read the other command file from `${CLAUDE_PLUGIN_ROOT}` and execute its procedure.
- **Plugin agents/skills register namespaced** (`ralph:ralph-builder`, `ralph:writing-ralph-specs`); parse agent output by SEEKING marker lines.
- **The evidence block format is frozen** by `tests/plugin_evidence.bats` — nothing here may change `ralph-evidence.sh` output.
- **`make check` and `claude plugin validate ./plugin` must be green after every task.**

## Preconditions

- On branch `feature/ralph-plugin-plan-3` (created off `main` at Plan 2's merge, `4c40767`).
- `bats`, `shellcheck`, `jq`, `gh` installed.
- Plan 2 merged: `/ralph:spec` (`--from-findings` proven), `/ralph:dev`, build.md step 3a, `plugin/skills/writing-ralph-specs/`, sandbox fixtures (findings F-001 medium bug / F-002 low test-coverage / F-003 info, `.claude/ralph.json`, Stop-hook settings copy).

## Decisions locked at plan approval

1. **Backlog-in-PR mechanism:** after `build.md` opens the PR, the cycle commits `addressed: <PR#>` to the backlog and pushes that one follow-up commit to the same open PR branch (the chicken-and-egg alternative — a branch-name marker — leaves references that rot after merge). This is the single sanctioned post-PR push, named in Global Constraints.
2. **This repo tracks `.claude/settings.json`** (a byte copy of `plugin/hooks/hooks.json`): worktrees and fresh clones then materialize the Stop-hook safety net automatically (platform fact 2). Cost: contributors' interactive sessions run the hook on every Stop (it allows immediately when no `.ralph-goal` exists), and sessions with the plugin installed evaluate it twice. Accepted.
3. **No detached spawns — harness-visible children only** (user directive): the launcher's spawn is a plain `&` child run through the Bash tool's background facility — no nohup/disown/setsid — with its PID captured in the sidecar, killable, and surfaced by `/ralph:status`. Task 1 probe (c) measures whether such a child outlives a headless parent session; fire-and-forget semantics are documented per that verdict (fire-and-forget from a persistent `/loop` session; `--wait` for routines and one-shot headless contexts). If the probe shows children die at session end, that is the desired no-orphan property and gets documented as such, not treated as a defect.
3a. **Native-first probe:** platform fact 1 forbids *assistant*-side `/goal` arming, but the goal-arming spike records the SDK-side gate as open ("the SDK's host code passing `/goal …` as the prompt argument"). Task 1 probe (d) tests arming the real native `/goal` via a headless `-p "/goal …"` prompt. GO → Task 7's spawn wraps the cycle in a native `/goal` condition (native evaluator; the settings-hook duplication becomes belt-and-suspenders for that spawn); NO-GO → the `.ralph-goal` + settings-hook mechanism stands, and the finding is recorded for v2.
4. **Config wiring:** `reviewFocus`, `sourceDirs`, `defaultBudgets` (build factors + improve caps + `improveFindings` N, added to the example config) go live. `models` and `artifactPaths` stay **reserved** — no new model routing is introduced, and artifact-path indirection is deferred until after the parity gate (spec.md/build.md hardcode `specs/`; changing that now would churn proven texts for no v1 consumer).
5. **Routine template inlines the launcher's five-line spawn as fallback, never the cycle:** if `/ralph:improve` doesn't resolve in the routine's fresh clone, the template falls back to `git worktree add` + the documented headless `claude -p "/ralph:improve-cycle" --plugin-dir <clone>/plugin …` invocation — the cycle's *instructions* always come from the clone's own `plugin/` directory, so there is no drift; hosts without a tracked plugin dir get an honest STOP.
6. **Parity-gate scope:** Task 9 produces the evidence record for design §9's four build-engine points plus the supervised-run tallies for spec/review/improve modes. Deprecating bash `ralph.sh` remains a human decision made on that record, not an act of this plan.
7. **Plan-2 riding minors stay as logged** (spec.md "(3a or 3b)" wording, build.md 3a commit-message label): the final reviewer triaged them non-blocking, and none of this plan's tasks need to touch those exact sentences.

## File Structure

```
.gitignore                                  # migration (Task 2)
.claude/settings.json                       # NEW, tracked Stop-hook duplicate (Task 2)
.claude/ralph.json                          # +defaultBudgets.improveFindings (Task 8)
plugin/
├── .claude-plugin/plugin.json              # version 0.2.0 → 0.3.0 (Task 8)
├── skills/reviewing-codebase/SKILL.md      # ported skill + addressed field (Task 3)
├── commands/
│   ├── review.md                           # /ralph:review (Task 4)
│   ├── build.md                            # config caps + turn-line timestamp (Task 5)
│   ├── improve-cycle.md                    # inner unit of work (Task 6)
│   ├── improve.md                          # launcher (Task 7)
│   └── status.md                           # improve-tick reporting (Task 7)
├── routines/improve-nightly.md             # cloud trigger template (Task 8)
└── README.md                               # review/improve docs, config status (Task 8)
docs/superpowers/spikes/
├── 2026-07-improve-mechanics.md            # Task 1 spike; Tasks 4/6/7 smoke appendices
└── 2026-07-parity-gate.md                  # Task 9 gate record
```

---

### Task 1: Spike — worktree headless runs, parallel agents, background-child semantics, native /goal

Four unverified platform assumptions gate this plan: (a) a headless `claude -p` inside a **git worktree** behaves normally (plugin loads via `--plugin-dir`, commits land on the worktree branch, the main checkout is untouched); (b) a command-driven headless session can dispatch **multiple Agent calls in parallel** (one assistant message, N tool_use blocks) — review.md's fan-out depends on it; (c) what happens to a **plain `&` background child** (no nohup — forbidden) when the Bash call and then the spawning session end: does it survive to completion (needs the pid-sidecar kill switch) or die with the session (the desired no-orphan property; fire-and-forget then requires a persistent session) — the launcher's documentation depends on the truth; (d) can a headless spawn arm the **real native `/goal`** via `-p "/goal …"` (the SDK-side gate the goal-arming spike records as open), and does the armed evaluator then drive autonomous work toward the condition?

**Files:**
- Create: `docs/superpowers/spikes/2026-07-improve-mechanics.md`

**Interfaces:**
- Produces: four recorded verdicts. (a) fail → STOP the plan, check in with the user (improve's isolation story collapses). (b) fail → review.md falls back to sequential dispatch (record the wording change Task 4 must apply: "dispatch the category subagents one at a time"). (c) either outcome is workable — the verdict routes Task 7's fire-and-forget documentation and L1's smoke expectations (children-die → fire-and-forget documented as requiring a live `/loop` session; children-survive → pid sidecar is the mandatory kill switch and L1 adds a mid-flight `kill` probe). (d) GO → Task 7 wraps the spawn in a native `/goal` condition; NO-GO → `.ralph-goal` + settings-hook stands, finding recorded for v2.

- [ ] **Step 1: Sandbox + worktree probe (assumption a)**

```bash
bash tests/make_sandbox.sh /tmp/ralph-sb-p3spike && cd /tmp/ralph-sb-p3spike
git worktree add /tmp/ralph-sb-p3spike-wt -b ralph/improve-spike main
cd /tmp/ralph-sb-p3spike-wt
claude -p "Create a file spike-wt.txt containing exactly 'wt-ok', run ./verify.sh, commit only spike-wt.txt with message 'chore: worktree spike probe', print git log --oneline -1 and git branch --show-current, then stop." \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 8 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit" \
  --max-budget-usd 3 > /tmp/p3-spike-worktree.jsonl 2>&1
```
(Bash tool timeout: 300000.) Verify, with real output: the init event's `slash_commands` includes `ralph:build` (plugin loaded in the worktree); `git -C /tmp/ralph-sb-p3spike-wt log --oneline -1` shows the probe commit on `ralph/improve-spike`; `git -C /tmp/ralph-sb-p3spike log --oneline` shows main's history unchanged and `git -C /tmp/ralph-sb-p3spike status --porcelain` clean.

- [ ] **Step 2: Parallel Agent dispatch probe (assumption b)**

```bash
cd /tmp/ralph-sb-p3spike
claude -p "Dispatch exactly two general-purpose subagents IN PARALLEL — a single assistant message containing two Agent tool calls. Subagent one: run a Bash command that prints AGENT-ONE-OK and return that marker as your entire final message. Subagent two: same with AGENT-TWO-OK. After both return, print both markers on separate lines and stop." \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose \
  --max-turns 8 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash" \
  --max-budget-usd 3 > /tmp/p3-spike-parallel.jsonl 2>&1
```
Verify structurally: one assistant message contains BOTH Agent tool_use blocks (same `message.id` / same content array — not two sequential messages), and both markers appear in tool_results. Record PARALLEL-OK or SEQUENTIAL-ONLY (if the harness serialized them, note whether both still completed — that decides Task 4's fallback wording).

- [ ] **Step 3: background-child semantics probe (assumption c) — NO nohup**

The question has two layers: does a plain `&` child survive (i) its spawning Bash tool call ending, and (ii) the spawning *session* ending? Test (ii) directly — it's the layer that decides orphan behavior. Run a headless OUTER session whose only job is to spawn an INNER background child and exit immediately:
```bash
cd /tmp/ralph-sb-p3spike && rm -f bg-ok.txt bg-probe.log bg-probe.pid
claude -p "Run exactly this Bash command, print its output, and stop immediately without waiting for the background process: claude -p 'Wait 30 seconds using sleep 30, then write a file bg-ok.txt containing exactly ok, then stop.' --setting-sources project --max-turns 4 --permission-mode acceptEdits --allowedTools 'Bash,Read,Write,Edit' --max-budget-usd 2 > bg-probe.log 2>&1 & echo \$! > bg-probe.pid; cat bg-probe.pid" \
  --setting-sources project \
  --max-turns 4 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit" \
  --max-budget-usd 2 > /tmp/p3-spike-bg-outer.jsonl 2>&1
echo "outer exited"; sleep 5; kill -0 "$(cat bg-probe.pid)" 2>/dev/null && echo CHILD-SURVIVES || echo CHILD-DIED
```
(Bash timeout 180000.) Then poll `kill -0` every ~15s until EXITED (or confirm immediate death); check whether `bg-ok.txt` eventually appears. Record the verdict: **CHILD-SURVIVES** (pid sidecar = mandatory kill switch; fire-and-forget works from one-shot sessions but MUST stay killable and status-visible) or **CHILD-DIED** (the no-orphan property holds natively; fire-and-forget requires a persistent session such as `/loop`'s; routines use `--wait`). If the child survives and is still alive at probe end, `kill` it and confirm it died — the kill switch is part of the evidence.

- [ ] **Step 4: native /goal arming probe (assumption d)**

```bash
cd /tmp/ralph-sb-p3spike && rm -f GOAL_OK.txt
claude -p "/goal The file GOAL_OK.txt exists in the current directory containing exactly the text goal-ok, produced by actually executing a command (visible as a tool_result in the transcript), not merely written as plain assistant text — or stop after 4 turns." \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 8 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit" \
  --max-budget-usd 3 > /tmp/p3-spike-goal.jsonl 2>&1
```
(Bash timeout 300000.) Judge from the stream: did the harness accept `/goal` as a command (vs. treating it as an ordinary prompt)? Did the evaluator drive one or more autonomous turns (goal-evaluator feedback events / `num_turns` > 1 without user input) ending with `GOAL_OK.txt` created by a real command? Verdict **GO** (native /goal is armable headlessly and drives work — Task 7 may wrap the spawn) or **NO-GO** (record exactly what happened instead). This probe must not weaken fact 1: it says nothing about *assistant*-side arming, which remains impossible.

- [ ] **Step 5: Record verdicts and clean up**

Write `docs/superpowers/spikes/2026-07-improve-mechanics.md`: date, the four questions, exact commands, verbatim key evidence (init-event fragment, the parallel tool_use structure, child-survival poll transcript, the /goal stream behavior), four decisions with the fallback routing from Interfaces above. Then:
```bash
cd /tmp/ralph-sb-p3spike && git worktree remove --force /tmp/ralph-sb-p3spike-wt
cd / && rm -rf /tmp/ralph-sb-p3spike
```
Keep all `/tmp/p3-spike-*.jsonl` captures.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/spikes/2026-07-improve-mechanics.md
git commit -m "spike: worktree headless runs, parallel agents, background-child semantics, native /goal"
```

---

### Task 2: Gitignore migration + tracked Stop-hook settings

Design §7: specs and the findings backlog must be **tracked** — worktrees and fresh clones only materialize tracked files, which is exactly where headless improve runs live. Also tracks the Stop-hook settings duplicate (Decision 2) so those same contexts get the safety net without copying.

**Files:**
- Modify: `.gitignore`
- Create: `.claude/settings.json` (byte copy of `plugin/hooks/hooks.json`)

**Interfaces:**
- Produces: `specs/*.json`, `review-output/*`, and `.claude/settings.json` are trackable in this repo. Task 7's launcher still carries the copy-if-absent fallback for host repos that don't track settings.

- [ ] **Step 1: Edit .gitignore**

Remove these three lines (leave `archive/`, `progress.txt`, `plans/*`, `.ralph-goal`, and everything else untouched):
```
review-output/
specs/*
!specs/example.json
```
Add one line immediately after the existing `!.claude/ralph.json` line:
```
!.claude/settings.json
```

- [ ] **Step 2: Create the tracked settings hook**

```bash
cp plugin/hooks/hooks.json .claude/settings.json
```

- [ ] **Step 3: Verify tracking state**

```bash
git check-ignore -v specs/anything.json review-output/findings.json .claude/settings.json; echo "exit=$?"
diff .claude/settings.json plugin/hooks/hooks.json && echo HOOK-COPY-OK
make check
```
Expected: `git check-ignore` matches nothing (exit=1 — none ignored), `HOOK-COPY-OK`, gates green. Also confirm `.ralph-goal` and `progress.txt` are STILL ignored: `git check-ignore .ralph-goal progress.txt` exits 0.

- [ ] **Step 4: Commit**

```bash
git add .gitignore .claude/settings.json
git commit -m "chore: track specs, review-output, and the Stop-hook settings duplicate"
```

---

### Task 3: Port the reviewing-codebase skill into the plugin

**Files:**
- Create: `plugin/skills/reviewing-codebase/SKILL.md`

**Interfaces:**
- Consumes: content adapted from `.claude/skills/reviewing-codebase/SKILL.md`.
- Produces: the skill review.md (Task 4) Reads from `${CLAUDE_PLUGIN_ROOT}/skills/reviewing-codebase/SKILL.md`. Section headings referenced by name downstream: **"Findings JSON Schema"**, **"Severity Rubric"**, **"Category Analysis Techniques"**, **"Accumulation and Deduplication Rules"** — keep them exact.

Adaptations (deliberate): `/ralph:review` replaces `./ralph.sh review`; the `addressed` field joins the schema; the "Fix Spec Generation Rules" section becomes a pointer to the writing-ralph-specs skill (Plan 2 moved those rules there — no duplication); the bash "Workflow" and "Host Project Mode" sections are dropped.

- [ ] **Step 1: Write the skill**

`plugin/skills/reviewing-codebase/SKILL.md`:
````markdown
---
name: reviewing-codebase
description: Structured codebase analysis producing a tracked JSON findings backlog and a Markdown report. Used by /ralph:review and the /ralph:improve cycle; also directly when reviewing code quality, security, test coverage, or architecture.
---

# Reviewing Codebase

Perform structured codebase analysis for `/ralph:review`. Produces JSON
findings (`review-output/findings.json` — the tracked source of truth)
and a regenerated Markdown report. Fix-specs are generated from findings
by `/ralph:spec --from-findings`, following the writing-ralph-specs
skill's "Fix-specs from review findings" rules — this skill defines what
a good finding is; that one defines how findings become tasks.

## Findings JSON Schema

Each finding is an object in the `findings` array:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier (e.g., "F-001") |
| `category` | string | Yes | One of: `security`, `bug`, `code-quality`, `test-coverage`, `architecture` |
| `severity` | string | Yes | One of: `critical`, `high`, `medium`, `low`, `info` |
| `file` | string | Yes | File path relative to project root |
| `line` | number | No | Line number (omit for file-level findings) |
| `title` | string | Yes | Short finding title (max 80 chars) |
| `description` | string | Yes | Detailed explanation of the issue |
| `suggestion` | string | Yes | Recommended fix or improvement |
| `effort` | string | Yes | One of: `small`, `medium`, `large` |
| `references` | string[] | No | Links to relevant docs, OWASP IDs, etc. |
| `addressed` | number\|string\|null | No | `null` (or absent — treated as null) while open; the fix PR's number once an improve cycle delivers one; `"stale-<date>"` when revalidation finds the symptom already gone. Set by improve cycles. Reviews must PRESERVE existing values, never clear or overwrite them. |

### Findings File Structure

```json
{
  "project": "Project Name",
  "reviewDate": "2026-07-20",
  "scope": {
    "target": "src/*",
    "diffBase": "",
    "focus": ["code-quality", "test-coverage", "architecture", "security"]
  },
  "summary": {
    "total": 0,
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0,
    "info": 0
  },
  "findings": []
}
```

## Severity Rubric

| Severity | Criteria | Examples |
|----------|----------|----------|
| **critical** | Exploitable vulnerability, data loss risk, or production-breaking bug | SQL injection, unvalidated file deletion, infinite loop in request handler |
| **high** | Security gap, likely bug, or missing critical error handling | Missing auth check, unhandled null dereference, race condition in state update |
| **medium** | Code smell, moderate risk, coverage gap in important paths | Complex function (>50 LOC), untested error paths, tight coupling between modules |
| **low** | Style issue, minor improvement, documentation gap | Inconsistent naming, missing docs on exported function, magic number |
| **info** | Observation, positive pattern, or architectural note | Well-structured module, potential future consideration, pattern to replicate |

**Severity calibration rules:**
- When uncertain between two levels, pick the lower one (avoid over-alarming)
- `critical` requires demonstrated exploitability or data-loss path
- `info` findings should highlight good patterns, not just fill space
- A finding without a clear `suggestion` should not be `high` or `critical`

## Category Analysis Techniques

### Security
- **OWASP Top 10**: Injection, broken auth, sensitive data exposure, XXE, broken access control, misconfiguration, XSS, insecure deserialization, known vulnerabilities, insufficient logging
- **Input validation**: Trace user inputs through to database/filesystem/exec calls
- **Auth/authz**: Check route protection, token validation, permission boundaries
- **Secrets**: Scan for hardcoded credentials, API keys, connection strings
- **Dependencies**: Flag known CVEs in package/lock files

### Bug
- **Error handling**: Uncaught exceptions, swallowed errors, missing cleanup paths
- **Race conditions**: Shared mutable state, async operations without proper guards
- **Type safety**: Implicit any, unchecked casts, null/undefined access patterns
- **Edge cases**: Off-by-one, empty arrays, boundary values, encoding issues
- **Resource leaks**: Unclosed connections, listeners never removed

### Test Coverage
- **Untested paths**: Error branches, edge cases, boundary conditions
- **Mock quality**: Mocks that don't match real behavior, over-mocking
- **Missing integration tests**: API routes, middleware chains, persistence
- **Assertion quality**: Tests that pass but don't verify meaningful behavior
- **Flaky patterns**: Time-dependent, order-dependent, non-deterministic tests

### Architecture
- **Coupling**: Modules with excessive cross-dependencies, god objects
- **Layering violations**: UI calling persistence directly, business logic in routes
- **Single responsibility**: Files/functions doing too many things
- **Abstraction quality**: Premature, leaky, or missing abstractions
- **Consistency**: Inconsistent patterns across similar modules

### Code Quality
- **Readability**: Deep nesting, unclear names, dead code
- **Duplication**: Verbatim logic blocks repeated instead of extracted
- **Complexity**: Functions beyond ~50 LOC, boolean-flag parameters, hidden side effects
- **Conventions**: Deviations from the repo's own documented style (CLAUDE.md)

## Anti-Patterns (Do NOT Do These)

**Vague findings:**
```json
{
  "title": "Code could be improved",
  "description": "This code has some issues",
  "suggestion": "Refactor to be better"
}
```

**False positives:**
- Flagging intentional patterns as bugs (e.g., catch-all error handlers that log and re-throw)
- Reporting missing tests for trivial getters/setters
- Flagging framework conventions as architectural violations

**Wrong severity:**
- `critical` for a style issue; `low` for an actual vulnerability; `high` for an info-level observation

**Duplicate findings:**
- Reporting the same pattern in every file instead of one finding with "affects N files"
- Multiple findings for the same root cause (report the root cause once)

## Accumulation and Deduplication Rules

When merging new analysis into an existing `findings.json`:

1. **Read existing findings first** — before analyzing, know what's already recorded
2. **Deduplicate by root cause** — if the same pattern appears in 5 files, ONE finding listing all affected files
3. **Never re-report an existing finding** — same root cause, same file ⇒ it's already in the backlog
4. **Increment ids** — continue from the highest existing id (F-015 → F-016)
5. **Preserve `addressed`** — existing findings keep their `addressed` value untouched; new findings get `addressed: null`
6. **Don't downgrade severity** — unless new information justifies it
7. **Remove false positives** — if deeper analysis shows a finding was wrong, remove it and say so in the report
8. **Recompute `summary`** — counts must equal the findings array, every write

## Tips

- **Start narrow, go wide**: one module deeply before sweeping the codebase
- **Read existing tests**: what IS tested reveals what ISN'T
- **Check git history**: recent changes are likelier to have issues than battle-tested code
- **Don't over-report**: 10 high-quality findings beat 50 low-quality ones
- **Positive findings matter**: `info` findings that highlight good patterns help the team
````

- [ ] **Step 2: Validate**

Run: `claude plugin validate ./plugin`
Expected: passes.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/reviewing-codebase/SKILL.md
git commit -m "feat(plugin): port reviewing-codebase skill with addressed-field tracking"
```

---

### Task 4: `/ralph:review` command

**Files:**
- Create: `plugin/commands/review.md`

**Interfaces:**
- Consumes: `plugin/skills/reviewing-codebase/SKILL.md` (Task 3 — Read from plugin root; headings per its Interfaces block); `.claude/ralph.json` `reviewFocus` and `sourceDirs`; Task 1's parallel-dispatch verdict (if SEQUENTIAL-ONLY, replace "all in a single message so they run in parallel" with "one at a time" in step 3 — note the substitution in the spike appendix).
- Produces: `review-output/findings.json` + `review-output/REVIEW_REPORT.md`, uncommitted. `improve-cycle.md` (Task 6) executes this file's procedure by reference.

- [ ] **Step 1: Write the command**

`plugin/commands/review.md`:
```markdown
---
description: Codebase review — parallel category subagents merged into the tracked findings backlog
argument-hint: '[--diff-base <ref>] [--focus <cat1,cat2>] [--target <path>]'
---
# /ralph:review — codebase analysis

Run a structured, read-only codebase review: $ARGUMENTS

You change NOTHING except two artifacts: `review-output/findings.json`
(the tracked backlog — source of truth) and
`review-output/REVIEW_REPORT.md` (derived, regenerated every run). You
never commit and never create branches — inspect the results, commit
them yourself, or let an improve cycle carry them inside its fix PR.

## Scope resolution
1. Categories: `--focus` (comma-separated) if given; else
   `.claude/ralph.json` → `reviewFocus` if non-empty; else all five:
   security, bug, code-quality, test-coverage, architecture.
2. Targets: `--target <path>` if given; else `.claude/ralph.json` →
   `sourceDirs` if non-empty; else infer the repo's primary source
   files from its layout and CLAUDE.md — and state the inference in
   your report.
3. `--diff-base <ref>`: restrict targets to files in
   `git diff --name-only <ref>...HEAD` that also fall under step 2's
   targets. Record the ref in the findings `scope.diffBase` (empty
   string when not used).

## Procedure
1. Read `${CLAUDE_PLUGIN_ROOT}/skills/reviewing-codebase/SKILL.md` — it
   defines the findings schema (including `addressed`), the severity
   rubric, per-category analysis techniques, anti-patterns, and the
   accumulation/dedup rules. Follow it exactly.
2. Load the existing backlog if `review-output/findings.json` exists:
   note the highest existing finding id, every existing finding's
   title/file/category (dedup context), and every `addressed` value
   (these must survive untouched).
3. Dispatch ONE subagent per category — all in a single message so they
   run in parallel. Each subagent is read-only (instruct it: analysis
   only, no Write/Edit, no state changes) and receives: its category;
   that category's section from the skill's "Category Analysis
   Techniques"; the "Severity Rubric" table with its calibration rules;
   the anti-patterns list; the resolved target file list; the titles of
   existing findings in its category (do not re-report these); and this
   output contract — final message is a RAW JSON ARRAY of finding
   objects (no prose, no markdown fences, no `id` and no `addressed`
   fields: the orchestrator assigns both), each with
   category/severity/file/line?/title/description/suggestion/effort/references?.
   If a subagent returns anything unparseable, re-dispatch it once;
   twice unparseable = drop that category and say so in the report.
4. Merge per the skill's "Accumulation and Deduplication Rules": drop
   duplicates of existing findings and cross-category duplicates (same
   root cause); assign sequential ids continuing from the highest
   existing; new findings get `"addressed": null`; existing findings
   keep their `addressed` values; recompute `summary` over ALL
   findings.
5. Write `review-output/findings.json` (create the directory if
   needed) using the skill's file structure — project (repo name),
   reviewDate (today), scope {target, diffBase, focus}, summary,
   findings. Validate with real commands and show the output:
   `jq -e '.summary.total == (.findings | length)'
   review-output/findings.json` must print `true`.
6. Regenerate `review-output/REVIEW_REPORT.md` from the merged
   findings: title + reviewDate + scope line; a summary table (counts
   by severity); then one section per severity in rubric order, each
   finding rendered as `### F-xxx [severity] title` with file:line,
   description, suggestion, and `addressed` status; end with an "Open
   vs addressed" count line.
7. Report: new findings vs pre-existing (counts by severity), the top
   findings by severity, the scope actually used, and both artifact
   paths. If `git check-ignore review-output/findings.json` exits 0,
   WARN prominently: an ignored backlog vanishes in worktrees and
   fresh clones and defeats the improve loop (plugin README, "Artifact
   tracking").
```

- [ ] **Step 2: Validate the plugin**

Run: `claude plugin validate ./plugin`
Expected: passes.

- [ ] **Step 3: Smoke R1 — full review, merge + dedup against the fixture backlog**

```bash
bash tests/make_sandbox.sh /tmp/ralph-sb-review && cd /tmp/ralph-sb-review
claude -p "/ralph:review" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 25 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 10 > /tmp/p3-review-full.jsonl 2>&1
```
(Bash timeout 600000.) Checklist — verify on disk + structurally in the stream:
- `findings.json` parses; `jq -e '.summary.total == (.findings|length)'` → true.
- Fixture findings F-001/F-002/F-003 still present, contents unmodified (compare title/severity fields), no duplicate of F-001's unknown-flag issue among the new findings (dedup worked — the five category agents will plausibly rediscover it).
- New finding ids continue from F-004; every new finding has `"addressed": null`.
- Five (default categories) Agent tool_use dispatches; per Task 1's verdict, parallel = multiple Agent tool_use blocks within one assistant message.
- `REVIEW_REPORT.md` exists with severity sections and the summary table.
- Zero commits (`git log --oneline` = 1 init commit), zero branches beyond main, working tree shows only the two review-output files modified.

- [ ] **Step 4: Smoke R2 — `--focus bug --target greeting.sh`**

Same sandbox:
```bash
claude -p "/ralph:review --focus bug --target greeting.sh" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 15 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 5 > /tmp/p3-review-focus.jsonl 2>&1
```
Checklist: exactly ONE Agent dispatch (bug only); `scope.focus == ["bug"]`; prior findings (from R1) preserved; ids continue.

- [ ] **Step 5: Smoke R3 — `--diff-base`**

Same sandbox:
```bash
printf '\n# touched for diff-base probe\n' >> verify.sh && git add verify.sh && git commit -qm "test: touch verify.sh"
claude -p "/ralph:review --diff-base HEAD~1" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 15 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 5 > /tmp/p3-review-diffbase.jsonl 2>&1
```
Checklist: `scope.diffBase == "HEAD~1"`; the dispatched subagents' target lists contain only `verify.sh`; backlog merge semantics intact. Then `cd / && rm -rf /tmp/ralph-sb-review`. Keep all three jsonl captures.

- [ ] **Step 6: Record observations**

Append a "Task 4 smoke runs" section to `docs/superpowers/spikes/2026-07-improve-mechanics.md` (evidence-first, per-checklist-item, same format as Plan 2's appendices). Note any wording adjustment made to review.md and re-run the affected smoke.

- [ ] **Step 7: Commit**

```bash
git add plugin/commands/review.md docs/superpowers/spikes/2026-07-improve-mechanics.md
git commit -m "feat(plugin): /ralph:review parallel category review into tracked backlog"
```

---

### Task 5: build.md — config-driven caps + evaluable turn-line timestamp

Wires `defaultBudgets.buildTurnsFactor`/`buildHours` (README currently documents them as reserved) and closes a Plan-1 deferred item: the 2-hour goal clause wasn't transcript-evaluable because no current timestamp ever appeared; adding "now" to the RALPH TURN line fixes that. Defaults preserve current behavior exactly.

**Files:**
- Modify: `plugin/commands/build.md` (four precise edits)

**Interfaces:**
- Consumes: `.claude/ralph.json` → `defaultBudgets.buildTurnsFactor` (default 2), `defaultBudgets.buildHours` (default 2).
- Produces: turn-line format `RALPH TURN <k>/<TURN_CAP> (build started <BUILD_START>, now <NOW>)` — Task 9's parity runs assert it; the goal condition text names HOURS_CAP.

- [ ] **Step 1: Edit Phase 1 step 6**

Replace:
```
6. Compute TURN_CAP = 2 × (number of tasks). Record BUILD_START as the
   current ISO 8601 timestamp — Phase 3 step 1 prints both every turn.
```
with:
```
6. Compute TURN_CAP = F × (number of tasks), where F is
   `.claude/ralph.json` → `defaultBudgets.buildTurnsFactor` if that
   file and field exist, else 2. Set HOURS_CAP from
   `defaultBudgets.buildHours` the same way, else 2. Record BUILD_START
   as the current ISO 8601 timestamp — Phase 3 step 1 prints these
   every turn.
```

- [ ] **Step 2: Edit the Phase 2 goal condition's closing clause**

Replace (inside the quoted condition in Phase 2 step 1):
```
   PASS — or the transcript shows a RALPH TURN line where k >= <TURN_CAP>,
   or shows the build has run more than 2 hours past its printed start
   timestamp."
```
with:
```
   PASS — or the transcript shows a RALPH TURN line where k >= <TURN_CAP>,
   or shows a RALPH TURN line whose 'now' timestamp is more than
   <HOURS_CAP> hours past its 'build started' timestamp."
```
(`<HOURS_CAP>` is filled with the real value like `<N>`/`<TURN_CAP>` are. Do not touch the provenance wording earlier in the condition.)

- [ ] **Step 3: Edit Phase 3 steps 1–2**

Step 1, replace:
```
1. Print `RALPH TURN <k>/<TURN_CAP> (build started <BUILD_START>)` where
   `k` is this turn's 1-based count.
```
with:
```
1. Print `RALPH TURN <k>/<TURN_CAP> (build started <BUILD_START>, now
   <current ISO 8601 timestamp>)` where `k` is this turn's 1-based
   count.
```
Step 2, replace `or more than 2 hours have` with `or more than HOURS_CAP hours have`.

- [ ] **Step 4: Edit Phase 4 step 3**

Replace `or more than 2 hours have elapsed since `BUILD_START`,` with `or more than HOURS_CAP hours have elapsed since `BUILD_START`,`.

- [ ] **Step 5: Validate**

Run: `claude plugin validate ./plugin && make check`
Expected: green. Confirm with `git diff` that Phase 1 steps 1–5 and 3a, and the README-cited step numbering, are untouched.

- [ ] **Step 6: Smoke — config override honored**

```bash
bash tests/make_sandbox.sh /tmp/ralph-sb-caps && cd /tmp/ralph-sb-caps
REMOTE=$(mktemp -d) && git init -q --bare "$REMOTE" && git remote add origin "$REMOTE"
jq '. + {defaultBudgets: {buildTurnsFactor: 3, buildHours: 1}}' .claude/ralph.json > .claude/ralph.json.tmp \
  && mv .claude/ralph.json.tmp .claude/ralph.json
git add .claude/ralph.json && git commit -qm "test: add build budget overrides"
claude -p "/ralph:build specs/sandbox.json" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 30 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 10 > /tmp/p3-build-caps.jsonl 2>&1
```
(Bash timeout 600000.) Checklist: turn lines read `RALPH TURN 1/6` (3 × 2 tasks) and contain `, now 20`; the `.ralph-goal` condition text (Read back in the transcript) names the 1-hour cap; build completes normally — both tasks, verifier PASS, exactly one push to the bare remote, honest `gh pr create` failure report. Then `cd / && rm -rf /tmp/ralph-sb-caps "$REMOTE"`; keep the capture.

- [ ] **Step 7: Record + commit**

Append "Task 5 smoke run" to the spike doc, then:
```bash
git add plugin/commands/build.md docs/superpowers/spikes/2026-07-improve-mechanics.md
git commit -m "feat(plugin): config-driven build caps and evaluable turn-line timestamp"
```

---

### Task 6: `/ralph:improve-cycle` — the inner unit of work

**Files:**
- Create: `plugin/commands/improve-cycle.md`

**Interfaces:**
- Consumes: `review.md` (Task 4), `spec.md` (`--from-findings`, Plan 2), `build.md` (Task 5 state), all executed by Reading from `${CLAUDE_PLUGIN_ROOT}`; `.claude/ralph.json` → `defaultBudgets.improveFindings` (default 3).
- Produces: the command the launcher (Task 7) and routine template (Task 8) spawn headlessly. Contract with the launcher: runtime files are SIDECARS next to the worktree, never inside it — pid at `<worktree-path>.pid`, log at `<worktree-path>.log`, selection scratch at `<worktree-path>.selected.json` — because build.md's preflight aborts on any untracked file in the tree beyond the target spec. The pid sidecar is removed as the LAST act of every terminal path (tolerating absence — foreground/routine runs have none); the selection scratch never survives the cycle.

- [ ] **Step 1: Write the command**

`plugin/commands/improve-cycle.md`:
```markdown
---
description: One bounded improve cycle — review, select, fix-spec, mini-build, PR. Internal; run headlessly in a ralph/improve-* worktree by /ralph:improve.
---
# /ralph:improve-cycle — the improve unit of work

You are running ONE bounded improvement cycle, headlessly, inside a
dedicated git worktree (or a routine's fresh clone) prepared by
/ralph:improve. Hard caps (--max-turns, --max-budget-usd) are already on
this process.

## Guard — before anything else
The current branch must match `ralph/improve-*` and `git status` must be
clean. If either fails — you are in someone's real checkout, or on a
default branch — ABORT immediately with a clear message and change
NOTHING. Do not create a branch to fix this; the launcher owns setup.

## Phase I-1 — Review
Execute the full procedure in `${CLAUDE_PLUGIN_ROOT}/commands/review.md`
(Read it), no arguments — config-driven scope. Result: an updated
`review-output/findings.json` and report, uncommitted.

## Phase I-2 — Select
1. N = `.claude/ralph.json` → `defaultBudgets.improveFindings`, else 3.
2. Candidates: findings with `addressed` null-or-absent and severity !=
   info, ordered critical → high → medium → low (ties: lower id first).
3. PR-overlap filter: `gh pr list --state open --json number,headRefName`;
   for each open `ralph/*` PR, `gh pr diff <number> --name-only`; drop
   any candidate whose `file` appears in any of those diffs (someone is
   already touching it). If gh fails (no GitHub remote), say so and
   skip this filter.
4. Revalidate each remaining candidate against the working tree: the
   cited file exists and the described symptom is still present at the
   cited location (read it). A candidate that fails revalidation is
   dropped AND marked in the backlog: `addressed: "stale-<today>"` —
   humans fix things too, and the next cycle must not re-chew it.
5. Take the top N. If ZERO remain: write the backlog only if step 4
   changed it, run the Cleanup section, and end with "improve: no
   actionable findings this cycle" — a successful empty cycle, not an
   error.

## Phase I-3 — Fix-spec
1. Write the selected findings (full objects, unmodified) to the
   sidecar scratch file `"$(pwd).selected.json"` (i.e.
   `/tmp/ralph-improve-<ts>.selected.json`, OUTSIDE the worktree so
   build.md's clean-tree preflight never sees it), shaped
   `{"findings": [...]}` — deleted in Cleanup.
2. Execute `${CLAUDE_PLUGIN_ROOT}/commands/spec.md`'s full procedure
   (Read it) with the input
   `--from-findings "$(pwd).selected.json"`. Name the spec's
   `project` field "Improve <today YYYY-MM-DD>"; if
   `specs/improve-<date>.json` already exists, append `-<HHMM>` to the
   project name and slug.
3. Commit the review artifacts NOW:
   `git add review-output && git commit -m "chore: review backlog for improve cycle"`
   — build.md's preflight requires a clean tree apart from the target
   spec file, and the backlog state that selected these findings
   belongs in the PR diff.
4. If spec generation aborts, run Cleanup and report the abort
   honestly. Never build without a validated spec.

## Phase I-4 — Build
Execute `${CLAUDE_PLUGIN_ROOT}/commands/build.md` (Read it) exactly, as
the orchestrator, with the generated spec path as its argument. You are
already on the `ralph/improve-*` branch — build.md keeps you on it and
commits the fresh spec via its Phase 1 step 3a. Every build.md rule
applies unchanged: caps, `.ralph-goal` lifecycle, script-produced
evidence, builder/verifier dispatches, single push at PR time, draft
partial PR on terminal stops, never merge, no attribution lines.

## Phase I-5 — Backlog reconciliation (ONLY if build.md reported a created PR)
1. In `review-output/findings.json`, set `addressed` to the PR number
   for every finding the spec's tasks cite (task descriptions carry
   "fixes F-xxx" per the fix-spec rules).
2. Commit: `chore: mark findings addressed by PR #<number>`.
3. Push that ONE commit to the same, already-open PR branch
   (`git push`). This is the improve cycle's single sanctioned post-PR
   push — the backlog update must land inside the PR that it
   references. Nothing else is ever pushed after it.
If no PR exists (gh unavailable, partial stop), skip all three steps
and say so — the findings stay open for the next cycle.

## Cleanup — every terminal path (success, empty, abort, partial)
1. Delete `"$(pwd).selected.json"` and `.ralph-goal` if present.
2. Remove the pid sidecar `"$(pwd).pid"` LAST, if present (foreground
   and routine runs have none) — its absence tells the launcher's next
   tick this cycle ended.
3. Final message: what happened (PR URL, partial, empty, or abort),
   which findings were addressed/stale-marked, and that the worktree
   can be removed with `git worktree remove <path>` once the PR is
   merged or the work inspected.
```

- [ ] **Step 2: Validate the plugin**

Run: `claude plugin validate ./plugin`
Expected: passes.

- [ ] **Step 3: Smoke C1 — guard refuses a real checkout**

```bash
bash tests/make_sandbox.sh /tmp/ralph-sb-cycle && cd /tmp/ralph-sb-cycle
claude -p "/ralph:improve-cycle" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 4 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Glob,Grep" \
  --max-budget-usd 2 > /tmp/p3-cycle-guard.jsonl 2>&1
```
Checklist: aborts on the branch guard (`main` ≠ `ralph/improve-*`); zero writes (`git status --porcelain` empty; no findings/spec/goal files created).

- [ ] **Step 4: Smoke C2 — full foreground cycle in a worktree**

Simulate exactly what the launcher will set up:
```bash
cd /tmp/ralph-sb-cycle
REMOTE=$(mktemp -d) && git init -q --bare "$REMOTE" && git remote add origin "$REMOTE"
git worktree add /tmp/ralph-sb-cycle-wt -b ralph/improve-smoke main
mkdir -p /tmp/ralph-sb-cycle-wt/.claude
cp /Users/g8s/Dev/ralph-starter/plugin/hooks/hooks.json /tmp/ralph-sb-cycle-wt/.claude/settings.json
echo $$ > /tmp/ralph-sb-cycle-wt.pid
cd /tmp/ralph-sb-cycle-wt
claude -p "/ralph:improve-cycle" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 15 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 10 > /tmp/p3-cycle-full.jsonl 2>&1
```
(Run via Bash `run_in_background: true` and poll BashOutput — a full cycle can exceed a foreground timeout.) Checklist:
- Guard passed; review executed (findings.json updated in the worktree; category agents dispatched).
- Selection: F-001 (medium) selected; F-003 (info) excluded; revalidation kept F-001 (greeting.sh genuinely ignores unknown flags); N respected.
- `specs/improve-<date>.json` exists, cites F-xxx ids, validated by the evidence script (exit 0 in transcript).
- Review artifacts committed before the first builder dispatch; spec committed by step 3a; fix implemented by a `ralph:ralph-builder` dispatch; verifier dispatched on completion.
- Exactly one `git push` (bare remote gains `refs/heads/ralph/improve-smoke`); `gh pr create` attempted, its local-remote failure reported honestly; Phase I-5 correctly SKIPPED (no PR) with the "findings stay open" note.
- Cleanup: `/tmp/ralph-sb-cycle-wt.selected.json` gone, `.ralph-goal` gone, the pid sidecar `/tmp/ralph-sb-cycle-wt.pid` GONE; sandbox main checkout untouched (`git -C /tmp/ralph-sb-cycle log --oneline` = init commits only).
Then clean up: `cd /tmp/ralph-sb-cycle && git worktree remove --force /tmp/ralph-sb-cycle-wt; cd / && rm -rf /tmp/ralph-sb-cycle "$REMOTE"`. Keep captures.

- [ ] **Step 5: Record observations**

Append "Task 6 smoke runs" to `docs/superpowers/spikes/2026-07-improve-mechanics.md`.

- [ ] **Step 6: Commit**

```bash
git add plugin/commands/improve-cycle.md docs/superpowers/spikes/2026-07-improve-mechanics.md
git commit -m "feat(plugin): /ralph:improve-cycle bounded review-to-PR unit of work"
```

---

### Task 7: `/ralph:improve` launcher + status tick reporting

**Files:**
- Create: `plugin/commands/improve.md`
- Modify: `plugin/commands/status.md` (add improve-tick section)

**Interfaces:**
- Consumes: `improve-cycle.md` (Task 6 — spawned, not Read); `.claude/ralph.json` → `defaultBudgets.improveTurns` (15) / `improveUsd` (10); Task 1 verdicts (c) — routes the fire-and-forget documentation and L1's expectations — and (d) — GO means the spawn prompt becomes the native-`/goal`-wrapped form below; sidecar contract from Task 6.
- Produces: the `/loop /ralph:improve` local trigger surface and the `--wait` mode routines use (Task 8).

- [ ] **Step 1: Write the launcher**

`plugin/commands/improve.md`:
```markdown
---
description: Launch one bounded, headless, worktree-isolated improve cycle (review → fix-spec → build → PR)
argument-hint: '[--wait]'
---
# /ralph:improve — improve-cycle launcher

Launch one improvement tick: $ARGUMENTS

You are a LAUNCHER. The work happens in a fresh git worktree, in a
separate capped headless claude process. You never review or build
anything yourself, and the cycle never runs in this session's checkout —
a tick that cannot get its worktree FAILS with the error; there is no
fallback.

## Busy checks — skip rather than stack
1. For each `git worktree list` entry whose path contains
   `ralph-improve-` (runtime files are SIDECARS: pid at `<path>.pid`,
   log at `<path>.log` — never inside the worktree, where they would
   trip build.md's clean-tree preflight):
   - `<path>.pid` exists and its PID is alive (`kill -0`): a tick is
     RUNNING — report path/branch/pid and STOP.
   - pid sidecar exists, process dead: a CRASHED tick — report the
     path and branch, tell the human to inspect it and remove it with
     `git worktree remove --force <path>` (plus the sidecars) when
     done, and STOP. Never remove it yourself.
   - no pid sidecar: the cycle finished — if `git -C <path> status
     --porcelain` is empty, run `git worktree remove <path>` and
     delete the leftover `<path>.log` (its work is pushed or it did
     nothing) and continue; otherwise report the leftover state and
     STOP.
2. `gh pr list --state open --json headRefName`: any open PR on a
   `ralph/improve-*` branch → report it and STOP (the previous cycle's
   PR awaits human review; don't pile on). If gh fails, warn that this
   check was skipped and continue.

## Launch
1. Caps: `.claude/ralph.json` → `defaultBudgets.improveTurns` (else 15)
   and `defaultBudgets.improveUsd` (else 10). (`improveHours` is
   approximated by the turn cap — no wall-clock flag exists.)
2. `TS=$(date +%Y%m%d-%H%M%S)`; `WT=/tmp/ralph-improve-$TS`;
   `git worktree add "$WT" -b "ralph/improve-$TS" <default-branch>`.
   Any failure here fails the tick — report the git error verbatim.
3. Stop-hook carry (plugin hooks are inert under
   `--setting-sources project`): if `$WT/.claude/settings.json` does
   not exist, `mkdir -p "$WT/.claude" && cp
   "${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json" "$WT/.claude/settings.json"`.
4. Spawn from inside $WT, as one Bash command run through your Bash
   tool's background facility — NEVER nohup/disown/setsid (orphaned
   background runs are the incident class this design exists to
   prevent; the child must stay harness-visible and killable). Pid and
   log are SIDECARS next to the worktree, never inside it:
   `cd "$WT" && claude -p "<SPAWN_PROMPT>"
   --plugin-dir "${CLAUDE_PLUGIN_ROOT}" --setting-sources project
   --permission-mode acceptEdits
   --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep"
   --max-turns <improveTurns> --max-budget-usd <improveUsd>
   --output-format stream-json --verbose
   > "$WT.log" 2>&1 & echo $! > "$WT.pid"`
   where `<SPAWN_PROMPT>` is `/ralph:improve-cycle` — or, per the
   improve-mechanics spike's native-/goal verdict (GO), the wrapped
   form: `/goal The transcript shows the full procedure of
   /ralph:improve-cycle (the plugin command) executed to a terminal
   state — a PR URL reported, or an honest partial, empty-cycle, or
   abort report with cleanup done — or stop after <improveTurns>
   turns.` (the native evaluator then drives the cycle; the
   settings-hook duplicate remains as belt-and-suspenders).
5. Without `--wait`: report the worktree path, branch, PID, log path
   (`$WT.log`), and caps, plus how to watch it (`tail -f "$WT.log"`,
   `/ralph:status`) and how to kill it (`kill <pid>`). A tick's
   lifetime is bounded by its caps AND by this session (children are
   not detached) — from `/loop`, the session persists between ticks;
   do not expect a tick to outlive the session that launched it.
   With `--wait`: poll `kill -0 <pid>` with short sleeps until it
   exits, then report the log's final result, the PR URL if one was
   created, and apply the finished-worktree rule from Busy checks 1
   (remove the worktree and log only if the pid sidecar is gone and
   the worktree status is clean).
```

- [ ] **Step 2: Add tick reporting to status.md**

In `plugin/commands/status.md`, after the existing step 4, add:
```
5. Improve ticks: for each `git worktree list` entry whose path
   contains `ralph-improve-`: report path, branch, and state —
   RUNNING (`<path>.pid` sidecar present, process alive), CRASHED
   (pid sidecar present, process dead — needs human inspection), or
   FINISHED (no pid sidecar; removable if clean).
```

- [ ] **Step 3: Validate**

Run: `claude plugin validate ./plugin`
Expected: passes.

- [ ] **Step 4: Smoke L1 — fire-and-forget launch**

```bash
bash tests/make_sandbox.sh /tmp/ralph-sb-launch && cd /tmp/ralph-sb-launch
REMOTE=$(mktemp -d) && git init -q --bare "$REMOTE" && git remote add origin "$REMOTE"
claude -p "/ralph:improve" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 10 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Glob,Grep" \
  --max-budget-usd 3 > /tmp/p3-launch-fire.jsonl 2>&1
```
(Bash timeout 300000 — the launcher itself returns quickly.) Checklist: a `/tmp/ralph-improve-<ts>` worktree exists on branch `ralph/improve-<ts>`; `.claude/settings.json` copied in; the sidecar `/tmp/ralph-improve-<ts>.pid` names a claude process; the launcher's final message contains path/branch/pid/log/caps/kill instructions. Then apply the spike's verdict (c): if CHILD-SURVIVES, poll the pid from your shell until it exits and verify the inner cycle's end state matches Task 6 C2's class (push to bare remote, honest gh failure, pid sidecar removed) — and additionally verify the kill switch on a SECOND launched tick (`kill <pid>` mid-flight → process dies → the next launcher invocation reports it as a CRASHED tick). If CHILD-DIED at outer-session end, record that as the no-orphan property working (the crashed-tick path then fires on the next invocation — verify it does), and rely on L3's `--wait` run for full-cycle validation.

- [ ] **Step 5: Smoke L2 — busy-check triple**

In the same sandbox, manufacture each state and invoke the launcher (same flags as L1, `--max-turns 8`, fresh capture files):
1. RUNNING: first `git worktree add /tmp/ralph-improve-fake -b ralph/improve-fake main`, then `sleep 600 &` and write that background PID to the sidecar: `echo $! > /tmp/ralph-improve-fake.pid` → launcher reports RUNNING tick and stops (no new worktree). Kill the sleep afterward.
2. CRASHED: leave the now-dead PID in the sidecar → launcher reports CRASHED with inspect/remove instructions and stops.
3. FINISHED: `rm /tmp/ralph-improve-fake.pid` (tree is clean) → launcher removes the fake worktree and proceeds to launch a real tick (which you then let finish or kill + clean up per its own report).
Also run `/ralph:status` once (headless, read-only allowlist `Bash,Read,Glob,Grep`, `--max-turns 8`) while a tick state exists and confirm step 5's tick line appears.

- [ ] **Step 6: Smoke L3 — `--wait`**

Fresh sandbox + bare remote (same setup as L1):
```bash
claude -p "/ralph:improve --wait" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 25 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Glob,Grep" \
  --max-budget-usd 15 > /tmp/p3-launch-wait.jsonl 2>&1
```
(Bash run_in_background + poll; the wait spans the whole inner cycle.) Checklist: launcher polls to completion, reports the inner cycle's outcome, and auto-removes the finished clean worktree. Clean up sandboxes/remotes; keep captures.

- [ ] **Step 7: Record observations**

Append "Task 7 smoke runs" to the spike doc.

- [ ] **Step 8: Commit**

```bash
git add plugin/commands/improve.md plugin/commands/status.md docs/superpowers/spikes/2026-07-improve-mechanics.md
git commit -m "feat(plugin): /ralph:improve worktree launcher with busy checks and --wait"
```

---

### Task 8: Routine template, config example, README, version bump

**Files:**
- Create: `plugin/routines/improve-nightly.md`
- Modify: `.claude/ralph.json` (add `improveFindings` to defaultBudgets)
- Modify: `plugin/README.md`
- Modify: `plugin/.claude-plugin/plugin.json` (version `0.3.0`)

**Interfaces:**
- Consumes: everything shipped in Tasks 2–7.
- Produces: the `/schedule`-ready routine prompt; accurate user-facing docs.

- [ ] **Step 1: Write the routine template**

`plugin/routines/improve-nightly.md`:
```markdown
# Ralph nightly improve — routine template

Register with the scheduler (e.g. `/schedule "nightly at 02:00" <the
Instructions block below>`). The routine runs Claude in a fresh clone of
the repository; platform fact: whether marketplace-installed plugins are
available in that clone is UNCONFIRMED, so the instructions verify and
fall back to the repo's own plugin directory rather than assuming.

## Instructions (use as the routine prompt)

You are a scheduled Ralph improvement tick running in a fresh clone.

1. Preflight: confirm `.claude/settings.json` exists and contains a
   Stop hook (repos that track it are covered; otherwise copy
   `plugin/hooks/hooks.json` to `.claude/settings.json` — plugin-shipped
   hooks do not fire under isolated setting sources).
2. If the `/ralph:improve` command is available, run:
   `/ralph:improve --wait`
3. If it is NOT available but the repo contains `plugin/commands/
   improve-cycle.md` (this repo ships its plugin in-tree), run the
   launcher's spawn directly and wait for it:
   - `TS=$(date +%Y%m%d-%H%M%S)`
   - `git worktree add "/tmp/ralph-improve-$TS" -b "ralph/improve-$TS" main`
   - `cp plugin/hooks/hooks.json /tmp/ralph-improve-$TS/.claude/settings.json`
     (create the `.claude` dir first; skip if the file materialized)
   - from inside the worktree:
     `claude -p "/ralph:improve-cycle" --plugin-dir "$PWD/plugin"
     --setting-sources project --permission-mode acceptEdits
     --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep"
     --max-turns 15 --max-budget-usd 10`
   (the cycle's instructions come from the clone's own plugin dir — no
   inlined drift)
4. If neither is possible, STOP and report "ralph plugin unavailable in
   routine environment" — do not improvise the cycle.
5. Report: the PR URL (or the honest failure/empty-cycle outcome), the
   caps used, and which findings were addressed.
```

- [ ] **Step 2: Update the example config**

`.claude/ralph.json` — inside `defaultBudgets`, after `"improveUsd": 10`, add:
```json
    "improveFindings": 3
```

- [ ] **Step 3: Update the README**

`plugin/README.md`:
1. Commands table — replace the `/ralph:review` and `/ralph:improve` "Coming in Plan 3" rows with:
```markdown
| `/ralph:review [--diff-base <ref>] [--focus <cats>] [--target <path>]` | Read-only codebase review — parallel category subagents merged into the tracked findings backlog |
| `/ralph:improve [--wait]` | One bounded improve tick: headless review → fix-spec → build → PR in a fresh worktree; `--wait` blocks until done |
| `/ralph:improve-cycle` | Internal — the unit of work `/ralph:improve` spawns; refuses to run outside a `ralph/improve-*` worktree |
```
2. New section after "Spec generation & the dev pipeline":
```markdown
## Review & the improve flywheel

`/ralph:review` writes `review-output/findings.json` (the tracked
backlog; schema in `plugin/skills/reviewing-codebase/`) and a
regenerated `REVIEW_REPORT.md`, never committing. Each finding carries
`addressed`: `null` while open, the fix PR's number once an improve
cycle delivers one, or `stale-<date>` when revalidation finds it
already fixed.

`/ralph:improve` runs one bounded cycle — review → select top-N open
findings (default 3, `defaultBudgets.improveFindings`) → fix-spec →
mini-build → PR — always headless in a fresh `/tmp/ralph-improve-<ts>`
worktree on a `ralph/improve-<ts>` branch, never in your checkout. Caps
come from `defaultBudgets.improveTurns`/`improveUsd` (15 / $10
defaults). A tick skips itself if a previous tick is running or its PR
is still open; a crashed tick is surfaced for human inspection, never
auto-deleted. The backlog update marking findings `addressed` is
committed and pushed into the same open PR as a single documented
follow-up commit — the one exception to single-push.

Triggers: locally, `/loop /ralph:improve` (each tick is
fire-and-forget within the live session; the loop cadence should
exceed a cycle's duration); in the cloud, schedule
`plugin/routines/improve-nightly.md`'s Instructions block, which uses
`--wait`. Ticks are never detached (no nohup) — a tick cannot outlive
the session that launched it, by design: orphaned background runs
that would not die are the incident class this replaces.

Kill switches: `kill <pid>` (the launcher prints it; the pid sidecar
sits next to the worktree), `/ralph:status` (shows
RUNNING/CRASHED/FINISHED ticks), PR review (nothing merges itself).
```
3. Config section — replace the `defaultBudgets`, `reviewFocus`, and `sourceDirs` bullets:
```markdown
- `defaultBudgets` — **live now**: `buildTurnsFactor`/`buildHours` set `/ralph:build`'s TURN_CAP factor and wall-clock cap (defaults 2 / 2h); `improveTurns`/`improveUsd` cap the improve spawn (defaults 15 / $10); `improveFindings` sets findings-per-cycle (default 3). `improveHours` is documented-only: no wall-clock CLI flag exists, the turn cap approximates it.
- `reviewFocus` — **live now**: the categories `/ralph:review` fans out across when `--focus` isn't given.
- `sourceDirs` — **live now**: the default review targets when `--target` isn't given.
```
4. `models` and `artifactPaths` bullets: change "reserved" to "reserved (deliberately — no consumer in v1; revisit after the parity gate)".
5. "Running headless / unattended" section: replace the inlined hook JSON snippet with:
```markdown
- **Caveat:** under `--setting-sources project` the plugin's own Stop hook does not fire at all (re-confirmed 2026-07-20) — the host repo needs the hook duplicated into its own `.claude/settings.json`. Copy it verbatim from [`plugin/hooks/hooks.json`](hooks/hooks.json) (this repo tracks such a copy at `.claude/settings.json`, so fresh clones and worktrees of ralph-starter already have it):

  ```bash
  cp plugin/hooks/hooks.json .claude/settings.json
  ```
```
6. Artifact tracking section — append: "This repo made that migration in Plan 3: `specs/`, `review-output/`, and `.claude/settings.json` are tracked here."

- [ ] **Step 4: Bump the version**

`plugin/.claude-plugin/plugin.json`: `"version": "0.3.0"`.

- [ ] **Step 5: Gate + commit**

```bash
make check && claude plugin validate ./plugin
git add plugin/routines/improve-nightly.md .claude/ralph.json plugin/README.md plugin/.claude-plugin/plugin.json
git commit -m "docs(plugin): improve flywheel docs, routine template, live config; bump to 0.3.0"
```

---

### Task 9: Parity gate — design §9 evidence record

Produces the evidence on which the human decides whether bash `ralph.sh` can be deprecated. All four build-engine points, asserted from disk/reflog/remote/stream — plus the supervised-run tallies for spec/review/improve.

**Files:**
- Create: `docs/superpowers/spikes/2026-07-parity-gate.md`

**Interfaces:**
- Consumes: the full shipped plugin (Tasks 2–8), `tests/make_sandbox.sh`.
- Produces: the gate record; the deprecation decision itself is explicitly NOT made here.

- [ ] **Step 1: Gate runs 1 and 2 — same spec, two clean-room runs**

For run in 1 2: fresh sandbox + fresh bare remote each time (`bash tests/make_sandbox.sh /tmp/ralph-sb-gate$run`), then:
```bash
cd /tmp/ralph-sb-gate$run
REMOTE=$(mktemp -d) && git init -q --bare "$REMOTE" && git remote add origin "$REMOTE"
git -C "$REMOTE" show-ref; echo "pre-run refs exit=$?"    # must be empty / exit 1
claude -p "/ralph:build specs/sandbox.json" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 40 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 15 > /tmp/p3-gate-run$run.jsonl 2>&1
```
(Bash run_in_background + poll.) Assert per run, with real command output recorded:
- **Point 1:** every task `passes:true` in the final spec; each `context.verificationCommands` entry exits 0 when run on the PR branch (`cd` into the sandbox, `git checkout ralph/sandbox-greeting`, run `./verify.sh`).
- **Point 2:** spec's `verifier.verdict == "PASS"`.
- **Point 3:** zero pushes before PR-time and zero default-branch writes: exactly one `git push` tool_use in the stream and it occurs AFTER the verifier PASS event; `git -C "$REMOTE" show-ref` post-run lists exactly one ref (`refs/heads/ralph/sandbox-greeting`); `git -C /tmp/ralph-sb-gate$run reflog show main` (and `git log main`) shows main untouched since init.
- Turn lines carry the Task 5 format (`, now `).

- [ ] **Step 2: Gate run 3 — adversarial unsatisfiable task**

Fresh sandbox + remote. Recreate Plan 1's Scenario B contradiction: edit `specs/sandbox.json` so T-002's sole acceptance criterion demands `./greeting.sh --name Sam` output `'goodbye Sam'` while adding the constraint `"never change the 'hello' greeting semantics — the greeting word itself must always remain 'hello'"`; commit the edit (`test: adversarial unsatisfiable T-002`). Same invocation as Step 1. Assert:
- **Point 4:** T-001 completes; T-002 ends `status:"blocked"`, `attempts:2`, reason in notes; terminal stop routes to a DRAFT PR attempt titled "… (partial)" with the evidence table; `grep -c '<ralph>COMPLETE</ralph>'` on the transcript = 0; no completion claim in the final message; zero verifier dispatches; one push; main untouched.

- [ ] **Step 3: Write the gate record**

`docs/superpowers/spikes/2026-07-parity-gate.md`: date; the four §9 points each with verdict + the exact evidence (commands and outputs, jsonl refs); the mode tallies — spec: 3 supervised runs (Plan 2 S1–S3), review: 3 (Plan 3 R1–R3), improve: ≥3 (Plan 3 C2, L1, L3) — each pointing at its smoke appendix; known residual gaps carried forward (Write-then-Read evidence laundering — verifier stays mandatory; `gh`-less improve cycles re-select the same findings; routine plugin-availability in fresh clones unconfirmed). Close with: "Gate verdict: <met/not met per point>. Deprecation of bash ralph.sh is a human decision on this record."

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/spikes/2026-07-parity-gate.md
git commit -m "test: record design-§9 parity gate evidence"
```

---

### Task 10: Real-surface validation (REQUIRES EXPLICIT USER GO-AHEAD AT EXECUTION TIME)

Everything so far ran against throwaway sandboxes with local bare remotes — `gh pr create` never actually succeeded anywhere, and `status.md` has never seen a real PR (deferred since Plan 1). This task runs the flywheel once against ralph-starter itself, supervised, producing one real PR on github.com/gregsantos/ralph-starter. **Do not start it without the user's recorded yes.**

**Files:** none in-repo except what the improve cycle itself produces (findings backlog, one fix PR from a `ralph/improve-*` branch); observations appended to the spike doc.

- [ ] **Step 1: Confirm the go-ahead** — the controller must have the user's explicit approval for a real PR on the real repo. Without it, mark this task skipped in the ledger and stop.

- [ ] **Step 2: Supervised interactive `/ralph:review`** in this repo's session (not headless): confirm findings.json + report land, are trackable (Task 2), and the findings are sane against real code (`ralph.sh`, `plugin/`, `tests/` per `.claude/ralph.json` sourceDirs). Human skims the backlog before proceeding; commit the backlog on the current plan branch (`chore: initial review backlog`).

- [ ] **Step 3: One real improve tick:** `/ralph:improve --wait` from the repo session. Watch it: worktree under `/tmp/ralph-improve-*`, cycle log, single push of `ralph/improve-<ts>`, a REAL draft-quality PR, backlog reconciliation commit landing in the PR (Phase I-5 — its first live execution), worktree auto-cleanup.

- [ ] **Step 4: `/ralph:status` against the real PR** — the deferred Plan-1 item: confirm the PR table lists the open `ralph/improve-*` PR correctly.

- [ ] **Step 5: Record everything** in a "Task 10 real-surface run" appendix (spike doc), including the PR URL. The PR is left OPEN for human review — never merged by this plan.

```bash
git add docs/superpowers/spikes/2026-07-improve-mechanics.md
git commit -m "test: record real-surface improve run observations"
```

---

## Self-review notes (completed during planning)

- **Handoff scope coverage:** reviewing-codebase port → Task 3; `/ralph:review` parallel + tracked backlog + `addressed` → Task 4; `/ralph:improve` headless worktree cycle (select rules incl. addressed/PR-overlap/stale skips, improve-tier caps) → Tasks 6–7; `/loop` trigger → launcher fire-and-forget mode (Task 7) — `/loop` itself is a harness feature needing no build; routine template + fresh-clone caveat + settings-hook carry → Task 8 + Decision 5; gitignore migration → Task 2; parity gate → Task 9. Deferred items: `status.md` real-PR test → Task 10; dated model ID → README now points at hooks.json instead of inlining (Task 8 step 3.5), copies stay at hooks.json + tracked settings.json (documented); 2-hour clause evaluability → Task 5 turn-line timestamp.
- **Consistency:** sidecar contract (`<worktree-path>.pid`/`.log`/`.selected.json`, outside the tree so build.md's clean-tree preflight never sees them; launcher writes the pid, cycle removes it LAST, launcher's next tick interprets) identical in Tasks 6/7 and status.md step 5; `ralph/improve-*` branch guard matches the launcher's `ralph/improve-$TS` naming; `defaultBudgets` field names (`buildTurnsFactor`, `buildHours`, `improveTurns`, `improveUsd`, `improveFindings`) identical across build.md, improve.md, improve-cycle.md, ralph.json, README; skill headings referenced by review.md match Task 3's port; `--from-findings` path form matches spec.md's existing contract; C2/L1/L3 give ≥3 supervised improve runs for the §9 tally.
- **Numbering safety:** build.md edits touch step 6 and cap clauses only; steps 1–5/3a and Phase ordering untouched (README citations stay valid). status.md gains step 5 without renumbering 1–4.
- **Known accepted risks (stated, not hidden):** the post-PR backlog push (Decision 1, flagged in Global Constraints); `gh`-less environments degrade the flywheel (re-selection); `improveHours` is approximate; parallel-dispatch, background-child, and native-/goal behavior are all spiked before their consumers ship.
- **User directive (2026-07-20) incorporated:** no orphanable processes anywhere (Global Constraints bullet; Decision 3; launcher step 4; README wording; L1's kill-switch probe) — the incident class was `ralph.sh` backgrounded by subagents refusing to die; and native-first (`/loop`/`/schedule` are the only schedulers, Task 1 probe (d) pursues native `/goal` for spawns, no new shell scripts — `ralph-evidence.sh` stays the lone, frozen script).
