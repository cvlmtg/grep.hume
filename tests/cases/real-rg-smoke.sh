#!/usr/bin/env bash
# The one case that runs against the real rg (every other case fixes the
# search program's output so it doesn't drift with rg's version) — catches
# drift in the actual default argv, and checks --smart-case: a lowercase
# pattern matches an uppercase occurrence, and adding an uppercase
# character narrows the match back to exact case.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

if ! command -v rg >/dev/null 2>&1; then
    echo "real-rg-smoke: rg is not on PATH — install it to run this case" >&2
    exit 1
fi

start_hume config/default.scm "$FIXTURES_DIR/tree/scratch.txt"

send ":grep" Enter
wait_for "grep: "
send "unfin"
wait_for "Unfinished business"
wait_for "unfinished paperwork"

send BSpace BSpace BSpace BSpace BSpace
send "Unfin"
sleep 0.3 # let the debounced re-search actually run and land
wait_for "Unfinished business"
expect_absent "unfinished paperwork"
