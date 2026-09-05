#!/usr/bin/env bash
# invariants this repo documents but nothing enforces:
# - manifest.scm's activation lists match plugin.scm's actual command
#   registrations (both directions)
# - README's Config table matches the keys plugin.scm actually reads
# - every top-level define uses this plugin's naming prefix
# - no tabs or trailing whitespace in a .scm file.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# The only line to change when copying this script to another plugin.
PREFIX="grep/"

fail=0
note() {
    echo "lint: $1" >&2
    fail=1
}

# extract_list <file> <marker> — the quoted strings inside the '(...)  list
# that starts at the first line containing <marker>, through the first line
# closing it with a ')'. Good enough for this repo's own simple, unnested
# lists; not a general Scheme reader.
extract_list() {
    local file="$1" marker="$2"
    grep -v '^[[:space:]]*;' "$file" | awk -v marker="$marker" '
        index($0, marker) { inlist = 1 }
        inlist {
            buf = buf $0 "\n"
            if (index($0, ")") > 0) { print buf; exit }
        }
    ' | grep -oE '"[^"]*"' | tr -d '"'
}

# defined_names <marker> — every "name" in a (marker "name" ...) call in
# plugin.scm, comment lines stripped first so a doc comment mentioning the
# marker in prose is never mistaken for a call.
defined_names() {
    local marker="$1"
    grep -v '^[[:space:]]*;' plugin.scm \
        | grep -oE "${marker}[[:space:]]*\"[^\"]*\"" \
        | grep -oE '"[^"]*"' \
        | tr -d '"'
}

diff_sets() {
    # diff_sets <label> <left-only-message> <right-only-message> <left-list> <right-list>
    #
    # Every comparison below is an `if`, never a bare `X && Y` — under
    # `set -e`, a false `&&` left side as a loop's or function's last
    # executed statement reads as that loop/function itself failing and
    # aborts the whole script, silently, right where it happens to land.
    local label="$1" left_msg="$2" right_msg="$3"
    local -a left=($4) right=($5)
    local item found
    for item in "${left[@]:-}"; do
        [[ -z "$item" ]] && continue
        found=0
        for r in "${right[@]:-}"; do
            if [[ "$item" == "$r" ]]; then
                found=1
                break
            fi
        done
        if [[ "$found" -eq 0 ]]; then
            note "$label: \"$item\" $left_msg"
        fi
    done
    for item in "${right[@]:-}"; do
        [[ -z "$item" ]] && continue
        found=0
        for l in "${left[@]:-}"; do
            if [[ "$item" == "$l" ]]; then
                found=1
                break
            fi
        done
        if [[ "$found" -eq 0 ]]; then
            note "$label: \"$item\" $right_msg"
        fi
    done
}

# --- manifest.scm's activation lists vs plugin.scm's actual commands -------
manifest_commands="$(extract_list manifest.scm '#:commands')"
manifest_typed="$(extract_list manifest.scm '#:typed-commands')"
plugin_commands="$(defined_names 'define-command!')"
plugin_typed="$(defined_names 'define-typed-command!')"

diff_sets "manifest.scm #:commands" \
    "is declared but no define-command! defines it" \
    "is defined via define-command! but missing from manifest.scm" \
    "$manifest_commands" "$plugin_commands"
diff_sets "manifest.scm #:typed-commands" \
    "is declared but no define-typed-command! defines it" \
    "is defined via define-typed-command! but missing from manifest.scm" \
    "$manifest_typed" "$plugin_typed"

# --- README's Config table vs the keys plugin.scm actually reads ----------
readme_keys="$(grep -oE '^\| `"[a-z-]+"`' README.md | grep -oE '"[a-z-]+"' | tr -d '"')"
plugin_keys="$(grep -v '^[[:space:]]*;' plugin.scm \
    | grep -oE "stdlib/config-[a-z]+\" ${PREFIX}plugin ${PREFIX}cfg \"[a-z-]+\"" \
    | grep -oE '"[a-z-]+"$' \
    | tr -d '"')"

diff_sets "README Config table" \
    "is documented but plugin.scm never reads it via stdlib/config-*" \
    "is read via stdlib/config-* but missing from README's Config table" \
    "$readme_keys" "$plugin_keys"

# --- every top-level define uses $PREFIX ------------------------------------
# Matches both (define name ...) and the (define (name args) ...) shorthand
# — [[:space:]]+ must come before the optional "(" or the shorthand form's
# name never matches at all.
bad_defines="$(grep -oE '^\(define[[:space:]]+\(?[a-zA-Z0-9!?*/<>=+-]+' plugin.scm \
    | grep -oE '[a-zA-Z0-9!?*/<>=+-]+$' \
    | grep -v "^${PREFIX}" || true)"
for name in $bad_defines; do
    note "plugin.scm: top-level define \"$name\" doesn't start with \"$PREFIX\" (CONTRIBUTING.md's naming convention)"
done

# --- whitespace hygiene in .scm files ---------------------------------------
tab="$(printf '\t')"
while IFS= read -r -d '' file; do
    if grep -q "$tab" "$file"; then
        note "$file: contains a tab"
    fi
    if grep -qE ' +$' "$file"; then
        note "$file: has trailing whitespace"
    fi
done < <(find . -name '*.scm' -not -path './.git/*' -print0)

if [[ "$fail" -eq 0 ]]; then
    echo "lint: clean"
else
    exit 1
fi
