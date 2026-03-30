#!/usr/bin/env bash
# test_helper.bash — Sourcing helper for ralph.sh tests
#
# Sets RALPH_TESTING=true before sourcing ralph.sh so that all top-level
# execution (host detection, arg parsing, config loading, main loop) is
# skipped. Only function definitions and constant arrays are evaluated.

export RALPH_TESTING=true

# Determine ralph.sh location relative to this helper
RALPH_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/ralph.sh"

# Set minimal globals that functions may reference
# (normally set during guarded initialization blocks)
SCRIPT_DIR="$(cd "$(dirname "$RALPH_SH")" && pwd)"
RALPH_SUBDIR=""
HOST_ROOT=""
PIPELINE_BUFFER=5
MODE="build"
PRESET_NAME="build"
VERBOSE=false
CLI_INLINE_PROMPT=""
CLI_FILE_PATH=""

# Source ralph.sh — with RALPH_TESTING=true, only functions and constants load
source "$RALPH_SH"
