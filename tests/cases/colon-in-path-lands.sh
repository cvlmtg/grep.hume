#!/usr/bin/env bash
# A path containing a literal ':' parses and Enter lands in it — the
# NUL-terminated 'vimgrep-null shape (default when "program" is rg-shaped)
# doesn't share 'vimgrep's colon-in-path limitation.
#
# ':' is illegal in Windows/NTFS filenames, so the fixture is created here
# rather than committed to the repo — a committed one broke `git pull` on
# Windows checkouts.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

case "$(uname -s)" in
MINGW* | MSYS* | CYGWIN*)
    echo "skip: ':' in filenames isn't supported on this filesystem" >&2
    exit 0
    ;;
esac

COLON_FIXTURE="$FIXTURES_DIR/tree/weird:file.txt"
echo "colon path line one" >"$COLON_FIXTURE"

# start_hume itself arms `trap stop_hume EXIT`, which would clobber a trap
# set before this call — so the fixture cleanup is chained onto it after.
start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$FIXTURES_DIR/bin/fakegrep-colon" FORMAT=vimgrep-null
trap 'stop_hume; rm -f "$COLON_FIXTURE"' EXIT

send ":grep" Enter
wait_for "grep: "
send "x"
wait_for "colon path TODO"
send Enter
wait_for_status "weird:file.txt"
wait_for_status "1:1"
