#!/usr/bin/env bash
# `#:config (hash "program" "nonexistent")` errors at load, naming the
# plugin and the key — not later from a debounce timer.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume_expect_load_error config/bad-program.scm "$FIXTURES_DIR/tree/scratch.txt"
wait_for_status "$PLUGIN_NAME"
wait_for_status "is not on PATH"
