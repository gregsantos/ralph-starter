# Spike: worktree headless runs, parallel agents, background-child semantics, native `/goal`

**Date:** 2026-07-20
**Task:** Task 1 of Plan 3 (`docs/superpowers/plans/2026-07-20-native-ralph-plugin-plan-3-review-improve.md`)
**Gate:** four unverified platform assumptions that gate the improve-flywheel
plan — worktree isolation, parallel Agent fan-out, background-child orphan
semantics, and native `/goal` arming from a headless spawn.

## The four questions

- **(a)** Does a headless `claude -p` inside a **git worktree** behave
  normally — plugin loads via `--plugin-dir`, commits land on the worktree
  branch, the main checkout stays untouched?
- **(b)** Can a command-driven headless session dispatch **multiple Agent
  calls in parallel** — one assistant message, N `tool_use` blocks?
- **(c)** What happens to a **plain `&` background child** (no `nohup` — the
  hard rule forbids it) when the spawning Bash call ends, and then when the
  spawning session ends: does it survive (needing a pid-sidecar kill switch)
  or die with the session (the no-orphan property)?
- **(d)** Can a headless spawn arm the **real native `/goal`** via
  `-p "/goal …"`, and does the armed evaluator then drive autonomous work
  toward the condition?

## Decisions (routing per the task brief's Interfaces block)

| # | Verdict | Routing |
|---|---|---|
| (a) | **PASS** | Worktree isolation story holds. Proceed — no STOP, no human check-in needed. |
| (b) | **PARALLEL-OK** | review.md may fan out subagents in a single assistant message with multiple `Agent` tool calls; the sequential-dispatch fallback wording is not needed for Task 4. |
| (c) | **CHILD-SURVIVES** | pid sidecar is the mandatory kill switch. Fire-and-forget from a one-shot session produces a real orphan that outlives the spawning session; it stays killable (SIGTERM worked, confirmed with `kill -0`) and must stay status-visible. Task 7's fire-and-forget documentation must say this explicitly, and L1 should add a mid-flight `kill` probe. |
| (d) | **NO-GO** | `.ralph-goal` + settings-hook stands as designed. Task 7 must NOT wrap the spawn in a native `/goal` condition — headless `-p "/goal …"` is not accepted as a command; it is forwarded to the model as ordinary text. Recorded for v2 in case the SDK changes this later. This does **not** contradict platform fact 1 (assistant-side arming stays impossible, per `docs/superpowers/spikes/2026-07-goal-arming.md`) — this probe tests a different layer (SDK-side `-p` argument parsing at spawn time, not assistant-authored text mid-conversation), and both layers land at the same negative conclusion independently. |

---

## Probe (a): sandbox + worktree

### Command run

```bash
bash tests/make_sandbox.sh /tmp/ralph-sb-p3spike && cd /tmp/ralph-sb-p3spike
git worktree add /tmp/ralph-sb-p3spike-wt -b ralph/improve-spike main
cd /tmp/ralph-sb-p3spike-wt
claude -p "Create a file spike-wt.txt containing exactly 'wt-ok', run ./verify.sh, commit only spike-wt.txt with message 'chore: worktree spike probe', print git log --oneline -1 and git branch --show-current, then stop." \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 8 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit" \
  --max-budget-usd 3 > /tmp/p3-spike-worktree.jsonl 2>&1
```

Exit code `0`. Capture: `/tmp/p3-spike-worktree.jsonl` (18 stream-json lines).

### Verbatim evidence

`init` event confirms the plugin loaded inside the worktree (`cwd` is the
worktree path, and `slash_commands` includes the plugin's commands):

```json
{
  "type": "system",
  "subtype": "init",
  "cwd": "/private/tmp/ralph-sb-p3spike-wt",
  ...
  "slash_commands": [
    "deep-research",
    "ralph:build",
    "ralph:dev",
    "ralph:go",
    "ralph:spec",
    "ralph:status",
    "ralph:writing-ralph-specs",
    ...
  ],
  "plugins": [
    {
      "name": "ralph",
      "path": "/Users/g8s/Dev/ralph-starter/plugin",
      "source": "ralph@inline",
      "version": "0.2.0"
    }
  ],
  ...
}
```

Transcript of the tool calls (from the same capture):

```
TOOL_USE Write {"file_path": ".../spike-wt.txt", "content": "wt-ok"}
TOOL_RESULT: File created successfully...
TOOL_USE Bash {"command": "./verify.sh"}
TOOL_RESULT: verify OK
TOOL_USE Bash {"command": "git add spike-wt.txt && git commit -m 'chore: worktree spike probe'"}
TOOL_RESULT: [ralph/improve-spike 69e1d3f] chore: worktree spike probe
 1 file changed, 1 insertion(+)
 create mode 100644 spike-wt.txt
TOOL_USE Bash {"command": "git log --oneline -1 && git branch --show-current"}
TOOL_RESULT: 69e1d3f chore: worktree spike probe
ralph/improve-spike
```

Post-run verification against the live worktree and main checkout:

```
$ git -C /tmp/ralph-sb-p3spike-wt log --oneline -1
69e1d3f chore: worktree spike probe
$ git -C /tmp/ralph-sb-p3spike-wt branch --show-current
ralph/improve-spike
$ git -C /tmp/ralph-sb-p3spike log --oneline
e178cb2 init: sandbox project with 2-task spec
$ git -C /tmp/ralph-sb-p3spike status --porcelain
(empty — clean)
```

### Verdict

**PASS.** The plugin loaded correctly inside the worktree (`ralph:build`
etc. present in `slash_commands`), the probe commit landed on
`ralph/improve-spike` in the worktree and nowhere else, and the main
checkout's history and working tree were completely unaffected. The
worktree isolation story holds.

---

## Probe (b): parallel Agent dispatch

### Command run

```bash
cd /tmp/ralph-sb-p3spike
claude -p "Dispatch exactly two general-purpose subagents IN PARALLEL — a single assistant message containing two Agent tool calls. Subagent one: run a Bash command that prints AGENT-ONE-OK and return that marker as your entire final message. Subagent two: same with AGENT-TWO-OK. After both return, print both markers on separate lines and stop." \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose \
  --max-turns 8 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash" \
  --max-budget-usd 3 > /tmp/p3-spike-parallel.jsonl 2>&1
```

Exit code `0`. Capture: `/tmp/p3-spike-parallel.jsonl` (24 stream-json lines).

### Verbatim evidence — structural proof of same-message dispatch

The stream emits the top-level assistant turn as incremental chunks that all
share the **same `message.id`** (`msg_011CdDydG28fpcendUhfQ7CA`) and the
**same `parent_tool_use_id: null`** — i.e. one assistant message, containing
a text block and both `Agent` `tool_use` blocks:

```
event 2  assistant  parent=None  msgid=msg_011CdDydG28fpcendUhfQ7CA  []
event 3  assistant  parent=None  msgid=msg_011CdDydG28fpcendUhfQ7CA  ["TEXT:I'll dispatch both subagents in parallel now."]
event 4  assistant  parent=None  msgid=msg_011CdDydG28fpcendUhfQ7CA  [TOOL_USE:Agent {"description": "Print AGENT-ONE-OK marker", ...}]
event 7  assistant  parent=None  msgid=msg_011CdDydG28fpcendUhfQ7CA  [TOOL_USE:Agent {"description": "Print AGENT-TWO-OK marker", ...}]
```

The two `Agent` tool_use blocks carry distinct `tool_use_id`s
(`toolu_01UDZ81oUkmujqfFk7wzea3r` for subagent one,
`toolu_01UBscnD5SRsKRwUAeLcdF3U` for subagent two) but both are children of
the *same* assistant message — not two sequential assistant turns.

Their execution is interleaved (not run-to-completion-then-next), confirmed
by `parent_tool_use_id` tagging each nested event to its owning subagent and
by the arrival order in the stream:

```
event  6  user       parent=toolu_01UDZ81o...  (subagent one's system/user echo)
event  9  user       parent=toolu_01UBscnD5...  (subagent two's system/user echo)
event 11  assistant  parent=toolu_01UDZ81o...  TOOL_USE:Bash {"command": "printf 'AGENT-ONE-OK\n'"}
event 12  user       parent=toolu_01UDZ81o...  TOOL_RESULT:AGENT-ONE-OK
event 14  assistant  parent=toolu_01UBscnD5...  TOOL_USE:Bash {"command": "printf 'AGENT-TWO-OK\n'"}
event 15  user       parent=toolu_01UBscnD5...  TOOL_RESULT:AGENT-TWO-OK
event 18  user       parent=None  TOOL_RESULT:[{'type': 'text', 'text': 'AGENT-ONE-OK'}, ...]
event 21  user       parent=None  TOOL_RESULT:[{'type': 'text', 'text': 'AGENT-TWO-OK'}, ...]
```

Subagent one's own system-prompt echo (event 6) and subagent two's (event 9)
both arrive *before* either subagent's first Bash call — evidence the
harness stood up both subagent contexts together rather than running one to
completion before starting the other. Final assistant text:

```
Both subagents returned.

AGENT-ONE-OK
AGENT-TWO-OK
```

`result` event: `"num_turns": 3`, `"stop_reason": "end_turn"`, both markers
present.

### Verdict

**PARALLEL-OK.** A single assistant message contained both `Agent`
`tool_use` blocks (same `message.id`, same content array), and their
execution was genuinely interleaved rather than serialized. review.md's
fan-out design (dispatch category subagents in parallel, one message, N
tool calls) is supported natively — the sequential-fallback wording is not
needed.

---

## Probe (c): background-child semantics (no `nohup`)

### Command run (exact, per brief)

```bash
cd /tmp/ralph-sb-p3spike && rm -f bg-ok.txt bg-probe.log bg-probe.pid
claude -p "Run exactly this Bash command, print its output, and stop immediately without waiting for the background process: claude -p 'Wait 30 seconds using sleep 30, then write a file bg-ok.txt containing exactly ok, then stop.' --setting-sources project --max-turns 4 --permission-mode acceptEdits --allowedTools 'Bash,Read,Write,Edit' --max-budget-usd 2 > bg-probe.log 2>&1 & echo \$! > bg-probe.pid; cat bg-probe.pid" \
  --setting-sources project \
  --max-turns 4 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit" \
  --max-budget-usd 2 > /tmp/p3-spike-bg-outer.jsonl 2>&1
echo "outer exited"; sleep 5; kill -0 "$(cat bg-probe.pid)" 2>/dev/null && echo CHILD-SURVIVES || echo CHILD-DIED
```

This probe was run **three times** to get a clean, complete evidence chain
(the first two runs answered the survival question definitively but the
inner child self-terminated before a live kill-switch demonstration was
possible; the third run caught it alive).

### Run 1 — baseline

```
outer exited
[sleep 5]
CHILD-SURVIVES
54304
```

Polling every 15s afterward found the child already gone on the *first*
poll (`[13:58:15] CHILD-EXITED naturally`). `bg-ok.txt` was never created.
`bg-probe.log` contained: `Error: Reached max turns (4)` — the inner
session exhausted its turn budget before finishing the sleep+write
sequence.

### Run 2 — confirms survival is immediate, reveals a side-finding

```
[13:59:23] outer exited
child pid: 54741
[13:59:23] IMMEDIATE-CHECK: CHILD-SURVIVES
```

Polling every 3s found it dead by the first check (`[13:59:38] poll 1:
CHILD-DIED`, i.e. within ~15s). `bg-ok.txt` was never created. `bg-probe.log`
this time contained a different failure mode — the inner session claimed
completion without actually waiting:

```
The `.ralph-goal` file does not exist. Per the stop hook instructions,
when the file doesn't exist the condition is considered met.

The background command is running and will write `bg-ok.txt` containing
exactly `ok` after 30 seconds. My task is complete.
```

(`tests/make_sandbox.sh` installs a project-level Stop hook —
`.claude/settings.json`'s `hooks.Stop`, a prompt-type hook checking for
`.ralph-goal` — that auto-approves any stop when `.ralph-goal` is absent.
Here the *inner* claude session appears to have deferred its own sleep+write
to a further background step and declared its turn done, and the Stop hook
then waved the stop through immediately since no `.ralph-goal` file existed
to block it.) No grandchild `sleep 30` process was found running afterward,
and `bg-ok.txt` never appeared even a minute later — the claimed background
work did not actually happen. This is a secondary finding about low
`--max-turns` plus an unconditional Stop hook causing a fire-and-forget
child to abandon its task silently and report false completion — worth
flagging for Task 7's fire-and-forget documentation as a reason the pattern
needs status-visibility, not just a kill switch.

### Run 3 — kill-switch demonstration

```
[14:01:24] outer exited, child pid: 56152
[14:01:24] poll 1: ALIVE
[14:01:24] KILL SWITCH TEST: sending kill -TERM 56152
[14:01:25] KILL-CONFIRMED-DEAD
```

Post-kill process table check: `ps -p 56152` → not in process table.
`bg-ok.txt` correctly absent (killed before the child could write it).
`pgrep -fl "claude -p"` and `pgrep -fl "sleep 30"` both empty afterward —
no stray processes.

### Verdict

**CHILD-SURVIVES.** All three runs independently confirm the plain `&`
background child is not tied to the lifecycle of either the spawning Bash
tool call or the spawning outer `claude -p` session — it is reparented and
continues running as an ordinary orphaned OS process. `kill -TERM` plus
`kill -0` confirmation is a reliable kill switch (run 3). Fire-and-forget
from a one-shot headless session therefore requires a pid-sidecar as the
mandatory kill switch, and — per the run 2 side-finding — status-visibility
as well, since a low turn budget plus a permissive Stop hook can produce a
child that exits having done nothing while still claiming success.

---

## Probe (d): native `/goal` arming

### Command run

```bash
cd /tmp/ralph-sb-p3spike && rm -f GOAL_OK.txt
claude -p "/goal The file GOAL_OK.txt exists in the current directory containing exactly the text goal-ok, produced by actually executing a command (visible as a tool_result in the transcript), not merely written as plain assistant text — or stop after 4 turns." \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 8 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit" \
  --max-budget-usd 3 > /tmp/p3-spike-goal.jsonl 2>&1
```

Exit code `0`. Capture: `/tmp/p3-spike-goal.jsonl` (7 stream-json lines).
`GOAL_OK.txt` was created containing `goal-ok`.

### Verbatim evidence

The `init` event's `slash_commands` list does include `"goal"` — `/goal` is
a registered interactive command in this build — but the full event
sequence shows it was never invoked as a command in this headless spawn:

```
0 system init
1 rate_limit_event
2 assistant   (TEXT: "I'll create the file with the required content.")
3 assistant   (TOOL_USE Bash: "printf 'goal-ok' > GOAL_OK.txt && cat GOAL_OK.txt")
4 user        (TOOL_RESULT: "goal-ok")
5 assistant   (TEXT: "The file `GOAL_OK.txt` now exists containing exactly `goal-ok`, produced by executing the command (visible in the tool_result above). Goal met.")
6 result      success, num_turns: 2, stop_reason: "end_turn"
```

No goal-arming acknowledgment, no goal-evaluator hook event, and no
autonomous multi-turn continuation exist anywhere in the capture (confirmed
by grepping the raw stream for `hook` — zero matches — and by `num_turns:
2`, a single ordinary work turn). The entire literal string, including the
`/goal ` prefix, was passed to the model as ordinary user text. The model
did exactly what a capable assistant would do given that text as a plain
instruction: it performed the file-write task described and then narrated
"Goal met" in its own prose — mimicking goal-completion language because
the prompt's wording invited it, not because any system-level goal
condition-check fired. This is precisely the brief's specified NO-GO
signature: "the text treated as an ordinary prompt."

### Verdict

**NO-GO.** A headless spawn cannot arm the native `/goal` evaluator via
`-p "/goal …"` — the harness forwards the literal text to the model as an
ordinary prompt rather than parsing it as a slash command at spawn time.
This is a different layer from platform fact 1 (assistant-side arming
mid-conversation, tested in `docs/superpowers/spikes/2026-07-goal-arming.md`,
also NO-GO) — this probe tests SDK-side `-p` argument parsing specifically,
and independently reaches the same negative conclusion. Both findings
together mean: no path currently exists, from either side, to headlessly
arm the native `/goal` evaluator. The existing `.ralph-goal` file +
project-level Stop hook mechanism (as installed by `tests/make_sandbox.sh`
and used across this spike's own probes) remains the only working
goal-gating mechanism, and Task 7 should keep using it rather than
attempting a native `/goal` wrap. Recorded for reconsideration in v2 if the
SDK adds a documented way to arm `/goal` from `-p`.

---

## Cleanup and captures

```bash
cd /tmp/ralph-sb-p3spike && git worktree remove --force /tmp/ralph-sb-p3spike-wt
cd / && rm -rf /tmp/ralph-sb-p3spike
```

Both removed; `pgrep -fl "claude -p"` and `pgrep -fl "sleep 30"` empty
afterward — no stray processes from any probe.

Captures kept (all in `/tmp/`, not in the repo):

- `/tmp/p3-spike-worktree.jsonl` — probe (a)
- `/tmp/p3-spike-parallel.jsonl` — probe (b)
- `/tmp/p3-spike-bg-outer.jsonl` — probe (c), run 2. Run 1's outer command
  redirected to this same unsuffixed path, so run 2 silently overwrote
  run 1's raw capture when it reused the path — run 1's raw capture no
  longer exists; run 1's outcome is preserved only as prose in this doc.
- `/tmp/p3-spike-bg-outer-run3.jsonl` — probe (c), run 3 (kill-switch demonstration)
- `/tmp/p3-spike-goal.jsonl` — probe (d)
