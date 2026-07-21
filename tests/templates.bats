#!/usr/bin/env bats

# Tests for plugin/templates/*.json — the ralph init starter templates.
# Every template must parse as valid JSON and expose the required
# defaultBudgets defaults and reviewFocus categories (see issue #15).

TEMPLATES_DIR="$BATS_TEST_DIRNAME/../plugin/templates"

@test "templates: at least one template exists" {
    run bash -c 'ls "$0"/*.json' "$TEMPLATES_DIR"
    [[ "$status" -eq 0 ]]
    [[ -n "$output" ]]
}

@test "templates: every *.json parses as valid JSON" {
    for f in "$TEMPLATES_DIR"/*.json; do
        run jq . "$f"
        [[ "$status" -eq 0 ]] || {
            echo "invalid JSON: $f"
            echo "$output"
            return 1
        }
    done
}

@test "templates: every template has the required defaultBudgets defaults" {
    for f in "$TEMPLATES_DIR"/*.json; do
        run jq -e '
            .defaultBudgets
            | has("buildTurnsFactor") and has("buildHours")
              and has("improveTurns") and has("improveUsd")
              and has("improveFindings")
        ' "$f"
        [[ "$status" -eq 0 ]] || {
            echo "missing defaultBudgets keys: $f"
            echo "$output"
            return 1
        }
    done
}

@test "templates: every template has a non-empty reviewFocus array" {
    for f in "$TEMPLATES_DIR"/*.json; do
        run jq -e '.reviewFocus | type == "array" and length > 0' "$f"
        [[ "$status" -eq 0 ]] || {
            echo "invalid reviewFocus: $f"
            echo "$output"
            return 1
        }
    done
}
