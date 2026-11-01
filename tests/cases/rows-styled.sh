#!/usr/bin/env bash
# A row shows its directory, line, column and match in their scopes'
# colors, its file name in the default one, and its text without the
# indentation. On the selected row everything but the match takes the
# picker's selected style. Enter still lands on the match's column.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

DIR="$(fg 10 11 12)"
NUM="$(fg 13 14 15)"
MATCH="$(fg 16 17 18)"
FOCUS="$(fg 19 20 21)"

start_hume config/styled.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep-styled" FORMAT=vimgrep-null

send ":grep" Enter
wait_for "grep: "
send "todo"
wait_for "tests/fixtures/tree/indented.txt:2:9:let TODO = 1;"
wait_for_styled "${FOCUS}tests/fixtures/tree/indented.txt:2:9:let ${MATCH}TODO${FOCUS} = 1;"
wait_for_styled "${DIR}tests/fixtures/tree/${FG_DEFAULT}utf8.txt:${NUM}3${FG_DEFAULT}:${NUM}14${FG_DEFAULT}:héllo world ${MATCH}TODO${FG_DEFAULT}"
send Enter
wait_for_status "2:9"
