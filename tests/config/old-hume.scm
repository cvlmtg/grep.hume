;;; An editor older than the supported version: the plugin must refuse to
;;; load, naming itself and the version it needs.
(load-plugin! "core:stdlib")
(define (hume-version>=? major minor patch) #f)
(load-plugin! "@PLUGIN@")
