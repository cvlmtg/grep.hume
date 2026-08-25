; Default activation for `(declare-plugin "cvlmtg/grep.hume")` with no
; explicit #:commands/#:events/#:languages — see README.md "Usage".
;
; Lazy activation only covers `:live-grep`/`:live-grep-selection` typed by
; command name or called from another plugin's `call!` — it does NOT bind
; `g /`, since a plugin's own `bind-key!` calls only run once its body has
; actually been evaluated. Bind the key yourself, or `load-plugin` instead
; of `declare-plugin` to get it for free (see README.md).
(declare-plugin "cvlmtg/grep.hume"
  #:commands '("live-grep" "live-grep-selection"))
