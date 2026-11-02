# Changelog

## [4.0.0] - 2026-11-02

Requires HUME 0.18.0 or later.

- Breaking: the picker opens with `z /`, next to HUME's other pickers, in place of `g /`.
- Works with HUME 0.18.0 as released, where 3.0.0's picker fails to open.
- Rows still shown while a new search starts highlight what their own search matched, not
  the newly typed query.

## [3.0.0] - 2026-11-02

Requires HUME 0.18.0 or later.

- Breaking: the plugin needs HUME 0.18.0, whose pickers take a keymap. The picker keeps
  its keys.
- Rows color the directory, line and column numbers and the match, leave out the line's
  indentation, and shorten a long directory from its front so the match stays in view.

## [2.0.0] - 2026-10-28

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
