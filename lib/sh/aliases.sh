#!/bin/bash
# aliases.sh — Single source of all sashi shell aliases
# Source from .bashrc / .zshrc:  source ~/ollama-local/lib/sh/aliases.sh
# sashi v3.2.1

_SASHI_DIR="${_SASHI_DIR:-$HOME/ollama-local}"

# ── Core sashi shortcuts ──────────────────────────────────────────────
alias s='$_SASHI_DIR/sashi'
alias sask='$_SASHI_DIR/sashi ask'
alias scode='$_SASHI_DIR/sashi code'
alias slocal='$_SASHI_DIR/sashi local'
alias schat='$_SASHI_DIR/sashi chat'
alias sstatus='$_SASHI_DIR/sashi status'
alias shistory='$_SASHI_DIR/sashi history'
alias smodels='$_SASHI_DIR/sashi models'
alias schangelog='$_SASHI_DIR/sashi changelog'
alias sgmail='$_SASHI_DIR/sashi gmail'
alias skanban='$_SASHI_DIR/sashi kanban board'

# ── Online / cloud ────────────────────────────────────────────────────
alias sonline='$_SASHI_DIR/sashi online'
alias scloud='$_SASHI_DIR/sashi cloud'
alias shf='$_SASHI_DIR/sashi hf'

# ── 8B model ──────────────────────────────────────────────────────────
alias s8b='$_SASHI_DIR/sashi 8b'

# ── USB / WiFi debugging ──────────────────────────────────────────────
alias usb-scan='$_SASHI_DIR/sashi usb scan'
alias usb-watch='$_SASHI_DIR/sashi usb watch'
alias usb-storage='$_SASHI_DIR/sashi usb storage'
alias wifi-init='$_SASHI_DIR/sashi wifi init'
alias wifi-connect='$_SASHI_DIR/sashi wifi connect'
alias wifi-scan='$_SASHI_DIR/sashi wifi scan'
alias wifi-status='$_SASHI_DIR/sashi wifi status'
alias wifi-logcat='$_SASHI_DIR/sashi wifi logcat'

# ── ADB shortcuts ─────────────────────────────────────────────────────
alias sadb='$_SASHI_DIR/sashi adb'
alias sdev='$_SASHI_DIR/sashi adb devices'
alias slogcat='$_SASHI_DIR/sashi adb logcat'

# ── gRPC ──────────────────────────────────────────────────────────────
alias sgrpc='$_SASHI_DIR/sashi grpc'
alias sgrpc-start='$_SASHI_DIR/sashi grpc start'
alias sgrpc-status='$_SASHI_DIR/sashi grpc status'
alias sprobe='$_SASHI_DIR/sashi probe'
alias sprobe-list='$_SASHI_DIR/sashi probe list'
alias sprobe-sync='$_SASHI_DIR/sashi probe sync'

# ── Ollama control ────────────────────────────────────────────────────
alias ollama-up='ollama serve &>/dev/null &'
alias ollama-down='pkill -f "ollama serve" 2>/dev/null; echo "Ollama stopped"'
alias ollama-restart='ollama-down; sleep 1; ollama-up; echo "Ollama restarted"'
alias ollama-logs='journalctl -u ollama -f 2>/dev/null || tail -f /tmp/ollama*.log 2>/dev/null'
alias ollama-boost='bash $_SASHI_DIR/scripts/ollama-boost.sh'

# ── Navigation ────────────────────────────────────────────────────────
alias cds='cd $_SASHI_DIR'
alias cdp='cd $HOME/persist-memory-probe'
alias cdk='cd $HOME/kanban-pmo'
alias cdf='cd $HOME/football-telemetry'

# ── Smart push ────────────────────────────────────────────────────────
alias smartpush='bash $_SASHI_DIR/scripts/smart-push.sh'
alias sp='bash $_SASHI_DIR/scripts/smart-push.sh'
alias gpush='bash $_SASHI_DIR/scripts/smart-push.sh'

# ── Git shortcuts ─────────────────────────────────────────────────────
alias gs='git status -sb'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline -20'
alias gla='git log --all --graph --oneline -30'
alias ga='git add'
alias gaa='git add -A'
alias gap='git add -p'
alias gc='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gb='git branch'
alias gco='git checkout'

# ── Quick AI shortcuts ────────────────────────────────────────────────
alias ai='$_SASHI_DIR/sashi ask'
alias aihelp='$_SASHI_DIR/sashi help'

# ── IDE ───────────────────────────────────────────────────────────────
alias side='$_SASHI_DIR/sashi android-studio'

export _SASHI_DIR
