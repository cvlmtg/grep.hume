;;; cvlmtg/grep.hume — live grep in the fuzzy picker.

(define grep/plugin "cvlmtg/grep.hume")

(unless (member "core:stdlib" (declared-plugins))
  (error (string-append grep/plugin ": requires core:stdlib — (declare-plugin! \"core:stdlib\") or (load-plugin! \"core:stdlib\") before (load-plugin! \"" grep/plugin "\")")))

;; ── Config ────────────────────────────────────────────────────────────────────
;; `(plugin-config)` only returns the real hash while this body is being
;; evaluated — read it now into defines, never from inside a command. See
;; README's Config table for what each key controls.

(define grep/cfg (plugin-config))

(define grep/default-program (or (which "rg") "grep"))
(define grep/program
  (call! "stdlib/config-string" grep/plugin grep/cfg "program" grep/default-program))

;;; Checked at load so a bad "program" errors immediately, not as a silent
;;; empty picker from inside a debounce timer later.
(unless (which grep/program)
  (error (string-append grep/plugin ": \"program\" (" grep/program
                         ") is not on PATH — install it, or set \"program\" to one that is")))

;;; Basename with a ".exe" suffix stripped, case-folded only for that check
;;; — Steel's `which` resolves an unqualified "rg" through Windows' PATHEXT,
;;; whose default casing is ".EXE", so a case-sensitive strip would miss the
;;; plugin's own zero-config default there. A bare (non-".exe") basename
;;; still compares case-sensitively — a program's exact name matters on the
;;; case-sensitive filesystems where no ".exe" is involved.
(define grep/program-name
  (let ([base (file-name grep/program)])
    (if (ends-with? (string-downcase base) ".exe")
        (string-downcase (substring base 0 (- (string-length base) 4)))
        base)))

;;; Output shape to parse — see README's Config table and Known limitations
;;; for what each of the three means. Defaults to whichever shape matches
;;; `program`; only a third program, or an `"args"` override dropping
;;; `--null`, needs `"format"` set explicitly.
(define grep/default-format (if (equal? grep/program-name "rg") 'vimgrep-null 'grep))
(define grep/format
  (call! "stdlib/config-enum" grep/plugin grep/cfg "format" grep/default-format
         '(vimgrep-null vimgrep grep)))

;;; Argv before the pattern; the pattern and search root (".") are appended
;;; after (see `grep/open!`). `--` stops a pattern starting with "-" from
;;; being read as a flag. See README's Known limitations for what `-m`/`-M`
;;; actually bound.
(define grep/default-args
  (cond [(equal? grep/format 'vimgrep-null)
         '("--vimgrep" "--no-heading" "--color" "never" "--null" "--smart-case" "-m" "1000" "-M" "512"
           "--max-columns-preview" "--")]
        [(equal? grep/format 'vimgrep)
         '("--vimgrep" "--no-heading" "--color" "never" "--smart-case" "-m" "1000" "-M" "512"
           "--max-columns-preview" "--")]
        [else '("-rnI" "-i" "--color=never" "--")]))
(define grep/args
  (call! "stdlib/config-list" grep/plugin grep/cfg "args" grep/default-args))

;;; Keystrokes are human-rate; searching on every one would spawn and kill
;;; a process mid-word for nothing. `live-picker!` re-validates this same
;;; shape at spawn time — checked here too for an earlier, key-named error.
(define grep/debounce-ms
  (call! "stdlib/config-integer" grep/plugin grep/cfg "debounce-ms" 120 0))

;; ── Selection seeding ─────────────────────────────────────────────────────────

;;; Text of the primary selection, or #f if it's collapsed (a bare cursor,
;;; or a single-character selection — anchor = head either way, nothing
;;; distinguishes them) or spans more than one line.
(define (grep/primary-selection-text pane)
  (let* ([primary (call! "stdlib/primary-selection" (buffer-selections pane))]
         [collapsed? (or (not primary)
                         (= (call! "stdlib/selection-anchor" primary)
                            (call! "stdlib/selection-head" primary)))])
    (and (not collapsed?)
         (let* ([start (hash-ref primary 'start)]
                [end (hash-ref primary 'end)]
                [line (offset->line pane start)])
           (and (= line (offset->line pane (- end 1)))
                (let* ([line-offset (line->offset pane line)]
                       [line-text (car (buffer-lines pane #:start line #:end (+ line 1)))])
                  ;; A whole-line selection ("x"/"X"/Ctrl+x) covers the
                  ;; line's trailing "\n", but `buffer-lines` strips it —
                  ;; clamp to the stripped length instead of overrunning it.
                  (substring line-text
                             (- start line-offset)
                             (min (- end line-offset) (string-length line-text)))))))))

;; ── Result-row parsing ────────────────────────────────────────────────────────

;;; Steel's `split-once` returns `#t` (not `#f`) when `sep` doesn't occur in
;;; `s` — wrap it to fail closed the way every parser below expects.
(define (grep/split-once s sep)
  (let ([parts (split-once s sep)])
    (and (list? parts) parts)))

(define grep/nul "\x0;")

;;; 0-based char index at 1-based UTF-8 byte offset `byte-col` (rg
;;; `--vimgrep`'s column unit) — `goto-location!` counts chars, so a
;;; multi-byte character before the match needs this conversion. `byte-col`
;;; 0 (grep format's "no column") and 1 both land at char 0. The `min`
;;; clamp is required, not defensive: an out-of-range `end` on
;;; `bytes->string/utf8` is an unrecoverable slice panic, not a catchable
;;; Steel error.
(define (grep/byte-col->char-col line byte-col)
  (if (<= byte-col 1)
      0
      (let ([bytes (string->bytes line)])
        (string-length (bytes->string/utf8 bytes 0 (min (- byte-col 1) (bytes-length bytes)))))))

;;; Shared by both vimgrep shapes — they differ only in the path
;;; terminator (":" vs NUL); line/col/text are colon-separated either way.
;;; `#f` if the row doesn't split into exactly these parts, or a numeric
;;; field fails to parse (a malformed row, not a HUME/rg bug).
(define (grep/parse-vimgrep-shaped-row row path-sep)
  (let* ([path+rest (grep/split-once row path-sep)]
         [line+rest (and path+rest (grep/split-once (cadr path+rest) ":"))]
         [col+text (and line+rest (grep/split-once (cadr line+rest) ":"))]
         [line (and col+text (string->number (car line+rest)))]
         [byte-col (and col+text (string->number (car col+text)))])
    (and (integer? line) (integer? byte-col)
         (list (car path+rest) line byte-col (cadr col+text)))))

;;; `path:line:text` → `(path line 0 text)` — byte-col 0 means "no column",
;;; read by `grep/byte-col->char-col` as start of line.
(define (grep/parse-grep-row row)
  (let* ([path+rest (grep/split-once row ":")]
         [line+text (and path+rest (grep/split-once (cadr path+rest) ":"))]
         [line (and line+text (string->number (car line+text)))])
    (and (integer? line)
         (list (car path+rest) line 0 (cadr line+text)))))

;;; The separator is the only difference between the two vimgrep shapes —
;;; passed straight through rather than a wrapper per shape.
(define (grep/parse-row row)
  (cond [(equal? grep/format 'vimgrep-null) (grep/parse-vimgrep-shaped-row row grep/nul)]
        [(equal? grep/format 'vimgrep) (grep/parse-vimgrep-shaped-row row ":")]
        [else (grep/parse-grep-row row)]))

;;; #f (Esc, or a placement action skipping an empty/not-yet-matching
;;; picker — see `stdlib/buffer-actions`) is a no-op, not an error: only a
;;; row that made it past that guard and still fails to parse is logged.
(define (grep/goto! row)
  (when row
    (let ([parsed (grep/parse-row row)])
      (if parsed
          (let ([path (car parsed)]
                [line (cadr parsed)]
                [byte-col (caddr parsed)]
                [text (cadddr parsed)])
            (goto-location! (focused-pane)
                            (hash 'target path
                                  'line (- line 1)
                                  'char-col (grep/byte-col->char-col text byte-col))))
          (log! 'error (string-append "picker-grep: could not parse result row: " row))))))

;; ── Open ──────────────────────────────────────────────────────────────────────

;;; Opens the picker seeded with `seed` (possibly ""), live: every query
;;; change re-runs `grep/program` instead of filtering already-fetched
;;; rows. `live-picker!` also turns off HUME's local fuzzy filter — the
;;; query already IS the search rg ran, and fuzzy-filtering matched rows
;;; again would drop hits a regex like "foo.*bar" doesn't happen to
;;; fuzzy-match. It stops the previous search before the debounce, not
;;; inside it, so a still-running search never appends stale rows for a
;;; pattern the query box no longer shows — the rows already on screen
;;; stay put, marked as refreshing, until the new search delivers its own.
(define (grep/open! pane seed)
  (live-picker! pane grep/goto!
                #:prompt "grep: "
                #:query seed
                #:command (lambda (query)
                            (and (not (equal? query ""))
                                 (cons grep/program (append grep/args (list query ".")))))
                #:debounce-ms grep/debounce-ms
                ;; rg exits 1 for "no matches" — a normal outcome while
                ;; typing, not a failure worth a message-log entry.
                #:ok-exit-codes '(0 1)
                ;; A result row is "path:line:col:text" — the path is what
                ;; the user is scanning for, not the match text trailing it,
                ;; so an overlong row should drop from the end, not the front.
                #:truncate 'tail
                ;; Ctrl-o/t/v/s open the match in the current pane, a new
                ;; tab, a side-by-side split, or a stacked split —
                ;; `grep/goto!` always targets `(focused-pane)`, which
                ;; these place and focus before calling it.
                #:actions (call! "stdlib/buffer-actions" grep/goto!)))

;; ── Commands ──────────────────────────────────────────────────────────────────

(define-typed-command! "grep"
  "Live-grep the working directory in the fuzzy picker. Optional argument seeds the pattern, e.g. :grep TODO"
  (lambda (pane arg) (grep/open! pane (or arg ""))))

(define-command! "picker-grep"
  "Live-grep the working directory, seeded with the primary selection (when it's non-collapsed and confined to one line)."
  (lambda (pane) (grep/open! pane (or (grep/primary-selection-text pane) ""))))

;; ── Keybindings ───────────────────────────────────────────────────────────────
;; Extend mode falls through to the normal trie, so 'normal alone covers both.
(bind-key! 'normal "g /" "picker-grep")
