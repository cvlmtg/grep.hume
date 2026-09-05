#!/usr/bin/env bash
# `#:config (hash "debounce-ms" "fast")` errors at load, naming the plugin
# and the key.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume_expect_load_error config/bad-debounce.scm "$FIXTURES_DIR/tree/scratch.txt"
wait_for_status "$PLUGIN_NAME"
wait_for_status "debounce-ms"
