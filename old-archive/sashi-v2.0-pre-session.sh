#!/bin/bash
# SASHI - Smart AI Shell Interface (Optimized)
# Routes queries to DeepSeek (fast) or Llama (offline)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env" 2>/dev/null || true

VERSION="2.0.0"
DB_PATH="$SCRIPT_DIR/db/history.db"
OLLAMA_API="http://localhost:11434"

# Performance tuning
LLAMA_CTX=2048        # Context window (smaller = faster)
LLAMA_PREDICT=512     # Max response tokens
LLAMA_TEMP=0.5        # Lower = faster, more deterministic

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Cache ollama status (check once per session)
OLLAMA_RUNNING=""
check_ollama() {
    if [ -z "$OLLAMA_RUNNING" ]; then
        curl -s --connect-timeout 1 "$OLLAMA_API/api/tags" &>/dev/null && OLLAMA_RUNNING=1 || OLLAMA_RUNNING=0
    fi
    [ "$OLLAMA_RUNNING" = "1" ]
}

show_help() {
    cat << EOF
$(echo -e "${BLUE}SASHI${NC}") - Smart AI Shell Interface v$VERSION

Usage: sashi <command> [prompt]

Commands:
  ask <prompt>      Quick question (DeepSeek)
  code <prompt>     Code generation (DeepSeek)
  local <prompt>    Offline mode (Llama 3.2 - optimized)
  chat              Interactive chat (DeepSeek)
  chat --local      Interactive chat (Llama)
  history           Show query history
  status            System status
  models            List available models
  gmail <cmd>       Gmail access (search/recent/export)
  voice [opts]      Voice input (--gui, --continuous)
  help              Show this help

Pipe support:
  cat file.py | sashi code 'explain this'
  git diff | sashi code 'review this'
EOF
}

# Fast async logging (non-blocking)
log_query() {
    local model="$1" prompt="$2" resp_len="$3" duration="$4"
    {
        python3 << PYEOF
import sqlite3
conn = sqlite3.connect('$DB_PATH')
c = conn.cursor()
c.execute('INSERT INTO queries (model, prompt, response_length, duration_ms) VALUES (?, ?, ?, ?)',
          ('$model', '''${prompt//\'/\'\'}''', $resp_len, $duration))
conn.commit()
PYEOF
    } &>/dev/null &
}

deepseek_query() {
    local prompt="$1"
    local start_time=$(date +%s%3N)

    local response=$(curl -s https://api.deepseek.com/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
      -d "{
        \"model\": \"$DEFAULT_MODEL\",
        \"messages\": [{\"role\": \"user\", \"content\": $(echo "$prompt" | jq -Rs .)}],
        \"temperature\": 0.7,
        \"max_tokens\": 2000
      }" | jq -r '.choices[0].message.content // .error.message // "Error: No response"')

    local duration=$(( $(date +%s%3N) - start_time ))
    echo "$response"
    log_query "deepseek" "$prompt" "${#response}" "$duration"
}

# Optimized Llama query using HTTP API (not CLI)
llama_query() {
    local prompt="$1"
    local start_time=$(date +%s%3N)

    if ! check_ollama; then
        echo -e "${RED}Ollama not running. Start with: ollama-up${NC}"
        return 1
    fi

    # Use HTTP API with streaming for faster first-token
    local response=$(curl -s "$OLLAMA_API/api/generate" \
      -d "{
        \"model\": \"$LOCAL_MODEL\",
        \"prompt\": $(echo "$prompt" | jq -Rs .),
        \"stream\": false,
        \"options\": {
          \"num_ctx\": $LLAMA_CTX,
          \"num_predict\": $LLAMA_PREDICT,
          \"temperature\": $LLAMA_TEMP
        }
      }" | jq -r '.response // "Error: No response"')

    local duration=$(( $(date +%s%3N) - start_time ))
    echo "$response"
    log_query "llama3.2" "$prompt" "${#response}" "$duration"
}

# Streaming Llama query (shows output as it generates)
llama_query_stream() {
    local prompt="$1"

    if ! check_ollama; then
        echo -e "${RED}Ollama not running. Start with: ollama-up${NC}"
        return 1
    fi

    curl -s "$OLLAMA_API/api/generate" \
      -d "{
        \"model\": \"$LOCAL_MODEL\",
        \"prompt\": $(echo "$prompt" | jq -Rs .),
        \"stream\": true,
        \"options\": {
          \"num_ctx\": $LLAMA_CTX,
          \"num_predict\": $LLAMA_PREDICT,
          \"temperature\": $LLAMA_TEMP
        }
      }" | while IFS= read -r line; do
        echo "$line" | jq -r '.response // empty' 2>/dev/null | tr -d '\n'
    done
    echo ""
}

show_status() {
    echo -e "${BLUE}SASHI System Status${NC} v$VERSION"
    echo "===================="

    # Ollama (fast check)
    if check_ollama; then
        echo -e "Ollama:    ${GREEN}Running${NC}"
    else
        echo -e "Ollama:    ${RED}Stopped${NC}"
    fi

    # DeepSeek
    if [ -n "$DEEPSEEK_API_KEY" ]; then
        echo -e "DeepSeek:  ${GREEN}Configured${NC}"
    else
        echo -e "DeepSeek:  ${RED}No API key${NC}"
    fi

    # Performance settings
    echo ""
    echo "Performance:"
    echo "  Context:  $LLAMA_CTX tokens"
    echo "  Max out:  $LLAMA_PREDICT tokens"
    echo "  Temp:     $LLAMA_TEMP"

    # Models
    echo ""
    echo "Local Models:"
    curl -s "$OLLAMA_API/api/tags" 2>/dev/null | jq -r '.models[]? | "  \(.name) (\(.size / 1073741824 | floor)GB)"' || echo "  (none)"

    # Stats
    echo ""
    echo "Query Stats:"
    python3 << PYEOF 2>/dev/null || echo "  No history yet"
import sqlite3
conn = sqlite3.connect('$DB_PATH')
c = conn.cursor()
c.execute('SELECT COUNT(*) FROM queries')
total = c.fetchone()[0]
c.execute('SELECT model, COUNT(*), AVG(duration_ms) FROM queries GROUP BY model')
by_model = c.fetchall()
print(f'  Total: {total}')
for m, cnt, avg in by_model:
    print(f'  {m}: {cnt} queries, avg {int(avg or 0)}ms')
PYEOF
}

show_history() {
    python3 << 'PYEOF'
import sqlite3
import os
conn = sqlite3.connect(os.path.expanduser('~/ollama-local/db/history.db'))
c = conn.cursor()
c.execute('SELECT id, timestamp, model, substr(prompt, 1, 50), duration_ms FROM queries ORDER BY id DESC LIMIT 20')
rows = c.fetchall()
if rows:
    print(f"{'ID':<4} {'Time':<20} {'Model':<10} {'Prompt':<50} {'ms':<6}")
    print('-' * 94)
    for r in rows:
        prompt = (r[3] or '').replace('\n', ' ')[:47]
        if len(r[3] or '') > 47:
            prompt += '...'
        print(f"{r[0]:<4} {r[1]:<20} {r[2]:<10} {prompt:<50} {r[4] or 0:<6}")
else:
    print('No history yet')
PYEOF
}

interactive_chat() {
    local use_local="$1"

    if [ "$use_local" = "--local" ]; then
        echo -e "${YELLOW}SASHI Chat (Llama 3.2 - Optimized)${NC}"
        echo "Context: ${LLAMA_CTX} | Max: ${LLAMA_PREDICT} | Temp: ${LLAMA_TEMP}"
        echo "Type 'exit' to quit"
        echo ""

        while true; do
            echo -n -e "${YELLOW}> ${NC}"
            read -r prompt
            [ "$prompt" = "exit" ] || [ "$prompt" = "quit" ] && break
            [ -z "$prompt" ] && continue
            echo ""
            llama_query_stream "$prompt"
            echo ""
        done
    else
        echo -e "${BLUE}SASHI Chat (DeepSeek)${NC}"
        echo "Type 'exit' to quit"
        echo "=============================="

        while true; do
            echo -n -e "${GREEN}> ${NC}"
            read -r prompt
            [ "$prompt" = "exit" ] || [ "$prompt" = "quit" ] && break
            [ -z "$prompt" ] && continue
            echo ""
            deepseek_query "$prompt"
            echo ""
        done
    fi
}

# Read stdin if available (fast)
STDIN_DATA=""
[ ! -t 0 ] && STDIN_DATA=$(cat -)

# Main command routing
case "${1:-help}" in
    ask)
        shift
        prompt="${STDIN_DATA}${STDIN_DATA:+ }$*"
        [ -z "$prompt" ] && { echo "Usage: sashi ask <prompt>"; exit 1; }
        deepseek_query "$prompt"
        ;;
    code)
        shift
        prompt="You are a coding assistant. Be concise. ${STDIN_DATA}${STDIN_DATA:+ }$*"
        [ -z "$*" ] && [ -z "$STDIN_DATA" ] && { echo "Usage: sashi code <prompt>"; exit 1; }
        deepseek_query "$prompt"
        ;;
    local)
        shift
        prompt="${STDIN_DATA}${STDIN_DATA:+ }$*"
        [ -z "$prompt" ] && { echo "Usage: sashi local <prompt>"; exit 1; }
        llama_query "$prompt"
        ;;
    stream)
        shift
        prompt="${STDIN_DATA}${STDIN_DATA:+ }$*"
        [ -z "$prompt" ] && { echo "Usage: sashi stream <prompt>"; exit 1; }
        llama_query_stream "$prompt"
        ;;
    chat)
        interactive_chat "$2"
        ;;
    history)
        show_history
        ;;
    status)
        show_status
        ;;
    models)
        curl -s "$OLLAMA_API/api/tags" | jq -r '.models[] | "\(.name)\t\(.size / 1073741824 | floor)GB"' 2>/dev/null || echo "Ollama not running"
        ;;
    gmail)
        shift
        "$SCRIPT_DIR/mcp/gmail/tools/gmail-cli" "$@"
        ;;
    voice)
        shift
        case "${1:---help}" in
            --gui|-g)
                "$SCRIPT_DIR/mcp/voice/tools/voice-gui"
                ;;
            --continuous|-c)
                "$SCRIPT_DIR/mcp/voice/tools/voice-input" --continuous
                ;;
            --install)
                "$SCRIPT_DIR/mcp/voice/tools/install-voice"
                ;;
            --help|-h)
                echo "Voice commands:"
                echo "  sashi voice              Single voice prompt"
                echo "  sashi voice --continuous Continuous listening"
                echo "  sashi voice --gui        Desktop GUI"
                echo "  sashi voice --install    Install dependencies"
                ;;
            *)
                "$SCRIPT_DIR/mcp/voice/tools/voice-input" "$@"
                ;;
        esac
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        prompt="${STDIN_DATA}${STDIN_DATA:+ }$*"
        [ -z "$prompt" ] && { show_help; exit 1; }
        deepseek_query "$prompt"
        ;;
esac
