#!/usr/bin/env bash
# memtune.sh — maximize RAM+swap for sashi/ollama and bitwig
# Usage: memtune.sh {apply|status|bitwig|ollama}
set -uo pipefail

MODE="${1:-status}"
ENV_FILE="$HOME/ollama-local/.env"

# 14 GB swap target: RAM(7.6G) + swap gives ~21G virtual pool
# vm.swappiness=100 makes kernel treat swap as eagerly as RAM
_kernel_apply() {
    sudo sysctl -w vm.swappiness=100        >/dev/null
    sudo sysctl -w vm.overcommit_memory=1   >/dev/null  # allow fake memory
    sudo sysctl -w vm.overcommit_ratio=100  >/dev/null
    sudo sysctl -w vm.vfs_cache_pressure=200 >/dev/null # free cache fast under pressure
    sudo sysctl -w vm.dirty_ratio=80        >/dev/null
    sudo sysctl -w vm.dirty_background_ratio=40 >/dev/null
    sudo sysctl -w vm.max_map_count=1048576 >/dev/null  # needed for large model mmap
    echo "[memtune] kernel: swappiness=100  overcommit=1  max_map_count=1048576"
}

_env_set() {
    local key="$1" val="$2"
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
    else
        echo "${key}=${val}" >> "$ENV_FILE"
    fi
    export "${key}=${val}"
}

_ollama_apply() {
    _env_set OLLAMA_NUM_CTX       2048
    _env_set OLLAMA_KEEP_ALIVE    -1
    _env_set OLLAMA_MAX_LOADED_MODELS 1
    _env_set MALLOC_ARENA_MAX     2
    echo "[memtune] ollama: NUM_CTX=2048  KEEP_ALIVE=-1  MAX_LOADED=1  MALLOC_ARENA=2"
}

_status() {
    echo "── kernel ──────────────────────────────────"
    echo "  swappiness:        $(cat /proc/sys/vm/swappiness)"
    echo "  overcommit_memory: $(cat /proc/sys/vm/overcommit_memory)"
    echo "  overcommit_ratio:  $(cat /proc/sys/vm/overcommit_ratio)"
    echo "  vfs_cache_pressure:$(cat /proc/sys/vm/vfs_cache_pressure)"
    echo "  max_map_count:     $(cat /proc/sys/vm/max_map_count)"
    echo "── memory ──────────────────────────────────"
    free -h | awk 'NR<=3'
    echo "── ollama env ──────────────────────────────"
    for k in OLLAMA_NUM_CTX OLLAMA_KEEP_ALIVE OLLAMA_MAX_LOADED_MODELS MALLOC_ARENA_MAX; do
        printf "  %-28s %s\n" "$k" "${!k:-not set}"
    done
}

_bitwig_launch() {
    _kernel_apply
    # Override bitwig's hardcoded -Xmx3g — give it up to 12G via swap
    export _JAVA_OPTIONS="-Xmx12g -Xms512m -XX:+UseG1GC -XX:MaxGCPauseMillis=50 -XX:+UseStringDeduplication"
    export JAVA_TOOL_OPTIONS="$_JAVA_OPTIONS"
    echo "[memtune] bitwig: _JAVA_OPTIONS=$_JAVA_OPTIONS"
    # Launch with best-effort realtime IO + elevated CPU
    exec nice -n -5 ionice -c 2 -n 0 bitwig-studio "$@"
}

_ollama_hot() {
    _kernel_apply
    _ollama_apply
    # Restart ollama service if running via systemd
    if systemctl --user is-active ollama >/dev/null 2>&1; then
        systemctl --user restart ollama && echo "[memtune] ollama service restarted"
    elif pgrep -x ollama >/dev/null; then
        echo "[memtune] ollama running (env changes take effect on next 'ollama run')"
    else
        echo "[memtune] ollama not running — start with: ollama serve"
    fi
}

case "$MODE" in
    apply)   _kernel_apply; _ollama_apply ;;
    status)  _status ;;
    bitwig)  shift 2>/dev/null || true; _bitwig_launch "$@" ;;
    ollama)  _ollama_hot ;;
    *)
        echo "Usage: memtune {apply|status|bitwig|ollama}"
        echo "  apply   — set kernel tunables + ollama env vars"
        echo "  status  — show current values"
        echo "  bitwig  — tune + launch bitwig with 12G heap"
        echo "  ollama  — tune + restart ollama with new ctx=2048"
        exit 1 ;;
esac
