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
│   └── PROMPT_product.md         # Product artifact generation
├── specs/
│   ├── INDEX.md                  # Feature catalog
│   ├── {feature}.json            # JSON specs (recommended)
│   └── {feature}.md              # Markdown specs (alternative)
├── plans/
│   └── IMPLEMENTATION_PLAN.md    # Task checklist
├── .claude/
│   └── skills/
│       └── writing-ralph-specs/  # Skill for creating JSON specs
├── product-input/                # Product context files
├── product-output/               # Generated artifacts
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
- Spec mode (`./ralph.sh spec`) automatically uses the writing-ralph-specs skill

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
# Launch mode (one-shot: product optional -> spec -> build)
./ralph.sh launch -p "Add dark mode"
./ralph.sh launch --full-product -p "Build a new SaaS app"
./ralph.sh launch --skip-product -p "Ship a small docs-only enhancement"
./ralph.sh launch --skip-product --launch-buffer 8 -p "Build a Kanban board"

# Spec mode (generate specs)
./ralph.sh spec -p "Add dark mode"      # From inline description
./ralph.sh spec -f ./requirements.md    # From requirements file
./ralph.sh spec --from-product          # From product artifacts

# Build mode (implement from spec)
./ralph.sh                              # Build mode, opus, 10 iterations (default)
./ralph.sh build -s ./specs/feature.json  # Build from specific spec
./ralph.sh build --model sonnet         # Build with sonnet

# Other modes and options
./ralph.sh plan -s ./specs/feature.json # Generate human-readable plan (optional)
./ralph.sh product                      # Product artifact generation (12 docs)
./ralph.sh -p "Fix lint errors" 3       # Inline prompt, 3 iterations
./ralph.sh --no-push                    # Disable auto-push
./ralph.sh --dry-run                    # Preview config without running
./ralph.sh --resume                     # Resume interrupted session
./ralph.sh -i                           # Interactive mode (confirm between iterations)
```

## Five Modes

| Mode        | Purpose                                         | Command              |
| ----------- | ----------------------------------------------- | -------------------- |
| **launch**  | One-shot pipeline: product(optional) -> spec -> build | `./ralph.sh launch` |
| **spec**    | Generate specs from input/files/product         | `./ralph.sh spec`    |
| **plan**    | Create human-readable plan (optional for tasks) | `./ralph.sh plan`    |
| **build**   | Execute tasks one at a time                     | `./ralph.sh build`   |
| **product** | Generate product documentation (12 artifacts)   | `./ralph.sh product` |

## Prompt Files

- `./prompts/PROMPT_spec.md` - Spec generation from various inputs
- `./prompts/PROMPT_plan.md` - Architecture and planning tasks (optional when using tasks)
- `./prompts/PROMPT_build.md` - Implementation tasks
- `./prompts/PROMPT_product.md` - Product artifact generation

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
