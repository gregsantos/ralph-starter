---
name: reviewing-codebase
description: Performs structured codebase analysis producing JSON findings and Markdown reports. Use when reviewing code quality, security, test coverage, or architecture. Triggers on "review the codebase", "code review", "audit code", "find issues", or when analysis is needed before refactoring.
---

# Reviewing Codebase

Perform structured codebase analysis via `./ralph.sh review`. Produces JSON findings (source of truth) and a generated Markdown report. Optionally generates a fix-spec with tasks for `./ralph.sh build`.

## Findings JSON Schema

Each finding is an object in the `findings` array:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique identifier (e.g., "F-001") |
| `category` | string | Yes | One of: `security`, `bug`, `code-quality`, `test-coverage`, `architecture` |
| `severity` | string | Yes | One of: `critical`, `high`, `medium`, `low`, `info` |
| `file` | string | Yes | File path relative to project root |
| `line` | number | No | Line number (omit for file-level findings) |
| `title` | string | Yes | Short finding title (max 80 chars) |
| `description` | string | Yes | Detailed explanation of the issue |
| `suggestion` | string | Yes | Recommended fix or improvement |
| `effort` | string | Yes | One of: `small`, `medium`, `large` |
| `references` | string[] | No | Links to relevant docs, OWASP IDs, etc. |

### Findings File Structure

```json
{
  "project": "Project Name",
  "reviewDate": "2024-01-15",
  "scope": {
    "target": "src/*",
    "diffBase": "",
    "focus": ["code-quality", "test-coverage", "architecture", "security"]
  },
  "summary": {
    "total": 0,
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0,
    "info": 0
  },
  "findings": []
}
```

## Severity Rubric

| Severity | Criteria | Examples |
|----------|----------|----------|
| **critical** | Exploitable vulnerability, data loss risk, or production-breaking bug | SQL injection, unvalidated file deletion, infinite loop in request handler |
| **high** | Security gap, likely bug, or missing critical error handling | Missing auth check, unhandled null dereference, race condition in state update |
| **medium** | Code smell, moderate risk, coverage gap in important paths | Complex function (>50 LOC), untested error paths, tight coupling between modules |
| **low** | Style issue, minor improvement, documentation gap | Inconsistent naming, missing JSDoc on exported function, magic number |
| **info** | Observation, positive pattern, or architectural note | Well-structured module, potential future consideration, pattern to replicate |

**Severity calibration rules:**
- When uncertain between two levels, pick the lower one (avoid over-alarming)
- `critical` requires demonstrated exploitability or data-loss path
- `info` findings should highlight good patterns, not just fill space
- A finding without a clear `suggestion` should not be `high` or `critical`

## Category Analysis Techniques

### Security
- **OWASP Top 10**: Injection, broken auth, sensitive data exposure, XXE, broken access control, misconfiguration, XSS, insecure deserialization, known vulnerabilities, insufficient logging
- **Input validation**: Trace user inputs through to database/filesystem/exec calls
- **Auth/authz**: Check route protection, token validation, permission boundaries
- **Secrets**: Scan for hardcoded credentials, API keys, connection strings
- **Dependencies**: Flag known CVEs in package.json/lock files

### Bug
- **Error handling**: Uncaught exceptions, swallowed errors, missing finally blocks
- **Race conditions**: Shared mutable state, async operations without proper guards
- **Type safety**: Implicit `any`, unchecked casts, null/undefined access patterns
- **Edge cases**: Off-by-one, empty arrays, boundary values, encoding issues
- **Resource leaks**: Unclosed connections, event listeners never removed

### Test Coverage
- **Untested paths**: Error branches, edge cases, boundary conditions
- **Mock quality**: Mocks that don't match real behavior, over-mocking
- **Missing integration tests**: API routes, middleware chains, database operations
- **Assertion quality**: Tests that pass but don't verify meaningful behavior
- **Flaky patterns**: Time-dependent tests, order-dependent tests, non-deterministic assertions

### Architecture
- **Coupling**: Modules with excessive cross-dependencies, god objects
- **Layering violations**: UI code calling database directly, business logic in routes
- **Single responsibility**: Files/functions doing too many things
- **Abstraction quality**: Premature abstraction, leaky abstractions, missing abstractions
- **Consistency**: Inconsistent patterns across similar modules

## Example Findings

### Security Example

```json
{
  "id": "F-001",
  "category": "security",
  "severity": "high",
  "file": "src/app/api/users/route.ts",
  "line": 23,
  "title": "Missing authentication check on user update endpoint",
  "description": "The PUT handler modifies user records without verifying the requesting user's identity or permissions. Any unauthenticated request can modify any user's data.",
  "suggestion": "Add authentication middleware and verify the requesting user has permission to modify the target user record. Use the existing `withAuth` wrapper from `lib/auth`.",
  "effort": "small",
  "references": ["OWASP A01:2021 - Broken Access Control"]
}
```

### Bug Example

```json
{
  "id": "F-002",
  "category": "bug",
  "severity": "medium",
  "file": "src/lib/cache.ts",
  "line": 45,
  "title": "Cache entries never expire due to missing TTL check",
  "description": "The `get()` method returns cached values without checking the `expiresAt` timestamp. Once set, cache entries persist indefinitely regardless of configured TTL, leading to stale data.",
  "suggestion": "Add expiration check in `get()`: compare `entry.expiresAt` against `Date.now()` and return null/delete entry if expired.",
  "effort": "small"
}
```

### Test Coverage Example

```json
{
  "id": "F-003",
  "category": "test-coverage",
  "severity": "medium",
  "file": "src/lib/validation.ts",
  "line": null,
  "title": "No tests for email validation edge cases",
  "description": "The `validateEmail` function has 6 branches but tests only cover the happy path (valid email) and one invalid case. Missing: unicode domains, plus-addressing, maximum length, empty string, null input.",
  "suggestion": "Add test cases for each branch: unicode domains (`user@xn--n3h.example`), plus-addressing (`user+tag@example.com`), 254-char limit, empty string, and null/undefined input.",
  "effort": "small"
}
```

## Anti-Patterns (Do NOT Do These)

**Vague findings:**
```json
{
  "title": "Code could be improved",
  "description": "This code has some issues",
  "suggestion": "Refactor to be better"
}
```

**False positives:**
- Flagging intentional patterns as bugs (e.g., catch-all error handlers that log and re-throw)
- Reporting missing tests for trivial getters/setters
- Flagging framework conventions as architectural violations

**Wrong severity:**
- `critical` for a style issue
- `low` for an actual security vulnerability
- `high` for an info-level observation

**Duplicate findings:**
- Reporting the same pattern in every file instead of one finding with "affects N files"
- Multiple findings for the same root cause (report the root cause once)

## Accumulation and Deduplication Rules

When running across multiple iterations:

1. **Read existing findings first** — check `findings.json` before analyzing
2. **Deduplicate by root cause** — if the same pattern appears in 5 files, create ONE finding listing all affected files in the description
3. **Increment IDs** — continue from the highest existing ID (F-001, F-002... F-015, F-016)
4. **Update summary counts** — recalculate the `summary` object after each iteration
5. **Don't downgrade severity** — if a previous iteration rated something `high`, don't change to `medium` unless you have new information
6. **Remove false positives** — if deeper analysis reveals a finding was incorrect, remove it and note the removal in progress

## Fix Spec Generation Rules

When `--fix-spec` is provided, convert findings to a tasks-array spec:

1. **Group findings by file/module** — related findings become one task
2. **Map severity to priority** — critical/high findings first, low/info findings optional
3. **Map effort directly** — finding effort → task effort
4. **Create acceptance criteria** from each finding's suggestion
5. **Set dependencies** — if fixing finding A requires fixing finding B first, add `dependsOn`
6. **Skip `info` findings** — observations don't need fix tasks
7. **Include verification** — every task should have "existing tests still pass" criterion

### Fix Spec Structure

```json
{
  "project": "Fix: [Project Name] Review Findings",
  "branchName": "fix/review-findings",
  "description": "Address findings from codebase review",
  "context": {
    "currentState": "Review identified N findings (X critical, Y high, Z medium)",
    "targetState": "All critical and high findings resolved, medium findings addressed where practical",
    "verificationCommands": ["pnpm test", "pnpm typecheck"]
  },
  "tasks": []
}
```

## Workflow

```bash
# 1. Review the codebase
./ralph.sh review --review-target ./src/

# 2. Review only changed files since main
./ralph.sh review --diff-base main

# 3. Focus on specific categories
./ralph.sh review --focus security,test-coverage

# 4. Generate fix spec from findings
./ralph.sh review --fix-spec ./specs/review-fixes.json

# 5. Build fixes from generated spec
./ralph.sh build -s ./specs/review-fixes.json
```

## Tips

- **Start narrow, go wide**: Review one module deeply before sweeping the whole codebase
- **Read existing tests**: Understanding what IS tested reveals what ISN'T
- **Check git blame**: Recent changes are more likely to have issues than battle-tested code
- **Don't over-report**: 10 high-quality findings beat 50 low-quality ones
- **Positive findings matter**: `info` findings that highlight good patterns help the team understand what to replicate
