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
| `/ralph:spec` | Coming in Plans 2–3 |
| `/ralph:dev` | Coming in Plans 2–3 |
| `/ralph:review` | Coming in Plans 2–3 |
| `/ralph:improve` | Coming in Plans 2–3 |

## Config

Optional `.claude/ralph.json` in the host repo (see [`.claude/ralph.json`](../.claude/ralph.json) here for an example). Field status below — most are reserved for the review/improve/dev commands landing in Plans 2–3 and aren't read by anything yet:

- `verificationCommands` — **live now**: `/ralph:go` reads this to verify a one-off task, if the file exists and defines it (falls back to the repo's documented test/lint commands otherwise). **Not** read by `/ralph:build` — that command sources its own verification commands from the spec's `context.verificationCommands` instead, see Spec format below.
- `sourceDirs` — **reserved**: intended as directories treated as source for review/improve scoping; no command reads this yet.
- `defaultBudgets` — **reserved**: intended turn/hour/USD caps for build and improve cycles; `/ralph:build` currently hardcodes its own caps instead (`TURN_CAP = 2 × task count`, 2-hour wall clock — build.md Phase 1 step 6).
- `reviewFocus` — **reserved**: intended categories for `/ralph:review` to fan subagents out across; `/ralph:review` doesn't exist yet.
- `models` — **reserved**: intended model routing overrides for `go`/`builder`/`verifier` (`"inherit"` would use the invoking session's model); `/ralph:go` currently hardcodes `model: sonnet` in its own frontmatter instead (go.md).
- `artifactPaths` — **reserved**: intended override for where specs and review output live, for submodule or non-standard layouts; no command reads this yet.

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
- **Caveat:** under `--setting-sources project` the plugin's own Stop hook does not fire at all (Task 11's "MAJOR FINDING") — duplicate it into the host's `.claude/settings.json`:

  ```json
  {
    "hooks": {
      "Stop": [
        {
          "hooks": [
            {
              "type": "prompt",
              "prompt": "Read the file .ralph-goal if it exists. If it exists and contains a condition, check if the transcript demonstrates that condition is met. Respond with {\"ok\": true} if the condition is met or the file doesn't exist. If the condition is not met, respond with {\"ok\": false, \"reason\": \"Condition not met: [specific detail of what remains]\"}.",
              "model": "claude-haiku-4-5-20251001"
            }
          ]
        }
      ]
    }
  }
  ```

Interactive sessions need none of this — the plugin's hook fires normally there.
