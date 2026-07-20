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

**Final `result` event** — a `.ralph-goal` check and a JSON-shaped
`{"ok": true}` fragment appear in the assistant's own result text below.

**Correction (post-review, 2026-07-20):** this section originally
attributed that text to the plugin's Stop hook "correctly" allowing the
stop. That attribution was wrong and is corrected here. Step 4's
invocation above used `--setting-sources project`, and the goal-arming
spike's MAJOR FINDING
(`docs/superpowers/spikes/2026-07-goal-arming.md`, ~lines 784–844)
establishes that under that exact flag combination the plugin's Stop
hook is completely inert — it produces zero hook events and no "Stop
hook feedback" injection, ever. A fresh, minimal probe re-confirms this
directly today rather than relying on inference alone. Run in a
throwaway dir (`/tmp/ralph-probe-p2`, never against ralph-starter),
same `--plugin-dir`/`--setting-sources project` combination as Step 4,
a `.ralph-goal` file with a plainly, unambiguously unmet condition
(`SPIKE0_DONE.txt` never created), `--include-hook-events` on:

```bash
claude -p "say hi and stop" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 3 --permission-mode acceptEdits \
  --max-budget-usd 2 > /tmp/p2-hook-probe.jsonl 2>&1
```

Verbatim inspection results:

```
$ grep -c 'hook_started\|hook_response' /tmp/p2-hook-probe.jsonl
0
$ grep -c "Stop hook feedback" /tmp/p2-hook-probe.jsonl
0
```

Final `result` event, verbatim:

```json
{"type":"result","subtype":"success","is_error":false,"api_error_status":null,"duration_ms":4562,"duration_api_ms":5552,"ttft_ms":2580,"ttft_stream_ms":2483,"time_to_request_ms":42,"num_turns":1,"result":"Hi!","stop_reason":"end_turn","session_id":"17d38a21-47cf-4001-a1dc-30e800bd143e","total_cost_usd":0.0688595,"permission_denials":[],"terminal_reason":"completed"}
```

The session ended immediately, on the very first turn, with the
`.ralph-goal` condition plainly unmet and nothing blocking the stop —
zero hook events, zero injected feedback. **Fact 2 is re-confirmed on
2026-07-20 by this probe.** Whatever produced the `.ralph-goal`-shaped
text quoted below in this Task 1 run's (now-deleted) raw capture, it
cannot have been the plugin's Stop hook — under this exact
configuration that hook cannot fire, let alone "correctly allow"
anything. It is preserved here only as a verbatim record of what that
run's final assistant-visible text contained, not as evidence of hook
activity; the deleted raw capture can no longer be inspected to
determine what actually produced it (most plausibly ordinary assistant
output following the now-removed probe command's own instructions).
**Both of this task's verdicts (plugin-root-read, skill-tool
registration) are unaffected** — they rest on the Skill-tool and
Read-tool evidence quoted above, not on this hook byproduct:

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

---

## Task 4 smoke runs

**Date:** 2026-07-20
**Task:** Task 4 of Plan 2 (see `.superpowers/sdd/task-4-brief.md`) —
`plugin/commands/spec.md` plus three supervised headless smoke runs
(S1 inline prompt, S2 requirements file, S3 findings backlog).

All three runs passed every checklist item on the first attempt. No
wording adjustments to `spec.md` were needed.

### Invocations

Sandbox created once via `bash tests/make_sandbox.sh /tmp/ralph-sb-spec`;
each smoke test ran in the same sandbox, with the previous test's
generated spec removed first to avoid slug collisions (all three specs
have distinct slugs anyway, but the brief's collision-avoidance step was
followed regardless).

```bash
# S1 — inline prompt
claude -p "/ralph:spec Add a --version flag to greeting.sh that prints 'greeting 1.0.0' and exits 0; unknown flags must exit 2 with usage on stderr; default hello output unchanged" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 15 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 5 > /tmp/p2-spec-p.jsonl 2>&1
# exit 0

rm specs/greeting-version-flag.json   # S1 cleanup before S2

# S2 — requirements file
claude -p "/ralph:spec -f requirements.md" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 15 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 5 > /tmp/p2-spec-f.jsonl 2>&1
# exit 0

rm specs/greeting-flags.json   # S2 cleanup before S3

# S3 — findings backlog
claude -p "/ralph:spec --from-findings" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 15 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 5 > /tmp/p2-spec-findings.jsonl 2>&1
# exit 0
```

### S1 — inline prompt

Generated `specs/greeting-version-flag.json` ("Greeting version flag",
2 tasks: T-001 add `--version`, T-002 reject unknown flags with
`dependsOn: ["T-001"]`).

| Checklist item | Evidence | Result |
|---|---|---|
| A new `specs/*.json` (not `sandbox.json`) exists; `jq .` parses it | `specs/greeting-version-flag.json` created; `jq .` parsed cleanly | PASS |
| `context.verificationCommands == ["./verify.sh"]` (proves 3a sourcing) | `jq -r '.context.verificationCommands'` → `["./verify.sh"]` | PASS |
| Every task: `status=="pending"`, `passes==false`, `attempts==0`; ids sequential; `dependsOn` valid | `jq` dump: T-001 `{pending,false,0,[]}`, T-002 `{pending,false,0,["T-001"]}` | PASS |
| Transcript: Read tool_use of the plugin skill path + Bash tool_use of `ralph-evidence.sh` with evidence block in tool_result | `{"name":"Read","input":{"file_path":"/Users/g8s/Dev/ralph-starter/plugin/skills/writing-ralph-specs/SKILL.md"}}` and a later `Bash` call running `/Users/g8s/Dev/ralph-starter/plugin/scripts/ralph-evidence.sh specs/greeting-version-flag.json`; tool_result contained `=== RALPH EVIDENCE ===` / `tasks: 2 total \| 0 passed \| 0 in_progress \| 2 pending \| 0 blocked` / `verifier: PENDING` / `=== END RALPH EVIDENCE ===`, `EVIDENCE_EXIT=0` | PASS |
| No commit, no branch, spec untracked | `git log --oneline` → 1 line (`ad66b05 init: ...`); `git branch` → `* main` only; `git status --porcelain` → `?? specs/greeting-version-flag.json` | PASS |

Bonus (not in the S1 checklist but checked anyway, per spec.md step 6):
`git check-ignore specs/greeting-version-flag.json` exited 1 (not
ignored) — same Bash call as the evidence run, output
`IGNORE_EXIT=1`.

### S2 — requirements file

Generated `specs/greeting-flags.json` ("Greeting flags", 2 tasks
mirroring T-001/T-002 of S1, worded slightly differently).

| Checklist item | Evidence | Result |
|---|---|---|
| Tasks derive from the file's three requirements (`--version` task, unknown-flag task, "hello unchanged") | T-001 "Add --version flag to greeting.sh" cites the exact string `greeting 1.0.0` and includes the criterion `Running: ./greeting.sh  still prints exactly 'hello'`; T-002 "Reject unknown flags with usage on stderr and exit 2" includes criteria for exit code 2, stderr-not-stdout, and re-confirms both `--version` and the no-arg default keep working | PASS — substance matches all three `requirements.md` bullets |
| Same structural checks as S1 (new spec parses, verificationCommands, task fields, ids/dependsOn) | `jq .` parsed; `verificationCommands == ["./verify.sh"]`; both tasks `{pending,false,0}`, T-002 `dependsOn:["T-001"]` | PASS |
| Transcript shows `requirements.md` was Read | `{"name":"Read","input":{"file_path":"/private/tmp/ralph-sb-spec/requirements.md"}}` (second tool_use, immediately after the skill Read) | PASS |
| No commit, no branch, spec untracked | `git log --oneline` still 1 line; `git branch` → `* main`; `git status --porcelain` → `?? specs/greeting-flags.json` | PASS |

Evidence tool_result for S2: `EXIT=0`, `IGNORE_EXIT=1`, same
`=== RALPH EVIDENCE ===` block shape as S1 with the S2 task titles.

### S3 — findings backlog

Generated `specs/sandbox-greeting-flag-error-handling.json`
("Sandbox greeting flag error handling", 2 tasks).

| Checklist item | Evidence | Result |
|---|---|---|
| Tasks cite F-001 and/or F-002 in descriptions | T-001 description opens "Fixes F-001."; T-002 description opens "Fixes F-002." | PASS |
| No task derives from F-003 (info skipped) | Only 2 tasks total, both about unknown-flag handling; nothing about "greeting logic is simple and readable" (F-003's subject) | PASS |
| Each task's criteria include the fix behavior and a "verification commands still pass"-style criterion | T-001's last criterion: `` `./verify.sh` passes and prints `verify OK` ``; T-002's last criterion: identical wording | PASS |
| Severity ordering (F-001's fix before/above F-002's) | T-001 (fixes F-001, medium) precedes T-002 (fixes F-002, low) in the `tasks` array, and T-002 `dependsOn: ["T-001"]` | PASS |
| Same structural checks as S1 | `jq .` parsed; `verificationCommands == ["./verify.sh"]`; both tasks `{pending,false,0}` with sequential ids and valid `dependsOn` | PASS |
| Transcript shows `review-output/findings.json` was Read | First tool_use of the run: `{"name":"Read","input":{"file_path":"/private/tmp/ralph-sb-spec/review-output/findings.json"}}` | PASS |
| No commit, no branch, spec untracked | `git log --oneline` still 1 line; `git branch` → `* main`; `git status --porcelain` → `?? specs/sandbox-greeting-flag-error-handling.json` | PASS |

Evidence tool_result for S3: `=== EVIDENCE EXIT: 0 ===`,
`=== CHECK-IGNORE EXIT: 1 ===`, evidence block showing
`tasks: 2 total | 0 passed | 0 in_progress | 2 pending | 0 blocked`.

### Prompt adjustments

None. `spec.md` as written in Step 1 of the Task 4 brief produced a
passing result on the first run of every smoke test — no re-runs were
needed.

### Cleanup

- `cd / && rm -rf /tmp/ralph-sb-spec` (sandbox) run after S3, per the
  brief.
- `/tmp/p2-spec-p.jsonl`, `/tmp/p2-spec-f.jsonl`,
  `/tmp/p2-spec-findings.jsonl` (raw stream captures) removed after
  writing up this section.
- `git status` in the ralph-starter repo before committing: only
  `plugin/commands/spec.md` (new) and this spike doc's edit are staged;
  no sandbox or capture files leaked into the working tree.

## Task 5 smoke runs

**Date:** 2026-07-20
**Task:** Task 5 of Plan 2 (see `.superpowers/sdd/task-5-brief.md`) —
`plugin/commands/build.md` Phase 1 preflight amendment (step 2 gains a
single exception for the target spec file; new step 3a commits that spec
on the work branch) plus two supervised headless smoke runs (negative
control, then happy path).

Negative control passed on the first attempt. Happy path required one
rerun — not because of the amendment's wording, but because the CLI's own
`--max-turns 25` budget (as specified in the brief) was exhausted one step
before the finish line (builder dispatch + verifier dispatch + evidence
runs + rebase left no turns for the push/PR step). This is a different
mechanism from the spec's internal `RALPH TURN_CAP` (which gates Phase 3
dispatch, not Phase 4 completion) — the brief's "rerun once" guidance was
applied by analogy since the effect (an incomplete run hitting a cap) is
the same. No wording change to `build.md` was needed or made.

### Invocations

Sandbox created via `bash tests/make_sandbox.sh /tmp/ralph-sb-bcommit`,
plus a throwaway bare remote (`git init --bare`) added as `origin`, per
the brief.

```bash
# Negative control — dirty verify.sh + untracked spec must abort preflight
claude -p "/ralph:build specs/version-flag.json" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 6 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 3 > /tmp/p2-build-dirty-abort.jsonl 2>&1
# exit 0 (claude CLI exit; orchestrator aborted per Phase 1 step 2)

# Happy path — run 1 (hit --max-turns 25 one step before push+PR)
claude -p "/ralph:build specs/version-flag.json" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 25 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 10 > /tmp/p2-build-uncommitted-spec.jsonl 2>&1
# exit 1, terminal_reason "max_turns" — task built + verified PASS + clean
# rebase all landed on disk, cut off checking gh auth just before push

# Happy path — run 2 (same invocation, same sandbox, resumed on ralph/version-flag)
claude -p "/ralph:build specs/version-flag.json" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 25 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 10 > /tmp/p2-build-uncommitted-spec-run2.jsonl 2>&1
# exit 0 — completion path: removed stale .ralph-goal, detected
# task+verifier already recorded, rebased (no-op), pushed once, gh pr
# create failed honestly against the local bare remote
```

### Negative control — other dirt still aborts

Sandbox state before the run: `verify.sh` modified (`# unrelated dirt`
appended) and `specs/version-flag.json` untracked (`git status
--porcelain` showed both).

| Checklist item | Evidence | Result |
|---|---|---|
| Run ABORTS in preflight (dirty `verify.sh` alongside the untracked spec) | Final result text: "Aborting — preflight failed (Phase 1, step 2)... `verify.sh` is modified... This is unrelated to the spec and is not the allowed exception." | PASS |
| No `ralph/*` branch created | `git branch` after run → `* main` only | PASS |
| No builder dispatched | tool_use names in `/tmp/p2-build-dirty-abort.jsonl`: only `Bash` (x2) and `Read` (x1); no `Task`/`Agent` tool_use; the one `"name":"ralph"` match is the plugin-metadata line in the `system init` event, not a tool call | PASS |
| No commit added | `git log --oneline` after run → still 1 line (`init: sandbox project with 2-task spec`) | PASS |

`git checkout verify.sh` afterward restored the sandbox to clean-except-untracked-spec for the happy-path run, per the brief.

### Happy path — uncommitted spec is committed on the branch

**Run 1** (`--max-turns 25`, `/tmp/p2-build-uncommitted-spec.jsonl`, 166
lines): reached `"type":"result","subtype":"error_max_turns"` at
`num_turns:26`, `stop_reason:"tool_use"`, mid-way through checking `git
remote -v` / `gh auth status` ahead of the push step. Disk state at that
point (captured before the rerun):

```
$ git log main..ralph/version-flag --oneline --name-only
719794a chore: record verifier PASS          specs/version-flag.json
b1c2443 chore(T-001): complete                specs/version-flag.json
2ac6230 feat(T-001): Add --version flag        greeting.sh
318cbc3 chore(T-001): start                    specs/version-flag.json
f5f9388 chore: add spec for Version flag       specs/version-flag.json
```

Confirmed via `python3`-parsed structural tool_use scan of run 1's
stream: exactly one `Task`/`Agent` dispatch with
`subagent_type:"ralph:ralph-builder"` for T-001, exactly one dispatch with
`subagent_type:"ralph:ralph-verifier"`, and zero `git push` commands
anywhere in the transcript (the run was cut off before reaching step 6).

**Run 2** (same invocation, `/tmp/p2-build-uncommitted-spec-run2.jsonl`):
exit 0. The orchestrator detected the resumed state ("entering this
session, the spec was already fully built... I ran the completion path
rather than rebuilding"), did not redispatch the builder or verifier, and
completed Phase 4: rebase (no-op, `main` already an ancestor), push, `gh
pr create` attempt.

| Checklist item | Evidence | Result |
|---|---|---|
| Preflight proceeds; branch `ralph/version-flag` created | `git branch -a` → `* ralph/version-flag`, `main` (run 1's transcript shows the branch-creation step; both runs operated on it) | PASS |
| FIRST commit on the branch is `chore: add spec for Version flag` touching only `specs/version-flag.json` | `git log main..ralph/version-flag --oneline --name-only` (above) — last-listed (oldest) commit is `f5f9388 chore: add spec for Version flag`, sole file `specs/version-flag.json` | PASS |
| Build completes: builder dispatch for T-001 | Run 1 tool_use: `{"description":"Build T-001 version flag","subagent_type":"ralph:ralph-builder",...}` | PASS |
| Verifier PASS written to the spec | Run 1 tool_use: `{"description":"Verify version-flag build","subagent_type":"ralph:ralph-verifier",...}`; disk state `specs/version-flag.json` → `"verifier":{"verdict":"PASS","date":"2026-07-20",...}` | PASS |
| Exactly one `git push` (grep tool_use Bash commands for "git push") | Structural scan across both run files combined: zero matches in run 1, exactly one in run 2 — `'git push -u origin ralph/version-flag 2>&1; echo "PUSH_EXIT=$?"'`, tool_result `PUSH_EXIT=0` | PASS |
| Bare-remote refs (`git -C "$REMOTE" show-ref`) | `719794a06d4bb19ddbb0f1df7029eff0be3c47d6 refs/heads/ralph/version-flag` — matches the local branch tip exactly | PASS |
| Honest report of the `gh pr create` failure against the local bare remote | tool_result for the `gh pr create` call: `"none of the git remotes configured for this repository point to a known GitHub host... GH_EXIT=1"`; final report: "PR not opened — environment limitation, not a conflict... In a normal GitHub-backed repo this would have produced a PR titled 'ralph: Version flag'..." | PASS |
| `main` unchanged | `git log main --oneline` → still 1 line (`init: sandbox project with 2-task spec`) | PASS |
| `.ralph-goal` absent afterward | `ls .ralph-goal` → "No such file or directory"; final report: "deleted in Phase 1 and never re-armed... absent" | PASS |

### Prompt adjustments

None. The two `build.md` edits (Phase 1 step 2 exception, new step 3a)
worked as written on the first attempt for both smoke tests. The happy
path's rerun was caused by the CLI's `--max-turns 25` budget being tight
for a full builder+verifier+push+PR cycle in one session, not by any
defect or ambiguity in the amendment's wording — no `build.md` change was
made in response.

### Cleanup

- `cd / && rm -rf /tmp/ralph-sb-bcommit "$REMOTE"` run after both happy-path
  runs completed, per the brief.
- `/tmp/p2-build-dirty-abort.jsonl`, `/tmp/p2-build-uncommitted-spec.jsonl`,
  and `/tmp/p2-build-uncommitted-spec-run2.jsonl` (run 1 and run 2 of the
  happy path) were **kept** — per this task's instructions — in case the
  final whole-branch review consults them; they are gitignored `/tmp`
  paths, not part of the repo.
- `git status` in the ralph-starter repo before committing: only
  `plugin/commands/build.md` and this spike doc's edit are staged; no
  sandbox or capture files leaked into the working tree.

## Task 6 smoke runs

**Date:** 2026-07-20
**Task:** Task 6 of Plan 2 (see `.superpowers/sdd/task-6-brief.md`) —
`plugin/commands/dev.md`, the full spec-to-build pipeline command that
composes `/ralph:spec` and `/ralph:build` by Reading them from
`${CLAUDE_PLUGIN_ROOT}` (the mechanism this repeats was spike-proven at
the top of this document and re-proven live by Tasks 4/5), plus two
supervised headless smoke runs (D1 full pipeline happy path, D2
`--review` pause after Phase A).

Both runs passed every checklist item on the first attempt. No wording
adjustments to `dev.md` were needed, and no rerun of either test was
required — D1 finished at `num_turns: 36` against its `--max-turns 40`
budget, with `stop_reason: "end_turn"` and `terminal_reason: "completed"`
(not a cap-out), so the "known from Task 5" outer-`--max-turns` risk this
task's instructions flagged did not materialize here.

### Invocations

```bash
# D1 — full pipeline, happy path
bash tests/make_sandbox.sh /tmp/ralph-sb-dev && cd /tmp/ralph-sb-dev
REMOTE=$(mktemp -d) && git init -q --bare "$REMOTE" && git remote add origin "$REMOTE"
claude -p "/ralph:dev Add a --version flag to greeting.sh that prints 'greeting 1.0.0' and exits 0; extend verify.sh to check it; the default hello output must not change" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 40 --permission-mode acceptEdits \
  --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 20 > /tmp/p2-dev-happy.jsonl 2>&1
# exit 0, num_turns 36, terminal_reason "completed"

# D2 — --review pauses after Phase A
bash tests/make_sandbox.sh /tmp/ralph-sb-devrev && cd /tmp/ralph-sb-devrev
claude -p "/ralph:dev --review Add a --version flag to greeting.sh that prints 'greeting 1.0.0' and exits 0" \
  --plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project \
  --output-format stream-json --verbose --include-hook-events \
  --max-turns 15 --permission-mode acceptEdits \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep" \
  --max-budget-usd 5 > /tmp/p2-dev-review.jsonl 2>&1
# exit 0, num_turns 9, terminal_reason "completed"
```

### D1 — full pipeline, happy path

Produced `specs/greeting-version-flag.json` ("Greeting version flag",
1 task file with 2 tasks: T-001 add `--version`, T-002 extend `verify.sh`),
built it, verified it, rebased, and pushed to the sandbox's local bare
remote.

| Checklist item | Evidence | Result |
|---|---|---|
| Transcript shows Read tool_use of BOTH `spec.md` and `build.md` (and the skill via spec.md's procedure) | Structural scan of `tool_use` blocks: `Read` of `/Users/g8s/Dev/ralph-starter/plugin/commands/spec.md`, then `/Users/g8s/Dev/ralph-starter/plugin/commands/build.md`, then `/Users/g8s/Dev/ralph-starter/plugin/skills/writing-ralph-specs/SKILL.md`, in that order | PASS |
| New spec validated by the evidence script (exit 0 tool_result); `verificationCommands == ["./verify.sh"]` | tool_result for the first `ralph-evidence.sh specs/greeting-version-flag.json` call: `=== RALPH EVIDENCE ===` / `tasks: 2 total \| 0 passed \| 0 in_progress \| 2 pending \| 0 blocked` / `EVIDENCE_EXIT=0`; disk state `jq '.context.verificationCommands' specs/greeting-version-flag.json` → `["./verify.sh"]` | PASS |
| Branch `ralph/<slug>` created; FIRST commit `chore: add spec for <project>` | `git log main..ralph/greeting-version-flag --oneline --reverse` (oldest first): `c245d65 chore: add spec for Greeting version flag`, then the T-001/T-002 start/complete commits, then `de3a7d2 chore: record verifier PASS` | PASS |
| >=1 `ralph:ralph-builder` dispatch; `ralph:ralph-verifier` dispatched; verifier PASS written into the spec | Structural scan of `Task`/`Agent` tool_use: two `subagent_type:"ralph:ralph-builder"` dispatches (T-001, T-002) and one `subagent_type:"ralph:ralph-verifier"` dispatch; disk state `jq .verifier specs/greeting-version-flag.json` → `{"verdict":"PASS","date":"2026-07-20","summary":"--version flag prints 'greeting 1.0.0'/exit 0, default 'hello' intact, verify.sh assertions are real and pass."}` | PASS |
| Exactly one `git push`; `gh pr create` attempted and its local-remote failure reported honestly; `main` unchanged; `.ralph-goal` deleted (absent on disk) | Structural scan of Bash commands: exactly one command containing `git push` (`git push -u origin ralph/greeting-version-flag`); one `gh pr create --base main --head ralph/greeting-version-flag ...` whose tool_result read `none of the git remotes configured for this repository point to a known GitHub host`; final report: "One deviation to flag ... could not be opened ... environment constraint, not a build failure ... Never auto-merged"; `git log main --oneline` → still 1 line (init commit); `ls .ralph-goal` → No such file or directory | PASS |
| No attribution lines in the attempted PR title/body or any commit message | `git log main..ralph/greeting-version-flag --format="%B"` grepped for `generated with\|co-authored-by\|claude code` → no matches; the constructed `gh pr create` command's `PR_BODY` heredoc (captured in the transcript) contains only a Summary/Evidence/Tasks/Verifier structure, no attribution trailer | PASS |

Bonus structural checks: remote branch tip matches local
(`git ls-remote origin` → `de3a7d2...refs/heads/ralph/greeting-version-flag`,
identical to `git log ralph/greeting-version-flag -1 --format=%H`);
`git status --porcelain` clean at the end.

### D2 — `--review` pauses after Phase A

| Checklist item | Evidence | Result |
|---|---|---|
| Session ends after Phase A (`terminal_reason: "completed"`), final message presents the spec and asks for approval | Result event: `"terminal_reason":"completed"`, `"stop_reason":"end_turn"`; result text ends "## Gate (`--review`) ... Do you approve this spec to proceed to Phase B (build)? Reply **approve** to continue... this session is non-interactive. If no approval arrives, the pipeline correctly ends here" | PASS |
| Spec file exists, validated, untracked | `git status --porcelain` → `?? specs/greeting-version-flag.json`; tool_result for `ralph-evidence.sh` → `EVIDENCE_EXIT` path present, `tasks: 1 total \| 0 passed \| 0 in_progress \| 1 pending \| 0 blocked`, `check-ignore EXIT=1` | PASS |
| NO branch beyond main | `git branch -a` → `* main` only | PASS |
| NO Agent dispatches | Structural scan: zero `tool_use` blocks with `name` in `{Task, Agent}` | PASS |
| NO `.ralph-goal` ever created | `ls -la .ralph-goal` → No such file or directory; no Bash command in the transcript references `.ralph-goal` | PASS |
| Zero commits beyond init | `git log --oneline` → 1 line (`881110c init: sandbox project with 2-task spec`) | PASS |

Note: the transcript shows `Read` of both `spec.md` and `build.md` early
in the session (turns 8 and 10, before any writing), the same as D1 —
the orchestrator reads both command files up front to understand the
whole pipeline per `dev.md`'s framing ("you compose them by reading the
command files below"), but only *executes* `spec.md`'s procedure in this
run. Reading `build.md` without dispatching anything, branching, or
committing does not violate any D2 checklist item, and Phase B's
substance (branch creation, builder/verifier dispatch, commits) never
ran.

Correction to a plan-level overreach (not to the smoke evidence above):
`/tmp/p2-dev-review.jsonl` (D2's capture) shows zero hook events, which
per Task 11's MAJOR FINDING is exactly what an allow-path prompt-type
Stop hook looks like when it is completely inert under
`--setting-sources project` — an allow-path hook leaves no observable
trace either way, so "the Stop hook allowed the stop" is unobservable
from this capture rather than confirmed, regardless of which of those
two states actually held during D2.

### Skipped: interactive `--review` approval check

Per this task's controller decision, the brief's optional check —
running `/ralph:dev --review …` in a supervised **interactive** session
and approving when asked — was skipped. Headless D2 already proves the
load-bearing mechanics (the gate stops the session cleanly after Phase A,
with nothing beyond it executed); the interactive approve-and-continue
path exercises no new platform fact and was left for a human-supervised
session outside this task's scope.

### Prompt adjustments

None. `dev.md` as written in Step 1 of the Task 6 brief produced a
passing result on the first run of both smoke tests.

### Cleanup

- `cd / && rm -rf /tmp/ralph-sb-dev /tmp/ralph-sb-devrev "$REMOTE"` run
  after D2, per the brief.
- `/tmp/p2-dev-happy.jsonl` and `/tmp/p2-dev-review.jsonl` (raw stream
  captures) were **kept** — per this task's instructions — in case the
  final whole-branch review consults them; they are gitignored `/tmp`
  paths, not part of the repo.
- `git status` in the ralph-starter repo before committing: only
  `plugin/commands/dev.md` and this spike doc's edit are staged; no
  sandbox or capture files leaked into the working tree.
