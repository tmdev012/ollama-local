#!/bin/bash
# pipeline/client.sh — Bash wrapper for gRPC pipeline client
# Usage:
#   ./client.sh health
#   ./client.sh infer "explain quicksort"
#   ./client.sh stream "write a haiku"
#   ./client.sh write /tmp/out.txt "content here"
#   ./client.sh pipeline "summarize X" /tmp/result.txt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT="$SCRIPT_DIR/client.py"
export PIPELINE_ADDR="${PIPELINE_ADDR:-localhost:50051}"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <health|infer|stream|write|pipeline> [args...]"
    exit 1
fi

python3 "$CLIENT" "$@"
