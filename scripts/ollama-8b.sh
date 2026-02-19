#!/bin/bash
# ollama-8b.sh — Safe 8B launcher for 7.6GB RAM machine
# Unloads all models first, then runs sashi-llama-8b
# Usage: ollama-8b.sh "your prompt"

MODEL="sashi-llama-8b"
PROMPT="${*:-}"

echo "Unloading all models from RAM..."
# Set keepalive to 0 to immediately unload any loaded model
OLLAMA_KEEP_ALIVE=0 ollama run fast-sashi "" 2>/dev/null &
sleep 1
kill %1 2>/dev/null || true

# Wait for memory to free
sleep 3
AVAILABLE=$(free -m | awk '/^Mem/ {print $7}')
echo "Available RAM: ${AVAILABLE}MB (need ~5000MB for 8B)"

if [ "$AVAILABLE" -lt 4000 ]; then
    echo "WARNING: Low RAM (${AVAILABLE}MB). 8B may be slow."
fi

if [ -z "$PROMPT" ]; then
    echo "Starting interactive 8B session..."
    OLLAMA_NUM_THREAD=2 ollama run "$MODEL"
else
    echo "Querying 8B: $PROMPT"
    OLLAMA_NUM_THREAD=2 ollama run "$MODEL" "$PROMPT"
fi
