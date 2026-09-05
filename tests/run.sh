#!/usr/bin/env bash
# tests/run.sh — discovers and runs tests/cases/*.sh against a real `hume`
# under tmux. Each case runs as its own subprocess so one crash can't take
# down the rest.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

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
for case_file in cases/*.sh; do
    name="$(basename "$case_file" .sh)"
    if bash "$case_file"; then
        echo "PASS $name"
        ((pass++))
    else
        echo "FAIL $name"
        ((fail++))
    fi
done

echo
echo "$pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
