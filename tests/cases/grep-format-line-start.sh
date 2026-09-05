#!/usr/bin/env bash
# `#:config (hash "program" "grep")` parses path:line:text (no column) rows
# and lands at line start.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep-grep" FORMAT=grep

send ":grep" Enter
wait_for "grep: "
send "x"
wait_for "tests/fixtures/tree/utf8.txt:2:line two TODO"
send Enter
wait_for_status "2:1"
