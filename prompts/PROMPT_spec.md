# Spec Mode Instructions

## Context

- **Input**: `{{INPUT_SOURCE}}` (feature description, requirements file, or product artifacts)
- **Output**: `{{OUTPUT_FILE}}` (generated JSON spec file)
- **Progress**: `{{PROGRESS_FILE}}` (iteration history)
- **Source**: `{{SOURCE_DIR}}`
- **CLAUDE.md**: Consult for project context and coding conventions

## Critical: Read the Skill First

**You MUST read `.claude/skills/writing-ralph-specs/SKILL.md` BEFORE generating any spec.**

This skill defines:

- Required JSON structure and fields
- Task format with acceptance criteria
- Dependency mapping conventions
- Quality guidelines

**Do not proceed without reading the skill.**

## Philosophy

**Specs are the single source of truth.** A well-crafted spec enables autonomous execution. Build mode reads directly from the spec's tasks—no separate plan file needed. Every task should be atomic, verifiable, and have clear acceptance criteria.

**Research before writing.** Understand the codebase deeply before defining tasks. A spec based on assumptions will fail in build mode.

**Tasks are the unit of work.** Each task should be completable in 1-2 iterations. Too large = gets stuck. Too small = overhead. Find the sweet spot.

## Iteration Model

You are running in a loop. Each iteration should make **incremental progress** on spec creation:

1. Research the codebase and requirements
2. Draft or refine spec sections
3. Document in `{{PROGRESS_FILE}}`
4. The loop will call you again if more work is needed

Spec mode typically completes in 1-3 iterations depending on complexity.

## Workflow (Per Iteration)

### 1. Read the Skill

**First action every iteration**: Read `.claude/skills/writing-ralph-specs/SKILL.md`

This ensures you're using the current spec format and best practices.

### 2. Understand the Input

Parse and understand the input provided:

**If inline prompt (`-p`):**
- Extract the feature description
- Identify key requirements and constraints
- Note any specific technologies or approaches mentioned

**If file input (`-f`):**
- Read the entire file
- Extract requirements, user stories, or feature descriptions
- Note any existing acceptance criteria

**If product artifacts (`--from-product`):**
- Study the PRD (`7_prd.md`) as the primary source
- Reference personas (`4_personas.md`) for user context
- Check technical requirements (`9_technical_requirements.md`) for constraints
- Cross-reference other artifacts as needed

### 3. Research the Codebase

**Critical: Don't assume functionality is missing.** Always search first—the codebase likely has what you need.

- Use parallel Sonnet subagents for broad codebase exploration
- Identify existing patterns, conventions, and utilities
- Find related implementations to understand the approach
- Note testing patterns and verification commands
- Check CLAUDE.md for project-specific conventions

### 4. Design the Tasks

Based on research, design tasks that:

- Are atomic and completable in 1-2 iterations
- Have specific, testable acceptance criteria
- Include documentation updates for user-facing features
- Map dependencies correctly (`dependsOn` field)
- Start with `passes: false` and `status: "pending"`

**Task granularity guidelines:**
- If a task description includes "and" multiple times, split it
- If acceptance criteria exceed 5-6 items, the task may be too large
- If a task could be done in one edit, it might be too small

### 5. Generate the Spec

Create the JSON spec at `{{OUTPUT_FILE}}` with:

```json
{
  "project": "Feature Name",
  "branchName": "feature/branch-name",
  "version": "1.0.0",
  "description": "One-line description of the feature",
  "context": {
    "currentState": "What exists today",
    "targetState": "What we want to achieve",
    "constraints": ["Constraint 1", "Constraint 2"],
    "verificationCommands": ["pnpm test", "pnpm typecheck", "shellcheck ralph.sh"]
  },
  "phases": [
    {
      "id": "P1",
      "name": "Phase Name",
      "description": "What this phase accomplishes",
      "rationale": "Why this phase is needed"
    }
  ],
  "tasks": [
    {
      "id": "T-001",
      "phase": "P1",
      "title": "Short action title",
      "description": "What this task accomplishes and why",
      "acceptanceCriteria": [
        "Specific, testable criterion 1",
        "Specific, testable criterion 2",
        "pnpm test passes"
      ],
      "dependsOn": [],
      "status": "pending",
      "effort": "small",
      "passes": false,
      "notes": ""
    }
  ],
  "dependencies": {
    "T-002": ["T-001"]
  }
}
```

**Required fields:**
- `project`, `branchName`, `description`
- `context` with `currentState`, `targetState`, `verificationCommands`
- `tasks` array with all task fields

**Optional fields:**
- `version`, `phases`, `milestones`, `glossary`

### 6. Validate the Spec

Before completing, verify:

- [ ] JSON is valid (no syntax errors)
- [ ] All tasks have unique IDs (T-001, T-002, etc.)
- [ ] All tasks have acceptance criteria (specific and testable)
- [ ] Dependencies form a DAG (no circular dependencies)
- [ ] `dependsOn` arrays reference valid task IDs
- [ ] All tasks have `passes: false` and `status: "pending"`
- [ ] Verification commands are correct for this project
- [ ] Documentation tasks included for user-facing changes

### 7. Document Progress

Append to `{{PROGRESS_FILE}}`:

- Input source analyzed
- Codebase patterns discovered
- Tasks designed and rationale
- Any assumptions made
- Open questions (if any)

## Rules

- **Read the skill first**—every iteration starts with `.claude/skills/writing-ralph-specs/SKILL.md`
- **Research before writing**—understand the codebase, don't assume
- **One task = one iteration**—tasks should be completable in 1-2 build iterations
- **Specific criteria**—"works correctly" is not acceptable; be precise
- **Include doc updates**—user-facing features need README, --help, reference doc tasks
- **Valid JSON only**—validate before completing
- **passes: false**—all tasks start incomplete; build mode marks them complete
- **Never signal completion early**—only when spec is fully ready

## Completion Protocol

**CRITICAL: The completion marker means the spec is FULLY complete—not just this iteration.**

⚠️ **NEVER output `<ralph>COMPLETE</ralph>` after a single research iteration.**

- "End this iteration" = normal, loop continues with more work
- "Signal completion" = spec is complete and ready for build mode

### Pre-Completion Checklist

Before outputting the completion marker, verify ALL of the following:

1. **Read the skill** `.claude/skills/writing-ralph-specs/SKILL.md` this iteration
2. **Spec file exists** at `{{OUTPUT_FILE}}`
3. **JSON is valid** (no syntax errors)
4. **All required fields present** (project, branchName, description, context, tasks)
5. **All tasks have**:
   - Unique ID (T-001 format)
   - Title and description
   - Acceptance criteria (specific and testable)
   - `dependsOn` array (even if empty)
   - `status: "pending"` and `passes: false`
   - `effort` field
6. **Dependencies are valid** (reference existing task IDs, no cycles)
7. **Documentation tasks included** for user-facing features
8. **Progress documented** in `{{PROGRESS_FILE}}`

### When to Signal Completion

**DO NOT output the marker if:**

- You haven't read the skill this iteration
- Spec file doesn't exist or has syntax errors
- More research is needed
- Tasks are incomplete or missing criteria
- Documentation tasks are missing for user-facing features

**ONLY output the marker if:**

- All checklist items above are satisfied
- Spec is ready for build mode execution

### Signaling Completion

**When ALL criteria above are met**, output exactly:

```text
<ralph>COMPLETE</ralph>
```

This tells the ralph loop to exit with success status.

**If the spec is NOT complete:** Simply end your response after documenting progress. Do NOT output the completion marker. The loop will automatically call you again to continue.
