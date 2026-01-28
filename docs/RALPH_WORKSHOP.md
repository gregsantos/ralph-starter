# Ralph Loop: Workshop Guide

A comprehensive guide to autonomous AI-assisted development with Ralph Loop.

---

## Table of Contents

1. [What is Ralph Loop?](#what-is-ralph-loop)
2. [Core Concepts](#core-concepts)
3. [Minimum Setup](#minimum-setup)
4. [Configuration](#configuration)
5. [Planning Mode](#planning-mode)
6. [Build Mode](#build-mode)
7. [The Iteration Cycle](#the-iteration-cycle)
8. [Best Practices](#best-practices)
9. [Advanced Usage](#advanced-usage)
10. [Troubleshooting](#troubleshooting)

---

## What is Ralph Loop?

Ralph Loop is an **autonomous AI agent runner** that breaks software development into small, context-independent tasks and executes them iteratively. Each iteration spawns a fresh AI instance with no memory between runs—persistence comes only from files.

### Why Ralph?

- **Incremental progress**: Complex features become manageable when broken into single-iteration tasks
- **Quality gates**: Every iteration must pass tests and type checks before proceeding
- **Knowledge preservation**: Learnings persist in files, not AI memory
- **Hands-off execution**: Start a session, walk away, return to completed work

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                        RALPH LOOP                                │
│                                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │  Read    │ -> │ Execute  │ -> │ Verify   │ -> │  Commit  │  │
│  │  State   │    │  1 Task  │    │  Tests   │    │  & Push  │  │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘  │
│       │                                                │         │
│       └────────────────── Loop ───────────────────────┘         │
│                                                                  │
│  Exit when: All tasks complete OR max iterations reached         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Concepts

### 1. Fresh Instances, File-Based Memory

Each iteration starts with **zero memory** of previous runs. The AI reads its state from files:

| File | Purpose |
|------|---------|
| `specs/{feature}.md` | Feature specification (the "what & why") |
| `plans/IMPLEMENTATION_PLAN.md` | Checklist of tasks (`[ ]` pending, `[x]` done) |
| `progress.txt` | Append-only log of decisions and learnings |
| `CLAUDE.md` | Project context and discovered patterns |

### Specs vs Plans

| Directory | Contains | Purpose | Lifecycle |
|-----------|----------|---------|-----------|
| `specs/` | Feature specifications | Requirements, architecture, rationale | Semi-permanent |
| `plans/` | Implementation checklists | Step-by-step tasks | Disposable |

**When to use each:**
- **Inline prompts** (`-p "Fix X"`) — Quick fixes, no spec/plan needed
- **Single plan file** — Small features where a checklist is sufficient
- **Spec + Plan** — Major features needing stable requirements doc

### 2. Two Modes

| Mode | Purpose | When to Use |
|------|---------|-------------|
| **Plan** | Analyze codebase, create task checklist | Starting a new feature, investigating issues |
| **Build** | Execute tasks one at a time | Implementing the plan |

### 3. One Task Per Iteration

**Critical rule**: Complete exactly ONE checklist item per iteration.

- Too much? AI loses context, makes mistakes
- Too little? Wastes iterations on trivial progress

### 4. Completion Signal

When ALL tasks are done, the AI outputs:

```
<ralph>COMPLETE</ralph>
```

This tells the loop to exit successfully. Without this marker, the loop continues until max iterations.

### 5. Quality Gates (Backpressure)

Tests and type checks are your **rejection mechanism**. They push back on bad changes:

- Tests fail → Change is wrong. Fix or reconsider.
- Types fail → Interface contract broken. Align types.
- Never leave broken builds for the next iteration.

---

## Minimum Setup

### Prerequisites

```bash
# Required tools
claude --version    # Claude CLI installed and authenticated
jq --version        # JSON parsing
git --version       # Version control
```

### Required Files

```
project-root/
├── ralph.sh                      # The loop script
├── ralph.conf                    # Configuration (optional)
├── prompts/
│   ├── PROMPT_plan.md           # Planning mode instructions
│   └── PROMPT_build.md          # Build mode instructions
├── specs/
│   ├── INDEX.md                 # Feature catalog
│   └── {feature}.md             # Feature specifications (the "what & why")
├── plans/
│   └── IMPLEMENTATION_PLAN.md   # Task checklist (the "how")
├── progress.txt                  # Iteration history (auto-created)
└── CLAUDE.md                     # Project context
```

### Step 1: Create the Prompts Directory

```bash
mkdir -p prompts specs
```

### Step 2: Create PROMPT_plan.md

This prompt tells the AI how to analyze and plan:

```markdown
# Plan Mode Instructions

## Context

- **Specs**: `{{SPEC_FILE}}` (primary spec file)
- **Progress**: `{{PROGRESS_FILE}}` (if present)
- **Source**: `{{SOURCE_DIR}}`
- **CLAUDE.md**: Consult for project context

## Philosophy

**Plans are disposable.** If a plan becomes wrong or stale—regenerate it.

## Workflow (Per Iteration)

### 1. Research

**Don't assume functionality is missing.** Search first.

- Study the codebase—don't just read, understand intent
- Study progress file for context from previous iterations
- Confirm what exists vs what's actually missing

### 2. Gap Analysis

- What exists?
- What's incomplete? (TODOs, placeholders, skipped tests)
- What's inconsistent with codebase patterns?
- What's the precise delta?

### 3. Plan

- Create/update specs with prioritized checklist
- Each item must be atomic and verifiable
- Document reasoning for priorities

### 4. Document

- Append decisions to progress file
- Update CLAUDE.md with discovered patterns

## Completion Protocol

When planning is complete, output exactly:

\`\`\`
<ralph>COMPLETE</ralph>
\`\`\`
```

### Step 3: Create PROMPT_build.md

This prompt tells the AI how to implement:

```markdown
# Build Mode Instructions

## Context

- **Specs**: `{{SPEC_FILE}}` (primary checklist)
- **Progress**: `{{PROGRESS_FILE}}` (append-only history)
- **Source**: `{{SOURCE_DIR}}`
- **CLAUDE.md**: Consult and update with patterns

## Iteration Model

Each iteration:
1. Complete **ONE** checklist item
2. Mark it `[x]` and document in progress file
3. Commit and push
4. Loop calls you again for next task

**Do NOT complete all tasks in one iteration.** Work incrementally.

## Workflow (Per Iteration)

### 1. Understand State

- Study specs for checklist items (understand intent)
- Study progress for previous iteration context
- Identify next incomplete item

### 2. Implement ONE Task

**Don't assume missing.** Search first—the codebase likely has what you need.

- Implement completely—no placeholders or TODOs
- Capture the why in code comments for non-obvious decisions

### 3. Verify (Backpressure)

- Run tests: `npm run test`
- Run typecheck: `npm run typecheck`
- Fix ALL failures before proceeding

### 4. Document

- Mark item `[x]` in specs
- Append to progress: task, decisions, files changed
- Update CLAUDE.md with discovered patterns

### 5. Commit

- `git add -A && git commit -m "feat/fix: description" && git push`

## Completion Protocol

When ALL items are `[x]` and tests pass, output:

\`\`\`
<ralph>COMPLETE</ralph>
\`\`\`
```

### Step 4: Create CLAUDE.md

Project context the AI reads each iteration:

```markdown
# CLAUDE.md

## Project Overview

[Brief description of your project]

## Key Commands

\`\`\`bash
npm run test       # Run tests
npm run typecheck  # Type checking
npm run build      # Build project
\`\`\`

## Architecture

[Key files and their purposes]

## Codebase Patterns (Ralph-discovered)

_Update this section as you learn the codebase._

### Conventions
- (discovered patterns go here)

### Gotchas
- (pitfalls to avoid go here)
```

### Step 5: Verify Setup

```bash
./ralph.sh --help
```

You should see the help output with available options.

---

## Configuration

### Config File (Optional)

Create `ralph.conf` for project defaults:

```bash
# ralph.conf - Project defaults

# Spec file location
SPEC_FILE="./specs/IMPLEMENTATION_PLAN.md"

# Progress tracking
PROGRESS_FILE="progress.txt"

# Source directory for context
SOURCE_DIR="src/*"

# Default iterations
MAX_ITERATIONS=10

# Auto-push after each iteration
PUSH_ENABLED=true
```

### Template Variables

Prompts support these placeholders (automatically substituted):

| Variable | Default | Description |
|----------|---------|-------------|
| `{{SPEC_FILE}}` | `./specs/IMPLEMENTATION_PLAN.md` | Feature specification (the "what & why") |
| `{{PLAN_FILE}}` | `./plans/IMPLEMENTATION_PLAN.md` | Implementation checklist (the "how") |
| `{{PROGRESS_FILE}}` | `progress.txt` | Iteration log |
| `{{SOURCE_DIR}}` | `src/*` | Source code location |

### CLI Overrides

Any config can be overridden via command line:

```bash
./ralph.sh -s ./specs/feature-x.md    # Spec file (plan auto-derived)
./ralph.sh -l ./plans/custom_PLAN.md  # Override derived plan
./ralph.sh --progress ./logs/prog.txt # Different progress file
./ralph.sh --source lib/*             # Different source dir
./ralph.sh --dry-run                  # Preview config without running
```

### Plan Derivation

When you specify a spec file without a plan file, the plan is automatically derived:

| Spec File | Derived Plan File |
|-----------|-------------------|
| `./specs/feature.md` | `./plans/feature_PLAN.md` |
| `./specs/auth-system.md` | `./plans/auth-system_PLAN.md` |

This keeps spec and plan files paired by naming convention.

---

## Planning Mode

Planning mode analyzes your codebase and creates an implementation checklist.

### When to Use Plan Mode

- Starting a new feature
- Investigating a bug
- Refactoring existing code
- Understanding unfamiliar codebase

### Running Plan Mode

```bash
# Basic: Plan until complete (up to 10 iterations)
./ralph.sh plan

# Limit iterations
./ralph.sh plan 3

# Use specific model
./ralph.sh plan --model opus
```

### What Plan Mode Does

1. **Research**: Reads codebase, understands existing patterns
2. **Gap Analysis**: Compares requirements vs current implementation
3. **Creates Checklist**: Writes prioritized tasks to specs file
4. **Documents Findings**: Appends learnings to progress file

### Example Output: specs/IMPLEMENTATION_PLAN.md

```markdown
# Implementation Plan: User Authentication

## Overview

Add JWT-based authentication to the API.

## Checklist

- [ ] Add `jsonwebtoken` dependency
- [ ] Create `src/lib/auth.ts` with token utilities
- [ ] Add auth middleware to `src/middleware/`
- [ ] Protect `/api/users/*` routes
- [ ] Add login endpoint `POST /api/auth/login`
- [ ] Add tests for auth utilities
- [ ] Add integration tests for protected routes

## Dependencies

- Items 3-5 depend on item 2
- Items 6-7 can run in parallel after item 5

## Notes

- Existing `src/lib/crypto.ts` has hashing utilities—reuse
- Follow middleware pattern in `src/middleware/logging.ts`
```

### Planning Philosophy

**Plans are disposable.** If your plan becomes wrong or stale:

- Don't patch it with amendments
- Regenerate from scratch with new understanding
- A fresh plan with current knowledge beats a patched old plan

---

## Build Mode

Build mode executes the plan one task at a time.

### When to Use Build Mode

- After planning is complete
- Task checklist exists and is clear
- Ready for autonomous implementation

### Running Build Mode

```bash
# Basic: Build until complete (up to 10 iterations)
./ralph.sh build

# Equivalent (build is default)
./ralph.sh

# Limit iterations
./ralph.sh build 5

# Different model for faster/cheaper iterations
./ralph.sh build --model sonnet
```

### What Build Mode Does (Each Iteration)

1. **Read State**: Check specs for next `[ ]` item
2. **Search First**: Verify functionality doesn't already exist
3. **Implement**: Complete exactly ONE task
4. **Verify**: Run tests and type checks
5. **Document**: Mark `[x]`, update progress
6. **Commit**: Push changes to remote
7. **Check**: All done? Signal completion. Otherwise, loop continues.

### The One-Task Rule

Each iteration completes **exactly one** checklist item:

```markdown
Before iteration 3:
- [x] Add dependency
- [x] Create auth utilities
- [ ] Add middleware        <- This iteration works on this
- [ ] Protect routes
- [ ] Add login endpoint

After iteration 3:
- [x] Add dependency
- [x] Create auth utilities
- [x] Add middleware        <- Now complete
- [ ] Protect routes        <- Next iteration
- [ ] Add login endpoint
```

### Build Mode Rules

| Rule | Why |
|------|-----|
| **Don't assume missing** | Search codebase before adding new code |
| **Fix all failures** | Never leave broken builds for next iteration |
| **Capture the why** | Document reasoning, not just what |
| **No placeholders** | Implement completely or don't start |

---

## The Iteration Cycle

### Visual Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ ITERATION START                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. READ STATE                                                   │
│     ├── specs/IMPLEMENTATION_PLAN.md (what's left?)             │
│     ├── progress.txt (what happened before?)                    │
│     └── CLAUDE.md (project context)                             │
│                                                                  │
│  2. EXECUTE                                                      │
│     ├── Search codebase (don't assume missing)                  │
│     ├── Implement ONE task                                       │
│     └── Write tests if needed                                    │
│                                                                  │
│  3. VERIFY (Backpressure)                                       │
│     ├── npm run test                                             │
│     ├── npm run typecheck                                        │
│     └── Fix failures before continuing                           │
│                                                                  │
│  4. DOCUMENT                                                     │
│     ├── Mark [x] in specs                                        │
│     ├── Append to progress.txt                                   │
│     └── Update CLAUDE.md with patterns                          │
│                                                                  │
│  5. COMMIT                                                       │
│     └── git add -A && git commit && git push                    │
│                                                                  │
│  6. CHECK COMPLETION                                             │
│     ├── All [x]? → Output <ralph>COMPLETE</ralph> → EXIT        │
│     └── More [ ]? → END ITERATION → LOOP CONTINUES              │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│ ITERATION END                                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Sample progress.txt Entry

```
## Iteration 3 - 2024-01-15 14:32

### Task
- [x] Add auth middleware (specs item 3)

### Decisions
- Placed in `src/middleware/auth.ts` following existing pattern
- Used existing `crypto.ts` for token verification
- Chose to throw 401 vs redirect—API should return JSON errors

### Files Changed
- src/middleware/auth.ts (new)
- src/middleware/index.ts (export)
- tests/middleware/auth.test.ts (new)

### Notes for Next Iteration
- Ready to protect routes (item 4)
- Consider rate limiting for auth endpoints
```

---

## Best Practices

### Writing Good Checklist Items

**Good items are:**
- Atomic (one thing)
- Verifiable (clear done/not-done)
- Right-sized (completable in one iteration)

| Bad | Good |
|-----|------|
| "Implement authentication" | "Create token generation utility" |
| "Fix bugs" | "Fix null pointer in UserCard component" |
| "Add tests" | "Add unit tests for auth.ts" |
| "Refactor code" | "Extract validation logic to src/lib/validate.ts" |

### The "Don't Assume Missing" Rule

Before implementing anything, search first:

```
BAD:  "Need to add a date formatter"
      → Creates new dateFormatter.ts

GOOD: "Need to add a date formatter"
      → Searches codebase
      → Finds existing src/lib/dates.ts
      → Uses existing utility
```

### Capturing Knowledge

The AI discovers things each iteration. Capture them:

| Discovery | Where to Put It |
|-----------|-----------------|
| "This test is flaky" | progress.txt (immediate note) |
| "Always use `api.fetch` not raw fetch" | CLAUDE.md (permanent pattern) |
| "Item 5 depends on item 3" | specs file (plan update) |

### When to Regenerate Plans

Regenerate (don't patch) when:
- Current approach isn't working after 3+ iterations
- Discovered codebase is structured differently than assumed
- Better approach became apparent
- Plan has too many amendments

### Subagent Strategy

The AI can spawn subagents for parallel work:

| Task | Subagent Strategy |
|------|-------------------|
| Reading/searching files | Many parallel (up to 500) |
| Building/testing | Single sequential |
| Complex reasoning | Opus for "Ultrathink" moments |

---

## Advanced Usage

### Model Selection

| Model | Speed | Cost | Best For |
|-------|-------|------|----------|
| `opus` | Slowest | Highest | Complex reasoning, architecture |
| `sonnet` | Medium | Medium | Standard implementation |
| `haiku` | Fastest | Lowest | Simple fixes, documentation |

```bash
# Override default model
./ralph.sh build --model sonnet
./ralph.sh plan --model opus
./ralph.sh -p "Fix typo" --model haiku
```

### Iteration Limits

```bash
# Default: 10 iterations
./ralph.sh build

# Custom limit
./ralph.sh build 25
./ralph.sh -n 50

# Unlimited (use with caution!)
./ralph.sh --unlimited
```

### Push Control

```bash
# Disable auto-push (for local experimentation)
./ralph.sh build --no-push

# Explicitly enable (default)
./ralph.sh build --push
```

### Custom Prompts

```bash
# Use custom prompt file
./ralph.sh -f ./prompts/security-audit.md

# Inline prompt (creates temp file)
./ralph.sh -p "Fix all TypeScript errors"
```

### Different Spec Files

```bash
# Use different spec file
./ralph.sh -s ./specs/feature-auth.md
./ralph.sh -s ./specs/bugfix-123.md
```

### Branch Archiving

When you switch branches, Ralph automatically archives:
- Previous branch's spec file
- Previous branch's progress.txt
- Saved to `archive/YYYY-MM-DD-branch-name/`

This preserves history when context-switching between features.

### Logging

Full session logs saved to `/tmp/ralph_<mode>_<timestamp>.log`:

```bash
# View recent logs
ls -la /tmp/ralph_*.log

# Tail running session
tail -f /tmp/ralph_build_*.log

# Search for errors
grep -i error /tmp/ralph_*.log
```

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success—all tasks complete |
| `1` | Max iterations reached—work may remain |
| `130` | Interrupted (Ctrl+C) |

### Background Execution

```bash
# Run in background
nohup ./ralph.sh build 50 > ralph.log 2>&1 &

# Check progress
tail -f ralph.log

# Or use screen/tmux
screen -S ralph
./ralph.sh build 100
# Ctrl+A, D to detach
# screen -r ralph to reattach
```

---

## Troubleshooting

### "Error: Prompt file not found"

Ensure prompt files exist:
```bash
ls prompts/PROMPT_plan.md prompts/PROMPT_build.md
```

### Loop runs but no progress

Check that:
1. Spec file has `[ ]` items (unchecked)
2. AI can understand the task (not too vague)
3. Tests aren't failing immediately

### Tests keep failing

The AI should fix failures, but if stuck:
1. Check progress.txt for what it tried
2. Run tests manually to understand failure
3. Consider simplifying the task

### AI keeps "searching" but not implementing

Common when tasks are too vague. Improve checklist:
```markdown
# Bad
- [ ] Add authentication

# Good
- [ ] Create JWT token utility in src/lib/auth.ts
- [ ] Add login endpoint POST /api/auth/login
```

### Session seems stuck

Check the log file:
```bash
tail -100 /tmp/ralph_build_*.log | less
```

Look for:
- Rate limiting messages
- Error responses
- Repeated tool calls

### Completion signal not triggering

Verify:
1. ALL checklist items are `[x]`
2. Tests pass (`npm run test`)
3. Type checks pass (`npm run typecheck`)
4. The prompt includes the completion protocol

---

## Quick Reference

### Common Commands

```bash
# Help
./ralph.sh --help

# Plan mode
./ralph.sh plan           # Plan until complete
./ralph.sh plan 5         # Max 5 iterations

# Build mode
./ralph.sh                # Build (default)
./ralph.sh build 10       # Max 10 iterations

# Model selection
./ralph.sh --model sonnet
./ralph.sh -m haiku

# Custom prompts
./ralph.sh -f custom.md
./ralph.sh -p "Fix the bug"

# Options
./ralph.sh --no-push      # Don't auto-push
./ralph.sh --unlimited    # No iteration limit
./ralph.sh --dry-run      # Preview config without running
./ralph.sh -s specs/x.md  # Spec file (plan auto-derived)
./ralph.sh -s specs/x.md -l plans/custom.md  # Override derived plan
```

### Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | Loop script |
| `ralph.conf` | Optional defaults |
| `prompts/PROMPT_plan.md` | Planning instructions |
| `prompts/PROMPT_build.md` | Build instructions |
| `specs/INDEX.md` | Feature catalog |
| `specs/{feature}.md` | Feature specification (the "what & why") |
| `plans/IMPLEMENTATION_PLAN.md` | Task checklist (the "how") |
| `progress.txt` | Iteration history |
| `CLAUDE.md` | Project context |

### The Golden Rules

1. **One task per iteration**
2. **Don't assume missing—search first**
3. **Tests are your rejection mechanism**
4. **Plans are disposable—regenerate if wrong**
5. **Capture the why, not just the what**

---

## Next Steps

1. **Set up minimum files** in your project
2. **Run plan mode** to create your first checklist
3. **Run build mode** and watch it work
4. **Iterate** on your prompts as you learn what works

Happy automating!
