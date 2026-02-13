# Feature Specifications Index

Source of truth for all system capabilities and planned features.

## Completed

| Feature         | Spec                                                 | Status   | Plan                                                              | Description                                            |
| --------------- | ---------------------------------------------------- | -------- | ----------------------------------------------------------------- | ------------------------------------------------------ |
| Ralph Loop v2.0 | [ralph-improvements.json](./ralph-improvements.json) | Complete | [ralph-improvements_PLAN.md](../plans/ralph-improvements_PLAN.md) | Resilience, observability, config, and DX improvements |

## Examples

| Feature              | Spec                                         | Description                                              |
| -------------------- | -------------------------------------------- | -------------------------------------------------------- |
| Example Tasks Format | [example-tasks.json](./example-tasks.json)   | Reference example showing all task fields and dependencies |

## Active Development

| Feature               | Spec                                                             | Status      | Plan                                                                    | Description                                                |
| --------------------- | ---------------------------------------------------------------- | ----------- | ----------------------------------------------------------------------- | ---------------------------------------------------------- |
| Launch E2E Verification | [create-a-tiny-docs-only-improvement-to-verify-launch-e2e-flow.json](./create-a-tiny-docs-only-improvement-to-verify-launch-e2e-flow.json) | In Progress | — | Docs-only improvement: enhance launch mode examples and guidance |
| Unified Spec Workflow | [unified-spec-workflow.json](./unified-spec-workflow.json)       | In Progress | [unified-spec-workflow_PLAN.md](../plans/unified-spec-workflow_PLAN.md) | Add spec mode, eliminate plan requirement, tasks in specs  |

## Planned

| Feature | Spec | Priority | Description |
| ------- | ---- | -------- | ----------- |
|         |      |          |             |

## Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                     RECOMMENDED WORKFLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. SPEC MODE          2. BUILD MODE         3. PLAN MODE       │
│  (Generate spec)       (Implement tasks)     (Optional view)    │
│                                                                 │
│  ./ralph.sh spec       ./ralph.sh build      ./ralph.sh plan    │
│    -p "Feature"          -s spec.json          -s spec.json     │
│    -f requirements.md                                           │
│    --from-product                                               │
│         │                    │                     │            │
│         ▼                    ▼                     ▼            │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐     │
│  │ spec.json   │  ──▶ │  Code +     │      │ PLAN.md     │     │
│  │ (tasks)     │      │  Tests      │      │ (read-only) │     │
│  └─────────────┘      └─────────────┘      └─────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Key insight**: Specs with tasks are the single source of truth. Build mode works directly from the spec. Plan mode is optional for generating human-readable views.

## Conventions

### Spec Files (`specs/`)

- **Purpose**: Requirements, architecture, rationale ("what & why") + tasks (single source of truth)
- **Lifecycle**: Semi-permanent, evolves with product
- **Format**: JSON (recommended) or Markdown
  - **JSON with tasks**: Structured with tasks array, acceptance criteria, dependencies (recommended)
  - **JSON with userStories**: Legacy format, requires plan mode to generate checklist
  - **Markdown**: Prose requirements, architecture docs
- **When to create**: Major features needing stable reference documentation
- **How to create**: Use spec mode (`./ralph.sh spec`) or `writing-ralph-specs` skill

### Spec Formats: Tasks vs userStories

| Format         | Primary Use             | Build Mode Workflow          | Recommended |
| -------------- | ----------------------- | ---------------------------- | ----------- |
| **tasks**      | New specs               | Works directly from spec     | ✅ Yes       |
| **userStories**| Backward compatibility  | Requires plan mode checklist | Legacy      |

**Tasks format** (recommended):
```json
{
  "tasks": [
    {
      "id": "T-001",
      "title": "Add feature X",
      "description": "Detailed description",
      "acceptanceCriteria": ["Criterion 1", "Criterion 2"],
      "dependsOn": [],
      "status": "pending",
      "passes": false,
      "effort": "medium",
      "notes": ""
    }
  ]
}
```

**userStories format** (legacy):
```json
{
  "userStories": [
    {
      "id": "US-001",
      "story": "As a user, I want...",
      "acceptanceCriteria": ["..."],
      "passes": false
    }
  ]
}
```

### Plan Files (`plans/`)

- **Purpose**: Human-readable implementation view (optional for specs with tasks)
- **Lifecycle**: Disposable, regenerate when stale; derived view for specs with tasks
- **Format**: Markdown with `[ ]`/`[x]` checklist items
- **Location**: `plans/{feature}_PLAN.md` or `plans/IMPLEMENTATION_PLAN.md` (default)
- **Note**: When using specs with tasks, the plan is a read-only derived view. Edit the spec, not the plan.

### When to Create Separate Files

| Scenario          | Spec (with tasks) | Plan       | Notes                                              |
| ----------------- | ----------------- | ---------- | -------------------------------------------------- |
| Major feature     | Yes               | Optional   | Spec with tasks is sufficient; plan for visibility |
| Small enhancement | Yes               | No         | Use spec mode with `-p "Add X"`                    |
| Bug fix           | No                | No         | Use inline prompt (`-p "Fix X"`)                   |
| Refactoring       | Optional          | No         | Depends on scope                                   |

### Template Variables

| Variable            | Default                          | Mode(s)      | Purpose                       |
| ------------------- | -------------------------------- | ------------ | ----------------------------- |
| `{{SPEC_FILE}}`     | `./specs/IMPLEMENTATION_PLAN.md` | plan, build  | Feature specification         |
| `{{PLAN_FILE}}`     | `./plans/IMPLEMENTATION_PLAN.md` | plan, build  | Implementation checklist      |
| `{{PROGRESS_FILE}}` | `progress.txt`                   | all          | Iteration history             |
| `{{SOURCE_DIR}}`    | `src/*`                          | all          | Source code location          |
| `{{INPUT_SOURCE}}`  | (from -p, -f, or --from-product) | spec         | Input for spec generation     |
| `{{OUTPUT_FILE}}`   | `specs/new-spec.json`            | spec         | Output path for generated spec|

## File Organization

```
project-root/
├── specs/
│   ├── INDEX.md              # This file - feature catalog
│   ├── {feature}.json        # JSON spec with tasks (recommended)
│   └── {feature}.md          # Markdown spec (alternative)
├── plans/
│   └── {feature}_PLAN.md     # Optional human-readable view
├── prompts/
│   ├── PROMPT_spec.md         # Generates spec from input
│   ├── PROMPT_plan.md         # Generates plan (optional, derived view)
│   └── PROMPT_build.md        # Executes tasks from spec
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
