# Writing a third-party HUME plugin

`cvlmtg/grep.hume` doubles as a minimal reference for a HUME plugin that lives in its own
repository, installed through
[PLUM](https://cvlmtg.github.io/HUME/core-plugins.html#plum). The general rules for writing
one — commands, `call!`, selections, dependencies, `#:config`, and the rest — are in
[HUME's user manual](https://cvlmtg.github.io/HUME/plugins.html); this file covers only what
this repo's own layout demonstrates.

- **`plugin.scm`** at the repo root is the only required file. HUME itself resolves
  `(load-plugin! "cvlmtg/grep.hume")` to it directly;
  PLUM separately probes for the same filename to discover an already-installed plugin on
  disk. `"cvlmtg/grep.hume"` is also the GitHub path PLUM clones from and the install
  directory name under the data directory.
- **No `manifest.scm`**: a plugin without one loads eagerly, which this plugin needs — its
  only entry point besides its two typed commands is a key binding it sets itself (`g /`),
  and a plugin's own `bind-key!` call only runs once the plugin's body has been evaluated.
  A `manifest.scm` would make `load-plugin!` lazy and leave `g /` unbound until a command
  triggered activation.
- **This plugin's `(member "core:stdlib" (declared-plugins))` guard** and its
  `(plugin-config)` reads (both at the top of `plugin.scm`, evaluated once while the body
  runs) are worked examples of the manual's "Depending on another plugin" and "Configuring a
  plugin" sections — read those for the general rules and their caveats.
- **Testing a plugin**: with no headless plugin-eval mode to drive, `tests/` here scripts
  the real editor through `tmux` instead — a throwaway `$XDG_DATA_HOME` symlinks the working
  copy in as the installed plugin, and assertions read `tmux capture-pane` output. Fixture
  scripts stand in for the real search binary so a test's expected output is exact bytes,
  not something that can drift out from under it. Copy `tests/lib.sh` and
  `tests/cases/*.sh`'s shape directly for another plugin; the mechanism has nothing
  grep.hume-specific in it.
