#!/usr/bin/env bash
# model-cleanup.sh — remove stale duplicate models, keep canonical ones
# Keeps: fast-sashi (3B canonical), sashi-llama-8b (8B canonical)
# Removes: all duplicates

KEEP=("fast-sashi:latest" "sashi-llama-8b:latest")
REMOVE=("sashi-llama-fast:latest" "turbo-llama:latest" "fast-llama:latest" 
        "sashi-llama:latest" "llama3.1:8b" "llama3.2:1b" "llama3.2:latest")

echo "=== Current disk usage ==="
du -sh ~/.ollama/models/ 2>/dev/null || true

echo ""
echo "=== Removing stale models ==="
for model in "${REMOVE[@]}"; do
    if ollama list | grep -q "${model%%:*}"; then
        ollama rm "$model" 2>/dev/null && echo "Removed: $model" || echo "Skip: $model"
    fi
done

echo ""
echo "=== Remaining models ==="
ollama list

echo ""
echo "=== Disk freed ==="
du -sh ~/.ollama/models/ 2>/dev/null || true
