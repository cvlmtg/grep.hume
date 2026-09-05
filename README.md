# grep.hume

Live grep for [HUME](https://github.com/cvlmtg/hume), in the fuzzy picker.
Open the picker, type a pattern, and matches appear as you type.

Uses [`rg`](https://github.com/BurntSushi/ripgrep) when it's on `PATH`,
falling back to `grep`. Any other program can be configured (see below).

## Requirements

- HUME 0.12.0 or later.
- `rg` or `grep` on `PATH` (or another program you configure) — checked at
  load; a missing or misconfigured binary errors immediately instead of
  producing a silently empty picker.

## Install

```scheme
(declare-plugin "core:stdlib")
(load-plugin "cvlmtg/grep.hume")
```

Then, from inside HUME:

```
:plum-install-plugins
:reload-config
```

`:plum-install-plugins` clones the repo *after* `init.scm` has already run,
so the plugin doesn't exist on disk yet at that point — `:reload-config`
re-evaluates `init.scm` now that it does. `:plum-update-plugins` pulls
updates the same way, no reload needed until you actually want the new code
active.

## Usage

| Key   | Command                | Effect                                            |
|-------|------------------------|---------------------------------------------------|
| `g /` | `picker-grep` | Live-grep, seeded with the primary selection if it's non-collapsed and confined to one line |

Typed commands:

- `:grep` — opens empty.
- `:grep TODO` — opens seeded with `TODO`.

Inside the picker: type to search (each keystroke re-runs the search after a
short debounce), `Up`/`Down`/`Ctrl+p`/`Ctrl+n` move the selection,
`PageUp`/`PageDown`/`Ctrl+u`/`Ctrl+d` page it, `Backspace` edits the pattern,
`Enter` jumps to the match's file, line, and column, `Esc` dismisses (killing
the search if one is still running).

`declare-plugin` above activates lazily, on first use of either command —
but its own `bind-key!` call (the `g /` binding) only runs once the plugin's
body has actually been evaluated, so a lazily-declared install has no `g /`
key until *something* triggers activation first. Use `load-plugin` instead
of `declare-plugin` if you want the key available from startup, as in the
Install section above.

## Config

```scheme
(load-plugin "cvlmtg/grep.hume" #:config (hash "program" "grep"))
```

| Key            | Default                                    | Effect |
|----------------|---------------------------------------------|--------|
| `"program"`    | `"rg"` if on `PATH`, else `"grep"`          | The search binary. Checked at load — an unresolvable program errors immediately, naming the plugin and the key. |
| `"format"`     | `'vimgrep-null` if `"program"` is `"rg"`, else `'grep` | Output shape to parse: `'vimgrep-null`, `'vimgrep`, or `'grep` — see [Output shapes](#output-shapes). Set this if you configure a third program, or if you override `"args"` to drop `--null` (pair that with `"format" 'vimgrep`). |
| `"args"`       | rg: `'("--vimgrep" "--no-heading" "--color" "never" "--null" "--smart-case" "-m" "1000" "-M" "512" "--max-columns-preview" "--")`<br>grep: `'("-rnI" "-i" "--color=never" "--")` | Argv placed before the pattern. The pattern and the search root (`.`) are always appended after. `-m`/`-M` bound per-file and per-row cost — see Known limitations. |
| `"debounce-ms"`| `120`                                        | Milliseconds to wait after the last keystroke before re-running the search. Must be a non-negative integer. |

### Output shapes

- `'vimgrep-null` — `path\0line:col:text` (rg's `--vimgrep --null`,
  NUL-terminated path).
- `'vimgrep` — `path:line:col:text` (same without `--null`).
- `'grep` — `path:line:text` (no column).

## Known limitations

- `"format"` is a closed set of three shapes (see [Output
  shapes](#output-shapes)) — a third program needs `"args"` set to match
  one of them, and a program whose output matches none of the three can't
  be configured at all. The `'vimgrep` shape (no `--null`) also breaks on a
  literal `:` in the path, the same limitation vim's own `errorformat` has
  for this shape; `'vimgrep-null` doesn't have that problem.
- `-m` in the default `"args"` caps matching *lines* per file searched, not
  picker rows or the search as a whole — `--vimgrep` still emits one row per
  match on a capped line before the cap takes effect, and a broadly
  matching pattern across a large tree can still produce many rows. `-M`
  bounds each row's own width instead, showing a truncated preview
  (`--max-columns-preview`) rather than an unusable placeholder — `Enter`
  lands on the real column for a match within the limit, or the preview's
  end for one beyond it.
- Case: rg's default `"args"` carry `--smart-case` — an all-lowercase pattern
  matches either case, and typing any uppercase character narrows the search
  to that case. `grep` has no such mode, so its default `"args"` carry the
  blunter `-i` instead — always case-insensitive, with no way to narrow by
  case. Both are ordinary flags in `"args"`, so overriding that key changes
  or drops this behavior like any other.

## Contributing

Bug reports and pull requests — see [CONTRIBUTING.md](CONTRIBUTING.md).

This plugin doubles as a minimal reference for a HUME plugin that lives in its own
repository and installs through PLUM — see [PLUGIN-AUTHORING.md](PLUGIN-AUTHORING.md).
