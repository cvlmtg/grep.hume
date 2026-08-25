;;; cvlmtg/grep.hume — live grep in the fuzzy picker.
;;;
;;; Built entirely from the public plugin API (`picker!`, `picker-replace!`,
;;; `picker-source-spawn!`), the same as core:pickers — nothing here needs a
;;; capability third-party plugins don't have. See README.md for usage.
;;;
;;; Depends on core:stdlib (config validation calls stdlib/config-string
;;; /stdlib/config-enum via call!) — load it first, same as core:pickers.

(unless (member "core:stdlib" (declared-plugins))
  (error "cvlmtg/grep.hume: requires core:stdlib — (declare-plugin \"core:stdlib\") or (load-plugin \"core:stdlib\") before (load-plugin \"cvlmtg/grep.hume\")"))

;; ── Config ────────────────────────────────────────────────────────────────────
;; `(plugin-config)` only returns the real hash while this body is being
;; evaluated — read it now into defines, never from inside a command. See
;; README's Config table for what each key controls.

;;; `stdlib/config-value`'s shape (present? else default), for the two config
;;; keys core:stdlib has no typed accessor for — it covers boolean/string/enum,
;;; not "list" or "integer".
(define (grep/config-value cfg key default)
  (if (hash-contains? cfg key) (hash-ref cfg key) default))

(define (grep/config-list plugin cfg key default)
  (let ([v (grep/config-value cfg key default)])
    (unless (list? v)
      (error (string-append plugin ": \"" key "\" must be a list")))
    v))

(define (grep/config-integer plugin cfg key default)
  (let ([v (grep/config-value cfg key default)])
    (unless (integer? v)
      (error (string-append plugin ": \"" key "\" must be an integer")))
    v))

;;; `rg` when it's on PATH, else `grep` — "any other program can be
;;; configured" via `#:config (hash "program" ...)`.
(define grep/default-program (if (which "rg") "rg" "grep"))
(define grep/program
  (call! "stdlib/config-string" "cvlmtg/grep.hume" (plugin-config) "program" grep/default-program))

;;; Output shape: `'vimgrep` is `path:line:col:text` (rg's `--vimgrep`,
;;; 1-based byte column); `'grep` is `path:line:text` (no column). Defaults
;;; to whichever shape matches `program`, so a bare rg/grep setup needs no
;;; `"format"` override — only a *third* program (not rg or grep) does.
(define grep/default-format (if (equal? grep/program "rg") 'vimgrep 'grep))
(define grep/format
  (call! "stdlib/config-enum" "cvlmtg/grep.hume" (plugin-config) "format" grep/default-format '(vimgrep grep)))

;;; Argv placed before the pattern; the pattern and the search root (".")
;;; are appended after (see `grep/open!`). `--` before the pattern stops
;;; either tool from treating a pattern starting with "-" as a flag.
(define grep/default-args
  (if (equal? grep/format 'vimgrep)
      '("--vimgrep" "--no-heading" "--color" "never" "--")
      '("-rnI" "--color=never" "--")))
(define grep/args
  (grep/config-list "cvlmtg/grep.hume" (plugin-config) "args" grep/default-args))

;;; Milliseconds to wait after the last keystroke before re-running the
;;; search — keystrokes are human-rate, but a search per keystroke would
;;; still spawn and kill a process on every one of them for nothing while
;;; the user is mid-word.
(define grep/debounce-ms
  (grep/config-integer "cvlmtg/grep.hume" (plugin-config) "debounce-ms" 120))

;; ── Selection seeding ─────────────────────────────────────────────────────────

;;; Text of the primary selection, or #f if it's collapsed (a bare cursor —
;;; anchor = head, HUME has no zero-width selection) or spans more than one
;;; line (a nonsense grep seed). `current-selections` triples are raw
;;; `(anchor head primary?)` — car/cadr/caddr directly, the way
;;; core:lsp's `lsp/primary-selection-range` does, since the accessor
;;; functions that keep this opaque live in core:stdlib's own private module
;;; scope and aren't reachable from another plugin.
(define (grep/primary-selection-text)
  (let ([sels (current-selections)])
    (and sels
         (let* ([primary (car (filter caddr sels))]
                [anchor (car primary)]
                [head (cadr primary)])
           (and (not (= anchor head))
                (let* ([start (min anchor head)]
                       [end (max anchor head)]
                       [start-line (char-index->line start)]
                       [end-line (char-index->line end)])
                  (and start-line end-line (= start-line end-line)
                       (let* ([content-line (- start-line 1)]
                              [line-offset (line->offset (current-buffer) content-line)]
                              [line-text (car (buffer-lines (current-buffer)
                                                             #:start content-line
                                                             #:end (+ content-line 1)))])
                         (substring line-text
                                    (- start line-offset)
                                    (+ (- end line-offset) 1))))))))))

;; ── Result-row parsing ────────────────────────────────────────────────────────

;;; UTF-8 byte length of one Unicode scalar value.
(define (grep/utf8-byte-length ch)
  (let ([cp (char->integer ch)])
    (cond [(< cp #x80) 1]
          [(< cp #x800) 2]
          [(< cp #x10000) 3]
          [else 4])))

;;; 0-based char index into `line` at 1-based UTF-8 byte offset `byte-col` —
;;; `rg --vimgrep`'s column unit ("one byte is equal to one column", rg's
;;; own --column doc). `goto-location!` counts chars, so any multi-byte
;;; character before the match needs this conversion or the cursor lands
;;; short of the real match. `byte-col` 0 (the grep-format placeholder for
;;; "no column reported") lands at char 0 by the same formula — the target
;;; byte offset `-1` is met before the loop's first step.
(define (grep/byte-col->char-col line byte-col)
  (let loop ([i 0] [bytes-seen 0])
    (cond [(>= bytes-seen (- byte-col 1)) i]
          [(>= i (string-length line)) i] ; defensive: shouldn't happen against rg's own line
          [else (loop (+ i 1) (+ bytes-seen (grep/utf8-byte-length (string-ref line i))))])))

;;; Index of the n-th (1-based) occurrence of `ch` in `s`, or #f. A manual
;;; scan, not a generic split — a row must split on the first two or three
;;; colons only, since the path or the matched text itself may contain more.
(define (grep/nth-char-index s ch n)
  (let loop ([i 0] [remaining n])
    (cond [(>= i (string-length s)) #f]
          [(char=? (string-ref s i) ch)
           (if (= remaining 1) i (loop (+ i 1) (- remaining 1)))]
          [else (loop (+ i 1) remaining)])))

;;; `path:line:col:text` → `(path line byte-col text)`, or #f if the row has
;;; fewer than 3 colons (should not happen against rg's own output).
(define (grep/parse-vimgrep-row row)
  (let* ([c1 (grep/nth-char-index row #\: 1)]
         [c2 (and c1 (grep/nth-char-index row #\: 2))]
         [c3 (and c2 (grep/nth-char-index row #\: 3))])
    (and c3
         (list (substring row 0 c1)
               (string->number (substring row (+ c1 1) c2))
               (string->number (substring row (+ c2 1) c3))
               (substring row (+ c3 1) (string-length row))))))

;;; `path:line:text` → `(path line 0 text)` — byte-col 0 stands for "no
;;; column reported", read by `grep/byte-col->char-col` as "start of line".
(define (grep/parse-grep-row row)
  (let* ([c1 (grep/nth-char-index row #\: 1)]
         [c2 (and c1 (grep/nth-char-index row #\: 2))])
    (and c2
         (list (substring row 0 c1)
               (string->number (substring row (+ c1 1) c2))
               0
               (substring row (+ c2 1) (string-length row))))))

(define (grep/parse-row row)
  (if (equal? grep/format 'vimgrep)
      (grep/parse-vimgrep-row row)
      (grep/parse-grep-row row)))

;;; A path containing ":" (rare on POSIX, common in a Windows drive path)
;;; breaks this parse the same way it breaks vim's own errorformat — not
;;; solved here, just documented (README).
(define (grep/goto! row)
  (let ([parsed (grep/parse-row row)])
    (if parsed
        (let ([path (car parsed)]
              [line (cadr parsed)]
              [byte-col (caddr parsed)]
              [text (cadddr parsed)])
          (goto-location! (list path (- line 1) (grep/byte-col->char-col text byte-col))))
        (log! 'error (string-append "live-grep: could not parse result row: " row)))))

;; ── Open ──────────────────────────────────────────────────────────────────────

;;; Opens the picker seeded with `seed` (possibly ""), live: every query
;;; change re-runs `grep/program` with the new pattern instead of just
;;; filtering rows already fetched — the local fuzzy filter is off in this
;;; mode (see #:on-query-change in the user manual's "Custom pickers"), since
;;; the query already IS the search rg just ran, so a second fuzzy pass over
;;; already-matched rows would drop hits a regex like "foo.*bar" doesn't
;;; happen to fuzzy-match.
(define (grep/open! seed)
  (let* ([token #f]
         [requery
          (debounce grep/debounce-ms
            (lambda (query)
              ;; Replace BEFORE spawning: items are append-only, so the
              ;; previous pattern's rows must be cleared explicitly before
              ;; the new search's rows start arriving.
              (picker-replace! token '())
              (unless (equal? query "")
                (picker-source-spawn! token grep/program
                                      (append grep/args (list query "."))
                                      ;; rg exits 1 for "no matches" — a
                                      ;; normal outcome while typing, not a
                                      ;; failure worth a message-log entry.
                                      #:ok-exit-codes '(0 1)))))])
    (set! token
      (picker! '()
               (lambda (row) (when row (grep/goto! row)))
               #:prompt "grep: "
               #:query seed
               #:on-query-change requery))
    ;; `#:query` only prefills what's shown in the panel — it deliberately
    ;; does not fire `#:on-query-change` itself, so a non-empty seed needs
    ;; its own explicit kick to actually run a search.
    (unless (equal? seed "") (requery seed))))

;; ── Commands ──────────────────────────────────────────────────────────────────

(define-command! "live-grep"
  "Live-grep the working directory in the fuzzy picker. Optional argument seeds the pattern, e.g. :live-grep TODO"
  (lambda (arg) (grep/open! (if (string? arg) arg ""))))

(define-command! "live-grep-selection"
  "Live-grep the working directory, seeded with the primary selection (when it's non-collapsed and confined to one line)."
  (lambda () (grep/open! (or (grep/primary-selection-text) ""))))

;; ── Keybindings ───────────────────────────────────────────────────────────────
;; Extend mode falls through to the normal trie, so 'normal alone covers both.
(bind-key! 'normal "g /" "live-grep-selection")
