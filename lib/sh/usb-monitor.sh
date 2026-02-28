#!/bin/bash
# usb-monitor.sh — USB device detection library for sashi v3.2.1
# Single-file library: source me, then call usb_* functions
# Platform: Linux + Termux. Falls back to sysfs if lsusb unavailable.
# Usage: source lib/sh/usb-monitor.sh && usb_list

# ── Vendor database (Linux USB ID database subset) ───────────────────
declare -A USB_VENDORS=(
    ["12d1"]="Huawei"
    ["0951"]="Kingston"
    ["0781"]="SanDisk"
    ["0930"]="Toshiba"
    ["04e8"]="Samsung"
    ["058f"]="Alcor Micro"
    ["046d"]="Logitech"
    ["0bda"]="Realtek"
    ["8087"]="Intel"
    ["1d6b"]="Linux Foundation"
    ["18d1"]="Google/Nexus"
    ["22b8"]="Motorola"
    ["0bb4"]="HTC"
    ["2717"]="OnePlus"
    ["1ebf"]="Nothing"
    ["0fce"]="Sony"
    ["05c6"]="Qualcomm"
    ["2a70"]="ASUS"
    ["0403"]="FTDI"
    ["10c4"]="Silicon Labs"
    ["067b"]="Prolific"
    ["1a86"]="QinHeng (CH340)"
    ["2341"]="Arduino"
    ["0483"]="STMicroelectronics"
    ["04d8"]="Microchip"
    ["0d28"]="ARM/mbed"
)

# ── Platform detection ────────────────────────────────────────────────
usb_platform() {
    if [[ -n "${TERMUX_VERSION:-}" || -d "/data/data/com.termux" ]]; then
        echo "termux"
    elif [[ -f /proc/version ]] && grep -qi "android" /proc/version 2>/dev/null; then
        echo "android"
    else
        echo "linux"
    fi
}

# ── Core device listing ───────────────────────────────────────────────
usb_list() {
    local platform
    platform=$(usb_platform)

    echo -e "\033[34m=== USB Devices ($(date +%H:%M:%S)) ===\033[0m"

    if command -v lsusb &>/dev/null; then
        _usb_list_lsusb
    else
        _usb_list_sysfs
    fi
}

_usb_list_lsusb() {
    local count=0
    while IFS= read -r line; do
        if [[ $line =~ ID[[:space:]]([0-9a-fA-F]{4}):([0-9a-fA-F]{4}) ]]; then
            local vid="${BASH_REMATCH[1],,}"
            local pid="${BASH_REMATCH[2],,}"
            local vendor="${USB_VENDORS[$vid]:-Unknown}"
            local color="\033[0m"
            [[ "$vendor" != "Unknown" ]] && color="\033[33m"
            [[ "$vendor" == "Linux Foundation" ]] && color="\033[90m"
            echo -e "${color}${line}\033[0m  \033[36m[${vendor}]\033[0m"
            (( count++ ))
        fi
    done < <(lsusb 2>/dev/null)
    echo -e "\033[90m── $count device(s) total\033[0m"
}

_usb_list_sysfs() {
    # Termux fallback: read /sys/bus/usb/devices
    local count=0
    for dev in /sys/bus/usb/devices/*/; do
        [[ -f "${dev}product" ]] || continue
        local product
        product=$(cat "${dev}product" 2>/dev/null || echo "Unknown")
        local mfr
        mfr=$(cat "${dev}manufacturer" 2>/dev/null || echo "")
        local speed
        speed=$(cat "${dev}speed" 2>/dev/null || echo "?")
        echo -e "  \033[33m${mfr:+$mfr / }${product}\033[0m  \033[90m[${speed}M] $(basename "${dev}")\033[0m"
        (( count++ ))
    done
    [[ $count -eq 0 ]] && echo "  No USB devices found via sysfs"
    echo -e "\033[90m── $count device(s) total\033[0m"
}

# ── Vendor lookup ─────────────────────────────────────────────────────
usb_vendor() {
    local vid="${1,,}"
    echo "${USB_VENDORS[$vid]:-Unknown (${vid})}"
}

# ── Storage device listing ────────────────────────────────────────────
usb_storage() {
    echo -e "\033[34m=== USB Storage Devices ===\033[0m"

    if ! command -v lsblk &>/dev/null; then
        echo "  lsblk not available"
        return 1
    fi

    local found=0
    while IFS= read -r line; do
        if [[ $line =~ ^sd[b-z] ]]; then
            echo -e "  \033[32m/dev/${line%%[[:space:]]*}\033[0m  $line"
            found=1
        fi
    done < <(lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL,MODEL 2>/dev/null | tail -n +2)

    if [[ $found -eq 0 ]]; then
        echo "  No USB storage devices detected"
        echo "  (sda is typically the internal drive)"
    fi

    echo ""
    echo -e "\033[34m=== Mount Points ===\033[0m"
    mount 2>/dev/null | grep "^/dev/sd[b-z]" | while read -r line; do
        echo -e "  \033[32m✓\033[0m $line"
    done || echo "  No USB filesystems mounted"
}

# ── Detailed info for a device ────────────────────────────────────────
usb_details() {
    local target="${1:-}"
    if [[ -z "$target" ]]; then
        echo "Usage: usb_details <vendor_id:product_id>"
        echo "       usb_details 12d1:1f01"
        return 1
    fi

    if ! command -v lsusb &>/dev/null; then
        echo "lsusb not available"
        return 1
    fi

    lsusb -v -d "$target" 2>/dev/null | grep -E "^(Bus|Device|idVendor|idProduct|iProduct|iManufacturer|bDeviceClass|bNumInterfaces|bInterfaceClass|MaxPower)" | head -30
}

# ── Device tree / hierarchy ───────────────────────────────────────────
usb_tree() {
    echo -e "\033[34m=== USB Device Tree ===\033[0m"

    if command -v lsusb &>/dev/null && lsusb -t 2>/dev/null | grep -q .; then
        lsusb -t 2>/dev/null
        return
    fi

    # sysfs fallback
    for dev in /sys/bus/usb/devices/*/; do
        [[ -f "${dev}product" ]] || continue
        local name
        name=$(basename "${dev}")
        local depth
        depth=$(echo "$name" | tr -cd '.' | wc -c)
        local indent
        indent=$(printf '%*s' $((depth * 2)) '')
        local product
        product=$(cat "${dev}product" 2>/dev/null || echo "?")
        local speed
        speed=$(cat "${dev}speed" 2>/dev/null || echo "?")
        echo -e "${indent}\033[33m├─\033[0m $name: \033[36m$product\033[0m [$speed Mbps]"
    done 2>/dev/null
}

# ── Real-time event monitor ───────────────────────────────────────────
usb_watch_events() {
    local duration="${1:-0}"  # 0 = infinite
    echo -e "\033[34m=== USB Event Monitor ===\033[0m"
    echo -e "\033[33mPlug/unplug devices. Press Ctrl+C to stop.\033[0m"

    if ! command -v dmesg &>/dev/null; then
        echo "dmesg not available (need root on some systems)"
        return 1
    fi

    if [[ $duration -eq 0 ]]; then
        sudo dmesg -w 2>/dev/null | while IFS= read -r line; do
            if echo "$line" | grep -qi "usb"; then
                if echo "$line" | grep -qi "new\|attach\|connect\|enumerat"; then
                    echo -e "\033[32m[+] CONNECTED\033[0m  $line"
                elif echo "$line" | grep -qi "disconnect\|remov\|detach"; then
                    echo -e "\033[31m[-] REMOVED\033[0m    $line"
                else
                    echo -e "\033[90m[~] $line\033[0m"
                fi
            fi
        done
    else
        # Timed monitor
        sudo timeout "$duration" dmesg -w 2>/dev/null | grep -i "usb" | while IFS= read -r line; do
            if echo "$line" | grep -qi "new\|connect"; then
                echo -e "\033[32m[+]\033[0m $line"
            elif echo "$line" | grep -qi "disconnect\|remov"; then
                echo -e "\033[31m[-]\033[0m $line"
            fi
        done
        echo -e "\033[90m── Monitor ended after ${duration}s\033[0m"
    fi
}

# ── Search by name/vendor ─────────────────────────────────────────────
usb_search() {
    local term="${1:-}"
    [[ -z "$term" ]] && { echo "Usage: usb_search <name>"; return 1; }

    echo -e "\033[34m=== Search: $term ===\033[0m"

    echo -e "\033[33mUSB devices:\033[0m"
    lsusb 2>/dev/null | grep -i "$term" --color=always || echo "  No matches in lsusb"

    echo ""
    echo -e "\033[33mRecent kernel messages:\033[0m"
    dmesg 2>/dev/null | grep -i "$term" --color=always | tail -10 || echo "  No matches in dmesg"
}

# ── Export to JSONL ───────────────────────────────────────────────────
usb_export() {
    local outfile="${1:-$HOME/ollama-local/logs/usb-events.jsonl}"
    mkdir -p "$(dirname "$outfile")"

    local ts
    ts=$(date -Iseconds)

    if command -v lsusb &>/dev/null; then
        while IFS= read -r line; do
            if [[ $line =~ Bus[[:space:]]([0-9]+)[[:space:]]Device[[:space:]]([0-9]+):[[:space:]]ID[[:space:]]([0-9a-fA-F]{4}):([0-9a-fA-F]{4})[[:space:]](.*) ]]; then
                local bus="${BASH_REMATCH[1]}"
                local dev="${BASH_REMATCH[2]}"
                local vid="${BASH_REMATCH[3],,}"
                local pid="${BASH_REMATCH[4],,}"
                local desc="${BASH_REMATCH[5]}"
                local vendor="${USB_VENDORS[$vid]:-Unknown}"
                echo "{\"timestamp\":\"$ts\",\"bus\":\"$bus\",\"device\":\"$dev\",\"vendor_id\":\"$vid\",\"product_id\":\"$pid\",\"vendor_name\":\"$vendor\",\"description\":\"$desc\"}" >> "$outfile"
            fi
        done < <(lsusb 2>/dev/null)
        echo "USB snapshot → $outfile"
    else
        echo "{\"timestamp\":\"$ts\",\"error\":\"lsusb not available\"}" >> "$outfile"
        echo "Warning: lsusb unavailable, logged error to $outfile"
    fi
}

# ── Quick status line (for IDE header) ───────────────────────────────
usb_statusline() {
    if ! command -v lsusb &>/dev/null; then
        echo "USB:n/a"
        return
    fi

    local devices
    devices=$(lsusb 2>/dev/null | grep -v "Linux Foundation" | wc -l)
    local adb_dev=""

    ADB_BIN="${ADB_BIN:-$HOME/Android/platform-tools/adb}"
    if [[ -x "$ADB_BIN" ]]; then
        adb_dev=$("$ADB_BIN" devices 2>/dev/null | grep -v "^List\|^$\|^*" | grep "device$" | wc -l)
    fi

    if [[ -n "$adb_dev" && "$adb_dev" -gt 0 ]]; then
        echo "USB:${devices} ADB:${adb_dev}●"
    else
        echo "USB:${devices}"
    fi
}
