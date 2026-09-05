;;; Points "program" at a fixture script instead of a real search binary, so
;;; a case controls the exact bytes the plugin has to parse. @PROGRAM@ and
;;; @FORMAT@ (an unquoted symbol name, e.g. grep or vimgrep-null) are
;;; substituted by render_config; @FIXTURES@ resolves to tests/fixtures.
(declare-plugin "core:stdlib")
(load-plugin "@PLUGIN@"
             #:config (hash "program" "@PROGRAM@" "format" '@FORMAT@))
(configure-statusline! '("FileName") '() '("Position"))
