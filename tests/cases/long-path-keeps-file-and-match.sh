#!/usr/bin/env bash
# A row whose directory alone is wider than the picker drops the front of
# the directory, so the file name, location and match text stay visible.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume config/styled.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep-deep" FORMAT=vimgrep-null

send ":grep" Enter
wait_for "grep: "
send "needle"
wait_for "│…"
wait_for "-directory-name/deep.txt:7:1:needle here│"
expect_absent "tests/fixtures/tree/a-rather"
