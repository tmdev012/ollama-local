#!/usr/bin/env bash
# run.sh — Stage 2 Q3: expose vs ports proof
# Usage: bash run.sh
set -e
cd "$(dirname "$0")"

docker-compose up -d
sleep 4

echo "════════════════════════════════════"
echo " FROM INSIDE Docker (tester container)"
echo "════════════════════════════════════"
docker logs q3-tester 2>/dev/null || docker-compose logs tester

echo ""
echo "════════════════════════════════════"
echo " FROM HOST (your terminal)"
echo "════════════════════════════════════"
echo -n "svc-expose port 8001 from host: "
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 http://localhost:8001 2>/dev/null \
  && echo " ← accessible" || echo "CONNECTION REFUSED ← expose blocks host access"

echo -n "svc-ports  port 8002 from host: "
curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 http://localhost:8002 2>/dev/null \
  && echo " ← accessible (ports punches through to host)" || echo "failed"

echo ""
echo "── WHAT YOU LEARNED ──"
echo "expose: containers talk to it freely. Your terminal cannot."
echo "ports:  everyone can reach it — containers AND your terminal."
echo "Rule: internal services (Kafka, gRPC) use expose. Public APIs use ports."
docker-compose down
