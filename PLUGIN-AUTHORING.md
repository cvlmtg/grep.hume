# Writing a third-party HUME plugin

`cvlmtg/grep.hume` doubles as a minimal reference for a HUME plugin that lives in its own
repository, installed through
[PLUM](https://cvlmtg.github.io/HUME/core-plugins.html#plum). The general rules for writing
one — commands, `call!`, selections, dependencies, `#:config`, and the rest — are in
[HUME's user manual](https://cvlmtg.github.io/HUME/plugins.html); this file covers only what
this repo's own layout demonstrates.

- **`plugin.scm`** at the repo root is the only required file. HUME itself resolves
  `(declare-plugin "cvlmtg/grep.hume")`/`(load-plugin "cvlmtg/grep.hume")` to it directly;
  PLUM separately probes for the same filename to discover an already-installed plugin on
  disk. `"cvlmtg/grep.hume"` is also the GitHub path PLUM clones from and the install
  directory name under the data directory.
- **`manifest.scm`**, also at the repo root, is optional — it supplies the
  `#:commands`/`#:events`/`#:languages` this plugin's *lazy* `(declare-plugin ...)` (no
  explicit activation list of its own) should activate on.
- **Why this plugin needs `load-plugin`, not `declare-plugin`**: its only entry point besides
  its two typed commands is a key binding it sets itself (`g /`), and a plugin's own
  `bind-key!` call only runs once the plugin's body has actually been evaluated — a lazily
  `declare-plugin`d install would have no `g /` key until something else triggers
  activation first. See README's Usage section.
- **This plugin's `(member "core:stdlib" (declared-plugins))` guard** and its
  `(plugin-config)` reads (both at the top of `plugin.scm`, evaluated once while the body
  runs) are worked examples of the manual's "Depending on another plugin" and "Configuring a
  plugin" sections — read those for the general rules and their caveats.
