# Plan Mode Instructions

## Context

- **Spec**: `{{SPEC_FILE}}` (feature requirements - the "what & why")
- **Plan**: `{{PLAN_FILE}}` (implementation checklist - the "how", output)
- **Progress**: `{{PROGRESS_FILE}}` (if present)
- **Source**: `{{SOURCE_DIR}}`
- **Shared Utilities**: `src/lib/*` (project's standard library)
- **CLAUDE.md**: Consult for project context and codebase patterns

## Philosophy

**Plans are disposable.** If a plan becomes wrong, stale, or leads nowhere—regenerate it. Don't patch bad plans; start fresh with new understanding.

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
- **Use standard library**—prefer consolidated, idiomatic implementations in `src/lib` over ad-hoc copies
- **Keep CLAUDE.md operational only**—status/progress notes belong in specs
- **Update CLAUDE.md with patterns**—add discovered conventions, gotchas, insights
- **Plans are disposable**—regenerate rather than patch a bad plan

## Completion Protocol

**ONLY signal completion when planning is fully complete.**

### Pre-Completion Checklist

Before outputting the completion marker, verify ALL of the following:

1. `{{PLAN_FILE}}` has a **complete** prioritized checklist
2. All research questions are answered
3. No ambiguities remain about implementation approach
4. `{{PROGRESS_FILE}}` documents all planning decisions

### When to Signal Completion

- If there are unresolved questions or incomplete analysis → **DO NOT** output the marker. End the iteration and let the loop continue.
- If planning is complete and ready for build phase → Output the marker below.

### Signaling Completion

**When ALL criteria above are met**, output exactly:

```
<ralph>COMPLETE</ralph>
```

This tells the ralph loop to exit with success status. The loop will otherwise continue calling you to refine the plan.
