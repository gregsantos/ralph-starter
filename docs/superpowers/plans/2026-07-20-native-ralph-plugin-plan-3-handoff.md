# Native Ralph Plugin — Plan 3 Mid-Execution Handoff

**Date:** 2026-07-20 (evening)
**State:** Plans 1–2 are COMPLETE and merged (`main` @ `4c40767`, pushed to origin). Plan 3 is mid-execution on branch `feature/ralph-plugin-plan-3` @ `814958e` (10 commits from main). Tasks 1–5 of 10 are complete, each implemented by a fresh subagent and adversarially reviewed (superpowers:subagent-driven-development). Task 6 is mid-flight and was stopped CLEANLY for this handoff — no processes were left running (verified `pgrep` empty).

**A new session should read, in order:** this file → `docs/superpowers/plans/2026-07-20-native-ralph-plugin-plan-3-review-improve.md` (the approved plan — its Global Constraints are binding, especially the no-orphan directive) → `docs/superpowers/spikes/2026-07-improve-mechanics.md` (Task 1 verdicts + Task 4/5 smoke appendices) → `.superpowers/sdd/progress.md` (untracked scratch ledger; full task-by-task record incl. riding minors).

## Completed tasks (evidence lives in the spike doc appendices + these commits)

- **T1 spike** (`11a70af` + fix `022f9a2`): (a) headless claude inside a git worktree works (plugin loads, commits land on worktree branch, main untouched); (b) parallel Agent dispatch PARALLEL-OK (N tool_use blocks, one assistant message); (c) **CHILD-SURVIVES** — plain-`&` background children outlive the spawning session; kill switch verified working; (d) native `/goal` via `-p` **NO-GO** (forwarded as literal text; recorded as v2 platform request).
- **T2** (`0dc56c2`): gitignore migration — `specs/`, `review-output/` now trackable; `.claude/settings.json` (byte copy of `plugin/hooks/hooks.json`) now TRACKED so worktrees/clones materialize the Stop-hook safety net.
- **T3** (`870429e`): reviewing-codebase skill ported to `plugin/skills/` with the `addressed` field (null=open, PR# = fixed, `stale-<date>` = resolved externally).
- **T4** (`d4f3807` + fix `4225081`): `/ralph:review` live — R1 (5 parallel category agents, merge/dedup/id-continuation proven), R2 (`--focus`, passed on attempt 3 after two transport api_errors — honestly recorded), R3 (`--diff-base`). **PLATFORM FINDING (follow-up owed):** a headless session's resume-after-async-task leg re-inits advertising the operator's full ambient MCP roster (30 servers) despite `--setting-sources project`; session_id/plugin/permissionMode/model/cwd stayed pinned and no `mcp__*` tool was invoked — isolation leak surface, not exploited.
- **T5** (`7e14880`): build.md wired to `defaultBudgets.buildTurnsFactor`/`buildHours` (defaults 2/2 preserve old behavior) + the RALPH TURN line now carries `, now <ISO timestamp>` (wall-clock clause is finally transcript-evaluable). Provenance clause verified untouched three independent ways. Smoke-proven with factor-3/1-hour overrides (TURN_CAP 6 honored).

## Task 6 — exact state (RESUME HERE)

- `plugin/commands/improve-cycle.md` is written, plugin-validates, and is committed as WIP (`814958e`) — content matches the plan's Task 6 brief verbatim. The Task 6 commit contract (improve-cycle.md + spike appendix, message `feat(plugin): /ralph:improve-cycle bounded review-to-PR unit of work`) is still owed; fold the WIP commit in or follow it with the appendix commit.
- **C1 (guard smoke): PASSED** — cycle refuses to run outside a `ralph/improve-*` worktree, zero writes (capture `/tmp/p3-cycle-guard.jsonl`).
- **C2 (full cycle) attempt history:** a1 `aborted_streaming` (infra); a2 `max_turns(15)`; a3 killed by controller order (same 15 cap); a4 `max_turns(30)` — but the cycle executed CORRECTLY and deeply: worktree log showed `chore: review backlog` → `chore: add spec for Improve 2026-07-20` → T-001 complete → T-002 mid-build, zero pushes; a5 (50-turn sanctioned final attempt) was starting when this session stopped — killed cleanly. Old sandbox/worktree remnants under `/tmp/ralph-sb-cycle*` are safe to delete; regenerate fresh.
- **Continuation:** rerun C2 ONCE, completely fresh sandbox + bare remote + worktree per the plan's C2 procedure, with `--max-turns 50 --max-budget-usd 10` (controller-sanctioned deviation from the brief's 15 — document it and the evidence in the spike appendix). If it hits max_turns again: BLOCKED — restructure at plan level (candidates: scope the cycle's embedded review to fewer categories by default, or split into review-spawn + build-spawn).
- Captures kept in `/tmp` (volatile — the committed spike appendices are the durable record): `p3-cycle-guard.jsonl`, `p3-cycle-full-attempt1-interrupted.jsonl`, `p3-cycle-full-attempt2-maxturns15.jsonl`, `p3-cycle-full-attempt4-maxturns30.jsonl`, plus `p3-review-*.jsonl`, `p3-build-caps.jsonl`, `p3-spike-*.jsonl`.

## Binding mid-plan controller decisions (already ledgered; supersede the plan text where they conflict)

1. **`improveTurns` default becomes 50** (plan text says 15 — insufficient, proven twice). Consumers: Task 7's launcher default, `.claude/ralph.json` example + README in Task 8. Dollar cap stays 10.
2. **GUILLOTINE finding:** an outer CLI `max_turns` kill mid-build leaves NO partial draft PR (zero remote refs), unlike the inner build TURN_CAP which routes gracefully to Phase 5. The outer cap is a BACKSTOP and must sit comfortably above the inner graceful caps. Record in the Task 6 spike appendix + Task 8 README.
3. **No Monitor standby for subagents:** implementer subagents stalled twice "standing by" for Monitor/background notifications that never woke them. Every dispatch that runs long headless commands must mandate active sleep-polling loops (Bash run_in_background + repeated poll calls, `sleep 30` inside poll commands; kill + record past the stated deadline).

## Platform/process facts learned this session (do NOT relearn)

1. **CHILD-SURVIVES:** plain-`&` headless children outlive the session — pid sidecars (`<worktree-path>.pid`), `/ralph:status` visibility, `kill` verification, and hard caps are load-bearing. **nohup/disown/setsid are forbidden everywhere** (user directive after the orphaned-`ralph.sh` incident).
2. **Sidecar contract:** improve runtime files live OUTSIDE the worktree (`<worktree-path>.pid/.log/.selected.json`) or build.md's clean-tree preflight aborts mid-cycle.
3. **The tracked `.claude/settings.json` Stop hook fires on interactive sessions in this repo** and spuriously blocks with "insufficient evidence" whenever the recent transcript lacks `.ralph-goal` evidence (first-call access gap; recurring, not one-time). Answer: run `ls -la .ralph-goal` (shows absence) and end the turn. Candidate refinement for Task 8: let the evaluator pass when the transcript shows zero build activity — weigh against platform fact 5 (never weaken provenance) before touching the hook prompt.
4. **MCP-roster resume leak** (T4 finding above) — follow-up owed at final review; relevant to any long headless run that hits async-task resumes.
5. **Scratch collisions:** `.superpowers/sdd/task-N-{brief,report}.md` are task-number-keyed and collide across plans. Plan 1 scratch archived at `.superpowers/sdd/plan1/`, Plan 2 at `plan2/`. Archive before reusing numbers.
6. All Plan 1–2 platform facts still hold (see `docs/superpowers/plans/2026-07-20-native-ralph-plugin-next-steps.md` facts 1–7); native-`/goal`-via-`-p` NO-GO refines (does not contradict) fact 1.

## Remaining work after Task 6

- **T7** `/ralph:improve` launcher + status tick reporting — consume improveTurns=50 and the CHILD-SURVIVES routing (L1 gets the mid-flight `kill` probe branch; L2 busy-check triple; L3 `--wait`).
- **T8** routine template + config example (`improveFindings: 3`, improveTurns 50) + README (flywheel section, defaultBudgets bullet now STALE post-T5 — reviewer-flagged; kill-switch/no-orphan wording; hook-refinement candidate; cosmetic: T4 report says 29 MCP servers, actual 30) + plugin.json 0.3.0.
- **T9** parity gate record (2 clean-room builds + adversarial unsatisfiable run; tally supervised runs: spec 3 from Plan 2, review 3 from T4, improve — count honestly from C2 attempts + T7's L-runs).
- **T10** real-surface validation — **user approval already recorded 2026-07-20 ("approved, include 10")**: supervised `/ralph:review` on this repo, one `/ralph:improve --wait` producing a real PR (first live Phase I-5 backlog-reconciliation push — the sanctioned post-PR push), `status.md` against the real PR. Never merge the PR.
- **Final whole-branch review on the strongest model** (Plans 1–2 used Fable), fix wave, then **check in with the user for the merge decision** (their standing checkpoint list: plan approvals ✓ done, contradicting spikes, final merge).

## Guardrails (unchanged, binding)

Branch-first; PR-gated; never merge; single push at PR time (+ the ONE sanctioned post-PR backlog push in improve Phase I-5); `--max-turns` AND `--max-budget-usd` on every headless spawn; all smoke tests in `tests/make_sandbox.sh` sandboxes (Task 10 is the sole, user-approved exception); never `--dangerously-skip-permissions`; no attribution lines in commits/PRs; `make check` (94 BATS + shellcheck) and `claude plugin validate ./plugin` green after every task.
