#!/usr/bin/env bash
# A very long minified line: the displayed row is truncated, but on-select
# still receives the untruncated payload, so Enter must land on the exact
# column even though it's past where the display was clipped.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep-long" FORMAT=vimgrep-null

send ":grep" Enter
wait_for "grep: "
send "x"
wait_for "aaaaaaaaaa"
expect_absent "TODO"
send Enter
wait_for_status "1:91"
