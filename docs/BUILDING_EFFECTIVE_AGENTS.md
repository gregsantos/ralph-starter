# Building Effective Agents

Resources and patterns for building robust AI-assisted development workflows.

## Recommended Reading

- [Building Efficient Agents: A Step-by-Step Guide](https://www.notion.so/building-efficient-agents-a-step-by-step-guide-351b2766770a47868904119930498909)
- [Building Agents with the Claude Agent SDK](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk)
- [Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)

## Key Principles

### 1. Fresh Context, File-Based Memory

Each iteration starts with zero memory of previous runs. State persists through files:

| File                           | Purpose                                  |
| ------------------------------ | ---------------------------------------- |
| `specs/{feature}.md`           | Feature specification (the "what & why") |
| `plans/IMPLEMENTATION_PLAN.md` | Task checklist (the "how")               |
| `progress.txt`                 | Append-only iteration history            |
| `CLAUDE.md`                    | Project context and discovered patterns  |

### 2. One Task Per Iteration

Breaking work into atomic, context-independent tasks prevents:

- Context overflow in long sessions
- Cascading errors from accumulated state
- Difficulty debugging when things go wrong

### 3. Quality Gates (Backpressure)

Tests and type checks serve as rejection mechanisms:

- Failed tests = change is wrong, not incomplete
- Never leave broken builds for the next iteration
- Fix failures before proceeding

### 4. Disposable Plans

Plans should be regenerated, not patched:

- If a plan becomes wrong or stale, start fresh
- A new plan with current understanding beats accumulated amendments
- Don't fight bad plans—replace them

### 5. Search Before Implementing

The codebase is more complete than you think:

- Always search before adding new functionality
- Reuse existing patterns and utilities
- Avoid duplicating what already exists

## Ralph Loop Implementation

Ralph Loop (`ralph.sh`) implements these principles:

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

### Two Modes

| Mode      | Purpose                            | When to Use                             |
| --------- | ---------------------------------- | --------------------------------------- |
| **Plan**  | Analyze codebase, create checklist | Starting features, investigating issues |
| **Build** | Execute tasks one at a time        | Implementing the plan                   |

### Completion Signal

When all tasks are complete, output:

```
<ralph>COMPLETE</ralph>
```

This tells the loop to exit successfully.

## Subagent Strategies

Effective use of subagents for parallel and specialized work:

| Task Type         | Strategy                                     |
| ----------------- | -------------------------------------------- |
| Reading/searching | Many parallel subagents (up to 500)          |
| Building/testing  | Single sequential subagent                   |
| Complex reasoning | Opus "Ultrathink" for architecture decisions |

## Anti-Patterns to Avoid

### 1. Trying to Complete Everything in One Session

- Leads to context overflow
- Quality degrades as context fills
- Hard to recover from errors

### 2. Vague Task Descriptions

```markdown
# Bad

- [ ] Add authentication

# Good

- [ ] Create JWT token utility in src/lib/auth.ts
- [ ] Add login endpoint POST /api/auth/login
```

### 3. Ignoring Test Failures

- Tests are your safety net
- Failing tests mean the implementation is wrong
- Never "fix later"—fix now

### 4. Patching Bad Plans

- Accumulated amendments create confusion
- Regenerate plans when approach changes
- Fresh understanding > incremental patches

## Related Documentation

- [RALPH_LOOP_REF.md](./RALPH_LOOP_REF.md) - Full CLI reference
- [RALPH_WORKSHOP.md](./RALPH_WORKSHOP.md) - Comprehensive workshop guide
- [specs/INDEX.md](../specs/INDEX.md) - Feature catalog conventions
