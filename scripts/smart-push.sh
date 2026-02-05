#!/bin/bash
# Smart Push v2.0 - Intelligent Git Commit & Track
# Features: Auto-categorize, diff analysis, version tags, issue linking

set -e

# Config
REPO_DIR="$HOME/ollama-local"
DB_PATH="$REPO_DIR/db/history.db"
BACKUP_DIR="$REPO_DIR/backups"
TREE_FILE="$BACKUP_DIR/tree_$(date +%Y%m%d_%H%M%S).txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

cd "$REPO_DIR"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           SMART PUSH v2.0 - Intelligent Git Commit               ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# HELPER: Categorize file by extension
# ============================================
categorize_file() {
    local file="$1"
    local ext="${file##*.}"
    local dir=$(dirname "$file")

    case "$ext" in
        html|htm|css|scss|sass|less)
            echo "frontend:styles" ;;
        js|jsx|ts|tsx|vue|svelte)
            echo "frontend:script" ;;
        json|yaml|yml|toml|ini|conf|cfg|env)
            echo "config" ;;
        py|pyw)
            echo "backend:python" ;;
        sh|bash|zsh|fish)
            echo "scripts:shell" ;;
        sql|db|sqlite)
            echo "database" ;;
        md|txt|rst|doc)
            echo "docs" ;;
        Dockerfile|docker-compose*)
            echo "devops:docker" ;;
        test*|*_test.*|*spec.*)
            echo "testing" ;;
        jpg|jpeg|png|gif|svg|ico|webp)
            echo "assets:images" ;;
        mp3|wav|ogg|mp4|webm)
            echo "assets:media" ;;
        *)
            # Check directory patterns
            case "$dir" in
                *test*|*spec*) echo "testing" ;;
                *config*|*conf*) echo "config" ;;
                *doc*|*docs*) echo "docs" ;;
                *script*) echo "scripts" ;;
                *mcp*) echo "mcp:module" ;;
                *) echo "other" ;;
            esac
            ;;
    esac
}

# ============================================
# HELPER: Analyze diff and generate description
# ============================================
analyze_changes() {
    local categories=()
    local descriptions=()
    local files_by_category=""

    # Get all changed files
    local changed_files=$(git diff --cached --name-only 2>/dev/null)
    [ -z "$changed_files" ] && changed_files=$(git diff --name-only 2>/dev/null)
    [ -z "$changed_files" ] && changed_files=$(git ls-files --others --exclude-standard 2>/dev/null)

    # Categorize each file
    declare -A cat_files
    declare -A cat_counts

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        local cat=$(categorize_file "$file")
        cat_files[$cat]+="$file\n"
        ((cat_counts[$cat]++)) || cat_counts[$cat]=1
    done <<< "$changed_files"

    # Build description
    local desc=""
    local primary_cat=""
    local max_count=0

    for cat in "${!cat_counts[@]}"; do
        if [ "${cat_counts[$cat]}" -gt "$max_count" ]; then
            max_count="${cat_counts[$cat]}"
            primary_cat="$cat"
        fi
    done

    # Generate smart description based on categories
    case "$primary_cat" in
        frontend:*)
            desc="Frontend updates" ;;
        backend:*)
            desc="Backend changes" ;;
        config)
            desc="Configuration updates" ;;
        scripts:*)
            desc="Script improvements" ;;
        database)
            desc="Database schema changes" ;;
        docs)
            desc="Documentation updates" ;;
        devops:*)
            desc="DevOps/Infrastructure changes" ;;
        testing)
            desc="Test updates" ;;
        mcp:*)
            desc="MCP module updates" ;;
        *)
            desc="General updates" ;;
    esac

    # Add secondary categories
    local secondary=""
    for cat in "${!cat_counts[@]}"; do
        [ "$cat" = "$primary_cat" ] && continue
        local short_cat="${cat%%:*}"
        secondary+="${short_cat}, "
    done
    secondary="${secondary%, }"

    [ -n "$secondary" ] && desc="$desc + $secondary"

    echo "$desc"
}

# ============================================
# 1. TIMESTAMP & BRANCH INFO
# ============================================
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
BRANCH=$(git branch --show-current)
MAIN_BRANCH="main"

echo -e "${CYAN}Timestamp:${NC}  $TIMESTAMP"
echo -e "${CYAN}Branch:${NC}     $BRANCH"
echo ""

# ============================================
# 2. BRANCH COMPARISON (vs main)
# ============================================
echo -e "${YELLOW}[1/8]${NC} Branch comparison (${BRANCH} vs ${MAIN_BRANCH}):"
echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"

if [ "$BRANCH" != "$MAIN_BRANCH" ]; then
    AHEAD=$(git rev-list --count ${MAIN_BRANCH}..${BRANCH} 2>/dev/null || echo "0")
    BEHIND=$(git rev-list --count ${BRANCH}..${MAIN_BRANCH} 2>/dev/null || echo "0")
    echo -e "  Ahead of $MAIN_BRANCH:  ${GREEN}$AHEAD commits${NC}"
    echo -e "  Behind $MAIN_BRANCH:    ${YELLOW}$BEHIND commits${NC}"

    if [ "$BEHIND" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠ Consider: git merge $MAIN_BRANCH${NC}"
    fi
else
    echo -e "  ${GREEN}✓ On main branch${NC}"
fi
echo ""

# ============================================
# 3. BACKUP FILE TREE
# ============================================
mkdir -p "$BACKUP_DIR"
echo -e "${YELLOW}[2/8]${NC} Creating file tree backup..."
tree -I '.git|__pycache__|*.pyc|node_modules|backups' > "$TREE_FILE" 2>/dev/null || find . -type f ! -path "./.git/*" ! -path "./backups/*" > "$TREE_FILE"
echo -e "  ${GREEN}✓${NC} $TREE_FILE"
ls -t "$BACKUP_DIR"/tree_*.txt 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
echo ""

# ============================================
# 4. FILE CHANGES BY CATEGORY
# ============================================
echo -e "${YELLOW}[3/8]${NC} File changes by category:"
echo -e "${CYAN}─────────────────────────────────────────────────────────────────${NC}"

# Stage all first to analyze
git add -A 2>/dev/null

declare -A categories
declare -A file_details

while IFS=$'\t' read -r status file; do
    [ -z "$file" ] && continue
    cat=$(categorize_file "$file")
    categories[$cat]+="$status|$file\n"

    # Get diff stats for this file
    adds=$(git diff --cached --numstat "$file" 2>/dev/null | awk '{print $1}' || echo "0")
    dels=$(git diff --cached --numstat "$file" 2>/dev/null | awk '{print $2}' || echo "0")
    file_details[$file]="$status|$adds|$dels"
done < <(git diff --cached --name-status 2>/dev/null)

# Also check untracked
while IFS= read -r file; do
    [ -z "$file" ] && continue
    cat=$(categorize_file "$file")
    categories[$cat]+="A|$file\n"
    file_details[$file]="A|?|?"
done < <(git ls-files --others --exclude-standard 2>/dev/null)

# Display by category
for cat in $(echo "${!categories[@]}" | tr ' ' '\n' | sort); do
    echo -e "\n  ${MAGENTA}[$cat]${NC}"
    echo -e "${categories[$cat]}" | while IFS='|' read -r status file; do
        [ -z "$file" ] && continue
        case $status in
            A) icon="${GREEN}+${NC}" ;;
            M) icon="${YELLOW}~${NC}" ;;
            D) icon="${RED}-${NC}" ;;
            R) icon="${CYAN}→${NC}" ;;
            *) icon="$status" ;;
        esac
        # Get line changes
        info="${file_details[$file]}"
        adds=$(echo "$info" | cut -d'|' -f2)
        dels=$(echo "$info" | cut -d'|' -f3)

        printf "    ${icon} %-45s " "$file"
        [ "$adds" != "?" ] && printf "${GREEN}+%s${NC} " "$adds"
        [ "$dels" != "?" ] && [ "$dels" != "0" ] && printf "${RED}-%s${NC}" "$dels"
        echo ""
    done
done

echo -e "\n${CYAN}─────────────────────────────────────────────────────────────────${NC}"
echo ""

# ============================================
# 5. GIT DIFF SUMMARY
# ============================================
echo -e "${YELLOW}[4/8]${NC} Diff summary:"
DIFF_STAT=$(git diff --cached --stat 2>/dev/null | tail -1)
echo -e "  $DIFF_STAT"

TOTAL_ADDS=$(git diff --cached --numstat 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
TOTAL_DELS=$(git diff --cached --numstat 2>/dev/null | awk '{sum+=$2} END {print sum+0}')
FILES_CHANGED=$(git diff --cached --name-only 2>/dev/null | wc -l)

echo -e "  Total: ${GREEN}+$TOTAL_ADDS${NC} / ${RED}-$TOTAL_DELS${NC} in $FILES_CHANGED files"
echo ""

# ============================================
# 6. AUTO-GENERATE DESCRIPTION
# ============================================
echo -e "${YELLOW}[5/8]${NC} Auto-generated description:"
AUTO_DESC=$(analyze_changes)
echo -e "  ${CYAN}Suggested:${NC} $AUTO_DESC"
echo ""

# ============================================
# 7. VERSION & ISSUE INPUT
# ============================================
echo -e "${YELLOW}[6/8]${NC} Commit details:"

# Get current version tag
CURRENT_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo -e "  Current version: ${CYAN}$CURRENT_TAG${NC}"

# Parse version
IFS='.' read -r major minor patch <<< "${CURRENT_TAG#v}"
patch=$((patch + 1))
SUGGESTED_TAG="v${major}.${minor}.${patch}"

# Ask for version tag
read -p "  Version tag (Enter for $SUGGESTED_TAG, 'skip' to skip): " VERSION_TAG
[ -z "$VERSION_TAG" ] && VERSION_TAG="$SUGGESTED_TAG"
[ "$VERSION_TAG" = "skip" ] && VERSION_TAG=""

# Ask for issue number
read -p "  Issue number (optional, Enter to skip): #" ISSUE_NUM

# Ask for commit message (with auto-suggestion)
echo -e "  ${CYAN}Auto-suggested:${NC} $AUTO_DESC"
read -p "  Commit message (Enter for auto): " COMMIT_MSG
[ -z "$COMMIT_MSG" ] && COMMIT_MSG="$AUTO_DESC"

# Build full message
FULL_MSG="$COMMIT_MSG"
[ -n "$ISSUE_NUM" ] && FULL_MSG="$FULL_MSG

Fixes #$ISSUE_NUM"
[ -n "$VERSION_TAG" ] && FULL_MSG="$FULL_MSG

Release: $VERSION_TAG"

FULL_MSG="$FULL_MSG

Changes:
$(git diff --cached --stat 2>/dev/null | head -20)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"

echo ""

# ============================================
# 8. COMMIT & PUSH
# ============================================
echo -e "${YELLOW}[7/8]${NC} Committing..."

COMMIT_HASH=$(git commit -m "$FULL_MSG" 2>&1 | grep -oP '^\[\w+ \K[a-f0-9]+' || echo "")

if [ -z "$COMMIT_HASH" ]; then
    COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "none")
fi

echo -e "  ${GREEN}✓${NC} Commit: $COMMIT_HASH"

# Create version tag if specified
if [ -n "$VERSION_TAG" ] && [ "$VERSION_TAG" != "skip" ]; then
    git tag -a "$VERSION_TAG" -m "Release $VERSION_TAG: $COMMIT_MSG" 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} Tagged: $VERSION_TAG" || \
        echo -e "  ${YELLOW}⚠${NC} Tag already exists or failed"
fi

echo -e "${YELLOW}[8/8]${NC} Pushing..."
git push origin "$BRANCH" 2>&1 | head -3
[ -n "$VERSION_TAG" ] && git push origin "$VERSION_TAG" 2>/dev/null

echo ""

# ============================================
# STORE IN SQLITE
# ============================================
python3 << PYEOF
import sqlite3
import os
from datetime import datetime

db_path = os.path.expanduser('$DB_PATH')
conn = sqlite3.connect(db_path)
c = conn.cursor()

# Create/update commits table
c.execute('''CREATE TABLE IF NOT EXISTS commits (
    id INTEGER PRIMARY KEY,
    hash TEXT,
    message TEXT,
    auto_description TEXT,
    issue_number TEXT,
    version_tag TEXT,
    branch TEXT,
    files_changed INTEGER,
    lines_added INTEGER,
    lines_deleted INTEGER,
    categories TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    tree_backup TEXT
)''')

c.execute('CREATE INDEX IF NOT EXISTS idx_commits_hash ON commits(hash)')
c.execute('CREATE INDEX IF NOT EXISTS idx_commits_version ON commits(version_tag)')
c.execute('CREATE INDEX IF NOT EXISTS idx_commits_issue ON commits(issue_number)')

# Get categories as string
categories = ','.join(sorted(set([cat.split(':')[0] for cat in '''${!categories[@]}'''.split()])))

c.execute('''INSERT INTO commits
    (hash, message, auto_description, issue_number, version_tag, branch, files_changed, lines_added, lines_deleted, categories, tree_backup)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
    ('$COMMIT_HASH', '''$COMMIT_MSG''', '''$AUTO_DESC''', '$ISSUE_NUM' or None, '$VERSION_TAG' or None,
     '$BRANCH', $FILES_CHANGED, $TOTAL_ADDS, $TOTAL_DELS, categories, '$TREE_FILE'))

conn.commit()
conn.close()
PYEOF

# ============================================
# SUMMARY
# ============================================
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                          SUMMARY                                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Commit:${NC}      $COMMIT_HASH"
echo -e "  ${BOLD}Message:${NC}     $COMMIT_MSG"
echo -e "  ${BOLD}Auto-desc:${NC}   $AUTO_DESC"
[ -n "$ISSUE_NUM" ] && echo -e "  ${BOLD}Issue:${NC}       #$ISSUE_NUM → https://github.com/tmdev012/ollama-local/issues/$ISSUE_NUM"
[ -n "$VERSION_TAG" ] && echo -e "  ${BOLD}Version:${NC}    $VERSION_TAG"
echo -e "  ${BOLD}Branch:${NC}      $BRANCH"
echo -e "  ${BOLD}Changes:${NC}     ${GREEN}+$TOTAL_ADDS${NC} / ${RED}-$TOTAL_DELS${NC} in $FILES_CHANGED files"
echo ""

echo -e "${YELLOW}Quick Commands:${NC}"
echo ""
echo -e "  ${GREEN}View commit:${NC}"
echo -e "    git show $COMMIT_HASH"
echo ""
[ -n "$VERSION_TAG" ] && echo -e "  ${CYAN}Checkout version:${NC}
    git checkout $VERSION_TAG
"
echo -e "  ${YELLOW}Revert this commit:${NC}"
echo -e "    git revert $COMMIT_HASH"
echo ""
echo -e "  ${RED}Undo commit (keep changes):${NC}"
echo -e "    git reset --soft HEAD~1"
echo ""
[ -n "$VERSION_TAG" ] && echo -e "  ${RED}Delete tag:${NC}
    git tag -d $VERSION_TAG && git push origin :refs/tags/$VERSION_TAG
"
echo -e "  ${CYAN}View history:${NC}"
echo -e "    ghist"
echo ""

echo -e "${GREEN}✓ Done!${NC} https://github.com/tmdev012/ollama-local/commit/$COMMIT_HASH"
