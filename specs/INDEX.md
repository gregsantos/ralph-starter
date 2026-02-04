# Feature Specifications Index

Source of truth for all system capabilities and planned features.

## Active Development

| Feature         | Spec                                                 | Status      | Plan                                                              | Description                                            |
| --------------- | ---------------------------------------------------- | ----------- | ----------------------------------------------------------------- | ------------------------------------------------------ |
| Ralph Loop v2.0 | [ralph-improvements.json](./ralph-improvements.json) | In Progress | [ralph-improvements_PLAN.md](../plans/ralph-improvements_PLAN.md) | Resilience, observability, config, and DX improvements |

## Planned

| Feature | Spec | Priority | Description |
| ------- | ---- | -------- | ----------- |
|         |      |          |             |

## Conventions

### Spec Files (`specs/`)

- **Purpose**: Requirements, architecture, rationale ("what & why")
- **Lifecycle**: Semi-permanent, evolves with product
- **Format**: JSON (recommended) or Markdown
  - **JSON**: Structured with user stories, acceptance criteria, dependencies
  - **Markdown**: Prose requirements, architecture docs
- **When to create**: Major features needing stable reference documentation
- **Skill**: Use `writing-ralph-specs` skill to create JSON specs (see `.claude/skills/`)

### Plan Files (`plans/`)

- **Purpose**: Implementation checklist ("how")
- **Lifecycle**: Disposable, regenerate when stale
- **Format**: Markdown with `[ ]`/`[x]` checklist items
- **Location**: `plans/{feature}_PLAN.md` or `plans/IMPLEMENTATION_PLAN.md` (default)

### When to Create Separate Files

| Scenario          | Spec     | Plan | Notes                                                   |
| ----------------- | -------- | ---- | ------------------------------------------------------- |
| Major feature     | Yes      | Yes  | Full separation: spec for reference, plan for checklist |
| Small enhancement | Optional | Yes  | Plan may be sufficient                                  |
| Bug fix           | No       | No   | Use inline prompt (`-p "Fix X"`)                        |
| Refactoring       | Optional | Yes  | Depends on scope                                        |

### Template Variables

| Variable            | Default                          | Purpose                  |
| ------------------- | -------------------------------- | ------------------------ |
| `{{SPEC_FILE}}`     | `./specs/IMPLEMENTATION_PLAN.md` | Feature specification    |
| `{{PLAN_FILE}}`     | `./plans/IMPLEMENTATION_PLAN.md` | Implementation checklist |
| `{{PROGRESS_FILE}}` | `progress.txt`                   | Iteration history        |
| `{{SOURCE_DIR}}`    | `src/*`                          | Source code location     |

## File Organization

```
project-root/
├── specs/
│   ├── INDEX.md              # This file - feature catalog
│   ├── {feature}.json        # JSON spec (recommended)
│   └── {feature}.md          # Markdown spec (alternative)
├── plans/
│   └── IMPLEMENTATION_PLAN.md # Default active plan (the "how")
├── prompts/
│   ├── PROMPT_plan.md         # Reads spec → generates plan
│   └── PROMPT_build.md        # Reads plan → executes checklist
├── .claude/
│   └── skills/
│       └── writing-ralph-specs/ # Skill for creating JSON specs
├── ralph.sh                   # Ralph Loop script
├── ralph.conf                 # Ralph Loop configuration
└── progress.txt               # Iteration history
```

## Related Resources

- **CLAUDE.md**: Project context and codebase patterns
- **progress.txt**: Append-only iteration history
- **archive/**: Previous branch specs and progress
- **docs/RALPH_LOOP_REF.md**: Full CLI reference
- **docs/RALPH_WORKSHOP.md**: Ralph Loop workshop guide
- **.claude/skills/writing-ralph-specs/**: Skill for creating JSON specs
