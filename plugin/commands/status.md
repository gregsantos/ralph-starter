---
description: Show Ralph state — active goal, spec progress, open ralph/* PRs, worktrees
---
# /ralph:status

Report Ralph state, read-only (change nothing):

1. Goal: check for a `.ralph-goal` file in the repo root. If it exists,
   print its condition as the active goal. If absent, report "None
   active".
2. Specs: for each specs/*.json (skip example.json), run
   `${CLAUDE_PLUGIN_ROOT}/scripts/ralph-evidence.sh <spec>` and show the
   counts line. Note: exit 3 means the spec lacks verificationCommands —
   report it as "unbuildable (no verificationCommands)".
3. PRs: `gh pr list --state open --json headRefName,title,url,isDraft`
   filtered to branches starting with ralph/ (report "gh unavailable" if
   the command fails; don't guess).
4. Branches/worktrees: `git branch --list 'ralph/*'` and
   `git worktree list` entries containing "ralph".
Summarize in a short table. No recommendations unless something is stuck
(blocked tasks, draft partial PRs, conflicts).
