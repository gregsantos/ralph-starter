# Implementation Plan

> This is a template. Replace with your actual implementation checklist.

## Overview

Brief description of what's being implemented and why.

## Checklist

<!-- Each item should be atomic and completable in one iteration -->

- [ ] Task 1: Description of first task
- [ ] Task 2: Description of second task
- [ ] Task 3: Description of third task

## Dependencies

Note any ordering constraints between tasks.

## Notes

Additional context, decisions made, or gotchas discovered during planning.

---

## How to Use This File

1. **Replace the template content** with your actual tasks
2. **Keep items atomic**: One clear deliverable per checkbox
3. **Mark complete**: Change `[ ]` to `[x]` when done
4. **Document learnings**: Add notes as you discover things

### Good Checklist Items

```markdown
# Bad - too vague

- [ ] Add authentication

# Good - specific and actionable

- [ ] Create JWT token utility in src/lib/auth.ts
- [ ] Add auth middleware to src/middleware/auth.ts
- [ ] Add login endpoint POST /api/auth/login
- [ ] Add tests for auth utilities
```

### When to Regenerate

Regenerate this plan (don't patch) when:

- Current approach isn't working after 3+ iterations
- Discovered the codebase is structured differently
- Better approach became apparent
- Too many amendments accumulated
