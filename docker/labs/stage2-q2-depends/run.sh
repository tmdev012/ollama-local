#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

echo "════ PART 1: WITHOUT depends_on (race condition) ════"
docker-compose -f compose-broken.yml up --abort-on-container-exit 2>&1 | grep -E "client|server|FAILED|GOT|ready"
docker-compose -f compose-broken.yml down -v 2>/dev/null

sleep 2

echo ""
echo "════ PART 2: WITH depends_on + healthcheck (fixed) ════"
docker-compose -f compose-fixed.yml up --abort-on-container-exit 2>&1 | grep -E "client|server|FAILED|GOT|ready"
docker-compose -f compose-fixed.yml down -v 2>/dev/null

echo ""
echo "── LEARNED: depends_on alone = race. healthcheck = guaranteed order ──"
