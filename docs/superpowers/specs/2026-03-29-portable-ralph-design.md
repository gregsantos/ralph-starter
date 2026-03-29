# Portable Ralph: Host Project Integration Design

## Context

Ralph-starter is a bash-based autonomous Claude Code runner with seven modes (dev, launch, spec, plan, build, product, review). Currently it assumes it IS the project — all paths resolve relative to CWD, which must be the project root. This design makes ralph portable so it can be cloned into any project as a git submodule and operate on the host project's code while keeping its own artifacts (specs, plans, progress) self-contained.

**Problem**: When ralph-starter lives as a subdirectory (e.g., `my-app/ralph-starter/`), the Claude CLI, git operations, and source code analysis all need to target the parent project — not ralph-starter itself.

**Primary user**: Single developer who changes ralph frequently. Simplicity over ceremony.

## Design

### 1. Host Project Auto-Detection

Add a detection block in `ralph.sh` immediately after `SCRIPT_DIR` is set (line ~1018).

**Logic**:
1. From `SCRIPT_DIR`, walk up to find the enclosing git repo root: `git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel`
2. If a parent root exists AND differs from SCRIPT_DIR, set `HOST_ROOT` and `RALPH_SUBDIR` (the relative path from host root to ralph-starter, e.g., `ralph-starter`)
3. `cd "$HOST_ROOT"` — all subsequent operations (Claude CLI, git, file creation) target the host project
4. When no parent repo is found, `HOST_ROOT` is empty and behavior is unchanged (standalone mode)

**Override**: `RALPH_HOST_ROOT` env var. Set to a path to force a specific host root, or set to empty string (`RALPH_HOST_ROOT=""`) to force standalone mode even inside a parent repo.

**Edge cases**:
- Ralph cloned inside a monorepo subdirectory: detection finds the monorepo root. If that's wrong, use `RALPH_HOST_ROOT` override.
- Nested git repos (submodule of a submodule): detection finds the immediate parent, which is correct.
- Running ralph.sh from a different CWD than the host root: detection uses SCRIPT_DIR's parent, not CWD, so it's CWD-independent.

### 2. Path Rebasing

When `HOST_ROOT` is set, all CWD-relative defaults get the `$RALPH_SUBDIR/` prefix so artifacts land inside ralph-starter:

| Variable | Standalone Default | Submodule Default |
|---|---|---|
| `SPEC_FILE` | `./specs/IMPLEMENTATION_PLAN.md` | `./$RALPH_SUBDIR/specs/IMPLEMENTATION_PLAN.md` |
| `PLAN_FILE` | `./plans/IMPLEMENTATION_PLAN.md` | `./$RALPH_SUBDIR/plans/IMPLEMENTATION_PLAN.md` |
| `PROGRESS_FILE` | `progress.txt` | `./$RALPH_SUBDIR/progress.txt` |
| `PRODUCT_CONTEXT_DIR` | `./product-input/` | `./$RALPH_SUBDIR/product-input/` |
| `PRODUCT_OUTPUT_DIR` | `./product-output/` | `./$RALPH_SUBDIR/product-output/` |
| `ARTIFACT_SPEC_FILE` | `./docs/PRODUCT_ARTIFACT_SPEC.md` | `./$RALPH_SUBDIR/docs/PRODUCT_ARTIFACT_SPEC.md` |
| Session files | `.ralph-session.json` | `./$RALPH_SUBDIR/.ralph-session.json` |
| Dev session | `.ralph-dev-session.json` | `./$RALPH_SUBDIR/.ralph-dev-session.json` |
| Launch session | `.ralph-launch-session.json` | `./$RALPH_SUBDIR/.ralph-launch-session.json` |

**Unchanged** (already correct in both modes):
- `SOURCE_DIR` stays `src/*` — resolves to host project source from host CWD
- `REVIEW_TARGET` stays `src/*` — same reasoning
- Prompts use `$SCRIPT_DIR/prompts/` — absolute, always correct
- Archive uses `$SCRIPT_DIR/archive/` — absolute, always correct
- Last-branch marker uses `$SCRIPT_DIR/.ralph-last-branch` — absolute, always correct
- Log dir uses `~/.ralph/logs/` — home-relative, always correct

**Spec/dev/launch mode output**: Spec, dev, and launch modes generate spec files using `${SCRIPT_DIR}/specs/{slug}.json` (absolute path via `slugify_text` at line ~2994). This already resolves inside ralph-starter — no rebasing needed. However, the `SPEC_MODE_OUTPUT_FILE` variable and the `-o` CLI flag use CWD-relative paths, so those defaults need rebasing when in submodule mode.

**Review mode output**: `mkdir -p` for review-output already uses `$SCRIPT_DIR` in some codepaths but CWD-relative in others. Normalize to always create inside `$RALPH_SUBDIR/review-output/` when in submodule mode.

### 3. Host-Level ralph.conf

Support a `ralph.conf` in the host project root (CWD) with **higher priority** than ralph-starter's own config:

**New precedence**: CLI flags > env vars > **host ralph.conf** (CWD) > SCRIPT_DIR ralph.conf > global ~/.ralph/config > built-in defaults

**Implementation**: After loading `$SCRIPT_DIR/ralph.conf`, check for `$(pwd)/ralph.conf`. If it exists and differs from SCRIPT_DIR's config, load it. Values from the host config override ralph-starter's defaults.

**Use case**: Projects with non-standard source directories (e.g., `SOURCE_DIR=lib/*` instead of `src/*`), or teams that want to override iteration counts, model selection, etc.

**Generation**: `ralph.sh setup` can optionally generate a commented-out template at `./ralph.conf` in the host root.

### 4. Setup Command

New `ralph.sh setup` subcommand for one-time host project integration.

**What it does**:

1. **Detect HOST_ROOT** using the same logic as runtime detection
2. **Symlink skills**: For each skill in `$SCRIPT_DIR/.claude/skills/*/`:
   - Create `$HOST_ROOT/.claude/skills/` directory if needed
   - Create relative symlink: `$HOST_ROOT/.claude/skills/{name}` → `../$RALPH_SUBDIR/.claude/skills/{name}`
   - Relative paths ensure portability across machines
3. **Generate host ralph.conf** (optional, with `--with-config` flag):
   - Create `$HOST_ROOT/ralph.conf` with commented-out overrides
   - Include SOURCE_DIR, MODEL, MAX_ITERATIONS, and mode-specific paths
4. **Print usage instructions**: Show example commands for the host project context

**Invocation**:
```bash
cd my-host-project
./ralph-starter/ralph.sh setup              # Symlinks skills only
./ralph-starter/ralph.sh setup --with-config  # Also generates host ralph.conf
```

**Idempotent**: Running setup again refreshes symlinks and regenerates config (if requested). Existing host ralph.conf is not overwritten unless `--force` is used.

**Sharing via git**: Symlinks are committed to the host repo. Collaborators who clone with `--recurse-submodules` get working symlinks immediately — no per-developer setup needed.

### 5. Skill Enhancement for Host-Awareness

Update the two existing skills (`writing-ralph-specs`, `reviewing-codebase`) to work correctly when invoked from a host project via Claude Code (not via ralph.sh).

**Detection in skills**: Skills check for `ralph-starter/` (or configurable subdir name) in the project structure. If found, they adjust their output paths accordingly.

**Changes to `writing-ralph-specs/SKILL.md`**:
- Add a "Host Project Mode" section explaining path resolution
- Instruct Claude to check if a ralph-starter subdirectory exists
- If yes: write specs to `ralph-starter/specs/`, read source from project root
- If no: use current paths (backward compatible)

**Changes to `reviewing-codebase/SKILL.md`**:
- Same host detection logic
- Write findings to `ralph-starter/review-output/`
- Analyze source code from project root

**No new skills needed**: The existing two skills handle their respective domains. The prompts (PROMPT_build.md, PROMPT_plan.md, PROMPT_product.md) are only used via ralph.sh, which handles path substitution — they don't need skill-level changes.

### 6. CLAUDE.md Separation

**Ralph-starter's CLAUDE.md** remains as-is — it documents ralph's own conventions (TypeScript patterns, Next.js conventions, etc.) and is only relevant when developing ralph itself.

**Host project's CLAUDE.md** is untouched by ralph. When Claude operates via ralph.sh, the prompts contain all ralph-specific context (spec format, completion markers, iteration workflow). Claude reads the host's CLAUDE.md for the host project's coding conventions.

**No merging or concatenation**: The prompt files are the bridge between ralph's workflow and the host project's conventions.

### 7. Git Operations

All git operations (commit, push, branch creation) happen in the host project's repo because CWD is set to HOST_ROOT. This is the desired behavior — ralph is building features in the host project.

The archive and last-branch tracking (which use `$SCRIPT_DIR` paths) continue to write inside ralph-starter — they're ralph's internal state, not host project state.

**Submodule commits**: Changes to ralph-starter's internal files (spec status updates, progress.txt) modify the submodule. Git tracks these as submodule changes in the host repo. Ralph's auto-commit in build mode will commit both host code changes AND submodule state changes together — this is correct and desirable.

## Files to Modify

### ralph.sh (~100 lines of changes)
- Add host detection block after SCRIPT_DIR (lines ~1018-1040)
- Add path rebasing in defaults section (lines ~2669-2676)
- Add session file path rebasing (lines ~185, 1051)
- Add SPEC_MODE_OUTPUT_FILE default rebasing for `-o` flag (spec mode)
- Add review output path rebasing (line ~2749)
- Add host ralph.conf loading in config chain (lines ~2611)
- Add `setup` subcommand handler (~40 lines)
- Add `--with-config` flag parsing

### ralph.conf
- Add comments documenting host project override capability

### .claude/skills/writing-ralph-specs/SKILL.md
- Add "Host Project Mode" section with path detection logic

### .claude/skills/reviewing-codebase/SKILL.md
- Add "Host Project Mode" section with path detection logic

### New files
- None required. All changes are to existing files.

## Verification Plan

### Unit verification
1. Run `ralph.sh --dry-run` in standalone mode — confirm all paths resolve to ralph-starter root
2. Create a test host project with ralph-starter as submodule
3. Run `ralph.sh setup` from host project — confirm symlinks created correctly
4. Run `ralph.sh --dry-run` from host project — confirm paths rebase to `ralph-starter/` for artifacts and stay at host root for source
5. Verify `RALPH_HOST_ROOT=""` forces standalone mode

### Integration verification
1. Run `ralph.sh spec -p "Test feature"` from host project — confirm spec lands in `ralph-starter/specs/`
2. Run `ralph.sh build -s ./ralph-starter/specs/test.json` — confirm Claude operates on host project code
3. Verify git commits happen in host project repo
4. Verify git push works correctly
5. Test with host-level `ralph.conf` overriding SOURCE_DIR

### Skill verification
1. Open Claude Code in host project directory
2. Invoke `/writing-ralph-specs` skill — confirm it detects host mode and uses correct paths
3. Invoke `/reviewing-codebase` skill — confirm findings go to `ralph-starter/review-output/`

### Collaborator verification
1. Clone host project with `--recurse-submodules`
2. Verify `.claude/skills/` symlinks resolve correctly
3. Run `ralph.sh build` without running setup — confirm it works
