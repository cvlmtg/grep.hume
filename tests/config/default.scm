;;; Zero-config install — whatever "program"/"format" the plugin resolves on
;;; its own (real rg if it's on PATH, else grep). Used only by the one case
;;; that deliberately exercises the real search binary rather than a fixture.
(declare-plugin "core:stdlib")
(load-plugin "@PLUGIN@")
(configure-statusline! '("FileName") '() '("Position"))
