#!/usr/bin/env bash
# Enter lands on the exact column on a line with a multi-byte character
# before the match — the fixture row's byte-col 14 (rg's unit) must resolve
# to displayed column 13 once "é" (2 UTF-8 bytes, 1 char) is accounted for.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep" FORMAT=vimgrep-null

send ":grep" Enter
wait_for "grep: "
send "x"
wait_for "héllo world TODO"
send Enter
wait_for_status "3:13"
