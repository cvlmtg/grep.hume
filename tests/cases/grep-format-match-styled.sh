#!/usr/bin/env bash
# The grep format reports no column, so the match highlighted is the
# pattern's occurrence in the row's text, compared without case as the
# default -i searches.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

MATCH="$(fg 16 17 18)"

start_hume config/styled.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep-grep" FORMAT=grep

send ":grep" Enter
wait_for "grep: "
send "todo"
wait_for "tests/fixtures/tree/utf8.txt:2:line two TODO"
wait_for_styled "line two ${MATCH}TODO"
