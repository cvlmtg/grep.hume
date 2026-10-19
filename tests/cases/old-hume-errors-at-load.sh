#!/usr/bin/env bash
# On an editor older than the supported version the plugin errors at load,
# naming itself and the version it needs.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./lib.sh

start_hume_expect_load_error config/old-hume.scm "$FIXTURES_DIR/tree/scratch.txt"
wait_for "$PLUGIN_NAME"
wait_for "requires HUME $MIN_HUME_VERSION or later"
