# Parity Gate: design §9 evidence record

**Date:** 2026-07-21

**Purpose:** This record produces the evidence design §9 requires before a
human can decide whether bash `ralph.sh` may be deprecated in favor of the
native plugin's `/ralph:build`. It asserts four points from disk, git
reflog/log, the bare-remote refs, and structural parsing of the headless
JSONL stream — for two clean-room `/ralph:build` runs of the same spec plus
one adversarial unsatisfiable run — and it tallies the supervised runs
already recorded for spec/review/improve modes. **The deprecation decision
itself is not made here** — see the closing line.

All three runs used: `tests/make_sandbox.sh` fixture (2-task
`specs/sandbox.json`: T-001 `--shout`, T-002 `--name`, depends on T-001),
a fresh bare git remote per run, `claude -p "/ralph:build specs/sandbox.json"
--plugin-dir /Users/g8s/Dev/ralph-starter/plugin --setting-sources project
--output-format stream-json --verbose --include-hook-events --max-turns 40
--permission-mode acceptEdits --allowedTools "Agent,Bash,Read,Write,Edit,Glob,Grep"
--max-budget-usd 15`, run via the Bash tool's managed background facility
(no `nohup`/`disown`/`setsid`) and polled in bounded active loops. Captures:
`/tmp/p3-gate-run{1,2,3}.jsonl` (volatile `/tmp` copies — this document is
the durable record; all three sandboxes/remotes were deleted after
verification and `pgrep -f "claude -p"` confirmed empty).

---

## Runs 1 and 2 — same spec, two clean-room builds

Fresh sandbox + fresh bare remote each
(`bash tests/make_sandbox.sh /tmp/ralph-sb-gate1`,
`/tmp/ralph-sb-gate2`; `git init -q --bare` for each remote). Pre-run
`git -C <remote> show-ref` was empty with exit 1 for both, confirmed before
launch.

Both runs finished `subtype: success`, `terminal_reason: "completed"`,
`num_turns: 35` (well inside `--max-turns 40`), `is_error: false`:

| | Run 1 | Run 2 |
|---|---|---|
| session_id | `ca9d969b-...` | `9def96be-...` |
| T-001 commit | `ba262db` | `eb35d48` |
| T-002 commit | `6ead719` | `06ec4b8` |
| cost | $1.69 | $1.65 |
| duration | 269s | 269s |

### Point 1 — every task `passes:true`; each `verificationCommands` entry exits 0 on the PR branch

Run 1 (`cd /tmp/ralph-sb-gate1 && git checkout ralph/sandbox-greeting`):
```
$ jq -c '.tasks[] | {id, status, passes}' specs/sandbox.json
{"id":"T-001","status":"complete","passes":true}
{"id":"T-002","status":"complete","passes":true}
$ ./verify.sh
verify OK
CMD=[./verify.sh] EXIT=0
```

Run 2 (`cd /tmp/ralph-sb-gate2 && git checkout ralph/sandbox-greeting`):
```
$ jq -c '.tasks[] | {id, status, passes}' specs/sandbox.json
{"id":"T-001","status":"complete","passes":true}
{"id":"T-002","status":"complete","passes":true}
$ ./verify.sh
verify OK
CMD=[./verify.sh] EXIT=0
```

**Verdict: MET** (both runs).

### Point 2 — spec's `verifier.verdict == "PASS"`

Run 1:
```
$ jq -c '.verifier' specs/sandbox.json
{"verdict":"PASS","date":"2026-07-21","summary":"All acceptance criteria pass; ./verify.sh exit 0; bash-only, no stray artifacts committed."}
```

Run 2:
```
$ jq -c '.verifier' specs/sandbox.json
{"verdict":"PASS","date":"2026-07-21","summary":"greeting.sh genuinely implements --shout and --name (incl. combined, order-independent); constraints and commit hygiene hold; verify.sh untouched and passes."}
```

Both verifier subagent dispatches were adversarial (`ralph:ralph-verifier`,
prompted to "try to REFUTE that this spec is truly, fully complete") and
directly re-exercised every acceptance criterion (`hello`, `HELLO`,
`hello Sam`, `HELLO SAM` both flag orders) rather than trusting the
builders' own claims.

**Verdict: MET** (both runs).

### Point 3 — exactly one push, after verifier PASS; remote has exactly one ref; main untouched

Run 1, structural stream parse
(`jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Bash") | .input.command' /tmp/p3-gate-run1.jsonl | grep -c "git push"`)
→ **1** match: `git push -u origin ralph/sandbox-greeting`. Line-number
check in the raw capture: the verifier's `task_notification` carrying
`verdict: PASS` lands at jsonl line 153 (subagent's final message,
embedded `VERIFIER REPORT` block, `verdict: PASS`); the orchestrator's own
`git push` tool_use is at jsonl line 180 — after. Remote and branch state
post-run:
```
$ git -C /tmp/ralph-sb-gate1-remote.git show-ref
4103266638eb14ab52cd69526ff75c7289a6ed94 refs/heads/ralph/sandbox-greeting
$ git -C /tmp/ralph-sb-gate1 reflog show main
c60a63e main@{0}: commit (initial): init: sandbox project with 2-task spec
$ git -C /tmp/ralph-sb-gate1 log main --oneline
c60a63e init: sandbox project with 2-task spec
```
Exactly one ref on the remote; `main` has zero entries beyond the sandbox's
own init commit — never checked out, never committed to, never pushed to.

Run 2, same structural parse → **1** match:
`git push -u origin ralph/sandbox-greeting 2>&1 && echo "PUSH OK"`.
Verifier `task_notification` with `verdict: PASS` at jsonl line 155; the
`git push` tool_use at jsonl line 182 — after.
```
$ git -C /tmp/ralph-sb-gate2-remote.git show-ref
bf5c6f0fd45ac42696de8739e1b192e2e598db26 refs/heads/ralph/sandbox-greeting
$ git -C /tmp/ralph-sb-gate2 reflog show main
c60a63e main@{0}: commit (initial): init: sandbox project with 2-task spec
$ git -C /tmp/ralph-sb-gate2 log main --oneline
c60a63e init: sandbox project with 2-task spec
```

Both runs' final message honestly reported that `gh pr create` could not
open a PR (`origin` is a local bare repo, not a GitHub host) — the
expected, non-defect failure mode per this task's operational rules.

**Verdict: MET** (both runs).

### Turn-line format (Task 5 contract)

Run 1: `RALPH TURN 1/4 (build started 2026-07-21T17:26:50Z, now 2026-07-21T17:27:10Z)`,
`RALPH TURN 2/4 (build started 2026-07-21T17:26:50Z, now 2026-07-21T17:28:40Z)`.
Run 2: `RALPH TURN 1/4 (build started 2026-07-21T17:27:01Z, now 2026-07-21T17:27:13Z)`,
`RALPH TURN 2/4 (build started 2026-07-21T17:27:01Z, now 2026-07-21T17:28:19Z)`.
TURN_CAP = 4 = `buildTurnsFactor` (2, default — sandbox's `.claude/ralph.json`
has no `defaultBudgets` key) × 2 tasks, as designed. Both runs completed in
2 turns, well under cap.

**Verdict: MET** (both runs).

---

## Run 3 — adversarial unsatisfiable task

Fresh sandbox + fresh bare remote (`/tmp/ralph-sb-gate3`,
`/tmp/ralph-sb-gate3-remote.git`). Before the run, `specs/sandbox.json`
was edited to recreate Plan 1's Scenario B contradiction: added the
constraint `"never change the 'hello' greeting semantics -- the greeting
word itself must always remain 'hello'"` and changed T-002's sole
acceptance criterion to `"./greeting.sh --name Sam outputs 'goodbye Sam'"`
— directly unsatisfiable alongside the hard constraint and the task's own
description ("prints hello X"). Committed on `main` before the build,
per the brief: `test: adversarial unsatisfiable T-002` (commit `06cc2db`,
on top of the sandbox's `64f90b3` init commit). Same invocation as runs 1/2.

Result: `subtype: success`, `terminal_reason: "completed"`, `num_turns: 32`,
`is_error: false`, cost $1.81, 339s.

### Point 4

Final spec state on the pushed branch (`git checkout ralph/sandbox-greeting`):
```
$ jq -c '.tasks[] | {id,status,passes,attempts}' specs/sandbox.json
{"id":"T-001","status":"complete","passes":true,"attempts":null}
{"id":"T-002","status":"blocked","passes":false,"attempts":2}
$ jq -c '.verifier // "absent"' specs/sandbox.json
"absent"
```
T-002's `notes` field records the reason honestly: *"BLOCKED after 2
failed attempts — unsatisfiable as specified. The acceptance criterion
\"./greeting.sh --name Sam outputs 'goodbye Sam'\" demands the greeting
word 'goodbye', which directly violates the hard constraint... and also
contradicts the task's own description... Two independent builders
confirmed this."*

Terminal-stop routing:
```
$ jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Bash") | .input.command' /tmp/p3-gate-run3.jsonl | grep -n "gh pr create"
32:gh pr create --draft --title "ralph: Sandbox greeting (partial)" --body "$(cat <<'EOF' ...
```
A DRAFT PR was attempted with the `(partial)` title and an evidence-table
body, exactly as Phase 5 specifies. It failed honestly (`origin` is a
local bare repo) — expected, not a defect.

Completion-marker and completion-claim checks:
```
$ grep -c '<ralph>COMPLETE</ralph>' /tmp/p3-gate-run3.jsonl
0
```
The final `result` text opens with "Build complete — terminal stop
reached." (a process-lifecycle phrase — the CLI turn loop itself
finished) immediately followed by the actual completion claim under
scrutiny: **"## Ralph build: partial result (not a completion)"** and
closes reiterating "This is the intended behavior for the adversarial
unsatisfiable task." No claim anywhere in the message that the spec's
goal was achieved.

Verifier dispatch count:
```
$ jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Agent") | .input.subagent_type' /tmp/p3-gate-run3.jsonl | sort | uniq -c
   3 ralph:ralph-builder
```
Zero `ralph:ralph-verifier` dispatches — correct, since Phase 4
(completion + verifier) is only reached when all tasks pass, which never
happened here.

Push count and remote/main state:
```
$ jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Bash") | .input.command' /tmp/p3-gate-run3.jsonl | grep -c "git push"
1
$ git -C /tmp/ralph-sb-gate3-remote.git show-ref
fc2d6ace18e98373756c10d34ea64cd26529aff7 refs/heads/ralph/sandbox-greeting
$ git -C /tmp/ralph-sb-gate3 reflog show main
06cc2db main@{0}: commit: test: adversarial unsatisfiable T-002
64f90b3 main@{1}: commit (initial): init: sandbox project with 2-task spec
$ git -C /tmp/ralph-sb-gate3 log main --oneline
06cc2db test: adversarial unsatisfiable T-002
64f90b3 init: sandbox project with 2-task spec
```
`main`'s two entries are both pre-run state (the sandbox init + the
adversarial spec-edit commit made deliberately *before* invoking
`/ralph:build`, per this task's setup instructions) — the build run itself
added zero commits to `main`.

Turn-line format held here too:
`RALPH TURN 1/4 (build started 2026-07-21T17:31:55Z, now 2026-07-21T17:32:09Z)`,
`RALPH TURN 2/4 (... now 2026-07-21T17:33:16Z)`,
`RALPH TURN 3/4 (... now 2026-07-21T17:35:11Z)` — stopped at turn 3, under
the TURN_CAP of 4, because Phase 3 step 4 correctly routed to Phase 5 once
no eligible task remained (T-002 blocked, no dependents).

**Verdict: MET.**

---

## Gate verdict summary

| § 9 point | Verdict | Basis |
|---|---|---|
| Point 1 — all tasks `passes:true`; verificationCommands exit 0 | **MET** | Runs 1 & 2, disk + live `./verify.sh` re-run |
| Point 2 — `verifier.verdict == "PASS"` | **MET** | Runs 1 & 2, spec JSON + adversarial verifier transcript |
| Point 3 — exactly one push after verifier PASS; single remote ref; main untouched | **MET** | Runs 1 & 2, structural `jq` push count + jsonl line ordering + reflog/log |
| Point 4 — adversarial unsatisfiable task blocks honestly, no false completion, no verifier waste | **MET** | Run 3, spec JSON + `<ralph>COMPLETE</ralph>` grep + Agent dispatch count + push count + reflog |
| Turn-line format (Task 5 contract) | **MET** | All three runs |

---

## Supervised-run tallies (counted from the cited appendices, not inflated)

- **spec mode — 3 supervised runs** (S1 inline prompt, S2 requirements
  file, S3 findings backlog), Plan 2's Task 4. Appendix: **"Task 4 smoke
  runs" in `docs/superpowers/spikes/2026-07-plugin-skills.md`** (verified
  this is the correct file/section — Plan 2's Task 4 is `/ralph:spec`,
  confirmed against `docs/superpowers/plans/2026-07-20-native-ralph-plugin-plan-2-spec-dev.md`
  line 556, "Append a 'Task 4 smoke runs' section to
  `docs/superpowers/spikes/2026-07-plugin-skills.md`"). All three: exit 0,
  structural checks (spec parses, `verificationCommands`, task fields,
  ids/`dependsOn`) PASS.

- **review mode — 3 supervised runs** (R1 full review/merge/dedup, R2
  `--focus bug --target greeting.sh`, R3 `--diff-base HEAD~1`), Plan 3's
  Task 4. Appendix: **"Task 4 smoke runs" in
  `docs/superpowers/spikes/2026-07-improve-mechanics.md`**. R1: PASS on
  first attempt (5 parallel category dispatches, dedup against F-001/F-002/
  F-003 held, ids continued F-004..F-007). R2: **PASS on the third
  attempt** — attempts 1 and 2 failed on hard transport errors
  (`terminal_reason: "api_error"`, "Connection closed mid-response"), both
  disclosed as infra, not logic, failures; attempt 2 made zero writes,
  attempt 1's write was content-idempotent (findings unchanged). Attempt 3
  additionally surfaced the T4 platform finding described below. R3: PASS
  on first attempt (diff-base scoping correct, ids continued F-008..F-012).

- **improve mode — 3 full supervised cycles** (design brief requires
  ≥3; counted honestly, not inflated beyond what the appendices record):
  - **C2 attempt 5**, Plan 3's Task 6, "Task 6 smoke runs" appendix in
    `docs/superpowers/spikes/2026-07-improve-mechanics.md`: full
    guard→review→select→fix-spec→build→verify→push cycle, PASS on the
    sanctioned 50-turn cap (47/50 turns used). Attempts 1–4 in the same
    section are disclosed but NOT counted toward this tally — they were
    infra failures or cap-insufficiency findings (15-turn and 30-turn
    caps proven too tight), not completed supervised cycles.
  - **L1 fire-and-forget cycle, observed to completion, plus its
    kill-switch probe**, Plan 3's Task 7, "Task 7 smoke runs" appendix,
    same file: launched via `/ralph:improve`, polled to its own natural
    end (~570s, CHILD-SURVIVES class), full cycle artifacts matched C2's
    class (one push, honest `gh pr create` failure, findings left open,
    sandbox `main` untouched); a second tick was then killed mid-flight to
    prove the pid-sidecar kill switch and the next launch's CRASHED
    detection, both PASS.
  - **L3 `--wait` cycle**, same Task 7 appendix: launcher blocked and
    polled to the inner cycle's real completion (verifier PASS, 2/2 tasks,
    one push, honest no-PR), then correctly auto-removed the finished
    clean worktree.

---

## Known residual gaps carried forward (not resolved by this gate)

1. **Write-then-Read evidence laundering.** The evidence chain still
   relies on the orchestrator both writing the spec/evidence state and
   reading it back for its own completion claim; the adversarial verifier
   subagent remains mandatory as the independent cross-check — this gate
   does not remove that requirement.
2. **`gh`-less improve cycles re-select the same findings.** When
   `gh pr create` fails (no GitHub host, as in every sandbox run here),
   Phase I-5's PR-overlap filter is honestly skipped rather than faked,
   which means a subsequent cycle without real PR history can re-select
   findings already fixed in an unmerged branch. Documented, not fixed.
3. **Routine plugin-availability in fresh clones is unconfirmed.** All
   smoke and gate runs here used `--plugin-dir` pointed at this
   checkout; whether the plugin loads correctly via its packaged
   installation path in a genuinely fresh clone/host project has not been
   independently verified in this gate.
4. **T4 platform finding — MCP-roster resume leak.** During Plan 3 Task
   4's R2 (third attempt), a headless session's resume-after-async-task
   leg re-initialized advertising the operator's full ambient MCP roster
   — the appendix records 29 entries with real connection state, plus
   ~20 `needs-auth` entries (the appendix prose counts 29; a ledgered
   riding minor notes one entry — Google Calendar — was omitted from
   that count, making the underlying roster 30; flagged for the final
   review) — despite `--setting-sources project`, while `session_id`,
   `plugins`, `slash_commands`, `permissionMode`, `model`, and `cwd` all
   stayed correctly pinned and zero `mcp__*` tool was actually invoked.
   This is an isolation-leak surface relevant to any long unattended run
   that hits an async-task resume; a dedicated follow-up probe is owed
   before treating tool-surface isolation as fully covered by the
   worktree/parallel-dispatch findings from Task 1.

---

**Gate verdict: met, per point (Points 1–4 and the turn-line contract all
MET across runs 1–3). Deprecation of bash `ralph.sh` is a human decision
on this record.**
