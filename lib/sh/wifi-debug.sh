#!/bin/bash
# wifi-debug.sh — ADB WiFi wireless debugging library for sashi v3.2.1
# Requires: adb (~/Android/platform-tools/adb)
# Usage: source lib/sh/wifi-debug.sh && wifi_adb_init

ADB_BIN="${ADB_BIN:-$HOME/Android/platform-tools/adb}"
WIFI_DEFAULT_PORT="${WIFI_DEFAULT_PORT:-5555}"

_wifi_adb_check() {
    if [[ ! -x "$ADB_BIN" ]]; then
        echo -e "\033[31madb not found at $ADB_BIN\033[0m"
        echo "Install: bash ~/ollama-local/scripts/android-setup.sh"
        return 1
    fi
}

# ── Step 1: Enable TCP mode over USB (device must be plugged in) ──────
wifi_adb_init() {
    local port="${1:-$WIFI_DEFAULT_PORT}"
    _wifi_adb_check || return 1

    echo -e "\033[34m=== WiFi ADB Init ===\033[0m"
    echo "Step 1: Switching device to TCP/IP mode on port $port..."

    if ! "$ADB_BIN" tcpip "$port" 2>&1; then
        echo -e "\033[31mFailed — is a device connected via USB?\033[0m"
        echo "Run: sashi adb status"
        return 1
    fi

    echo ""
    echo "Step 2: Getting device IP address..."
    local ip
    ip=$("$ADB_BIN" shell ip route 2>/dev/null | awk '/wlan0/ && /src/ {print $9}' | head -1)
    if [[ -z "$ip" ]]; then
        ip=$("$ADB_BIN" shell ip addr show wlan0 2>/dev/null | awk '/inet / {split($2,a,"/"); print a[1]}' | head -1)
    fi

    if [[ -n "$ip" ]]; then
        echo -e "Device IP: \033[32m$ip\033[0m"
        echo ""
        echo "Step 3: Connecting wirelessly..."
        "$ADB_BIN" connect "$ip:$port"
        echo ""
        echo -e "\033[32m✓ Wireless debugging ready\033[0m"
        echo "You can now unplug USB."
        echo "Verify: sashi wifi status"
    else
        echo -e "\033[33mCould not auto-detect IP.\033[0m"
        echo "Manually: Settings → About phone → Status → IP address"
        echo "Then run: sashi wifi connect <phone-ip>"
    fi
}

# ── Connect to a known IP ─────────────────────────────────────────────
wifi_adb_connect() {
    local ip="${1:-}"
    local port="${2:-$WIFI_DEFAULT_PORT}"
    _wifi_adb_check || return 1

    [[ -z "$ip" ]] && { echo "Usage: wifi_adb_connect <ip> [port]"; return 1; }

    echo -e "\033[34mConnecting to $ip:$port...\033[0m"
    "$ADB_BIN" connect "$ip:$port"
}

# ── Scan LAN for Android devices ─────────────────────────────────────
wifi_adb_scan() {
    _wifi_adb_check || return 1

    echo -e "\033[34m=== Scanning LAN for Android Devices ===\033[0m"

    # Get local subnet
    local subnet
    subnet=$(ip route 2>/dev/null | awk '/src/ && /wlan0|wlp|wlan/ {print $1}' | head -1)
    if [[ -z "$subnet" ]]; then
        subnet=$(ip route 2>/dev/null | awk 'NR==1 {print $1}')
    fi

    if [[ -z "$subnet" ]]; then
        echo "Could not determine local subnet. Try: wifi_adb_connect <ip>"
        return 1
    fi

    echo "Scanning $subnet for port $WIFI_DEFAULT_PORT (ADB)..."

    if command -v nmap &>/dev/null; then
        # Fast nmap scan for ADB port
        nmap -p "$WIFI_DEFAULT_PORT" --open -T4 "$subnet" 2>/dev/null | grep -E "^Nmap|$WIFI_DEFAULT_PORT/tcp" | while IFS= read -r line; do
            if [[ $line =~ Nmap.*scan.*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
                echo -e "\033[33mHost: ${BASH_REMATCH[1]}\033[0m"
            elif echo "$line" | grep -q "open"; then
                echo -e "  \033[32mPort $WIFI_DEFAULT_PORT: OPEN\033[0m — Try: wifi_adb_connect <ip>"
            fi
        done
    elif command -v arp &>/dev/null; then
        # arp -a as fallback (no port check)
        echo -e "\033[33m(nmap not available — showing ARP table)\033[0m"
        arp -a 2>/dev/null | while IFS= read -r line; do
            echo "  $line"
        done
        echo ""
        echo "Try connecting manually: wifi_adb_connect <ip>"
    else
        echo "nmap and arp not available. Connect manually: sashi wifi connect <ip>"
    fi
}

# ── Show connected WiFi devices ───────────────────────────────────────
wifi_adb_status() {
    _wifi_adb_check || return 1

    echo -e "\033[34m=== WiFi ADB Devices ===\033[0m"

    local found=0
    while IFS= read -r line; do
        # Wireless devices have IP:port format
        if [[ $line =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+ ]]; then
            local addr="${line%%[[:space:]]*}"
            local state="${line##*[[:space:]]}"
            local color="\033[32m"
            [[ "$state" != "device" ]] && color="\033[33m"
            echo -e "  ${color}● $addr\033[0m  [$state]"
            found=1
        fi
    done < <("$ADB_BIN" devices 2>/dev/null | tail -n +2)

    if [[ $found -eq 0 ]]; then
        echo -e "  \033[90mNo wireless ADB devices connected\033[0m"
        echo "  Use: sashi wifi init  (with USB plugged in first)"
    fi
}

# ── Logcat over WiFi ──────────────────────────────────────────────────
wifi_adb_logcat() {
    _wifi_adb_check || return 1
    local filter="${1:-}"

    echo -e "\033[34m=== WiFi Logcat ${filter:+(filter: $filter)} ===\033[0m"
    echo -e "\033[33mPress Ctrl+C to stop\033[0m"

    if [[ -n "$filter" ]]; then
        "$ADB_BIN" logcat 2>/dev/null | grep -i "$filter" --color=always
    else
        "$ADB_BIN" logcat 2>/dev/null
    fi
}

# ── Shell command over WiFi ───────────────────────────────────────────
wifi_adb_shell() {
    _wifi_adb_check || return 1
    local cmd="${*:-}"

    if [[ -z "$cmd" ]]; then
        echo -e "\033[34m=== WiFi ADB Interactive Shell ===\033[0m"
        "$ADB_BIN" shell
    else
        "$ADB_BIN" shell "$cmd"
    fi
}

# ── Disconnect all WiFi ADB ───────────────────────────────────────────
wifi_adb_disconnect() {
    _wifi_adb_check || return 1

    local ip="${1:-}"
    if [[ -n "$ip" ]]; then
        "$ADB_BIN" disconnect "$ip"
    else
        "$ADB_BIN" disconnect
        echo "Disconnected all wireless ADB devices"
    fi
}

# ── Status line (for IDE header) ──────────────────────────────────────
wifi_statusline() {
    [[ ! -x "$ADB_BIN" ]] && echo "WiFi:n/a" && return

    local count
    count=$("$ADB_BIN" devices 2>/dev/null | tail -n +2 | grep -c "^[0-9].*device$" 2>/dev/null); count=${count:-0}

    if [[ "$count" -gt 0 ]]; then
        local addr
        addr=$("$ADB_BIN" devices 2>/dev/null | grep "^[0-9].*device$" | head -1 | awk '{print $1}')
        echo "WiFi:${addr}●"
    else
        echo "WiFi:─"
    fi
}
