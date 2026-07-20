# Native Ralph Plugin — Spec & Dev Pipeline Implementation Plan (Plan 2 of 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the spec-generation half of the Ralph pipeline to the plugin: `/ralph:spec` (inline prompt, requirements file, or review-findings input), `/ralph:dev` (spec → build auto-continue with a `--review` pause), and the `writing-ralph-specs` skill ported into `plugin/skills/` — proven by supervised headless smoke runs in the sandbox.

**Architecture:** `/ralph:spec` is a single-session command that reads the ported skill from the plugin root, writes `specs/<slug>.json`, and validates it with the existing `ralph-evidence.sh` (exit 0 required — the same gate `/ralph:build` preflights with). `/ralph:dev` composes by reference: it executes `spec.md`'s procedure, optionally pauses for approval, then executes `build.md`'s procedure — no duplicated engine logic. One small amendment to `build.md`'s preflight lets a freshly generated, uncommitted spec be committed as the first act on the work branch, which is what makes both the standalone spec→build handoff and the dev pipeline work now that specs are tracked artifacts. Spec: `docs/superpowers/specs/2026-07-19-native-ralph-port-design.md` §2–3.

**Tech Stack:** Claude Code plugin system (commands/skills as markdown), bash + jq (fixtures, evidence script), BATS/shellcheck (`make check`), gh CLI.

**Plan 3 (not in this document):** `/ralph:review` + findings backlog + `/ralph:improve` (headless worktree ticks + routine template) + gitignore migration + parity gate.

## Global Constraints

(from the design spec, Plan 1's execution record, and the spike-verified platform facts — every task implicitly includes these)

- **PR-gated autonomy:** agents push only `ralph/*` branches, exactly once, at PR time; **never merge**; never write on the default branch. No attribution lines in commits or PR titles/bodies.
- **Caps on every headless spawn:** `--max-turns` AND `--max-budget-usd`, always. No uncapped loops.
- **All smoke tests run in throwaway sandboxes** created by `tests/make_sandbox.sh` — never headless `claude` against ralph-starter itself. Never `--dangerously-skip-permissions`.
- **Proven headless invocation shape** (platform facts 3–4): `--plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project --permission-mode acceptEdits --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep"` (drop `Agent` from allowedTools only for runs that must not dispatch subagents).
- **Plugin hooks do not fire under `--setting-sources project`** (platform fact 2): the sandbox must carry the Stop-hook duplicate in its own `.claude/settings.json` (Task 3 does this by copying `plugin/hooks/hooks.json`).
- **Evaluator provenance is opt-in** (platform fact 5): never weaken the `.ralph-goal` condition wording or the evidence-script provenance requirements; the verifier cross-check stays mandatory.
- **Plugin agents are namespaced** `ralph:ralph-builder` / `ralph:ralph-verifier`; parse agent output by SEEKING the `BUILDER REPORT` / `VERIFIER REPORT` marker line (platform fact 6).
- **Slash commands cannot be invoked from assistant output** (platform fact 1) — composition between commands is done by Reading the other command's markdown from `${CLAUDE_PLUGIN_ROOT}` and executing its procedure, never by emitting `/ralph:...` text.
- **Build-managed spec fields** (platform fact 7): per-task `attempts` (blocked at 2), top-level `verifier` `{verdict, date, summary}`.
- **The evidence block format is frozen** by `tests/plugin_evidence.bats` — nothing in this plan may change `ralph-evidence.sh`'s output.
- **`make check` and `claude plugin validate ./plugin` must be green after every task.**

## Preconditions

- On branch `feature/ralph-plugin-plan-2` (created off `main`).
- `bats`, `shellcheck`, `jq`, `gh` installed.
- Plan 1 merged at `main` (commands `go`/`build`/`status`, agents, evidence script, hooks.json, sandbox generator all exist).

## Decisions locked at plan approval

1. **Skill invocation mechanism:** `spec.md`/`dev.md` instruct the model to **Read the skill file from `${CLAUDE_PLUGIN_ROOT}/skills/...` and follow it** — deterministic, works headless, no dependency on skill registration. Whether plugin skills also register for interactive auto-trigger is spiked in Task 1 and affects only README wording.
2. **`build.md` preflight amendment** (touches a Plan 1 deliverable): the clean-tree requirement gains exactly one exception — the target spec file itself may be untracked/modified and is committed as the first act on the work branch. Everything else about `build.md` is unchanged; the amendment is re-proven live in Tasks 5–6.
3. **Sandbox gains the documented production companion config:** `.claude/settings.json` with the Stop-hook duplicate (copied from `plugin/hooks/hooks.json`, avoiding a third copy of the dated model ID) plus `.claude/ralph.json` with `verificationCommands`.
4. **`models` config stays reserved:** `/ralph:spec` and `/ralph:dev` run on the session model; no new model routing is introduced in Plan 2, so per the handoff no wiring happens.
5. **`--from-findings` ships in Plan 2** against the existing findings schema (`.claude/skills/reviewing-codebase/SKILL.md`); Plan 3's `/ralph:review` will produce real backlogs with the same schema.
6. **Name collision accepted:** this repo keeps its project-level `writing-ralph-specs` skill (bash-era) alongside the plugin's ported copy until the parity gate retires bash assets.

## File Structure

```
plugin/
├── .claude-plugin/plugin.json               # version bump 0.1.0 → 0.2.0 (Task 7)
├── skills/writing-ralph-specs/SKILL.md      # ported skill (Task 2)
├── commands/
│   ├── spec.md                              # /ralph:spec (Task 4)
│   ├── dev.md                               # /ralph:dev (Task 6)
│   └── build.md                             # preflight amendment only (Task 5)
└── README.md                                # command table + spec/dev docs (Task 7)
tests/make_sandbox.sh                        # fixtures: ralph.json, settings hook, findings, requirements (Task 3)
Makefile                                     # lint line gains make_sandbox.sh (Task 3)
docs/superpowers/spikes/2026-07-plugin-skills.md  # Task 1 spike record; smoke observations appended by Tasks 4–6
```

---

### Task 1: Spike — plugin skill registration + plugin-root file reads

Two platform assumptions in this plan are unverified: (a) a `plugin/skills/<name>/SKILL.md` directory is valid in a plugin and (optionally) registers as an invokable skill; (b) a command's instruction to **Read** a file under `${CLAUDE_PLUGIN_ROOT}` works in a headless run (Plan 1 proved `${CLAUDE_PLUGIN_ROOT}` for **Bash** execution only). Both are load-bearing for `spec.md`/`dev.md`. Spike them before building anything.

**Files:**
- Create (temporary, removed in Step 6): `plugin/skills/spike-probe/SKILL.md`
- Create (temporary, removed in Step 6): `plugin/commands/skill-probe.md`
- Create: `docs/superpowers/spikes/2026-07-plugin-skills.md`

**Interfaces:**
- Produces: a recorded verdict on (a) skill registration (name string if registered — README wording in Task 7 depends on it) and (b) plugin-root Read (hard requirement — if this fails, STOP the plan and check in with the user, because it contradicts the Plan-1-proven `${CLAUDE_PLUGIN_ROOT}` behavior).

- [ ] **Step 1: Create the probe skill**

`plugin/skills/spike-probe/SKILL.md`:
```markdown
---
name: spike-probe
description: Throwaway probe skill verifying plugin skill registration. Do not use for real work.
---
# Spike probe skill

SPIKE-SKILL-CONTENT-LOADED-OK

If you are reading this via the Skill tool, state the exact skill name you invoked.
```

- [ ] **Step 2: Create the probe command**

`plugin/commands/skill-probe.md`:
```markdown
---
description: "Spike: verify plugin skill registration and plugin-root file reads"
---
# Skill probe

Do these in order and report each outcome verbatim:

1. Try to invoke the skill named `ralph:spike-probe` with the Skill tool.
   If that exact name errors, try `spike-probe`. Report which form (if
   either) worked, and the exact error text otherwise.
2. Read the file `${CLAUDE_PLUGIN_ROOT}/skills/spike-probe/SKILL.md` with
   the Read tool and print the marker line it contains.
3. End with exactly:
   PROBE COMPLETE
   skill-tool: <worked as `<name>` | failed>
   plugin-root-read: <ok | failed>
```

- [ ] **Step 3: Validate the plugin still parses**

Run: `claude plugin validate ./plugin`
Expected: validation passes (warnings acceptable). If a `skills/` directory is itself a validation error, record that immediately — it changes Task 2's shape (skill would live under `plugin/skills/` only if valid; otherwise check in with the user before proceeding).

- [ ] **Step 4: Run the probe headlessly in a fresh sandbox**

```bash
bash tests/make_sandbox.sh /tmp/ralph-sb-spike && cd /tmp/ralph-sb-spike
claude -p "/ralph:skill-probe" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 8 --permission-mode acceptEdits \
  --allowedTools "Skill,Bash,Read,Glob,Grep" \
  --max-budget-usd 3 > /tmp/p2-skill-probe.jsonl 2>&1
```
(`Skill` is deliberately allowlisted — without it, a permission denial would be indistinguishable from "skill not registered".)

Then inspect:
```bash
grep -o '"slash_commands":\[[^]]*\]' /tmp/p2-skill-probe.jsonl | head -1   # sanity: ralph:skill-probe listed
grep -c "SPIKE-SKILL-CONTENT-LOADED-OK" /tmp/p2-skill-probe.jsonl          # >0 required
grep -o "PROBE COMPLETE" /tmp/p2-skill-probe.jsonl
```
Also check the init event for any skill registry field mentioning `spike-probe` (registration evidence independent of the Skill-tool attempt).

- [ ] **Step 5: Record the outcome**

Write `docs/superpowers/spikes/2026-07-plugin-skills.md` with: the exact commands run, verbatim relevant stream excerpts, and two decisions:
- **plugin-root-read:** ok → `spec.md`/`dev.md` proceed as planned (Read-the-file mechanism). failed → **STOP the plan; check in with the user** (contradicts Plan 1's `${CLAUDE_PLUGIN_ROOT}` platform behavior).
- **skill-tool registration:** record the working name (e.g. `ralph:writing-ralph-specs` by analogy) or "not registered"; consumed by Task 7's README wording only.

- [ ] **Step 6: Remove the probe files, keep the record**

```bash
rm -rf plugin/skills/spike-probe plugin/commands/skill-probe.md
rm -rf /tmp/ralph-sb-spike
claude plugin validate ./plugin   # still passes with probes gone
```

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/spikes/2026-07-plugin-skills.md
git commit -m "spike: verify plugin skill registration and plugin-root reads"
```

---

### Task 2: Port the writing-ralph-specs skill into the plugin

**Files:**
- Create: `plugin/skills/writing-ralph-specs/SKILL.md`

**Interfaces:**
- Consumes: nothing (content adapted from `.claude/skills/writing-ralph-specs/SKILL.md` + fix-spec rules from `.claude/skills/reviewing-codebase/SKILL.md`).
- Produces: the skill file `spec.md` (Task 4) and `dev.md` (Task 6) instruct the model to Read from `${CLAUDE_PLUGIN_ROOT}/skills/writing-ralph-specs/SKILL.md`. Section heading **"Fix-specs from review findings (--from-findings)"** is referenced by name in `spec.md` — keep the heading exact.

Adaptations from the bash-era skill (deliberate, not drift): `/ralph:build` replaces `./ralph.sh build` as the consumer; the legacy `userStories` section, bash workflow section, and Host Project Mode section are dropped (the plugin has no submodule path-rebasing); the `attempts` field and build-managed-fields note are added (platform fact 7); fix-spec conversion rules move in from the reviewing-codebase skill so `--from-findings` needs only this one file; `branchName` is dropped from the skeleton (`/ralph:build` derives its branch from `project`, ignoring `branchName`).

- [ ] **Step 1: Write the skill**

`plugin/skills/writing-ralph-specs/SKILL.md`:
````markdown
---
name: writing-ralph-specs
description: Creates structured JSON specs for Ralph plugin autonomous builds. Use when creating feature specs, fix-specs from review findings, or task lists for the /ralph:spec → /ralph:build workflow. Triggers on "create a spec", "plan this feature", "spec out", or when features need implementation planning.
---

# Writing Ralph Specs

Create JSON specs in `specs/` for autonomous execution via `/ralph:build`.
The spec is the single source of truth for a build: the orchestrator
selects tasks from it, records task state in it, and completion evidence
is derived from it. Write it as if no one will be around to clarify
intent later — for an autonomous build, no one will be.

## Spec skeleton

```json
{
  "project": "Feature Name",
  "description": "One-line description",
  "context": {
    "currentState": "What exists today",
    "targetState": "What we want to achieve",
    "constraints": ["Constraint 1"],
    "verificationCommands": ["make check"]
  },
  "tasks": []
}
```

`context.verificationCommands` is REQUIRED and must be non-empty:
`/ralph:build` refuses to start without it (its evidence script exits 3 —
unverifiable builds don't run). List only commands that actually exist
in the target repo.

## Task fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier ("T-001", "T-002", …) |
| `title` | string | Yes | Short action title |
| `description` | string | Yes | What to do, self-contained — the builder sees only this task card and the repo, never the conversation that produced the spec |
| `acceptanceCriteria` | string[] | Yes | Specific, executable/checkable criteria |
| `dependsOn` | string[] | Yes | Task ids that must pass first (empty array if none) |
| `status` | string | Yes | `pending` \| `in_progress` \| `complete` \| `blocked` — initialize as `pending` |
| `passes` | boolean | Yes | Initialize `false`; the orchestrator sets `true` when the task verifies |
| `effort` | string | Yes | `small` \| `medium` \| `large` |
| `notes` | string | Yes | Initialize `""`; the orchestrator records builder notes and failure reasons here |
| `attempts` | number | No | Initialize `0`; the orchestrator increments it per failed build attempt and blocks the task at 2 |

Build-managed fields — initialize but never pre-fill: `status`, `passes`,
`notes`, `attempts`, and the top-level `verifier` field (omit it or set
`null`; the build writes `{verdict, date, summary}` on verifier PASS).

## Acceptance criteria quality

Bad (vague, unfalsifiable):

```json
"acceptanceCriteria": ["Works correctly", "Is fast"]
```

Good (specific, executable):

```json
"acceptanceCriteria": [
  "Retry on HTTP 429, 500, 502, 503, 504",
  "Exponential backoff: 1s, 2s, 4s",
  "--max-retries flag added (default: 3)",
  "--help text documents the new flag",
  "make check passes"
]
```

Include documentation criteria for user-facing changes: CLI flags →
help text + reference docs; config options → config comments + README;
workflow changes → README.

## Fix-specs from review findings (--from-findings)

Converting a findings backlog (`review-output/findings.json`) into a
buildable spec:

1. Skip `info` findings — observations don't need fix tasks.
2. Group related findings by file/module — one task per root cause, not
   one per symptom.
3. Order tasks critical → high → medium → low.
4. Turn each finding's `suggestion` into acceptance criteria; keep them
   executable.
5. Map finding `effort` directly to task `effort`.
6. Cite source finding ids in the task description ("fixes F-001,
   F-004") so the backlog can be reconciled later.
7. Every task carries the criterion "existing verification commands
   still pass".
8. Use `dependsOn` when one fix builds on another.

## Tips

- **Atomic tasks**: each task is one fresh-context builder session;
  prefer 2–6 tasks per spec and split anything larger.
- **Self-contained descriptions**: name the exact files and commands
  involved.
- **Testable criteria**: at least one criterion per task should be a
  command the builder can run.
- **dependsOn discipline**: only real ordering constraints; no cycles.
````

- [ ] **Step 2: Validate**

Run: `claude plugin validate ./plugin`
Expected: passes.

- [ ] **Step 3: Commit**

```bash
git add plugin/skills/writing-ralph-specs/SKILL.md
git commit -m "feat(plugin): port writing-ralph-specs skill into plugin/skills"
```

---

### Task 3: Sandbox fixtures for spec/dev smoke tests

The smoke tests in Tasks 4–6 need four things the sandbox doesn't have: a host config (`verificationCommands` sourcing path), the Stop-hook duplicate (platform fact 2 — plugin hooks are inert under `--setting-sources project`, which is exactly how smoke runs invoke claude), a findings backlog fixture (`--from-findings`), and a requirements file (`-f`).

**Files:**
- Modify: `tests/make_sandbox.sh`
- Modify: `Makefile` (lint line gains `tests/make_sandbox.sh`)

**Interfaces:**
- Produces: every generated sandbox additionally contains `.claude/ralph.json` (verificationCommands `["./verify.sh"]`), `.claude/settings.json` (byte-identical copy of `plugin/hooks/hooks.json` — single source for the hook + dated model ID), `review-output/findings.json` (3 findings: medium bug F-001, low test-coverage F-002, info F-003), `requirements.md`. All committed in the sandbox's init commit. Tasks 4–6 consume all four.

- [ ] **Step 1: Add the fixtures to the generator**

In `tests/make_sandbox.sh`, insert after the `set -euo pipefail` line (line 3) — SCRIPT_DIR must be computed before the `cd`:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

Then insert the following block immediately before the final `git add -A && git commit …` line:

```bash
mkdir -p .claude review-output

cat > .claude/ralph.json <<'EOF'
{
  "verificationCommands": ["./verify.sh"]
}
EOF

# Duplicate the plugin's Stop hook into project settings: plugin-shipped
# hooks do not fire under --setting-sources project, which is the shape
# every supervised smoke run here uses (see plugin/README.md, "Running
# headless / unattended"). Copying hooks.json keeps a single source for
# the hook prompt and its pinned model ID.
cp "$SCRIPT_DIR/../plugin/hooks/hooks.json" .claude/settings.json

cat > review-output/findings.json <<'EOF'
{
  "project": "Sandbox greeting",
  "reviewDate": "2026-07-20",
  "scope": {
    "target": "greeting.sh",
    "diffBase": "",
    "focus": ["bug", "test-coverage"]
  },
  "summary": { "total": 3, "critical": 0, "high": 0, "medium": 1, "low": 1, "info": 1 },
  "findings": [
    {
      "id": "F-001",
      "category": "bug",
      "severity": "medium",
      "file": "greeting.sh",
      "line": 3,
      "title": "Unknown flags are silently ignored",
      "description": "greeting.sh ignores unrecognized flags and prints the default greeting anyway, hiding user errors.",
      "suggestion": "Print a usage message to stderr and exit 2 when an unknown flag is passed.",
      "effort": "small"
    },
    {
      "id": "F-002",
      "category": "test-coverage",
      "severity": "low",
      "file": "verify.sh",
      "title": "verify.sh does not cover flag error handling",
      "description": "verify.sh only checks the default and shout greetings; a regression in flag handling would still pass verification.",
      "suggestion": "Add a check that an unknown flag exits non-zero once that behavior exists.",
      "effort": "small"
    },
    {
      "id": "F-003",
      "category": "code-quality",
      "severity": "info",
      "file": "greeting.sh",
      "title": "Greeting logic is simple and readable",
      "description": "The current structure is easy to extend; keep flag parsing in one place as flags are added.",
      "suggestion": "No action needed.",
      "effort": "small"
    }
  ]
}
EOF

cat > requirements.md <<'EOF'
# Greeting requirements

- `greeting.sh` must support a `--version` flag that prints `greeting 1.0.0` and exits 0.
- Unknown flags must print a usage message to stderr and exit 2.
- The default behavior (prints `hello`) must not change.
EOF
```

- [ ] **Step 2: Add the generator to lint**

`Makefile` lint target becomes:
```makefile
lint:
	shellcheck -x -s bash ralph.sh plugin/scripts/ralph-evidence.sh tests/make_sandbox.sh
```

- [ ] **Step 3: Verify**

```bash
make check
bash tests/make_sandbox.sh /tmp/ralph-sb-fixtures
cd /tmp/ralph-sb-fixtures && ./verify.sh \
  && jq -e '.verificationCommands == ["./verify.sh"]' .claude/ralph.json \
  && jq -e '.hooks.Stop' .claude/settings.json \
  && jq -e '.findings | length == 3' review-output/findings.json \
  && test -f requirements.md \
  && git status --porcelain | wc -l | grep -qx ' *0' \
  && diff .claude/settings.json /Users/g8s/Dev/ralph-starter/plugin/hooks/hooks.json \
  && echo FIXTURES-OK
cd / && rm -rf /tmp/ralph-sb-fixtures
```
Expected: `verify OK`, then `FIXTURES-OK` (clean tree confirms everything was committed; the `diff` confirms the settings hook is a byte-identical copy).

- [ ] **Step 4: Commit**

```bash
cd /Users/g8s/Dev/ralph-starter
git add tests/make_sandbox.sh Makefile
git commit -m "test: sandbox fixtures for spec/dev smoke runs (config, Stop hook, findings, requirements)"
```

---

### Task 4: `/ralph:spec` command

**Files:**
- Create: `plugin/commands/spec.md`

**Interfaces:**
- Consumes: `plugin/skills/writing-ralph-specs/SKILL.md` (Task 2, Read from plugin root — including its "Fix-specs from review findings (--from-findings)" section); `${CLAUDE_PLUGIN_ROOT}/scripts/ralph-evidence.sh` (validation gate); `.claude/ralph.json` `verificationCommands` (optional source); sandbox fixtures (Task 3).
- Produces: `specs/<slug>.json` — uncommitted, no branch. Slug = lowercase-hyphenated `project` field, the same derivation `build.md` uses for its `ralph/<slug>` branch. `dev.md` (Task 6) executes this file's procedure by reference.

- [ ] **Step 1: Write the command**

`plugin/commands/spec.md`:
```markdown
---
description: Generate a Ralph spec JSON — from a prompt, a requirements file, or review findings
argument-hint: '"<what to build>" | -f <requirements-file> | --from-findings [findings.json]'
---
# /ralph:spec — spec generator

Generate a Ralph spec from: $ARGUMENTS

You produce exactly one file: `specs/<slug>.json`. You do NOT commit, do
NOT create branches, and do NOT implement anything — spec generation is a
read-analyze-write activity. Committing happens later: `/ralph:build`'s
preflight commits a freshly generated spec on its work branch (Phase 1
step 3a), whether reached directly or via the /ralph:dev pipeline.

## Input (exactly one source; zero or several → abort, printing this Input section as usage)
- Bare text, or `-p "<text>"` → inline description of what to build.
- `-f <path>` → requirements read from that file. Abort if unreadable.
- `--from-findings [path]` → fix-spec from a findings backlog. Default
  path `review-output/findings.json`. Abort if the file is missing or
  not valid JSON.

## Procedure
1. Read `${CLAUDE_PLUGIN_ROOT}/skills/writing-ralph-specs/SKILL.md` and
   follow it for everything about spec content: the schema, task
   fields and their initial values, acceptance-criteria quality, and —
   for --from-findings — its "Fix-specs from review findings" rules.
2. Study the repo before writing: CLAUDE.md (conventions), the source
   files the work would touch, existing `specs/` for naming. Tasks must
   name real files and real commands.
3. Determine `context.verificationCommands`, in priority order:
   a. `.claude/ralph.json` → `verificationCommands`, if non-empty.
   b. The repo's documented test/lint commands (CLAUDE.md, README,
      Makefile targets, package.json scripts) — confirm a candidate is
      really defined (the target/script exists) before using it.
   c. Neither yields anything → ABORT: "cannot emit an unbuildable
      spec — no verification commands found. Add verificationCommands
      to .claude/ralph.json or state them in the request." Never invent
      commands.
4. Write `specs/<slug>.json` — slug is the lowercase, hyphenated form
   of the spec's `project` field (the same derivation /ralph:build uses
   for its branch name). If that file already exists: ABORT and report
   the collision — never overwrite an existing spec.
5. Validate by running
   `${CLAUDE_PLUGIN_ROOT}/scripts/ralph-evidence.sh specs/<slug>.json`
   and printing its real output. Exit 2 or 3 → fix the spec file and
   re-run; if you cannot get exit 0, ABORT and report exactly what is
   invalid (leave the file in place for inspection).
6. Tracking check: run `git check-ignore specs/<slug>.json`. Exit 0
   means the spec is gitignored — WARN prominently in your report: a
   gitignored spec cannot be committed, silently vanishes in worktrees
   and fresh clones, and /ralph:build will refuse it at Phase 1 step 3a
   (see the plugin README's "Artifact tracking" for the one-line
   migration).
7. Report: spec path; project name; a task table (id, title, effort,
   dependsOn); the verificationCommands and which source (3a or 3b)
   supplied them; the evidence-script output; and the next step —
   `/ralph:build specs/<slug>.json`.

## Content rules (enforced on top of the skill)
- tasks[] initial state: `status: "pending"`, `passes: false`,
  `attempts: 0`, `notes: ""`; top-level `verifier` omitted or null.
- ids sequential T-001, T-002, …; every `dependsOn` entry names an
  existing task id; no dependency cycles.
- Tasks atomic — one fresh-context builder session each; prefer 2–6
  tasks; split anything larger.
- Every acceptance criterion is checkable by running a command or
  inspecting a named file — no "works correctly".
```

- [ ] **Step 2: Validate the plugin**

Run: `claude plugin validate ./plugin`
Expected: passes.

- [ ] **Step 3: Smoke test S1 — inline prompt**

```bash
bash tests/make_sandbox.sh /tmp/ralph-sb-spec && cd /tmp/ralph-sb-spec
claude -p "/ralph:spec Add a --version flag to greeting.sh that prints 'greeting 1.0.0' and exits 0; unknown flags must exit 2 with usage on stderr; default hello output unchanged" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 15 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 5 > /tmp/p2-spec-p.jsonl 2>&1
```

Checklist (verify on disk and in the transcript, not from the final summary):
- A new `specs/*.json` (not `sandbox.json`) exists; `jq .` parses it.
- `context.verificationCommands == ["./verify.sh"]` — proves the `.claude/ralph.json` sourcing path (3a).
- Every task: `status=="pending"`, `passes==false`, `attempts==0`; ids sequential; `dependsOn` references valid.
- Transcript contains a Read tool_use of the plugin skill path and a Bash tool_use of `ralph-evidence.sh` on the new spec with the evidence block in its tool_result.
- No commit (`git log --oneline` still exactly 1 init commit), no branch (`git branch` = main only), spec untracked in `git status --porcelain`.

- [ ] **Step 4: Smoke test S2 — requirements file**

Same sandbox (delete the S1 spec first to avoid slug collisions: `rm specs/<s1-slug>.json`):
```bash
claude -p "/ralph:spec -f requirements.md" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 15 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 5 > /tmp/p2-spec-f.jsonl 2>&1
```
Checklist: spec derives its tasks from the file's three requirements (a `--version` task and an unknown-flag task at minimum, "hello unchanged" as a criterion or constraint); same structural checks as S1; transcript shows `requirements.md` was Read.

- [ ] **Step 5: Smoke test S3 — findings backlog**

Same sandbox (remove the S2 spec):
```bash
claude -p "/ralph:spec --from-findings" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 15 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 5 > /tmp/p2-spec-findings.jsonl 2>&1
```
Checklist: the fix-spec's tasks cite F-001 and/or F-002 in descriptions; **no task derives from F-003** (info skipped); each task's criteria include the fix behavior and a "verification commands still pass"-style criterion; severity ordering (F-001's fix before/above F-002's); same structural checks as S1. Then `cd / && rm -rf /tmp/ralph-sb-spec`.

- [ ] **Step 6: Record observations**

Append a "Task 4 smoke runs" section to `docs/superpowers/spikes/2026-07-plugin-skills.md`: invocations, outcomes per checklist item, any prompt adjustments made to `spec.md` (re-run the affected smoke test after any adjustment).

- [ ] **Step 7: Commit**

```bash
git add plugin/commands/spec.md docs/superpowers/spikes/2026-07-plugin-skills.md
git commit -m "feat(plugin): /ralph:spec command with prompt, file, and findings inputs"
```

---

### Task 5: `build.md` preflight amendment — commit a fresh spec on the work branch

Specs are tracked artifacts now, but `/ralph:spec` deliberately leaves its output uncommitted (standalone use = human reviews first, and it must never commit to the default branch). Without this amendment, `build.md`'s "git status clean" preflight makes the natural handoff (`/ralph:spec` → `/ralph:build`) and the entire `/ralph:dev` pipeline impossible. The amendment is the narrowest possible exception: only the target spec file, committed immediately on the work branch.

**Files:**
- Modify: `plugin/commands/build.md` (Phase 1 steps 2–3 only)

**Interfaces:**
- Consumes: nothing new.
- Produces: Phase 1 step 3a — referenced by name in `spec.md` (Task 4) and `dev.md` (Task 6). Numbering of existing steps 4–6 must NOT change (`plugin/README.md` cites "build.md Phase 1 step 5" and "step 6").

- [ ] **Step 1: Amend Phase 1 step 2**

In `plugin/commands/build.md`, replace:
```
2. `git status` clean.
```
with:
```
2. `git status` clean — with exactly one exception: the target spec file
   itself may be untracked or modified (a spec freshly generated by
   /ralph:spec or the /ralph:dev pipeline, not yet committed). Any other
   dirty or untracked path still aborts. If the spec file is dirty this
   way, step 3a commits it once you are on the work branch.
```

- [ ] **Step 2: Insert step 3a after step 3**

Immediately after the step 3 block (`3. Current branch is NOT the default branch, … passes:true are skipped naturally).`), insert:
```
3a. If the target spec file was untracked or modified in step 2: when it
   is untracked AND `git check-ignore <spec-path>` exits 0, ABORT — a
   gitignored spec can never be committed and silently vanishes in
   worktrees and fresh clones; point at the plugin README's "Artifact
   tracking" section for the one-line migration. Otherwise commit the
   spec file alone, now, on the work branch:
   `git add <spec-path> && git commit -m "chore: add spec for <project>"`.
```

- [ ] **Step 3: Validate**

Run: `claude plugin validate ./plugin && make check`
Expected: both green (no script or test touches build.md, but run the full gate anyway).

- [ ] **Step 4: Smoke test — other dirt still aborts (negative control first)**

```bash
bash tests/make_sandbox.sh /tmp/ralph-sb-bcommit && cd /tmp/ralph-sb-bcommit
REMOTE=$(mktemp -d) && git init -q --bare "$REMOTE" && git remote add origin "$REMOTE"
cat > specs/version-flag.json <<'EOF'
{
  "project": "Version flag",
  "description": "Add --version to greeting.sh",
  "context": {
    "currentState": "greeting.sh has no version flag",
    "targetState": "greeting.sh --version prints greeting 1.0.0",
    "constraints": ["bash only"],
    "verificationCommands": ["./verify.sh"]
  },
  "tasks": [
    {
      "id": "T-001",
      "title": "Add --version flag",
      "description": "greeting.sh --version prints 'greeting 1.0.0' and exits 0. Default output stays 'hello'.",
      "acceptanceCriteria": [
        "./greeting.sh --version outputs 'greeting 1.0.0'",
        "./greeting.sh still outputs hello",
        "./verify.sh exits 0"
      ],
      "dependsOn": [],
      "status": "pending",
      "passes": false,
      "effort": "small",
      "notes": "",
      "attempts": 0
    }
  ]
}
EOF
echo "# unrelated dirt" >> verify.sh
claude -p "/ralph:build specs/version-flag.json" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 6 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 3 > /tmp/p2-build-dirty-abort.jsonl 2>&1
git checkout verify.sh
```
Checklist: the run ABORTS in preflight (dirty `verify.sh` alongside the untracked spec); no `ralph/*` branch created (`git branch`), no builder dispatched, no commit added.

- [ ] **Step 5: Smoke test — uncommitted spec is committed on the branch (happy path)**

Same sandbox, now clean except the untracked spec:
```bash
claude -p "/ralph:build specs/version-flag.json" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 25 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 10 > /tmp/p2-build-uncommitted-spec.jsonl 2>&1
```
Checklist:
- Preflight proceeds; branch `ralph/version-flag` created.
- FIRST commit on the branch is `chore: add spec for Version flag` touching only `specs/version-flag.json` (`git log main..ralph/version-flag --oneline --name-only`).
- Build completes: builder dispatch for T-001, verifier PASS written to the spec, exactly one `git push`, honest report of the `gh pr create` failure against the local bare remote, `main` unchanged, `.ralph-goal` absent afterward.
- (A 1-task spec has TURN_CAP=2 — if the run lands in a partial draft-PR stop instead because the builder or verifier needed a retry, that is the failure path working as designed, not a test failure: verify the partial-PR behavior, then rerun once for the happy-path evidence.)

Then `cd / && rm -rf /tmp/ralph-sb-bcommit "$REMOTE"`.

- [ ] **Step 6: Record observations**

Append a "Task 5 smoke runs" section to `docs/superpowers/spikes/2026-07-plugin-skills.md` (same format as Task 4's).

- [ ] **Step 7: Commit**

```bash
git add plugin/commands/build.md docs/superpowers/spikes/2026-07-plugin-skills.md
git commit -m "feat(plugin): build preflight commits a freshly generated spec on the work branch"
```

---

### Task 6: `/ralph:dev` command

**Files:**
- Create: `plugin/commands/dev.md`

**Interfaces:**
- Consumes: `plugin/commands/spec.md` (Task 4) and `plugin/commands/build.md` (Task 5, incl. step 3a) — both executed by Reading them from `${CLAUDE_PLUGIN_ROOT}` (platform fact 1 forbids emitting `/ralph:...` as text).
- Produces: the full pipeline command; nothing downstream consumes it in this plan.

- [ ] **Step 1: Write the command**

`plugin/commands/dev.md`:
```markdown
---
description: Ralph dev pipeline — generate a spec, then build it; --review pauses for approval
argument-hint: '"<what to build>" [--review]'
---
# /ralph:dev — spec → build pipeline

Run the full Ralph pipeline for: $ARGUMENTS

Two phases: Phase A generates and validates a spec exactly as /ralph:spec
does; Phase B executes /ralph:build's procedure on the result. You are
one session throughout — in Phase B you become the build ORCHESTRATOR
with everything that implies (you never edit source files; builders
build). A slash command cannot invoke another slash command — you compose
them by reading the command files below and executing their procedures.

## Phase A — spec
1. Strip `--review` from the arguments if present and remember it. The
   remaining arguments are the spec input (same three source forms as
   /ralph:spec: bare/-p text, -f <file>, --from-findings [path]).
2. Read `${CLAUDE_PLUGIN_ROOT}/commands/spec.md` and execute its full
   procedure on that input — every rule applies (single input source,
   the skill, verificationCommands sourcing, no overwrite, evidence-
   script validation, tracking check, no commit). Skip only its closing
   "next step" suggestion; this pipeline continues below instead.
3. If spec generation aborted for any reason: STOP and report the abort
   reason. Never proceed to build without a validated spec file.

## Gate — only when --review was passed
Present the spec (project, task table, verificationCommands) and END
YOUR TURN asking for approval. Proceed only after the user approves; if
they request changes, edit the spec file, re-run the evidence-script
validation, and ask again. Without --review, proceed immediately.
(--review is meaningless in a headless run — no one can answer; the
session will simply end after Phase A with the spec written and
reported, which is the correct, safe outcome.)

## Phase B — build
Read `${CLAUDE_PLUGIN_ROOT}/commands/build.md` and execute it exactly as
written, as the orchestrator, with Phase A's spec path as its argument.
Its preflight handles the work branch and commits the still-uncommitted
spec file (Phase 1 step 3a). Every rule applies unchanged: the caps, the
`.ralph-goal` lifecycle, evidence blocks produced by really running the
script, builder and verifier dispatches, single push at PR time, draft
partial PRs on terminal stops, never merging, no attribution lines.

Final report: the spec path and how it was produced, then the build
outcome exactly as build.md's terminal phase reports it.
```

- [ ] **Step 2: Validate the plugin**

Run: `claude plugin validate ./plugin`
Expected: passes.

- [ ] **Step 3: Smoke test D1 — full pipeline, happy path**

```bash
bash tests/make_sandbox.sh /tmp/ralph-sb-dev && cd /tmp/ralph-sb-dev
REMOTE=$(mktemp -d) && git init -q --bare "$REMOTE" && git remote add origin "$REMOTE"
claude -p "/ralph:dev Add a --version flag to greeting.sh that prints 'greeting 1.0.0' and exits 0; extend verify.sh to check it; the default hello output must not change" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 40 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 20 > /tmp/p2-dev-happy.jsonl 2>&1
```
Checklist (transcript + repo state):
- Transcript shows Read tool_use of BOTH `${CLAUDE_PLUGIN_ROOT}/commands/spec.md` and `.../commands/build.md` (and the skill via spec.md's procedure).
- A new spec file exists, was validated by the evidence script (exit 0 in a tool_result), and `verificationCommands == ["./verify.sh"]`.
- Branch `ralph/<slug>` created; its FIRST commit is `chore: add spec for <project>` (step 3a working through the pipeline).
- At least one `ralph:ralph-builder` dispatch; `ralph:ralph-verifier` dispatched at completion; verifier PASS written into the spec.
- Exactly one `git push`; `gh pr create` attempted and its local-remote failure reported honestly; `main` unchanged; `.ralph-goal` deleted (absent on disk).
- No attribution lines in the attempted PR title/body or any commit message.

- [ ] **Step 4: Smoke test D2 — `--review` pauses after Phase A**

```bash
bash tests/make_sandbox.sh /tmp/ralph-sb-devrev && cd /tmp/ralph-sb-devrev
claude -p "/ralph:dev --review Add a --version flag to greeting.sh that prints 'greeting 1.0.0' and exits 0" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 15 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 5 > /tmp/p2-dev-review.jsonl 2>&1
```
Checklist:
- Session ends normally after Phase A (`terminal_reason: "completed"`), with the final message presenting the spec and asking for approval.
- Spec file exists, validated, untracked; NO branch beyond main; NO Agent dispatches; NO `.ralph-goal` ever created; zero commits beyond the sandbox init commit.
- (This also confirms the sandbox Stop hook allows a stop when no `.ralph-goal` exists.)
Optionally, additionally verify the interactive approval flow by running `/ralph:dev --review …` in a supervised interactive session in a fresh sandbox and approving when asked — record what happened either way.

Then clean up: `cd / && rm -rf /tmp/ralph-sb-dev /tmp/ralph-sb-devrev "$REMOTE"`.

- [ ] **Step 5: Record observations**

Append a "Task 6 smoke runs" section to `docs/superpowers/spikes/2026-07-plugin-skills.md`.

- [ ] **Step 6: Commit**

```bash
git add plugin/commands/dev.md docs/superpowers/spikes/2026-07-plugin-skills.md
git commit -m "feat(plugin): /ralph:dev spec-to-build pipeline with --review gate"
```

---

### Task 7: README, version bump, final gate

**Files:**
- Modify: `plugin/README.md`
- Modify: `plugin/.claude-plugin/plugin.json` (version `0.1.0` → `0.2.0`)

**Interfaces:**
- Consumes: Task 1's spike verdict on skill registration (README wording), everything shipped in Tasks 2–6.

- [ ] **Step 1: Update the commands table**

In `plugin/README.md`, replace the `/ralph:spec` and `/ralph:dev` rows ("Coming in Plans 2–3") with:
```markdown
| `/ralph:spec "<prompt>" \| -f <file> \| --from-findings [path]` | Generate a validated spec JSON in `specs/` (no commit — review, then build) |
| `/ralph:dev "<prompt>" [--review]` | Full pipeline: generate spec → build it; `--review` pauses for spec approval |
```
(`/ralph:review` and `/ralph:improve` keep their "Coming" rows, now reading "Coming in Plan 3".)

- [ ] **Step 2: Add a "Spec generation & the dev pipeline" section**

Insert after the Commands section, content (adjust the final sentence per Task 1's spike verdict — keep it if the skill registers, drop it if not):
```markdown
## Spec generation & the dev pipeline

`/ralph:spec` writes `specs/<slug>.json` from one input source — inline
text, `-f <requirements-file>`, or `--from-findings [findings.json]`
(fix-spec from a review backlog; default path
`review-output/findings.json`). Every generated spec is validated with
the plugin's evidence script before the command reports success, and
`context.verificationCommands` is sourced from `.claude/ralph.json` or
the repo's documented test commands — if neither exists the command
aborts rather than emit an unbuildable spec. The spec is left
uncommitted for human review; `/ralph:build`'s preflight commits a fresh
spec as the first commit on its `ralph/*` work branch (and refuses
gitignored specs — see Artifact tracking above).

`/ralph:dev` chains the two: spec generation, an optional `--review`
pause for human approval, then the full build engine. Headless example
(same flag requirements as the build invocation below):

    claude -p "/ralph:dev Add feature X" \
      --plugin-dir /path/to/ralph-starter/plugin \
      --permission-mode acceptEdits \
      --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
      --setting-sources project \
      --max-turns 40 \
      --max-budget-usd 20

Do not pass `--review` headlessly — with no one to approve, the session
ends after spec generation (safe, but probably not what you wanted).

The spec-writing guidance ships as a plugin skill
(`plugin/skills/writing-ralph-specs/`), which both commands follow.
```

- [ ] **Step 3: Bump the plugin version**

`plugin/.claude-plugin/plugin.json`: `"version": "0.2.0"`.

- [ ] **Step 4: Full gate**

```bash
make check
claude plugin validate ./plugin
```
Expected: BATS all pass, shellcheck clean (now including `tests/make_sandbox.sh`), plugin validates.

- [ ] **Step 5: Commit**

```bash
git add plugin/README.md plugin/.claude-plugin/plugin.json
git commit -m "docs(plugin): spec/dev command docs; bump plugin to 0.2.0"
```

---

## Self-review notes (completed during planning)

- **Handoff scope coverage:** `/ralph:spec` with `-p`/`-f`/`--from-findings` → Task 4; non-empty `verificationCommands` enforcement → Task 4 step 3 + evidence-script validation (exit 3 = abort); `/ralph:dev` auto-continue + `--review` → Task 6; skill port → Task 2; `models` wiring → not applicable (no routing introduced — Decision 4).
- **Consistency:** slug derivation identical in spec.md step 4 and build.md's existing branch rule; "Phase 1 step 3a" named identically in spec.md, build.md, dev.md, and the README section; the skill's "Fix-specs from review findings (--from-findings)" heading matches spec.md's reference; findings fixture matches the reviewing-codebase schema (`id`/`category`/`severity`/`file`/`title`/`description`/`suggestion`/`effort` + `summary` counts).
- **Numbering safety:** build.md steps 4–6 keep their numbers (README cites step 5 and step 6); 3a insertion avoids renumbering.
- **Known carried items (unchanged from the handoff):** `status.md` untested against real GitHub `ralph/*` PRs (sandbox remotes are local bare repos — still deferred); dated model ID duplication stays at two copies (hooks.json + README — Task 3 copies the file rather than adding a third); the 2-hour goal clause remains transcript-unevaluable (orchestrator cap check covers it).
