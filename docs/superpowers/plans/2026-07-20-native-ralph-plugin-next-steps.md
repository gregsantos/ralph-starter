# Native Ralph Plugin — Next Steps (Plans 2 & 3 Handoff)

**Date:** 2026-07-20
**State:** Plan 1 (foundation) is COMPLETE and merged to `main` at `5379803`. All 13 tasks executed via subagent-driven development, each adversarially reviewed; final whole-branch review verdict: ready to merge. `make check` = 94/94 BATS + shellcheck clean; `claude plugin validate ./plugin` passes.

**A new session should read, in order:** this file → `docs/superpowers/specs/2026-07-19-native-ralph-port-design.md` (the approved design; §5 improve pipeline and §9 parity gate are the unbuilt parts) → `docs/superpowers/spikes/2026-07-goal-arming.md` (the evidence record — platform facts below are sourced there) → `plugin/README.md` (what ships today).

## What exists today (Plan 1 deliverables, all e2e-proven)

- `/ralph:build` — goal-driven orchestrator (`plugin/commands/build.md`): `.ralph-goal` condition file + prompt-type Stop-hook evaluator (`plugin/hooks/hooks.json`), fresh `ralph:ralph-builder` subagent per spec task, `ralph:ralph-verifier` adversarial gate, deterministic evidence via `plugin/scripts/ralph-evidence.sh` (format frozen by `tests/plugin_evidence.bats`), transcript-visible turn/time caps checked before every builder dispatch, single push at PR time, draft `ralph:partial` PRs on terminal stops, never merges.
- `/ralph:go` — one-off tasks (branch-first, verify, commit; `--pr` optional). `/ralph:status` — read-only dashboard.
- Sandbox harness for supervised smoke tests: `tests/make_sandbox.sh`.
- Host config example `.claude/ralph.json` (only `verificationCommands` is live — consumed by `/ralph:go`; `defaultBudgets`/`models`/`reviewFocus`/`artifactPaths` are RESERVED for Plans 2-3 and must be wired up when their consumers are built).

## Platform facts a new session MUST NOT re-derive (all spike-verified)

1. **Slash commands cannot be invoked from assistant output.** A command's markdown can't arm `/goal`; that's why the engine uses the `.ralph-goal` file + Stop hook (design's FALLBACK).
2. **Plugin-shipped hooks DO NOT fire under `--setting-sources project`.** Interactive sessions: plugin hooks fire. Headless/unattended runs that isolate settings: the host repo MUST duplicate the Stop-hook into its own `.claude/settings.json` (copy-paste snippet is in `plugin/README.md`). This binds Plan 3's improve loop and routine template directly.
3. **`--permission-mode acceptEdits` alone strands agents** — Bash calls get auto-rejected until the session aborts. Headless spawns need `--allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep"` (+ `--max-turns`, `--max-budget-usd`).
4. **`--setting-sources project` is required for headless runs** to prevent user-settings contamination (a user-level git-push approval gate silently denied a build's push in e2e) — but see fact 2 for the hook cost.
5. **Evaluator provenance is opt-in (HARDEN):** goal conditions must explicitly require evidence "produced by running the script as a real command execution, visible as tool output" or plain-text fabrications satisfy the judge. Residual risk (untested): Write-then-Read laundering — the verifier cross-check must stay mandatory.
6. **Plugin agents register as `ralph:ralph-builder` / `ralph:ralph-verifier`.** Parse their output by SEEKING the `BUILDER REPORT` / `VERIFIER REPORT` marker line (agents may emit prose before the block).
7. **Spec fields build mode writes:** per-task `attempts` (int; blocked at 2), top-level `verifier` `{verdict, date, summary}` (see `specs/example.json`).

## Plan 2 — Spec & Dev pipeline (write the plan, then execute)

Scope from the design (§2-3): `/ralph:spec` (wrap the existing `.claude/skills/writing-ralph-specs` skill; inputs `-p`/`-f`/`--from-findings`; output `specs/{slug}.json` — must emit non-empty `context.verificationCommands` or builds refuse to start), `/ralph:dev` (spec → build auto-continue; `--review` flag pauses for human spec approval), port the writing-ralph-specs skill into `plugin/skills/`. Wire `models` config field if introducing model routing.

## Plan 3 — Review & Improve (the auto-improve flywheel)

Scope from the design (§5): port `reviewing-codebase` skill; `/ralph:review` (parallel subagents per focus category → tracked `review-output/findings.json` with `addressed: <PR#|null>`); `/ralph:improve` = review → select top-N (skip addressed/open-PR-overlapping/stale findings) → fix-spec → mini-build via the §4 engine with improve-tier caps → PR, executed **headlessly in a fresh worktree** (never the user's session/goal slot/checkout); local trigger = `/loop /ralph:improve` spawning the headless unit; cloud trigger = `/schedule` routine template (must verify plugin availability in fresh clones — open question — and carry the settings-hook duplication per platform fact 2). **Gitignore migration:** this repo (and host guidance) still ignores `specs/*` and `review-output/` — Plan 3 flips them to tracked per design §7. **Parity gate** (design §9, 4-point checklist incl. the adversarial unsatisfiable-task spec — partially proven already in Plan 1's e2e scenario B) before deprecating bash ralph.sh.

## Deferred/logged items (from the SDD ledger, triaged at final review)

- `status.md` smoke-tested only in sandbox — test against real `ralph/*` branches/PRs once they exist (Plan 2/3).
- Dated model ID `claude-haiku-4-5-20251001` duplicated in `plugin/hooks/hooks.json` + README snippet — will rot; consider indirection.
- Goal condition's 2-hour clause isn't transcript-evaluable (only BUILD_START is printed) — orchestrator's own cap check covers it; adding a current timestamp to the RALPH TURN line would make it evaluable.
- The `.superpowers/sdd/progress.md` ledger (untracked scratch) holds the full task-by-task execution record if archaeology is ever needed.

## Process that worked (recommended for Plans 2-3)

Brainstorm → design already done (the design doc covers Plans 2-3 scope). Per plan: superpowers:writing-plans (complete code/content in tasks; spikes first for any unverified platform assumption) → superpowers:subagent-driven-development (fresh implementer per task + adversarial task reviews — they caught one Critical state-machine gap and one MAJOR platform finding that e2e alone would have missed) → whole-branch final review on the strongest model. All supervised smoke tests in the sandbox (`tests/make_sandbox.sh`), never against a real repo; PR-gated always; no attribution lines in commits or PRs.
