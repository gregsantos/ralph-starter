# Ralph Plugin Operator Reference — Review & Improve Flywheel

Task-oriented runbook for the native plugin's review/improve features.
The [plugin README](../plugin/README.md) is the overview (install,
commands table, config, guardrails); this document is the *how do I run,
watch, recover, and tune it* companion. For the legacy bash CLI, see
[RALPH_LOOP_REF.md](RALPH_LOOP_REF.md).

The flywheel in one line:

```
/ralph:review → findings backlog → /ralph:improve tick → fix PR →
   human reviews & merges → backlog reconciled → next tick picks the next findings
```

Nothing in this loop ever merges anything. Humans merge; the flywheel
finds, fixes, and files PRs.

---

## 1. Run a review

Interactive, in your checkout (writes only the two artifacts, never
commits):

```
/ralph:review                            # config-driven scope
/ralph:review --focus bug,security      # subset of categories
/ralph:review --target src/lib          # override targets
/ralph:review --diff-base main          # only files changed since main
```

Scope resolution: `--focus` → else `.claude/ralph.json` `reviewFocus` →
else all five categories (security, bug, code-quality, test-coverage,
architecture). Targets: `--target` → else `sourceDirs` → else inferred
from the repo layout (the report states the inference).

What happens: one read-only subagent per category runs in parallel; the
orchestrator merges results into `review-output/findings.json`
(deduplicating by root cause, continuing ids from the highest existing)
and regenerates `review-output/REVIEW_REPORT.md`. A subagent that
returns malformed output is re-dispatched once, then dropped with a
note in the report.

**After a review:** skim the report, then commit the backlog yourself
(`git add review-output && git commit`) — or leave it uncommitted and
let the next improve cycle's own review regenerate and commit it inside
the fix PR. An *uncommitted* backlog does not survive into improve
worktrees; a *gitignored* one is worse (see §8).

## 2. The findings backlog

`review-output/findings.json` is the source of truth (schema:
`plugin/skills/reviewing-codebase/SKILL.md`). The lifecycle field is
`addressed`:

| Value | Meaning | Written by |
|---|---|---|
| `null` / absent | open — selectable by improve cycles | review |
| `<PR number>` | a fix PR delivered it | improve cycle, Phase I-5 |
| `"stale-<date>"` | revalidation found the symptom already gone | improve cycle, selection |

Rules worth knowing:

- Reviews **preserve** existing `addressed` values — never clear one by
  re-running a review. Don't hand-clear them either; open a new finding
  if a fix regressed.
- Selection (inside a tick) takes the top `improveFindings` (default 3)
  open, non-`info` findings ordered critical → high → medium → low,
  ties by lower id.
- Findings whose `file` appears in any open `ralph/*` PR's diff are
  skipped (someone is already touching it). Requires `gh`; without it
  the filter is skipped with a warning.
- Each candidate is revalidated against the working tree before
  selection; vanished symptoms get `stale-<date>` so they're never
  re-chewed.
- Only findings cited by tasks that were **completed** get a PR number
  on a partial PR — the rest stay open for the next cycle.

## 3. Run an improve tick

Interactive (the launcher does everything; the work itself always runs
headless in a fresh worktree, never in your checkout):

```
/ralph:improve            # fire-and-forget: prints pid/log/kill info and returns
/ralph:improve --wait     # blocks until the tick finishes, reports the outcome
```

Headless (routines, scripts):

```bash
claude -p "/ralph:improve --wait" \
  --plugin-dir /path/to/ralph-starter/plugin \
  --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Glob,Grep" \
  --setting-sources project \
  --max-turns 25 --max-budget-usd 15
```

(The launcher itself needs only read tools; the inner cycle it spawns
carries its own full toolset and its own caps from
`defaultBudgets.improveTurns`/`improveUsd`.)

What the launcher does, in order:

1. **Busy checks** — skips rather than stacks: a RUNNING tick, a
   CRASHED tick, or an open `ralph/improve-*` PR each stop the launch
   (see §4). A FINISHED clean worktree is auto-pruned and the launch
   proceeds.
2. Creates `/tmp/ralph-improve-<ts>` on branch `ralph/improve-<ts>`,
   copies the Stop-hook settings in if the repo doesn't track them.
3. Spawns `claude -p "/ralph:improve-cycle"` inside it, capped, with
   **sidecars next to (never inside) the worktree**:
   `<worktree>.pid` and `<worktree>.log`.
4. Without `--wait`: prints path, branch, pid, log path, caps, and how
   to watch/kill. With `--wait`: polls the pid, then reports the
   outcome and prunes the finished worktree.

Watch a running tick:

```bash
tail -f /tmp/ralph-improve-<ts>.log     # raw stream
/ralph:status                            # tick state + open ralph PRs
```

Kill a running tick:

```bash
kill $(cat /tmp/ralph-improve-<ts>.pid)
```

A killed tick becomes a CRASHED tick on the next launcher run — its
work is preserved for inspection, never auto-deleted. The spawned tick
is a plain `&` child and **survives the session that launched it**
(spike-verified) — the pid sidecar is the kill switch, not session
exit.

## 4. Tick states & recovery

`/ralph:status` step 5 reports every `ralph-improve-` worktree as one
of:

- **RUNNING** — pid sidecar present, process alive. Watch or kill.
- **CRASHED** — pid sidecar present, process dead (killed, machine
  slept, hard failure). The launcher will refuse to start new ticks
  until you deal with it. Runbook:
  1. Read the log: `less /tmp/ralph-improve-<ts>.log`
  2. Inspect the work: `git -C /tmp/ralph-improve-<ts> log --oneline`
     and `status`.
  3. Salvage if worthwhile (push the branch and open a PR manually, or
     cherry-pick commits), then remove:
     `git worktree remove --force /tmp/ralph-improve-<ts>` and delete
     the `.pid`/`.log` sidecars.
- **FINISHED** — no pid sidecar (the cycle removes it as its last act).
  If the tree is clean, the next launcher run (or `--wait` teardown)
  removes the worktree automatically.

## 5. Tick outcomes

Every cycle ends in exactly one of:

- **Full PR** — all selected findings fixed, verifier PASS, one push,
  PR opened, backlog reconciliation commit pushed into the same PR (the
  single sanctioned post-PR push). Review and merge it like any PR.
- **Partial draft PR** (`"… (partial)"`) — an inner cap or the budget
  ran out mid-build; completed tasks are in the PR, their findings
  marked `addressed`; unfinished tasks stay `pending`/`blocked` in the
  committed spec and their findings stay open. To resume: either let a
  future tick re-select the open findings (simplest), or check out the
  PR branch and run `/ralph:build specs/improve-<date>.json` to
  continue the committed spec by hand.
- **Empty cycle** — no actionable findings (all addressed, stale, info,
  or PR-overlapped). Success, not an error.
- **Abort** — guard failure or spec-generation failure, reported
  honestly with cleanup done.

If the *outer* `--max-turns`/`--max-budget-usd` kills the process
mid-build instead, there is **no PR at all** (the backstop is a
guillotine — see §7's sizing rules) and you'll find a CRASHED or
dirty-FINISHED worktree via §4.

## 6. Triggers

**Locally, recurring:** `/loop /ralph:improve` from an interactive
session. Pick a loop cadence longer than a full cycle (~15+ min on a
real repo); if ticks overlap anyway, the busy checks make the extra
invocation skip — nothing stacks. Each tick is fire-and-forget; the
loop session is just the scheduler.

**Cloud/scheduled:** register the Instructions block of
`plugin/routines/improve-nightly.md` with your scheduler (e.g.
`/schedule "nightly at 02:00" <instructions>`). It preflights the
Stop-hook settings, prefers `/ralph:improve --wait`, falls back to the
documented direct spawn if the plugin isn't installed in the fresh
clone, and STOPs honestly if neither is possible.

**One-off:** just run `/ralph:improve --wait` whenever you want a
single bounded improvement pass.

## 7. Budget & cap sizing (from live data)

Measured on this repo's first real tick: the five parallel review
subagents alone cost **~$7.8**, leaving ~$2.2 of the default
`improveUsd: 10` for spec + build — the cycle landed a graceful partial
PR. Sizing guidance:

- `improveUsd`: 15–25 for real repos with the default five categories;
  or keep 10 and narrow `reviewFocus`/`sourceDirs` so review costs
  less.
- `improveTurns` (default 50): a toy 2-task cycle used 47 turns; the
  real tick used 22 (budget-bound). Keep this comfortably above
  review + selection + spec turns plus `buildTurnsFactor` × expected
  tasks — it is a backstop, and when it fires mid-build you get
  *nothing*, unlike the inner caps which route to a partial draft PR.
- `improveFindings` (default 3): fewer findings per tick = cheaper,
  more predictable cycles; the flywheel's cadence does the rest.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Stop hook blocks an interactive session with "insufficient evidence" | Tracked settings copy evaluates the hook on every Stop; no `.ralph-goal` evidence in recent transcript | Run `ls .ralph-goal` (shows absence), stop again |
| Tick worktree commits abort / backlog "vanishes" in worktrees | `specs/*` or `review-output/` gitignored (bash-Ralph legacy) | Remove those ignore rules, commit the files once (README "Artifact tracking") |
| Headless run dies instantly, `Bash` rejected | Missing `--allowedTools` alongside `--permission-mode acceptEdits` | Use the proven invocation shape (README "Running headless") |
| Hook never fires headlessly | `--setting-sources project` makes plugin hooks inert | `cp plugin/hooks/hooks.json .claude/settings.json` in the host repo (track it) |
| Same findings selected every cycle, no PRs | No `gh`/GitHub remote: PR creation fails, reconciliation skips, findings stay open | Give the environment `gh` auth + a GitHub remote, or triage the backlog by hand |
| Launcher refuses to run | RUNNING/CRASHED tick or an open `ralph/improve-*` PR | That's the design (skip, don't stack): finish/kill/inspect per §4, merge or close the PR |
| Tick ended, no PR, worktree dirty | Outer cap guillotined it mid-build | Salvage per §4; raise the outer caps per §7 |

## 9. Safety model (what protects you)

- **PR-gated:** only `ralph/*` branches are ever pushed; one push at PR
  time plus the single documented reconciliation follow-up; nothing
  merges itself; writing commands refuse the default branch.
- **Caps on every spawn:** `--max-turns` and `--max-budget-usd`, always;
  inner build caps route gracefully to partial PRs.
- **No orphans:** no `nohup`/`disown`/`setsid` anywhere; every tick has
  a pid sidecar, is visible in `/ralph:status`, and dies to `kill`.
- **Isolation:** the cycle refuses to run outside a `ralph/improve-*`
  worktree; your checkout is never the workspace.
- **Trust boundary (open):** review-finding text flows into spec
  criteria executed by Bash-capable builders (backlog finding F-020) —
  until hardened, run the flywheel only on repos whose contents you
  trust.

---

*Deeper background: design doc
`docs/superpowers/specs/2026-07-19-native-ralph-port-design.md`;
empirical evidence for every claim above lives in
`docs/superpowers/spikes/2026-07-improve-mechanics.md` and
`docs/superpowers/spikes/2026-07-parity-gate.md`.*
