;;; cvlmtg/grep.hume — live grep in the fuzzy picker.
;;;
;;; Built entirely from the public plugin API (`live-picker!`), the same as
;;; core:pickers — nothing here needs a capability third-party plugins
;;; don't have. See README.md for usage.

;;; Depends on core:stdlib (config validation calls stdlib/config-string
;;; /stdlib/config-enum, and primary-selection lookup calls stdlib/find,
;;; all via call!) — load it first, same as core:pickers.

(unless (member "core:stdlib" (declared-plugins))
  (error "cvlmtg/grep.hume: requires core:stdlib — (declare-plugin \"core:stdlib\") or (load-plugin \"core:stdlib\") before (load-plugin \"cvlmtg/grep.hume\")"))

;; ── Config ────────────────────────────────────────────────────────────────────
;; `(plugin-config)` only returns the real hash while this body is being
;; evaluated — read it now into defines, never from inside a command. See
;; README's Config table for what each key controls.

;;; `stdlib/config-value`'s shape (present? else default), for the two config
;;; keys core:stdlib has no typed accessor for — it covers boolean/string/enum,
;;; not "list" or "integer". Not reachable via `call!` itself (no
;;; `define-command!`, no manifest export), so reimplemented here rather
;;; than imported.
(define (grep/config-value cfg key default)
  (if (hash-contains? cfg key) (hash-ref cfg key) default))

(define (grep/config-list plugin cfg key default)
  (let ([v (grep/config-value cfg key default)])
    (unless (and (list? v) (null? (filter (lambda (x) (not (string? x))) v)))
      (error (string-append plugin ": \"" key "\" must be a list of strings")))
    v))

(define (grep/config-integer plugin cfg key default)
  (let ([v (grep/config-value cfg key default)])
    (unless (and (integer? v) (>= v 0))
      (error (string-append plugin ": \"" key "\" must be a non-negative integer")))
    v))

;;; `rg` when it's on PATH, else `grep` — "any other program can be
;;; configured" via `#:config (hash "program" ...)`.
(define grep/default-program (or (which "rg") "grep"))
(define grep/program
  (call! "stdlib/config-string" "cvlmtg/grep.hume" (plugin-config) "program" grep/default-program))

;;; Fails loudly at load if the resolved binary isn't runnable — otherwise
;;; the first sign of trouble is an empty picker from inside a debounce
;;; timer, with no link back to the config key that caused it.
(unless (which grep/program)
  (error (string-append "cvlmtg/grep.hume: \"program\" (" grep/program
                         ") is not on PATH — install it, or set \"program\" to one that is")))

;;; Basename of `grep/program`, POSIX separator only — a Windows path is a
;;; known gap, not solved here (see README's Known limitations). Used to
;;; tell rg from grep by identity, not by the exact string configured, so
;;; `"program" "/opt/homebrew/bin/rg"` still means rg.
(define grep/program-name (car (reverse (split-many grep/program "/"))))

;;; Output shape: `'vimgrep-null` is `path\0line:col:text` (rg's `--vimgrep
;;; --null`, 1-based byte column, NUL-terminated path — see grep/nul below);
;;; `'vimgrep` is the same without `--null` (`path:line:col:text`, breaks on
;;; a literal ":" in the path); `'grep` is `path:line:text` (no column).
;;; Defaults to whichever shape matches `program`, so a bare rg/grep setup
;;; needs no `"format"` override — a *third* program needs one, and so does
;;; overriding `"args"` to drop `--null` (pair that with `"format" 'vimgrep`).
(define grep/default-format (if (equal? grep/program-name "rg") 'vimgrep-null 'grep))
(define grep/format
  (call! "stdlib/config-enum" "cvlmtg/grep.hume" (plugin-config) "format" grep/default-format
         '(vimgrep-null vimgrep grep)))

;;; Argv placed before the pattern; the pattern and the search root (".")
;;; are appended after (see `grep/open!`). `--` before the pattern stops
;;; either tool from treating a pattern starting with "-" as a flag. `-m`/
;;; `-M` bound a single search's cost: a metacharacter-heavy pattern typed
;;; on the way to a narrower one (e.g. "\b" before "\bfoo\b") can otherwise
;;; match millions of lines before the next keystroke cancels it, and
;;; HUME's picker never truncates what it's given.
(define grep/default-args
  (cond [(equal? grep/format 'vimgrep-null)
         '("--vimgrep" "--no-heading" "--color" "never" "--null" "-m" "1000" "-M" "512" "--")]
        [(equal? grep/format 'vimgrep)
         '("--vimgrep" "--no-heading" "--color" "never" "-m" "1000" "-M" "512" "--")]
        [else '("-rnI" "--color=never" "--")]))
(define grep/args
  (grep/config-list "cvlmtg/grep.hume" (plugin-config) "args" grep/default-args))

;;; Milliseconds to wait after the last keystroke before re-running the
;;; search — keystrokes are human-rate, but a search per keystroke would
;;; still spawn and kill a process on every one of them for nothing while
;;; the user is mid-word.
(define grep/debounce-ms
  (grep/config-integer "cvlmtg/grep.hume" (plugin-config) "debounce-ms" 120))

;; ── Selection seeding ─────────────────────────────────────────────────────────

;;; Text of the primary selection, or #f if it's collapsed (a bare cursor,
;;; or a genuine single-character selection — anchor = head is both in
;;; HUME's model, and no predicate can tell them apart) or spans more than
;;; one line (a nonsense grep seed). `current-selections` triples are raw
;;; `(anchor head primary?)`; `stdlib/find` locates the primary one without
;;; assuming its position in the list, but car/cadr on the triple it finds
;;; still reads the fields directly — the named accessors that would avoid
;;; that (`stdlib/selection-anchor`/`-head`) exist in core:stdlib but aren't
;;; `define-command!`'d, so `call!` can't reach them. `core:lsp` reads this
;;; same triple shape the same way.
(define (grep/primary-selection-text)
  (let ([sels (current-selections)])
    (and sels
         (let* ([primary (call! "stdlib/find" caddr sels)]
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
                         ;; `end` lands ON the line's trailing "\n" for a
                         ;; whole-line selection ("x"/"X"/Ctrl+x select
                         ;; through the break), but `buffer-lines` strips
                         ;; it — clamp to the stripped length instead of
                         ;; overrunning it.
                         (substring line-text
                                    (- start line-offset)
                                    (min (+ (- end line-offset) 1) (string-length line-text)))))))))))

;; ── Result-row parsing ────────────────────────────────────────────────────────

;;; Steel's `split-once` returns `#t` (not `#f`) when `sep` doesn't occur in
;;; `s` — wrap it to fail closed the way every parser below expects.
(define (grep/split-once s sep)
  (let ([parts (split-once s sep)])
    (and (list? parts) parts)))

;;; The NUL byte `--null` uses to terminate the path field, built via
;;; `integer->char` rather than a string escape literal.
(define grep/nul (string (integer->char 0)))

;;; 0-based char index into `line` at 1-based UTF-8 byte offset `byte-col` —
;;; `rg --vimgrep`'s column unit ("one byte is equal to one column", rg's
;;; own --column doc). `goto-location!` counts chars, so any multi-byte
;;; character before the match needs this conversion or the cursor lands
;;; short of the real match. `byte-col` 0 (the grep-format placeholder for
;;; "no column reported") and `byte-col` 1 (the first byte) both land at
;;; char 0. The `min` clamp is required, not defensive: an out-of-range
;;; `end` on `bytes->string/utf8` is an unrecoverable slice panic, not a
;;; catchable Steel error.
(define (grep/byte-col->char-col line byte-col)
  (if (<= byte-col 1)
      0
      (let ([bytes (string->bytes line)])
        (string-length (bytes->string/utf8 bytes 0 (min (- byte-col 1) (bytes-length bytes)))))))

;;; Shared by both vimgrep row shapes — they differ only in what terminates
;;; the path field (":" for plain `--vimgrep`, NUL for `--vimgrep --null`);
;;; `line`/`col`/`text` are colon-separated either way. `#f` if the row
;;; doesn't split into exactly these parts, or either numeric field fails
;;; to parse (a malformed row, not a HUME/rg bug).
(define (grep/parse-vimgrep-shaped-row row path-sep)
  (let ([path+rest (grep/split-once row path-sep)])
    (and path+rest
         (let ([line+rest (grep/split-once (cadr path+rest) ":")])
           (and line+rest
                (let ([col+text (grep/split-once (cadr line+rest) ":")])
                  (and col+text
                       (let ([line (string->number (car line+rest))]
                             [byte-col (string->number (car col+text))])
                         (and (integer? line) (integer? byte-col)
                              (list (car path+rest) line byte-col (cadr col+text)))))))))))

;;; `path:line:col:text` (rg's `--vimgrep`, no `--null`) — still breaks on a
;;; path containing ":" the way vim's own errorformat does for this shape
;;; (README's Known limitations); the default `'vimgrep-null` shape doesn't.
(define (grep/parse-vimgrep-row row) (grep/parse-vimgrep-shaped-row row ":"))

;;; `path\0line:col:text` (rg's `--vimgrep --null`) — NUL terminates the
;;; path only, so a colon inside the path itself never breaks the parse.
(define (grep/parse-vimgrep-null-row row) (grep/parse-vimgrep-shaped-row row grep/nul))

;;; `path:line:text` (rg without `--vimgrep`, or GNU grep) → `(path line 0
;;; text)` — byte-col 0 stands for "no column reported", read by
;;; `grep/byte-col->char-col` as "start of line".
(define (grep/parse-grep-row row)
  (let ([path+rest (grep/split-once row ":")])
    (and path+rest
         (let ([line+text (grep/split-once (cadr path+rest) ":")])
           (and line+text
                (let ([line (string->number (car line+text))])
                  (and (integer? line)
                       (list (car path+rest) line 0 (cadr line+text)))))))))

(define (grep/parse-row row)
  (cond [(equal? grep/format 'vimgrep-null) (grep/parse-vimgrep-null-row row)]
        [(equal? grep/format 'vimgrep) (grep/parse-vimgrep-row row)]
        [else (grep/parse-grep-row row)]))

;;; rg's `-M` (in `grep/default-args`) replaces an over-long line's text
;;; with this marker, keeping the row's real byte column but nothing for
;;; `grep/byte-col->char-col` to walk — recognize it and land at column 0
;;; instead of the placeholder's own (meaningless) length.
(define grep/omitted-line-marker "[Omitted long line with ")

(define (grep/goto! row)
  (let ([parsed (grep/parse-row row)])
    (if parsed
        (let ([path (car parsed)]
              [line (cadr parsed)]
              [byte-col (caddr parsed)]
              [text (cadddr parsed)])
          (goto-location! (list path (- line 1)
                                (if (starts-with? text grep/omitted-line-marker)
                                    0
                                    (grep/byte-col->char-col text byte-col)))))
        (log! 'error (string-append "live-grep: could not parse result row: " row)))))

;; ── Open ──────────────────────────────────────────────────────────────────────

;;; Opens the picker seeded with `seed` (possibly ""), live: every query
;;; change re-runs `grep/program` with the new pattern instead of just
;;; filtering rows already fetched. `live-picker!` (not `picker!`) is what
;;; makes this live — it opens in a mode where HUME's own local fuzzy
;;; filter is off, since the query already IS the search rg just ran, and a
;;; second fuzzy pass over already-matched rows would drop hits a regex
;;; like "foo.*bar" doesn't happen to fuzzy-match. It also stops the
;;; previous search and clears its rows before the debounce, not inside it,
;;; so a still-running search never refills a picker the user just cleared.
(define (grep/open! seed)
  (live-picker! (lambda (row) (when row (grep/goto! row)))
                #:prompt "grep: "
                #:query seed
                #:command (lambda (query)
                            (and (not (equal? query ""))
                                 (cons grep/program (append grep/args (list query ".")))))
                #:debounce-ms grep/debounce-ms
                ;; rg exits 1 for "no matches" — a normal outcome while
                ;; typing, not a failure worth a message-log entry.
                #:ok-exit-codes '(0 1)))

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
