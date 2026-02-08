#!/bin/bash
# GIT ALIASES & PIPELINE | Group: git
# VERBOSE_L3: Two tiers - simple aliases and sqlite-backed functions
alias gs="git status -sb"
alias gd="git diff"
alias gds="git diff --staged"
alias gl="git log --oneline -20"
alias gla="git log --oneline --all --graph -20"
alias ga="git add"
alias gaa="git add -A"
alias gap="git add -p"
alias gc="git commit -m"
alias gca="git commit --amend"
alias gcn="git commit --amend --no-edit"
alias gp="git push"
alias gpf="git push --force-with-lease"
alias gpl="git pull"
alias gplo="git pull origin"
alias gb="git branch"
alias gba="git branch -a"
alias gco="git checkout"
alias gcb="git checkout -b"
alias gm="git merge"
alias gr="git remote -v"
alias gra="git remote add"
alias gf="git fetch --all"
alias gst="git stash"
alias gstp="git stash pop"
alias gstl="git stash list"

gitpush() {
    local msg="${1:-Auto-commit $(date +%Y-%m-%d\ %H:%M)}"
    git add -A && git commit -m "$msg" && git push
}
alias gpp="gitpush"
alias ship="gitpush"
gitship() {
    git status -sb
    read -p "Commit message: " msg
    gitpush "$msg"
}
alias gship="gitship"
alias smartpush='${SASHI_HOME:-$HOME/ollama-local}/scripts/smart-push.sh'
alias sp='smartpush'
alias gpush='smartpush'

git-history() {
    python3 -c "
import sqlite3, os
db = os.path.expanduser('~/ollama-local/db/history.db')
conn = sqlite3.connect(db)
c = conn.cursor()
try:
    c.execute('''SELECT hash, message, version_tag, issue_number, branch,
                        files_changed, lines_added, lines_deleted, categories, timestamp
                 FROM commits ORDER BY id DESC LIMIT 15''')
    rows = c.fetchall()
    if rows:
        print(f\"{'Hash':<9} {'Ver':<8} {'Issue':<6} {'Cat':<12} {'+/-':<10} {'Message':<35}\")
        print('=' * 90)
        for r in rows:
            ver = r[2] or '-'
            issue = f'#{r[3]}' if r[3] else '-'
            cat = (r[8] or 'other')[:10]
            changes = f'+{r[6] or 0}/-{r[7] or 0}'
            msg = (r[1] or '')[:33]
            print(f'{r[0]:<9} {ver:<8} {issue:<6} {cat:<12} {changes:<10} {msg}')
    else:
        print('No commits tracked. Use: smartpush')
except Exception:
    print('Run smartpush first to initialize tracking')
"
}
alias ghist='git-history'
git-issue() {
    local issue="$1"
    [ -z "$issue" ] && { echo "Usage: git-issue <number>"; return 1; }
    python3 -c "
import sqlite3, os
conn = sqlite3.connect(os.path.expanduser('~/ollama-local/db/history.db'))
c = conn.cursor()
c.execute('SELECT hash, message, version_tag, timestamp FROM commits WHERE issue_number=? ORDER BY id DESC', ('$issue',))
for r in c.fetchall():
    print(f'  {r[0]} | {r[2] or \"-\":<8} | {r[1][:40]}')
"
}
alias gissue='git-issue'
git-version() {
    python3 -c "
import sqlite3, os
conn = sqlite3.connect(os.path.expanduser('~/ollama-local/db/history.db'))
c = conn.cursor()
c.execute('SELECT DISTINCT version_tag, hash, message, timestamp FROM commits WHERE version_tag IS NOT NULL ORDER BY id DESC LIMIT 10')
for r in c.fetchall():
    print(f'  {r[0]:<10} {r[1]} | {r[2][:35]}')
"
}
alias gver='git-version'
