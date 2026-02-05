# Unified Spec Workflow - Implementation Plan

**Spec:** `./specs/unified-spec-workflow.json`
**Branch:** `ralph/unified-spec-workflow`
**Version:** 2.1.0

## Overview

Simplify the ralph workflow from `product→spec→plan→build` to `product→spec→build` by making specs self-sufficient with embedded tasks. Add a new `spec` mode that generates specs from user input or product artifacts.

## Dependency Graph

```
T-001 (Spec mode args) ───┬─► T-002 (Input flags) ──────┐
                          ├─► T-003 (Output flag) ──────┼─► T-005 (Wire spec mode) ─┐
                          └─► T-004 (PROMPT_spec.md) ───┘                            │
                                                                                     │
T-006 (Tasks schema) ─────┬─► T-007 (Update skill) ─────► T-016 (Example spec)      │
                          ├─► T-008 (Build find task) ──► T-009 (Update status) ────┤
                          │                                       │                  │
                          │                               T-010 (Completion) ────────┤
                          └─► T-011 (Plan as derived) ──────────────────────────────┤
                                                                                     │
                          T-012 (RALPH_LOOP_REF.md) ◄───────────────────────────────┘
                                    │
                          ┌─────────┼─────────┐
                          ▼         ▼         ▼
                    T-013      T-014      T-015
                  (README)   (CLAUDE)    (INDEX)

T-017 (Shell completions) ◄─────────────────────────────────────────────────────────┘
```

## Implementation Checklist

### Phase 1: Spec Mode Foundation

#### Task 1.1: T-001 Add spec mode argument parsing
**Effort:** Small | **Depends on:** None

- [x] 1.1.1 Add "spec" to the list of recognized presets in argument parsing (~line 580)
- [x] 1.1.2 Set default model for spec mode to opus
- [x] 1.1.3 Set default prompt file to prompts/PROMPT_spec.md
- [x] 1.1.4 Add spec mode to show_help() output
- [x] 1.1.5 Run shellcheck ralph.sh

**Acceptance criteria:**
- `./ralph.sh spec` recognized as valid mode
- `./ralph.sh spec --help` shows spec-specific options
- shellcheck passes

---

#### Task 1.2: T-002 Add spec mode input flags
**Effort:** Medium | **Depends on:** T-001

- [x] 1.2.1 Add --from-product flag that sets INPUT_SOURCE to product-output/ contents
- [x] 1.2.2 Ensure -p/--prompt works with spec mode (INPUT_SOURCE = inline prompt)
- [x] 1.2.3 Ensure -f/--file works with spec mode (INPUT_SOURCE = file contents)
- [x] 1.2.4 Add mutual exclusivity check: error if multiple input sources specified
- [x] 1.2.5 Require at least one input source for spec mode
- [x] 1.2.6 Run shellcheck ralph.sh

**Acceptance criteria:**
- `-p 'description'` works for inline feature description
- `-f PATH` works for requirements file input
- `--from-product` reads product-output/ artifacts
- Error if multiple input flags specified
- shellcheck passes

---

#### Task 1.3: T-003 Add spec mode output flag
**Effort:** Small | **Depends on:** T-001

- [x] 1.3.1 Add -o/--output flag for spec output path
- [x] 1.3.2 Default output path: specs/{feature-slug}.json (derived from prompt/file)
- [x] 1.3.3 Create specs/ directory if it doesn't exist
- [x] 1.3.4 Add --force flag to overwrite existing output file
- [x] 1.3.5 Warn and exit if output exists without --force
- [x] 1.3.6 Run shellcheck ralph.sh

**Acceptance criteria:**
- `-o PATH` specifies output location
- Default path derived from input
- Overwrite protection works
- shellcheck passes

---

#### Task 1.4: T-004 Create PROMPT_spec.md
**Effort:** Medium | **Depends on:** T-001

- [x] 1.4.1 Create prompts/PROMPT_spec.md
- [x] 1.4.2 Add instruction to read .claude/skills/writing-ralph-specs/SKILL.md FIRST
- [x] 1.4.3 Add template variables: {{INPUT_SOURCE}}, {{OUTPUT_FILE}}, {{PROGRESS_FILE}}
- [x] 1.4.4 Describe input handling (prompt, file, product artifacts)
- [x] 1.4.5 Instruct to research codebase before generating spec
- [x] 1.4.6 Instruct to output JSON with tasks array
- [x] 1.4.7 Include completion protocol (when spec is ready)

**Acceptance criteria:**
- Prompt exists at prompts/PROMPT_spec.md
- Explicitly requires reading the skill first
- All template variables documented
- Output format is tasks-based JSON

---

#### Task 1.5: T-005 Wire spec mode in main loop
**Effort:** Medium | **Depends on:** T-002, T-003, T-004

- [ ] 1.5.1 Set PROMPT_FILE to prompts/PROMPT_spec.md when mode=spec
- [ ] 1.5.2 Populate INPUT_SOURCE variable from input flags
- [ ] 1.5.3 Populate OUTPUT_FILE variable from -o flag or default
- [ ] 1.5.4 Add {{INPUT_SOURCE}} and {{OUTPUT_FILE}} to template substitution
- [ ] 1.5.5 For --from-product, read and concatenate relevant files (7_prd.md, etc.)
- [ ] 1.5.6 Run spec mode through main loop (typically 1-3 iterations)
- [ ] 1.5.7 Run shellcheck ralph.sh

**Acceptance criteria:**
- Template variables substituted correctly
- Spec mode generates output file
- Works with all input sources
- shellcheck passes

---

### Phase 2: Enhanced Spec Format

#### Task 2.1: T-006 Define enhanced spec schema with tasks
**Effort:** Small | **Depends on:** None

- [ ] 2.1.1 Document tasks array schema in code comments or separate schema file
- [ ] 2.1.2 Define task fields: id, title, description, acceptanceCriteria, dependsOn, status, passes, effort, notes, phase (optional)
- [ ] 2.1.3 Define status values: pending, in_progress, complete, blocked
- [ ] 2.1.4 Define passes as boolean for completion tracking (aligns with build mode expectations)
- [ ] 2.1.5 Define dependsOn as array of task IDs
- [ ] 2.1.6 Document backward compatibility: userStories array still supported

**Acceptance criteria:**
- Schema fully documented
- All fields defined with types (including passes: boolean)
- Backward compatibility clear

---

#### Task 2.2: T-007 Update writing-ralph-specs skill
**Effort:** Medium | **Depends on:** T-006

- [ ] 2.2.1 Update .claude/skills/writing-ralph-specs/SKILL.md
- [ ] 2.2.2 Add tasks array as recommended format (above userStories)
- [ ] 2.2.3 Mark userStories as legacy/backward-compatible
- [ ] 2.2.4 Add tasks example showing all fields including passes: false
- [ ] 2.2.5 Document task granularity guidelines (1-2 iterations per task)
- [ ] 2.2.6 Document dependsOn usage
- [ ] 2.2.7 Update workflow section to show spec→build (plan optional)

**Acceptance criteria:**
- Skill updated with tasks format
- userStories marked legacy
- Examples use tasks format with passes field
- Workflow updated

---

### Phase 3: Build Mode Integration

#### Task 3.1: T-008 Update build mode to find next task
**Effort:** Medium | **Depends on:** T-006

- [ ] 3.1.1 Update prompts/PROMPT_build.md to check for tasks array in spec
- [ ] 3.1.2 Add logic to find first task with passes=false and all dependsOn tasks have passes=true
- [ ] 3.1.3 Add fallback: if no tasks array, use plan file (backward compat)
- [ ] 3.1.4 Add instruction to set task status to in_progress before starting
- [ ] 3.1.5 Update workflow section to reflect tasks-first approach

**Acceptance criteria:**
- Build mode reads tasks from spec
- Respects dependsOn (checks passes=true on dependencies)
- Falls back to plan file if no tasks
- Sets in_progress status

---

#### Task 3.2: T-009 Update build mode to update task status
**Effort:** Medium | **Depends on:** T-008

- [ ] 3.2.1 Update prompts/PROMPT_build.md to update task passes and status in spec
- [ ] 3.2.2 Set passes=true and status='complete' when task done
- [ ] 3.2.3 Update notes field with implementation summary
- [ ] 3.2.4 Commit message format: 'feat(T-001): description'
- [ ] 3.2.5 Document: don't update separate plan file when using tasks
- [ ] 3.2.6 Add backward compat: still update userStories.passes if using legacy format

**Acceptance criteria:**
- Task passes=true and status=complete in spec
- Notes field populated
- Commit message includes task ID
- Legacy format still works

---

#### Task 3.3: T-010 Update build mode completion detection
**Effort:** Small | **Depends on:** T-009

- [ ] 3.3.1 Update prompts/PROMPT_build.md pre-completion checklist
- [ ] 3.3.2 Check all tasks have passes=true (when using tasks)
- [ ] 3.3.3 Fall back to plan checklist for specs without tasks
- [ ] 3.3.4 Update when to signal completion section

**Acceptance criteria:**
- Completion based on all tasks having passes=true
- Fallback to plan checklist
- Pre-completion checklist updated

---

#### Task 3.4: T-011 Update plan mode as derived artifact generator
**Effort:** Medium | **Depends on:** T-006

- [ ] 3.4.1 Update prompts/PROMPT_plan.md to detect tasks array in spec
- [ ] 3.4.2 When tasks present, generate Markdown view of tasks (not create new tasks)
- [ ] 3.4.3 Add header note: "This is a derived view. Edit the spec, not this file."
- [ ] 3.4.4 For specs without tasks, plan mode works as before (creates checklist)
- [ ] 3.4.5 Document plan as optional/derived in prompt

**Acceptance criteria:**
- Plan mode generates Markdown from tasks
- Note about derived artifact included
- Backward compat for specs without tasks
- Plan mode documented as optional

---

### Phase 4: Documentation & Polish

#### Task 4.1: T-012 Update docs/RALPH_LOOP_REF.md
**Effort:** Medium | **Depends on:** T-005, T-010

- [ ] 4.1.1 Add Spec Mode section with all flags
- [ ] 4.1.2 Add examples for -p, -f, --from-product inputs
- [ ] 4.1.3 Update workflow diagram to: product→spec→build
- [ ] 4.1.4 Document tasks format in spec section
- [ ] 4.1.5 Add migration notes for existing specs
- [ ] 4.1.6 Update Quick Reference table with spec mode

**Acceptance criteria:**
- Spec mode fully documented
- All examples work
- Workflow diagram updated
- Migration path clear

---

#### Task 4.2: T-013 Update README.md
**Effort:** Medium | **Depends on:** T-012

- [ ] 4.2.1 Update workflow diagram to show spec mode
- [ ] 4.2.2 Update Quick Start with spec mode example
- [ ] 4.2.3 Update Three Modes table to Four Modes
- [ ] 4.2.4 Update "Specs vs Plans" to explain tasks vs userStories
- [ ] 4.2.5 Update common commands with spec mode examples

**Acceptance criteria:**
- Workflow diagram shows spec mode
- Quick start updated
- Modes table includes spec
- Tasks format explained

---

#### Task 4.3: T-014 Update CLAUDE.md
**Effort:** Small | **Depends on:** T-012

- [ ] 4.3.1 Update "Spec → Plan → Build Workflow" section title and content
- [ ] 4.3.2 Document tasks format as primary
- [ ] 4.3.3 Note plan mode as optional
- [ ] 4.3.4 Reference writing-ralph-specs skill for spec creation

**Acceptance criteria:**
- Workflow section updated
- Tasks documented as primary
- Plan noted as optional

---

#### Task 4.4: T-015 Update specs/INDEX.md
**Effort:** Small | **Depends on:** T-012

- [ ] 4.4.1 Update conventions to show tasks vs userStories
- [ ] 4.4.2 Update workflow diagram
- [ ] 4.4.3 Add this spec to the index table

**Acceptance criteria:**
- Conventions updated
- Diagram updated
- New spec in index

---

#### Task 4.5: T-016 Create example spec with tasks
**Effort:** Small | **Depends on:** T-007

- [ ] 4.5.1 Create specs/example-tasks.json
- [ ] 4.5.2 Include all task fields as example (id, title, description, acceptanceCriteria, dependsOn, status, passes, effort, notes)
- [ ] 4.5.3 Show dependency between tasks
- [ ] 4.5.4 Reference from skill and INDEX.md

**Acceptance criteria:**
- Example spec exists
- All fields demonstrated (including passes: false)
- Dependencies shown
- Referenced in docs

---

#### Task 4.6: T-017 Add shell completion for spec mode
**Effort:** Small | **Depends on:** T-005

- [ ] 4.6.1 Update completions/ralph.bash with spec preset
- [ ] 4.6.2 Update completions/ralph.zsh with spec preset
- [ ] 4.6.3 Add --from-product flag completion
- [ ] 4.6.4 Add -o/--output flag completion
- [ ] 4.6.5 Run shellcheck on completion scripts

**Acceptance criteria:**
- Spec mode tab-completes
- New flags complete
- shellcheck passes

---

## Milestones

### M1: Spec Mode MVP (v2.1.0-alpha)
Tasks: T-001, T-002, T-003, T-004, T-005
**Goal:** Can generate specs from user input, file, or product artifacts

### M2: Unified Spec Format (v2.1.0-beta)
Tasks: T-006, T-007
**Goal:** Tasks array defined and documented in skill

### M3: Build Mode Integration (v2.1.0-rc1)
Tasks: T-008, T-009, T-010, T-011
**Goal:** Build mode works directly from spec tasks

### M4: Documentation Complete (v2.1.0)
Tasks: T-012, T-013, T-014, T-015, T-016, T-017
**Goal:** All docs updated, examples created, completions updated

---

## Verification Commands

After each task, run:
```bash
shellcheck ralph.sh
./ralph.sh --help
./ralph.sh spec --help
./ralph.sh --dry-run
```

After milestone M1:
```bash
./ralph.sh spec -p 'Add dark mode toggle' --dry-run
./ralph.sh spec --from-product --dry-run
```

After milestone M3:
```bash
./ralph.sh build -s ./specs/example-tasks.json --dry-run
```

---

## Notes

- Maintain backward compatibility with existing userStories format
- Spec mode should typically complete in 1-3 iterations
- The writing-ralph-specs skill is the single source of truth for spec format
- Plan mode becomes optional - useful for human review but not required for build
