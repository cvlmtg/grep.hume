# grep.hume

Live grep for [HUME](https://github.com/cvlmtg/hume), in the fuzzy picker.
Open the picker, type a pattern, and results stream in and re-search as you
type — the same picker `g f`/`g b`/`g m` use, driven live instead of
filtering a fixed list.

Uses [`rg`](https://github.com/BurntSushi/ripgrep) when it's on `PATH`,
falling back to `grep`. Any other program can be configured (see below).

## Requirements

- HUME with `picker!`'s `#:query`/`#:on-query-change`/`picker-replace!` and
  `picker-source-spawn!`'s `#:ok-exit-codes` (0.12.0 or later).
- `core:stdlib` declared or loaded first.
- `rg` or `grep` on `PATH` (or another program you configure).

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
|-------|-------------------------|----------------------------------------------------|
| `g /` | `live-grep-selection`  | Live-grep, seeded with the primary selection if it's non-collapsed and confined to one line |

Typed commands:

- `:live-grep` — opens empty.
- `:live-grep TODO` — opens seeded with `TODO`.
- `:live-grep-selection` — same as `g /`.

Inside the picker: type to search (each keystroke re-runs the search after a
short debounce), `Up`/`Down`/`Ctrl+p`/`Ctrl+n` move the selection,
`PageUp`/`PageDown`/`Ctrl+u`/`Ctrl+d` page it, `Backspace` edits the pattern,
`Enter` jumps to the match's file, line, and column, `Esc` dismisses (killing
the search if one is still running).

`declare-plugin` above activates lazily, on first use of either command —
but its own `bind-key!` call (the `g /` binding) only runs once the plugin's
body has actually been evaluated, so a lazily-declared install has no `g /`
key until *something* triggers activation first. Use `load-plugin` instead
of `declare-plugin` if you want the key available from startup, as in the
Install section above.

## Config

```scheme
(load-plugin "cvlmtg/grep.hume" #:config (hash "program" "grep"))
```

| Key            | Default                                    | Effect |
|----------------|---------------------------------------------|--------|
| `"program"`    | `"rg"` if on `PATH`, else `"grep"`          | The search binary. |
| `"format"`     | `'vimgrep` if `"program"` is `"rg"`, else `'grep` | Output shape to parse: `'vimgrep` is `path:line:col:text` (rg's `--vimgrep`), `'grep` is `path:line:text` (no column). Set this if you configure a third program that isn't rg or grep. |
| `"args"`       | rg: `'("--vimgrep" "--no-heading" "--color" "never" "--")`<br>grep: `'("-rnI" "--color=never" "--")` | Argv placed before the pattern. The pattern and the search root (`.`) are always appended after. |
| `"debounce-ms"`| `120`                                        | Milliseconds to wait after the last keystroke before re-running the search. |

## Known limitations

- A result whose file path contains a literal `:` breaks the row parse (the
  same limitation vim's own `errorformat` has for this shape) — the row logs
  an error instead of jumping anywhere.
- Configuring a third program (not `rg` or `grep`) needs `"format"` (and
  usually `"args"`) set to match its output — there's no default for it.

## Contributing

Bug reports and pull requests — see [CONTRIBUTING.md](CONTRIBUTING.md).

This plugin doubles as a minimal reference for a HUME plugin that lives in its own
repository and installs through PLUM — see [PLUGIN-AUTHORING.md](PLUGIN-AUTHORING.md).
