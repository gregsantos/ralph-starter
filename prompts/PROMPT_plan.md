# Plan Mode Instructions

## Context

- **Spec**: `{{SPEC_FILE}}` (feature requirements - the "what & why")
- **Plan**: `{{PLAN_FILE}}` (implementation checklist - the "how", output)
- **Progress**: `{{PROGRESS_FILE}}` (if present)
- **Source**: `{{SOURCE_DIR}}`
- **CLAUDE.md**: Consult for project context and codebase patterns

## Spec Format Detection

**First, check if the spec has a `tasks` array:**

```
If spec has "tasks" array:
  → Generate derived Markdown plan (see "Derived Plan from Tasks" below)
  → Plan is read-only reference for humans
  → Build mode works directly from spec, not this plan
Else (userStories only or no spec):
  → Use traditional planning workflow (see "Traditional Planning" below)
  → Build mode will use this plan as source of truth
```

## Philosophy

**Plans are disposable.** If a plan becomes wrong, stale, or leads nowhere—regenerate it. Don't patch bad plans; start fresh with new understanding.

---

## Derived Plan from Tasks

**Use this workflow when the spec has a `tasks` array.**

The spec is the source of truth. This plan is a derived human-readable view for reference only.

### Generated Plan Format

Create `{{PLAN_FILE}}` with this structure:

```markdown
# Implementation Plan: {project name}

> ⚠️ **This is a derived view.** Edit the spec (`{{SPEC_FILE}}`), not this file.
> Build mode works directly from the spec's tasks array.

## Overview

{Brief description from spec}

## Tasks

### Phase: {phase name}

- [ ] **T-001**: {task title}
  - {acceptance criterion 1}
  - {acceptance criterion 2}
  - Dependencies: {dependsOn tasks or "None"}

- [x] **T-002**: {task title} ✓
  - Dependencies: T-001
  - Notes: {task notes if any}

{Continue for all tasks, grouped by phase}

## Progress Summary

- **Completed**: X of Y tasks
- **In Progress**: {task IDs}
- **Blocked**: {task IDs and why}
- **Ready**: {next tasks with satisfied dependencies}

## Dependency Graph

{Optional: visual representation of task dependencies}
```

### Workflow for Derived Plans

1. **Read** the spec's `tasks` array
2. **Generate** the Markdown plan following the format above
3. **Mark tasks** based on their `passes` field: `[ ]` for false, `[x]` for true
4. **Group by phase** if phases are defined in the spec
5. **Show dependencies** clearly for each task
6. **Write** to `{{PLAN_FILE}}`
7. **Document** in `{{PROGRESS_FILE}}`

### Completion for Derived Plans

This is typically a **single-iteration** operation:

1. Read spec
2. Generate derived plan
3. Write plan file
4. Document in progress
5. Output `<ralph>COMPLETE</ralph>`

**Note:** Build mode does NOT update this plan. It updates the spec directly.

---

## Traditional Planning

**Use this workflow when the spec has NO `tasks` array (legacy userStories format or no spec).**

## Iteration Model

You are running in a loop. Each iteration should make **incremental progress** on planning:

1. Research and analyze a portion of the codebase
2. Update the plan with findings
3. Document in `{{PROGRESS_FILE}}`
4. The loop will call you again to continue if needed

## Workflow (Per Iteration)

### 1. Research

**Critical: Don't assume functionality is missing.** Always search first—the codebase likely has what you need.

- **Study** codebase with parallel Sonnet subagents (up to 250)—don't just read, understand
- **Study** `{{PROGRESS_FILE}}` for context from previous iterations
- **Study** `{{SPEC_FILE}}` if present (it may be outdated or incorrect)
- **Study** CLAUDE.md for project context and existing patterns
- Search codebase to confirm what exists vs what's actually missing

### 2. Gap Analysis

Perform rigorous comparison of specs vs actual implementation:

- **What exists?** Search thoroughly before assuming absence
- **What's incomplete?** Look for: TODOs, minimal implementations, placeholders, skipped/flaky tests
- **What's inconsistent?** Patterns that don't match the rest of the codebase
- **What's the delta?** Precise list of what needs to change
- Use Opus subagent ("Ultrathink") for complex architectural decisions
- Prioritize by importance and dependencies

### 3. Plan

- **Read** `{{SPEC_FILE}}` for requirements and architecture (if present)
- **Create/update** `{{PLAN_FILE}}` with prioritized checklist
- Document reasoning for priorities
- Note any ambiguities or blockers
- Each item should be atomic and verifiable
- **Include documentation tasks** for user-facing changes (CLI flags, workflow changes, config options)

### 4. Document

- Append to `{{PROGRESS_FILE}}`:
  - Planning decisions made and reasoning
  - Specs or plans created/updated
  - Any blockers or questions
- Keep entries concise
- **Update CLAUDE.md** with discovered patterns, conventions, or gotchas

### 5. Check Plan Health

**Regenerate the plan if:**

- Current approach isn't working (off-track after multiple iterations)
- Discovered fundamentally different codebase structure
- Accumulated too many amendments/patches
- Better approach became apparent

**Proceed if:**

- Plan is complete, unambiguous, and actionable
- All research questions answered
- Each checklist item is atomic and verifiable

If incomplete: End iteration. Loop will continue.
If complete: Proceed to Completion Protocol below.

## Rules

- **Plan only**—do NOT implement anything
- **Search first**—confirm functionality is missing before planning to add it
- **Don't assume not implemented**—the codebase is more complete than you think
- **Keep CLAUDE.md operational only**—status/progress notes belong in specs
- **Update CLAUDE.md with patterns**—add discovered conventions, gotchas, insights
- **Plans are disposable**—regenerate rather than patch a bad plan
- **Plan documentation updates**—include doc tasks for user-facing features (README.md, RALPH_LOOP_REF.md, --help)
- **Never signal completion early**—only output `<ralph>COMPLETE</ralph>` when plan is fully ready for build

## Completion Protocol

**CRITICAL: The completion marker means planning is FULLY complete—not just this iteration.**

⚠️ **NEVER output `<ralph>COMPLETE</ralph>` after a single research iteration.**

- "End this iteration" = normal, loop continues with more research
- "Signal completion" = plan is COMPLETE and ready for build phase

**If you just finished researching one component and more areas remain → DO NOT output the marker. End the iteration normally and let the loop continue.**

### Pre-Completion Checklist

Before outputting the completion marker, verify ALL of the following:

1. `{{PLAN_FILE}}` has a **complete** prioritized checklist covering ALL requirements
2. All research questions are answered (no open questions remain)
3. No ambiguities remain about implementation approach
4. `{{PROGRESS_FILE}}` documents all planning decisions
5. Plan is ready for build phase (another agent can execute it without questions)

### When to Signal Completion

**DO NOT output the marker if:**

- You just finished one research iteration (more areas to explore)
- Open questions remain about implementation approach
- Plan checklist is incomplete or has gaps
- More codebase exploration is needed

**ONLY output the marker if:**

- Plan is complete, unambiguous, and actionable
- All research is done
- Ready to hand off to build phase

### Signaling Completion

**When ALL criteria above are met**, output exactly:

```text
<ralph>COMPLETE</ralph>
```

This tells the ralph loop to exit with success status.

**If planning is NOT complete:** Simply end your response after documenting progress. Do NOT output the completion marker. The loop will automatically call you again to continue planning.
