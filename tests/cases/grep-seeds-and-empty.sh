#!/usr/bin/env bash
# :grep opens empty; :grep TODO opens already seeded and searching; a result
# row reads path:line:col:text with no visible NUL placeholder.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep" FORMAT=vimgrep-null

send ":grep" Enter
wait_for "grep: "
wait_for "0/0"
expect_absent "héllo world TODO"

send "x"
wait_for "héllo world TODO"
wait_for "tests/fixtures/tree/utf8.txt:3:14:héllo world TODO"
expect_absent "<0>"

send Escape
send ":grep TODO" Enter
wait_for "grep: TODO"
wait_for "héllo world TODO"
