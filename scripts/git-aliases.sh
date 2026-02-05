#!/bin/bash
# Git Aliases Installer for SASHI
# Adds to both .bashrc and .zshrc

BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"

GIT_ALIASES='
# ============================================
# GIT ALIASES & PIPELINE
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
# GITPUSH - One command add+commit+push
# ============================================
gitpush() {
    local msg="${1:-Auto-commit $(date +%Y-%m-%d\ %H:%M)}"

    echo "📦 Staging all changes..."
    git add -A

    echo "📝 Committing: $msg"
    git commit -m "$msg

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"

    echo "🚀 Pushing to origin..."
    git push

    echo "✅ Done!"
}

# Alias for gitpush
alias gpp="gitpush"
alias ship="gitpush"

# Interactive gitpush
gitship() {
    echo "📋 Current status:"
    git status -sb
    echo ""
    read -p "Commit message: " msg
    gitpush "$msg"
}
alias gship="gitship"
'

# Add to bashrc if not exists
if ! grep -q "GITPUSH - One command" "$BASHRC" 2>/dev/null; then
    echo "$GIT_ALIASES" >> "$BASHRC"
    echo "Added git aliases to $BASHRC"
else
    echo "Git aliases already in $BASHRC"
fi

# Add to zshrc if not exists
if ! grep -q "GITPUSH - One command" "$ZSHRC" 2>/dev/null; then
    echo "$GIT_ALIASES" >> "$ZSHRC"
    echo "Added git aliases to $ZSHRC"
else
    echo "Git aliases already in $ZSHRC"
fi

echo ""
echo "Git aliases installed!"
echo "  gitpush 'message'  - Add, commit, push in one command"
echo "  gpp 'message'      - Short alias for gitpush"
echo "  ship 'message'     - Another alias"
echo "  gship              - Interactive mode"
