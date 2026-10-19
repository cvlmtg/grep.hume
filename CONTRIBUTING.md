# Contributing to grep.hume

- **Bug reports are always welcome.** Include your HUME version (`hume --version`), your
  `"program"`/`"format"`/`"args"` config if you set any, the exact pattern you searched, and
  — if a result row failed to parse — the row itself from `:messages`.
- **Small, focused fixes** can go straight to a pull request.

By contributing you agree that your work is licensed under the [MIT License](LICENSE).

## Getting set up

`(load-plugin! "cvlmtg/grep.hume")` resolves one path only, so a working copy has to be
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

- Editor command names are prefixed `grep/` (`grep/picker`), so they can't collide with
  another plugin's commands. The typed command `:grep` has no prefix.
- Top-level `define`s carry the same `grep/` prefix as house style. They are private to the
  plugin, so the prefix only sets them apart from HUME builtins and Steel functions
  (`grep/split-once` wraps Steel's `split-once`). `lint.sh` checks it.
- Comments explain *why*, never *what*, and stay self-contained — no references to plan
  files or "as discussed". `;;;` documents the definition below it; `;;` marks a section
  banner or an inline aside.
- If a change relies on a newer HUME API, bump `tests/lib.sh`'s `MIN_HUME_VERSION`,
  `plugin.scm`'s `hume-version>=?` check and its error message, and README's
  **Requirements** together — `lint.sh` checks they all match. CI picks stable vs. nightly
  on its own; nothing in `ci.yml` needs editing. See
  [PLUGIN-AUTHORING.md](PLUGIN-AUTHORING.md#version-gating) for how the pieces fit.
- A user-visible change adds a line under `## Unreleased` at the top of
  [CHANGELOG.md](CHANGELOG.md), creating that heading if it isn't there.

The rules for writing a HUME plugin are in HUME's
[Writing Plugins](https://cvlmtg.github.io/HUME/writing-plugins.html) manual.
[PLUGIN-AUTHORING.md](PLUGIN-AUTHORING.md) covers what this repo adds on top: layout,
version gating, tests, lint, CI and releases.

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
optional: `picker`, `config`, `parse`, `selection`, `keys`, `docs`, `tests`, `lint`, or `ci`.

The subject says what changed; the body says **why**. If the change isn't obvious from the
diff, the body is not optional.

## Verification

```sh
./scripts/lint.sh                # README.md drift, naming convention, whitespace
./tests/run.sh                   # end-to-end, driving a real hume under tmux
./tests/run.sh real-rg-smoke     # only the named cases from tests/cases/
```

CI (`.github/workflows/ci.yml`) runs the same two scripts against the newest stable HUME
release that ships `tests/lib.sh`'s `MIN_HUME_VERSION`, falling back to nightly if none does.

`lint.sh` has no dependencies beyond bash/grep/awk. `tests/run.sh` needs `tmux`, `rg` and
`grep` on `PATH`, plus a `hume` binary — the first one found, in order: `$HUME_BIN`,
`$HUME_REPO` (built once via `cargo build -p hume-editor`), `hume` on `PATH`, or a sibling
checkout at `../hume`. See [PLUGIN-AUTHORING.md](PLUGIN-AUTHORING.md#testing) for how it
drives HUME.

The suite covers nearly everything HUME's own plugin API and this plugin's config
validation can be asserted on: both typed and normal commands, selection seeding
(including the newline-clamp case), UTF-8 column math, all three output shapes, a
malformed row, load-time config errors, `Esc` actually killing the spawned search, `Ctrl+t`
placing the match in a new tab rather than the current pane, and a truncated display row
still parsing from its full untruncated payload. One case runs against the real `rg` for
`--smart-case` and one row per matching line, and one against the real `grep` for skipping
`.git`; every other case fixes the search program's output via a fixture script, so the
suite doesn't drift with the search programs' own versions.

What's left to check by hand, because it needs a platform this suite doesn't run on:

### Windows

- [ ] `#:config (hash "program" "RG.EXE")` (any casing) — still uses vimgrep shape and
      rg argv.

## Releasing

1. Rename CHANGELOG.md's `## Unreleased` heading to `## [X.Y.Z] - YYYY-MM-DD`. See
   [PLUGIN-AUTHORING.md](PLUGIN-AUTHORING.md#releasing) for which part of the version to
   bump.
2. Check that HUME has tagged `v` + `MIN_HUME_VERSION`, so CI ran against a stable
   release rather than nightly, and that CI on `main` is green.
3. Tag and push the tag: `git tag vX.Y.Z && git push origin vX.Y.Z`.
4. Optionally, create a GitHub release from the tag with the changelog entry as its notes.

## Security

Please do not open a public issue for a security problem. Use GitHub's **Report a
vulnerability** button on the repository's Security tab, which opens a private advisory.
