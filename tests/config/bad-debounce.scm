;;; A non-integer "debounce-ms" — the plugin must error at load, naming
;;; itself and the "debounce-ms" key.
(declare-plugin "core:stdlib")
(load-plugin "@PLUGIN@" #:config (hash "debounce-ms" "fast"))
