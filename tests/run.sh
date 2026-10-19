#!/usr/bin/env bash
# tests/run.sh [case-name ...] — runs tests/cases/*.sh, or only the named
# cases, against a real `hume` under tmux. Each case runs as its own
# subprocess so one crash can't take down the rest.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

case_files=(cases/*.sh)
if [[ "$#" -gt 0 ]]; then
    case_files=()
    for arg in "$@"; do
        case_file="cases/$(basename "$arg" .sh).sh"
        if [[ ! -f "$case_file" ]]; then
            echo "tests: no case named \"$arg\" in tests/cases/" >&2
            exit 1
        fi
        case_files+=("$case_file")
    done
fi

if ! command -v tmux >/dev/null 2>&1; then
    echo "tests: tmux is required — install it and re-run" >&2
    exit 1
fi

source ./lib.sh
hume_resolve
echo "hume: $(command -v hume) ($(hume --version))"
echo

pass=0
fail=0
for case_file in "${case_files[@]}"; do
    name="$(basename "$case_file" .sh)"
    if bash "$case_file"; then
        echo "PASS $name"
        # Assignment, not `((pass++))` — under this script's inherited
        # `set -e`, an arithmetic command returns the pre-increment value
        # as its exit status, so the very first increment (0) reads as a
        # failure and aborts the whole loop.
        pass=$((pass + 1))
    else
        echo "FAIL $name"
        fail=$((fail + 1))
    fi
done

echo
echo "$pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
