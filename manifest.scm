; Default activation for `(declare-plugin "cvlmtg/grep.hume")` with no
; explicit #:commands/#:events/#:languages — see README.md "Usage" for what
; each command does and why lazy activation alone doesn't bind `g /`.
(declare-plugin "cvlmtg/grep.hume"
  #:commands '("live-grep" "live-grep-selection"))
