#!/usr/bin/env bash
# multiternary.sh — multi-ternary evaluator for bash
# Usage: multiternary <value> <pat1> <result1> [<pat2> <result2> ...] [default]
#
# Example:
#   multiternary 3 1 "one" 2 "two" 3 "three" "unknown"
#   → three
#
#   # Regex mode:
#   multiternary "hello world" "^hello" "greeting" "^bye" "farewell" "neutral"
#   → greeting

multiternary() {
    local value="$1"; shift
    local fallback=""

    # If odd number of remaining args, last one is the default
    if (( $# % 2 == 1 )); then
        fallback="${@: -1}"
        set -- "${@:1:$(($#-1))}"
    fi

    while (( $# >= 2 )); do
        local pattern="$1"
        local result="$2"
        shift 2
        if [[ "$value" =~ ^${pattern}$ ]] || [[ "$value" == "$pattern" ]]; then
            echo "$result"
            return 0
        fi
    done

    echo "$fallback"
}

# Numeric range ternary (ternary tree over ranges)
# Usage: range_ternary <number> <lo1> <hi1> <r1> [<lo2> <hi2> <r2> ...] [default]
range_ternary() {
    local n="$1"; shift
    local fallback=""
    if (( $# % 3 == 1 )); then
        fallback="${@: -1}"
        set -- "${@:1:$(($#-1))}"
    fi
    while (( $# >= 3 )); do
        local lo="$1" hi="$2" result="$3"; shift 3
        if (( n >= lo && n <= hi )); then
            echo "$result"; return 0
        fi
    done
    echo "$fallback"
}

# ── Self-test (run this file directly to verify) ──────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== multiternary self-test ==="
    multiternary "foo"  "bar" "is-bar" "foo" "is-foo"  "unknown"
    multiternary "baz"  "bar" "is-bar" "foo" "is-foo"  "unknown"
    multiternary "^hel" "^hel" "greeting" "^bye" "farewell" "neutral"

    echo "=== range_ternary self-test ==="
    range_ternary 5   0 5 "low" 6 10 "mid" 11 100 "high" "out-of-range"
    range_ternary 8   0 5 "low" 6 10 "mid" 11 100 "high" "out-of-range"
    range_ternary 999 0 5 "low" 6 10 "mid" 11 100 "high" "out-of-range"
fi
