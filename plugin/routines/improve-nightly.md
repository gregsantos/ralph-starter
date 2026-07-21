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
     --max-turns 50 --max-budget-usd 10`
   (the cycle's instructions come from the clone's own plugin dir — no
   inlined drift)
4. If neither is possible, STOP and report "ralph plugin unavailable in
   routine environment" — do not improvise the cycle.
5. Report: the PR URL (or the honest failure/empty-cycle outcome), the
   caps used, and which findings were addressed.
