This codebase will outlive you. Every shortcut you take becomes
someone else's burden. Every hack compounds into technical debt
that slows the whole team down.

You are not just writing code. You are shaping the future of this
project. The patterns you establish will be copied. The corners
you cut will be cut again.

Fight entropy. Leave the codebase better than you found it.

# Application and Coding Conventions

## Build & Run

- Run: `pnpm dev`
- Build: `pnpm build`
- Start: `pnpm start`

## Validation

Run these after implementing to get immediate feedback:

- Tests: `pnpm test`
- Typecheck: `pnpm typecheck`
- Lint: `pnpm lint`

## Project Structure

```
ralph-starter/
├── ralph.sh                      # The loop script
├── ralph.conf                    # Configuration defaults
├── CLAUDE.md                     # Project context (this file)
├── prompts/
│   ├── PROMPT_spec.md            # Spec generation instructions
│   ├── PROMPT_plan.md            # Planning mode instructions (optional)
│   ├── PROMPT_build.md           # Build mode instructions
│   ├── PROMPT_product.md         # Product artifact generation
│   └── PROMPT_review.md          # Codebase analysis and review
├── specs/
│   ├── INDEX.md                  # Feature catalog
│   ├── {feature}.json            # JSON specs (recommended)
│   └── {feature}.md              # Markdown specs (alternative)
├── plans/
│   └── IMPLEMENTATION_PLAN.md    # Task checklist
├── .claude/
│   └── skills/
│       ├── writing-ralph-specs/  # Skill for creating JSON specs
│       └── reviewing-codebase/   # Skill for codebase analysis
├── product-input/                # Product context files
├── product-output/               # Generated artifacts
├── review-output/                # Review findings and reports
├── progress.txt                  # Iteration history
├── archive/                      # Auto-archived branch state
└── docs/
    ├── RALPH_LOOP_REF.md         # CLI reference
    ├── RALPH_WORKSHOP.md         # Workshop guide
    └── PRODUCT_ARTIFACT_SPEC.md  # Artifact specifications
```

## TypeScript

- Enable strict mode. No `any` unless absolutely necessary and documented.
- Prefer `interface` for object shapes, `type` for unions/intersections.
- Use explicit return types on exported functions.
- Leverage discriminated unions for state machines and complex conditionals.
- Avoid enums; use `as const` objects or union types instead.
- Never use `@ts-ignore`. Use `@ts-expect-error` with explanation if unavoidable.

```typescript
// Prefer this
type Status = "idle" | "loading" | "success" | "error"

// Over this
enum Status {
  Idle,
  Loading,
  Success,
  Error,
}
```

## Next.js App Router

- Use Server Components by default. Add `'use client'` only when needed.
- Colocate loading.tsx, error.tsx, and not-found.tsx with their pages.
- Use `generateMetadata` for dynamic SEO, not hardcoded meta tags.
- API routes go in `app/api/` using route.ts with named exports (GET, POST, etc.).
- Prefer Server Actions for mutations when possible over API routes.
- Use `next/navigation` for routing (`useRouter`, `usePathname`, `redirect`).

## React Patterns

- Prefer function components with hooks. No class components.
- Keep components small and focused. Extract when exceeding ~100 lines.
- Use `useMemo` and `useCallback` only when there's a measured performance issue.
- Avoid prop drilling beyond 2 levels; use context or composition instead.
- Name event handlers with `handle` prefix: `handleClick`, `handleSubmit`.
- Name boolean props with `is`, `has`, `should` prefix: `isLoading`, `hasError`.

## State Management

- Use SWR for server state (fetching, caching, revalidation).
- Use React Context for app-wide UI state (theme, workspace, modals).
- Use `useState` for local component state.
- Prefer localStorage for persistent user preferences, IndexedDB for large data.
- Never store derived state. Compute it.

## Styling

- Use Tailwind CSS utility classes. Avoid custom CSS unless necessary.
- Use shadcn/ui components as the foundation. Customize via className.
- Use `cn()` utility from `lib/utils` for conditional class merging.
- Responsive design: mobile-first with `sm:`, `md:`, `lg:` breakpoints.
- Dark mode: use `dark:` variant classes, managed by `next-themes`.

## Error Handling

- Use error boundaries for component-level failures.
- API routes: return proper HTTP status codes with structured error responses.
- Client errors: show user-friendly messages, log details to console.
- Never swallow errors silently. Log or handle them explicitly.

```typescript
// API error response pattern
return Response.json({error: "Invalid request", details: "..."}, {status: 400})
```

## Testing

- Write tests for business logic and utilities first.
- Use descriptive test names: `it('returns null when user is not found')`.
- One assertion per test when possible. Multiple related assertions are acceptable.
- Mock external dependencies (APIs, storage), not internal modules.
- Test behavior, not implementation details.

## Performance

- Use dynamic imports for heavy components: `dynamic(() => import('./Heavy'))`.
- Lazy load below-the-fold content.
- Optimize images with `next/image`.
- Avoid blocking the main thread; use Web Workers for heavy computation.
- Profile before optimizing. Don't guess at bottlenecks.

## Security

- Validate all user input on the server, even if validated on client.
- Use parameterized queries/methods for any data operations.
- Sanitize content before rendering if it includes user-generated HTML.
- Never expose secrets in client-side code or git history.
- Use HTTPS, secure cookies, and proper CORS configuration.

## Code Style

- Use descriptive variable names. Avoid abbreviations except common ones (id, url, api).
- Prefer early returns to reduce nesting.
- Avoid magic numbers and strings; use named constants.
- Keep functions under 30 lines when possible. Extract helpers for complex logic.
- Comments explain "why", not "what". Code should be self-documenting.

## Git

- Write clear, imperative commit messages: "Add user authentication" not "Added auth".
- Keep commits atomic: one logical change per commit.
- Never commit secrets, API keys, or credentials.

# Skills

- Use `frontend-design` skill for creative aesthetics (typography choices, color palettes, animations, visual style)
- Use `ui-quality` skill for implementation correctness (accessibility, performance, forms, loading states)
- Use `writing-ralph-specs` skill for creating structured JSON specs with tasks array (see `.claude/skills/`)
- Use `reviewing-codebase` skill for structured codebase analysis with JSON findings (see `.claude/skills/`)
- Spec mode (`./ralph.sh spec`) automatically uses the writing-ralph-specs skill
- Review mode (`./ralph.sh review`) automatically uses the reviewing-codebase skill

# Spec → Build Workflow

The recommended workflow for implementing features with Ralph:

```
1. (Optional) Product Mode → product-output/*          (discovery artifacts)
2. Create Spec (JSON)      → specs/{feature}.json      (the "what & why" + tasks)
3. Run Build Mode          → Implementation complete   (the code)
4. (Optional) Plan Mode    → plans/{feature}_PLAN.md  (human-readable view)
```

For one-shot execution, use launch mode:

```bash
./ralph.sh launch -p "Add user authentication with OAuth"
```

## Creating Specs

**Recommended: Use spec mode** to generate specs automatically:

```bash
# From an inline description
./ralph.sh spec -p "Add user authentication with OAuth"

# From a requirements file
./ralph.sh spec -f ./requirements.md

# From product artifacts
./ralph.sh spec --from-product
```

Or use the `writing-ralph-specs` skill or create JSON specs manually in `specs/`.

## Spec Format: Tasks (Recommended)

Specs use the **tasks array** as the primary format. Build mode works directly from tasks:

```json
{
  "project": "My Feature",
  "tasks": [
    {
      "id": "T-001",
      "title": "Add authentication middleware",
      "description": "Create middleware for JWT validation",
      "acceptanceCriteria": ["JWT tokens validated", "401 on invalid token"],
      "dependsOn": [],
      "status": "pending",
      "passes": false,
      "effort": "medium",
      "notes": ""
    }
  ]
}
```

**Task fields:**
- **id**: Unique identifier (T-001, T-002, etc.)
- **title**: Short task name
- **description**: What needs to be done
- **acceptanceCriteria**: How to verify completion
- **dependsOn**: Array of task IDs that must complete first
- **status**: pending | in_progress | complete | blocked
- **passes**: Boolean for completion tracking (build mode sets to true)
- **effort**: small | medium | large (optional)
- **notes**: Implementation notes (updated by build mode)

## Legacy: userStories

For backward compatibility, specs can still use `userStories` array:

```json
{
  "userStories": [
    {
      "id": "US-001",
      "story": "As a user, I want to...",
      "acceptanceCriteria": ["..."],
      "passes": false
    }
  ]
}
```

When using userStories, plan mode is required to create the implementation checklist.

## Running the Workflow

```bash
# Recommended: spec mode generates spec with tasks
./ralph.sh spec -p "Add dark mode toggle"

# Build mode executes tasks directly from spec
./ralph.sh build -s ./specs/dark-mode-toggle.json

# Optional: generate human-readable plan
./ralph.sh plan -s ./specs/dark-mode-toggle.json
```

## Tasks vs userStories

| Format          | Primary Use                   | Build Mode Workflow                |
| --------------- | ----------------------------- | ---------------------------------- |
| **tasks**       | Recommended for new specs     | Works directly from spec           |
| **userStories** | Legacy/backward compatible    | Requires plan mode for checklist   |

Both work with Ralph. Tasks format is recommended as it eliminates the plan step and makes specs the single source of truth.

# Ralph Loop

Autonomous Claude Code runner for iterative development. See [docs/RALPH_LOOP_REF.md](docs/RALPH_LOOP_REF.md) for full documentation.

## Quick Start

```bash
# Inline — quick fixes (sonnet, no spec needed)
./ralph.sh -p "Fix lint errors" 3       # Simple fix, 3 iterations
./ralph.sh -p "Add favicon" 1           # Trivial change, 1 iteration

# Launch — features (generates spec, then builds)
./ralph.sh launch -p "Add dark mode"
./ralph.sh launch -p "Build user auth with OAuth"

# Launch with product discovery (only when you need it)
./ralph.sh launch --full-product -p "Build a new SaaS app"

# Manual control — generate spec, review it, then build
./ralph.sh spec -p "Add dark mode"
./ralph.sh build -s ./specs/dark-mode.json

# Review — codebase analysis
./ralph.sh review                       # Review src/* for all categories
./ralph.sh review --diff-base main      # Only changed files since main

# Other
./ralph.sh plan -s ./specs/feature.json # Human-readable plan (optional)
./ralph.sh product                      # Product artifact generation (12 docs)
./ralph.sh --dry-run                    # Preview config without running
./ralph.sh --resume                     # Resume interrupted session
```

## Modes

| Mode        | Purpose                                               | Command              |
| ----------- | ----------------------------------------------------- | -------------------- |
| **inline**  | Quick fixes and simple changes (sonnet, no spec)       | `./ralph.sh -p "…"`  |
| **launch**  | Features: generates spec → builds (default for features) | `./ralph.sh launch`  |
| **spec**    | Generate spec only (for manual review before building) | `./ralph.sh spec`    |
| **build**   | Execute tasks from an existing spec                    | `./ralph.sh build`   |
| **review**  | Codebase analysis producing findings + report          | `./ralph.sh review`  |
| **plan**    | Human-readable plan from spec tasks (optional)         | `./ralph.sh plan`    |
| **product** | Generate product documentation (12 artifacts)          | `./ralph.sh product` |
| **setup**   | Configure host project integration                     | `./ralph.sh setup`   |

**Quick fixes → inline. Features → launch.** Use `spec` + `build` separately when you want to review the spec before building. Launch skips product by default — it only runs product when `--full-product` is set or `product-input/` has content.

## Host Project Integration

Ralph-starter can be used as a git submodule in any project. It auto-detects the host project and adjusts paths so Claude operates on host code while artifacts stay in `ralph-starter/`.

```bash
# Setup in a host project
git submodule add <url> ralph-starter
./ralph-starter/ralph.sh setup              # Symlink skills
./ralph-starter/ralph.sh setup --with-config  # Also generate host ralph.conf

# Run from host project root
./ralph-starter/ralph.sh build -s ./ralph-starter/specs/feature.json
./ralph-starter/ralph.sh spec -p "Add feature"

# Override detection
RALPH_HOST_ROOT="" ./ralph.sh build  # Force standalone mode
```

See [docs/RALPH_LOOP_REF.md](docs/RALPH_LOOP_REF.md) for full host project documentation.

## Prompt Files

- `./prompts/PROMPT_spec.md` - Spec generation from various inputs
- `./prompts/PROMPT_plan.md` - Architecture and planning tasks (optional when using tasks)
- `./prompts/PROMPT_build.md` - Implementation tasks
- `./prompts/PROMPT_product.md` - Product artifact generation
- `./prompts/PROMPT_review.md` - Codebase analysis and review

## Completion Marker

When all tasks are complete, output `<ralph>COMPLETE</ralph>` to signal the loop to stop.

# Specs

- `./specs/INDEX.md` - Feature catalog
- `./specs/{feature}.md` - Feature specification (the "what & why")

# Plans

- `./plans/IMPLEMENTATION_PLAN.md` - Task checklist (the "how")

# Product Artifacts

- `./product-input/` - Context files for product mode (vision, research, requirements)
- `./product-output/` - Generated artifacts (12 documents)
- `./docs/PRODUCT_ARTIFACT_SPEC.md` - Artifact specifications

# Progress

- `./progress.txt` - Iteration history
