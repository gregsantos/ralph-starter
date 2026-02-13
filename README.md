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

# Generate a spec from a feature description (NEW!)
./ralph.sh spec -p "Add user authentication with JWT tokens"
# Creates: specs/user-auth.json with tasks and acceptance criteria

# Or generate a spec from an existing PRD/requirements file
./ralph.sh spec -f ./requirements.md

# Or run the full one-shot pipeline (product optional)
./ralph.sh launch -p "Build a collaborative notes app with auth and realtime sync"

# Run build mode (executes tasks from spec one at a time)
./ralph.sh build -s ./specs/user-auth.json

# Optional: generate human-readable plan from spec
./ralph.sh plan -s ./specs/user-auth.json
```

## Project Structure

```
ralph-starter/
├── ralph.sh                      # The loop script
├── ralph.conf                    # Configuration defaults
├── CLAUDE.md                     # Project context for Claude
├── prompts/
│   ├── PROMPT_spec.md            # Spec generation instructions (NEW!)
│   ├── PROMPT_plan.md            # Planning mode instructions
│   ├── PROMPT_build.md           # Build mode instructions
│   └── PROMPT_product.md         # Product artifact generation
├── specs/
│   ├── INDEX.md                  # Feature catalog
│   ├── {feature}.json            # JSON specs with tasks (recommended)
│   └── {feature}.md              # Markdown specs (alternative)
├── plans/
│   └── {feature}_PLAN.md         # Derived task checklist (optional)
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

### Modes

| Mode        | Purpose                                      | Command              |
| ----------- | -------------------------------------------- | -------------------- |
| **Launch**  | One-shot pipeline: product(optional) → spec → build | `./ralph.sh launch` |
| **Spec**    | Generate JSON spec from input (NEW!)         | `./ralph.sh spec`    |
| **Plan**    | Derive readable checklist from spec tasks    | `./ralph.sh plan`    |
| **Build**   | Execute tasks from spec one at a time        | `./ralph.sh build`   |
| **Product** | Generate product documentation artifacts     | `./ralph.sh product` |

**Recommended workflow**: `launch` for one-shot execution, or `spec` → `build` for manual control (plan mode is optional).

### Specs vs Plans

| Directory | Contains                  | Purpose                                                  | Lifecycle      |
| --------- | ------------------------- | -------------------------------------------------------- | -------------- |
| `specs/`  | Feature specifications    | Requirements, tasks, acceptance criteria (source of truth) | Semi-permanent |
| `plans/`  | Implementation checklists | Human-readable view derived from spec tasks (optional)   | Disposable     |

### Spec Formats: Tasks vs User Stories

| Format           | Use Case                  | Recommended? |
| ---------------- | ------------------------- | ------------ |
| **tasks** array  | New specs with spec mode  | ✅ Yes        |
| **userStories**  | Legacy/existing specs     | Backward compatible |

**Tasks format** (recommended):
```json
{
  "tasks": [
    {
      "id": "T-001",
      "title": "Add login form",
      "description": "Create login form component with validation",
      "acceptanceCriteria": ["Form validates email format", "Submit disabled when invalid"],
      "dependsOn": [],
      "status": "pending",
      "passes": false,
      "effort": "small"
    }
  ]
}
```

- Build mode reads tasks directly from spec—no separate plan file needed
- `status` tracks progress: pending → in_progress → complete
- `passes` indicates completion (true when all acceptance criteria met)
- `dependsOn` ensures tasks run in correct order

**userStories format** (legacy):
```json
{
  "userStories": [
    {
      "id": "US-001",
      "title": "User login",
      "acceptanceCriteria": ["..."],
      "passes": false
    }
  ]
}
```

- Requires plan mode to generate a separate checklist file
- Build mode updates both plan file and spec—higher divergence risk

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
# Spec generation (NEW!)
./ralph.sh spec -p "Add dark mode"          # From inline description
./ralph.sh spec -f ./requirements.md        # From requirements file
./ralph.sh spec --from-product              # From product artifacts
./ralph.sh spec -p "Feature" -o ./specs/feature.json  # Custom output

# Building (uses spec as source of truth)
./ralph.sh                       # Build mode (default)
./ralph.sh build 20              # Build with max 20 iterations
./ralph.sh build -s ./specs/feature.json    # Build from specific spec

# Planning (optional - generates readable checklist from spec)
./ralph.sh plan -s ./specs/feature.json     # Derive plan from spec
./ralph.sh plan 5                # Limit to 5 iterations

# Product artifacts
./ralph.sh product               # Generate product docs (12 artifacts)
./ralph.sh product --context ./input/ --output ./output/  # Custom paths

# Launch pipeline (one-shot)
./ralph.sh launch -p "Build an AI meeting assistant"
./ralph.sh launch -f ./requirements.md
./ralph.sh launch --full-product --context ./product-input
./ralph.sh launch --skip-product -p "Build a Kanban app"

# Custom prompts
./ralph.sh -f prompts/review.md  # Use custom prompt file
./ralph.sh -p "Fix lint errors"  # Inline prompt (build mode)

# Model selection
./ralph.sh build --model sonnet  # Use Sonnet (faster, cheaper)
./ralph.sh spec --model opus     # Use Opus (default for spec)

# Options
./ralph.sh --no-push             # Don't auto-push to remote
./ralph.sh --unlimited           # Remove iteration limit (careful!)
./ralph.sh --dry-run             # Preview config without running

# Session management
./ralph.sh --resume              # Resume interrupted session
./ralph.sh --list-sessions       # List resumable sessions

# Resilience
./ralph.sh --no-retry            # Disable automatic retry on errors
./ralph.sh --max-retries 5       # Custom retry limit (default: 3)
```

See [docs/RALPH_LOOP_REF.md](docs/RALPH_LOOP_REF.md) for the full CLI reference including environment variables, global config, and all options.

## Complete Workflow

The simplified workflow for implementing features with Ralph:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│           PRODUCT (optional) → SPEC → BUILD                                  │
│                                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                              │
│  │ Product  │ -> │   Spec   │ -> │  Build   │                              │
│  │   Mode   │    │   Mode   │    │   Mode   │                              │
│  │(discover)│    │(generate)│    │ (execute)│                              │
│  └──────────┘    └──────────┘    └──────────┘                              │
│       │               │               │                                     │
│  product-output/  specs/*.json   Code changes                              │
│  12 artifacts     tasks + spec   Implementation                            │
│                                                                             │
│  Plan mode is optional—generates human-readable view from spec tasks        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### One-Shot Workflow (`launch`)

Run the full pipeline with one command:

```bash
# Uses prompt input, auto-creates feature branch, runs spec->build
# Product phase runs only when --full-product or product-input has meaningful content
./ralph.sh launch -p "Build a habit tracker with streaks"

# Force product phase first (15 iters), then spec (5), then build (tasks + buffer)
./ralph.sh launch --full-product -p "Build a CRM for small agencies"
```

Launch defaults:
- Product phase is **optional** by default.
- Product runs when `--full-product` is set, or `product-input/` contains meaningful non-empty context files.
- Build iterations are computed dynamically: `task_count + launch_buffer` (default buffer `5`).
- Plan mode is not part of launch (spec tasks are the source of truth).
- `--dry-run` is read-only and does not archive branches or modify `progress.txt`.
- Use `--skip-product` to force spec→build only, or `--launch-buffer N` to tune build iteration headroom.

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

# 3. Generate spec from product artifacts
./ralph.sh spec --from-product
#    → specs/new-spec.json with tasks derived from PRD
```

See `docs/PRODUCT_ARTIFACT_SPEC.md` for the full artifact specification.

### Step 1: Generate a Spec (Recommended)

Use spec mode to generate a JSON spec with tasks:

```bash
# From a feature description
./ralph.sh spec -p "Add user authentication with JWT tokens"

# From a requirements file
./ralph.sh spec -f ./requirements.md

# From product artifacts (after running product mode)
./ralph.sh spec --from-product

# Specify output file
./ralph.sh spec -p "Dark mode toggle" -o ./specs/dark-mode.json
```

This creates a spec with:
- **tasks** array: Atomic implementation tasks with acceptance criteria
- **context**: Current state, target state, constraints
- **dependencies**: Which tasks depend on which

### Step 1 (Alternative): Create Spec Manually

Create a JSON spec file manually in `specs/`:

```json
{
  "project": "My Feature",
  "branchName": "feature/my-feature",
  "description": "What this feature does",
  "tasks": [
    {
      "id": "T-001",
      "title": "First task",
      "description": "Implementation details",
      "acceptanceCriteria": ["Criterion 1", "Criterion 2"],
      "dependsOn": [],
      "status": "pending",
      "passes": false,
      "effort": "small"
    }
  ]
}
```

The `passes` field starts as `false` and is set to `true` by build mode when all acceptance criteria are met.

See `specs/unified-spec-workflow.json` for a comprehensive example.

### Step 2: Run Build Mode

Build mode executes tasks from the spec one at a time:

```bash
./ralph.sh build -s ./specs/my-feature.json
# Reads tasks from spec, implements each one, runs tests, commits
```

### Step 3 (Optional): Generate Human-Readable Plan

Plan mode can generate a Markdown checklist from spec tasks:

```bash
./ralph.sh plan -s ./specs/my-feature.json
# Creates: plans/my-feature_PLAN.md (read-only view)
```

Note: Build mode works directly from the spec—plans are optional for documentation purposes.

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

1. **Read State**: Find next task in spec where `passes=false` and dependencies satisfied
2. **Search First**: Verify functionality doesn't already exist
3. **Implement**: Complete exactly ONE task
4. **Verify**: Run tests and type checks (backpressure)
5. **Document**: Set `passes=true` and `status=complete` in spec, update progress
6. **Commit**: Push changes to remote (commit message includes task ID: `feat(T-001): description`)
7. **Check**: All tasks done? Signal completion. Otherwise, loop continues.

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

**Option A: Use Spec Mode (Recommended)**

Generate a spec with tasks automatically:

```bash
# From a feature description
./ralph.sh spec -p "Add user authentication with JWT tokens" -o ./specs/auth.json

# From a requirements file
./ralph.sh spec -f ./requirements.md -o ./specs/my-feature.json
```

**Option B: JSON Spec (Manual)**

Create a JSON spec with tasks manually:

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
  "tasks": [
    {
      "id": "T-001",
      "title": "First task",
      "description": "Implementation details",
      "acceptanceCriteria": [
        "Specific criterion 1",
        "Specific criterion 2",
        "pnpm typecheck passes"
      ],
      "dependsOn": [],
      "status": "pending",
      "passes": false,
      "effort": "small"
    }
  ]
}
EOF
```

**Option C: Markdown Spec (Simpler)**

For less structured work (requires plan mode):

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

### 3. Run Build

```bash
# Build from spec with tasks (recommended)
./ralph.sh build -s ./specs/my-feature.json
```

### 4. Run Planning (Optional)

For specs without tasks, or to generate a human-readable checklist:

```bash
# Generate plan from spec
./ralph.sh plan -s ./specs/my-feature.json
# Creates: plans/my-feature_PLAN.md

# Then build from spec
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
ls prompts/PROMPT_spec.md prompts/PROMPT_plan.md prompts/PROMPT_build.md prompts/PROMPT_product.md
```

### Loop runs but no progress

1. Check that spec has tasks with `passes: false`, or plan file has `[ ]` items
2. Ensure tasks are specific enough to be actionable
3. Check progress.txt for what the AI attempted
4. Verify task dependencies aren't blocking (all `dependsOn` tasks must have `passes: true`)

### Tests keep failing

The AI should fix failures, but if stuck:

1. Check progress.txt for attempted solutions
2. Run tests manually to understand the failure
3. Consider simplifying the task

### View session logs

```bash
# Full logs saved to ~/.ralph/logs/
ls -la ~/.ralph/logs/
tail -f ~/.ralph/logs/latest.log
```

## License

MIT
