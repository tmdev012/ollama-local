#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
mkdir -p host-dir

echo "════ PART 1: named volume survives container death ════"
docker-compose up --abort-on-container-exit 2>&1 | grep -E "writer:|reader:|wrote|hello"

echo ""
echo "════ PART 2: volume still exists after containers gone ════"
docker-compose down 2>/dev/null
docker volume inspect stage3-testdata | grep -E "Name|Mountpoint"

echo ""
echo "════ PART 3: read volume from a brand new container ════"
docker run --rm -v stage3-testdata:/data alpine cat /data/proof.txt

echo ""
echo "════ PART 4: bind mount wrote to HOST filesystem ════"
echo -n "host-dir/fromcontainer.txt contains: "
cat host-dir/fromcontainer.txt

echo ""
echo "════ PART 5: down -v DESTROYS named volume ════"
docker-compose down -v 2>&1 | grep -E "Removing volume|done"
docker volume inspect stage3-testdata 2>&1 | grep -E "Error|No such"

echo ""
echo "── LEARNED ──"
echo "named volume : data outlives containers. destroyed only with down -v"
echo "bind mount   : direct host folder. see changes on host immediately"
echo "Kafka needs named volume — queue must survive container restarts"
