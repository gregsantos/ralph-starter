# Ralph Starter Template

A minimal starter kit for autonomous AI-assisted development with **Ralph Loop**.

Ralph Loop breaks complex software development into small, context-independent tasks and executes them iteratively. Each iteration spawns a fresh AI instance—persistence comes only from files.

## Why Ralph?

- **Incremental progress**: Complex features become manageable when broken into single-iteration tasks
- **Quality gates**: Every iteration must pass tests and type checks before proceeding
- **Knowledge preservation**: Learnings persist in files, not AI memory
- **Hands-off execution**: Start a session, walk away, return to completed work

## Quick Start

### Prerequisites

```bash
# Required tools
claude --version    # Claude CLI installed and authenticated
jq --version        # JSON parsing
git --version       # Version control
```

### Your First Run

```bash
# Clone or copy this template
git clone https://github.com/gregsantos/ralph-starter my-project
cd my-project

# Verify setup
./ralph.sh --help

# Preview config without running
./ralph.sh --dry-run

# Run planning mode (analyzes codebase, creates task checklist)
./ralph.sh plan

# Run build mode (executes tasks one at a time)
./ralph.sh build
```

## Project Structure

```
ralph-starter/
├── ralph.sh                      # The loop script
├── ralph.conf                    # Configuration defaults
├── CLAUDE.md                     # Project context for Claude
├── prompts/
│   ├── PROMPT_plan.md            # Planning mode instructions
│   └── PROMPT_build.md           # Build mode instructions
├── specs/
│   ├── INDEX.md                  # Feature catalog
│   └── {feature}.md              # Feature specs (the "what & why")
├── plans/
│   └── IMPLEMENTATION_PLAN.md    # Task checklist (the "how")
├── progress.txt                  # Iteration history (auto-created)
├── archive/                      # Auto-archived branch state
└── docs/
    ├── RALPH_LOOP_REF.md         # Full CLI reference
    └── RALPH_WORKSHOP.md         # Comprehensive workshop guide
```

## Core Concepts

### Two Modes

| Mode      | Purpose                                 | Command            |
| --------- | --------------------------------------- | ------------------ |
| **Plan**  | Analyze codebase, create task checklist | `./ralph.sh plan`  |
| **Build** | Execute tasks one at a time             | `./ralph.sh build` |

### Specs vs Plans

| Directory | Contains                  | Purpose                                                  | Lifecycle      |
| --------- | ------------------------- | -------------------------------------------------------- | -------------- |
| `specs/`  | Feature specifications    | Requirements, architecture, rationale (the "what & why") | Semi-permanent |
| `plans/`  | Implementation checklists | Step-by-step tasks (the "how")                           | Disposable     |

### One Task Per Iteration

**Critical rule**: Complete exactly ONE checklist item per iteration. The loop handles orchestration.

### Completion Signal

When ALL tasks are done, the AI outputs:

```
<ralph>COMPLETE</ralph>
```

This tells the loop to exit successfully.

## Common Commands

```bash
# Planning
./ralph.sh plan                  # Plan until complete (max 10 iterations)
./ralph.sh plan 5                # Limit to 5 iterations

# Building
./ralph.sh                       # Build mode (default)
./ralph.sh build 20              # Build with max 20 iterations

# Custom prompts
./ralph.sh -f prompts/review.md  # Use custom prompt file
./ralph.sh -p "Fix lint errors"  # Inline prompt

# Model selection
./ralph.sh build --model sonnet  # Use Sonnet (faster, cheaper)
./ralph.sh plan --model opus     # Use Opus (default, most capable)

# Options
./ralph.sh --no-push             # Don't auto-push to remote
./ralph.sh --unlimited           # Remove iteration limit (careful!)
./ralph.sh --dry-run             # Preview config without running
./ralph.sh -s ./specs/feature.md # Custom spec (plan auto-derived)
```

## Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                        RALPH LOOP                               │
│                                                                 │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │  Read    │ -> │ Execute  │ -> │ Verify   │ -> │  Commit  │  │
│  │  State   │    │  1 Task  │    │  Tests   │    │  & Push  │  │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘  │
│       │                                                │        │
│       └────────────────── Loop ────────────────────────┘        │
│                                                                 │
│  Exit when: All tasks complete OR max iterations reached        │
└─────────────────────────────────────────────────────────────────┘
```

### Each Iteration

1. **Read State**: Check plan for next `[ ]` item
2. **Search First**: Verify functionality doesn't already exist
3. **Implement**: Complete exactly ONE task
4. **Verify**: Run tests and type checks (backpressure)
5. **Document**: Mark `[x]`, update progress
6. **Commit**: Push changes to remote
7. **Check**: All done? Signal completion. Otherwise, loop continues.

## Configuration

### ralph.conf

```bash
# Path defaults (supports template variables)
SPEC_FILE=./specs/IMPLEMENTATION_PLAN.md
PLAN_FILE=./plans/IMPLEMENTATION_PLAN.md
PROGRESS_FILE=progress.txt
SOURCE_DIR=src/*

# Execution settings (uncomment to change defaults)
# MODEL=opus
# MAX_ITERATIONS=10
# PUSH_ENABLED=true
```

### Template Variables

Prompts support these placeholders:

| Variable            | Default                          | Description              |
| ------------------- | -------------------------------- | ------------------------ |
| `{{SPEC_FILE}}`     | `./specs/IMPLEMENTATION_PLAN.md` | Feature specification    |
| `{{PLAN_FILE}}`     | `./plans/IMPLEMENTATION_PLAN.md` | Implementation checklist |
| `{{PROGRESS_FILE}}` | `progress.txt`                   | Iteration history        |
| `{{SOURCE_DIR}}`    | `src/*`                          | Source code location     |

## Customizing for Your Project

### 1. Update CLAUDE.md

Add your project-specific context:

```markdown
# Project Overview

[Brief description]

# Key Commands

npm run test # Run tests
npm run typecheck # Type checking
npm run build # Build project

# Architecture

[Key files and patterns]
```

### 2. Create Your First Spec

```bash
# Create a feature spec
cat > specs/my-feature.md << 'EOF'
# My Feature

## Overview
What this feature does and why.

## Requirements
- Requirement 1
- Requirement 2

## Architecture
How it fits into the existing system.
EOF
```

### 3. Run Planning

```bash
./ralph.sh plan -s ./specs/my-feature.md
```

This creates `plans/my-feature_PLAN.md` with a task checklist.

### 4. Run Build

```bash
./ralph.sh build -s ./specs/my-feature.md
```

## Best Practices

### Writing Good Checklist Items

| Bad                        | Good                                     |
| -------------------------- | ---------------------------------------- |
| "Implement authentication" | "Create token generation utility"        |
| "Fix bugs"                 | "Fix null pointer in UserCard component" |
| "Add tests"                | "Add unit tests for auth.ts"             |

### The "Don't Assume Missing" Rule

Before implementing anything, search the codebase first. It likely has what you need.

### Capture the Why

Document reasoning in progress.txt and CLAUDE.md, not just what changed.

### Plans Are Disposable

If a plan becomes wrong or stale—regenerate it. Don't patch bad plans.

## Documentation

| Document                                           | Purpose                                |
| -------------------------------------------------- | -------------------------------------- |
| [CLAUDE.md](./CLAUDE.md)                           | Project context and coding conventions |
| [docs/RALPH_LOOP_REF.md](./docs/RALPH_LOOP_REF.md) | Full CLI reference                     |
| [docs/RALPH_WORKSHOP.md](./docs/RALPH_WORKSHOP.md) | Comprehensive workshop guide           |
| [specs/INDEX.md](./specs/INDEX.md)                 | Feature catalog and conventions        |

## Exit Codes

| Code  | Meaning                                |
| ----- | -------------------------------------- |
| `0`   | Success—all tasks complete             |
| `1`   | Max iterations reached—work may remain |
| `130` | Interrupted (Ctrl+C)                   |

## Troubleshooting

### "Error: Prompt file not found"

Ensure prompt files exist:

```bash
ls prompts/PROMPT_plan.md prompts/PROMPT_build.md
```

### Loop runs but no progress

1. Check that plan file has `[ ]` items (unchecked)
2. Ensure tasks are specific enough to be actionable
3. Check progress.txt for what the AI attempted

### Tests keep failing

The AI should fix failures, but if stuck:

1. Check progress.txt for attempted solutions
2. Run tests manually to understand the failure
3. Consider simplifying the task

### View session logs

```bash
# Full logs saved to /tmp
ls -la /tmp/ralph_*.log
tail -f /tmp/ralph_build_*.log
```

## License

MIT
