#!/usr/bin/env bash
# Esc mid-search dismisses the picker and kills the still-running search
# process, rather than letting it run to completion in the background.
#
# Proven via a filesystem side effect rather than a process check: the
# fixture writes a marker file only if it runs to completion (3s sleep); if
# Esc actually killed it, the marker must still be missing once that same
# window has fully elapsed.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
MARKER="$SCRATCH/done"
WRAPPER="$SCRATCH/slowgrep"
cat > "$WRAPPER" <<EOF
#!/usr/bin/env bash
trap 'exit 143' TERM
sleep 3
echo done > "$MARKER"
EOF
chmod +x "$WRAPPER"

start_hume config/fake.scm "$FIXTURES_DIR/tree/scratch.txt" \
    PROGRAM="$WRAPPER" FORMAT=vimgrep-null

send ":grep" Enter
wait_for "grep: "
send "x"
# No observable signal that the debounced spawn has actually happened yet —
# wait out the plugin's default 120ms debounce plus margin before dismissing.
sleep 0.3
send Escape

# If Esc didn't kill it, the marker appears once the fixture's own 3s sleep
# elapses. Poll for its whole lifetime rather than a single fixed sleep, so
# a genuine failure is caught as soon as it happens instead of only at the
# very end.
deadline=$(($(date +%s) + 4))
while [[ "$(date +%s)" -lt "$deadline" ]]; do
    if [[ -e "$MARKER" ]]; then
        echo "slowgrep was not killed by Esc — marker file exists" >&2
        exit 1
    fi
    sleep 0.2
done
