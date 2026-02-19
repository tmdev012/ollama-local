#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
echo "════ building gRPC server + client ════"
docker-compose build 2>&1 | grep -E "Step|Successfully|error" | head -20
echo ""
echo "════ running ════"
docker-compose up --abort-on-container-exit 2>&1 | grep -E "server:|client:|error"
docker-compose down 2>/dev/null
echo ""
echo "── LEARNED ──"
echo ".proto = shared contract. change it on one side without updating the other = broken"
echo "client found server via name 'grpc-server' — same Docker DNS as Stage 2"
echo "port 50051 never exposed to host — container-to-container only (expose, not ports)"
