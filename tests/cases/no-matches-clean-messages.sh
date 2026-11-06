#!/usr/bin/env bash
# A pattern with no matches (rg's own exit-1 convention) logs nothing:
# :messages answers "No messages" instead of opening the log.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep-empty" FORMAT=vimgrep-null

send ":grep" Enter
wait_for "grep: "
send "x"
wait_for "0/0"
# "0/0" is indistinguishable from "hasn't searched yet" — there's no
# observable signal that the debounced search actually ran and exited, so
# wait out the plugin's default 120ms debounce plus margin before checking
# :messages for what that run might have logged.
sleep 0.3

send Escape
send ":messages" Enter
wait_for_status "No messages"
