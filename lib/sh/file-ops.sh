#!/bin/bash
# file-ops.sh — Sashi File Operations Library v3.2.2
# Spec: Operation Type | File Details | Performance | Error Handling
# Source: source ~/ollama-local/lib/sh/file-ops.sh

# ── Colors ────────────────────────────────────────────────────────────
_FO_RED='\033[0;31m'; _FO_GRN='\033[0;32m'; _FO_YLW='\033[0;33m'
_FO_CYN='\033[0;36m'; _FO_DIM='\033[2m';    _FO_BLD='\033[1m'; _FO_NC='\033[0m'

_fo_ok()   { echo -e "${_FO_GRN}✔${_FO_NC} $*"; }
_fo_err()  { echo -e "${_FO_RED}✘${_FO_NC} $*" >&2; }
_fo_warn() { echo -e "${_FO_YLW}⚠${_FO_NC} $*" >&2; }
_fo_info() { echo -e "${_FO_CYN}→${_FO_NC} $*"; }

# ══════════════════════════════════════════════════════════════════════
# 1. OPERATION TYPE — detect what kind of op a file needs
# ══════════════════════════════════════════════════════════════════════
fops_detect_op() {
    local path="${1:-}"
    [[ -z "$path" ]] && { _fo_err "fops_detect_op: path required"; return 1; }
    [[ ! -e "$path" ]] && { echo "missing"; return; }
    local mime; mime=$(file --mime-type -b "$path" 2>/dev/null || echo "unknown")
    local size; size=$(stat -c%s "$path" 2>/dev/null || echo 0)
    local ext="${path##*.}"
    local ops=""
    case "$mime" in
        text/csv|application/csv)        ops="parse:csv" ;;
        application/json|text/json)      ops="parse:json" ;;
        text/*)                          ops="parse:text" ;;
        application/octet-stream|image/*|audio/*|video/*) ops="binary" ;;
        *)                               ops="unknown:$mime" ;;
    esac
    # override by extension when mime is generic
    case "$ext" in
        csv)  ops="parse:csv"  ;;
        json) ops="parse:json" ;;
        jsonl|ndjson) ops="parse:jsonl" ;;
        db|sqlite|sqlite3) ops="binary:sqlite" ;;
        gz|bz2|xz|zip) ops="binary:archive" ;;
        sh|bash|zsh)    ops="text:script"  ;;
        md|txt)         ops="text:plain"   ;;
        py|js|ts|go|rs) ops="text:code"    ;;
    esac
    local size_class="small"
    (( size > 10485760  )) && size_class="large"    # >10MB
    (( size > 104857600 )) && size_class="huge"     # >100MB
    echo "op=${ops} size=${size}B class=${size_class} mime=${mime}"
}

# ══════════════════════════════════════════════════════════════════════
# 2. READING — size-aware, encoding-aware, binary-safe
# ══════════════════════════════════════════════════════════════════════
fops_read() {
    local path="${1:-}" enc="${2:-utf-8}" head_n="${3:-0}"
    fops_check_missing "$path" || return 1
    fops_check_perms   "$path" "r" || return 1
    local size; size=$(stat -c%s "$path" 2>/dev/null || echo 0)
    # binary guard
    if file --mime-type -b "$path" 2>/dev/null | grep -qv "^text/"; then
        _fo_warn "Binary file detected — use fops_read_binary for: $path"
        return 2
    fi
    # large file: stream with pv if available, else plain cat
    if (( size > 10485760 )); then
        _fo_info "Large file ($(numfmt --to=iec $size)) — streaming"
        if command -v pv &>/dev/null; then
            pv "$path"
        elif [[ "$head_n" -gt 0 ]]; then
            head -n "$head_n" "$path"
        else
            cat "$path"
        fi
    else
        [[ "$head_n" -gt 0 ]] && head -n "$head_n" "$path" || cat "$path"
    fi
}

fops_read_binary() {
    local path="${1:-}" mode="${2:-hex}"
    fops_check_missing "$path" || return 1
    case "$mode" in
        hex)    xxd "$path" | head -40 ;;
        base64) base64 "$path" ;;
        stat)   stat "$path"; file "$path" ;;
        *)      _fo_err "mode: hex|base64|stat" ; return 1 ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# 3. WRITING — atomic (tmp→mv), backup-before-overwrite, perm-check
# ══════════════════════════════════════════════════════════════════════
fops_write() {
    local path="${1:-}" content="${2:-}" backup="${3:-0}"
    [[ -z "$path" ]]    && { _fo_err "fops_write: path required"; return 1; }
    [[ -z "$content" ]] && { _fo_err "fops_write: content required"; return 1; }
    local dir; dir=$(dirname "$path")
    fops_check_perms "$dir" "w" || return 1
    # backup existing
    if [[ -f "$path" && "$backup" == "1" ]]; then
        local bak="${path}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$path" "$bak" && _fo_info "Backup → $bak"
    fi
    # atomic write via tmp
    local tmp; tmp=$(mktemp "${dir}/.fops_write_XXXXXX") || {
        _fo_err "Cannot create tmp in $dir"; return 1; }
    printf '%s' "$content" > "$tmp" || {
        rm -f "$tmp"; _fo_err "Write to tmp failed"; return 1; }
    mv "$tmp" "$path" && _fo_ok "Written: $path ($(stat -c%s "$path")B)"
}

fops_write_file() {
    # pipe-friendly: fops_write_file <path> [--backup] < input
    local path="${1:-}" backup=0
    [[ "${2:-}" == "--backup" ]] && backup=1
    [[ -z "$path" ]] && { _fo_err "fops_write_file: path required"; return 1; }
    local dir; dir=$(dirname "$path")
    fops_check_perms "$dir" "w" || return 1
    [[ -f "$path" && $backup -eq 1 ]] && cp "$path" "${path}.bak.$(date +%Y%m%d_%H%M%S)"
    local tmp; tmp=$(mktemp "${dir}/.fops_write_XXXXXX")
    cat > "$tmp" && mv "$tmp" "$path" && _fo_ok "Written: $path"
}

# ══════════════════════════════════════════════════════════════════════
# 4. APPENDING — flock for concurrent safety, size-checked
# ══════════════════════════════════════════════════════════════════════
fops_append() {
    local path="${1:-}" content="${2:-}" max_mb="${3:-100}"
    fops_check_missing_or_create "$path" || return 1
    fops_check_perms "$path" "w" || return 1
    local size_mb; size_mb=$(( $(stat -c%s "$path" 2>/dev/null || echo 0) / 1048576 ))
    if (( size_mb >= max_mb )); then
        _fo_warn "File at ${size_mb}MB (limit ${max_mb}MB) — rotate before append"
        return 3
    fi
    # flock: concurrent-safe append
    (
        flock -w 5 200 || { _fo_err "fops_append: lock timeout on $path"; return 1; }
        printf '%s\n' "$content" >> "$path"
    ) 200>"${path}.lock"
    rm -f "${path}.lock"
    _fo_ok "Appended to $path"
}

fops_rotate() {
    # rotate large file: mv to .1, create fresh
    local path="${1:-}" keep="${2:-5}"
    [[ -f "$path" ]] || return 0
    for i in $(seq $((keep-1)) -1 1); do
        [[ -f "${path}.${i}" ]] && mv "${path}.${i}" "${path}.$((i+1))"
    done
    mv "$path" "${path}.1"
    touch "$path"
    _fo_ok "Rotated $path → ${path}.1 (kept $keep)"
}

# ══════════════════════════════════════════════════════════════════════
# 5. PARSING — CSV, JSON, JSONL, text, binary detection
# ══════════════════════════════════════════════════════════════════════
fops_parse_csv() {
    local path="${1:-}" col="${2:-}" delim="${3:-,}"
    fops_check_missing "$path" || return 1
    if [[ -n "$col" ]]; then
        # extract specific column (1-indexed)
        awk -F"$delim" -v c="$col" 'NR==1{print "["$c"]"} NR>1{print $c}' "$path"
    else
        # summary: row count, col count, header
        local rows; rows=$(wc -l < "$path")
        local header; header=$(head -1 "$path")
        local cols; cols=$(head -1 "$path" | awk -F"$delim" '{print NF}')
        _fo_info "CSV: $rows rows | $cols cols | delimiter='$delim'"
        echo "Header: $header"
    fi
}

fops_parse_json() {
    local path="${1:-}" query="${2:-.}"
    fops_check_missing "$path" || return 1
    # validate JSON first
    if ! python3 -c "import json,sys; json.load(sys.stdin)" < "$path" 2>/dev/null; then
        _fo_err "Invalid JSON: $path"
        fops_check_corrupt "$path"
        return 2
    fi
    if command -v jq &>/dev/null; then
        jq "$query" "$path"
    else
        python3 -c "
import json, sys
data = json.load(open('$path'))
print(json.dumps(data, indent=2))
"
    fi
}

fops_parse_jsonl() {
    local path="${1:-}" head_n="${2:-10}"
    fops_check_missing "$path" || return 1
    local total; total=$(wc -l < "$path")
    _fo_info "JSONL: $total records — showing first $head_n"
    local i=0
    while IFS= read -r line && (( i < head_n )); do
        if python3 -c "import json,sys; json.loads(sys.stdin.read())" <<< "$line" 2>/dev/null; then
            echo "$line" | python3 -m json.tool 2>/dev/null || echo "$line"
        else
            _fo_warn "Line $((i+1)): invalid JSON — $line"
        fi
        (( i++ ))
    done < "$path"
}

fops_parse_text() {
    local path="${1:-}" mode="${2:-stats}"
    fops_check_missing "$path" || return 1
    case "$mode" in
        stats)
            local lines words chars; read -r lines words chars < <(wc -lwc < "$path")
            local enc; enc=$(file --mime-encoding -b "$path" 2>/dev/null || echo unknown)
            _fo_info "Text: $lines lines | $words words | $chars chars | encoding:$enc"
            ;;
        head)  head -20 "$path" ;;
        tail)  tail -20 "$path" ;;
        grep)  grep -n "${3:-}" "$path" ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# 6. FILE SYSTEM OPS — copy, move, delete (safe defaults)
# ══════════════════════════════════════════════════════════════════════
fops_copy() {
    local src="${1:-}" dst="${2:-}" verify="${3:-1}"
    fops_check_missing "$src" || return 1
    fops_check_perms   "$(dirname "$dst")" "w" || return 1
    if [[ -d "$src" ]]; then
        rsync -ah --progress "$src/" "$dst/" || { _fo_err "Copy failed"; return 1; }
    else
        rsync -ah --progress "$src" "$dst" || { _fo_err "Copy failed"; return 1; }
    fi
    if [[ "$verify" == "1" ]]; then
        local h1 h2
        h1=$(sha256sum "$src" 2>/dev/null | cut -d' ' -f1)
        h2=$(sha256sum "$dst" 2>/dev/null | cut -d' ' -f1)
        [[ "$h1" == "$h2" ]] && _fo_ok "Verified copy: $src → $dst" \
                              || { _fo_err "Checksum mismatch after copy!"; return 1; }
    fi
}

fops_move() {
    local src="${1:-}" dst="${2:-}"
    fops_check_missing "$src" || return 1
    fops_check_perms "$(dirname "$dst")" "w" || return 1
    # cross-device: copy+verify+delete
    if [[ "$(stat -c%d "$src")" != "$(stat -c%d "$(dirname "$dst")")" ]]; then
        _fo_info "Cross-device move — copy+verify+delete"
        fops_copy "$src" "$dst" 1 || return 1
        rm -rf "$src" && _fo_ok "Moved (cross-device): $src → $dst"
    else
        mv -v "$src" "$dst" && _fo_ok "Moved: $src → $dst"
    fi
}

fops_delete() {
    local path="${1:-}" mode="${2:-trash}"
    fops_check_missing "$path" || return 1
    case "$mode" in
        trash)
            local trash="$HOME/.local/share/Trash/files"
            mkdir -p "$trash"
            mv "$path" "$trash/" && _fo_ok "Trashed: $path → $trash/"
            ;;
        shred)
            command -v shred &>/dev/null || { _fo_err "shred not available"; return 1; }
            shred -u "$path" && _fo_ok "Shredded: $path"
            ;;
        force)
            rm -rf "$path" && _fo_ok "Deleted: $path"
            ;;
        dry)
            _fo_info "[DRY RUN] Would delete: $path ($(stat -c%s "$path")B)"
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# 7. BATCH PROCESSING — parallel xargs or sequential, progress tracked
# ══════════════════════════════════════════════════════════════════════
fops_batch() {
    local op="${1:-}"; shift
    local pattern="${1:-}"; shift
    local parallel="${1:-1}"; shift
    local extra=("$@")
    [[ -z "$op" || -z "$pattern" ]] && {
        _fo_err "Usage: fops_batch <op> <pattern> [parallel=N] [args...]"
        return 1
    }
    local files=()
    while IFS= read -r f; do files+=("$f"); done < <(eval "find . $pattern" 2>/dev/null)
    local total=${#files[@]}
    [[ $total -eq 0 ]] && { _fo_warn "No files matched: $pattern"; return 0; }
    _fo_info "Batch $op on $total files (parallel=$parallel)"
    local done_n=0 failed_n=0
    _batch_run_one() {
        local f="$1"
        case "$op" in
            parse)   fops_detect_op "$f" ;;
            hash)    sha256sum "$f" ;;
            stat)    stat -c "%n %s %y" "$f" ;;
            chmod)   chmod "${extra[0]:-644}" "$f" ;;
            chown)   chown "${extra[0]:-$(id -un)}" "$f" ;;
            gzip)    gzip -k "$f" ;;
            copy)    fops_copy "$f" "${extra[0]:-/tmp/batch_out/}$(basename "$f")" 0 ;;
            delete)  fops_delete "$f" "${extra[0]:-dry}" ;;
            *)       _fo_err "Unknown batch op: $op"; return 1 ;;
        esac
    }
    export -f _batch_run_one fops_detect_op fops_copy fops_delete fops_check_missing fops_check_perms
    export -f _fo_ok _fo_err _fo_warn _fo_info
    if (( parallel > 1 )) && command -v xargs &>/dev/null; then
        printf '%s\n' "${files[@]}" | xargs -P "$parallel" -I{} bash -c '_batch_run_one "$@"' _ {}
    else
        for f in "${files[@]}"; do
            _batch_run_one "$f" && (( done_n++ )) || (( failed_n++ ))
            printf "\r  Progress: %d/%d (failed:%d)" $done_n $total $failed_n
        done
        echo ""
    fi
    _fo_ok "Batch done: $done_n ok | $failed_n failed of $total"
}

# ══════════════════════════════════════════════════════════════════════
# 8. ERROR HANDLING — corrupt, missing, permissions, partial recovery
# ══════════════════════════════════════════════════════════════════════
fops_check_missing() {
    local path="${1:-}"
    [[ -z "$path" ]]  && { _fo_err "No path provided"; return 1; }
    [[ -e "$path" ]]  && return 0
    _fo_err "Missing: $path"
    # suggest nearby matches
    local dir; dir=$(dirname "$path")
    local base; base=$(basename "$path")
    if [[ -d "$dir" ]]; then
        local matches; matches=$(find "$dir" -maxdepth 1 -name "*${base%.*}*" 2>/dev/null | head -3)
        [[ -n "$matches" ]] && { _fo_info "Did you mean:"; echo "$matches"; }
    fi
    return 1
}

fops_check_missing_or_create() {
    local path="${1:-}"
    [[ -e "$path" ]] && return 0
    local dir; dir=$(dirname "$path")
    mkdir -p "$dir" 2>/dev/null || { _fo_err "Cannot create dir: $dir"; return 1; }
    touch "$path" && _fo_info "Created: $path"
}

fops_check_perms() {
    local path="${1:-}" mode="${2:-r}"
    [[ -z "$path" ]] && return 1
    local target="$path"
    [[ ! -e "$path" ]] && target=$(dirname "$path")
    case "$mode" in
        r) [[ -r "$target" ]] || { _fo_err "No read permission: $target"; return 1; } ;;
        w) [[ -w "$target" ]] || { _fo_err "No write permission: $target"; return 1; } ;;
        x) [[ -x "$target" ]] || { _fo_err "No execute permission: $target"; return 1; } ;;
        rw)[[ -r "$target" && -w "$target" ]] || { _fo_err "No r/w permission: $target"; return 1; } ;;
    esac
}

fops_check_corrupt() {
    local path="${1:-}"
    fops_check_missing "$path" || return 1
    local size; size=$(stat -c%s "$path" 2>/dev/null || echo 0)
    local ext="${path##*.}"
    _fo_info "Integrity check: $path (${size}B)"
    # zero-byte check
    (( size == 0 )) && { _fo_err "CORRUPT: zero-byte file"; return 2; }
    # format-specific validation
    case "$ext" in
        json)
            python3 -c "import json,sys; json.load(sys.stdin)" < "$path" 2>/dev/null \
                && _fo_ok "JSON: valid" \
                || { _fo_err "JSON: invalid/corrupt"; return 2; }
            ;;
        csv)
            local rows; rows=$(wc -l < "$path")
            local expected_cols; expected_cols=$(head -1 "$path" | awk -F, '{print NF}')
            local bad; bad=$(awk -F, -v c="$expected_cols" 'NF!=c{print NR": "NF" cols (expected "c")"}' "$path" | head -5)
            [[ -z "$bad" ]] && _fo_ok "CSV: $rows rows, $expected_cols cols — consistent" \
                            || { _fo_warn "CSV inconsistent rows:"; echo "$bad"; return 3; }
            ;;
        db|sqlite|sqlite3)
            sqlite3 "$path" "PRAGMA integrity_check;" 2>/dev/null | grep -q "^ok$" \
                && _fo_ok "SQLite: integrity ok" \
                || { _fo_err "SQLite: corrupt or not a valid db"; return 2; }
            ;;
        gz|tgz)
            gzip -t "$path" 2>/dev/null && _fo_ok "gzip: valid" \
                                        || { _fo_err "gzip: corrupt"; return 2; }
            ;;
        *)
            # generic: check if readable and not all-null bytes
            if cat "$path" | tr -d '\0' | wc -c | grep -q "^0$"; then
                _fo_err "CORRUPT: all null bytes"
                return 2
            fi
            _fo_ok "Generic check: readable, non-null"
            ;;
    esac
}

fops_recover() {
    # Partial read/write recovery
    local path="${1:-}" strategy="${2:-backup}"
    _fo_warn "Recovery attempt: $path (strategy=$strategy)"
    case "$strategy" in
        backup)
            # find most recent .bak
            local bak; bak=$(ls -t "${path}".bak.* 2>/dev/null | head -1)
            if [[ -n "$bak" ]]; then
                _fo_info "Restoring from backup: $bak"
                cp "$bak" "$path" && _fo_ok "Restored: $path"
            else
                _fo_err "No backup found for: $path"
                return 1
            fi
            ;;
        git)
            # restore from last git commit
            local repo_root; repo_root=$(git -C "$(dirname "$path")" rev-parse --show-toplevel 2>/dev/null)
            if [[ -n "$repo_root" ]]; then
                local rel="${path#$repo_root/}"
                git -C "$repo_root" checkout HEAD -- "$rel" 2>/dev/null \
                    && _fo_ok "Restored from git HEAD: $rel" \
                    || { _fo_err "git restore failed for: $rel"; return 1; }
            else
                _fo_err "Not in a git repo — cannot use git strategy"
                return 1
            fi
            ;;
        truncate)
            # truncate to last known-good newline
            local last_nl; last_nl=$(grep -bo $'\n' "$path" 2>/dev/null | tail -1 | cut -d: -f1)
            if [[ -n "$last_nl" ]]; then
                truncate -s "$last_nl" "$path" && _fo_ok "Truncated to last newline at byte $last_nl"
            else
                _fo_err "No newline found in file — cannot truncate"
                return 1
            fi
            ;;
        *)
            _fo_err "strategy: backup|git|truncate"
            return 1
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════
# 9. FILE INFO — unified info card for any file
# ══════════════════════════════════════════════════════════════════════
fops_info() {
    local path="${1:-}"
    fops_check_missing "$path" || return 1
    local size mime enc lines
    size=$(stat -c%s "$path" 2>/dev/null || echo 0)
    mime=$(file --mime-type -b "$path" 2>/dev/null || echo unknown)
    enc=$(file --mime-encoding -b "$path" 2>/dev/null || echo unknown)
    echo -e "\n${_FO_BLD}${_FO_CYN}══ File Info: $(basename "$path") ══${_FO_NC}"
    printf "  %-18s %s\n" "Path:"     "$path"
    printf "  %-18s %s\n" "Size:"     "$(numfmt --to=iec $size 2>/dev/null || echo ${size}B)"
    printf "  %-18s %s\n" "MIME:"     "$mime"
    printf "  %-18s %s\n" "Encoding:" "$enc"
    printf "  %-18s %s\n" "Modified:" "$(stat -c%y "$path" 2>/dev/null | cut -d. -f1)"
    printf "  %-18s %s\n" "Perms:"    "$(stat -c%A "$path" 2>/dev/null)"
    printf "  %-18s %s\n" "Owner:"    "$(stat -c%U:%G "$path" 2>/dev/null)"
    if [[ "$mime" == text/* ]]; then
        lines=$(wc -l < "$path" 2>/dev/null || echo 0)
        printf "  %-18s %s\n" "Lines:" "$lines"
    fi
    printf "  %-18s %s\n" "SHA256:"   "$(sha256sum "$path" 2>/dev/null | cut -c1-16)..."
    printf "  %-18s %s\n" "Op-class:" "$(fops_detect_op "$path" 2>/dev/null)"
    echo ""
}

# ══════════════════════════════════════════════════════════════════════
# 10. PERFORMANCE HELPERS
# ══════════════════════════════════════════════════════════════════════
fops_stream() {
    # Real-time processing: tail -f equivalent with optional grep filter
    local path="${1:-}" filter="${2:-}"
    fops_check_missing "$path" || return 1
    _fo_info "Streaming: $path (Ctrl+C to stop)"
    if [[ -n "$filter" ]]; then
        tail -f "$path" | grep --line-buffered "$filter"
    else
        tail -f "$path"
    fi
}

fops_split() {
    # Split large files for processing: by lines or by size
    local path="${1:-}" by="${2:-lines}" val="${3:-1000}"
    fops_check_missing "$path" || return 1
    local out_prefix="${path%.}.part_"
    case "$by" in
        lines) split -l "$val" "$path" "$out_prefix" && _fo_ok "Split by $val lines → ${out_prefix}*" ;;
        size)  split -b "$val" "$path" "$out_prefix" && _fo_ok "Split by ${val}B → ${out_prefix}*" ;;
        *)     _fo_err "by: lines|size" ;;
    esac
}

fops_join() {
    local pattern="${1:-}" out="${2:-joined.out}"
    local files=(); while IFS= read -r f; do files+=("$f"); done < <(ls $pattern 2>/dev/null | sort)
    [[ ${#files[@]} -eq 0 ]] && { _fo_err "No files matched: $pattern"; return 1; }
    cat "${files[@]}" > "$out" && _fo_ok "Joined ${#files[@]} files → $out"
}

