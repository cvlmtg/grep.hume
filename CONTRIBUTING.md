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
| Windows | `%LOCALAPPDATA%\hume\` |

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
- Public plugin API only (`picker!`, `picker-replace!`, `picker-source-spawn!`) — nothing
  here should need a capability third-party plugins don't have.
- Reach another plugin through `call!` by command name (e.g. `stdlib/config-string`), never
  by importing its internals.
- Read `(plugin-config)` into `define`s while the plugin body evaluates, never from inside a
  command — it returns an empty hash from anywhere else.
- Config values fail loudly at load time, naming the plugin and the key, not wherever a bad
  value happens to misbehave later.
- Comments explain *why*, never *what*, and stay self-contained — no references to plan
  files or "as discussed". `;;;` documents the definition below it; `;;` marks a section
  banner or an inline aside.
- If a change relies on a newer HUME API, bump the version in README's **Requirements**.

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

There is no test suite or CI here — say in the pull request which of these you checked:

1. `:live-grep` opens empty; typing streams results and re-searches after the debounce.
2. `:live-grep TODO` opens seeded *and* already searching.
3. `g /` seeds from a one-line, non-collapsed selection; a bare cursor or a multi-line
   selection opens empty instead.
4. `Enter` lands on the exact column on a line with multi-byte characters before the match.
5. `#:config (hash "program" "grep")` parses `path:line:text` rows and lands at line start.
6. A pattern with no matches leaves `:messages` clean.
7. `Esc` mid-search kills the running process.
8. A bad config value (e.g. `"debounce-ms" "fast"`) errors at load, naming the plugin and
   the key.

## Security

Please do not open a public issue for a security problem. Use GitHub's **Report a
vulnerability** button on the repository's Security tab, which opens a private advisory.
