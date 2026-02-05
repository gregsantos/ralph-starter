---
name: writing-ralph-specs
description: Creates structured JSON specifications for Ralph Loop autonomous execution. Use when creating feature specs, PRDs, improvement plans, or task lists for the spec → build workflow. Triggers on "create a spec", "plan this feature", "write a PRD", "spec out", or when features need implementation planning.
---

# Writing Ralph Specs

Create JSON specs in `specs/` for autonomous execution via `./ralph.sh build`. Plan mode is optional for generating human-readable views.

## Tasks Array Schema (Recommended)

The `tasks` array is the recommended format for specs. Each task is an atomic unit of work that build mode can execute.

### Task Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier (e.g., "T-001") |
| `title` | string | Yes | Short action title |
| `description` | string | Yes | What needs to be done |
| `acceptanceCriteria` | string[] | Yes | Specific, testable criteria |
| `dependsOn` | string[] | Yes | Array of task IDs this depends on (empty if none) |
| `status` | string | Yes | One of: `pending`, `in_progress`, `complete`, `blocked` |
| `passes` | boolean | Yes | `false` initially; `true` when all criteria met |
| `effort` | string | Yes | One of: `small`, `medium`, `large` |
| `notes` | string | No | Implementation notes (populated by build mode) |
| `phase` | string | No | Phase ID if using phases |

### Status Values

- **pending**: Task not started, waiting for dependencies
- **in_progress**: Currently being worked on (only one at a time)
- **complete**: All acceptance criteria met, `passes: true`
- **blocked**: Cannot proceed due to external factors

### Example Spec with Tasks

```json
{
  "project": "Feature Name",
  "branchName": "feature/branch-name",
  "description": "One-line description",
  "context": {
    "currentState": "What exists today",
    "targetState": "What we want to achieve",
    "constraints": ["Constraint 1"],
    "verificationCommands": ["pnpm test", "pnpm typecheck"]
  },
  "tasks": [
    {
      "id": "T-001",
      "title": "Set up infrastructure",
      "description": "Configure the base infrastructure for the feature",
      "acceptanceCriteria": [
        "Install required dependencies",
        "Add configuration to project",
        "pnpm typecheck passes"
      ],
      "dependsOn": [],
      "status": "pending",
      "passes": false,
      "effort": "small",
      "notes": ""
    },
    {
      "id": "T-002",
      "title": "Implement core functionality",
      "description": "Build the main feature on top of infrastructure",
      "acceptanceCriteria": [
        "Feature works as specified",
        "Tests added and passing",
        "pnpm test passes"
      ],
      "dependsOn": ["T-001"],
      "status": "pending",
      "passes": false,
      "effort": "medium",
      "notes": ""
    }
  ]
}
```

**Optional fields**: `version`, `phases`, `milestones`, `glossary`, `dependencies` (top-level map for complex specs).

---

## Legacy: userStories Array

The `userStories` format is still supported for backward compatibility. New specs should use `tasks`.

```json
{
  "userStories": [
    {
      "id": "US-001",
      "title": "Short action title",
      "description": "As a [role], I want [feature] so that [benefit].",
      "acceptanceCriteria": ["Specific, testable criterion"],
      "priority": 1,
      "effort": "small|medium|large",
      "passes": false
    }
  ],
  "dependencies": {"US-002": ["US-001"]}
}
```

## Acceptance Criteria Guidelines

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
  "Update docs/RALPH_LOOP_REF.md with retry section",
  "pnpm test passes"
]
```

**Include documentation** for user-facing features:

- CLI flags → `--help` text + `docs/RALPH_LOOP_REF.md`
- Workflow changes → `README.md`
- Config options → `ralph.conf` comments + reference docs

## Complete Example (Tasks Format)

```json
{
  "project": "Dark Mode",
  "branchName": "feature/dark-mode",
  "description": "Add dark mode toggle",
  "context": {
    "currentState": "Light theme only",
    "targetState": "Toggle between light/dark themes",
    "verificationCommands": ["pnpm typecheck"]
  },
  "tasks": [
    {
      "id": "T-001",
      "title": "Configure next-themes",
      "description": "Set up theme infrastructure with next-themes package",
      "acceptanceCriteria": [
        "Install next-themes",
        "Add ThemeProvider to layout",
        "pnpm typecheck passes"
      ],
      "dependsOn": [],
      "status": "pending",
      "passes": false,
      "effort": "small",
      "notes": ""
    },
    {
      "id": "T-002",
      "title": "Add theme toggle component",
      "description": "Create component to switch between light/dark/system themes",
      "acceptanceCriteria": [
        "ThemeToggle component toggles light/dark/system",
        "Add to header",
        "pnpm typecheck passes"
      ],
      "dependsOn": ["T-001"],
      "status": "pending",
      "passes": false,
      "effort": "small",
      "notes": ""
    }
  ]
}
```

## Workflow

```bash
# 1. Create spec (manual or via spec mode)
./ralph.sh spec -p "Add dark mode toggle"
#    → specs/dark-mode.json

# 2. (Optional) Plan mode generates readable view
./ralph.sh plan -s ./specs/dark-mode.json

# 3. Build mode executes tasks directly from spec
./ralph.sh build -s ./specs/dark-mode.json
```

## Tips

- **Atomic tasks**: Completable in 1-2 iterations
- **Testable criteria**: Include verification commands
- **Include doc updates**: Add documentation criteria for user-facing features (--help, README, reference docs)
- **Use dependsOn**: `"dependsOn": ["T-001"]` means task depends on T-001 completion
- **Update INDEX.md**: Add entry to `specs/INDEX.md`
- **passes field**: Initialize as `false`; build mode sets to `true` when all criteria met
- **status field**: Build mode sets to `in_progress` when starting, `complete` when done

## Reference

- `specs/example-tasks.json` - Simple example showing all task fields and dependencies
- `specs/unified-spec-workflow.json` - Comprehensive multi-phase example with phases, milestones, and task dependencies
