# Spike: plugin skill registration + plugin-root file reads

**Date:** 2026-07-20
**Task:** Task 1 of Plan 2 of the native Ralph plugin build (see
`.superpowers/sdd/task-1-brief.md`)
**Question:** Two platform assumptions load-bearing for `spec.md`/`dev.md`
(Plan 2) are unverified: (a) does a `plugin/skills/<name>/SKILL.md`
directory register as an invokable skill; (b) does a command's
instruction to **Read** a file under `${CLAUDE_PLUGIN_ROOT}` work in a
headless run (Plan 1 only proved `${CLAUDE_PLUGIN_ROOT}` for **Bash**
execution).

## Decision

- **plugin-root-read: ok.** `spec.md`/`dev.md` proceed as planned — the
  Read-the-file-under-`${CLAUDE_PLUGIN_ROOT}` mechanism works headlessly.
- **skill-tool registration: worked as `ralph:spike-probe`.** A
  `plugin/skills/<name>/SKILL.md` directory is valid and registers as an
  invokable skill under the `<plugin-name>:<skill-name>` namespace — the
  same pattern already observed for commands (`ralph:goal-spike`) and
  agents (`ralph:ralph-builder`). Task 7's README wording can state the
  skill name as `ralph:<skill-name>`.

Both verdicts are clean, unconfounded results — the Skill tool call
succeeded on its first, exact-name attempt; no permission denial occurred
that would need a retry.

## What was run

### Step 1–2: probe skill + probe command

Created verbatim from the task brief:

- `plugin/skills/spike-probe/SKILL.md`
- `plugin/commands/skill-probe.md`

### Step 3: plugin still validates

```
$ claude plugin validate ./plugin
Validating plugin manifest: /Users/g8s/Dev/ralph-starter/plugin/.claude-plugin/plugin.json

✔ Validation passed
```

No warnings at all (cleaner than Plan 1's spike, which had a "no author
field" warning — this plugin.json already declares `author`). The
`skills/` directory is not flagged as an error; it's accepted silently.

### Step 4: headless probe in a fresh sandbox

```bash
bash tests/make_sandbox.sh /tmp/ralph-sb-spike && cd /tmp/ralph-sb-spike
claude -p "/ralph:skill-probe" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 8 --permission-mode acceptEdits \
  --allowedTools "Skill,Bash,Read,Glob,Grep" \
  --max-budget-usd 3 > /tmp/p2-skill-probe.jsonl 2>&1
```

Exit code `0`. Run completed in `num_turns: 6`, `terminal_reason:
"completed"`, `total_cost_usd: 0.185` (well under the `$3` budget cap),
`permission_denials: []` — a single, unconfounded run; no retry was
needed.

### Step 4 inspection commands and their real output

```
$ grep -o '"slash_commands":\[[^]]*\]' /tmp/p2-skill-probe.jsonl | head -1
"slash_commands":["deep-research","ralph:build","ralph:go","ralph:skill-probe","ralph:status","ralph:spike-probe","design-sync","dataviz", ... ]
```

Both `ralph:skill-probe` (the probe command) and `ralph:spike-probe` (the
probe **skill**) are listed in `slash_commands` — an unexpected but
consistent finding: skills are, in this build, also independently
directly invocable as slash commands, not merely via the Skill tool. Not
required by either verdict, but recorded since it was directly observed.

```
$ grep -c "SPIKE-SKILL-CONTENT-LOADED-OK" /tmp/p2-skill-probe.jsonl
3
```

`>0` as required.

```
$ grep -o "PROBE COMPLETE" /tmp/p2-skill-probe.jsonl
PROBE COMPLETE
```

### Independent registration evidence: the `init` event's `skills` field

Beyond the Skill-tool attempt, the `system/init` event (line 0 of the
stream) carries its own dedicated `skills` array, separate from
`slash_commands` and `agents`:

```json
"skills": [
  "deep-research",
  "ralph:spike-probe",
  "design-sync",
  "dataviz",
  "update-config",
  "verify",
  "debug",
  "code-review",
  "simplify",
  "batch",
  "fewer-permission-prompts",
  "doctor",
  "loop",
  "schedule",
  "claude-api",
  "run",
  "run-skill-generator"
],
```

`ralph:spike-probe` appears there, namespaced identically to the agents
array's `ralph:ralph-builder`/`ralph:ralph-verifier` pattern from Plan
1's spike. This is registration evidence independent of whether the
Skill tool call itself succeeded — the platform enumerated the plugin's
skill at session init regardless.

## Verbatim transcript excerpts

**Skill tool invocation (assistant turn), exact name attempted first:**

```json
{"type":"assistant","message":{... "content":[{"type":"text","text":"I'll run the probe steps in order.\n\n**Step 1:** Invoking the skill `ralph:spike-probe`:"}], ...}}
```

```json
{"type":"assistant", ... "content":[{"type":"tool_use","name":"Skill","input":{"skill":"ralph:spike-probe"}, ...}]}
```

**Tool result acknowledging the launch, with a structured `commandName` field:**

```json
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_01DEfzeVvrUbT1muEmxuAS94","content":"Launching skill: ralph:spike-probe"}]}, ..., "tool_use_result":{"success":true,"commandName":"ralph:spike-probe"}}
```

`tool_use_result.success: true` and `commandName: "ralph:spike-probe"` —
structured, unambiguous success, not just a text string that could be
misread.

**Skill body delivered as a synthetic user-role text block immediately
after (not inside the tool_result content itself), containing the exact
marker:**

```
Base directory for this skill: /Users/g8s/Dev/ralph-starter/plugin/skills/spike-probe

# Spike probe skill

SPIKE-SKILL-CONTENT-LOADED-OK

If you are reading this via the Skill tool, state the exact skill name you invoked.
```

**Read of `${CLAUDE_PLUGIN_ROOT}/skills/spike-probe/SKILL.md` (Step 2 of
the probe command), tool call and result:**

```json
{"type":"assistant", ... "content":[{"type":"tool_use","name":"Read","input":{"file_path":"/Users/g8s/Dev/ralph-starter/plugin/skills/spike-probe/SKILL.md"}}]}
```

```
1	---
2	name: spike-probe
3	description: Throwaway probe skill verifying plugin skill registration. Do not use for real work.
4	---
5	# Spike probe skill
6	
7	SPIKE-SKILL-CONTENT-LOADED-OK
8	
9	If you are reading this via the Skill tool, state the exact skill name you invoked.
```

Confirms `${CLAUDE_PLUGIN_ROOT}` expanded correctly to
`/Users/g8s/Dev/ralph-starter/plugin` inside the headless run's Read
call, and the file content — including the marker — loaded successfully.

**The `PROBE COMPLETE` block, verbatim, exactly as the command
specified:**

```json
{"type": "assistant", "message": {... "content": [{"type": "text", "text": "Both steps completed. The marker line in the file is: `SPIKE-SKILL-CONTENT-LOADED-OK`\n\nPROBE COMPLETE\nskill-tool: worked as `ralph:spike-probe`\nplugin-root-read: ok"}], ...}}
```

Rendered as plain text:

```
Both steps completed. The marker line in the file is: `SPIKE-SKILL-CONTENT-LOADED-OK`

PROBE COMPLETE
skill-tool: worked as `ralph:spike-probe`
plugin-root-read: ok
```

**Final `result` event** (unrelated Stop-hook feedback and a
`.ralph-goal` check appear after this in the stream — the sandbox
generator's repo has no `.ralph-goal`, and the plugin's own Stop hook,
per the goal-arming spike, correctly allowed the stop once it found no
such file):

```json
{"type":"result","subtype":"success","is_error":false,"num_turns":6,"result":"The `.ralph-goal` file does not exist in the working directory.\n\n{\"ok\": true}","stop_reason":"end_turn","terminal_reason":"completed","total_cost_usd":0.18534199999999998,"permission_denials":[]}
```

## Step 3 (re-run): plugin still validates with probes removed

```bash
rm -rf plugin/skills/spike-probe plugin/commands/skill-probe.md
rm -rf /tmp/ralph-sb-spike /tmp/p2-skill-probe.jsonl
claude plugin validate ./plugin
```

```
Validating plugin manifest: /Users/g8s/Dev/ralph-starter/plugin/.claude-plugin/plugin.json

✔ Validation passed
```

## Confounding check (interpretation notes)

The Skill tool was allowlisted (`--allowedTools "Skill,Bash,Read,Glob,Grep"`)
specifically so a permission denial wouldn't be mistaken for "skill not
registered." `permission_denials: []` in the final `result` event
confirms this run had zero denials of any kind — the Skill call
succeeded cleanly on the first, exact-name (`ralph:spike-probe`) attempt.
No retry was necessary, and none was performed.

## Cleanup

- `plugin/skills/spike-probe/` and `plugin/commands/skill-probe.md`
  removed (Step 6, confirmed above).
- `/tmp/ralph-sb-spike` (sandbox) and `/tmp/p2-skill-probe.jsonl` (raw
  stream capture) removed.
- `git status` after removal + before commit: only this spike doc is new;
  no probe files remain.
