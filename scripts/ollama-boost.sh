#!/bin/bash
# ollama-boost.sh - Prioritize ollama for swap/CPU/IO
# Run with: sudo bash ~/ollama-local/scripts/ollama-boost.sh

set -e

# Find ollama PIDs
SERVE_PID=$(pgrep -f "ollama serve" | head -1)
RUNNER_PID=$(pgrep -f "ollama runner" | head -1)

if [ -z "$SERVE_PID" ]; then
    echo "ollama not running"; exit 1
fi

echo "ollama serve: PID $SERVE_PID"
echo "ollama runner: PID ${RUNNER_PID:-none}"

# 1. Swappiness 60→10 (keep model in RAM, swap other stuff)
sysctl -w vm.swappiness=10
echo "  swappiness: 10"

# 2. OOM protection (-999 = almost never kill)
echo -999 > /proc/$SERVE_PID/oom_score_adj
echo "  oom_score_adj serve: -999"
if [ -n "$RUNNER_PID" ]; then
    echo -999 > /proc/$RUNNER_PID/oom_score_adj
    echo "  oom_score_adj runner: -999"
fi

# 3. CPU priority (nice -10 = high)
renice -n -10 -p $SERVE_PID > /dev/null
echo "  nice serve: -10"
if [ -n "$RUNNER_PID" ]; then
    renice -n -10 -p $RUNNER_PID > /dev/null
    echo "  nice runner: -10"
fi

# 4. I/O priority (best-effort, priority 0 = highest in class)
ionice -c 2 -n 0 -p $SERVE_PID
echo "  ionice serve: best-effort/0"
if [ -n "$RUNNER_PID" ]; then
    ionice -c 2 -n 0 -p $RUNNER_PID
    echo "  ionice runner: best-effort/0"
fi

echo ""
echo "Done. ollama is now prioritized for RAM, CPU, and I/O."
echo "To make swappiness permanent: echo 'vm.swappiness=10' >> /etc/sysctl.conf"
