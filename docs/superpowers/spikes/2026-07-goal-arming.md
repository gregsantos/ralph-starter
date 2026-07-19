# Spike: can a plugin command arm `/goal`?

**Date:** 2026-07-19
**Task:** Task 1 of the native Ralph plugin build (see
`docs/superpowers/plans/2026-07-19-native-ralph-plugin-foundation.md`)
**Question:** Can a plugin slash command's Markdown instructions cause the
*assistant*, mid-conversation, to arm the built-in `/goal` evaluator
programmatically — the mechanism Task 10's `build.md` Phase 2 ("Arm /goal
with exactly this condition") assumes?

## Decision

**FALLBACK.** Task 10 must use the plugin Stop-hook variant (`.ralph-goal`
file + `plugin/hooks/hooks.json`), not a literal "arm /goal" instruction in
`build.md`. Evidence below.

## What was run

All three files from Step 1–2 of the task brief were created verbatim:

- `plugin/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `plugin/commands/goal-spike.md`

Both validate cleanly:

```
$ claude plugin validate ./plugin
✔ Validation passed with warnings   # only: no author field
$ claude plugin validate .
✔ Validation passed with warnings   # only: no marketplace description
```

Execution was adapted to run **headlessly** rather than interactively,
because this spike runs inside a non-interactive subagent. Interactive
`/plugin marketplace add` + `/plugin install` was replaced with the
documented `--plugin-dir` session-scoped loader, which is functionally
equivalent for this question (it loads the same plugin manifest and
registers the same slash command — confirmed by the `init` event's
`slash_commands` list containing `ralph:goal-spike`).

All runs happened inside an isolated scratch repo at `/tmp/ralph-spike`
(a fresh `git init`, plugin files copied in — never run against
ralph-starter itself).

### Run 1 — the spike command as specified

```bash
cd /tmp/ralph-spike && claude -p "/ralph:goal-spike" \
  --plugin-dir /tmp/ralph-spike/plugin \
  --output-format stream-json --verbose \
  --max-turns 8 --permission-mode acceptEdits \
  > spike-run.jsonl
```

The plugin loaded correctly — the `system/init` event's `slash_commands`
array includes `"ralph:goal-spike"`, confirming the command resolved and
its Markdown body reached the model as instructions.

Observed behavior (from the stream): the assistant never attempted to
literally type `/goal ...`. Instead it went looking for a *tool* to do the
arming:

```
TOOL_USE: ToolSearch {"query": "goal session arm evaluator", "max_results": 5}
...
TOOL_USE: ToolSearch {"query": "+goal", "max_results": 5}
...
TEXT: The tool search didn't surface a goal tool. Let me look at the ralph
      plugin in this repo to see how the /goal mechanism is meant to be armed.
...
TOOL_USE: ToolSearch {"query": "select:Goal,SetGoal,SessionGoal,GoalSet,ArmGoal", ...}
TOOL_RESULT: No matching deferred tools found
...
TOOL_USE: Bash {"command": "claude --help 2>&1 | grep -in goal; which claude", ...}
...
TOOL_USE: Bash {"command": "CLAUDE_BIN=$(readlink -f ...); grep -aoiE '[a-z]{0,20}goal[a-z]{0,20}' \"$CLAUDE_BIN\" ...", ...}
TOOL_RESULT: Contains shell syntax (string) that cannot be statically analyzed
```

It hit `--max-turns 8` (`"subtype": "error_max_turns"`, `"terminal_reason":
"max_turns"`) never having armed anything, with one Bash call permission-denied
along the way. No `SPIKE_DONE.txt`, no goal-related file, was ever created.

### Run 2 — direct test of whether assistant text output is parsed as a slash command

Run 1 leaves an ambiguity: maybe the model just didn't think to try the
literal syntax. So Run 2 forces the literal attempt and checks whether the
harness treats assistant-authored `/goal ...` text the same way it treats
human-typed `/goal ...` text:

```bash
cd /tmp/ralph-spike && claude -p 'Do not use any tools. Your entire response
must be exactly this literal text and nothing else, on its own line:
"/goal The file SPIKE_DONE.txt exists in the current directory and contains
the text spike-ok, or 3 turns have elapsed." Then on a new line say only:
spike armed' \
  --output-format stream-json --verbose \
  --max-turns 6 --permission-mode acceptEdits \
  > spike-run-2.jsonl
```

Verbatim assistant output and result:

```json
{"type":"assistant", ... "text":"/goal The file SPIKE_DONE.txt exists in the current directory and contains the text spike-ok, or 3 turns have elapsed.\nspike armed"}
{"type":"result","subtype":"success","is_error":false,"num_turns":1,
 "result":"/goal The file SPIKE_DONE.txt exists in the current directory and contains the text spike-ok, or 3 turns have elapsed.\nspike armed",
 "stop_reason":"end_turn","terminal_reason":"completed", ...}
```

The literal `/goal ...` text was treated as inert prose. `num_turns: 1`,
`stop_reason: "end_turn"`, `terminal_reason: "completed"` — the session
ended normally on the very next boundary, exactly as it would have for any
ordinary response. No autonomous continuation, no goal armed. `ls
/tmp/ralph-spike` afterward shows no `SPIKE_DONE.txt` and no goal-state
file of any kind was created by either run.

## Success criteria (from the task brief) — all three failed

| Criterion | Result |
|---|---|
| `/goal` shows an active goal after the command | Never observed — no arming occurred in either run |
| The evaluator drives a second turn without user input | Never observed — Run 1 ended via max-turns exhaustion (not evaluator-driven continuation); Run 2 ended via ordinary `end_turn` after a single turn |
| The goal clears after `cat SPIKE_DONE.txt` output appears | N/A — `SPIKE_DONE.txt` was never created because nothing was armed to begin with |

## Why: documentation + mechanism

Researched against current Claude Code docs (`commands.md`, `goal.md`,
`tools-reference.md`, `plugins-reference.md`, `agent-sdk/slash-commands.md`,
`hooks.md`):

1. **No tool exists** for an assistant to invoke a slash command
   programmatically. `tools-reference.md`'s built-in tool list has nothing
   like `SlashCommand`/`InvokeCommand`/`SetGoal`, and this spike's own
   `ToolSearch` calls for `Goal`, `SetGoal`, `SessionGoal`, `GoalSet`,
   `ArmGoal` all came back empty — consistent with the docs.
2. **Slash-command parsing is a user-input-layer feature, not a
   model capability.** `commands.md`: a command is "only recognized at the
   start of your message" — the *user's* message. The harness does not
   re-parse assistant-generated text for slash commands. Run 2 confirms
   this empirically: literal `/goal ...` text from the assistant is just
   text.
3. **`/goal` itself is documented as "a wrapper around a session-scoped
   prompt-based Stop hook."** This is the load-bearing detail: the
   capability we want (a Stop-time evaluator judging a condition against
   the transcript) does exist under the hood — it's just gated behind a
   human (or SDK host application) literally typing `/goal <condition>` as
   their own message, or the SDK's host code passing `/goal ...` as the
   `prompt` argument to `query()`. Neither applies to a plugin command's
   Markdown body, which only ever produces *assistant* turns.

Net: the design's Task 10 Phase 2 ("Arm /goal with exactly this condition")
as literally written will not work when executed by an assistant following
`build.md`'s instructions — it will either search fruitlessly for a
mechanism (Run 1) or emit inert text and silently fail to arm anything
(Run 2), in both cases proceeding to build without any completion gate at
all. This must be corrected before Task 10 is implemented.

## Fallback mechanism for Task 10

Since `/goal` is confirmed to be "a wrapper around a session-scoped
prompt-based Stop hook" under the hood, the fallback re-implements that
same idea directly as a plugin hook, without needing the `/goal` UI layer:

- `build.md`'s "Arm the goal" step becomes: write the goal condition to a
  file (`.ralph-goal` in the repo root) instead of trying to arm `/goal`.
  On completion (or terminal stop with a delivered PR), delete the file.
- `plugin/hooks/hooks.json` adds a `Stop` hook that reads `.ralph-goal` if
  present, has an LLM judge whether the transcript demonstrates the
  condition, and blocks stopping (with a message describing what remains)
  if not met; allows stopping if met or if no `.ralph-goal` file exists.

**Correction to the brief's candidate schema.** The brief's Step 4 proposed
`"type": "prompt"` for the Stop hook entry with a plain-text prompt and no
declared output contract. That type value is correct, but the output
contract was wrong. Per `hooks-guide.md`'s "Prompt-based hooks" section,
`type: "prompt"` hooks are documented for exactly this judgment-call use
case, including a worked `Stop` hook example ("ask the model whether all
requested tasks are complete"). The model's job is to return a yes/no
verdict as JSON:

- `"ok": true` — the action (stopping) proceeds normally.
- `"ok": false` — for `Stop`/`SubagentStop`, the `reason` string is fed
  back to Claude as its next instruction, forcing another turn.

This is a different contract than `command`-type hooks, which print
`{"decision": "block", ...}` to stdout — that field does **not** apply to
`prompt`-type hooks, and an earlier documentation pass by a research
subagent incorrectly asserted `prompt`-type hooks weren't supported for
`Stop` at all; a follow-up, more careful check of `hooks-guide.md` found
the correct pattern and is what's recorded here. **Corrected, working
form:**

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

The prompt hook has access to `$ARGUMENTS` (hook input, including
`transcript_path` and `cwd`) so it can read both the transcript and
`.ralph-goal`. This schema should still be validated with `claude plugin
validate` and a live Stop-hook trigger before Task 10 ships it — this
spike confirmed the schema against docs but did not execute a live
prompt-hook run end-to-end (out of scope; Task 2's evaluator-discrimination
spike is the natural place to exercise it).

**Task 10 impact:** `build.md`'s Phase 2 ("Arm /goal with exactly this
condition") must be replaced with "write the goal condition to
`.ralph-goal`"; Phase 4/5 completion steps must delete `.ralph-goal` on
both successful completion and terminal stop. `plugin/hooks/hooks.json`
(prompt-type Stop hook, per above) ships alongside `build.md`.
