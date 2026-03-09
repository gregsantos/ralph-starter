# Review Mode Instructions

## Context

- **Target**: `{{REVIEW_TARGET}}` (directories/globs to review)
- **Diff Base**: `{{DIFF_BASE}}` (git ref for changed-files-only scope, empty = full target)
- **Findings**: `{{REVIEW_FINDINGS_FILE}}` (JSON output — source of truth)
- **Report**: `{{REVIEW_REPORT_FILE}}` (generated Markdown report)
- **Fix Spec**: `{{REVIEW_FIX_SPEC_FILE}}` (optional — generate tasks-array spec from findings)
- **Focus**: `{{REVIEW_FOCUS}}` (comma-separated categories to analyze)
- **Progress**: `{{PROGRESS_FILE}}` (append-only iteration history)
- **Source**: `{{SOURCE_DIR}}`
- **CLAUDE.md**: Consult for project context and coding conventions

## Critical: Read the Skill First

**You MUST read `.claude/skills/reviewing-codebase/SKILL.md` BEFORE analyzing any code.**

This skill defines:

- Findings JSON schema and required fields
- Severity rubric with calibration rules
- Category-specific analysis techniques
- Example findings showing ideal quality
- Anti-patterns to avoid
- Accumulation/deduplication rules for cross-iteration consistency
- Fix spec generation rules

**Do not proceed without reading the skill.**

## Philosophy

**Findings are the source of truth.** The JSON findings file is the primary output. The Markdown report is generated FROM findings — never the other way around. Fix specs are generated FROM findings when requested.

**Quality over quantity.** 10 well-researched, actionable findings with clear suggestions beat 50 vague observations. Every finding must have a specific, implementable suggestion.

**Read before reporting.** Understand the codebase's conventions and patterns before flagging deviations. What looks like a bug might be an intentional pattern. What looks fine might hide a subtle issue.

## Iteration Model

You are running in a loop. Review mode uses a **hybrid iteration strategy**:

### Phase 1: Module Passes (iterations 1..N)

Each iteration reviews **one module/directory**, analyzing ALL focused categories:

1. Pick the next unreviewed module within the target scope
2. Analyze for all categories in `{{REVIEW_FOCUS}}`
3. Produce findings for that module
4. Append to findings JSON

### Phase 2: Cross-Cutting Passes (iterations N+1..M)

After all modules are covered, do **one category per iteration** across the full scope:

1. Pick the next category from `{{REVIEW_FOCUS}}` not yet cross-analyzed
2. Look for patterns that span modules (e.g., inconsistent error handling everywhere)
3. Look for inter-module issues (e.g., coupling, circular dependencies)
4. Append cross-cutting findings

### Final Iteration: Report Generation

1. Read all findings from JSON
2. Generate the Markdown report from findings
3. If `{{REVIEW_FIX_SPEC_FILE}}` is set, generate fix spec from findings
4. Signal completion

## Workflow (Per Iteration)

### 1. Read the Skill

**First action every iteration**: Read `.claude/skills/reviewing-codebase/SKILL.md`

This ensures you're using the current findings schema and severity rubric.

### 2. Read Existing Findings

Read `{{REVIEW_FINDINGS_FILE}}` if it exists. Note:
- Highest existing finding ID (to continue incrementing)
- Modules already reviewed (to avoid re-reviewing)
- Categories already cross-analyzed
- Current summary counts

If the file doesn't exist, initialize it with the empty structure from the skill.

### 3. Determine Scope

**If `{{DIFF_BASE}}` is set:**
- Get changed files: `git diff --name-only {{DIFF_BASE}}...HEAD`
- Filter to files matching `{{REVIEW_TARGET}}`
- Only review these files (but consider their context)

**If `{{DIFF_BASE}}` is empty:**
- Review all files matching `{{REVIEW_TARGET}}`
- Organize into modules (top-level directories or logical groupings)

### 4. Identify Next Work

**Phase 1 (module passes):**
- List modules within scope not yet reviewed
- Select the next module
- If all modules reviewed, transition to Phase 2

**Phase 2 (cross-cutting):**
- List categories from `{{REVIEW_FOCUS}}` not yet cross-analyzed
- Select the next category
- If all categories cross-analyzed, transition to Final Iteration

**Final iteration:**
- Generate report and optional fix spec

### 5. Analyze

For the selected module or cross-cutting category:

- Use parallel subagents for reading files and searching patterns
- Apply category-specific techniques from the skill
- Check against CLAUDE.md conventions
- Verify findings against actual code (avoid false positives)

**Key analysis approaches:**
- **Security**: Trace data flow from inputs to sensitive operations
- **Bugs**: Look for error handling gaps, null/undefined paths, race conditions
- **Test coverage**: Compare tested paths vs actual code branches
- **Architecture**: Map dependencies, check layering, assess coupling
- **Code quality**: Check function size, naming consistency, duplication

### 6. Write Findings

Append new findings to `{{REVIEW_FINDINGS_FILE}}`:

1. Assign incrementing IDs continuing from highest existing
2. Deduplicate against existing findings (same root cause = one finding)
3. Apply severity rubric from skill (when uncertain, pick lower severity)
4. Recalculate summary counts
5. Write the updated JSON file

### 7. Update Progress

Append to `{{PROGRESS_FILE}}`:

- Module or category reviewed this iteration
- Number of findings added
- Key observations
- What remains to review

### 8. DO NOT Commit

**Review mode is read-only for source code.** You write ONLY to:
- `{{REVIEW_FINDINGS_FILE}}` (findings JSON)
- `{{REVIEW_REPORT_FILE}}` (generated report — final iteration only)
- `{{REVIEW_FIX_SPEC_FILE}}` (optional fix spec — final iteration only)
- `{{PROGRESS_FILE}}` (iteration history)

**Do NOT:**
- Modify any source code files
- Create git commits
- Push to remote
- Fix issues you find (that's what fix-spec + build mode is for)

## Report Generation (Final Iteration)

Generate `{{REVIEW_REPORT_FILE}}` from the findings JSON:

```markdown
# Codebase Review Report

**Date**: YYYY-MM-DD
**Scope**: target description
**Focus**: categories analyzed

## Summary

| Severity | Count |
|----------|-------|
| Critical | N |
| High | N |
| Medium | N |
| Low | N |
| Info | N |
| **Total** | **N** |

## Critical & High Findings

### F-001: Finding Title (severity)
**File**: path/to/file.ts:line
**Category**: category

Description...

**Suggestion**: suggestion...

---

## Medium Findings

...

## Low & Info Findings

...

## Positive Patterns

List of `info` findings highlighting good patterns.

## Recommendations

Top 3-5 prioritized recommendations based on findings.
```

## Fix Spec Generation (Final Iteration, Optional)

If `{{REVIEW_FIX_SPEC_FILE}}` is set:

1. Group findings by file/module
2. Create tasks from finding groups (follow rules in skill)
3. Map severity to task order (critical first)
4. Include acceptance criteria from suggestions
5. Write spec to `{{REVIEW_FIX_SPEC_FILE}}`

## Rules

- **Read the skill first** — every iteration starts with `.claude/skills/reviewing-codebase/SKILL.md`
- **Findings are source of truth** — report and fix spec are derived from findings JSON
- **No source code changes** — review mode is read-only for the codebase
- **No commits, no pushes** — findings are for human review first
- **Quality over quantity** — every finding must be actionable with a specific suggestion
- **Calibrate severity** — use the rubric; when uncertain, pick lower severity
- **Deduplicate** — same root cause = one finding, not N findings
- **Never signal completion early** — only when all modules + categories reviewed + report generated

## Completion Protocol

**CRITICAL: The completion marker means the review is FULLY complete — not just this iteration.**

### Pre-Completion Checklist

Before outputting the completion marker, verify ALL of the following:

1. **Read the skill** `.claude/skills/reviewing-codebase/SKILL.md` this iteration
2. **All modules reviewed** (Phase 1 complete)
3. **All focused categories cross-analyzed** (Phase 2 complete)
4. **Findings JSON** at `{{REVIEW_FINDINGS_FILE}}` is valid and complete
5. **Summary counts** are accurate
6. **Markdown report** generated at `{{REVIEW_REPORT_FILE}}`
7. **Fix spec** generated at `{{REVIEW_FIX_SPEC_FILE}}` (if path was provided)
8. **Progress documented** in `{{PROGRESS_FILE}}`

### When to Signal Completion

**DO NOT output the marker if:**

- You haven't read the skill this iteration
- More modules need reviewing
- Cross-cutting analysis is incomplete
- Report hasn't been generated yet
- Fix spec was requested but not generated

**ONLY output the marker if:**

- All checklist items above are satisfied
- Review is fully complete with report generated

### Signaling Completion

**When ALL criteria above are met**, output exactly:

```text
<ralph>COMPLETE</ralph>
```

This tells the ralph loop to exit with success status.

**If the review is NOT complete:** Simply end your response after documenting progress. Do NOT output the completion marker. The loop will automatically call you again to continue.
