#!/usr/bin/env bash
# invariants this repo documents but nothing enforces:
# - README's Config table matches the keys plugin.scm actually reads
# - README's Requirements version matches tests/lib.sh's MIN_HUME_VERSION
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

# --- README's Requirements version vs tests/lib.sh's MIN_HUME_VERSION ------
min_version="$(grep -oE '^MIN_HUME_VERSION="[^"]*"' tests/lib.sh | grep -oE '"[^"]*"' | tr -d '"')"
readme_version="$(grep -oE '^- HUME [0-9]+\.[0-9]+\.[0-9]+ or later\.' README.md | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
if [[ "$min_version" != "$readme_version" ]]; then
    note "README Requirements says HUME $readme_version, but tests/lib.sh's MIN_HUME_VERSION is $min_version"
fi

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
