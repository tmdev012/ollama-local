#!/bin/bash
# aliases.sh — Single source of truth for all sashi/ollama/git aliases
# Source this from ~/.bashrc and ~/.zshrc
# Git-tracked at: ~/ollama-local/lib/sh/aliases.sh
# v3.1.0 — 2026-02-17

# ============================================
# SASHI Primary Interface
# ============================================
alias s='~/ollama-local/sashi'
alias sask='~/ollama-local/sashi ask'
alias scode='~/ollama-local/sashi code'
alias slocal='~/ollama-local/sashi local'
alias schat='~/ollama-local/sashi chat'
alias sstatus='~/ollama-local/sashi status'
alias shistory='~/ollama-local/sashi history'
alias smodels='~/ollama-local/sashi models'
alias sgmail='~/ollama-local/sashi gmail'
alias sonline='~/ollama-local/sashi online'
alias scloud='~/ollama-local/sashi cloud'
alias skanban='~/ollama-local/sashi kanban'
alias s8b='~/ollama-local/sashi 8b'
alias ai='~/ollama-local/sashi'
alias aihelp='~/ollama-local/sashi help'

# ============================================
# Ollama Service Management
# ============================================
alias ollama-up='sudo systemctl start ollama && sleep 3 && sudo bash ~/ollama-local/scripts/ollama-boost.sh'
alias ollama-down='sudo systemctl stop ollama'
alias ollama-restart='sudo systemctl restart ollama && sleep 3 && sudo bash ~/ollama-local/scripts/ollama-boost.sh'
alias ollama-logs='sudo journalctl -u ollama -f -n 50'
alias ollama-status='systemctl is-active ollama && ollama list'
alias ollama-boost='sudo bash ~/ollama-local/scripts/ollama-boost.sh'

# ============================================
# Pipe Support
# ============================================
aipipe() { ~/ollama-local/sashi code "$1 $(cat -)"; }
alias analyze='aipipe "Analyze:"'
alias summarize='aipipe "Summarize:"'
alias explain='aipipe "Explain:"'
alias review='aipipe "Code review:"'

# ============================================
# Cross-Repo Navigation
# ============================================
alias cds='cd ~/ollama-local'
alias cdp='cd ~/persist-memory-probe'
alias cdk='cd ~/kanban-pmo'
alias cdc='cd ~/.claude'
alias cdprobe='cd ~/persist-memory-probe'

# ============================================
# Persist-Memory-Probe
# ============================================
alias probe='~/persist-memory-probe/probe.sh'
alias probe-sync='~/persist-memory-probe/sync.sh'
alias probe-status='~/persist-memory-probe/status.sh'

# ============================================
# GIT ALIASES
# ============================================

# Quick status
alias gs="git status -sb"
alias gd="git diff"
alias gds="git diff --staged"
alias gl="git log --oneline -20"
alias gla="git log --oneline --all --graph -20"

# Staging
alias ga="git add"
alias gaa="git add -A"
alias gap="git add -p"

# Commit
alias gc="git commit -m"
alias gca="git commit --amend"
alias gcn="git commit --amend --no-edit"

# Push/Pull
alias gp="git push"
alias gpf="git push --force-with-lease"
alias gpl="git pull"
alias gplo="git pull origin"

# Branches
alias gb="git branch"
alias gba="git branch -a"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gm="git merge"

# Remote
alias gr="git remote -v"
alias gra="git remote add"
alias gf="git fetch --all"

# Stash
alias gst="git stash"
alias gstp="git stash pop"
alias gstl="git stash list"

# ============================================
# GITPUSH — One command add+commit+push
# ============================================
gitpush() {
    local msg="${1:-Auto-commit $(date +%Y-%m-%d\ %H:%M)}"

    echo "Staging all changes..."
    git add -A

    echo "Committing: $msg"
    git commit -m "$msg

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

    echo "Pushing to origin..."
    git push

    echo "Done!"
}

alias gpp="gitpush"
alias ship="gitpush"

# Interactive gitpush (POSIX-compatible prompt for bash+zsh)
gitship() {
    echo "Current status:"
    git status -sb
    echo ""
    echo -n "Commit message: "
    read -r msg
    gitpush "$msg"
}
alias gship="gitship"

alias termux-sync="~/ollama-local/scripts/termux-sync.sh"

# ============================================
# SMART PUSH — Comprehensive Git Push
# ============================================
alias smartpush='~/ollama-local/scripts/smart-push.sh'
alias sp='smartpush'
alias gpush='smartpush'

# ============================================
# Git History (SQLite-backed, v2.0)
# ============================================
git-history() {
    python3 << 'PYEOF'
import sqlite3
import os
db = os.path.expanduser('~/ollama-local/db/history.db')
conn = sqlite3.connect(db)
c = conn.cursor()
try:
    c.execute('''SELECT hash, message, version_tag, issue_number, branch, 
                        files_changed, lines_added, lines_deleted, categories, timestamp 
                 FROM commits ORDER BY id DESC LIMIT 15''')
    rows = c.fetchall()
    if rows:
        print(f"{'Hash':<9} {'Ver':<8} {'Issue':<6} {'Cat':<12} {'+/-':<10} {'Message':<35}")
        print("\u2500" * 90)
        for r in rows:
            ver = r[2] or "-"
            issue = f"#{r[3]}" if r[3] else "-"
            cat = (r[8] or "other")[:10]
            changes = f"+{r[6] or 0}/-{r[7] or 0}"
            msg = (r[1] or '')[:33]
            print(f"{r[0]:<9} {ver:<8} {issue:<6} {cat:<12} {changes:<10} {msg}")
    else:
        print("No commits tracked. Use: smartpush")
except:
    print("Run smartpush first to initialize tracking")
PYEOF
}
alias ghist='git-history'

# View by issue
git-issue() {
    local issue="$1"
    [ -z "$issue" ] && { echo "Usage: git-issue <number>"; return 1; }
    python3 << PYEOF
import sqlite3, os
conn = sqlite3.connect(os.path.expanduser('~/ollama-local/db/history.db'))
c = conn.cursor()
c.execute("SELECT hash, message, version_tag, timestamp FROM commits WHERE issue_number=? ORDER BY id DESC", ('$issue',))
rows = c.fetchall()
print(f"Commits for issue #$issue:")
print("\u2500" * 60)
for r in rows:
    print(f"  {r[0]} | {r[2] or '-':<8} | {r[1][:40]}")
    print(f"           {r[3]}")
PYEOF
}
alias gissue='git-issue'

# View by version
git-version() {
    python3 << 'PYEOF'
import sqlite3, os
conn = sqlite3.connect(os.path.expanduser('~/ollama-local/db/history.db'))
c = conn.cursor()
c.execute("SELECT DISTINCT version_tag, hash, message, timestamp FROM commits WHERE version_tag IS NOT NULL ORDER BY id DESC LIMIT 10")
rows = c.fetchall()
print("Version Tags:")
print("\u2500" * 60)
for r in rows:
    print(f"  {r[0]:<10} {r[1]} | {r[2][:35]}")
PYEOF
}
alias gver='git-version'

# ============================================
# Help Function
# ============================================
mcp-help() {
    source ~/ollama-local/lib/sh/banner.sh 2>/dev/null || true
    sashi_banner 2>/dev/null || true
    echo "MCP AI Commands:"
    echo ""
    echo "  SASHI (recommended):"
    echo "    s 'question'      Ask AI (auto-routes)"
    echo "    slocal 'question' Offline (Llama)"
    echo "    sonline 'question' Cloud (OpenRouter free)"
    echo "    schat             Interactive chat"
    echo "    sgmail search     Email context"
    echo "    skanban           Kanban board"
    echo "    sstatus           System status"
    echo ""
    echo "  Pipe support:"
    echo "    cat file.py | analyze"
    echo "    git diff | review"
    echo ""
    echo "  Ollama:"
    echo "    ollama-up         Start + boost"
    echo "    ollama-down       Stop service"
    echo "    ollama-status     Check status"
    echo "    ollama-boost      Re-apply priority boost"
    echo ""
    echo "  Navigation:"
    echo "    cds / cdp / cdk / cdc   Jump to repos"
}
alias o8b='~/ollama-local/scripts/ollama-8b.sh'
