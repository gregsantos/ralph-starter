#!/usr/bin/env bash
# ralph-evidence.sh — deterministic evidence block for the Ralph goal evaluator.
# Usage: ralph-evidence.sh <spec.json> [--full]
# Exit: 0 evidence printed; 2 missing/invalid spec; 3 no verificationCommands.
set -euo pipefail

SPEC="${1:-}"
MODE="${2:-}"

fail() { echo "ralph-evidence: $2" >&2; exit "$1"; }

[[ -n "$SPEC" && -f "$SPEC" ]] || fail 2 "spec not found: ${SPEC:-<missing>}"
jq empty "$SPEC" 2>/dev/null || fail 2 "spec is not valid JSON: $SPEC"

VERIFY_COUNT=$(jq '(.context.verificationCommands // []) | length' "$SPEC")
[[ "$VERIFY_COUNT" -gt 0 ]] || fail 3 "context.verificationCommands is missing or empty — builds are unverifiable without it"

TOTAL=$(jq '.tasks | length' "$SPEC")
PASSED=$(jq '[.tasks[] | select(.passes == true)] | length' "$SPEC")
IN_PROGRESS=$(jq '[.tasks[] | select(.passes != true and .status == "in_progress")] | length' "$SPEC")
PENDING=$(jq '[.tasks[] | select(.passes != true and .status == "pending")] | length' "$SPEC")
BLOCKED=$(jq '[.tasks[] | select(.passes != true and .status == "blocked")] | length' "$SPEC")

echo "=== RALPH EVIDENCE ==="
echo "spec: $SPEC"
echo "tasks: $TOTAL total | $PASSED passed | $IN_PROGRESS in_progress | $PENDING pending | $BLOCKED blocked"

task_line='.tasks[] | (.id + " [" + (if .passes == true then "passed" else .status end) + "] " + .title)'
if [[ "$TOTAL" -le 12 ]]; then
    jq -r "$task_line" "$SPEC"
else
    echo "passed tasks omitted: $PASSED"
    jq -r ".tasks[] | select(.passes != true) | (.id + \" [\" + .status + \"] \" + .title)" "$SPEC"
fi

# --full verification runs are added in Task 5.

echo "verifier: $(jq -r '.verifier.verdict // "PENDING"' "$SPEC")"
echo "=== END RALPH EVIDENCE ==="
