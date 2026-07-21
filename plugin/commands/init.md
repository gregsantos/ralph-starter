---
description: Onboard a repo to the ralph plugin — detect the stack, confirm the verification suite, write .claude/ralph.json and safety plumbing
argument-hint: '(no arguments)'
---
# /ralph:init — onboarding

Onboard the current repo to the ralph plugin: $ARGUMENTS

This command changes NOTHING outside `.claude/` (and, only on the
greenfield path and only with your confirmation, a `verify.sh` at the
repo root). It never commits, never creates branches, and never pushes —
you review what it wrote and commit it yourself. Every write is
confirmed with you first; nothing is guessed silently.

## Procedure — deviations are failures

1. **Detect the stack and harvest candidate commands.** Inspect the repo
   root and classify it:
   - `package.json` → Node (template `ralph-node.json`).
   - `pyproject.toml` → Python (template `ralph-python.json`).
   - `Cargo.toml` → Rust — **no dedicated template exists**; take the
     custom-commands path (step 2's second option) and build the config
     off `ralph-bash.json`'s shape, never guessing Rust commands.
   - `Makefile` (no package manifest) → Make/bash (template
     `ralph-bash.json`).
   - Shell scripts only, no manifest → plain bash (template
     `ralph-bash.json`).
   - Empty or near-empty directory (no source, no manifest) → greenfield
     (template `ralph-greenfield.json`).

   Then harvest CANDIDATE test/lint commands (do not run or assume them
   yet) from: `package.json` `scripts`, `Makefile` targets,
   `pyproject.toml`/tool config, CI configs (`.github/workflows/*`,
   `.gitlab-ci.yml`, etc.), and repo docs (`README`, `CONTRIBUTING`,
   `CLAUDE.md`). Note the detected `sourceDirs` (e.g. `src`, or `.` for a
   flat bash repo) from the same evidence.

2. **Ask the user to confirm the verification suite BEFORE writing
   anything.** Present the detected stack and harvested candidates, then
   offer exactly these choices and WAIT for an answer — never guess
   silently:
   - Use the detected commands as-is.
   - Type a custom command (or commands) to use instead — this is also
     the path for any detected stack with no matching template (e.g.
     Rust/`Cargo.toml`): confirm the commands with the user rather than
     guessing.
   - Greenfield / empty dir only: scaffold a starter `verify.sh` by
     copying `${CLAUDE_PLUGIN_ROOT}/templates/verify-starter.sh` to
     `verify.sh` at the repo root, and set the verification command to
     `bash verify.sh`. Ask before writing `verify.sh`; it is the one
     file this command may create outside `.claude/`.

3. **Write `.claude/ralph.json`** from the matching template in
   `${CLAUDE_PLUGIN_ROOT}/templates/`, applying the confirmed
   `verificationCommands` and the detected `sourceDirs`, and these
   defaults under `defaultBudgets`: `buildTurnsFactor` 2, `buildHours`
   2, `improveTurns` 50, `improveUsd` 15, `improveFindings` 3; plus all
   five `reviewFocus` categories (`code-quality`, `test-coverage`,
   `architecture`, `security`, `bug`). Confirm the exact contents with
   the user before writing. **NEVER overwrite an existing
   `.claude/ralph.json` without explicit confirmation** — if one is
   present, show a diff of what would change and proceed only if the
   user approves; otherwise leave it untouched.

4. **Safety plumbing.**
   - If `.claude/settings.json` is ABSENT, copy
     `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json` to `.claude/settings.json`,
     explaining WHY: the plugin's own Stop hook does not fire under
     `--setting-sources project` (how headless builds run), so the host
     repo needs the hook duplicated into its own `.claude/settings.json`
     (plugin README, "Running headless / unattended"). If it already
     exists, leave it and say so.
   - Run `git check-ignore specs review-output` (and the files beneath):
     if `specs/` or `review-output/` are gitignored, WARN — an ignored
     spec or findings backlog silently vanishes in worktrees and fresh
     clones and defeats the improve loop (plugin README, "Artifact
     tracking") — and offer to drop the ignore rules as the fix.
   - WARN (do NOT fail) on any of: not a git repo, no `gh` auth
     (`gh auth status`), or no `origin` remote (`git remote get-url
     origin`). These block PR-time steps later but not initialization.

5. **Next-steps card.** Finish by printing these four, one line each:
   - `/ralph:go "<task>"` — quick one-off task.
   - `/ralph:dev "<feature>"` — generate a spec, then build a feature.
   - `/ralph:review` — build the tracked findings backlog.
   - `/ralph:improve` — bounded autopilot: review → fix-spec → build → PR.

6. **Scope statement.** State plainly that `/ralph:init` changed nothing
   outside `.claude/` (and, on the greenfield path only, `verify.sh`),
   and that it never commits — the user reviews and commits the new
   files themselves.
