# Build Mode Instructions

## Context

- **Plan**: `{{PLAN_FILE}}` (primary checklist - the "how")
- **Spec**: `{{SPEC_FILE}}` (requirements reference - the "what & why")
- **Progress**: `{{PROGRESS_FILE}}` (append-only iteration history)
- **Source**: `{{SOURCE_DIR}}`
- **CLAUDE.md**: Consult for project context and update with discovered patterns

## Iteration Model

You are running in a loop. Each iteration should:
1. Complete **ONE** checklist item from `{{PLAN_FILE}}`
2. Mark that item `[x]` and document in `{{PROGRESS_FILE}}`
3. Commit and push changes
4. The loop will call you again for the next task

**Do NOT try to complete all tasks in one iteration.** Work incrementally.

## Workflow (Per Iteration)

### 1. Understand Current State

- **Study** `{{PLAN_FILE}}` for checklist items (primary task list)
- **Study** `{{SPEC_FILE}}` for requirements context (the "why" behind tasks)
- **Study** `{{PROGRESS_FILE}}` for what was completed in previous iterations
- **Study** CLAUDE.md for project context and previous learnings
- Identify the **next** incomplete item (highest priority)

### 2. Implement ONE Task

**Critical: Don't assume functionality is missing.** Always search first—the codebase likely has what you need.

- Use parallel Sonnet subagents for search/read (up to 500)
- Use single Sonnet subagent for build/test
- Use Opus subagent ("Ultrathink") for complex reasoning, debugging, or architectural decisions
- Implement completely—no placeholders, stubs, or TODOs
- **Capture the why**: Document reasoning in code comments for non-obvious decisions

### 3. Verify (Backpressure)

Tests and types are your rejection mechanism. They push back on bad changes:

- Run tests: `npm run test`
- Run typecheck: `npm run typecheck`
- **Fix ALL failures before proceeding**—never leave broken builds
- If tests fail, the change is wrong. Fix it or reconsider approach.

### 4. Document

- Mark the completed item `[x]` in `{{PLAN_FILE}}`
- Append to `{{PROGRESS_FILE}}`:
  - Task completed and plan reference
  - Key decisions made and **why** (not just what)
  - Files changed
  - Any blockers or notes for next iteration
- Keep entries concise
- **Update CLAUDE.md** with discovered patterns, gotchas, or codebase conventions

### 5. Commit

- `git add -A`
- `git commit -m "feat/fix/docs: description"`
- `git push`

### 6. Check If All Done

- Review `{{PLAN_FILE}}` - are ALL items marked `[x]`?
- If NO: End this iteration. Loop will continue with next task.
- If YES: Proceed to Completion Protocol below.

## Rules

- **Single source of truth**—no migrations or adapters
- **Fix related failures**—if tests unrelated to your work fail, resolve them
- **Keep CLAUDE.md operational only**—status/progress notes belong in `{{PLAN_FILE}}`
- **Update CLAUDE.md with patterns**—add discovered conventions, gotchas, insights
- **Keep plans current**—update `{{PLAN_FILE}}` with learnings after each task
- **Reference specs for context**—consult `{{SPEC_FILE}}` for the "why" behind requirements
- **Capture the why**—tests and implementation reasoning matter
- **Resolve or document bugs**—even if unrelated to current work
- **Tag on clean builds**—create git tag when no build/test errors (start at 0.0.0, increment patch)
- **Don't assume not implemented**—search before adding new code

## Completion Protocol

**ONLY signal completion when ALL tasks in the plan are done.**

### Pre-Completion Checklist

Before outputting the completion marker, verify ALL of the following:

1. **All checklist items** in `{{PLAN_FILE}}` are marked `[x]` (not just one - ALL of them)
2. `npm run test` passes
3. `npm run typecheck` passes
4. All changes are committed and pushed
5. `{{PROGRESS_FILE}}` documents all completed tasks

### When to Signal Completion

- If there are remaining `[ ]` items in the checklist → **DO NOT** output the marker. End the iteration and let the loop continue.
- If ALL `[x]` items are checked AND tests pass → Output the marker below.

### Signaling Completion

**When ALL criteria above are met**, output exactly:

```
<ralph>COMPLETE</ralph>
```

This tells the ralph loop to exit with success status. The loop will otherwise continue calling you for the next task.
