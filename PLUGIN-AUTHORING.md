# Writing a third-party HUME plugin

`cvlmtg/grep.hume` doubles as a minimal reference for a HUME plugin that lives in its own
repository, installed through
[PLUM](https://cvlmtg.github.io/HUME/core-plugins.html#plum). Read this alongside its
`plugin.scm` and `manifest.scm`:

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
