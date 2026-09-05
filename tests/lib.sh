#!/usr/bin/env bash
# tests/lib.sh — tmux driver shared by run.sh and every tests/cases/*.sh.
#
# These tests script a real interactive `hume` under tmux. Every case gets
# its own tmux session and its own hermetic $XDG_DATA_HOME with this working
# copy symlinked in as the installed plugin — a case never touches the real
# ~/.config/hume or ~/.local/share/hume.
#
# A case script sources this file, calls `start_hume`, drives the session
# with `send`/`wait_for`/`wait_for_status`/`expect_absent`, and relies on
# `set -euo pipefail` (set below) to turn any failed assertion into a
# non-zero exit — run.sh reads that exit code as pass/fail.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES_DIR="$REPO_ROOT/tests/fixtures"

# The only line to change when copying this scaffolding to another plugin.
PLUGIN_NAME="cvlmtg/grep.hume"

# ── Resolving which `hume` to drive ─────────────────────────────────────────
#
# Order: an explicit $HUME_BIN override, then $HUME_REPO (explicit), then
# `hume` on PATH (the default — matches CI and anyone with a release
# installed), then a sibling checkout at ../hume as a last-resort
# convenience for a dev machine that has both repos checked out side by side
# but no installed `hume`. Resolves to a PATH-prepended shim so every case
# can just invoke `hume` uniformly regardless of which branch fired.
#
# Called once by run.sh, never by a case script — the resolved PATH is
# inherited by every case subprocess, so cargo only builds once and the
# shim only needs cleaning up at run.sh's own exit.
hume_resolve() {
    local shim_dir bin runtime=""
    shim_dir="$(mktemp -d)"
    trap "rm -rf '$shim_dir'" EXIT # single quotes would defer expansion past hume_resolve's own scope

    if [[ -n "${HUME_BIN:-}" ]]; then
        bin="$HUME_BIN"
    elif [[ -n "${HUME_REPO:-}" ]]; then
        echo "tests: building hume from \$HUME_REPO ($HUME_REPO)..." >&2
        (cd "$HUME_REPO" && cargo build -p hume-editor) >&2
        bin="$HUME_REPO/target/debug/hume"
        runtime="$HUME_REPO/runtime"
    elif command -v hume >/dev/null 2>&1; then
        bin="$(command -v hume)"
    elif [[ -d "$REPO_ROOT/../hume" ]]; then
        local checkout="$REPO_ROOT/../hume"
        echo "tests: building hume from sibling checkout ($checkout)..." >&2
        (cd "$checkout" && cargo build -p hume-editor) >&2
        bin="$checkout/target/debug/hume"
        runtime="$checkout/runtime"
    else
        echo "tests: no hume found — set \$HUME_BIN, set \$HUME_REPO, put hume on PATH, or check out cvlmtg/hume next to this repo" >&2
        exit 1
    fi

    cat > "$shim_dir/hume" <<SHIM
#!/usr/bin/env bash
$([[ -n "$runtime" ]] && echo "export HUME_RUNTIME=\"$runtime\"")
exec "$bin" "\$@"
SHIM
    chmod +x "$shim_dir/hume"
    export PATH="$shim_dir:$PATH"
}

# ── Per-case session lifecycle ───────────────────────────────────────────────

# render_config <template> <out-file> [NAME=value ...]
#
# Substitutes @FIXTURES@ (this repo's tests/fixtures dir) and @PLUGIN@
# ($PLUGIN_NAME), plus any @NAME@ placeholder given as a NAME=value pair.
render_config() {
    local template="$1" out="$2"
    shift 2
    local expr="s|@FIXTURES@|$FIXTURES_DIR|g; s|@PLUGIN@|$PLUGIN_NAME|g" pair name value
    for pair in "$@"; do
        name="${pair%%=*}"
        value="${pair#*=}"
        expr+="; s|@${name}@|${value}|g"
    done
    sed -e "$expr" "$template" > "$out"
}

# _launch_hume <config-template> <input-file> [NAME=value ...] [-- extra hume args...]
#
# Renders <config-template> via render_config, stages a throwaway
# XDG_DATA_HOME with this working copy symlinked in as $PLUGIN_NAME, and
# launches hume under tmux with cwd pinned to the repo root — a relative
# fixture path, and the plugin's own search root if it has one, resolve
# against it. Sets $SESSION and $WORKDIR, and arms a trap so `stop_hume`
# always runs, pass or fail. Shared by start_hume and
# start_hume_expect_load_error, which differ only in how they wait for the
# first frame — see start_hume's doc.
_launch_hume() {
    local template="$1" input="$2"
    shift 2
    local subs=()
    while [[ "$#" -gt 0 && "$1" == *=* ]]; do
        subs+=("$1")
        shift
    done
    [[ "${1:-}" == "--" ]] && shift

    WORKDIR="$(mktemp -d)"
    local data_dir="$WORKDIR/data/hume"
    mkdir -p "$data_dir/plugins/${PLUGIN_NAME%/*}"
    ln -s "$REPO_ROOT" "$data_dir/plugins/$PLUGIN_NAME"
    export XDG_DATA_HOME="$WORKDIR/data"

    local config="$WORKDIR/init.scm"
    # ${subs[@]+"${subs[@]}"} rather than "${subs[@]}" — bash 3.2 (macOS's
    # /bin/bash) treats a `set -u` expansion of an empty array as unbound.
    render_config "$template" "$config" ${subs[@]+"${subs[@]}"}

    SESSION="grep-hume-test-$$-${RANDOM}"
    PANE_PID="" # cleared so a failed new-session below can't leave stop_hume killing a stale pid from an earlier scenario in this script
    trap stop_hume EXIT
    tmux new-session -d -s "$SESSION" -x 100 -y 30 -c "$REPO_ROOT" \
        hume --config "$config" "$input" "$@"
    PANE_PID="$(tmux list-panes -t "$SESSION" -F '#{pane_pid}')"
}

# start_hume <config-template> <input-file> [NAME=value ...] [-- extra hume args...]
#
# _launch_hume, then blocks until the first real frame renders (the input
# file's basename shows in the statusline) — without this, a case's first
# send-keys can race hume's startup and land before scripting/UI init
# finishes.
start_hume() {
    _launch_hume "$@"
    wait_for "$(basename "$2")" 10
    _wait_settled
}

# _wait_settled — blocks until the pane stops changing on its own.
#
# The first frame can render before startup work still running alongside it
# (terminal-capability probing, kitty keyboard negotiation) has finished —
# a keystroke sent into that window has been observed to land wrong. There's
# no single flag to wait on for "settled", so this polls for the pane
# rendering the same content across consecutive checks instead of guessing a
# fixed delay.
_wait_settled() {
    local timeout=10 start last=$'\x01' current # \x01 never matches a real frame
    start="$(date +%s)"
    while true; do
        current="$(tmux capture-pane -t "$SESSION" -p)"
        [[ "$current" == "$last" ]] && return 0
        last="$current"
        if (( $(date +%s) - start >= timeout )); then
            echo "TIMEOUT waiting for the pane to settle" >&2
            echo "$current" >&2
            return 1
        fi
        sleep 0.15
    done
}

# start_hume_expect_load_error <config-template> <input-file> [NAME=value ...]
#
# For a config expected to fail plugin load (a bad "program"/"debounce-ms"):
# the statusline shows the load error instead of the filename, so there's no
# basename to wait for. Waits for "Error:" instead — the prefix HUME's own
# config-load failure banner uses.
start_hume_expect_load_error() {
    _launch_hume "$@"
    wait_for_status "Error:" 10
}

stop_hume() {
    [[ -n "${SESSION:-}" ]] && tmux kill-session -t "$SESSION" 2>/dev/null
    # kill-session only closes the pane's pty — hume doesn't reliably exit on
    # the resulting SIGHUP alone, and a still-running process from a
    # previous case in the same script has been observed to steal keys sent
    # to the next one's brand new session. Wait briefly for it to exit; force
    # it if it hasn't.
    if [[ -n "${PANE_PID:-}" ]] && kill -0 "$PANE_PID" 2>/dev/null; then
        kill -TERM "$PANE_PID" 2>/dev/null || true
        for _ in 1 2 3 4 5; do
            kill -0 "$PANE_PID" 2>/dev/null || break
            sleep 0.1
        done
        if kill -0 "$PANE_PID" 2>/dev/null; then
            kill -KILL "$PANE_PID" 2>/dev/null || true
        fi
    fi
    [[ -n "${WORKDIR:-}" ]] && rm -rf "$WORKDIR"
}

# send <tmux send-keys args...> — thin wrapper so cases don't repeat -t $SESSION.
send() {
    tmux send-keys -t "$SESSION" "$@"
}

# wait_for <substring> [timeout-seconds] — polls the whole captured pane.
# Prints the pane and fails on timeout, so a CI failure is diagnosable.
wait_for() {
    local pattern="$1" timeout="${2:-5}" start
    start="$(date +%s)"
    while ! tmux capture-pane -t "$SESSION" -p | grep -qF "$pattern"; do
        if (( $(date +%s) - start >= timeout )); then
            echo "TIMEOUT waiting for: $pattern" >&2
            tmux capture-pane -t "$SESSION" -p >&2
            return 1
        fi
        sleep 0.1
    done
}

# wait_for_status <substring> [timeout-seconds] — matches only the bottom
# statusline row rather than the whole pane, so an assertion like a "3:13"
# position can't be satisfied by a coincidental match elsewhere on screen
# (scrollback, a picker row, the buffer text itself).
wait_for_status() {
    local pattern="$1" timeout="${2:-5}" start line
    start="$(date +%s)"
    while true; do
        line="$(tmux capture-pane -t "$SESSION" -p | tail -1)"
        [[ "$line" == *"$pattern"* ]] && return 0
        if (( $(date +%s) - start >= timeout )); then
            echo "TIMEOUT waiting for status line to contain: $pattern" >&2
            echo "  last status line was: $line" >&2
            return 1
        fi
        sleep 0.1
    done
}

# expect_absent <substring> — asserts the pattern is NOT anywhere in the
# current pane right now (a point-in-time check, not a wait).
expect_absent() {
    if tmux capture-pane -t "$SESSION" -p | grep -qF "$1"; then
        echo "UNEXPECTED: found '$1' in pane" >&2
        tmux capture-pane -t "$SESSION" -p >&2
        return 1
    fi
}
