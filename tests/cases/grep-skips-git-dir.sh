#!/usr/bin/env bash
# The real `grep`'s default "args" don't descend into .git. The query names
# a key only .git/config holds; its bracket keeps this script from matching.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

if [[ ! -d "$REPO_ROOT/.git" ]]; then
    echo "grep-skips-git-dir: $REPO_ROOT/.git is not a directory — run from a regular clone" >&2
    exit 1
fi

start_hume config/grep.scm "$FIXTURES_DIR/tree/scratch.txt"

# The search runs at all: a fixture line shows up.
send ":grep" Enter
wait_for "grep: "
send "line tw[o]"
wait_for "./tests/fixtures/tree/utf8.txt:2:line two"

send Escape
send ":grep" Enter
wait_for "grep: "
send "repositoryformatversio[n]"
sleep 0.5 # let the debounced search run and exit
expect_absent "./.git/config:"
