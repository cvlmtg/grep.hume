#!/usr/bin/env bash
# The one case that runs against the real rg (every other case fixes the
# search program's output so it doesn't drift with rg's version) — catches
# drift in the actual default argv, and checks --smart-case: a lowercase
# pattern matches an uppercase occurrence, and adding an uppercase
# character narrows the match back to exact case. Also checks that a line
# with several matches shows as a single row.
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

# A line matching twice is one row, landing on its first match. The
# bracket keeps this script from matching the pattern, so the only rows
# are the fixture's.
send Escape
send ":grep" Enter
wait_for "grep: "
send "zebrafis[h]"
wait_for "tree/repeat.txt:1:1:"
sleep 0.3 # a second row from the same search would already have landed
expect_absent "tree/repeat.txt:1:11:"
