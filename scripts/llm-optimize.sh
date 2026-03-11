#!/usr/bin/env bash
# llm-optimize.sh — dedicate machine to LLM inference
# Run: sudo bash llm-optimize.sh
set -euo pipefail

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GRN}[OPT]${NC} $*"; }
warn()  { echo -e "${YLW}[WARN]${NC} $*"; }
section(){ echo -e "\n${RED}══ $* ══${NC}"; }

# ── 1. BASELINE ──────────────────────────────────────────────────────────────
section "BASELINE"
free -h
echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
echo "THP: $(cat /sys/kernel/mm/transparent_hugepage/enabled)"
echo "Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"

# ── 2. CPU: PERFORMANCE MODE ─────────────────────────────────────────────────
section "CPU GOVERNOR → PERFORMANCE"
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance | tee "$gov" > /dev/null
done
info "All cores → performance"

# ── 3. KILL JUNK SERVICES ────────────────────────────────────────────────────
section "KILLING NON-ESSENTIAL SERVICES"
KILL_SERVICES=(
    bluetooth avahi-daemon cups cups-browsed colord fwupd
    ModemManager kerneloops touchegg switcheroo-control
    power-profiles-daemon thermald irqbalance
)
for svc in "${KILL_SERVICES[@]}"; do
    if systemctl is-active --quiet "${svc}.service" 2>/dev/null; then
        systemctl stop "${svc}.service" && info "Stopped: $svc"
    fi
done

# ── 4. KERNEL TUNING ─────────────────────────────────────────────────────────
section "KERNEL TUNING"
# Keep model weights in RAM, not swap
sysctl -w vm.swappiness=5          && info "swappiness → 5"
# THP: always = faster memory access for large model allocations
echo always > /sys/kernel/mm/transparent_hugepage/enabled
echo always > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
info "THP → always"
# More RAM for file cache (model loading speed)
sysctl -w vm.dirty_ratio=5         && info "dirty_ratio → 5"
sysctl -w vm.dirty_background_ratio=2
# CPU scheduler: favor compute over interactive
sysctl -w kernel.sched_autogroup_enabled=0 && info "sched_autogroup → off"

# ── 5. SWAP PRIORITY ─────────────────────────────────────────────────────────
section "SWAP CONFIGURATION"
# zram: fast compressed swap in RAM for OS, SSD swap for model overflow
if ! lsmod | grep -q zram; then
    modprobe zram 2>/dev/null && info "zram module loaded"
fi
# Check if zram0 already set up
if [ ! -b /dev/zram0 ] || [ "$(cat /sys/block/zram0/disksize 2>/dev/null)" = "0" ]; then
    echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
    echo 2G > /sys/block/zram0/disksize 2>/dev/null && \
    mkswap /dev/zram0 && \
    swapon /dev/zram0 --priority 200 && \
    info "zram0: 2GB compressed swap at priority 200"
else
    info "zram0 already active"
fi
# Boost SSD swap priority (currently -2, raise it)
swapoff /swapfile 2>/dev/null || true
swapon /swapfile --priority 100 && info "SSD swap priority → 100"
swapon --show

# ── 6. OLLAMA SERVICE TUNING ─────────────────────────────────────────────────
section "OLLAMA SYSTEMD OVERRIDE"
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/performance.conf << 'EOF'
[Service]
# Flash attention (faster on CPU)
Environment="OLLAMA_FLASH_ATTENTION=1"
# Only one model in RAM at a time
Environment="OLLAMA_MAX_LOADED_MODELS=1"
# One request, all resources
Environment="OLLAMA_NUM_PARALLEL=1"
# Never unload model (keep weights hot)
Environment="OLLAMA_KEEP_ALIVE=-1"
# Use physical cores only (HT slows inference)
Environment="OLLAMA_NUM_THREAD=2"
# Allow mlock (pin weights to RAM)
LimitMEMLOCK=infinity
# Real-time I/O priority
IOSchedulingClass=realtime
IOSchedulingPriority=0
# High CPU priority
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=50
# Physical cores 0,2 only (no HT contention)
AllowedCPUs=0-3
EOF
systemctl daemon-reload
systemctl restart ollama
info "Ollama restarted with performance config"

# ── 7. MLOCK: PIN MODEL WEIGHTS ──────────────────────────────────────────────
section "MLOCK — PIN WEIGHTS TO RAM"
OLLAMA_PID=$(pgrep -f "ollama serve" 2>/dev/null | head -1 || true)
if [ -n "$OLLAMA_PID" ]; then
    renice -n -20 -p "$OLLAMA_PID" 2>/dev/null && info "ollama niceness → -20"
    ionice -c 1 -n 0 -p "$OLLAMA_PID"          && info "ollama I/O → realtime"
    # Taskset to physical cores only
    taskset -p 0x5 "$OLLAMA_PID" 2>/dev/null   && info "ollama pinned to cores 0,2"
fi

# ── 8. FREE RAM REPORT ───────────────────────────────────────────────────────
section "POST-OPTIMIZATION MEMORY"
free -h
AVAIL=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
AVAIL_GB=$(echo "scale=1; $AVAIL/1048576" | bc)
echo ""
info "Available RAM: ${AVAIL_GB}GB"
if (( AVAIL > 5000000 )); then
    echo -e "${GRN}✓ 13B Q4 will fit in RAM (>5GB available)${NC}"
elif (( AVAIL > 3500000 )); then
    echo -e "${YLW}⚠ 13B Q3 will fit (3.5-5GB, rest in swap)${NC}"
else
    echo -e "${RED}✗ 8B max — close Firefox to free more RAM${NC}"
fi

section "DONE — next: close Firefox, then pull model"
echo "  ollama pull qwen2.5-coder:7b        (immediate quality upgrade, same RAM)"
echo "  ollama pull qwen2.5-coder:14b-instruct-q3_K_S   (13B if >5GB available)"
