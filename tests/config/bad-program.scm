;;; A "program" that isn't on PATH — the plugin must error at load, naming
;;; itself and the "program" key, rather than producing a silently empty
;;; picker later.
(declare-plugin "core:stdlib")
(load-plugin "@PLUGIN@" #:config (hash "program" "nonexistent"))
