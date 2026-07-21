# ralph — Native Ralph Loop Plugin

A native Claude Code port of the [Ralph Loop](../README.md) bash script:
goal-driven autonomous builds using fresh-context builder subagents,
independent adversarial verification, and deterministic completion
evidence instead of a self-reported `<ralph>COMPLETE</ralph>` marker. The
bash implementation (`ralph.sh`) stays in place and unchanged until the
parity gate in the design doc passes — the two are not yet interchangeable.

## Install

```
/plugin marketplace add <this-repo-path-or-url>
/plugin install ralph@ralph-starter
```

## Commands

| Command | Description |
|---|---|
| `/ralph:go "<task>" [--pr]` | One-off task: branch-first, implement, verify, commit; `--pr` opens a PR |
| `/ralph:build <spec.json>` | Goal-driven build from a spec: fresh builder per task, verifier-gated PR |
| `/ralph:status` | Read-only dashboard: active goal, spec progress, open `ralph/*` PRs, worktrees |
| `/ralph:spec "<prompt>" \| -f <file> \| --from-findings [path]` | Generate a validated spec JSON in `specs/` (no commit — review, then build) |
| `/ralph:dev "<prompt>" [--review]` | Full pipeline: generate spec → build it; `--review` pauses for spec approval |
| `/ralph:review [--diff-base <ref>] [--focus <cats>] [--target <path>]` | Read-only codebase review — parallel category subagents merged into the tracked findings backlog |
| `/ralph:improve [--wait]` | One bounded improve tick: headless review → fix-spec → build → PR in a fresh worktree; `--wait` blocks until done |
| `/ralph:improve-cycle` | Internal — the unit of work `/ralph:improve` spawns; refuses to run outside a `ralph/improve-*` worktree |

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
gitignored specs — see Artifact tracking below).

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
come from `defaultBudgets.improveTurns`/`improveUsd` (50 / $10
defaults). A tick skips itself if a previous tick is running or its PR
is still open; a crashed tick is surfaced for human inspection, never
auto-deleted. The backlog update marking findings `addressed` is
committed and pushed into the same open PR as a single documented
follow-up commit — the one exception to single-push.

Triggers: locally, `/loop /ralph:improve` (each tick is
fire-and-forget within the live session; the loop cadence should
exceed a cycle's duration); in the cloud, schedule
`plugin/routines/improve-nightly.md`'s Instructions block, which uses
`--wait`. Ticks are never detached (no nohup/disown/setsid), but a
plain `&` child survives the session that launched it (spike-verified:
CHILD-SURVIVES) — which is exactly why the pid sidecar kill switch and
`/ralph:status` visibility are mandatory: a tick must always be
findable and killable. Orphaned background runs that could not be
found or killed are the incident class this design replaces.

Kill switches: `kill <pid>` (the launcher prints it; the pid sidecar
sits next to the worktree), `/ralph:status` (shows
RUNNING/CRASHED/FINISHED ticks), PR review (nothing merges itself).

Trust caveat: review-finding text flows into spec criteria executed by
Bash-capable builders (tracked as backlog finding F-020), so until that
boundary is hardened, run the improve flywheel only on repos whose
contents you trust.

The outer `--max-turns` cap on the improve spawn is a backstop, not a
working limit: if it fires mid-build it kills the tick with no partial
draft PR left behind, unlike the inner build `TURN_CAP`, which routes
gracefully to a draft partial PR. Configure `improveTurns` comfortably
above the inner graceful caps (review + selection + spec phases, plus
`buildTurnsFactor` × task count). On a real repo the five parallel
review subagents alone consumed ~$7.8 of the default $10 `improveUsd`
in the first live run, so real deployments should raise `improveUsd`
and/or narrow `reviewFocus`/`sourceDirs` — a budget-exhausted cycle
still lands the graceful partial draft PR.

## Config

Optional `.claude/ralph.json` in the host repo (see [`.claude/ralph.json`](../.claude/ralph.json) here for an example). Field status below — `verificationCommands`, `defaultBudgets`, `reviewFocus`, and `sourceDirs` are live; `models` and `artifactPaths` are deliberately reserved:

- `verificationCommands` — **live now**: `/ralph:go` reads this to verify a one-off task, if the file exists and defines it (falls back to the repo's documented test/lint commands otherwise). `/ralph:spec` (and therefore `/ralph:dev`, which chains it) also reads this field as the priority source for a generated spec's `context.verificationCommands`, before falling back to the repo's documented test commands. **Not** read by `/ralph:build` — that command sources its verification commands from the spec's `context.verificationCommands` instead (already populated by `/ralph:spec` from this field, if present), see Spec format below.
- `defaultBudgets` — **live now**: `buildTurnsFactor`/`buildHours` set `/ralph:build`'s TURN_CAP factor and wall-clock cap (defaults 2 / 2h); `improveTurns`/`improveUsd` cap the improve spawn (defaults 50 / $10); `improveFindings` sets findings-per-cycle (default 3). `improveHours` is documented-only: no wall-clock CLI flag exists, the turn cap approximates it.
- `reviewFocus` — **live now**: the categories `/ralph:review` fans out across when `--focus` isn't given.
- `sourceDirs` — **live now**: the default review targets when `--target` isn't given.
- `models` — **reserved (deliberately — no consumer in v1; revisit after the parity gate)**: intended model routing overrides for `go`/`builder`/`verifier` (`"inherit"` would use the invoking session's model); `/ralph:go` currently hardcodes `model: sonnet` in its own frontmatter instead (go.md).
- `artifactPaths` — **reserved (deliberately — no consumer in v1; revisit after the parity gate)**: intended override for where specs and review output live, for submodule or non-standard layouts; no command reads this yet.

## Spec format

Specs use the `tasks[]` schema (see [`specs/example.json`](../specs/example.json)):
`id`, `title`, `description`, `acceptanceCriteria`, `dependsOn`, `status`,
`passes`, `effort`, `notes`. A top-level `context` block is also part of
the schema:

- **`context.verificationCommands`** (array of strings) — **required for
  `/ralph:build`**: the commands it runs to verify the build. Read by
  `${CLAUDE_PLUGIN_ROOT}/scripts/ralph-evidence.sh` directly from the
  spec (build.md Phase 1 step 5), which exits 3 and aborts the build if
  this is missing or empty — no independent verification, no evidence
  chain. This is a field on the spec JSON itself, distinct from
  `.claude/ralph.json`'s `verificationCommands` field above, which
  `/ralph:build` never reads.

`/ralph:build` also reads and writes two more fields not covered
elsewhere:

- **`attempts`** (per task, integer) — orchestrator-managed retry
  counter; a task moves to `status: blocked` once `attempts` reaches 2
  without a `DONE` builder report.
- **`verifier`** (top-level, `{verdict, date, summary}`) — written once
  the `ralph-verifier` subagent returns `PASS` at completion; absent (or
  `null` in `specs/example.json`, which was never built) until then.

## Artifact tracking

`specs/*.json` and `review-output/findings.json` must be **git-tracked**,
not gitignored — worktrees and fresh clones only materialize tracked
files, so an ignored spec or backlog silently vanishes exactly where
headless builds run. Host repos migrating off bash Ralph (which
gitignored both) should drop the `specs/*` / `review-output/` ignore
rules and commit the existing files once.

This repo made that migration in Plan 3: `specs/`, `review-output/`, and
`.claude/settings.json` are tracked here.

## Guardrails

- **PR-gated, branch-first, never merges** — every writing command
  refuses the default branch; only `ralph/*` branches are ever pushed, and
  only at PR time.
- **Caps everywhere** — every goal carries turn and wall-clock stop
  clauses; headless spawns add a dollar cap. There is no `--unlimited`.
- **POSIX shell required** — the evidence script needs `bash`; pure
  Windows without git-bash/WSL is unsupported in v1.
- **`.ralph-goal`** is an ephemeral, gitignored runtime file that
  `/ralph:build` writes and deletes itself — hosts should gitignore it
  and never commit it.

## Running headless / unattended

Proven invocation shape (e.g. from `/loop` or a cloud routine):

```bash
claude -p "/ralph:build specs/feature.json" \
  --plugin-dir /path/to/ralph-starter/plugin \
  --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --setting-sources project \
  --max-turns 40 \
  --max-budget-usd 20
```

- `--allowedTools` is required alongside `acceptEdits` (which only auto-approves `Edit`/`Write`) — otherwise `Bash` calls get rejected until the session dies (Task 7; full list including `Agent` validated end-to-end in Task 11, Scenario A, ~line 707).
- `--setting-sources project` excludes the invoking user's personal settings — a real incident had a user-level `git push` approval gate silently deny a build's push.
- `--max-budget-usd` is what backs the "headless spawns add a dollar cap" guardrail above — the recorded end-to-end runs (Task 7, Task 11) predate this flag being added to the invocation and ran without it; include it for any new headless spawn.
- **Caveat:** under `--setting-sources project` the plugin's own Stop hook does not fire at all (re-confirmed 2026-07-20) — the host repo needs the hook duplicated into its own `.claude/settings.json`. Copy it verbatim from [`plugin/hooks/hooks.json`](hooks/hooks.json) (this repo tracks such a copy at `.claude/settings.json`, so fresh clones and worktrees of ralph-starter already have it):

  ```bash
  cp plugin/hooks/hooks.json .claude/settings.json
  ```

Because the settings copy is tracked here, interactive sessions also evaluate the hook on every Stop; with no `.ralph-goal` present it should allow immediately, but it has been observed to spuriously block with "insufficient evidence" when the recent transcript carries no `.ralph-goal` evidence — running `ls .ralph-goal` to surface the file's absence satisfies it.

Interactive sessions need none of this — the plugin's hook fires normally there.
