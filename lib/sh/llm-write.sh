#!/bin/bash
# llm-write.sh — Sashi LLM File Write System v3.2.2
# Integrates llama inference with file-ops: read→prompt→write
# All writes are atomic. All reads are format-aware. Errors are handled.

source "$(dirname "${BASH_SOURCE[0]}")/file-ops.sh" 2>/dev/null || true

_LW_RED='\033[0;31m'; _LW_GRN='\033[0;32m'; _LW_YLW='\033[0;33m'
_LW_CYN='\033[0;36m'; _LW_BLD='\033[1m'; _LW_DIM='\033[2m'; _LW_NC='\033[0m'

_lw_ok()   { echo -e "${_LW_GRN}✔${_LW_NC} $*"; }
_lw_err()  { echo -e "${_LW_RED}✘${_LW_NC} $*" >&2; }
_lw_info() { echo -e "${_LW_CYN}→${_LW_NC} $*"; }
_lw_step() { echo -e "${_LW_BLD}[${1}]${_LW_NC} ${2}"; }

# ── Core inference — streams llama, captures output ───────────────────
_lw_infer() {
    local model="${LLM_MODEL:-${MODEL:-llama3.2}}"
    local prompt="$1"
    if [[ -z "$prompt" ]]; then _lw_err "Empty prompt"; return 1; fi
    ollama run "$model" "$prompt" 2>/dev/null
}

# ── 1. SIMPLE WRITE — prompt → file (replaces old sashi write) ────────
llmw_write() {
    local outfile="$1"; shift
    local prompt="$*"
    [[ -z "$outfile" || -z "$prompt" ]] && {
        echo "Usage: llmw_write <outfile> <prompt>"; return 1; }

    _lw_step "1/3" "Inferring: $prompt"
    local output; output=$(_lw_infer "$prompt") || { _lw_err "Inference failed"; return 1; }
    [[ -z "$output" ]] && { _lw_err "Empty response from model"; return 1; }

    _lw_step "2/3" "Writing → $outfile"
    fops_write "$outfile" "$output" 1 || return 1   # atomic + backup

    _lw_step "3/3" "Verify"
    fops_check_corrupt "$outfile"
    _lw_ok "Done: $outfile ($(wc -l < "$outfile") lines, $(wc -c < "$outfile")B)"
}

# ── 2. READ→PROCESS→WRITE — file-in + prompt + file-out ──────────────
llmw_process() {
    local infile="$1" outfile="$2"; shift 2
    local prompt="$*"
    [[ -z "$infile" || -z "$outfile" || -z "$prompt" ]] && {
        echo "Usage: llmw_process <infile> <outfile> <prompt>"; return 1; }

    _lw_step "1/4" "Reading: $infile"
    fops_check_missing "$infile" || return 1
    fops_check_corrupt "$infile"  || { _lw_err "Input corrupt — aborting"; return 1; }
    local op_info; op_info=$(fops_detect_op "$infile")
    _lw_info "Detected: $op_info"

    local content; content=$(fops_read "$infile") || return 1
    local size=${#content}
    # truncate large files to avoid context overflow (keep ~6000 chars)
    if (( size > 6000 )); then
        _lw_info "Input ${size}B — truncating to 6000 chars for context window"
        content="${content:0:6000}"$'\n...[truncated]'
    fi

    _lw_step "2/4" "Building prompt"
    local full_prompt="File: $infile
Content:
${content}

Task: ${prompt}

Respond with the result only. No explanations unless asked."

    _lw_step "3/4" "Inferring"
    local output; output=$(_lw_infer "$full_prompt") || { _lw_err "Inference failed"; return 1; }
    [[ -z "$output" ]] && { _lw_err "Empty response"; return 1; }

    _lw_step "4/4" "Writing → $outfile"
    fops_write "$outfile" "$output" 1
    fops_check_corrupt "$outfile"
    _lw_ok "Done: $outfile"
}

# ── 3. APPEND — AI output appended to existing file ──────────────────
llmw_append() {
    local outfile="$1"; shift
    local prompt="$*"
    [[ -z "$outfile" || -z "$prompt" ]] && {
        echo "Usage: llmw_append <outfile> <prompt>"; return 1; }

    _lw_step "1/2" "Inferring"
    local output; output=$(_lw_infer "$prompt") || { _lw_err "Inference failed"; return 1; }
    [[ -z "$output" ]] && { _lw_err "Empty response"; return 1; }

    _lw_step "2/2" "Appending → $outfile"
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    fops_append "$outfile" "
--- $ts ---
${output}"
    _lw_ok "Appended to: $outfile"
}

# ── 4. BATCH — process multiple files with same prompt ────────────────
llmw_batch() {
    local pattern="$1" out_dir="$2"; shift 2
    local prompt="$*"
    [[ -z "$pattern" || -z "$out_dir" || -z "$prompt" ]] && {
        echo "Usage: llmw_batch <glob-pattern> <out-dir> <prompt>"
        echo "Example: llmw_batch '*.log' ./summaries 'summarise this log'"
        return 1; }

    mkdir -p "$out_dir"
    local files=(); while IFS= read -r f; do files+=("$f"); done < <(ls $pattern 2>/dev/null)
    [[ ${#files[@]} -eq 0 ]] && { _lw_err "No files matched: $pattern"; return 1; }

    local total=${#files[@]} done_n=0 failed_n=0
    _lw_info "Batch: $total files → $out_dir"

    for f in "${files[@]}"; do
        local base; base=$(basename "$f")
        local outfile="${out_dir}/${base%.}__ai.txt"
        printf "\r  [%d/%d] %s" $((done_n+failed_n+1)) "$total" "$base"
        if llmw_process "$f" "$outfile" "$prompt" &>/dev/null; then
            (( done_n++ ))
        else
            _lw_err "Failed: $f"
            (( failed_n++ ))
        fi
    done
    echo ""
    _lw_ok "Batch done: $done_n ok | $failed_n failed of $total"
}

# ── 5. FORMAT-AWARE WRITE — JSON/CSV/MD validated output ─────────────
llmw_write_fmt() {
    local fmt="$1" outfile="$2"; shift 2
    local prompt="$*"
    [[ -z "$fmt" || -z "$outfile" || -z "$prompt" ]] && {
        echo "Usage: llmw_write_fmt <json|csv|md|sh> <outfile> <prompt>"
        return 1; }

    local fmt_instruction=""
    case "$fmt" in
        json) fmt_instruction="Output ONLY valid JSON. No markdown fences. No explanation." ;;
        csv)  fmt_instruction="Output ONLY CSV with header row. No explanation." ;;
        md)   fmt_instruction="Output ONLY markdown. Use headers, bullets, code blocks as needed." ;;
        sh)   fmt_instruction="Output ONLY a bash script. No explanation. Start with #!/bin/bash." ;;
        *)    _lw_err "Format: json|csv|md|sh"; return 1 ;;
    esac

    local full_prompt="${prompt}

${fmt_instruction}"

    _lw_step "1/3" "Inferring ($fmt)"
    local output; output=$(_lw_infer "$full_prompt") || { _lw_err "Inference failed"; return 1; }

    # strip markdown fences if model added them anyway
    output=$(echo "$output" | sed '/^```/d')

    _lw_step "2/3" "Validating $fmt"
    case "$fmt" in
        json)
            echo "$output" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null \
                && _lw_ok "JSON valid" \
                || _lw_err "Warning: output may not be valid JSON"
            ;;
        sh)
            echo "$output" | bash -n 2>/dev/null \
                && _lw_ok "Bash syntax ok" \
                || _lw_err "Warning: bash syntax errors detected"
            ;;
    esac

    _lw_step "3/3" "Writing → $outfile"
    fops_write "$outfile" "$output" 1
    _lw_ok "Done: $outfile ($fmt)"
}

# ── 6. PIPE WRITE — stdin content + prompt → file ────────────────────
llmw_pipe() {
    # cat file.py | llmw_pipe out.md "document this code"
    local outfile="$1"; shift
    local prompt="$*"
    [[ -z "$outfile" || -z "$prompt" ]] && {
        echo "Usage: cat <file> | llmw_pipe <outfile> <prompt>"; return 1; }
    [[ -t 0 ]] && { _lw_err "No stdin — pipe content into llmw_pipe"; return 1; }
    local content; content=$(cat -)
    local sz=${#content}
    (( sz > 6000 )) && { content="${content:0:6000}"$'\n...[truncated]'; _lw_info "Truncated stdin to 6000 chars"; }
    local full_prompt="Content:
${content}

Task: ${prompt}"
    _lw_info "Inferring from pipe → $outfile"
    local output; output=$(_lw_infer "$full_prompt") || { _lw_err "Inference failed"; return 1; }
    fops_write "$outfile" "$output" 1
    _lw_ok "Done: $outfile"
}

# ── 7. ERROR RECOVERY WRITE — retry with fallback model ──────────────
llmw_safe_write() {
    local outfile="$1"; shift
    local prompt="$*"
    local primary="${LLM_MODEL:-llama3.2}"
    local fallback="fast-sashi"

    _lw_info "Safe write → $outfile (primary: $primary)"
    local output
    output=$(MODEL="$primary" _lw_infer "$prompt" 2>/dev/null)
    if [[ -z "$output" ]]; then
        _lw_info "Primary failed — retrying with $fallback"
        output=$(MODEL="$fallback" _lw_infer "$prompt" 2>/dev/null)
    fi
    [[ -z "$output" ]] && { _lw_err "Both models failed — cannot write"; return 1; }
    fops_write "$outfile" "$output" 1
    _lw_ok "Safe write done: $outfile"
}
