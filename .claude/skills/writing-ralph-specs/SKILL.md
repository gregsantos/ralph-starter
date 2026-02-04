---
name: writing-ralph-specs
description: Creates structured JSON specifications for Ralph Loop autonomous execution. Use when creating feature specs, PRDs, improvement plans, or task lists for the spec → plan → build workflow. Triggers on "create a spec", "plan this feature", "write a PRD", "spec out", or when features need implementation planning.
---

# Writing Ralph Specs

Create JSON specs in `specs/` for autonomous execution via `./ralph.sh plan` → `./ralph.sh build`.

## Spec Structure

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

**Optional fields**: `version`, `phases`, `milestones`, `glossary`, `implementation` hints per story.

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
  "pnpm test passes"
]
```

## Example Spec

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
  "userStories": [
    {
      "id": "US-001",
      "title": "Configure next-themes",
      "description": "As a developer, I need theme infrastructure.",
      "acceptanceCriteria": [
        "Install next-themes",
        "Add ThemeProvider to layout",
        "pnpm typecheck passes"
      ],
      "priority": 1,
      "effort": "small",
      "passes": false
    },
    {
      "id": "US-002",
      "title": "Add theme toggle component",
      "description": "As a user, I want to switch themes.",
      "acceptanceCriteria": [
        "ThemeToggle component toggles light/dark/system",
        "Add to header",
        "pnpm typecheck passes"
      ],
      "priority": 2,
      "effort": "small",
      "passes": false
    }
  ],
  "dependencies": {"US-002": ["US-001"]}
}
```

## Workflow

```bash
# 1. Create spec
#    → specs/my-feature.json

# 2. Plan mode creates checklist
./ralph.sh plan -s ./specs/my-feature.json

# 3. Build mode executes
./ralph.sh build -s ./specs/my-feature.json
```

## Tips

- **Atomic stories**: Completable in 1-2 iterations
- **Testable criteria**: Include verification commands
- **Map dependencies**: `{ "US-002": ["US-001"] }` means US-002 depends on US-001
- **Update INDEX.md**: Add entry to `specs/INDEX.md`
- **passes field**: Initialize as `false`; build mode sets to `true` when acceptance criteria are met

## Reference

See `specs/ralph-improvements.json` for a comprehensive multi-phase example with phases, milestones, and implementation hints.
