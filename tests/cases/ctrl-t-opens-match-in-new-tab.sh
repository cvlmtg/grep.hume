#!/usr/bin/env bash
# Ctrl-t (stdlib/buffer-actions, via #:actions) opens the selected match in a
# new tab instead of the current pane — the original pane/tab keeps showing
# scratch.txt, unmoved.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep" FORMAT=vimgrep-null

send ":grep" Enter
wait_for "grep: "
send "x"
wait_for "héllo world TODO"
send C-t
wait_for_status "3:13"
wait_for "utf8.txt"

# Confirm this landed in a *new* tab rather than the original pane: the
# previous tab must still show scratch.txt, untouched.
send C-p T
wait_for_status "scratch.txt"
