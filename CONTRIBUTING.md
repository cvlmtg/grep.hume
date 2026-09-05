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

Editing `plugin.scm` with `core:steel-server` declared in your own `init.scm` gets you
free-identifier diagnostics for HUME's own builtins (`live-picker!`, `call!`, and the rest) —
see [Core Plugins](https://cvlmtg.github.io/HUME/core-plugins.html#core-steel-server) for the
one-time `:steel-server-install`.

## Code standards

- Every top-level `define` is prefixed `grep/` — everything in this file shares one namespace.
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

```sh
./scripts/lint.sh  # manifest.scm/README.md drift, naming convention, whitespace
./tests/run.sh     # end-to-end, driving a real hume under tmux
```

CI (`.github/workflows/ci.yml`) runs the same two scripts against the latest HUME release.

`lint.sh` has no dependencies beyond bash/grep/awk. `tests/run.sh` needs `tmux`, plus a
`hume` binary — the first one found, in order: `$HUME_BIN`, `$HUME_REPO` (built once via
`cargo build -p hume-editor`), `hume` on `PATH`, or a sibling checkout at `../hume`. See
[PLUGIN-AUTHORING.md](PLUGIN-AUTHORING.md)'s *Testing a plugin* for how it drives HUME.

The suite covers nearly everything HUME's own plugin API and this plugin's config
validation can be asserted on: both typed and normal commands, selection seeding
(including the newline-clamp case), UTF-8 column math, all three output shapes, a
malformed row, load-time config errors, `Esc` actually killing the spawned search, and a
truncated display row still parsing from its full untruncated payload. One case runs
against the real `rg` for `--smart-case`; every other case fixes the search program's
output via a fixture script, so the suite doesn't drift with `rg`'s own version.

What's left to check by hand, because it needs a platform this suite doesn't run on:

### Windows

- [ ] `#:config (hash "program" "RG.EXE")` (any casing) — still uses vimgrep shape and
      rg argv.

## Security

Please do not open a public issue for a security problem. Use GitHub's **Report a
vulnerability** button on the repository's Security tab, which opens a private advisory.
