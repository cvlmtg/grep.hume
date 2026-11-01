;;; fake.scm under the grep-test fixture theme, whose one foreground per
;;; scope lets a case check which part of a row each scope colors.
(load-plugin! "core:stdlib")
(load-plugin! "@PLUGIN@"
             #:config (hash 'program "@PROGRAM@" 'format '@FORMAT@))
(configure-statusline! '("FileName") '() '("Position"))
(set-option! "theme" "grep-test")
