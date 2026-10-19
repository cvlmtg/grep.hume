# Writing a third-party HUME plugin

`cvlmtg/grep.hume` doubles as a reference for a HUME plugin that lives in its own repository
and installs through [PLUM](https://cvlmtg.github.io/HUME/core-plugins.html#core-plum). The
rules for writing one (commands, `call!`, selections, dependencies, `#:config` and the rest)
are in HUME's [Writing Plugins](https://cvlmtg.github.io/HUME/writing-plugins.html) manual,
and every builtin is listed in the [Plugin API](https://cvlmtg.github.io/HUME/plugin-api.html).
This file covers what a plugin repository adds on top: layout, conventions, version gating,
tests, lint, CI and releases.

## Starting your own plugin from this repo

1. Copy these files into the new repository:
   - `plugin.scm`, as a starting point to cut down;
   - `README.md`'s Requirements, Install and Config sections, as a shape to fill in;
   - `scripts/lint.sh`;
   - `tests/lib.sh` and `tests/run.sh` as they are, plus one file from `tests/cases/` and
     one from `tests/config/` as templates;
   - `.github/workflows/ci.yml` and `.editorconfig`.

   Start a `CHANGELOG.md` and pick a `LICENSE` of your own.
2. Change the lines that name this plugin:
   - `tests/lib.sh`: `PLUGIN_NAME` and `MIN_HUME_VERSION`;
   - `scripts/lint.sh`: `PREFIX`;
   - `plugin.scm`: the `<prefix>plugin` define, the `(hume-version>=? …)` check and the
     version in its error message;
   - `README.md`: the `- HUME X.Y.Z or later.` line under Requirements.
3. In `ci.yml`, change only the package-install step: it installs `ripgrep` because this
   plugin's tests search with it.
4. Run `./scripts/lint.sh` and `./tests/run.sh` before the first commit.

Marking the repository as a template on GitHub turns step 1 into "Use this template".

## Layout

- **`plugin.scm`** at the repo root is the only required file. HUME resolves
  `(load-plugin! "cvlmtg/grep.hume")` to it directly, and PLUM probes for the same filename
  to discover an already-installed plugin on disk. `"cvlmtg/grep.hume"` is also the GitHub
  path PLUM clones from and the install directory name under the data directory.
- **No `manifest.scm`**: a plugin without one loads eagerly, which this plugin needs. Its
  only entry point besides its `:grep` and `grep/picker` commands is a key binding it sets
  itself (`g /`), and a plugin's own `bind-key!` call only runs once the plugin's body has
  been evaluated. A `manifest.scm` would make `load-plugin!` lazy and leave `g /` unbound
  until a command triggered activation. A user who wants it lazy anyway can declare their
  own triggers; see [Choosing your own
  triggers](https://cvlmtg.github.io/HUME/plugins.html#choosing-your-own-triggers).

## Reading `plugin.scm`

The file reads top to bottom in the order HUME evaluates it:

1. **Load-time guards**: the minimum HUME version and the `core:stdlib` dependency, each
   failing with an error that names the plugin.
2. **Config**: every `#:config` key read once, into defines, through `core:stdlib`'s
   `stdlib/config-*` helpers, and a bad `"program"` rejected at load instead of inside a
   search.
3. **Selection seeding**: turning the primary selection into the initial query.
4. **Result-row parsing**: runs only on the row the user picks, never per row, so the
   picker stays fast however many rows a search streams in.
5. **Open**: the `live-picker!` call, with its subprocess source and the open-in-tab or
   split actions.
6. **Commands**: one typed command and one key-bindable command, both calling the same
   function.
7. **Key binding**: the default `g /`.

## Conventions

### Naming

Editor commands from every plugin share one namespace. Give every `define-command!` name one
shared prefix followed by `/` (`grep/picker`), so two plugins never collide on a command, and
leave typed commands unprefixed (`:grep`), as [Defining
commands](https://cvlmtg.github.io/HUME/writing-plugins.html#defining-commands) describes.

Top-level `define`s are a separate matter: HUME loads `plugin.scm` as a Steel module, so they
are private to the plugin and need no prefix. This repo gives them the same `grep/` prefix as
house style (`grep/program`, `grep/split-once`), to set them apart from HUME builtins and
Steel functions, and `lint.sh` checks it.

### Dependencies and config

The `(member "core:stdlib" (declared-plugins))` guard and the `stdlib/config-*` reads at the
top of `plugin.scm` are worked examples of [Depending on another
plugin](https://cvlmtg.github.io/HUME/writing-plugins.html#depending-on-another-plugin) and
[Configuring a
plugin](https://cvlmtg.github.io/HUME/writing-plugins.html#configuring-a-plugin).
`(plugin-config)` returns the user's `#:config` only while the plugin's body is being
evaluated, so read every key there, never from inside a command.

### Version gating

One minimum HUME version appears in four places, and `lint.sh` fails if they differ:

- `plugin.scm`'s `(hume-version>=? X Y Z)` check, which refuses to load on an older editor;
- the version named in that check's error message;
- `tests/lib.sh`'s `MIN_HUME_VERSION`, which `hume_resolve` checks against the `hume` the
  tests drive before running any case. A too-old binary would otherwise fail every case in
  unrelated-looking ways, such as an opaque tmux "no server running". A nightly reports a
  version like `0.16.0-<sha>`; the check strips the suffix, so a nightly of the required
  version passes;
- the README's Requirements line.

A development build reports the release it is heading toward, so the plugin can require a
version HUME hasn't released yet and still load on that cycle's nightly.

## Testing

HUME's headless `--keys` mode replays keys back to back and saves only the buffer's text, so
it can't watch a picker fill from a debounced background search. `tests/` scripts the real
editor through `tmux` instead:

- Each case gets its own tmux session and a throwaway `$XDG_DATA_HOME` with the working copy
  symlinked in as the installed plugin, so it never touches the real config or data
  directory.
- A case renders a config template from `tests/config/`, starts `hume`, sends keys, and
  asserts on `tmux capture-pane` output with `wait_for`, `wait_for_status` and
  `expect_absent`.
- Fixture scripts in `tests/fixtures/bin/` stand in for the real search binary, so a case's
  expected output is exact bytes that don't change with the binary's version.
- `./tests/run.sh` runs every case; `./tests/run.sh <name>…` runs only the named ones.

`tests/lib.sh` and `tests/run.sh` have nothing grep.hume-specific beyond the two lines named
in [Starting your own plugin](#starting-your-own-plugin-from-this-repo).

## Lint and CI

`scripts/lint.sh` checks what the docs claim against what the code does. It parses these
shapes, so keep them when adapting the files:

| Check | Shape it reads |
|---|---|
| README's Config table lists the keys `plugin.scm` reads, no more and no fewer | table rows whose first cell is a lowercase, hyphenated key in quotes and backticks (`` `"debounce-ms"` ``), and calls of the form `(call! "stdlib/config-…" <prefix>plugin <prefix>cfg "key" …)` |
| The minimum HUME version matches everywhere | `- HUME X.Y.Z or later.` in the README, `(hume-version>=? X Y Z)` and `requires HUME X.Y.Z or later` in `plugin.scm`, `MIN_HUME_VERSION="X.Y.Z"` in `tests/lib.sh` |
| Every top-level define is prefixed | `(define <prefix>name …)` and `(define (<prefix>name …) …)` |
| No tabs or trailing whitespace in `.scm` files | every `.scm` file in the repo |

`.github/workflows/ci.yml` runs `lint.sh` and `tests/run.sh` on Linux. Once HUME has tagged
`v` + `MIN_HUME_VERSION`, it tests against HUME's latest stable release; until then, against
the nightly build. Raising the minimum version never needs a `ci.yml` edit.

## Releasing

Tag releases as `vX.Y.Z`. Users who pin a tag with `#:ref` (see [Pinning a
version](https://cvlmtg.github.io/HUME/plugins.html#pinning-a-version)) stay on it until they
change it. Everyone else gets the default branch's latest commit on every
`:plum-update-plugins`, so keep `main` releasable.

Version numbers follow [Semantic Versioning](https://semver.org) from the user's side:

- **Major**: a working `init.scm` stops working. That covers a renamed or removed config
  key, command or default key binding, and a higher minimum HUME version.
- **Minor**: a new command, config key or behavior that leaves existing configs working.
- **Patch**: a fix.

Record each user-visible change in `CHANGELOG.md` as it lands, so a release only has to date
the entry. This repo's own steps are in [CONTRIBUTING.md](CONTRIBUTING.md#releasing).
