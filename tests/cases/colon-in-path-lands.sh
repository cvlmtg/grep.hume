#!/usr/bin/env bash
# A path containing a literal ':' parses and Enter lands in it — the
# NUL-terminated 'vimgrep-null shape (default when "program" is rg-shaped)
# doesn't share 'vimgrep's colon-in-path limitation.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep-colon" FORMAT=vimgrep-null

send ":grep" Enter
wait_for "grep: "
send "x"
wait_for "colon path TODO"
send Enter
wait_for_status "weird:file.txt"
wait_for_status "1:1"
