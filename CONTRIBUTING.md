# Contributing to grep.hume

- **Bug reports are always welcome.** Include your HUME version (`hume --version`), your
  `"program"`/`"format"`/`"args"` config if you set any, the exact pattern you searched, and
  — if a result row failed to parse — the row itself from `:messages`.
- **Small, focused fixes** can go straight to a pull request.

By contributing you agree that your work is licensed under the [MIT License](LICENSE).

## Getting set up

`(load-plugin "cvlmtg/grep.hume")` resolves one path only, so a working copy has to be
reachable there:

| Platform | `<data>/plugins/cvlmtg/grep.hume/` resolves under |
|---|---|
| macOS, Linux | `$XDG_DATA_HOME/hume/`, default `~/.local/share/hume/` |
| Windows | `%LOCALAPPDATA%\hume\`, falling back to `%APPDATA%\hume\` if `LOCALAPPDATA` is unset |

Either clone your fork straight into that path and work there, or symlink it there from a
checkout elsewhere — path resolution follows symlinks. The one consequence of a symlinked
checkout: PLUM counts it as installed, so `:plum-update-plugins` will run `git pull` inside
your working tree.

Iterating: edit `plugin.scm`, then `:reload-config` inside HUME — it resets every plugin to
default and re-runs `init.scm`, so the edited body is re-evaluated with no restart needed.
To avoid touching a real `init.scm`, keep a scratch config that just declares
`core:stdlib` and loads this plugin, and start HUME with `hume --config ./demo.scm <file>`
— the data directory still resolves normally, so your checkout is still found.

## Code standards

- Every top-level `define` is prefixed `grep/` — Steel plugins share one flat namespace.
- Comments explain *why*, never *what*, and stay self-contained — no references to plan
  files or "as discussed". `;;;` documents the definition below it; `;;` marks a section
  banner or an inline aside.
- If a change relies on a newer HUME API, bump the version in README's **Requirements**.

The general plugin-authoring rules this repo follows — public API only, reaching another
plugin through `call!` by command name, reading `(plugin-config)` while the body evaluates,
failing loudly on bad config — are documented once in
[PLUGIN-AUTHORING.md](PLUGIN-AUTHORING.md); follow those rather than restating them here.

## Pull requests

- One logical change per pull request.
- Rebase on `main` rather than merging it in — pull requests are squash-merged.

### Commit messages

[Conventional Commits](https://www.conventionalcommits.org), imperative mood, no trailing
period:

```
fix(parse): handle a path containing a literal colon
docs(readme): document the debounce-ms config key
```

Types in use: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `style`, `chore`. Scope is
optional: `picker`, `config`, `parse`, `selection`, `keys`, or `docs`.

The subject says what changed; the body says **why**. If the change isn't obvious from the
diff, the body is not optional.

## Verification

There is no test suite or CI here. Before opening a pull request, manually check the
items below that your change could plausibly affect, and list them as checked in the
pull request description. The Unix and Windows sections only apply on that platform;
check whichever matches the machine you tested on.

### General

- [ ] `:grep` opens empty; typing streams results and re-searches after the debounce.
- [ ] `:grep TODO` opens seeded *and* already searching.
- [ ] `g /` seeds from a one-line, non-collapsed selection; a bare cursor or a multi-line
      selection opens empty instead.
- [ ] `Enter` lands on the exact column on a line with multi-byte characters before the
      match.
- [ ] A result row reads `path:line:col:text`, with no `<0>` (default `"format"`;
      the picker shows the NUL path separator as `:`).
- [ ] `#:config (hash "program" "grep")` parses `path:line:text` rows and lands at line
      start.
- [ ] A pattern with no matches leaves `:messages` clean.
- [ ] A lowercase pattern matches an uppercase occurrence (`unfin` finds
      `Unfinished`); adding an uppercase character narrows it again under `rg`.
- [ ] `Esc` mid-search kills the running process.
- [ ] A bad config value (e.g. `"debounce-ms" "fast"` or `"debounce-ms" -1`) errors at
      load, naming the plugin and the key.
- [ ] `x` (and `X`, `Ctrl+x`, extend-right onto the newline) then `g /` — seeds from the
      line, no "index out of bounds" in `:messages`.
- [ ] A malformed row (a program emitting a non-numeric line field) — logs the row to
      `:messages` and jumps nowhere, rather than raising.
- [ ] `#:config (hash "program" "nonexistent")` — errors at load naming the plugin and
      the key, not later from a timer.
- [ ] A file with a very long minified line — the row shows a truncated preview instead
      of a placeholder, and `Enter` is instant and lands on the right column for a match
      within the preview.
- [ ] Backspace to empty mid-search — rows clear and stay cleared, no stale refill.

### Unix (macOS, Linux)

- [ ] A path containing a literal `:` — the row parses and `Enter` lands in it (default
      `"format"`; not `'vimgrep`, which still has this limitation). Windows file systems
      reserve `:` in a file name, so this case can't arise there.
- [ ] `#:config (hash "program" "/full/path/to/rg")` — still uses vimgrep shape and rg
      argv.

### Windows

- [ ] `#:config (hash "program" "RG.EXE")` (any casing) — still uses vimgrep shape and
      rg argv.

## Security

Please do not open a public issue for a security problem. Use GitHub's **Report a
vulnerability** button on the repository's Security tab, which opens a private advisory.
