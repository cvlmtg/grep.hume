# Changelog

## Unreleased

Requires HUME 0.17.0 or later.

- Breaking: `#:config` keys are symbols, as HUME 0.17.0 requires: write
  `(hash 'program "grep")` for `(hash "program" "grep")`, and the same for `'format`,
  `'args` and `'debounce-ms`.

## [1.0.0] - 2026-10-20

First stable release. Requires HUME 0.16.0 or later.

- Live grep in HUME's picker: type a pattern and matching lines appear as you type, one
  row per line, re-searched after a short debounce.
- `:grep` opens the picker empty, and `:grep TODO` opens it seeded with a pattern.
- `g /` (`grep/picker`) opens it seeded with the primary selection when that selection is
  non-collapsed and on one line.
- `Enter`/`Ctrl+o` jump to the match's file, line and column in the current pane;
  `Ctrl+t`, `Ctrl+v` and `Ctrl+s` open it in a new tab, a side-by-side split or a stacked
  split.
- Uses `rg` when it's on `PATH` (smart case, per-file and per-line caps), falling back to
  `grep` (case-insensitive, skipping `.git`).
- Config keys `"program"`, `"format"` (`'vimgrep-null`, `'vimgrep` or `'grep`), `"args"`
  and `"debounce-ms"`. A missing program, a bad value, a HUME older than 0.16.0 or a
  missing `core:stdlib` errors when the plugin loads.
