# SASHI FAQ

## How does prompt caching work?
Every prompt is md5-hashed. On query, SQLite checks `prompt_cache` table first.
Hit = 0ms (instant return). Miss = ollama inference (~2.2s) + async cache store.

## Why remove deepseek?
Cloud API costs money ($0.14/M tokens). llama3.2 + SQLite cache = free + faster on repeats.

## How do aliases load?
Single `source ~/ollama-local/lib/sh/aliases/loader.sh` in .bashrc/.zshrc.
Loader sources 5 grouped files: core, ollama, pipe, git, nav.

## How do repos share data?
Symlinks: `persist-memory-probe/db/sashi_history.db -> ollama-local/db/history.db`
Same for kanban-pmo. One SQLite, many consumers.

## What is CMMI Level 4?
Quantitative process management. Every operation is:
- Logged to SQLite (measured)
- Indexed for fast lookup (controlled)
- Auditable via `sashi_db.py cred-audit` (quantified)
- Cached for performance (optimized)

## How does env-guard prevent secret leaks?
Pre-commit hook checks staged files against blocked patterns (.env, *.key, *.pem, *.db).
Blocks commit if any match. Cannot be bypassed without --no-verify.

## How does horizontal scaling work?
All repos symlink to one SQLite DB. Add a new repo:
`ln -sf ~/ollama-local/db/history.db ~/new-repo/db/sashi_history.db`
Instant shared state. WAL mode handles concurrent writes.

## What credentials does lombok auto-resolve?
- SSH: git_push, git_pull, git_clone, remote_exec
- PAT: gh_api, gh_repo_create, gh_issue, gh_pr
- GPG: git_sign, encrypt, verify, ci_cd_sign
Run: `python3 lib/py/sashi_db.py cred-recommend git_push`
