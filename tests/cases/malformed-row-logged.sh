#!/usr/bin/env bash
# A malformed row (a non-numeric line field) logs the row and jumps
# nowhere, rather than raising — proven by the log banner itself appearing
# in place of a successful jump, and by the message surviving in :messages
# afterward.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/badgrep" FORMAT=vimgrep-null

send ":grep" Enter
wait_for "grep: "
send "x"
wait_for "broken row"
send Enter
wait_for "picker-grep: could not parse result row"

send "l" # dismiss the inline banner
wait_for_status "error"

send ":messages" Enter
wait_for "picker-grep: could not parse result row"
