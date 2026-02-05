#!/bin/bash
# SASHI Git/SSH/GPG Setup Script
# Run with: ./scripts/git-setup.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  SASHI Git/SSH/GitHub Setup${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Config
GIT_USER="tmdev012"
GIT_EMAIL="tmdev012@users.noreply.github.com"
REPO_NAME="ollama-local"
SSH_KEY="$HOME/.ssh/id_ed25519"

# Step 1: Git config
echo -e "${GREEN}[1/6]${NC} Configuring Git..."
git config --global user.name "$GIT_USER"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global core.editor "nano"
git config --global push.default current
git config --global pull.rebase false
echo "  User: $GIT_USER"
echo "  Email: $GIT_EMAIL"

# Step 2: Generate SSH key
echo ""
echo -e "${GREEN}[2/6]${NC} Setting up SSH key..."
if [ -f "$SSH_KEY" ]; then
    echo "  SSH key already exists: $SSH_KEY"
else
    echo "  Generating new ED25519 key..."
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY" -N ""
    echo "  Created: $SSH_KEY"
fi

# Start ssh-agent and add key
eval "$(ssh-agent -s)" > /dev/null
ssh-add "$SSH_KEY" 2>/dev/null || true

echo ""
echo -e "${YELLOW}Your SSH public key:${NC}"
echo "─────────────────────────────────────────────"
cat "${SSH_KEY}.pub"
echo "─────────────────────────────────────────────"
echo ""
echo -e "${YELLOW}Copy the key above and add it to GitHub:${NC}"
echo "  https://github.com/settings/ssh/new"
echo ""
read -p "Press ENTER after adding SSH key to GitHub..."

# Step 3: Install GitHub CLI
echo ""
echo -e "${GREEN}[3/6]${NC} Installing GitHub CLI..."
if command -v gh &>/dev/null; then
    echo "  gh already installed: $(gh --version | head -1)"
else
    echo "  Installing gh..."
    sudo apt update
    sudo apt install gh -y || {
        # Manual install if apt fails
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install gh -y
    }
fi

# Step 4: GitHub auth
echo ""
echo -e "${GREEN}[4/6]${NC} Authenticating with GitHub..."
if gh auth status &>/dev/null; then
    echo "  Already authenticated:"
    gh auth status
else
    echo "  Starting GitHub authentication..."
    gh auth login -p ssh -h github.com
fi

# Verify
echo ""
echo -e "${GREEN}[5/6]${NC} Verifying setup..."
echo "  Testing SSH connection..."
ssh -T git@github.com 2>&1 | head -2 || true

# Step 6: Create/set remote
echo ""
echo -e "${GREEN}[6/6]${NC} Setting up remote repository..."
cd ~/ollama-local

# Check if repo exists on GitHub
if gh repo view "$GIT_USER/$REPO_NAME" &>/dev/null; then
    echo "  Repository exists: github.com/$GIT_USER/$REPO_NAME"
else
    echo "  Creating repository on GitHub..."
    gh repo create "$REPO_NAME" --public --source=. --remote=origin --push || {
        echo "  Creating private repo instead..."
        gh repo create "$REPO_NAME" --private --source=. --remote=origin --push
    }
fi

# Update remote to SSH
git remote remove origin 2>/dev/null || true
git remote add origin "git@github.com:$GIT_USER/$REPO_NAME.git"
echo "  Remote set: git@github.com:$GIT_USER/$REPO_NAME.git"

# Show status
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Git config:"
git config --global --list | grep -E "user\.|push\.|pull\."
echo ""
echo "SSH key: $SSH_KEY"
echo "Remote: $(git remote -v | head -1)"
echo ""
echo "GitHub auth:"
gh auth status 2>&1 | head -3
echo ""
echo -e "Ready to push! Use: ${GREEN}gitpush 'commit message'${NC}"
