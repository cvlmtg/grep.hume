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

## Writing your own third-party plugin

This plugin doubles as a minimal reference for a HUME plugin that lives in
its own repository, installed through
[PLUM](https://cvlmtg.github.io/HUME/core-plugins.html#plum):

- **`plugin.scm`** at the repo root is the only required file — HUME's
  plugin manager (PLUM) looks for it by that exact name, both to discover an
  installed plugin and to resolve `(declare-plugin "user/repo")`/
  `(load-plugin "user/repo")` to a file. `"user/repo"` (this repo:
  `cvlmtg/grep.hume`) is also the GitHub path PLUM clones from and the
  install directory name under the data directory.
- **`manifest.scm`**, also at the repo root, is optional — it supplies the
  `#:commands`/`#:events`/`#:languages` a *lazy* `(declare-plugin "user/repo")`
  (no explicit activation list of its own) should activate on. Without one,
  a bare `(declare-plugin "user/repo")` has nothing to ever wake it up.
- **`declare-plugin` vs `load-plugin`**: `declare-plugin` registers the
  plugin without running its body — it activates later, the first time one
  of its trigger commands/events/languages fires. `load-plugin` runs the
  body immediately. A plugin whose only entry point is a key binding it sets
  itself (like this one's `g /`) needs `load-plugin`, or a user who wants it
  lazy has to trigger activation some other way first (a typed command, in
  this plugin's case).
- **Depending on another plugin**: guard on `(member "core:stdlib"
  (declared-plugins))` at the top of `plugin.scm` and error out with a
  message naming both plugins if it's missing — see this plugin's own guard.
  `declared-plugins` (not `loaded-plugins`) is enough, since it also forces
  activation.
- **`#:config`**: read `(plugin-config)` into `define`s at the top of
  `plugin.scm`, while the plugin's own body is being evaluated — it returns
  an empty hash from anywhere else, including from inside a command this
  plugin defines. `core:stdlib` ships typed accessors
  (`stdlib/config-string`/`stdlib/config-boolean`/`stdlib/config-enum`) that
  raise an error naming the plugin and the key on a bad value, so
  misconfiguration fails at load rather than wherever the untyped value
  happens to misbehave later.
- **Install flow**: `(declare-plugin "user/repo" ...)`/`(load-plugin
  "user/repo" ...)` in `init.scm` only *declares intent* — nothing is
  fetched until `:plum-install-plugins` clones it, and nothing in the
  running editor picks it up until `:reload-config` re-evaluates `init.scm`.

See the full plugin-authoring guide in [HUME's user
manual](https://cvlmtg.github.io/HUME/plugins.html).
