#!/usr/bin/env bash
set -euo pipefail

SASHI_ROOT="${SASHI_ROOT:-$HOME/ollama-local}"
GEMINI_VAULT="${GEMINI_VAULT:-$HOME/.config/sashi/secrets/gemini.env}"
GEMINI_MODEL="${GEMINI_MODEL:-gemini-2.5-flash-lite}"
GEMINI_LOG_DIR="$SASHI_ROOT/logs/gemini"
mkdir -p "$GEMINI_LOG_DIR"

_sashi_gemini_load_env() {
  [ -f "$GEMINI_VAULT" ] && source "$GEMINI_VAULT"
  [ -n "${GEMINI_API_KEY:-}" ] || {
    echo "GEMINI_API_KEY missing in $GEMINI_VAULT"
    return 1
  }
}

_sashi_gemini_call() {
  _sashi_gemini_load_env || return 1

  local prompt="$*"
  local model="${GEMINI_MODEL:-gemini-2.5-flash-lite}"
  local ts raw out

  [ -n "$prompt" ] || {
    echo "Usage: sashi gemini ask <prompt>"
    return 1
  }

  ts="$(date +%Y%m%d_%H%M%S)"
  raw="$GEMINI_LOG_DIR/response-$ts.raw.json"
  out="$GEMINI_LOG_DIR/response-$ts.txt"

  jq -n --arg p "$prompt" \
    '{contents:[{parts:[{text:$p}]}]}' \
  | curl -s "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent" \
      -H "x-goog-api-key: ${GEMINI_API_KEY}" \
      -H "Content-Type: application/json" \
      -d @- > "$raw"

  if jq -e '.error' "$raw" >/dev/null 2>&1; then
    echo "[GEMINI ERROR]"
    jq -r '.error.message' "$raw"
    return 1
  fi

  jq -r '.candidates[0].content.parts[0].text // .' "$raw" | tee "$out"
}

sashi_gemini() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    ask|chat)
      _sashi_gemini_call "$@"
      ;;
    code)
      _sashi_gemini_call "You are SASHI IDE coding assistant. Return concise implementation steps and safe shell/code patches. Task: $*"
      ;;
    gate)
      _sashi_gemini_call "Act as SASHI release gate. Check this task against version gate, safety, tests, evidence, rollback. Task: $*"
      ;;
    model)
      echo "Current GEMINI_MODEL=${GEMINI_MODEL:-gemini-2.5-flash-lite}"
      echo "Set temporarily:"
      echo "  export GEMINI_MODEL=gemini-2.5-flash-lite"
      echo "  export GEMINI_MODEL=gemini-2.5-flash"
      echo "  export GEMINI_MODEL=gemini-2.5-pro"
      ;;
    test)
      _sashi_gemini_call "Reply OK only"
      ;;
    help|*)
      cat <<HELP
SASHI Gemini route

Usage:
  sashi gemini ask "question"
  sashi gemini code "task"
  sashi gemini gate "task"
  sashi gemini model
  sashi gemini test

Short aliases:
  sashi gai "question"
  sashi gcode "task"
  sashi ggate "task"
HELP
      ;;
  esac
}
