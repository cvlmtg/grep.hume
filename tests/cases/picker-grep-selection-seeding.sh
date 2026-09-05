#!/usr/bin/env bash
# `g /` seeds from a one-line, non-collapsed selection — including one
# extended through the trailing newline (x/X/Ctrl+x). A bare cursor or a
# multi-line selection opens the picker empty instead.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

# --- one-line selection through the trailing newline seeds the query ------
# Needs utf8.txt's real multi-byte line 3 — the "héllo" is what exercises
# the clamp this scenario is really about.
start_hume config/fake.scm "$FIXTURES_DIR/tree/utf8.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep" FORMAT=vimgrep-null
send "jj"  # line 1 -> line 3 ("héllo world TODO")
send "x"
send "g/"
wait_for "grep: héllo world TODO"

send Escape
send ":messages" Enter
expect_absent "index out of bounds"
stop_hume

# --- a bare (collapsed) cursor opens the picker empty ----------------------
# scratch.txt here (not utf8.txt) so its content can't coincidentally
# contain the fixture's own canned row text and produce a false pass.
start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep" FORMAT=vimgrep-null
send "g/"
wait_for "grep: "
wait_for "0/0"
expect_absent "héllo world TODO"
stop_hume

# --- a multi-line selection also opens the picker empty --------------------
start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep" FORMAT=vimgrep-null
send C-x
send C-x
send "g/"
wait_for "grep: "
wait_for "0/0"
expect_absent "héllo world TODO"
