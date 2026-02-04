# Ralph Starter Template

A minimal starter kit for autonomous AI-assisted development with **Ralph Loop**.

Ralph Loop breaks complex software development into small, context-independent tasks and executes them iteratively. Each iteration spawns a fresh AI instance—persistence comes only from files.

## Why Ralph?

- **Incremental progress**: Complex features become manageable when broken into single-iteration tasks
- **Quality gates**: Every iteration must pass tests and type checks before proceeding
- **Knowledge preservation**: Learnings persist in files, not AI memory
- **Hands-off execution**: Start a session, walk away, return to completed work
- **Resilient sessions**: Automatic retry on transient failures, resume interrupted sessions
- **Flexible configuration**: Environment variables, global config, and project config

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
│   ├── PROMPT_build.md           # Build mode instructions
│   └── PROMPT_product.md         # Product artifact generation
├── specs/
│   ├── INDEX.md                  # Feature catalog
│   ├── {feature}.json            # JSON specs (recommended)
│   └── {feature}.md              # Markdown specs (alternative)
├── plans/
│   └── IMPLEMENTATION_PLAN.md    # Task checklist (the "how")
├── .claude/
│   └── skills/
│       └── writing-ralph-specs/  # Skill for creating JSON specs
├── product-input/                # Product context files (product mode)
├── product-output/               # Generated artifacts (product mode)
├── progress.txt                  # Iteration history (auto-created)
├── archive/                      # Auto-archived branch state
└── docs/
    ├── RALPH_LOOP_REF.md         # Full CLI reference
    ├── RALPH_WORKSHOP.md         # Comprehensive workshop guide
    └── PRODUCT_ARTIFACT_SPEC.md  # Product artifact specifications
```

## Core Concepts

### Three Modes

| Mode        | Purpose                                  | Command              |
| ----------- | ---------------------------------------- | -------------------- |
| **Plan**    | Analyze codebase, create task checklist  | `./ralph.sh plan`    |
| **Build**   | Execute tasks one at a time              | `./ralph.sh build`   |
| **Product** | Generate product documentation artifacts | `./ralph.sh product` |

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

# Product artifacts
./ralph.sh product               # Generate product docs (12 artifacts)
./ralph.sh product --context ./input/ --output ./output/  # Custom paths

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

# Session management
./ralph.sh --resume              # Resume interrupted session
./ralph.sh --list-sessions       # List resumable sessions

# Resilience
./ralph.sh --no-retry            # Disable automatic retry on errors
./ralph.sh --max-retries 5       # Custom retry limit (default: 3)
```

See [docs/RALPH_LOOP_REF.md](docs/RALPH_LOOP_REF.md) for the full CLI reference including environment variables, global config, and all options.

## Complete Workflow

The full workflow for implementing features with Ralph:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│           PRODUCT (optional) → SPEC → PLAN → BUILD                          │
│                                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ Product  │ -> │  Create  │ -> │   Plan   │ -> │  Build   │              │
│  │   Mode   │    │   Spec   │    │   Mode   │    │   Mode   │              │
│  │(discover)│    │  (JSON)  │    │ (analyze)│    │ (execute)│              │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘              │
│       │               │               │               │                     │
│  product-output/  specs/*.json   plans/*_PLAN.md   Code changes            │
│  12 artifacts     "what & why"    "how"           Implementation           │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Step 0: Product Discovery (Optional)

For new projects, start with product mode to generate foundational artifacts:

```bash
# 1. Add context files to product-input/
#    - vision.md, research.md, requirements.md, etc.

# 2. Run product mode to generate 12 artifacts
./ralph.sh product
#    → product-output/1_executive_summary.md
#    → product-output/7_prd.md
#    → ... (12 total artifacts)

# 3. Use the PRD (7_prd.md) to inform your spec
```

See `docs/PRODUCT_ARTIFACT_SPEC.md` for the full artifact specification.

### Step 1: Create a Spec

Create a JSON spec file in `specs/` with user stories and acceptance criteria:

```bash
# specs/my-feature.json
{
  "project": "My Feature",
  "branchName": "feature/my-feature",
  "description": "What this feature does",
  "userStories": [
    {
      "id": "US-001",
      "title": "First task",
      "acceptanceCriteria": ["Criterion 1", "Criterion 2"],
      "priority": 1,
      "passes": false
    }
  ]
}
```

The `passes` field starts as `false` and is set to `true` by build mode when all acceptance criteria are met.

See `specs/ralph-improvements.json` for a comprehensive example.

### Step 2: Run Plan Mode

Plan mode analyzes the spec and codebase, then creates a task checklist:

```bash
./ralph.sh plan -s ./specs/my-feature.json
# Creates: plans/my-feature_PLAN.md
```

### Step 3: Run Build Mode

Build mode executes the plan one task at a time:

```bash
./ralph.sh build -s ./specs/my-feature.json
# Implements each task, runs tests, commits
```

## Loop Architecture

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
5. **Document**: Mark `[x]` in plan, update `passes` in spec (if story complete), update progress
6. **Commit**: Push changes to remote
7. **Check**: All done? Signal completion. Otherwise, loop continues.

## Configuration

### ralph.conf

```bash
# Path defaults (supports template variables)
SPEC_FILE=./specs/IMPLEMENTATION_PLAN.md
PLAN_FILE=./plans/IMPLEMENTATION_PLAN.md
ARTIFACT_SPEC_FILE=./docs/PRODUCT_ARTIFACT_SPEC.md
PROGRESS_FILE=progress.txt
SOURCE_DIR=src/*

# Execution settings (uncomment to change defaults)
# MODEL=opus
# MAX_ITERATIONS=10
# PUSH_ENABLED=true
```

### Template Variables

Prompts support these placeholders:

**Build/Plan Mode:**

| Variable            | Default                          | Description              |
| ------------------- | -------------------------------- | ------------------------ |
| `{{SPEC_FILE}}`     | `./specs/IMPLEMENTATION_PLAN.md` | Feature specification    |
| `{{PLAN_FILE}}`     | `./plans/IMPLEMENTATION_PLAN.md` | Implementation checklist |
| `{{PROGRESS_FILE}}` | `progress.txt`                   | Iteration history        |
| `{{SOURCE_DIR}}`    | `src/*`                          | Source code location     |

**Product Mode:**

| Variable                  | Default                           | Description             |
| ------------------------- | --------------------------------- | ----------------------- |
| `{{PRODUCT_CONTEXT_DIR}}` | `./product-input/`                | Product context files   |
| `{{PRODUCT_OUTPUT_DIR}}`  | `./product-output/`               | Generated artifacts     |
| `{{ARTIFACT_SPEC_FILE}}`  | `./docs/PRODUCT_ARTIFACT_SPEC.md` | Artifact specifications |
| `{{PROGRESS_FILE}}`       | `progress.txt`                    | Iteration history       |

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

**Option A: JSON Spec (Recommended)**

JSON specs provide structured user stories with acceptance criteria:

```bash
cat > specs/my-feature.json << 'EOF'
{
  "project": "My Feature",
  "branchName": "feature/my-feature",
  "description": "What this feature does and why",
  "context": {
    "currentState": "Current situation",
    "targetState": "Desired outcome",
    "verificationCommands": ["pnpm test", "pnpm typecheck"]
  },
  "userStories": [
    {
      "id": "US-001",
      "title": "First task",
      "description": "As a user, I want X so that Y.",
      "acceptanceCriteria": [
        "Specific criterion 1",
        "Specific criterion 2",
        "pnpm typecheck passes"
      ],
      "priority": 1,
      "passes": false
    }
  ]
}
EOF
```

**Option B: Markdown Spec (Simpler)**

For less structured work:

```bash
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
# For JSON spec
./ralph.sh plan -s ./specs/my-feature.json

# For markdown spec
./ralph.sh plan -s ./specs/my-feature.md
```

This creates `plans/my-feature_PLAN.md` with a task checklist.

### 4. Run Build

```bash
./ralph.sh build -s ./specs/my-feature.json
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

| Document                                                         | Purpose                                |
| ---------------------------------------------------------------- | -------------------------------------- |
| [CLAUDE.md](./CLAUDE.md)                                         | Project context and coding conventions |
| [docs/RALPH_LOOP_REF.md](./docs/RALPH_LOOP_REF.md)               | Full CLI reference                     |
| [docs/RALPH_WORKSHOP.md](./docs/RALPH_WORKSHOP.md)               | Comprehensive workshop guide           |
| [docs/PRODUCT_ARTIFACT_SPEC.md](./docs/PRODUCT_ARTIFACT_SPEC.md) | Product artifact specifications        |
| [specs/INDEX.md](./specs/INDEX.md)                               | Feature catalog and conventions        |

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
ls prompts/PROMPT_plan.md prompts/PROMPT_build.md prompts/PROMPT_product.md
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
