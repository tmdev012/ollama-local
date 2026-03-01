#!/bin/bash
# git-autonomous.sh — Full autonomous repo creation pipeline
# CMMI4: SSH keygen → gh repo create → git init → push
# Usage: git-autonomous.sh <repo-name> [description]
# Archived 2026-02-08, restored 2026-03-01

set -e
REPO_NAME="${1:?Usage: git-autonomous.sh <repo-name> [description]}"
DESCRIPTION="${2:-Auto-created by SASHI}"
SASHI_DB="${SASHI_DB:-$HOME/ollama-local/db/history.db}"

# Step 1: Ensure SSH key exists
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -C "$(git config user.email)" -f ~/.ssh/id_ed25519 -N ""
    echo "Add this key to GitHub: https://github.com/settings/keys"
    cat ~/.ssh/id_ed25519.pub
fi

# Step 2: Ensure gh auth
if ! gh auth status &>/dev/null; then
    echo "GitHub CLI not authenticated. Run: gh auth login"
    exit 1
fi

# Step 3: Create repo on GitHub
echo "Creating repo: $REPO_NAME"
gh repo create "$REPO_NAME" --public --description "$DESCRIPTION" 2>/dev/null || echo "Repo may already exist"

# Step 4: Init local
REPO_DIR="$HOME/$REPO_NAME"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"
git init 2>/dev/null || true

# Step 5: .gitignore (CMMI4 enforced)
cat > .gitignore << 'GI'
.env
.env.*
*.key
*.pem
*.credentials*
service-account.json
*.db
node_modules/
__pycache__/
.DS_Store
GI

# Step 6: Wire remote
git remote remove origin 2>/dev/null || true
git remote add origin "git@github.com:$(git config user.name || echo tmdev012)/$REPO_NAME.git"
git add -A
git commit -m "init: $DESCRIPTION" 2>/dev/null || true
git branch -M main
git push -u origin main 2>/dev/null || echo "Push pending (add SSH key first)"

# Step 7: Log to SQLite
python3 -c "
import sqlite3, os
conn = sqlite3.connect('$SASHI_DB')
c = conn.cursor()
c.execute('CREATE TABLE IF NOT EXISTS sync_queue (id INTEGER PRIMARY KEY, repo TEXT, action TEXT, detail TEXT, status TEXT DEFAULT \"pending\", created_at DATETIME DEFAULT CURRENT_TIMESTAMP, synced_at DATETIME)')
c.execute('INSERT INTO sync_queue (repo, action, detail) VALUES (?,?,?)', ('$REPO_NAME', 'create', '$DESCRIPTION'))
conn.commit()
print('Logged to sync_queue')
" 2>/dev/null

echo "DONE: $REPO_NAME created at $REPO_DIR"
