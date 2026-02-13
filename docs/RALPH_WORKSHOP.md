# Ralph Loop: Workshop Guide

A comprehensive guide to autonomous AI-assisted development with Ralph Loop.

---

## Table of Contents

1. [What is Ralph Loop?](#what-is-ralph-loop)
2. [Core Concepts](#core-concepts)
3. [Quick Start](#quick-start)
4. [The Five Modes](#the-five-modes)
5. [The Recommended Workflow](#the-recommended-workflow)
6. [Configuration](#configuration)
7. [Spec Mode](#spec-mode)
8. [Plan Mode](#plan-mode)
9. [Build Mode](#build-mode)
10. [Product Mode](#product-mode)
11. [The Iteration Cycle](#the-iteration-cycle)
12. [Best Practices](#best-practices)
13. [Advanced Usage](#advanced-usage)
14. [Troubleshooting](#troubleshooting)
15. [Quick Reference](#quick-reference)

---

## What is Ralph Loop?

Ralph Loop is an **autonomous AI agent runner** that breaks software development into small, context-independent tasks and executes them iteratively. Each iteration spawns a fresh AI instance with no memory between runs—persistence comes only from files.

### Why Ralph?

- **Incremental progress**: Complex features become manageable when broken into single-iteration tasks
- **Quality gates**: Every iteration must pass tests and type checks before proceeding
- **Knowledge preservation**: Learnings persist in files, not AI memory
- **Hands-off execution**: Start a session, walk away, return to completed work
- **Autonomous recovery**: Automatic retry with exponential backoff for transient failures

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

| File                           | Purpose                                        |
| ------------------------------ | ---------------------------------------------- |
| `specs/{feature}.json`         | Feature specification with tasks (source of truth) |
| `plans/{feature}_PLAN.md`      | Human-readable plan (optional, derived from spec) |
| `progress.txt`                 | Append-only log of decisions and learnings     |
| `CLAUDE.md`                    | Project context and discovered patterns        |

### 2. Specs vs Plans

| Directory | Contains                  | Purpose                               | Lifecycle      |
| --------- | ------------------------- | ------------------------------------- | -------------- |
| `specs/`  | JSON feature specifications | Requirements + tasks (source of truth) | Semi-permanent |
| `plans/`  | Markdown checklists       | Human-readable view (optional)        | Disposable     |

**The key insight**: Specs with a `tasks` array are the single source of truth. Build mode works directly from the spec—no separate plan file needed. Plan mode is optional for generating human-readable views.

### 3. Five Modes

| Mode      | Purpose                                           | When to Use                                      |
| --------- | ------------------------------------------------- | ------------------------------------------------ |
| **Launch** | One-shot pipeline (product optional -> spec -> build) | Fastest path from idea to first implementation   |
| **Spec**  | Generate JSON specs from input                    | Starting from requirements, PRD, or idea         |
| **Plan**  | Create human-readable plan (optional)             | When you need a readable checklist view          |
| **Build** | Execute tasks one at a time                       | Implementing the spec                            |
| **Product** | Generate product documentation                  | Product discovery and planning                   |

### 4. One Task Per Iteration

**Critical rule**: Complete exactly ONE task per iteration.

- Too much? AI loses context, makes mistakes
- Too little? Wastes iterations on trivial progress

### 5. Completion Signal

When ALL tasks are done, the AI outputs:

```
<ralph>COMPLETE</ralph>
```

This tells the loop to exit successfully. Without this marker, the loop continues until max iterations.

### 6. Quality Gates (Backpressure)

Tests and type checks are your **rejection mechanism**. They push back on bad changes:

- Tests fail → Change is wrong. Fix or reconsider.
- Types fail → Interface contract broken. Align types.
- Never leave broken builds for the next iteration.

---

## Quick Start

### Prerequisites

```bash
# Required tools
claude --version    # Claude CLI installed and authenticated
jq --version        # JSON parsing
git --version       # Version control
```

### Installation

Ralph runs pre-flight checks automatically to verify dependencies. Use `--skip-checks` to bypass if needed.

### Your First Run

```bash
# 1. One-shot flow (recommended for quick starts)
./ralph.sh launch -p "Add dark mode toggle to settings"

# 2. Optional: use explicit spec->build for more control
./ralph.sh spec -p "Add dark mode toggle to settings"
./ralph.sh build -s ./specs/new-spec.json

# Done! Ralph handles the rest autonomously.
```

### Verify Setup

```bash
./ralph.sh --help
```

You should see the help output with all available options.

---

## The Five Modes

### Mode Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│     PRODUCT (optional) → SPEC MODE → BUILD MODE                             │
│                                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                               │
│  │ Product  │ -> │   Spec   │ -> │  Build   │                               │
│  │   Mode   │    │   Mode   │    │   Mode   │                               │
│  │(discover)│    │(generate)│    │ (execute)│                               │
│  └──────────┘    └──────────┘    └──────────┘                               │
│       │               │               │                                     │
│  product-output/  specs/*.json    Code changes                              │
│  12 artifacts     with tasks      Implementation                            │
│                                                                             │
│  Optional: Plan mode generates human-readable view from spec                │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Mode Defaults

| Mode          | Default Model | Rationale                                    |
| ------------- | ------------- | -------------------------------------------- |
| `launch`      | opus          | End-to-end product/spec/build orchestration |
| `spec`        | opus          | Requires deep understanding for spec design  |
| `plan`        | opus          | Complex reasoning for architecture decisions |
| `build`       | opus          | Quality implementation with full context     |
| `product`     | opus          | Comprehensive product artifact generation    |
| `inline` (-p) | sonnet        | Faster for quick, focused tasks              |
| `custom` (-f) | opus          | Assumes complex task unless specified        |

---

## The Recommended Workflow

### Launch (One Command)

For most greenfield or early feature work, use launch mode:

```bash
# Product phase auto-runs only when context is meaningful
./ralph.sh launch -p "Add user authentication with OAuth"

# Force product phase first
./ralph.sh launch --full-product -p "Build a recruiting platform"

# Force spec->build only
./ralph.sh launch --skip-product -p "Ship a small docs feature"
```

Launch behavior:
1. Auto-creates/switches to `feature/<slug>` branch
2. Runs product phase only when forced or meaningful `product-input/` exists
3. Runs spec phase (default max 5 iterations)
4. Runs build phase with dynamic iterations (`task_count + launch buffer`)
5. Skips plan mode (spec tasks are source of truth)

### Spec → Build (Simplest)

For most features, you only need two steps:

```bash
# 1. Create a spec with tasks
./ralph.sh spec -p "Add user authentication with OAuth"
#    → specs/new-spec.json

# 2. Execute the tasks
./ralph.sh build -s ./specs/new-spec.json
#    → Implementation complete
```

### Product → Spec → Build (Full Discovery)

For new projects or major features, start with product mode:

```bash
# 1. Add context files to product-input/
mkdir -p product-input
# Add: vision.md, research.md, requirements.md

# 2. Generate product artifacts (12 documents)
./ralph.sh product
#    → product-output/7_prd.md (and 11 others)

# 3. Generate spec from product artifacts
./ralph.sh spec --from-product
#    → specs/new-spec.json

# 4. Build the feature
./ralph.sh build -s ./specs/new-spec.json
```

### When to Use Each Workflow

| Scenario | Workflow |
|----------|----------|
| One-shot implementation | `./ralph.sh launch -p "..."` |
| Quick bug fix | `./ralph.sh -p "Fix the null pointer in UserCard"` |
| Small feature | `./ralph.sh spec -p "..." && ./ralph.sh build -s ...` |
| Major feature | `./ralph.sh product && ./ralph.sh spec --from-product && ./ralph.sh build -s ...` |
| Existing requirements doc | `./ralph.sh spec -f ./requirements.md && ./ralph.sh build -s ...` |

---

## Configuration

### Config File Locations

1. **Global config**: `~/.ralph/config` (user-wide defaults)
2. **Project config**: `./ralph.conf` (project-specific overrides)

### Example `ralph.conf`

```bash
# Ralph Loop Configuration
# Use standard KEY=VALUE syntax (no shell execution for security)

# Path Configuration
SPEC_FILE=./specs/IMPLEMENTATION_PLAN.md
PLAN_FILE=./plans/IMPLEMENTATION_PLAN.md
PROGRESS_FILE=progress.txt
SOURCE_DIR=src/*

# Execution Settings
MODEL=opus
MAX_ITERATIONS=10
PUSH_ENABLED=true

# Logging
LOG_DIR=~/.ralph/logs
LOG_FORMAT=text
```

### Configuration Precedence

CLI flags > Environment variables > Config file > Defaults

### Environment Variables

| Variable               | Description                             | Example                       |
| ---------------------- | --------------------------------------- | ----------------------------- |
| `RALPH_MODEL`          | Default model (opus, sonnet, haiku)     | `RALPH_MODEL=sonnet`          |
| `RALPH_MAX_ITERATIONS` | Maximum iterations limit                | `RALPH_MAX_ITERATIONS=20`     |
| `RALPH_PUSH_ENABLED`   | Git push toggle (true/false/yes/no/1/0) | `RALPH_PUSH_ENABLED=false`    |
| `RALPH_SPEC_FILE`      | Path to spec file                       | `RALPH_SPEC_FILE=./spec.json` |
| `RALPH_PLAN_FILE`      | Path to plan file                       | `RALPH_PLAN_FILE=./plan.md`   |
| `RALPH_PROGRESS_FILE`  | Path to progress file                   | `RALPH_PROGRESS_FILE=log.txt` |
| `RALPH_LOG_DIR`        | Log directory path                      | `RALPH_LOG_DIR=/tmp/logs`     |
| `RALPH_LOG_FORMAT`     | Log format (text/json)                  | `RALPH_LOG_FORMAT=json`       |
| `RALPH_LAUNCH_BUFFER`  | Build iteration buffer in launch mode   | `RALPH_LAUNCH_BUFFER=8`       |
| `RALPH_FULL_PRODUCT`   | Force product phase in launch mode      | `RALPH_FULL_PRODUCT=true`     |
| `RALPH_SKIP_PRODUCT`   | Skip product phase in launch mode       | `RALPH_SKIP_PRODUCT=true`     |
| `RALPH_NOTIFY_WEBHOOK` | Webhook URL for session notifications   | `RALPH_NOTIFY_WEBHOOK=...`    |

### Template Variables

Prompts support these placeholders (automatically substituted):

| Variable            | Default                          | Description                              |
| ------------------- | -------------------------------- | ---------------------------------------- |
| `{{SPEC_FILE}}`     | `./specs/IMPLEMENTATION_PLAN.md` | Feature specification                    |
| `{{PLAN_FILE}}`     | `./plans/IMPLEMENTATION_PLAN.md` | Implementation checklist                 |
| `{{PROGRESS_FILE}}` | `progress.txt`                   | Iteration log                            |
| `{{SOURCE_DIR}}`    | `src/*`                          | Source code location                     |

---

## Spec Mode

Spec mode generates structured JSON specifications from various input sources. The generated specs can then be executed directly by build mode.

### Input Sources

You need exactly one input source:

| Flag | Description |
|------|-------------|
| `-p, --prompt STR` | Inline feature description |
| `-f, --file PATH` | Requirements file (markdown, text) |
| `--from-product` | Read from product-output/ artifacts |

### Running Spec Mode

```bash
# From inline description
./ralph.sh spec -p "Add dark mode toggle to settings"

# From requirements file
./ralph.sh spec -f ./requirements/dark-mode.md

# From product artifacts (reads 7_prd.md, etc.)
./ralph.sh spec --from-product

# Specify custom output path
./ralph.sh spec -p "Add user auth" -o ./specs/auth.json

# Overwrite existing spec file
./ralph.sh spec -p "Update auth flow" -o ./specs/auth.json --force
```

### What Spec Mode Does

1. **Reads the skill**: Consults `.claude/skills/writing-ralph-specs/SKILL.md`
2. **Understands input**: Parses requirements from your chosen source
3. **Researches codebase**: Finds existing patterns and utilities
4. **Designs tasks**: Creates atomic, verifiable tasks with dependencies
5. **Generates JSON**: Writes spec to output file

### The Tasks Array Format (Recommended)

```json
{
  "project": "Feature Name",
  "branchName": "feature/branch-name",
  "description": "One-line description of the feature",
  "context": {
    "currentState": "What exists today",
    "targetState": "What we want to achieve",
    "verificationCommands": ["pnpm test", "pnpm typecheck"]
  },
  "tasks": [
    {
      "id": "T-001",
      "title": "Short action title",
      "description": "What this task accomplishes and why",
      "acceptanceCriteria": [
        "Specific, testable criterion 1",
        "Specific, testable criterion 2",
        "pnpm test passes"
      ],
      "dependsOn": [],
      "status": "pending",
      "passes": false,
      "effort": "small",
      "notes": ""
    },
    {
      "id": "T-002",
      "title": "Depends on T-001",
      "description": "This task builds on T-001",
      "acceptanceCriteria": ["..."],
      "dependsOn": ["T-001"],
      "status": "pending",
      "passes": false,
      "effort": "medium",
      "notes": ""
    }
  ]
}
```

### Task Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier (e.g., "T-001") |
| `title` | string | Yes | Short action title |
| `description` | string | Yes | What needs to be done |
| `acceptanceCriteria` | string[] | Yes | Specific, testable criteria |
| `dependsOn` | string[] | Yes | Task IDs this depends on (empty if none) |
| `status` | string | Yes | pending, in_progress, complete, blocked |
| `passes` | boolean | Yes | `false` initially; `true` when done |
| `effort` | string | Yes | small, medium, large |
| `notes` | string | No | Implementation notes (populated by build) |

---

## Plan Mode

Plan mode creates a human-readable Markdown view of your spec. It's **optional** when using specs with tasks—build mode works directly from the spec.

### When to Use Plan Mode

- You want a readable checklist to share with teammates
- You prefer reviewing tasks in Markdown format
- You're using the legacy `userStories` format (requires plan for build)

### Running Plan Mode

```bash
# Generate plan from spec
./ralph.sh plan -s ./specs/my-feature.json
#    → plans/my-feature_PLAN.md

# Default behavior (when no spec specified)
./ralph.sh plan
#    → Uses ./specs/IMPLEMENTATION_PLAN.md
```

### What Plan Mode Does

1. **Reads** the spec's `tasks` array
2. **Generates** a Markdown plan with checkboxes
3. **Groups** tasks by phase (if phases defined)
4. **Shows** dependencies clearly
5. **Marks** completion status: `[ ]` for pending, `[x]` for complete

### Generated Plan Format

```markdown
# Implementation Plan: Feature Name

> ⚠️ **This is a derived view.** Edit the spec, not this file.
> Build mode works directly from the spec's tasks array.

## Overview

Brief description from spec

## Tasks

### Phase: Setup

- [ ] **T-001**: Configure infrastructure
  - Install required dependencies
  - Add configuration to project
  - Dependencies: None

- [ ] **T-002**: Implement core functionality
  - Feature works as specified
  - Tests added and passing
  - Dependencies: T-001

## Progress Summary

- **Completed**: 0 of 2 tasks
- **Ready**: T-001
```

### Plan Derivation from Spec

When you specify a spec file, the plan file is automatically derived:

| Spec File                | Derived Plan File             |
| ------------------------ | ----------------------------- |
| `./specs/feature.json`   | `./plans/feature_PLAN.md`     |
| `./specs/auth-system.md` | `./plans/auth-system_PLAN.md` |

---

## Build Mode

Build mode executes the spec one task at a time. It's where the actual implementation happens.

### When to Use Build Mode

- Spec exists with clear tasks
- Ready for autonomous implementation
- After planning is complete (for legacy workflow)

### Running Build Mode

```bash
# Basic: Build until complete (up to 10 iterations)
./ralph.sh build

# Equivalent (build is default)
./ralph.sh

# With specific spec file
./ralph.sh build -s ./specs/my-feature.json

# Limit iterations
./ralph.sh build 5

# Different model for faster iterations
./ralph.sh build --model sonnet
```

### What Build Mode Does (Each Iteration)

1. **Read State**: Find next task where `passes: false` and all `dependsOn` tasks have `passes: true`
2. **Set Status**: Mark task `"in_progress"` in spec
3. **Search First**: Verify functionality doesn't already exist
4. **Implement**: Complete exactly ONE task
5. **Verify**: Run tests and type checks
6. **Update Spec**: Set `passes: true` and `status: "complete"`, add notes
7. **Document**: Update progress.txt
8. **Commit**: Push changes with task ID in message: `feat(T-001): description`
9. **Check**: All done? Signal completion. Otherwise, loop continues.

### The One-Task Rule

Each iteration completes **exactly one** task:

```markdown
Before iteration 3:

Task T-001: [x] passes: true
Task T-002: [x] passes: true
Task T-003: [ ] passes: false  <- This iteration works on this
Task T-004: [ ] passes: false
Task T-005: [ ] passes: false

After iteration 3:

Task T-001: [x] passes: true
Task T-002: [x] passes: true
Task T-003: [x] passes: true  <- Now complete
Task T-004: [ ] passes: false <- Next iteration
Task T-005: [ ] passes: false
```

### Build Mode Rules

| Rule                     | Why                                          |
| ------------------------ | -------------------------------------------- |
| **Don't assume missing** | Search codebase before adding new code       |
| **Fix all failures**     | Never leave broken builds for next iteration |
| **Capture the why**      | Document reasoning, not just what            |
| **No placeholders**      | Implement completely or don't start          |
| **Update spec**          | Set `passes: true` when task is done         |

---

## Product Mode

Product mode generates comprehensive product documentation—12 artifacts that cover everything from executive summary to go-to-market strategy.

### When to Use Product Mode

- Starting a new project
- Major feature requiring stakeholder alignment
- Need comprehensive product documentation
- Want to generate PRD before specs

### Running Product Mode

```bash
# Basic: Generate all 12 artifacts
./ralph.sh product

# Custom input/output directories
./ralph.sh product --context ./my-context/ --output ./my-output/

# Custom artifact specification
./ralph.sh product --artifact-spec ./docs/MY_SPEC.md
```

### Product Mode Workflow

1. **Add context files** to `product-input/`:
   - `vision.md` - Product vision and goals
   - `research.md` - User research, market data
   - `requirements.md` - High-level requirements

2. **Run product mode**:
   ```bash
   ./ralph.sh product
   ```

3. **Review generated artifacts** in `product-output/`:
   - `1_executive_summary.md`
   - `2_charter.md`
   - `3_market_analysis.md`
   - `4_personas.md`
   - `5_journey_map.md`
   - `6_positioning.md`
   - `7_prd.md` ← Use this to inform your spec
   - `8_product_roadmap.md`
   - `9_technical_requirements.md`
   - `10_ux_copy_deck.md`
   - `11_wireflow.md`
   - `12_go_to_market.md`

4. **Generate spec from PRD**:
   ```bash
   ./ralph.sh spec --from-product
   ```

### Artifact Dependencies

Artifacts are generated in dependency order:

```
Phase 1: Strategic Foundation
  └─▶ 1_executive_summary.md
  └─▶ 2_charter.md

Phase 2: Market & User Discovery
  └─▶ 3_market_analysis.md
  └─▶ 4_personas.md
  └─▶ 5_journey_map.md

Phase 3: Product Definition
  └─▶ 6_positioning.md
  └─▶ 7_prd.md
  └─▶ 8_product_roadmap.md

Phase 4: Solution Design
  └─▶ 9_technical_requirements.md
  └─▶ 10_ux_copy_deck.md
  └─▶ 11_wireflow.md

Phase 5: Go-to-Market
  └─▶ 12_go_to_market.md
```

---

## The Iteration Cycle

### Visual Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ ITERATION START                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. READ STATE                                                   │
│     ├── specs/{feature}.json (find next task)                   │
│     ├── progress.txt (what happened before?)                    │
│     └── CLAUDE.md (project context)                             │
│                                                                  │
│  2. EXECUTE                                                      │
│     ├── Set task status: "in_progress"                          │
│     ├── Search codebase (don't assume missing)                  │
│     ├── Implement ONE task                                       │
│     └── Write tests if needed                                    │
│                                                                  │
│  3. VERIFY (Backpressure)                                       │
│     ├── pnpm test                                                │
│     ├── pnpm typecheck                                           │
│     └── Fix failures before continuing                           │
│                                                                  │
│  4. DOCUMENT                                                     │
│     ├── Update spec: passes: true, status: "complete"           │
│     ├── Append to progress.txt                                   │
│     └── Update CLAUDE.md with patterns                          │
│                                                                  │
│  5. COMMIT                                                       │
│     └── git add -A && git commit -m "feat(T-XXX): ..." && push  │
│                                                                  │
│  6. CHECK COMPLETION                                             │
│     ├── All tasks pass? → Output <ralph>COMPLETE</ralph> → EXIT │
│     └── More tasks? → END ITERATION → LOOP CONTINUES            │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│ ITERATION END                                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Sample progress.txt Entry

```
## Iteration 3 - 2024-01-15 14:32

### Task
- [x] T-003: Add auth middleware

### Decisions
- Placed in `src/middleware/auth.ts` following existing pattern
- Used existing `crypto.ts` for token verification
- Chose to throw 401 vs redirect—API should return JSON errors

### Files Changed
- src/middleware/auth.ts (new)
- src/middleware/index.ts (export)
- tests/middleware/auth.test.ts (new)

### Notes for Next Iteration
- Ready for T-004: Protect routes
- Consider rate limiting for auth endpoints
```

---

## Best Practices

### Writing Good Tasks

**Good tasks are:**

- Atomic (one thing)
- Verifiable (clear done/not-done)
- Right-sized (completable in one iteration)

| Bad                        | Good                                              |
| -------------------------- | ------------------------------------------------- |
| "Implement authentication" | "Create token generation utility"                 |
| "Fix bugs"                 | "Fix null pointer in UserCard component"          |
| "Add tests"                | "Add unit tests for auth.ts"                      |
| "Refactor code"            | "Extract validation logic to src/lib/validate.ts" |

### Writing Good Acceptance Criteria

**Bad** (vague):

```json
"acceptanceCriteria": ["Works correctly", "Is fast"]
```

**Good** (specific, testable):

```json
"acceptanceCriteria": [
  "Retry on HTTP 429, 500, 502, 503, 504",
  "Exponential backoff: 1s, 2s, 4s",
  "Add --max-retries flag (default: 3)",
  "Update --help text with new flag",
  "pnpm test passes"
]
```

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

| Discovery                              | Where to Put It               |
| -------------------------------------- | ----------------------------- |
| "This test is flaky"                   | progress.txt (immediate note) |
| "Always use `api.fetch` not raw fetch" | CLAUDE.md (permanent pattern) |
| "Item 5 depends on item 3"             | spec file (update dependsOn)  |

### When to Regenerate Specs

Regenerate (don't patch) when:

- Current approach isn't working after 3+ iterations
- Discovered codebase is structured differently than assumed
- Better approach became apparent
- Spec has too many amendments

---

## Advanced Usage

### Test Mode

Run a single iteration without pushing—ideal for validating prompts:

```bash
# Single iteration, no push, ignore completion marker
./ralph.sh --test
./ralph.sh -1                    # Short flag

# Combine with other options
./ralph.sh --test --model haiku  # Test with haiku
./ralph.sh --test --dry-run      # Preview test config
```

### Interactive Mode

Prompt for confirmation between iterations—great for learning or cautious sessions:

```bash
# Enable interactive mode
./ralph.sh --interactive
./ralph.sh -i                    # Short flag

# Set custom timeout (default: 300 seconds / 5 minutes)
./ralph.sh -i --interactive-timeout 60
```

When enabled, after each iteration Ralph will:
1. Display an iteration summary (duration, status, files changed)
2. Prompt: `Continue to next iteration? [Y/n/s]`
   - **Y** (or Enter): Continue to next iteration
   - **n**: Stop the session gracefully
   - **s**: Show git diff, then prompt again
3. Auto-continue after timeout

### Verbose Mode

Debug configuration and see where settings come from:

```bash
./ralph.sh --verbose
./ralph.sh -v                    # Short flag
./ralph.sh -v --dry-run          # Verbose dry run
```

Verbose mode shows:
- Configuration precedence (cli/env/config/default)
- Prompt preview (first 20 lines)
- Session state updates
- Retry logic decisions
- In launch mode, dry-run is read-only and does not archive branches or rewrite `progress.txt`.

### Session Resume

Resume interrupted sessions (Ctrl+C, network drop, laptop sleep):

```bash
# List all resumable sessions
./ralph.sh --list-sessions

# Resume the interrupted session
./ralph.sh --resume
```

Session state is saved to `.ralph-session.json` during execution. On successful completion, it's archived to `~/.ralph/logs/`. On interrupt or failure, it's preserved for resume.

### Retry Logic

Ralph automatically retries on transient failures:

```bash
# Disable automatic retry (fail immediately on errors)
./ralph.sh --no-retry

# Set custom max retries (default: 3)
./ralph.sh --max-retries 5
```

Retry uses exponential backoff (5s → 15s → 45s) for transient errors like rate limits (429), server errors (500, 502, 503, 504), and network issues. Fatal errors (auth failures, 401, 403) are not retried.

### Model Selection

| Model    | Speed   | Cost    | Best For                        |
| -------- | ------- | ------- | ------------------------------- |
| `opus`   | Slowest | Highest | Complex reasoning, architecture |
| `sonnet` | Medium  | Medium  | Standard implementation         |
| `haiku`  | Fastest | Lowest  | Simple fixes, documentation     |

```bash
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

### Webhook Notifications

Get notified when sessions complete:

```bash
# Send notifications to a webhook endpoint
./ralph.sh --notify-webhook "https://hooks.slack.com/services/xxx/yyy/zzz" build

# Or via environment variable
RALPH_NOTIFY_WEBHOOK="https://example.com/webhook" ./ralph.sh build
```

Webhooks send a JSON POST with:
- `event`: session_complete, session_max_iterations, session_interrupted
- `session_id`, `status`, `iterations`, `duration_seconds`
- `branch`, `mode`, `model`, `summary`, `last_commit`

### Structured JSON Logging

For log aggregation systems (ELK, Datadog, Splunk):

```bash
./ralph.sh --log-format json build
```

JSON log events include:
- `session_start`, `iteration_start`, `tool_call`, `iteration_end`, `error`, `session_end`
- Each with `timestamp`, `session_id`, `event`, `data`

### Session Summary Reports

Ralph auto-generates a markdown summary after each session:

```bash
# Summaries generated by default
./ralph.sh build

# Disable summary generation
./ralph.sh --no-summary build
```

Location: `~/.ralph/logs/{session_id}_summary.md`

Includes:
- Session overview (status, duration, iterations)
- Per-iteration table (duration, exit code, files, commit message)
- Files modified, commits made
- Troubleshooting section for failed sessions

### Custom Log Locations

```bash
# Use custom log directory
./ralph.sh --log-dir /path/to/logs build

# Use explicit log file path
./ralph.sh --log-file /path/to/session.log build
```

Default: `~/.ralph/logs/{mode}_{branch}_{timestamp}.log`

A symlink `~/.ralph/logs/latest.log` always points to the current session log.

### Branch Archiving

When you switch branches, Ralph automatically archives:

- Previous branch's spec file
- Previous branch's progress.txt
- Saved to `archive/YYYY-MM-DD-branch-name/`

This preserves history when context-switching between features.

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

### Shell Completion

Tab completion is available for bash and zsh:

**Bash:**
```bash
source completions/ralph.bash
# Or copy to /etc/bash_completion.d/ralph
```

**Zsh:**
```bash
fpath=(/path/to/ralph-starter/completions $fpath)
autoload -Uz compinit && compinit
```

---

## Troubleshooting

### "Error: Prompt file not found"

Ensure prompt files exist:

```bash
ls prompts/PROMPT_plan.md prompts/PROMPT_build.md prompts/PROMPT_spec.md
```

### Loop runs but no progress

Check that:

1. Spec file has tasks with `passes: false`
2. AI can understand the task (not too vague)
3. Tests aren't failing immediately

### Tests keep failing

The AI should fix failures, but if stuck:

1. Check progress.txt for what it tried
2. Run tests manually to understand failure
3. Consider simplifying the task

### AI keeps "searching" but not implementing

Common when tasks are too vague. Improve the task:

```json
// Bad
{
  "title": "Add authentication",
  "acceptanceCriteria": ["Auth works"]
}

// Good
{
  "title": "Create JWT token utility in src/lib/auth.ts",
  "acceptanceCriteria": [
    "generateToken(payload) returns signed JWT",
    "verifyToken(token) returns payload or throws",
    "pnpm typecheck passes"
  ]
}
```

### Session seems stuck

Check the log file:

```bash
tail -100 ~/.ralph/logs/latest.log | less
```

Look for:
- Rate limiting messages
- Error responses
- Repeated tool calls

### Completion signal not triggering

Verify:

1. ALL tasks have `passes: true`
2. Tests pass (`pnpm test`)
3. Type checks pass (`pnpm typecheck`)
4. The prompt includes the completion protocol

### Session was interrupted

Resume it:

```bash
./ralph.sh --list-sessions
./ralph.sh --resume
```

---

## Quick Reference

### Common Commands

```bash
# Help
./ralph.sh --help

# Spec mode (generate specs)
./ralph.sh spec -p "Add dark mode"       # From inline description
./ralph.sh spec -f ./requirements.md     # From requirements file
./ralph.sh spec --from-product           # From product artifacts
./ralph.sh spec -p "X" -o ./specs/x.json # Custom output path
./ralph.sh spec --force                  # Overwrite existing

# Launch mode (one-shot)
./ralph.sh launch -p "Build a Kanban board"      # Auto pipeline
./ralph.sh launch --full-product -p "Build CRM"  # Force product phase
./ralph.sh launch --skip-product -p "Quick MVP"  # Skip product phase
./ralph.sh launch --launch-buffer 8 -p "App"     # Increase build headroom

# Plan mode (optional human-readable view)
./ralph.sh plan                          # Default spec
./ralph.sh plan -s ./specs/feature.json  # Specific spec

# Build mode (implementation)
./ralph.sh                               # Build (default)
./ralph.sh build 10                      # Max 10 iterations
./ralph.sh build -s ./specs/feature.json # Specific spec

# Product mode (12 artifacts)
./ralph.sh product                       # Generate all artifacts
./ralph.sh product --context ./input/    # Custom input directory

# Model selection
./ralph.sh --model sonnet
./ralph.sh -m haiku

# Testing and debugging
./ralph.sh --test                        # Single iteration, no push
./ralph.sh --interactive                 # Confirm between iterations
./ralph.sh --verbose                     # Show detailed output
./ralph.sh --dry-run                     # Preview config
./ralph.sh launch --dry-run -p "Idea"    # Preview launch plan (read-only)

# Session management
./ralph.sh --resume                      # Resume interrupted session
./ralph.sh --list-sessions               # List resumable sessions

# Push and iteration control
./ralph.sh --no-push                     # Don't auto-push
./ralph.sh --unlimited                   # No iteration limit
./ralph.sh -n 50                         # Custom iteration limit

# Retry control
./ralph.sh --no-retry                    # Disable retry
./ralph.sh --max-retries 5               # Custom retry limit

# Logging
./ralph.sh --log-format json             # Structured logging
./ralph.sh --log-dir /custom/logs        # Custom log directory

# Notifications
./ralph.sh --notify-webhook "https://..." # Webhook on completion
```

### Key Files

| File                           | Purpose                                  |
| ------------------------------ | ---------------------------------------- |
| `ralph.sh`                     | Loop script                              |
| `ralph.conf`                   | Project configuration                    |
| `~/.ralph/config`              | Global configuration                     |
| `prompts/PROMPT_spec.md`       | Spec mode instructions                   |
| `prompts/PROMPT_plan.md`       | Plan mode instructions                   |
| `prompts/PROMPT_build.md`      | Build mode instructions                  |
| `prompts/PROMPT_product.md`    | Product mode instructions                |
| `specs/INDEX.md`               | Feature catalog                          |
| `specs/{feature}.json`         | Feature specification (source of truth)  |
| `plans/{feature}_PLAN.md`      | Human-readable plan (optional, derived)  |
| `progress.txt`                 | Iteration history                        |
| `CLAUDE.md`                    | Project context                          |
| `.ralph-session.json`          | Active session state                     |
| `~/.ralph/logs/latest.log`     | Current session log                      |

### Project Structure

```
project-root/
├── ralph.sh                      # The loop script
├── ralph.conf                    # Project configuration
├── CLAUDE.md                     # Project context
├── progress.txt                  # Iteration history
├── prompts/
│   ├── PROMPT_spec.md           # Spec generation instructions
│   ├── PROMPT_plan.md           # Planning mode instructions
│   ├── PROMPT_build.md          # Build mode instructions
│   └── PROMPT_product.md        # Product artifact generation
├── specs/
│   ├── INDEX.md                 # Feature catalog
│   └── {feature}.json           # JSON specs with tasks
├── plans/
│   └── {feature}_PLAN.md        # Human-readable plans (optional)
├── product-input/               # Product context files
├── product-output/              # Generated product artifacts
├── .claude/
│   └── skills/
│       └── writing-ralph-specs/ # Skill for creating JSON specs
├── archive/                     # Auto-archived branch state
├── docs/
│   ├── RALPH_LOOP_REF.md        # CLI reference
│   ├── RALPH_WORKSHOP.md        # This guide
│   └── PRODUCT_ARTIFACT_SPEC.md # Product artifact specifications
└── completions/
    ├── ralph.bash               # Bash completion
    └── ralph.zsh                # Zsh completion
```

### Exit Codes

| Code  | Meaning                                |
| ----- | -------------------------------------- |
| `0`   | Success—all tasks complete             |
| `1`   | Max iterations reached—work may remain |
| `130` | Interrupted (Ctrl+C)                   |

### The Golden Rules

1. **One task per iteration**
2. **Don't assume missing—search first**
3. **Tests are your rejection mechanism**
4. **Specs are the source of truth**
5. **Plans are optional and derived**
6. **Capture the why, not just the what**

---

## Next Steps

1. **Try spec mode**: `./ralph.sh spec -p "Add dark mode toggle"`
2. **Run build mode**: `./ralph.sh build -s ./specs/new-spec.json`
3. **Watch it work**: Use `--interactive` to see each iteration
4. **Iterate on specs**: Refine tasks as you learn what works

Happy automating!
