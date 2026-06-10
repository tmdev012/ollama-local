#!/usr/bin/env bash
set -euo pipefail

SASHI_ROOT="${SASHI_ROOT:-$HOME/ollama-local}"
OPENAI_VAULT="${OPENAI_VAULT:-$HOME/.config/sashi/secrets/openai.env}"
OPENAI_MODEL="${OPENAI_MODEL:-gpt-5.4-mini}"
OPENAI_LOG_DIR="$SASHI_ROOT/logs/openai"

mkdir -p "$OPENAI_LOG_DIR"

_sashi_openai_load_env() {
  if [ -f "$OPENAI_VAULT" ]; then
    # shellcheck disable=SC1090
    source "$OPENAI_VAULT"
  fi

  if [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "OPENAI_API_KEY missing. Put it in:"
    echo "$OPENAI_VAULT"
    return 1
  fi
}

_sashi_openai_call() {
  _sashi_openai_load_env || return 1

  local prompt="$*"
  local model="${OPENAI_MODEL:-gpt-5.4-mini}"
  local ts raw out

  [ -n "$prompt" ] || {
    echo "Usage: sashi openai <prompt>"
    return 1
  }

  ts="$(date +%Y%m%d_%H%M%S)"
  raw="$OPENAI_LOG_DIR/response-$ts.raw.json"
  out="$OPENAI_LOG_DIR/response-$ts.txt"

  jq -n \
    --arg model "$model" \
    --arg input "$prompt" \
    '{
      model: $model,
      input: $input,
      reasoning: { effort: "medium" }
    }' \
  | curl -sS https://api.openai.com/v1/responses \
      -H "Authorization: Bearer ${OPENAI_API_KEY}" \
      -H "Content-Type: application/json" \
      -d @- > "$raw"

  if jq -e '.error' "$raw" >/dev/null 2>&1; then
    echo "[OPENAI ERROR]"
    jq '.error' "$raw"
    return 1
  fi

  jq -r '
    .output_text //
    ([.output[]?.content[]?.text] | join("\n")) //
    .
  ' "$raw" | tee "$out"
}

sashi_openai() {
  local cmd="${1:-help}"
  shift || true

  case "$cmd" in
    ask|chat)
      _sashi_openai_call "$@"
      ;;

    code)
      _sashi_openai_call "You are SASHI IDE coding assistant. Return practical implementation steps and code only where useful. Task: $*"
      ;;

    review)
      local diff
      diff="$(git diff 2>/dev/null || true)"
      if [ -z "$diff" ]; then
        echo "No git diff found."
        return 0
      fi
      _sashi_openai_call "Review this git diff for bugs, missing tests, and risky changes. Return concise fixes. Diff: $diff"
      ;;

    commitmsg)
      local diff
      diff="$(git diff --cached 2>/dev/null || git diff 2>/dev/null || true)"
      if [ -z "$diff" ]; then
        echo "No diff found."
        return 0
      fi
      _sashi_openai_call "Write a conventional commit message for this diff. Diff: $diff"
      ;;

    gate)
      _sashi_openai_call "Act as SASHI release gate. Check this task against: version gate, safety, tests, evidence, rollback. Task: $*"
      ;;

    model)
      echo "Current OPENAI_MODEL=${OPENAI_MODEL:-gpt-5.4-mini}"
      echo "Set temporarily:"
      echo "  export OPENAI_MODEL=gpt-5.5"
      echo "  export OPENAI_MODEL=gpt-5.4-mini"
      ;;

    test)
      _sashi_openai_load_env || return 1
      curl -fsS https://api.openai.com/v1/models \
        -H "Authorization: Bearer ${OPENAI_API_KEY}" \
        | jq -r '.data[0].id'
      ;;

    help|*)
      cat <<HELP
SASHI OpenAI route

Usage:
  sashi openai ask "question"
  sashi openai code "build feature"
  sashi openai review
  sashi openai commitmsg
  sashi openai gate "task"
  sashi openai model
  sashi openai test

Aliases after patch:
  sashi ai "question"
  sashi ocode "task"
  sashi oreview
  sashi ogate "task"

Default model:
  OPENAI_MODEL=gpt-5.4-mini

For deeper reasoning:
  export OPENAI_MODEL=gpt-5.5
HELP
      ;;
  esac
}
