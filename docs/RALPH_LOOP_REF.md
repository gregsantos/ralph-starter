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
- **Session management**: Tracks iterations, duration, and saves full logs to `/tmp`

## Installation

The script is self-contained. Ensure you have:

- `claude` CLI installed and authenticated
- `jq` for JSON parsing
- `git` for version control operations

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
./ralph.sh -s ./specs/my-feature.md
# → Plan: ./plans/my-feature_PLAN.md (auto-derived from spec name)

# Override the derived plan if needed
./ralph.sh -s ./specs/my-feature.md -l ./plans/custom_PLAN.md build 5
```

### Dry Run

```bash
# Preview config without running Claude
./ralph.sh -s ./specs/my-feature.md --dry-run
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
| `inline` (-p) | sonnet        | Faster for quick, focused tasks              |
| `custom` (-f) | opus          | Assumes complex task unless specified        |

## Prompt Files

### Preset Prompts

The script looks for these files in the `prompts/` directory:

- `prompts/PROMPT_plan.md` - Planning and architecture tasks
- `prompts/PROMPT_build.md` - Implementation and coding tasks

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

Full session logs are saved to `/tmp/ralph_<mode>_<timestamp>.log`. These contain the raw JSON stream from Claude for debugging.

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

## Suggested Improvements

### Near-term

1. **Session Resume**: Add ability to resume interrupted sessions

   ```bash
   ./ralph.sh --resume <session-id>
   ```

2. **Progress Persistence**: Save iteration state to allow recovery after crashes

3. **Parallel Execution**: Run multiple independent tasks in parallel

```bash
./ralph.sh -f task1.md -f task2.md --parallel
```

### Medium-term

4. **Web Dashboard**: Real-time monitoring UI for long-running sessions

5. **Notification Hooks**: Send alerts on completion, errors, or specific events

6. **Template System**: Parameterized prompts with variable substitution

```bash
./ralph.sh -f templates/fix-issue.md --var issue=123
```

### Long-term

7. **Multi-Agent Orchestration**: Coordinate multiple Claude instances

8. **Learning Mode**: Capture successful patterns for future reference

9. **Integration with CI/CD**: Trigger ralph loops from GitHub Actions, etc.

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

Full session output is saved to `/tmp/ralph_<mode>_<timestamp>.log`:

```bash
# View recent logs
ls -la /tmp/ralph_*.log

# Tail a running session
tail -f /tmp/ralph_build_*.log

# Search for errors
grep -i error /tmp/ralph_build_*.log
```

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

Currently none. All configuration is via CLI arguments.

## Exit Codes

| Code | Meaning                                       |
| ---- | --------------------------------------------- |
| 0    | Success (completed all iterations)            |
| 1    | Error (invalid arguments, missing file, etc.) |
| 130  | Interrupted (Ctrl+C)                          |

## Template Variables

Prompts support these placeholders (automatically substituted):

| Variable            | Default                     | Description                              |
| ------------------- | --------------------------- | ---------------------------------------- |
| `{{SPEC_FILE}}`     | `./specs/{feature}.md`      | Feature specification (the "what & why") |
| `{{PLAN_FILE}}`     | `./plans/{feature}_PLAN.md` | Implementation checklist (the "how")     |
| `{{PROGRESS_FILE}}` | `progress.txt`              | Iteration history log                    |
| `{{SOURCE_DIR}}`    | `src/*`                     | Source code location                     |

## File Structure

```
project-root/
├── specs/
│   ├── INDEX.md                    # Feature catalog
│   └── {feature}.md                # Feature specs (the "what & why")
├── plans/
│   ├── IMPLEMENTATION_PLAN.md      # Default active plan (the "how")
│   └── {feature}_PLAN.md           # Feature-specific plans
├── prompts/
│   ├── PROMPT_plan.md              # Planning mode instructions
│   └── PROMPT_build.md             # Build mode instructions
├── archive/                        # Auto-archived branch state on branch change
├── ralph.sh                        # The loop script
├── ralph.conf                      # Optional configuration file
└── progress.txt                    # Iteration history
```

## Related Files

- `prompts/PROMPT_plan.md` - Planning mode prompt
- `prompts/PROMPT_build.md` - Build mode prompt
- `specs/INDEX.md` - Feature catalog
- `/tmp/ralph_*.log` - Session logs
