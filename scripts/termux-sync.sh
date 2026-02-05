#!/bin/bash
# Termux Sync - Backup/restore shell configs between devices
# Usage:
#   termux-sync push    - Upload local configs to GitHub
#   termux-sync pull    - Download configs from GitHub
#   termux-sync status  - Show sync status

set -e

REPO_DIR="$HOME/ollama-local"
SYNC_DIR="$REPO_DIR/sync"
BRANCH="main"

# Files to sync
SYNC_FILES=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.bash_history"
    "$HOME/.zsh_history"
    "$HOME/.gitconfig"
    "$HOME/.ssh/config"
)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect environment
detect_env() {
    if [ -n "$TERMUX_VERSION" ]; then
        echo "termux"
    elif [ -f /etc/os-release ]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

ENV=$(detect_env)

push_sync() {
    echo -e "${BLUE}Pushing configs to GitHub...${NC}"

    mkdir -p "$SYNC_DIR/$ENV"

    for file in "${SYNC_FILES[@]}"; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            cp "$file" "$SYNC_DIR/$ENV/$filename"
            echo -e "  ${GREEN}✓${NC} $filename"
        fi
    done

    # Add timestamp
    echo "Last sync: $(date -Iseconds)" > "$SYNC_DIR/$ENV/.last_sync"
    echo "Environment: $ENV" >> "$SYNC_DIR/$ENV/.last_sync"
    echo "Hostname: $(hostname)" >> "$SYNC_DIR/$ENV/.last_sync"

    cd "$REPO_DIR"
    git add sync/
    git commit -m "Sync: $ENV configs $(date +%Y-%m-%d_%H:%M)" || echo "No changes to commit"
    git push origin "$BRANCH"

    echo -e "${GREEN}Pushed!${NC}"
}

pull_sync() {
    echo -e "${BLUE}Pulling configs from GitHub...${NC}"

    cd "$REPO_DIR"
    git pull origin "$BRANCH"

    # Check if sync dir exists for this environment
    if [ ! -d "$SYNC_DIR/$ENV" ]; then
        echo -e "${YELLOW}No sync data for $ENV environment${NC}"
        echo "Available: $(ls "$SYNC_DIR" 2>/dev/null || echo 'none')"
        return 1
    fi

    echo "Restoring configs for: $ENV"

    for file in "${SYNC_FILES[@]}"; do
        filename=$(basename "$file")
        if [ -f "$SYNC_DIR/$ENV/$filename" ]; then
            # Backup existing
            [ -f "$file" ] && cp "$file" "${file}.backup"
            cp "$SYNC_DIR/$ENV/$filename" "$file"
            echo -e "  ${GREEN}✓${NC} $filename"
        fi
    done

    echo -e "${GREEN}Restored!${NC}"
    echo "Reload shell: source ~/.bashrc"
}

show_status() {
    echo -e "${BLUE}Termux Sync Status${NC}"
    echo "===================="
    echo "Environment: $ENV"
    echo "Repo: $REPO_DIR"
    echo ""

    echo "Synced environments:"
    for dir in "$SYNC_DIR"/*/; do
        if [ -d "$dir" ]; then
            env_name=$(basename "$dir")
            last_sync=$(cat "$dir/.last_sync" 2>/dev/null | head -1 || echo "unknown")
            echo "  - $env_name: $last_sync"
        fi
    done

    echo ""
    echo "Local files:"
    for file in "${SYNC_FILES[@]}"; do
        if [ -f "$file" ]; then
            size=$(du -h "$file" 2>/dev/null | cut -f1)
            echo -e "  ${GREEN}✓${NC} $(basename $file) ($size)"
        else
            echo -e "  ${YELLOW}✗${NC} $(basename $file) (missing)"
        fi
    done
}

setup_auto_sync() {
    echo -e "${BLUE}Setting up auto-sync on shell exit...${NC}"

    # Add to bashrc
    if ! grep -q "termux-sync" "$HOME/.bashrc" 2>/dev/null; then
        cat >> "$HOME/.bashrc" << 'AUTOSYNC'

# Auto-sync on exit (optional)
trap 'cd ~/ollama-local && git add -A && git commit -m "Auto-sync $(date +%Y-%m-%d)" 2>/dev/null && git push 2>/dev/null' EXIT
AUTOSYNC
        echo "Added auto-sync to .bashrc"
    fi

    echo -e "${GREEN}Auto-sync configured!${NC}"
}

case "${1:-status}" in
    push)
        push_sync
        ;;
    pull)
        pull_sync
        ;;
    status)
        show_status
        ;;
    auto)
        setup_auto_sync
        ;;
    *)
        echo "Termux Sync - Backup shell configs to GitHub"
        echo ""
        echo "Usage: termux-sync <command>"
        echo ""
        echo "Commands:"
        echo "  push     Upload local configs to GitHub"
        echo "  pull     Download configs from GitHub"
        echo "  status   Show sync status"
        echo "  auto     Enable auto-sync on shell exit"
        echo ""
        echo "Environment: $ENV"
        ;;
esac
