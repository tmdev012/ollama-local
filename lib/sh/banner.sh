#!/bin/bash
# SASHI v3.1.0 — Shared ASCII Banner
# Source this file, then call: sashi_banner

sashi_banner() {
    local CYAN='\033[0;36m'
    local GREEN='\033[0;32m'
    local DIM='\033[2m'
    local NC='\033[0m'
    echo -e "${DIM}┌──────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}  ███████╗ █████╗ ███████╗██╗  ██╗██╗${NC}"
    echo -e "${CYAN}  ██╔════╝██╔══██╗██╔════╝██║  ██║██║${NC}"
    echo -e "${CYAN}  ███████╗███████║███████╗███████║██║${NC}"
    echo -e "${CYAN}  ╚════██║██╔══██║╚════██║██╔══██║██║${NC}"
    echo -e "${CYAN}  ███████║██║  ██║███████║██║  ██║██║${NC}"
    echo -e "${CYAN}  ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝${NC}"
    echo -e "${GREEN}         Smart AI Shell Interface  •  v3.1.0${NC}"
    echo -e "${DIM}         Local-first • llama3.2 • ollama run • i7-6500U${NC}"
    echo -e "${DIM}├──────────────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${DIM}│  sashi ask│code│chat│kanban│write│history│status│models│voice│help          │${NC}"
    echo -e "${DIM}│  ai-orchestrator --ask│--code│--kanban│--write│--status│--help              │${NC}"
    echo -e "${DIM}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
}
