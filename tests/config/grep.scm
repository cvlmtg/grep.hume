;;; The real `grep` as 'program, with 'format and 'args left to the
;;; plugin's own defaults for it.
(load-plugin! "core:stdlib")
(load-plugin! "@PLUGIN@" #:config (hash 'program "grep"))
(configure-statusline! '("FileName") '() '("Position"))
