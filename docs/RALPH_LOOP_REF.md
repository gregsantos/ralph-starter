# Ralph Loop

Autonomous Claude Code runner for iterative development workflows.

## Overview

Ralph Loop (`ralph.sh`) is a bash script that runs Claude Code in headless mode, iterating through development tasks automatically. It's designed for autonomous coding sessions where Claude reads a prompt file and works through tasks, committing and pushing changes after each iteration.

## Features

- **Multiple prompt sources**: Named presets, custom files, or inline prompts
- **Model selection**: Choose between opus, sonnet, or haiku with smart defaults
- **Iteration limits**: Default 10 iterations to prevent runaway sessions (override with `--unlimited`)
- **Push control**: Enable or disable automatic git push after iterations
- **Clean logging**: Parses Claude's JSON output to show only relevant tool calls
- **Session management**: Tracks iterations, duration, and saves logs to `~/.ralph/logs/`
- **Session resume**: Resume interrupted sessions with `--resume`
- **Retry logic**: Automatic retry with exponential backoff for transient failures
- **Environment variables**: Configure via `RALPH_*` env vars for CI/CD
- **Global config**: User-wide defaults at `~/.ralph/config`
- **Safe config parsing**: Config files are parsed safely (no shell execution)

## Installation

The script is self-contained. Ensure you have:

- `claude` CLI installed and authenticated
- `jq` for JSON parsing
- `git` for version control operations

Ralph automatically runs pre-flight checks to verify these dependencies. Use `--skip-checks` to bypass if needed.

## Usage

### Basic Commands

```bash
# Default: build mode, opus, 10 iterations
./ralph.sh

# Plan mode (10 iterations default)
./ralph.sh plan

# Specify iterations
./ralph.sh build 5
./ralph.sh plan 3
./ralph.sh -n 20                    # Explicit max flag

# Unlimited iterations (use with caution!)
./ralph.sh --unlimited
./ralph.sh build --unlimited
```

### Custom Prompts

```bash
# Use a custom prompt file
./ralph.sh -f ./prompts/review.md
./ralph.sh --file ~/my-prompts/refactor.md

# Inline prompt (creates temp file)
./ralph.sh -p "Fix all TypeScript errors and run tests"
./ralph.sh --prompt "Add dark mode support to the settings page"
```

### Spec and Plan Files

```bash
# Use custom spec file (plan automatically derived)
./ralph.sh -s ./specs/my-feature.json
# → Plan: ./plans/my-feature_PLAN.md (auto-derived from spec name)

# Also works with markdown specs
./ralph.sh -s ./specs/my-feature.md
# → Plan: ./plans/my-feature_PLAN.md

# Override the derived plan if needed
./ralph.sh -s ./specs/my-feature.json -l ./plans/custom_PLAN.md build 5
```

### Pre-flight Checks

```bash
# Skip dependency checks (advanced users)
./ralph.sh --skip-checks build
```

### Session Resume

```bash
# Resume an interrupted session
./ralph.sh --resume

# List all resumable sessions
./ralph.sh --list-sessions
```

Session state is saved to `.ralph-session.json` during execution. On successful completion, it's archived to `~/.ralph/logs/`. On interrupt or failure, it's preserved for resume.

### Retry Logic

```bash
# Disable automatic retry (fail immediately on errors)
./ralph.sh --no-retry build

# Set custom max retries (default: 3)
./ralph.sh --max-retries 5 build
```

Retry uses exponential backoff (5s → 15s → 45s) for transient errors like rate limits (429), server errors (500, 502, 503, 504), and network issues. Fatal errors (auth failures, 401, 403) are not retried.

### Log Directory

```bash
# Use custom log directory
./ralph.sh --log-dir /path/to/logs build

# Use explicit log file path
./ralph.sh --log-file /path/to/session.log build
```

Default log location: `~/.ralph/logs/{mode}_{branch}_{timestamp}.log`

A symlink `~/.ralph/logs/latest.log` always points to the current session log.

### Global Config

```bash
# Use custom global config file
./ralph.sh --global-config ~/.config/ralph.conf build
```

Default global config: `~/.ralph/config` (loaded before project `ralph.conf`)

### Dry Run

```bash
# Preview config without running Claude
./ralph.sh -s ./specs/my-feature.md --dry-run
```

### Product Mode

```bash
# Generate product artifacts (default paths)
./ralph.sh product

# Custom product paths
./ralph.sh product --context ./my-context/ --output ./my-output/

# Custom artifact spec
./ralph.sh product --artifact-spec ./docs/MY_SPEC.md

# Combined options
./ralph.sh product --context ./input/ --output ./output/ --model sonnet 5
```

### Model Selection

```bash
# Override default model
./ralph.sh build --model sonnet
./ralph.sh -p "Quick fix" --model haiku
./ralph.sh -f complex-task.md --model opus
```

### Push Control

```bash
# Disable automatic push (useful for local experimentation)
./ralph.sh build --no-push

# Explicitly enable push (default behavior)
./ralph.sh plan --push
```

### Combined Options

```bash
# Custom file, sonnet model, 5 iterations, no push
./ralph.sh -f ./prompts/refactor.md --model sonnet --no-push 5

# Inline prompt with haiku, 3 iterations
./ralph.sh -p "Add unit tests for the auth module" --model haiku 3
```

## Model Defaults

| Mode          | Default Model | Rationale                                    |
| ------------- | ------------- | -------------------------------------------- |
| `plan`        | opus          | Complex reasoning for architecture decisions |
| `build`       | opus          | Quality implementation with full context     |
| `product`     | opus          | Comprehensive product artifact generation    |
| `inline` (-p) | sonnet        | Faster for quick, focused tasks              |
| `custom` (-f) | opus          | Assumes complex task unless specified        |

## Prompt Files

### Preset Prompts

The script looks for these files in the `prompts/` directory:

- `prompts/PROMPT_plan.md` - Planning and architecture tasks
- `prompts/PROMPT_build.md` - Implementation and coding tasks
- `prompts/PROMPT_product.md` - Product artifact generation

### Creating Custom Prompts

Create a markdown file with instructions for Claude:

```markdown
# Task: Review and Refactor

Review the authentication module for:

1. Security vulnerabilities
2. Code duplication
3. Missing error handling

For each issue found:

- Explain the problem
- Implement the fix
- Add tests if applicable

Run `pnpm test` and `pnpm typecheck` after changes.
```

## Output

### Terminal Output

The script displays:

- Session header with configuration
- Iteration markers with timestamps
- Tool calls (Read, Write, Edit, Bash, Task, etc.)
- Git status after each iteration
- Push status
- Session summary

Example:

```
╔════════════════════════════════════════════════════════════════╗
║                      RALPH LOOP                              ║
╚════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────┐
│ Mode     → build
│ Model    → opus
│ Prompt   → PROMPT_build.md
│ Branch   → feature/auth
│ Push     → enabled
│ Log      → /tmp/ralph_build_20260118_143632.log
└─────────────────────────────────────────┘

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚙ ITERATION 1  14:36:32
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  🔍 Read src/lib/auth.ts
  🔍 Glob src/**/*.test.ts
  ✎ Edit src/lib/auth.ts
  ⚙ 🧪 Running tests
  ⚙ ⎇ Committing

  ─────────────────────────────────────────
  Summary
     Tool calls: 5
     Files modified: 1
     🧪 Tests: ran
     ⎇ Commits made

  ⎇ Git Status
     1 staged
     Last commit: Fix auth token validation

  ✓ Pushed to feature/auth
  ✓ Iteration 1 complete (45s)
```

### Log Files

Full session logs are saved to `~/.ralph/logs/{mode}_{branch}_{timestamp}.log` by default. These contain the raw JSON stream from Claude for debugging.

A `latest.log` symlink in the log directory always points to the current/most recent session log for quick access.

## Architecture

```
ralph.sh
├── Argument parsing (presets, flags, positional args)
├── Prompt resolution (preset → file → inline)
├── Validation (file exists, valid model)
├── Main loop
│   ├── Run Claude with stream-json output
│   ├── Parse JSON → display tool calls
│   ├── Show git status
│   ├── Push changes (if enabled)
│   └── Increment iteration
└── Cleanup (temp files, summary)
```

### Key Components

1. **Argument Parser**: Handles short/long flags, presets, and positional arguments
2. **JSON Stream Parser**: Filters verbose Claude output to show only tool invocations
3. **Git Integration**: Automatic status checks, push with branch creation fallback
4. **Signal Handling**: Clean shutdown on Ctrl+C with session summary

## Future Improvements

### Near-term

1. **Parallel Execution**: Run multiple independent tasks in parallel

```bash
./ralph.sh -f task1.md -f task2.md --parallel
```

2. **Structured JSON Logging**: Machine-readable log format (LOG_FORMAT=json)

3. **Webhook Notifications**: Send alerts on completion, errors, or specific events

### Medium-term

4. **Web Dashboard**: Real-time monitoring UI for long-running sessions

5. **Template System**: Parameterized prompts with variable substitution

```bash
./ralph.sh -f templates/fix-issue.md --var issue=123
```

### Long-term

6. **Multi-Agent Orchestration**: Coordinate multiple Claude instances

7. **Learning Mode**: Capture successful patterns for future reference

## Troubleshooting

### "Error: Prompt file not found"

Ensure the prompt file exists at the specified path. For presets, check that `PROMPT_plan.md` or `PROMPT_build.md` exists in the project root.

### No tool calls showing

Check that `jq` is installed. The parser requires it for JSON processing:

```bash
brew install jq  # macOS
apt install jq   # Ubuntu/Debian
```

### Claude not running / 0 tool calls

The script requires `--verbose` with `--output-format=stream-json`. If you've modified the script, ensure both flags are present.

### Push failing

Check that:

- You have push access to the remote repository
- The branch exists or can be created
- Git is properly configured with credentials

### Viewing full logs

Full session output is saved to `~/.ralph/logs/`:

```bash
# View recent logs
ls -la ~/.ralph/logs/

# View the latest session log
tail -f ~/.ralph/logs/latest.log

# Search for errors in recent logs
grep -i error ~/.ralph/logs/*.log
```

### Session was interrupted

If your session was interrupted (Ctrl+C, network drop, laptop sleep), you can resume:

```bash
# Check if a session can be resumed
./ralph.sh --list-sessions

# Resume the interrupted session
./ralph.sh --resume
```

Note: The session file `.ralph-session.json` is preserved on interrupt. It's only archived after successful completion.

## Command Line Examples

### Quick Reference

```bash
# Show help
./ralph.sh --help
./ralph.sh -h

# Presets (default: 10 iterations)
./ralph.sh                    # Build mode, opus, 10 iterations
./ralph.sh plan               # Plan mode, opus, 10 iterations
./ralph.sh build 5            # Build mode, 5 iterations
./ralph.sh plan 3             # Plan mode, 3 iterations
./ralph.sh -n 20              # Explicit max iterations
./ralph.sh --unlimited        # Remove limit (careful!)

# Custom files
./ralph.sh -f prompts/review.md
./ralph.sh --file ./tasks/refactor-auth.md
./ralph.sh -f ~/global-prompts/security-audit.md 3

# Inline prompts
./ralph.sh -p "Fix the failing tests"
./ralph.sh --prompt "Add error handling to all API routes"
./ralph.sh -p "Refactor duplicate code in src/lib" 2

# Model selection
./ralph.sh --model sonnet                    # Faster, cheaper
./ralph.sh --model haiku                     # Fastest, cheapest
./ralph.sh --model opus                      # Most capable (default)
./ralph.sh -m sonnet                         # Short flag

# Push control
./ralph.sh --no-push                         # Don't push changes
./ralph.sh build --no-push 5                 # Local only, 5 iterations
./ralph.sh --push                            # Explicit push (default)

# Session management
./ralph.sh --resume                          # Resume interrupted session
./ralph.sh --list-sessions                   # List resumable sessions

# Retry control
./ralph.sh --no-retry                        # Disable automatic retry
./ralph.sh --max-retries 5                   # Custom retry limit (default: 3)

# Logging
./ralph.sh --log-dir /custom/logs            # Custom log directory
./ralph.sh --log-file /path/to/session.log   # Explicit log file

# Configuration
./ralph.sh --global-config ~/.config/ralph   # Custom global config
./ralph.sh --skip-checks                     # Skip pre-flight checks
./ralph.sh --dry-run                         # Preview config, don't run

# Combined examples
./ralph.sh build --model sonnet --no-push 3
./ralph.sh -f review.md -m haiku 10
./ralph.sh -p "Add tests" --model sonnet --no-push 1
./ralph.sh plan --model opus 5
```

### Common Workflows

```bash
# Quick bug fix (fast model, single iteration, no push)
./ralph.sh -p "Fix the null pointer in UserCard component" --model haiku --no-push 1

# Code review (custom prompt, multiple passes)
./ralph.sh -f prompts/code-review.md --model sonnet 3

# Architecture planning (opus for complex reasoning)
./ralph.sh plan --model opus 2

# Continuous development (build mode, auto-push)
./ralph.sh build 20

# Local experimentation (no push, unlimited)
./ralph.sh build --no-push

# Security audit (thorough, no auto-push for review)
./ralph.sh -f prompts/security-audit.md --model opus --no-push

# Quick refactor (inline, fast)
./ralph.sh -p "Extract the validation logic into a separate utility" --model sonnet 1

# Test writing session
./ralph.sh -p "Add comprehensive tests for src/lib/storage.ts" --model sonnet 5

# Documentation pass
./ralph.sh -p "Add JSDoc comments to all exported functions in src/lib" --model haiku 3
```

### Running in Background

```bash
# Run with nohup for long sessions
nohup ./ralph.sh build 50 > ralph_output.log 2>&1 &

# Check progress
tail -f ralph_output.log

# Or use screen/tmux
screen -S ralph
./ralph.sh build 100
# Ctrl+A, D to detach
# screen -r ralph to reattach
```

## Environment Variables

Ralph supports environment variables for CI/CD integration and user defaults. Precedence: CLI > env var > config file > defaults.

| Variable               | Description                             | Example                       |
| ---------------------- | --------------------------------------- | ----------------------------- |
| `RALPH_MODEL`          | Default model (opus, sonnet, haiku)     | `RALPH_MODEL=sonnet`          |
| `RALPH_MAX_ITERATIONS` | Maximum iterations limit                | `RALPH_MAX_ITERATIONS=20`     |
| `RALPH_PUSH_ENABLED`   | Git push toggle (true/false/yes/no/1/0) | `RALPH_PUSH_ENABLED=false`    |
| `RALPH_SPEC_FILE`      | Path to spec file                       | `RALPH_SPEC_FILE=./spec.json` |
| `RALPH_PLAN_FILE`      | Path to plan file                       | `RALPH_PLAN_FILE=./plan.md`   |
| `RALPH_PROGRESS_FILE`  | Path to progress file                   | `RALPH_PROGRESS_FILE=log.txt` |
| `RALPH_LOG_DIR`        | Log directory path                      | `RALPH_LOG_DIR=/tmp/logs`     |
| `RALPH_LOG_FORMAT`     | Log format (text/json) - future use     | `RALPH_LOG_FORMAT=json`       |
| `RALPH_NOTIFY_WEBHOOK` | Webhook URL for notifications - future  | `RALPH_NOTIFY_WEBHOOK=...`    |

### Example: CI/CD Usage

```bash
# GitHub Actions example
RALPH_MODEL=sonnet \
RALPH_MAX_ITERATIONS=5 \
RALPH_PUSH_ENABLED=false \
./ralph.sh build
```

## Exit Codes

| Code | Meaning                                                        |
| ---- | -------------------------------------------------------------- |
| 0    | Task complete (`<ralph>COMPLETE</ralph>` marker detected)      |
| 1    | Max iterations reached (check progress.txt for remaining work) |
| 130  | Interrupted (Ctrl+C)                                           |

## Template Variables

Prompts support these placeholders (automatically substituted):

### Build/Plan Mode

| Variable            | Default                          | Description                              |
| ------------------- | -------------------------------- | ---------------------------------------- |
| `{{SPEC_FILE}}`     | `./specs/IMPLEMENTATION_PLAN.md` | Feature specification (the "what & why") |
| `{{PLAN_FILE}}`     | `./plans/IMPLEMENTATION_PLAN.md` | Implementation checklist (the "how")     |
| `{{PROGRESS_FILE}}` | `progress.txt`                   | Iteration history log                    |
| `{{SOURCE_DIR}}`    | `src/*`                          | Source code location                     |

### Product Mode

| Variable                  | Default                           | Description                       |
| ------------------------- | --------------------------------- | --------------------------------- |
| `{{PRODUCT_CONTEXT_DIR}}` | `./product-input/`                | Product context/input directory   |
| `{{PRODUCT_OUTPUT_DIR}}`  | `./product-output/`               | Product artifact output directory |
| `{{ARTIFACT_SPEC_FILE}}`  | `./docs/PRODUCT_ARTIFACT_SPEC.md` | Artifact specification file       |
| `{{PROGRESS_FILE}}`       | `progress.txt`                    | Iteration history log             |

## Configuration File

Ralph supports configuration files for default settings. Configuration precedence: CLI > environment variables > project config > global config > defaults.

### Config File Locations

1. **Global config**: `~/.ralph/config` (user-wide defaults)
2. **Project config**: `./ralph.conf` (project-specific overrides)

Use `--global-config PATH` to specify an alternate global config location.

### Example `ralph.conf`

```bash
# Ralph Loop Configuration
# Use standard KEY=VALUE syntax (no shell execution for security)

# Path Configuration
SPEC_FILE=./specs/IMPLEMENTATION_PLAN.md
PLAN_FILE=./plans/IMPLEMENTATION_PLAN.md
ARTIFACT_SPEC_FILE=./docs/PRODUCT_ARTIFACT_SPEC.md
PROGRESS_FILE=progress.txt
SOURCE_DIR=src/*

# Execution Settings
MODEL=opus
MAX_ITERATIONS=10
PUSH_ENABLED=true

# Logging
LOG_DIR=~/.ralph/logs
```

### Supported Settings

| Setting              | Description                                  | Default                           |
| -------------------- | -------------------------------------------- | --------------------------------- |
| `SPEC_FILE`          | Path to feature specification                | `./specs/IMPLEMENTATION_PLAN.md`  |
| `PLAN_FILE`          | Path to implementation checklist             | `./plans/IMPLEMENTATION_PLAN.md`  |
| `ARTIFACT_SPEC_FILE` | Path to product artifact spec (product mode) | `./docs/PRODUCT_ARTIFACT_SPEC.md` |
| `PROGRESS_FILE`      | Path to iteration history log                | `progress.txt`                    |
| `SOURCE_DIR`         | Source code directory                        | `src/*`                           |
| `MODEL`              | Default model (opus, sonnet, haiku)          | varies by mode                    |
| `MAX_ITERATIONS`     | Maximum iterations limit                     | `10`                              |
| `PUSH_ENABLED`       | Auto-push after iterations                   | `true`                            |
| `LOG_DIR`            | Log file directory                           | `~/.ralph/logs`                   |
| `LOG_FORMAT`         | Log format (text/json) - future              | `text`                            |
| `NOTIFY_WEBHOOK`     | Notification webhook URL - future            | (none)                            |

### Security

Config files are parsed safely using a whitelist approach:

- Only allowed keys are accepted (unknown keys trigger warnings)
- Values are type-validated (e.g., MODEL must be opus/sonnet/haiku)
- Shell command patterns (`$()`, backticks, `&&`, `||`, `;`) are rejected
- No arbitrary code execution from config files

## Branch-Change Archiving

When you switch git branches, Ralph automatically archives the previous branch's state:

- Copies spec, plan, and progress files to `archive/YYYY-MM-DD-branchname/`
- Resets `progress.txt` for the new branch
- Preserves work context for when you return to the branch

This prevents confusion when working on multiple features and ensures iteration history is branch-specific.

## File Structure

### Project Files

```
project-root/
├── product-input/                  # Product context files (Step 0)
│   ├── vision.md                   # Product vision and goals
│   ├── research.md                 # User research, market data
│   └── requirements.md             # High-level requirements
├── product-output/                 # Generated product artifacts (Step 0)
│   ├── 1_executive_summary.md
│   ├── 7_prd.md                    # Use to inform specs
│   └── ... (12 total)
├── specs/                          # Feature specifications (Step 1)
│   ├── INDEX.md                    # Feature catalog
│   ├── {feature}.json              # JSON specs (recommended)
│   └── {feature}.md                # Markdown specs (alternative)
├── plans/                          # Implementation checklists (Step 2)
│   ├── IMPLEMENTATION_PLAN.md      # Default active plan
│   └── {feature}_PLAN.md           # Feature-specific plans
├── prompts/
│   ├── PROMPT_plan.md              # Planning mode instructions
│   ├── PROMPT_build.md             # Build mode instructions
│   └── PROMPT_product.md           # Product artifact generation
├── docs/
│   └── PRODUCT_ARTIFACT_SPEC.md    # Product artifact specifications
├── .claude/
│   └── skills/
│       └── writing-ralph-specs/    # Skill for creating JSON specs
├── archive/                        # Auto-archived branch state on branch change
├── ralph.sh                        # The loop script
├── ralph.conf                      # Project configuration file
├── .ralph-session.json             # Active session state (gitignored)
└── progress.txt                    # Iteration history
```

### User Files

```
~/.ralph/
├── config                          # Global configuration file
└── logs/
    ├── latest.log                  # Symlink to current session
    ├── {session_id}_session.json   # Archived session states
    └── {mode}_{branch}_{ts}.log    # Session logs
```

## Complete Workflow: Product → Spec → Plan → Build

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

For new projects or major features, start with product mode:

```bash
# 1. Add context files to product-input/
mkdir -p product-input
# Add: vision.md, research.md, requirements.md, competitive-analysis.md, etc.

# 2. Run product mode to generate 12 structured artifacts
./ralph.sh product
#    → product-output/1_executive_summary.md
#    → product-output/2_charter.md
#    → product-output/3_market_analysis.md
#    → product-output/4_personas.md
#    → product-output/5_journey_map.md
#    → product-output/6_positioning.md
#    → product-output/7_prd.md              ← Use this to inform your spec
#    → product-output/8_product_roadmap.md
#    → product-output/9_solution_architecture.md
#    → product-output/10_metrics_framework.md
#    → product-output/11_risk_assessment.md
#    → product-output/12_go_to_market.md

# 3. Review artifacts, especially 7_prd.md, to inform spec creation
```

See `docs/PRODUCT_ARTIFACT_SPEC.md` for full artifact specifications.

### Step 1: Create a Spec

Use insights from product artifacts (or create directly for smaller features):

```bash
# Create a JSON spec with user stories and acceptance criteria
# (use the writing-ralph-specs skill or create manually)
#    → specs/my-feature.json

# Example minimal spec:
cat > specs/my-feature.json << 'EOF'
{
  "project": "My Feature",
  "branchName": "feature/my-feature",
  "description": "Feature description from PRD",
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
EOF
```

### Step 2: Run Plan Mode

Plan mode analyzes the spec and codebase, then creates a task checklist:

```bash
./ralph.sh plan -s ./specs/my-feature.json
#    → plans/my-feature_PLAN.md (auto-derived from spec name)
```

### Step 3: Run Build Mode

Build mode executes the plan one task at a time:

```bash
./ralph.sh build -s ./specs/my-feature.json
#    → Implementation complete
#    → spec.passes updated to true for completed stories
```

### Quick Reference Commands

```bash
# Full workflow from product discovery to implementation
./ralph.sh product                           # Step 0: Generate product artifacts
# (manually create spec from product output)  # Step 1: Create spec
./ralph.sh plan -s ./specs/my-feature.json   # Step 2: Create plan
./ralph.sh build -s ./specs/my-feature.json  # Step 3: Execute plan

# Skip product mode for smaller features
./ralph.sh plan -s ./specs/my-feature.json   # Create plan from existing spec
./ralph.sh build -s ./specs/my-feature.json  # Execute plan
```

JSON specs provide structured user stories with acceptance criteria that plan mode uses to create detailed checklists. Build mode updates the `passes` field in each user story when all acceptance criteria are met, providing story-level completion tracking.

See `specs/ralph-improvements.json` for a comprehensive spec example.

## Related Files

### Prompts

- `prompts/PROMPT_plan.md` - Planning mode prompt
- `prompts/PROMPT_build.md` - Build mode prompt
- `prompts/PROMPT_product.md` - Product artifact generation prompt

### Product Mode

- `product-input/` - Context files for product discovery (vision, research, requirements)
- `product-output/` - Generated product artifacts (12 documents)
- `docs/PRODUCT_ARTIFACT_SPEC.md` - Artifact specifications

### Specs & Plans

- `specs/INDEX.md` - Feature catalog
- `specs/*.json` - JSON specs (recommended)
- `plans/*_PLAN.md` - Implementation checklists
- `.claude/skills/writing-ralph-specs/` - Skill for creating JSON specs

### Configuration

- `ralph.conf` - Project configuration file
- `~/.ralph/config` - Global configuration file

### Session & Logs

- `~/.ralph/logs/` - Session logs directory
- `~/.ralph/logs/latest.log` - Symlink to current session log
- `.ralph-session.json` - Active session state (preserved on interrupt)
