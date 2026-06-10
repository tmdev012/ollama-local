#!/usr/bin/env bash
# revert-memtune.sh — undo all memtune changes in one shot
set -uo pipefail

echo "[revert] restoring kernel defaults..."
sudo sysctl -w vm.swappiness=80
sudo sysctl -w vm.overcommit_memory=0
sudo sysctl -w vm.overcommit_ratio=50
sudo sysctl -w vm.vfs_cache_pressure=50
sudo sysctl -w vm.dirty_ratio=20
sudo sysctl -w vm.dirty_background_ratio=10
sudo sysctl -w vm.max_map_count=65530

echo "[revert] restoring .env ollama vars..."
ENV="$HOME/ollama-local/.env"
sed -i '/^OLLAMA_NUM_CTX=/d'          "$ENV"
sed -i '/^OLLAMA_KEEP_ALIVE=/d'        "$ENV"
sed -i '/^OLLAMA_MAX_LOADED_MODELS=/d' "$ENV"
sed -i '/^MALLOC_ARENA_MAX=/d'         "$ENV"

echo "[revert] reverting git to pre-memtune snapshot..."
cd ~/ollama-local
git revert --no-commit HEAD
git checkout HEAD~ -- lib/sh/aliases.sh sashi
git reset HEAD scripts/memtune.sh scripts/revert-memtune.sh 2>/dev/null || true
echo "[revert] done — review with: git diff"
echo "         to finalise: git checkout -- ."
echo "         or tag is:   git checkout snapshot-pre-memtune-$(date +%Y%m%d)"
