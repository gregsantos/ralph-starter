# Build Mode Instructions

## Context

- **Spec**: `{{SPEC_FILE}}` (primary source of truth - contains tasks and requirements)
- **Plan**: `{{PLAN_FILE}}` (fallback checklist - used only if spec has no tasks array)
- **Progress**: `{{PROGRESS_FILE}}` (append-only iteration history)
- **Source**: `{{SOURCE_DIR}}`
- **CLAUDE.md**: Consult for project context and update with discovered patterns

## Task Source Priority

Build mode uses **tasks from the spec** as the primary source when available:

1. **If spec has `tasks` array**: Use tasks directly from spec. Ignore plan file.
2. **If spec has only `userStories`**: Use plan file checklist (legacy workflow).
3. **If no spec provided**: Use plan file checklist.

## Iteration Model

You are running in a loop. Each iteration should:

1. Complete **ONE** task from spec (or checklist item from plan if no tasks)
2. Update task status in spec and document in `{{PROGRESS_FILE}}`
3. Commit and push changes
4. The loop will call you again for the next task

**Do NOT try to complete all tasks in one iteration.** Work incrementally.

## Workflow (Per Iteration)

### 1. Understand Current State

**Read the spec first** to determine task source:

```
If spec has "tasks" array:
  → Use tasks from spec (recommended workflow)
  → Find next task using dependency rules below
Else if spec has "userStories" only:
  → Use plan file checklist (legacy workflow)
  → Find next [ ] item
Else:
  → Use plan file checklist
  → Find next [ ] item
```

**Finding the next task** (when using spec tasks):

1. Find tasks where `passes: false` (incomplete)
2. Filter to tasks where ALL `dependsOn` task IDs have `passes: true`
3. Select the first task by ID order (T-001 before T-002, etc.)
4. If no tasks are ready (all blocked or complete), check if all tasks pass

**Then study context:**

- **Study** `{{SPEC_FILE}}` for task details and requirements context
- **Study** `{{PROGRESS_FILE}}` for what was completed in previous iterations
- **Study** CLAUDE.md for project context and previous learnings
- If using plan file: study `{{PLAN_FILE}}` for checklist items

### 2. Implement ONE Task

**Before starting work** (when using spec tasks):
- Set the task's `status` to `"in_progress"` in the spec JSON
- This signals to future iterations that work has begun

**Critical: Don't assume functionality is missing.** Always search first—the codebase likely has what you need.

- Use parallel Sonnet subagents for search/read (up to 500)
- Use single Sonnet subagent for build/test
- Use Opus subagent ("Ultrathink") for complex reasoning, debugging, or architectural decisions
- Implement completely—no placeholders, stubs, or TODOs
- **Capture the why**: Document reasoning in code comments for non-obvious decisions

### 3. Verify (Backpressure)

Tests and types are your rejection mechanism. They push back on bad changes:

- Run tests: `pnpm test`
- Run typecheck: `pnpm typecheck`
- **Fix ALL failures before proceeding**—never leave broken builds
- If tests fail, the change is wrong. Fix it or reconsider approach.

### 4. Document

**When using spec tasks** (recommended):
- Update the task in spec JSON:
  - Set `"passes": true` (task complete)
  - Set `"status": "complete"`
  - Update `"notes"` with implementation summary
- Do NOT update plan file (spec is source of truth)

**When using plan file** (legacy/fallback):
- Mark the completed item `[x]` in `{{PLAN_FILE}}`
- If using JSON spec with userStories, also set `"passes": true` for completed stories

**Always:**
- Append to `{{PROGRESS_FILE}}`:
  - Task completed (include task ID like "T-008" when using spec tasks)
  - Key decisions made and **why** (not just what)
  - Files changed
  - Any blockers or notes for next iteration
- Keep entries concise
- **Update CLAUDE.md** with discovered patterns, gotchas, or codebase conventions
- **Update user-facing docs** if this task adds or changes:
  - CLI flags/options → update `--help` text and `docs/RALPH_LOOP_REF.md`
  - Workflow or behavior → update `README.md`
  - Configuration options → update `ralph.conf` comments and reference docs
  - Project structure → update directory trees in docs

### 5. Commit

- `git add -A`
- `git commit -m "feat/fix/docs: description"`
- `git push`

### 6. Check If All Done

**When using spec tasks:**
- Check if ALL tasks in spec have `passes: true`
- If NO: End this iteration. Loop will continue with next task.
- If YES: Proceed to Completion Protocol below.

**When using plan file:**
- Review `{{PLAN_FILE}}` - are ALL items marked `[x]`?
- If NO: End this iteration. Loop will continue with next task.
- If YES: Proceed to Completion Protocol below.

## Rules

- **Spec is source of truth**—when spec has tasks, update spec not plan file
- **Single source of truth**—no migrations or adapters
- **Fix related failures**—if tests unrelated to your work fail, resolve them
- **Keep CLAUDE.md operational only**—status/progress notes belong in spec or plan
- **Update CLAUDE.md with patterns**—add discovered conventions, gotchas, insights
- **Update task status in spec**—set `passes: true` and `status: "complete"` when done
- **Respect dependencies**—don't start a task until all `dependsOn` tasks have `passes: true`
- **Reference specs for context**—consult spec for the "why" behind requirements
- **Keep docs aligned**—update README.md, RALPH_LOOP_REF.md when adding user-facing features
- **Capture the why**—tests and implementation reasoning matter
- **Resolve or document bugs**—even if unrelated to current work
- **Tag on clean builds**—create git tag when no build/test errors (start at 0.0.0, increment patch)
- **Don't assume not implemented**—search before adding new code
- **Never signal completion early**—only output `<ralph>COMPLETE</ralph>` when ALL tasks are done

## Completion Protocol

**CRITICAL: The completion marker means ALL tasks are done—not just this iteration.**

⚠️ **NEVER output `<ralph>COMPLETE</ralph>` after completing a single task.**

- "End this iteration" = normal, loop continues with next task
- "Signal completion" = ALL checklist items are marked `[x]`

**If you just finished task 3 of 10 → DO NOT output the marker. End the iteration normally and let the loop continue.**

### Pre-Completion Checklist

Before outputting the completion marker, verify ALL of the following:

1. **All checklist items** in `{{PLAN_FILE}}` are marked `[x]` (not just one - ALL of them)
2. **All user stories** in `{{SPEC_FILE}}` have `"passes": true` (if using JSON spec)
3. **Documentation aligned**—new flags/features documented in `--help`, README.md, RALPH_LOOP_REF.md
4. `pnpm test` passes
5. `pnpm typecheck` passes
6. All changes are committed and pushed
7. `{{PROGRESS_FILE}}` documents all completed tasks

### When to Signal Completion

**DO NOT output the marker if:**

- You just finished one task (more remain in the checklist)
- Any `[ ]` items remain in `{{PLAN_FILE}}`
- Tests or typecheck fail

**ONLY output the marker if:**

- ALL checklist items are marked `[x]`
- Tests and typecheck pass
- All changes committed and pushed

### Signaling Completion

**When ALL criteria above are met**, output exactly:

```text
<ralph>COMPLETE</ralph>
```

This tells the ralph loop to exit with success status.

**If tasks remain:** Simply end your response after committing. Do NOT output the completion marker. The loop will automatically call you again for the next task.
