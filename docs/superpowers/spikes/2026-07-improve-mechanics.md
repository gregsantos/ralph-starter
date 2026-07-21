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

---

## Task 4 smoke runs

**Task:** Task 4 of Plan 3 — `plugin/commands/review.md` (the `/ralph:review`
command) plus three supervised headless smoke runs against the shared
sandbox fixture (`tests/make_sandbox.sh`, which seeds
`review-output/findings.json` with F-001/F-002/F-003 and `.claude/ralph.json`
with only `verificationCommands`, so the default five categories apply).
Sandbox: `/tmp/ralph-sb-review`, removed after R3 per the brief.

Per Task 1's verdict above ((b) = PARALLEL-OK), review.md's step 3 keeps its
"all in a single message so they run in parallel" wording as written — no
sequential-dispatch substitution was needed.

### R1 — full review: merge + dedup against the fixture backlog

Command run exactly as briefed (`claude -p "/ralph:review"`, default five
categories, `--max-turns 25 --max-budget-usd 10`, Bash timeout 600000).
Capture: `/tmp/p3-review-full.jsonl` (233 stream-json lines). Exit: success,
`is_error: false`, `stop_reason: "end_turn"`, `num_turns: 25` — this landed
exactly at the turn cap without being forced there (`stop_reason` is the
model's own `end_turn`, not a cap cutoff), so the margin was thin; worth
raising the smoke's `--max-turns` if this command grows another step.

Checklist, evidence-first:

- **`findings.json` parses; `jq -e '.summary.total == (.findings|length)'` →
  true.** Ran post-hoc: `true`.
- **Fixture findings F-001/F-002/F-003 still present, unmodified; no
  duplicate of F-001's unknown-flag issue among new findings.** `jq` diff of
  F-002/F-003 against the fixture source shows byte-identical
  title/description/suggestion/effort. F-001 unchanged (`"title": "Unknown
  flags are silently ignored"`, `severity: medium`, unchanged `line: 3`).
  Grepped every new finding's description for
  `unknown flag|unrecognized flag|silently ignor` → `NO_DUP_FOUND`. The
  agent's own final-message dedup log confirms the mechanism worked, not
  just the outcome: *"The bug subagent's 'omits --version and unknown-flag'
  finding was dropped as a duplicate: its unknown-flag half = existing
  F-002, its --version half = F-005."* — i.e. the subagent DID rediscover
  the unknown-flag issue (as expected — it's a real bug in greeting.sh) and
  the orchestrator correctly recognized it as already covered by F-001/F-002
  rather than writing a third copy. Zero wording adjustment needed.
- **New finding ids continue from F-004; every new finding has
  `"addressed": null`.** `jq` shows F-004..F-007 (all new), each with
  `"addressed": null`, F-001/F-002/F-003 with no `addressed` key at all
  (schema treats absent as null, per the skill) — preserved exactly as they
  were in the fixture, not backfilled.
- **Five (default categories) Agent tool_use dispatches; parallel = multiple
  Agent tool_use blocks within one assistant message.** `jq` count of
  `type=="tool_use" and name=="Agent"` across the capture = 5. All five
  share the identical `message.id` (`msg_011CdE2HA31jvq8YdEDsSXkt`):
  Security / Bug / Code-quality / Test-coverage / Architecture review, one
  `tool_use_id` each, zero sequential re-dispatch. Structural confirmation
  of PARALLEL-OK from Task 1's probe (b), reproduced live inside the shipped
  command.
- **`REVIEW_REPORT.md` exists with severity sections and the summary
  table.** Confirmed on disk: a Medium section (F-001, F-004, F-005, F-006),
  Low section (F-002, F-007), Info section (F-003), summary table with
  Critical/High/Medium/Low/Info/Total rows, and a closing
  `**Open vs addressed:** 7 open · 0 addressed (of 7 total)` line.
- **Zero commits (`git log --oneline` = 1 init commit), zero branches beyond
  main, working tree shows only the two review-output files modified.**
  `git log --oneline` → 1 line (`init: sandbox project with 2-task spec`);
  `git branch -a` → `* main` only; `git status --short` → `M
  review-output/findings.json` + `?? review-output/REVIEW_REPORT.md`,
  nothing else.

**Verdict: PASS**, all items, zero wording adjustments to review.md.

### R2 — `--focus bug --target greeting.sh`

Command run exactly as briefed (`--max-turns 15 --max-budget-usd 5`, Bash
timeout 300000), same sandbox, findings.json already at 7 from R1.

**Attempt 1** (`/tmp/p3-review-focus.jsonl`, 60 lines): the run DID Write
`review-output/findings.json` (tool_use at line 68 of that capture, content
verified: `scope` updated to `target: "greeting.sh"`, `focus: ["bug"]`,
still 7 findings, F-004..F-007 each `"addressed": null`) and ran the
required `jq -e '.summary.total == (.findings | length)'` validation
immediately after, which printed `true` in the transcript — then died
mid-response, immediately after that validation and before step 6
(`REVIEW_REPORT.md` regeneration) ran: `result.is_error: true`,
`result: "API Error: Connection closed mid-response..."`,
`terminal_reason: "api_error"`, `num_turns: 8`. `REVIEW_REPORT.md` on disk
still showed R1's stale scope line (never reached). This is a
transport-layer failure (`server_error` on the trailing assistant event),
not a review.md logic defect. Critically, the write did NOT corrupt or
duplicate anything: byte-diffing the written `findings` array against both
R1's prior output and the eventual final state (attempt 3, below) shows all
three identical — same 7 findings, same ids/categories/severities/titles,
same `addressed: null` on F-004..F-007. The bug subagent had (correctly)
found zero new findings, so this write's *content* was a no-op even though
the *write itself* did execute — "no corruption" is accurate, "no write"
is not.

**Attempt 2** (`/tmp/p3-review-focus-retry.jsonl`, 32 lines): same
transport error, this time before even dispatching the Agent call (transcript
ends right after "Dispatching the single-category (bug) read-only
subagent."). Unlike attempt 1, this attempt made no writes at all —
`findings.json`/`REVIEW_REPORT.md` mtimes confirmed unchanged by this
attempt. Both attempts' failure mode is safely inert (attempt 1 because the
write was content-idempotent, attempt 2 because it never got far enough to
write).

**Attempt 3** (`/tmp/p3-review-focus-retry2.jsonl`, 83 lines): succeeded,
`exit 0`, and is the run whose output is credited as R2's pass. Investigated
from the capture only (no re-run) because it surfaced something the brief
specifically asked to be scrutinized: the single capture contains two
`type: "result"` events and, unusually, two `type: "system", subtype: "init"`
events, both sharing one `session_id` (`c8dcc4ea-15bc-4fe5-9649-afc0afd3b6d8`).

*Field-by-field diff of the two `init` events* (full JSON at capture lines 1
and 51): **identical** — `session_id`, `cwd`
(`/private/tmp/ralph-sb-review`), `model` (`claude-opus-4-8`),
`permissionMode` (`acceptEdits`), `apiKeySource`, `claude_code_version`
(`2.1.215`), `plugins` (`ralph` at `/Users/g8s/Dev/ralph-starter/plugin`,
v0.2.0 — still loaded), and `slash_commands` (still includes `ralph:review`
and the rest of the plugin's commands). **Different**: `tools` — the first
init lists the standard 32-tool baseline (`Task, Bash, ..., Read, ...,
Write`, no `mcp__*` entries, no `ListMcpResourcesTool` /
`ReadMcpResourceDirTool` / `ReadMcpResourceTool`); the second init's `tools`
array adds those three MCP-resource tools plus ~90 `mcp__claude_ai_*` tool
names (Ashby, Gmail, Google Calendar, Google Drive, Granola, Notion, Slack,
Forgd Ashby Scorecard). **`mcp_servers`** — first init: `[]`; second init:
29 entries with real connection state (`"claude.ai Slack": "connected"`,
`"claude.ai Gmail": "connected"`, `"claude.ai Notion": "connected"`,
`"claude.ai Google Drive": "connected"`, `"claude.ai Granola": "connected"`,
`"claude.ai Ashby": "connected"`, `"claude.ai Forgd Ashby Scorecard":
"connected"`, plus ~20 `"needs-auth"` entries for Asana/Atlassian/Box/
Canva/Figma/HubSpot/Intercom/Linear/monday.com/etc.) — this is not a generic
or sandboxed roster; it is the exact set of third-party integrations
connected to the operator's real, ambient Claude account (the same names
visible among this session's own deferred MCP tools), which
`--setting-sources project` exists specifically to keep out of a headless
sandbox run.

*What the second leg actually was*, established from event correlation and
timestamps: at capture line 22 the outer orchestrator dispatched the bug
subagent via `Agent`, and the tool result (line 25) shows
`"isAsync": true, "status": "async_launched"` — the SDK ran it as a
background task (`task_id a3dda28ec846fff6d`), not nested synchronously
in-message (this async-dispatch pattern is normal and appeared in R1 and R3
too — both show `isAsync` 5 times each, once per parallel category
subagent, with zero re-init anomaly in either). Two `system, subtype:
api_retry` events appear in this capture only (lines 15 and 54;
`attempt: 1, max_retries: 10, error_status: null, error: "unknown"`) — soft,
auto-retried transient failures, structurally distinct from attempts 1/2's
hard `terminal_reason: "api_error"` fatal drops. R1 and R3, which had zero
`api_retry` events, also had exactly one `init` each; only this run — the
one with `api_retry` events — shows the second `init`. The second `init`
(line 51) lands immediately after the `task_notification` (line 50)
reporting the bug subagent's completion, sharing the same outer
`session_id` and carrying no `parent_tool_use_id`/`task_id` tag of its own
(unlike the subagent's own nested transcript at lines 27-28+, which is
correctly tagged `parent_tool_use_id: toolu_01HKfZzs3a5UY77yk934KCJm`
throughout and shows no init duplication). This is the OUTER orchestrator
session re-initializing itself upon resuming from the async task's
notification — not the subagent's own init, and not a hard crash-and-restart
like attempts 1/2 (this run's overall `result.is_error` is `false` throughout).

*Which leg produced the final artifacts*: `findings.json` was never
re-Written this run (0 new findings; the orchestrator only re-ran `jq`
validation against it, at capture lines 62 and 79, both after line 51) —
the only mutating write, `REVIEW_REPORT.md` (`Write` tool_use at line 68),
also ran after line 51. So the leg that actually produced this run's
user-visible output ran entirely under the second, ambient-roster `init`,
not the original isolated one.

*Mitigating fact, also load-bearing*: across this entire capture, every
`tool_use` invoked is one of `Agent, Bash, Edit, Read, ToolSearch, Write` —
grepping for any invoked tool name matching `mcp__` returns zero hits. The
session became *able* to see and call dozens of live third-party
integrations it should never have had visibility into, but nothing in this
run actually called one.

**PLATFORM FINDING — follow-up required.** A headless `claude -p` run under
`--setting-sources project --plugin-dir <path>` is not guaranteed to keep
its tool/MCP-server isolation for the full process lifetime: when a
subagent dispatched via the async `Agent`-tool path (`isAsync: true`)
completes and its `task_notification` triggers the outer session to resume
(observed here alongside soft `api_retry` events — not the hard
`terminal_reason: "api_error"` failures of attempts 1/2), the resumed leg's
second `init` event advertised the operator's full ambient tool/MCP roster
instead of the empty, isolated one the original invocation's flags produced
— while `plugins`, `slash_commands`, `permissionMode`, `model`, and `cwd`
all remained correctly pinned. Session identity (`session_id`) and the
review command's own context survived intact; only the tool-surface
isolation leaked. No `mcp__*` tool was actually invoked in this capture, so
this run caused no observable side effect beyond the roster leak itself —
but the capability was live, and a less carefully-scoped subagent prompt
(or a less benign findings-writing step) could have reached it. This
warrants a dedicated follow-up probe before this pattern is treated as
covered by the worktree/parallel-dispatch findings above (probes (a)/(b)):
specifically, whether async-Agent-dispatch + `task_notification` resume
after any soft retry reliably re-derives the outer session's tool
discovery from ambient settings rather than the original `--setting-sources
project` invocation flags, and whether this also holds for `mcp_servers`
that grant write/action capabilities rather than the read-oriented ones
listed here.

Checklist, evidence from the successful attempt 3 (state is cumulative —
attempt 1's write was content-identical to what was already there, attempt
2 made no writes, so attempt 3 is the only run in this sequence that changed
what's actually credited as R2's output — the `REVIEW_REPORT.md` rewrite):

- **Exactly ONE Agent dispatch (bug only).** `jq` count = 1;
  `input.description: "Bug review of greeting.sh"`.
- **`scope.focus == ["bug"]`.** Confirmed in `findings.json`:
  `"focus": ["bug"]`, `"target": "greeting.sh"`.
- **Prior findings (from R1) preserved.** All seven findings' `id` /
  `category` / `severity` / `title` fields byte-identical to R1's output;
  `summary.total` still 7 (0 new — the bug subagent correctly recognized
  every candidate bug in the 3-line `greeting.sh` as already covered by
  F-001/F-004/F-007, per its own final message).
- **Ids continue.** No new findings were generated this run, so there was
  nothing to continue past F-007 — satisfied vacuously (the mechanism was
  already proven with real continuation in R1's F-004..F-007 and R3's
  F-008..F-012 below).
- Bonus check (not in the R2 checklist but confirmed): `REVIEW_REPORT.md`
  was correctly regenerated in the successful attempt, scope line reading
  "target `greeting.sh` · diff base _(none)_ · focus: bug", and the working
  tree still showed only the two review-output files touched.

**Verdict: PASS** (on the third attempt). Zero wording adjustments to
review.md — both failures were transport-layer, not logic/dedup issues.

### R3 — `--diff-base HEAD~1`

Setup exactly as briefed:
`printf '\n# touched for diff-base probe\n' >> verify.sh && git add verify.sh
&& git commit -qm "test: touch verify.sh"` → `git log --oneline` now 2
commits. Command run exactly as briefed (`--max-turns 15
--max-budget-usd 5`, Bash timeout 300000). Capture:
`/tmp/p3-review-diffbase.jsonl` (186 lines). Exit: success,
`is_error: false`, `stop_reason: "end_turn"`, `num_turns: 19`.

Checklist, evidence-first:

- **`scope.diffBase == "HEAD~1"`.** Confirmed in `findings.json`:
  `"diffBase": "HEAD~1"`, `"target": "verify.sh"` (the only file `git diff
  --name-only HEAD~1...HEAD` returned that falls under the repo's source
  files).
- **The dispatched subagents' target lists contain only `verify.sh`.**
  Inspected each `Agent` tool_use's full `input.prompt`: every one of the
  five (Security/Bug/Code-quality/Test-coverage/Architecture) states
  *"Target file (the ONLY file in scope):
  `/private/tmp/ralph-sb-review/verify.sh`. You may read `greeting.sh`,
  `requirements.md`, `specs/sandbox.json` for context but only REPORT
  findings whose file is `verify.sh`."* — no subagent was given `greeting.sh`
  as a reportable target. All five share one `message.id`
  (`msg_011CdE6UanougfgcYmVD6tTQ`) — parallel dispatch held here too.
- **Backlog merge semantics intact.** `jq -e '.summary.total ==
  (.findings|length)'` → `true`. F-001..F-007 present with unchanged
  `category`/`addressed`. Five new findings F-008..F-012 (1 medium, 4 low,
  0 critical/high/info) added, continuing the id sequence correctly. The
  agent's own report lists the dedup decisions made against the diff-base
  scope: the grep-guard root cause (already F-004) and the --version/
  unknown-flag/--name bug variants (already F-005/F-002/F-006) were all
  recognized as duplicates and folded into the existing findings' context
  rather than re-reported.
- `REVIEW_REPORT.md` regenerated with the diff-base scope line: "target
  `verify.sh` · diff base `HEAD~1` · focus: security, bug, code-quality,
  test-coverage, architecture", and a closing
  `**Open vs addressed:** 12 open · 0 addressed (of 12 total)` line.

**Verdict: PASS**, all items, zero wording adjustments to review.md.

### Wording adjustments to review.md

**None.** All three runs' checklists passed against review.md exactly as
written in Task 4's brief — including the dedup nuance the brief flagged as
the likeliest failure mode (F-001's unknown-flag issue being rediscovered
and needing to merge rather than duplicate), which held on the first R1
attempt. The two hard failures observed were infra-layer (`terminal_reason:
"api_error"`, "Connection closed mid-response") during R2's attempts 1-2,
unrelated to review.md's content, and resolved by retrying rather than
editing the command. Separately, R2's successful attempt 3 surfaced a
platform-level tool-isolation finding (see the "PLATFORM FINDING" callout
in R2 above) — not a review.md defect, but a follow-up item for the
headless-isolation story this plan otherwise relies on.

### Cleanup and captures

```bash
cd / && rm -rf /tmp/ralph-sb-review
```

Removed after R3. Captures kept (all in `/tmp/`, not in the repo):

- `/tmp/p3-review-full.jsonl` — R1 (233 lines)
- `/tmp/p3-review-focus.jsonl` — R2 attempt 1, infra failure after
  `findings.json` write, before report regen (60 lines)
- `/tmp/p3-review-focus-retry.jsonl` — R2 attempt 2, infra failure before
  Agent dispatch, no writes (32 lines)
- `/tmp/p3-review-focus-retry2.jsonl` — R2 attempt 3, successful (83 lines)
- `/tmp/p3-review-diffbase.jsonl` — R3 (186 lines)

---

## Task 5 smoke run

**Task:** Task 5 of Plan 3 — wire `plugin/commands/build.md`'s Phase 1
step 6 to read `defaultBudgets.buildTurnsFactor`/`buildHours` from
`.claude/ralph.json` (defaults 2/2, preserving prior behavior), rename the
hardcoded "2 hours" in the Phase 2 goal condition and the Phase 3/4 cap
checks to `HOURS_CAP`, and add a current-timestamp `now` field to the
`RALPH TURN` line so the wall-clock clause is transcript-evaluable (a
Plan 1 deferred item). Sandbox: `/tmp/ralph-sb-caps`, built from
`tests/make_sandbox.sh` with `.claude/ralph.json` patched via `jq` to add
`{"defaultBudgets": {"buildTurnsFactor": 3, "buildHours": 1}}` before the
first commit, against a fresh bare remote (not GitHub) — removed after the
run per the brief.

Command run exactly as briefed (`claude -p "/ralph:build specs/sandbox.json"`,
`--max-turns 30 --max-budget-usd 10`, Bash timeout 600000, invoked via a
tracked background process with a bounded poll/kill guard rather than
`nohup`/`disown`). Capture: `/tmp/p3-build-caps.jsonl` (159 stream-json
lines). Exit: success, `is_error: false`, `stop_reason`/`subtype: success`,
`num_turns: 27`. The process exited on its own after ~181s — well inside
the 12-minute safety window, no kill needed, no retry needed.

Checklist, evidence-first:

- **TURN_CAP honored the override.** `RALPH TURN 1/6` and `RALPH TURN 2/6`
  both appear (3 × 2 tasks = 6, not the old hardcoded 4), confirming
  Phase 1 step 6 read `buildTurnsFactor: 3` from the sandbox's
  `.claude/ralph.json` rather than falling back to the default of 2.
- **Turn line carries a real `now` timestamp.** Both turn lines matched
  `, now 20...`:
  `RALPH TURN 1/6 (build started 2026-07-20T23:00:29Z, now
  2026-07-20T23:00:45Z)` and `RALPH TURN 2/6 (build started
  2026-07-20T23:00:29Z, now 2026-07-20T23:01:40Z)` — two distinct,
  increasing timestamps, not a copy of `BUILD_START`.
- **`.ralph-goal` condition names the 1-hour override and keeps the
  provenance clause verbatim.** Read back from the transcript's file-create
  tool result, the written condition ends "...or the transcript shows a
  RALPH TURN line where k >= 6, or shows a RALPH TURN line whose 'now'
  timestamp is more than 1 hours past its 'build started' timestamp." — the
  `<HOURS_CAP>` substitution landed correctly. The provenance clause earlier
  in the same string ("was produced by running
  `.../ralph-evidence.sh specs/sandbox.json --full` as a real command
  execution (visible as tool output in the transcript), not authored as
  plain assistant text, shows the tasks summary line reporting all tasks
  passed — 2 total | 2 passed — with zero in_progress/pending/blocked,
  every verify line exiting 0, and verifier: PASS") is byte-identical to
  build.md's unmodified wording — confirming the edit didn't bleed into the
  clause the brief said not to touch.
- **Both tasks completed, verifier PASS.** `ralph-evidence.sh --full`
  output in the agent's final report: `tasks: 2 total | 2 passed | 0
  in_progress | 0 pending | 0 blocked`, `T-001 [passed]`, `T-002 [passed]`,
  `verify: ./verify.sh -> exit 0`, `verifier: PASS`. The spec's `verifier`
  field was written with `"verdict": "PASS"`.
- **Exactly one push to the bare remote.** Grepped every dispatched Bash
  tool_use for `push`: a single match, `rm -f .ralph-goal && echo "deleted
  .ralph-goal" && git push -u origin ralph/sandbox-greeting 2>&1` (Phase 4
  step 6's combined push + goal-delete). The bare remote's refs after the
  run showed only `ralph/sandbox-greeting` (5 commits, matching the local
  branch) — no `main` ref was ever pushed there.
- **Honest `gh pr create` failure report.** The tool result for `gh pr
  create` was `Exit code 1`, `is_error: true`, message "none of the git
  remotes configured for this repository point to a known GitHub host." —
  expected, since the remote is a local bare repo, not GitHub. The agent's
  final message surfaced this plainly under a "One caveat — PR was not
  opened" heading, explained the cause, and pointed at the prepared PR body
  file rather than papering over the gap or fabricating a PR URL.
- **`main` untouched, `.ralph-goal` absent afterward.** The sandbox's local
  `main` still sat at the two setup commits (`test: add build budget
  overrides`, `init: sandbox project with 2-task spec`); all build commits
  landed on `ralph/sandbox-greeting`. `.ralph-goal` did not exist in the
  sandbox root after the run.

No retry was needed — the run completed cleanly on the first attempt,
comfortably under both the 6-turn and 1-hour caps the override configured.

**Verdict: PASS**, all checklist items, on the first attempt.

### Cleanup and captures

```bash
cd / && rm -rf /tmp/ralph-sb-caps "$REMOTE"
```

Removed after the run (sandbox and the temporary bare remote directory).
Capture kept: `/tmp/p3-build-caps.jsonl` (159 lines).

## Task 6 smoke runs

**Task:** Task 6 of Plan 3 — `plugin/commands/improve-cycle.md`, the inner
improve unit of work (guard → review → select → fix-spec → mini-build →
backlog reconciliation → cleanup), composed by Reading the shipped
review/spec/build command files from `${CLAUDE_PLUGIN_ROOT}`. The command
text matches the plan brief verbatim and `claude plugin validate ./plugin`
passes.

### C1 — guard refuses a real checkout: PASS

Sandbox `/tmp/ralph-sb-cycle` (fresh from `tests/make_sandbox.sh`), on
`main`, invoked `claude -p "/ralph:improve-cycle"` with a read-only
allowlist (`Bash,Read,Glob,Grep`), `--max-turns 4 --max-budget-usd 2`.
Capture: `/tmp/p3-cycle-guard.jsonl`. Result: `subtype: success`,
`num_turns: 2`, cost $0.13. The final message:

> **Guard check failed — aborting. Nothing changed.** … I'm on `main` (a
> default branch) … **Branch:** `main` (expected `ralph/improve-*`) ❌ …
> **Action taken:** none

`git status --porcelain` in the sandbox stayed empty — zero writes, no
findings/spec/goal files created. The guard works.

### C2 — full cycle: attempt history (honest record)

The brief specified `--max-turns 15`. That cap was **insufficient** and the
controller sanctioned raising the improve tier default to 50 (binding
mid-plan decision; consumers: Task 7's launcher default, Task 8's config
example + README). The dollar cap stayed at 10. History:

- **Attempt 1** (`p3-cycle-full-attempt1-interrupted.jsonl`): infra
  failure while streaming (`error_during_execution`), not a cycle defect.
- **Attempt 2** (`p3-cycle-full-attempt2-maxturns15.jsonl`):
  `error_max_turns` at `num_turns: 16` — the brief's 15-turn cap kills a
  correctly-executing cycle mid-flight.
- **Attempt 3** (`p3-cycle-full-attempt3-killed.jsonl`): killed by
  controller order under the same 15-turn regime
  (`error_during_execution`, 12 turns).
- **Attempt 4**: the prior session's live observation (recorded in the
  ledger and handoff) was a `max_turns` stop at a 30-turn cap with the
  cycle deep in correct execution — worktree log showed `chore: review
  backlog` → spec commit → T-001 complete → T-002 mid-build, zero pushes.
  **Capture-file discrepancy disclosed:** the two files labeled attempt 4
  (`…attempt4-transporterror.jsonl`, `…attempt4-maxturns30.jsonl`) show
  `success/15 turns (is_error: true)` and `error_during_execution/9
  turns` respectively — neither carries the `error_max_turns/30` result
  the narrative describes, so the file labels and the attempt numbering
  cannot be fully reconciled after the fact. The load-bearing findings
  (15 insufficient; deep-execution kill leaves no partial PR) rest on
  attempt 2's capture and the ledger's live observation, not on these two
  files.
- **GUILLOTINE finding** (carried from the ledger's live observation): an
  *outer* CLI `--max-turns` kill mid-build leaves NO partial draft PR —
  zero refs on the bare remote — unlike the *inner* build TURN_CAP, which
  routes gracefully to build.md Phase 5 and attempts a draft partial PR.
  The outer cap is therefore a BACKSTOP and must sit comfortably above
  the inner graceful caps (TURN_CAP = buildTurnsFactor × tasks, plus the
  review/select/spec phases' turns).

### C2 attempt 5 (2026-07-21, fresh session) — PASS

Completely fresh environment per the brief: `tests/make_sandbox.sh
/tmp/ralph-sb-cycle`, fresh bare remote `/tmp/ralph-sb-cycle-remote.git`
added as `origin`, worktree `/tmp/ralph-sb-cycle-wt` on branch
`ralph/improve-smoke`, Stop-hook settings copied to the worktree's
`.claude/settings.json`, pid sidecar `/tmp/ralph-sb-cycle-wt.pid` written
by the controller shell (simulating the launcher). Invocation exactly as
briefed except the sanctioned caps: `claude -p "/ralph:improve-cycle"
--plugin-dir …/plugin --setting-sources project --max-turns 50
--permission-mode acceptEdits --allowedTools
"Agent,Bash,Read,Write,Edit,Glob,Grep" --max-budget-usd 10`, run through
the Bash tool's managed background facility (no nohup/disown/setsid).
Capture: `/tmp/p3-cycle-full-attempt5.jsonl`.

**Result: `subtype: success`, `num_turns: 47`, cost $4.61, 666s** — the
cycle reached its own terminal state under the 50-turn cap (47 of 50 also
shows how little headroom 30 left). Checklist, evidence-first:

- **Guard passed.** Branch `ralph/improve-smoke`, clean tree; init event's
  `slash_commands` included the full `ralph:*` set (plugin loaded in the
  worktree).
- **I-1 review executed by reference.** Five read-only category subagents
  dispatched (stream shows five `Explore`-type Agent tool_use blocks
  before any builder); 5 new findings (F-004…F-008) merged into the
  fixture backlog after root-cause dedup — the agent reported the
  `grep 'shout'` source-inspection gate was independently found by 4
  categories and merged to ONE finding. Final backlog: 8 findings
  (3 medium, 3 low, 2 info), `summary.total == findings|length`.
- **I-2 selection correct.** N=3 respected: F-001, F-004, F-005 (all
  medium) selected; F-003/F-008 (info) excluded by rule; PR-overlap
  filter honestly SKIPPED with the reason stated (`gh` cannot reach a
  local bare remote); all three candidates revalidated against the
  working tree, none stale-marked.
- **I-3 fix-spec.** `specs/improve-2026-07-21.json` created with 2 atomic
  tasks whose descriptions cite the findings ("Fixes F-001", "Fixes F-004
  and F-005"); evidence script exit 0 in the transcript. The review
  backlog was committed BEFORE the first builder dispatch — stream order:
  `git add review-output && git commit -m "chore: review backlog for
  improve cycle"` precedes the first `ralph:ralph-builder` Agent
  dispatch.
- **I-4 build.** TURN_CAP 4 (2 × 2 tasks), two fresh `ralph:ralph-builder`
  dispatches, `ralph:ralph-verifier` dispatched at completion with
  verdict PASS (12/12 criteria). Worktree log after the run:
  `chore: review backlog for improve cycle` → `chore: add spec for
  Improve 2026-07-21` → T-001 start/feat/complete → T-002
  start/test/complete → `chore: verifier PASS for Improve 2026-07-21`.
- **Exactly one push.** Grepping every Bash tool_use for `git push`:
  one match (`git push -u origin ralph/improve-smoke`). The bare remote's
  refs after the run: exactly `refs/heads/ralph/improve-smoke` — no main,
  nothing else.
- **Honest `gh pr create` failure; Phase I-5 correctly skipped.**
  `gh pr create` was attempted and failed (local bare remote is not a
  GitHub host); the final message reports "**PR: not created**" with the
  cause, and Phase I-5 is explicitly skipped with "Findings **F-001,
  F-004, F-005 remain open** (`addressed: null`) for the next cycle" —
  no fabricated PR, no bogus backlog reconciliation.
- **Cleanup complete, pid last.** After the run:
  `/tmp/ralph-sb-cycle-wt.selected.json` gone, `.ralph-goal` gone, the
  pid sidecar `/tmp/ralph-sb-cycle-wt.pid` GONE; the final message names
  the pid-last ordering ("pid last, signaling the launcher this cycle
  ended") and tells the human the worktree is removable.
- **Sandbox main untouched.** `git -C /tmp/ralph-sb-cycle log --oneline`
  = the single init commit; `git status --porcelain` empty.

**Verdict: PASS**, every checklist item, on the first attempt at the
sanctioned 50-turn cap.

### Cleanup and captures

Worktree removed (`git worktree remove --force`), sandbox and bare remote
deleted. Captures kept: `/tmp/p3-cycle-guard.jsonl`,
`/tmp/p3-cycle-full-attempt{1,2,3,4*,5}.jsonl` (volatile `/tmp` copies;
this appendix is the durable record).

## Task 7 smoke runs

**Task:** Task 7 of Plan 3 — `plugin/commands/improve.md`, the
`/ralph:improve` launcher (busy checks → fresh worktree → capped headless
spawn of `/ralph:improve-cycle` → report or `--wait`), plus
`status.md`'s new tick-reporting step 5. Binding controller overrides
applied to the brief text: `improveTurns` default is **50**, not 15; the
native-`/goal` wrapped spawn-prompt alternative is **omitted** (Task 1's
verdict (d) was NO-GO — `-p "/goal …"` is forwarded as literal text, so
the spawn prompt is plainly `/ralph:improve-cycle`); step 5's lifetime
sentence reflects **CHILD-SURVIVES** (Task 1 verdict (c)) — the spawned
tick outlives the launching session, bounded only by its caps, with the
pid sidecar as the mandatory kill switch. `claude plugin validate
./plugin` passed before any smoke ran.

### L1 — fire-and-forget launch: PASS

Sandbox `/tmp/ralph-sb-launch` + bare remote
`/tmp/ralph-sb-launch-remote.git` added as `origin`. First invocation
exactly as briefed (`--max-turns 10 --max-budget-usd 3`,
`Bash,Read,Glob,Grep`), capture `/tmp/p3-launch-fire.jsonl`: `subtype:
success`, `num_turns: 12`, cost $0.43.

- **Busy checks correct.** No existing `ralph-improve-` worktrees; `gh pr
  list` failed (`none of the git remotes … point to a known GitHub
  host`) — warned and continued, per spec.
- **Caps read correctly.** Sandbox `.claude/ralph.json` has no
  `defaultBudgets` → the launcher reported "defaults apply —
  `improveTurns=50`, `improveUsd=10`" verbatim, confirming the Step-1
  override (else 50, not else 15) is live.
- **Worktree + branch:** `/tmp/ralph-improve-20260721-092622` on
  `ralph/improve-20260721-092622`, created off `main`.
- **Stop-hook carry side-finding:** the launcher's `cp` command for
  `$WT/.claude/settings.json` hit a permission prompt (compound `if`
  command) and was denied once — but the file already existed, because
  `.claude/settings.json` is git-tracked (Task 2) and materialized
  automatically when `git worktree add` checked out the branch. The
  launcher's own existence check (`if [ ! -f … ]`) correctly detected
  this on retry and skipped the redundant copy, exactly as Step 3
  specifies. Not a defect — the carry logic degrades gracefully when the
  file arrives by another path.
- **Spawn command matched the brief's shape verbatim**
  (`--plugin-dir …/plugin --setting-sources project --permission-mode
  acceptEdits --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep"
  --max-turns 50 --max-budget-usd 10 --output-format stream-json
  --verbose … & echo $! > "$WT.pid"`, spawn prompt plainly
  `/ralph:improve-cycle` — no `/goal` wrapping). Pid sidecar named a real
  process: `ps -p 81604` showed the exact `claude -p /ralph:improve-cycle
  …` command line.
- **Final message complete:** path, branch, PID (81604, "confirmed
  alive"), log path, caps table (50 turns / $10), watch instructions
  (`tail -f`, `/ralph:status`), kill instructions (`kill 81604`), and the
  CHILD-SURVIVES sentence verbatim ("survives this session … bounded
  only by its caps … PID sidecar … is the kill switch").

**Full-cycle end state (spike verdict (c), CHILD-SURVIVES branch).**
Polled PID 81604 from the controlling shell in bounded loops (`kill -0`
every 15s); it exited after ~570s (~9.5 min). Verified against Task 6
C2's class:

- Pid sidecar `/tmp/ralph-improve-20260721-092622.pid` — **gone**.
- `.selected.json` — **gone**. Worktree `git status --porcelain` —
  **empty**.
- Worktree log: `chore: review backlog for improve cycle` → `chore: add
  spec for Improve 2026-07-21` → T-001/T-002 complete → `chore: verifier
  PASS for Improve 2026-07-21`.
- Bare remote refs: exactly `refs/heads/ralph/improve-20260721-092622` —
  one push, no PR ref (matches "exactly one push" from Task 6 C2).
- Log's final message: honest `gh pr create` failure (local bare remote
  is not a GitHub host); findings F-001/F-002/F-005 reported open for the
  next cycle.
- Sandbox `main` untouched: single init commit, clean tree.

**Kill-switch + CRASHED-detection probe (second tick).** Re-invoked the
launcher (capture `/tmp/p3-launch-fire2.jsonl`): the outer result was
`subtype: error_max_turns` at `num_turns: 11` against the smoke's own
`--max-turns 10` cap — **a deviation, disclosed honestly**: the
transcript shows the launcher's actual work (busy check found the first
worktree finished-and-clean → removed it + its log → created
`/tmp/ralph-improve-20260721-093825` on `ralph/improve-20260721-093825`
→ spawned PID 84290, confirmed alive → delivered the full path/branch
/pid/log/caps/kill report) **completed correctly before** the max-turns
cutoff; the same compound-command permission prompt from L1 fired again
and cost an extra turn, which then ran out during a trailing Stop-hook
evaluation turn. The launcher's own logic was not at fault — this is an
artifact of the smoke's tight 10-turn outer cap combined with permission-
prompt retry overhead, not a `/ralph:improve` defect. Killed PID 84290
mid-flight (`kill 84290`); confirmed dead 1s later; the pid sidecar was
left in place (the cycle only removes it as its own last act, so a
killed cycle correctly leaves a stale sidecar behind). Third invocation
(capture `/tmp/p3-launch-busy-crashed.jsonl`): `subtype: success`,
`num_turns: 6`, cost $0.33 — reported the tick as **CRASHED**
(worktree/branch/dead-PID table, inspect/`git worktree remove --force`
instructions), **stopped**, and created no third worktree
(`git worktree list` confirmed only the sandbox + the crashed worktree
afterward). Manually cleaned the crashed worktree per its own
instructions.

**Verdict: PASS.** Every L1 checklist item held: worktree/branch/pid/log/
caps/kill-instructions present on first launch; full-cycle end state
matches Task 6 C2's class; the kill switch works and the next launcher
invocation correctly reports CRASHED and stops rather than auto-removing
or stacking.

### L2 — busy-check triple: PASS

Same sandbox. Manufactured each state with a fake worktree
`/tmp/ralph-improve-fake` on branch `ralph/improve-fake`.

1. **RUNNING:** `sleep 600 &` backgrounded from the controller shell
   (PID 84895, confirmed to persist across tool calls — CHILD-SURVIVES
   holds for plain shell children too), pid written to
   `/tmp/ralph-improve-fake.pid`. Invocation (capture
   `/tmp/p3-launch-busy-running.jsonl`): `subtype: success`, `num_turns:
   5`. Reported "a tick is already **RUNNING**" with worktree/branch/PID
   84895 "alive — verified with `kill -0`", stopped; `git worktree list`
   confirmed no new worktree. Killed the sleep afterward.
2. **CRASHED:** left the now-dead PID in the sidecar. Invocation
   (capture `/tmp/p3-launch-busy-crashed2.jsonl` — distinct from L1's
   `p3-launch-busy-crashed.jsonl` to avoid collision): `subtype: success`,
   `num_turns: 4`. Reported **CRASHED**, dead PID 84895, inspect/remove
   instructions, stopped; no new worktree.
3. **FINISHED:** `rm /tmp/ralph-improve-fake.pid` (tree clean).
   Invocation (capture `/tmp/p3-launch-busy-finished.jsonl`): `subtype:
   success`, `num_turns: 1`. Removed the fake worktree, then created and
   spawned a real tick (`/tmp/ralph-improve-20260721-094352` on
   `ralph/improve-20260721-094352`, PID 85716 confirmed alive) — the
   full launch path exactly as L1.

**Status tick reporting.** While PID 85716's tick was RUNNING, ran
`/ralph:status` once (read-only allowlist, capture
`/tmp/p3-status-tick.jsonl`): `subtype: success`, `num_turns: 7`. Output
included the new step-5 row verbatim in shape: `**Improve tick**
`ralph-improve-20260721-094352` | **RUNNING** (pid 85716 alive)` —
confirming status.md's appended step fires correctly alongside steps 1–4
(goal none active, spec 2 pending, PRs "gh unavailable", branches/
worktrees table).

Killed PID 85716 and force-removed its worktree + sidecars afterward
(full-cycle end state was already proven by L1 and is proven again by
L3; no need to let a second full cycle run to completion here).

**Verdict: PASS.** All three busy-check states detected correctly (no
stacking in RUNNING/CRASHED; correct auto-clean-then-launch in FINISHED),
and `/ralph:status` step 5 renders the tick line while a tick exists.

### L3 — `--wait`: PASS

Fresh sandbox `/tmp/ralph-sb-launch-wait` + bare remote
`/tmp/ralph-sb-launch-wait-remote.git`. Invocation exactly as briefed
(`--max-turns 25 --max-budget-usd 15`, capture
`/tmp/p3-launch-wait.jsonl`), run via the Bash tool's `run_in_background`
facility and polled in two bounded active-poll windows (10 min + ~9 min;
no bare `sleep` chains, no Monitor/notification standby — checked
`pgrep -f "claude -p .ralph:improve --wait."` and the capture file's
tail every 20s inside each window) until the outer process exited.

**Outer launcher result:** `subtype: success`, `num_turns: 15`,
`total_cost_usd: $0.54`, `duration_ms: 866273` (~14.4 min wall-clock —
comfortably inside the 25-turn/$15 cap; polling loops cost wall time, not
turns). Final message reported the inner cycle's outcome in full:
verifier PASS, 2/2 tasks complete, branch
`ralph/improve-20260721-094720` (tip `da40c69`) pushed to `origin`, inner
cost $5.24 / 52 turns / ~13 min; honest "no PR created" (local bare
remote, not a GitHub host) with backlog reconciliation correctly skipped
and findings left open.

**Auto-removal of the finished worktree confirmed:** after the run,
`git worktree list` in the sandbox showed **only** the `main` worktree —
the `--wait` branch's finished-worktree rule (remove only if the pid
sidecar is gone and the tree is clean) fired correctly. No leftover
`.pid`/`.log`/`.selected.json` for that tick's path. Sandbox `main`
itself untouched: single init commit, clean tree. Bare remote's refs:
exactly `refs/heads/ralph/improve-20260721-094720`.

**Verdict: PASS.** The launcher polled to completion, reported the inner
cycle's real outcome (not a fabricated summary), and auto-removed the
finished clean worktree per spec.

### Cleanup and captures

All sandboxes, bare remotes, and the manufactured fake worktree removed;
every spawned/manufactured process (`claude -p …` ticks, the `sleep 600`
fake) killed or allowed to exit and confirmed dead before moving on.
Final check: `pgrep -f "claude -p"` → empty, `pgrep -f "sleep 600"` →
empty. Captures kept (volatile `/tmp` copies; this appendix is the
durable record): `/tmp/p3-launch-fire.jsonl`,
`/tmp/p3-launch-fire2.jsonl`, `/tmp/p3-launch-busy-running.jsonl`,
`/tmp/p3-launch-busy-crashed.jsonl`, `/tmp/p3-launch-busy-crashed2.jsonl`,
`/tmp/p3-launch-busy-finished.jsonl`, `/tmp/p3-status-tick.jsonl`,
`/tmp/p3-launch-wait.jsonl`.
