# Design: `ralph` — Native Claude Code Plugin (Port of Ralph Loop)

**Status:** Approved design pending final user review
**Date:** 2026-07-19
**Reviewed by:** Fable adversarial design review (2 blockers, 5 majors — all resolved below)

## 1. Context & Goals

ralph-starter is a 4,341-line bash script wrapping `claude -p` in an iterate-until-done loop (modes: inline, build, spec, plan, product, review, dev, launch, setup). This design ports it to native Claude Code primitives as a **distributable plugin**. The bash implementation stays untouched until the parity gate (§9) passes.

Confirmed decisions:

1. **Architecture:** plugin + `/goal`-driven orchestrator dispatching fresh-context subagents (one per task).
2. **Auto-improve triggers:** local `/loop` **and** cloud routines — both drive the same headless, worktree-isolated unit of work.
3. **v1 scope:** `go`, `spec`, `build`, `dev`, `review`, `improve`, `status`. Product, launch, and plan modes deferred to v2.
4. **State format:** existing Ralph spec JSON schema (`tasks[]` with `id/title/description/acceptanceCriteria/dependsOn/status/passes/effort/notes`) remains the on-disk source of truth.
5. **Artifact persistence:** specs and the findings backlog are **tracked in git** (reverses today's gitignore — see §7).
6. **Autonomy:** PR-gated. Agents push only `ralph/*` branches and open PRs; nothing merges without human review.

### Why port (research findings)

Native primitives cover ~85% of Ralph and are strictly better on safety: `--max-budget-usd` (bash has zero cost controls), independent goal evaluator (vs. trusting a self-reported `<ralph>COMPLETE</ralph>` marker), permission modes (vs. hardcoded `--dangerously-skip-permissions`), worktree isolation, subagent parallelism, and no fragile stream-JSON parsing. Plugin distribution replaces the submodule/symlink/path-rebasing apparatus (~45 flags, 16 env vars, 14 conf keys).

### The three structural discrepancies the design engineers around

1. **Fresh context.** Bash Ralph runs a cold `claude -p` per iteration; `/goal` grows one session context (context rot). → Lean orchestrator + fresh builder subagent per task (§4).
2. **Blind evaluator.** `/goal`'s evaluator reads only the transcript — no tools, no files. → Deterministic evidence contract (§4.4).
3. **Local unattended longevity.** `/loop` is session-scoped (7-day expiry, jitter, requires live session). → True unattended runs live on cloud routines; local ticks are session-independent headless spawns (§5).

## 2. Plugin shape & command surface

Standard Claude Code plugin developed in `ralph-starter/plugin/`, installable via git path now, marketplace later:

```
plugin/
├── .claude-plugin/plugin.json
├── commands/                  # markdown → /ralph:* slash commands
│   ├── go.md                  # one-off task (replaces inline mode)
│   ├── spec.md                # generate spec JSON (wraps writing-ralph-specs skill)
│   ├── build.md               # goal-driven build from spec (§4)
│   ├── dev.md                 # spec → build pipeline (auto-continue; --review pauses at spec)
│   ├── review.md              # codebase analysis → findings + report (wraps reviewing-codebase)
│   ├── improve.md             # one bounded improvement cycle (§5)
│   └── status.md              # active goal, spec progress, open ralph PRs, backlog summary
├── agents/
│   ├── ralph-builder.md       # fresh-context task executor
│   └── ralph-verifier.md      # independent adversarial reviewer
├── skills/
│   ├── writing-ralph-specs/   # ported as-is
│   └── reviewing-codebase/    # ported as-is
├── scripts/
│   └── ralph-evidence.sh      # deterministic evidence printer (§4.4)
├── hooks/
│   └── (fallback Stop-hook prompt, only if the /goal spike fails — §9)
└── routines/
    └── improve-nightly.md     # prompt template for /schedule
```

Use-case mapping: one-offs → `/ralph:go` · planning/specs → `/ralph:spec` · features → `/ralph:dev` or `/ralph:build` · auto-improve → `/ralph:improve` via `/loop` or routine.

**Model routing** (bash parity: inline was deliberately sonnet-class for cost): `/ralph:go` → sonnet-class; builder → session model; verifier → never a weaker model than the builder; goal evaluator → platform default (Haiku-class). Overridable in config (§8).

## 3. Command semantics (non-build)

- **`/ralph:go "prompt"`** — single-session one-off: branch-first, implement, verify with the host's verification commands, commit; `--pr` opens a PR, default leaves the branch local.
- **`/ralph:spec`** — invokes writing-ralph-specs skill; sources: `-p` inline, `-f` file, `--from-findings` (fix-spec from backlog). Output `specs/{slug}.json`, committed on a branch when part of a pipeline.
- **`/ralph:review [--diff-base REF] [--focus cats]`** — read-only; fans out one subagent per focus category in parallel (replaces bash's one-module-per-iteration serialization); merges results into the tracked findings backlog + human-readable report.
- **`/ralph:dev "prompt"`** — spec → build, auto-continue (bash behavior); `--review` pauses for human spec approval between phases.
- **`/ralph:status`** — read-only dashboard: active goal, spec task table, open `ralph/*` PRs, backlog counts, running local ticks.

## 4. Build engine

`/ralph:build specs/foo.json` runs in the current session as a goal-driven orchestrator.

### 4.1 Preflight (hard requirements, not conventions)

- Refuse to write on the default branch; create `ralph/{slug}` (fail with guidance if it exists — `--continue-branch` reuses it, resuming from spec state: tasks with `passes:true` are skipped, giving task-level resume without bash's `.ralph-session.json`).
- Validate spec JSON against schema.
- **Require non-empty `context.verificationCommands`** — without independent verification the evidence chain degrades to self-report; the build refuses to start rather than run unverifiable.
- `git status` must be clean.

### 4.2 Goal contract

Set `/goal` with condition (single lifecycle — verifier folded in, so evaluator-yes cannot fire before verification):

> "The RALPH EVIDENCE block printed this turn shows every task in specs/foo.json with status=complete and passes=true, every verification command exiting 0, **and a ralph-verifier verdict of PASS** — or stop after {2×task_count} turns or 2 hours."

### 4.3 Turn contract (orchestrator stays lean)

1. Preflight the tree: if dirty (crashed builder), apply the recovery policy — stash the dirty diff and hand it to the next builder dispatch as context.
2. Select the next task whose `dependsOn` are all `passes:true`, skipping `status:blocked`.
3. Mark `in_progress`; dispatch **synchronously** (never backgrounded — a backgrounded builder would let the evaluator fire on an empty turn and cause double-dispatch) to a **ralph-builder** subagent: fresh context receiving only the task card, acceptance criteria, spec context block, and repo-conventions pointer.
4. Builder implements, runs task-level verification, commits `feat(T-xxx): title`.
5. Orchestrator updates spec JSON (`passes:true`, `status:complete`, `notes`) and commits the spec change; appends progress.txt (untracked, ephemeral).
6. Print the evidence block (§4.4).

**Failure path (the common case the caps exist for):** builder failure → increment an `attempts` counter in task metadata; at 2 failed attempts mark `status:blocked` with the failure reason in `notes` and move on. When all remaining tasks are blocked, or the turn/time cap hits: push the branch and open a **draft PR labeled `ralph:partial`** with the evidence table in the body. Partial work is always surfaced, never abandoned.

**Orchestrator discipline (honest caveat):** builder and verifier separation is mechanical (separate agent contexts); the orchestrator is the main session and cannot be tool-restricted, so "orchestrator never edits source directly" is a hard prompt rule, and the verifier flags any commit **touching source files** that wasn't authored via a builder dispatch (orchestrator commits to the spec and backlog are expected and exempt). This is the one guardrail that is a convention rather than a mechanism.

### 4.4 Evidence contract (tiered)

`${CLAUDE_PLUGIN_ROOT}/scripts/ralph-evidence.sh <spec> [--full]` prints deterministically:

- **Every turn (cheap):** task-status table read from the spec JSON, truncated to a fixed-size summary (counts + last-changed tasks) to avoid evidence-table context bloat.
- **Completion-claim turns only (`--full`):** each spec-level verification command executed with its real exit code, plus the verifier verdict line. A completion-claim turn is the first turn (and any subsequent turn) on which the status table shows every task complete with `passes:true`.

The evaluator judges only this output. Honest scoping of the guarantee: exit codes are the independent signal; the task table reflects orchestrator-written state. The preflight requirement (§4.1) is what keeps the chain anchored to real verification. Hardening option if the spike (§9) shows the evaluator can't distinguish genuine tool output from printed text: emit the block via a plugin Stop hook so the harness, not the model, produces it.

### 4.5 Completion

Evaluator sees a full evidence block with all tasks passing → orchestrator dispatches **ralph-verifier** (separate context, adversarial prompt: refute completion; hunt stubs, placeholder implementations, weakened or deleted tests, unmet acceptance criteria; flag non-builder commits) against the full branch diff vs. the spec. Verifier findings → fix turns within the same goal lifecycle and caps. On PASS: **rebase onto the default branch** (conflicts = stop and report in a draft PR; never auto-resolve), push `ralph/{slug}` once, `gh pr create`. **Never merges.**

Sequential task execution in v1. Parallel builders in separate worktrees for independent DAG branches: v2.

## 5. Auto-improve pipeline

`/ralph:improve` = one bounded cycle, always executed **headlessly inside a fresh worktree** — never in the invoking session's checkout or goal slot:

1. **Review:** scoped analysis (parallel subagents per category) → merge into the tracked findings backlog (`review-output/findings.json`, schema unchanged plus `addressed: <PR#|null>`).
2. **Select:** top-N findings by severity (default N=3 per cycle, configurable), skipping findings already `addressed`, findings whose file-paths intersect an open `ralph/*` PR diff (`gh pr diff`), and findings that fail revalidation (file/line still exists, symptom still reproducible — humans fix things too).
3. **Fix:** generate fix-spec → mini-build using the §4 engine with improve-tier caps (defaults: 15 turns, 1 hour, $10 — configurable via §8 `defaultBudgets`) → PR (backlog update committed inside the same PR).

**Triggers:**
- **Local:** `/loop /ralph:improve` — each tick spawns a managed background `claude -p "/goal …" --max-turns N --max-budget-usd X` in a mandatory fresh worktree (tick fails with a message if a worktree can't be created). The interactive session is never touched; every cycle gets fresh context; a tick skips itself if a previous tick's process or PR is still open.
- **Cloud:** `/schedule` nightly routine — fresh clone, same command, PR delivered. Routine template must verify the plugin is installed in the fresh clone (repo-level plugin declaration); until confirmed, the template inlines the improve instructions to prevent trigger drift.

Same unit of work → identical behavior across triggers (this was the point of decision 2, and the worktree+headless design is what makes it actually true).

## 6. Guardrails

- **Branch-first, always** — every writing command refuses the default branch.
- **Single push at PR time** — no per-iteration push; only `ralph/*` branches are ever pushed. (Bash pushed every iteration and silently created remote branches — the class of incident this design exists to prevent.)
- **Caps everywhere** — every goal carries turn + wall-clock stop clauses; every headless spawn carries `--max-turns` and `--max-budget-usd`. `--unlimited` is not ported. Known limit: no native in-session dollar cap exists, so interactive builds rely on turn/time caps.
- **Author ≠ evaluator ≠ verifier** — separate contexts; prompts hard-forbid weakening tests or CI ("any change that weakens CI is a blocker").
- **Kill switches** — `/goal clear` (session builds), process stop for headless ticks, routine pause in the UI, `/ralph:status` for visibility.

## 7. State & artifact tracking

Reverses today's gitignore for load-bearing artifacts (currently `specs/*`, `review-output/`, `progress.txt` are all ignored, which breaks fresh-clone routines, worktrees — which only materialize tracked files — and PR-visible task state):

| Artifact | v1 policy |
|---|---|
| `specs/*.json` | **Tracked.** Status updates committed on the `ralph/*` branch — spec churn is part of the reviewable PR diff. |
| `review-output/findings.json` | **Tracked.** The persistent improve backlog; updates committed inside fix PRs. |
| `review-output/REVIEW_REPORT.md` | Tracked (derived, regenerated). |
| `progress.txt` | Untracked, ephemeral. Nothing load-bearing reads it. |
| Session files (`.ralph-*.json`) | Gone — native resume + spec state replace them. |

Host repos adopting the plugin get a one-line gitignore migration note. This repo's own gitignore changes when the plugin lands.

## 8. Host integration & migration

- **Install:** plugin install (git/marketplace) replaces `git submodule add` + `setup` symlinks + path rebasing.
- **Config:** one `.claude/ralph.json` per host repo: `verificationCommands`, `sourceDirs`, `defaultBudgets` (turns/hours/USD), `reviewFocus`, `models`, `artifactPaths`. Defaults preserve today's standalone layout (`specs/`, `review-output/`). **Submodule deployments:** existing artifacts live under `ralph-starter/specs/` etc. — migration is either `artifactPaths: "ralph-starter/*"` or moving the files; documented, one line each.
- **Portability caveat:** the evidence script requires a POSIX shell (macOS/Linux/WSL/git-bash); pure Windows without git-bash is unsupported in v1.
- **Explicitly dropped:** webhook notifications (routines/PushNotification cover it), retry/backoff + stream parsing (harness-owned), `--unlimited`, per-iteration push, `.ralph-session.json` resume (replaced per §4.1).

## 9. Feasibility spikes & parity gate

**Day-one spike (before any other build-out):** can a plugin command prompt arm `/goal` programmatically? Success → §4 as written. Failure → named fallback, in order: (a) plugin-shipped Stop-hook prompt evaluating the same condition (documented equivalent pattern), (b) command spawns headless `claude -p "/goal …"` in a worktree (build becomes worktree-based like improve). Second spike, same session: does the evaluator treat printed text differently from tool output (decides the Stop-hook evidence hardening in §4.4)?

**Parity gate (build engine) — all must hold before deprecating bash:**
1. Same feature spec, **≥2 runs**: all tasks complete, verification commands pass on the PR branch.
2. Verifier verdict PASS on each run.
3. **Zero pushes before PR-time and zero writes on the default branch**, asserted from reflog and remote state.
4. **Adversarial spec containing one unsatisfiable task** ends in a graceful cap-stop with a partial draft PR and no completion claim.

Spec/review/improve modes gate on N supervised runs each (N=3) with human-judged output quality. Case 4 is the most informative test in the plan: it proves the failure path, the caps, and the honesty of the evidence chain simultaneously.

## 10. Open questions

- `/goal` availability inside cloud routine runs — assumed, unconfirmed; fallback mirrors the §9 spike fallbacks.
- Whether repo-level plugin declarations are honored in routine fresh clones (§5 mitigation in place until confirmed).
- Workflow-run resumability across sessions — affects only the v2 parallel-review upgrade, not v1.
