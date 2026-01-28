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

# Ralph Loop

Autonomous Claude Code runner for iterative development. See [docs/RALPH_LOOP_REF.md](docs/RALPH_LOOP_REF.md) for full documentation.

## Quick Start

```bash
./ralph.sh                              # Build mode, opus, 10 iterations (default)
./ralph.sh plan 5                       # Plan mode, 5 iterations
./ralph.sh -p "Fix lint errors" 3       # Inline prompt, 3 iterations
./ralph.sh -f prompts/review.md         # Custom prompt file
./ralph.sh build --model sonnet         # Build with sonnet
./ralph.sh --no-push                    # Disable auto-push
./ralph.sh --unlimited                  # Remove iteration limit (careful!)
./ralph.sh --dry-run                    # Preview config without running
./ralph.sh -s ./specs/feature.md        # Custom spec (plan auto-derived)
```

## Prompt Files

- `./prompts/PROMPT_plan.md` - Architecture and planning tasks
- `./prompts/PROMPT_build.md` - Implementation tasks

## Completion Marker

When all tasks are complete, output `<ralph>COMPLETE</ralph>` to signal the loop to stop.

# Specs

- `./specs/INDEX.md` - Feature catalog
- `./specs/{feature}.md` - Feature specification (the "what & why")

# Plans

- `./plans/IMPLEMENTATION_PLAN.md` - Task checklist (the "how")

# Progress

- `./progress.txt` - Iteration history
