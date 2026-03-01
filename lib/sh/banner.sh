#!/bin/bash
# banner.sh — Shared ASCII art banner for sashi v3.2.2
# Usage: source lib/sh/banner.sh && sashi_banner

sashi_banner() {
    local ver="${1:-${VERSION:-3.2.2}}"
    echo -e "\033[34m"
    cat << 'BANNER'
 ███████╗ █████╗ ███████╗██╗  ██╗██╗
 ██╔════╝██╔══██╗██╔════╝██║  ██║██║
 ███████╗███████║███████╗███████║██║
 ╚════██║██╔══██║╚════██║██╔══██║██║
 ███████║██║  ██║███████║██║  ██║██║
 ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝
BANNER
    echo -e "\033[0m\033[90m  Smart AI Shell Interface  v${ver}  local-first\033[0m"
    echo ""
}

# Compact one-liner for tight contexts
sashi_banner_short() {
    local ver="${1:-${VERSION:-3.2.2}}"
    echo -e "\033[34m[SASHI v${ver}]\033[0m \033[90mlocal-first AI · llama3.2 · zero cloud costs\033[0m"
}
