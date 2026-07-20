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

Optional `.claude/ralph.json` in the host repo (see [`.claude/ralph.json`](../.claude/ralph.json) here for an example):

- `verificationCommands` — commands run to verify a build; **required for
  `/ralph:build`**, which refuses to start without at least one (no
  independent verification, no evidence chain).
- `sourceDirs` — directories treated as source for review/improve scoping.
- `defaultBudgets` — turn/hour/USD caps for build and improve cycles.
- `reviewFocus` — categories `/ralph:review` fans subagents out across.
- `models` — model routing overrides for `go`/`builder`/`verifier`; `"inherit"` uses the invoking session's model.
- `artifactPaths` — where specs and review output live; override for submodule or non-standard layouts.

## Spec format

Specs use the `tasks[]` schema (see [`specs/example.json`](../specs/example.json)):
`id`, `title`, `description`, `acceptanceCriteria`, `dependsOn`, `status`,
`passes`, `effort`, `notes`. `/ralph:build` also reads and writes two
fields not covered elsewhere:

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

## Running headless / unattended

Proven invocation shape for unattended builds (e.g. from `/loop` or a
cloud routine):

```bash
claude -p "/ralph:build specs/feature.json" \
  --plugin-dir /path/to/ralph-starter/plugin \
  --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --setting-sources project \
  --max-turns 40
```

- **`--allowedTools` is not optional alongside `acceptEdits`.**
  `acceptEdits` only auto-approves `Edit`/`Write`; every `Bash` call (task
  verification, `git`, `gh`) comes back "requires approval" and gets
  auto-rejected until the session self-terminates
  (`docs/superpowers/spikes/2026-07-goal-arming.md`, "Agent-type
  registration (Task 7)").
- **`--setting-sources project` avoids user-settings contamination** — a
  real incident had a user-level `git push` approval gate silently deny a
  build's push.
- **Hard caveat:** under `--setting-sources project`, the plugin's own
  Stop hook (`plugin/hooks/hooks.json`) **does not fire at all** — zero
  hook events, no goal enforcement (same spike doc, Task 11's "MAJOR
  FINDING"). For headless/unattended builds, the host repo **must**
  duplicate the Stop hook into its own `.claude/settings.json`:

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

Interactive sessions need none of this — the plugin's own hook fires
normally there, since `--setting-sources` isn't restricted.
