;;; cvlmtg/grep.hume — live grep in the fuzzy picker.

(define grep/plugin "cvlmtg/grep.hume")

(unless (hume-version>=? 0 18 0)
  (error (string-append grep/plugin ": requires HUME 0.18.0 or later")))

(unless (member "core:stdlib" (declared-plugins))
  (error (string-append grep/plugin ": requires core:stdlib — (load-plugin! \"core:stdlib\") before (load-plugin! \"" grep/plugin "\")")))

;; ── Config ────────────────────────────────────────────────────────────────────
;; Every key is read here, at load, so a bad value errors when the plugin
;; loads instead of from inside a search. See README's Config table for what
;; each key controls.

(define grep/cfg (plugin-config))

(define grep/default-program (or (find-program "rg") "grep"))
(define grep/program
  (call! "stdlib/config-string" grep/plugin grep/cfg 'program grep/default-program))

(unless (find-program grep/program)
  (error (string-append grep/plugin ": 'program (" grep/program
                         ") is not on PATH — install it, or set 'program to one that is")))

;;; Output shape to parse — see README's Config table and Known limitations
;;; for what each of the three means. Defaults to whichever shape matches
;;; `program`; only a third program, or an 'args override dropping
;;; `--null`, needs 'format set explicitly. Windows' PATHEXT resolves "rg"
;;; to an "rg.exe" in any casing.
(define grep/default-format
  (let ([base (file-name grep/program)])
    (if (or (equal? base "rg") (equal? (string-downcase base) "rg.exe"))
        'vimgrep-null
        'grep)))
(define grep/format
  (call! "stdlib/config-enum" grep/plugin grep/cfg 'format grep/default-format
         '(vimgrep-null vimgrep grep)))

;;; Argv before the pattern; the pattern and search root (".") are appended
;;; after (see `grep/open!`). `--` stops a pattern starting with "-" from
;;; being read as a flag. rg's `--column` gives one row per matching line,
;;; at its first match, where `--vimgrep` repeats the line once per match.
;;; See README's Known limitations for what `-m`/`-M` actually bound.
(define grep/default-args
  (if (equal? grep/format 'grep)
      '("-rnI" "-i" "--exclude-dir=.git" "--color=never" "--")
      (append '("--column" "--with-filename" "--no-heading" "--color" "never")
              (if (equal? grep/format 'vimgrep-null) '("--null") '())
              '("--smart-case" "-m" "1000" "-M" "512" "--max-columns-preview" "--"))))
(define grep/args
  (call! "stdlib/config-list" grep/plugin grep/cfg 'args grep/default-args))

;;; Keystrokes are human-rate; searching on every one would spawn and kill
;;; a process mid-word for nothing. `live-picker!` re-validates this same
;;; shape at spawn time — checked here too for an earlier, key-named error.
(define grep/debounce-ms
  (call! "stdlib/config-integer" grep/plugin grep/cfg 'debounce-ms 120 0))

;; ── Selection seeding ─────────────────────────────────────────────────────────

;;; Text of the primary selection, or #f if it's collapsed (a bare cursor,
;;; or a single-character selection — anchor = head either way, nothing
;;; distinguishes them) or spans more than one line.
(define (grep/primary-selection-text pane)
  (let ([primary (call! "stdlib/primary-selection" (buffer-selections pane))])
    (and primary
         (not (= (selection-anchor primary) (selection-head primary)))
         (let* ([start (selection-start-char primary)]
                [end (selection-end-char primary)]
                [line (char-offset->line pane start)]
                [line-offset (line->char-offset pane line)]
                [line-text (car (buffer-lines pane
                                              #:range (hash 'start-line line 'end-line (+ line 1))))])
           (and (= line (char-offset->line pane (- end 1)))
                ;; A whole-line selection ("x"/"X"/Ctrl+x) covers the
                ;; line's trailing "\n", but `buffer-lines` strips it —
                ;; clamp to the stripped length instead of overrunning it.
                (substring line-text
                           (- start line-offset)
                           (min (- end line-offset) (string-length line-text))))))))

;; ── Result-row parsing ────────────────────────────────────────────────────────

;;; Steel's `split-once` returns `#t` (not `#f`) when `sep` doesn't occur in
;;; `s` — wrap it to fail closed the way every parser below expects.
(define (grep/split-once s sep)
  (let ([parts (split-once s sep)])
    (and (list? parts) parts)))

(define grep/nul "\x0;")

;;; A parsed result row. `byte-col` is #f when the format reports no column.
(struct grep/hit (path line byte-col text))

;;; 0-based char index at 1-based UTF-8 byte offset `byte-col` (rg
;;; `--vimgrep`'s column unit) — `goto-location!` counts chars, so a
;;; multi-byte character before the match needs this conversion. A
;;; `byte-col` of #f or 1 lands at char 0. The `min` clamp is required, not
;;; defensive: an out-of-range `end` on `bytes->string/utf8` is an
;;; unrecoverable slice panic, not a catchable Steel error.
(define (grep/byte-col->char-col line byte-col)
  (if (and byte-col (> byte-col 1))
      (let ([bytes (string->bytes line)])
        (string-length (bytes->string/utf8 bytes 0 (min (- byte-col 1) (bytes-length bytes)))))
      0))

;;; Shared by both vimgrep shapes — they differ only in the path
;;; terminator (":" vs NUL); line/col/text are colon-separated either way.
;;; `#f` if the row doesn't split into these parts, or a numeric field
;;; fails to parse (a malformed row, not a HUME/rg bug).
(define (grep/parse-vimgrep-shaped-row row path-sep)
  (let* ([path+rest (grep/split-once row path-sep)]
         [line+rest (and path+rest (grep/split-once (cadr path+rest) ":"))]
         [col+text (and line+rest (grep/split-once (cadr line+rest) ":"))]
         [line (and col+text (string->number (car line+rest)))]
         [byte-col (and col+text (string->number (car col+text)))])
    (and (integer? line) (integer? byte-col)
         (grep/hit (car path+rest) line byte-col (cadr col+text)))))

;;; `path:line:text`, which has no column.
(define (grep/parse-grep-row row)
  (let* ([path+rest (grep/split-once row ":")]
         [line+text (and path+rest (grep/split-once (cadr path+rest) ":"))]
         [line (and line+text (string->number (car line+text)))])
    (and (integer? line)
         (grep/hit (car path+rest) line #f (cadr line+text)))))

(define (grep/parse-row row)
  (cond [(equal? grep/format 'vimgrep-null) (grep/parse-vimgrep-shaped-row row grep/nul)]
        [(equal? grep/format 'vimgrep) (grep/parse-vimgrep-shaped-row row ":")]
        [else (grep/parse-grep-row row)]))

;;; #f (an accept key pressed while no row matches) is a no-op.
;;; `goto-location!` answers #f, moving nothing, when the row's line is gone
;;; from the file.
(define (grep/goto! row)
  (when row
    (let ([hit (grep/parse-row row)])
      (if hit
          (let ([path (grep/hit-path hit)]
                [line (grep/hit-line hit)])
            (unless (goto-location! (focused-pane)
                                    (hash 'target path
                                          'line (- line 1)
                                          'char-col (grep/byte-col->char-col (grep/hit-text hit)
                                                                             (grep/hit-byte-col hit))))
              (log! 'warning (string-append "grep: " path " has no line " (number->string line)))))
          (log! 'error (string-append "grep: could not parse result row: " row))))))

;; ── Row rendering ─────────────────────────────────────────────────────────────

(define (grep/span start end scope)
  (hash 'start-char start 'end-char end 'scope scope))

;;; A span that takes the picker's selected style on the selected row, where
;;; a theme's own color for `scope` can match that style's background.
(define (grep/part-span start end scope)
  (hash-insert (grep/span start end scope) 'selected-scope "ui.text.focus"))

;;; Char index in `text` where `query` occurs, compared without case, or #f.
;;; `char-col` is where the search program reported its match, kept only when
;;; the text there is the query, so a regex query gets #f unless it matched
;;; its own text. With no column (grep format) the first exact occurrence
;;; wins over a case-folded one, so a case-sensitive 'args highlights what it
;;; matched.
(define (grep/match-start text char-col query)
  (let* ([len (string-length query)]
         [index-in (lambda (haystack needle)
                     (let ([parts (grep/split-once haystack needle)])
                       (and parts (string-length (car parts)))))]
         [start (and (> len 0)
                     (or char-col
                         (index-in text query)
                         (index-in (string-downcase text) (string-downcase query))))])
    (and start
         (<= (+ start len) (string-length text))
         (string-ci=? (substring text start (+ start len)) query)
         start)))

;;; A parsed row as shown: its directory, line, column and match styled, and
;;; its text without indentation. A row wider than `budget` loses the front
;;; of its directory first, until the file name, the location and up to half
;;; the budget of text fit; `#:truncate 'tail` cuts whatever is still over.
(define (grep/row-display hit budget query)
  (let* ([path (grep/hit-path hit)]
         [line (number->string (grep/hit-line hit))]
         [byte-col (grep/hit-byte-col hit)]
         [text (grep/hit-text hit)]
         [col (and byte-col (number->string byte-col))]
         [indent (- (string-length text) (string-length (trim-start text)))]
         ;; As much of the text as the row can show, so a long line costs
         ;; no more than a short one. A match past it is off screen and
         ;; gets no highlight. The extra cell is for the "…" `string-fit`
         ;; adds when it cuts.
         [window (string-fit text (+ (string-width (substring text 0 indent)) budget 1) 'tail)]
         [match (grep/match-start window (and byte-col (grep/byte-col->char-col text byte-col)) query)]
         ;; Indentation stops at the match, so a query starting with spaces
         ;; still shows what it matched.
         [cut (min indent (or match indent))]
         [shown (substring window cut)]
         [name (file-name path)]
         [base (if (and (not (equal? name "")) (ends-with? path name)) name path)]
         [location (string-append ":" line (if col (string-append ":" col) "") ":")]
         [dir-cells (max 0 (- budget
                              (string-width (string-append base location))
                              (min (string-width shown) (quotient budget 2))))]
         [dir (string-fit (substring path 0 (- (string-length path) (string-length base)))
                          dir-cells 'head)]
         [prefix (+ (string-length dir) (string-length base))]
         [line-start (+ prefix 1)]
         [line-end (+ line-start (string-length line))]
         [text-start (+ prefix (string-length location))]
         [match-at (and match (+ text-start (- match cut)))])
    (hash 'text (string-append dir base location shown)
          'spans (append
                  (if (equal? dir "") '() (list (grep/part-span 0 (string-length dir) "comment")))
                  (list (grep/part-span line-start line-end "constant.numeric"))
                  (if col
                      (list (grep/part-span (+ line-end 1) (- text-start 1) "constant.numeric"))
                      '())
                  (if match-at
                      (list (grep/span match-at (+ match-at (string-length query))
                                       "ui.cursor.match.search"))
                      '())))))

;;; `#:render` for a picker searching `query`: a row that doesn't parse shows
;;; as the source gave it, and `grep/goto!` logs it if picked.
(define (grep/render-rows rows budget query)
  (map (lambda (row)
         (let ([hit (grep/parse-row (cdr row))])
           (if hit (grep/row-display hit budget query) (car row))))
       rows))

;; ── Open ──────────────────────────────────────────────────────────────────────

;;; Opens the picker seeded with `seed` (possibly ""). Every query change
;;; re-runs `grep/program` with the query as its pattern; an empty query
;;; clears the rows instead of searching. The keymap's Ctrl-t/v/s place and
;;; focus a new tab or split before calling `grep/goto!`, which targets
;;; `(focused-pane)`.
(define (grep/open! pane seed)
  ;; The query the shown rows answer: the source sets it as it starts a
  ;; search, and every row arriving after that is that search's.
  (let ([searched seed])
    (live-picker! pane (call! "stdlib/picker-keymap" grep/goto!)
                  #:prompt "grep: "
                  #:query seed
                  ;; rg exits 1 for "no matches" — a normal outcome while
                  ;; typing, not a failure worth a message-log entry.
                  #:source (picker-command-source
                            (lambda (query)
                              (set! searched query)
                              (and (not (equal? query ""))
                                   (cons grep/program (append grep/args (list query ".")))))
                            #:ok-exit-codes '(0 1))
                  #:debounce-ms grep/debounce-ms
                  #:render (lambda (rows budget) (grep/render-rows rows budget searched))
                  #:truncate 'tail)))

;; ── Commands ──────────────────────────────────────────────────────────────────

(define-typed-command! "grep"
  "Live-grep the working directory in the fuzzy picker. Optional argument seeds the pattern, e.g. :grep TODO"
  (lambda (pane arg) (grep/open! pane (or arg ""))))

(define-command! "grep/picker"
  "Live-grep the working directory, seeded with the primary selection (when it's non-collapsed and confined to one line)."
  (lambda (pane) (grep/open! pane (or (grep/primary-selection-text pane) ""))))

;; ── Keybindings ───────────────────────────────────────────────────────────────
;; Extend mode falls through to the normal trie, so 'normal alone covers both.
(bind-key! 'normal "z /" "grep/picker")
