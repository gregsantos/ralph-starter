#!/usr/bin/env bats

# Unit tests for branch-change archiving in ralph.sh
#
# These tests isolate LAST_BRANCH_FILE, ARCHIVE_DIR, and PROGRESS_FILE to a
# per-test scratch directory so they NEVER touch the repo's real
# .ralph-last-branch, archive/, or progress.txt files.

setup() {
    source "$BATS_TEST_DIRNAME/test_helper.bash"

    SCRATCH="$(mktemp -d)"

    # Isolate all files the archiving code reads or writes.
    LAST_BRANCH_FILE="$SCRATCH/.ralph-last-branch"
    ARCHIVE_DIR="$SCRATCH/archive"
    PROGRESS_FILE="$SCRATCH/progress.txt"
    # Point spec/plan at nonexistent paths so they never contribute content
    # unless a test explicitly creates them.
    SPEC_FILE="$SCRATCH/nonexistent-spec.json"
    PLAN_FILE="$SCRATCH/nonexistent-plan.md"
}

teardown() {
    [ -n "$SCRATCH" ] && rm -rf "$SCRATCH"
}

# ─────────────────────────────────────────────────────────────────────────────
# check_branch_change
# ─────────────────────────────────────────────────────────────────────────────

@test "check_branch_change: no branch file writes current branch and does not archive" {
    CURRENT_BRANCH="branch-a"
    [ ! -f "$LAST_BRANCH_FILE" ]

    check_branch_change

    # Last-branch file now records the current branch.
    [ -f "$LAST_BRANCH_FILE" ]
    [[ "$(cat "$LAST_BRANCH_FILE")" == "branch-a" ]]
    # Nothing was archived.
    [ ! -d "$ARCHIVE_DIR" ]
}

@test "check_branch_change: unchanged branch does not archive" {
    CURRENT_BRANCH="branch-a"
    printf '%s\n' "branch-a" > "$LAST_BRANCH_FILE"
    # Content exists that *could* be archived if the branch had changed.
    printf 'original progress\n' > "$PROGRESS_FILE"

    check_branch_change

    # No archive because the branch is unchanged.
    [ ! -d "$ARCHIVE_DIR" ]
    # Progress left untouched.
    [[ "$(cat "$PROGRESS_FILE")" == "original progress" ]]
    [[ "$(cat "$LAST_BRANCH_FILE")" == "branch-a" ]]
}

@test "check_branch_change: changed branch archives and resets progress" {
    CURRENT_BRANCH="new-branch"
    printf '%s\n' "old-branch" > "$LAST_BRANCH_FILE"
    printf 'original progress\n' > "$PROGRESS_FILE"

    check_branch_change

    local subdir="${ARCHIVE_DIR}/$(date +%Y-%m-%d)-old-branch"
    # Archive directory was created for the previous branch.
    [ -d "$subdir" ]
    # The old progress was preserved in the archive.
    [[ "$(cat "$subdir/progress.txt")" == "original progress" ]]
    # progress.txt was reset for the new branch.
    grep -q "# Progress for branch: new-branch" "$PROGRESS_FILE"
    # Last-branch file updated to the new branch.
    [[ "$(cat "$LAST_BRANCH_FILE")" == "new-branch" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# archive_branch_state
# ─────────────────────────────────────────────────────────────────────────────

@test "archive_branch_state: leaves progress.txt intact when the copy fails" {
    CURRENT_BRANCH="new-branch"
    printf 'original progress\n' > "$PROGRESS_FILE"

    # Force the cp to fail: pre-create a regular file exactly where the archive
    # subdirectory would be, so mkdir -p and the subsequent cp both fail.
    mkdir -p "$ARCHIVE_DIR"
    local subdir="${ARCHIVE_DIR}/$(date +%Y-%m-%d)-old-branch"
    printf 'blocker\n' > "$subdir"

    run archive_branch_state "old-branch"

    # The copy target is not a directory, so nothing was archived...
    [ ! -d "$subdir" ]
    # ...and progress.txt must NOT have been truncated/reset.
    [[ "$(cat "$PROGRESS_FILE")" == "original progress" ]]
    ! grep -q "# Progress for branch" "$PROGRESS_FILE"
}
