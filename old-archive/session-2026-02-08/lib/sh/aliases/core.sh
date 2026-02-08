#!/bin/bash
# ============================================
# CORE ALIASES - SASHI Primary Interface
# ============================================
# Group: core
# Purpose: Main AI CLI entry points
# Onboarding: These are the only aliases you need day-to-day
# Test: run `s status` to verify sashi is reachable
# ============================================

# --- SASHI_HOME resolves once, used everywhere ---
# VERBOSE_L3: SASHI_HOME is the root of the ollama-local repo.
#             All aliases below reference it so if the repo moves,
#             you only change this one variable.
export SASHI_HOME="${SASHI_HOME:-$HOME/ollama-local}"

# --- Primary interface ---
# TEST_VAR: CMD_SASHI="sashi router reachable"
# USAGE: s "what is grpc?" → routes to llama3.2 local
alias s='$SASHI_HOME/sashi'

# TEST_VAR: CMD_ASK="quick question pipeline"
alias sask='$SASHI_HOME/sashi ask'

# TEST_VAR: CMD_CODE="code generation pipeline"
alias scode='$SASHI_HOME/sashi code'

# TEST_VAR: CMD_LOCAL="offline llama3.2 direct"
alias slocal='$SASHI_HOME/sashi local'

# TEST_VAR: CMD_CHAT="interactive chat loop"
alias schat='$SASHI_HOME/sashi chat'

# TEST_VAR: CMD_STATUS="system health check"
alias sstatus='$SASHI_HOME/sashi status'

# TEST_VAR: CMD_HISTORY="sqlite query log"
alias shistory='$SASHI_HOME/sashi history'

# TEST_VAR: CMD_MODELS="ollama model list"
alias smodels='$SASHI_HOME/sashi models'

# TEST_VAR: CMD_GMAIL="email context access"
alias sgmail='$SASHI_HOME/sashi gmail'

# TEST_VAR: CMD_STREAM="streaming llama output"
alias sstream='$SASHI_HOME/sashi stream'

# --- Quick access (muscle memory) ---
alias ai='$SASHI_HOME/sashi'
alias aihelp='$SASHI_HOME/sashi help'

# --- Help function ---
# VERBOSE_L3: Shows all available commands grouped by function.
#             Called via `mcp-help` or `shelp`.
mcp-help() {
    echo "MCP AI Commands (llama3.2 local-first):"
    echo ""
    echo "  Primary:"
    echo "    s 'question'      Ask AI (llama3.2, cached)"
    echo "    sask 'question'   Quick question"
    echo "    scode 'task'      Code help"
    echo "    slocal 'question' Offline (Llama)"
    echo "    sstream 'prompt'  Streaming output"
    echo "    schat             Interactive chat"
    echo "    sgmail search     Email context"
    echo "    sstatus           System status"
    echo ""
    echo "  Pipe support:"
    echo "    cat file.py | analyze"
    echo "    git diff | review"
    echo ""
    echo "  Ollama:"
    echo "    ollama-up         Start service"
    echo "    ollama-down       Stop service"
    echo "    ollama-status     Check status"
    echo ""
    echo "  Navigation:"
    echo "    cds / cdp / cdk   Jump to repos"
    echo ""
    echo "  Full docs: $SASHI_HOME/README.md"
}
alias shelp='mcp-help'
