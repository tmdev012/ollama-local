#!/usr/bin/env bash
# run.sh — Stage 2 Q1: Docker internal DNS proof
# Usage: bash run.sh
set -e
cd "$(dirname "$0")"
docker-compose up --abort-on-container-exit
echo ""
echo "── WHAT YOU LEARNED ──"
echo "Docker bridge networks have a built-in DNS resolver."
echo "'server' resolved by name because both containers share the same network."
echo "This is exactly how 'ollama' resolves inside setup-box."
docker-compose down
