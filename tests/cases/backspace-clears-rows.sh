#!/usr/bin/env bash
# Backspace to empty mid-search — rows clear and stay cleared, no stale
# refill.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep" FORMAT=vimgrep-null

send ":grep" Enter
wait_for "grep: "
send "x"
wait_for "héllo world TODO"

send BSpace
wait_for "0/0" 2
expect_absent "héllo world TODO"
