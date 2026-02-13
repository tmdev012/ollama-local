# SASHI Workflow — the one command to rule them all
# Usage: make [target]

SHELL := /bin/bash
SASHI := ./sashi
DB    := db/history.db

.PHONY: help check test lint clean status push dev all docker

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

all: check lint test ## Full validation pipeline

check: ## Verify ollama + sashi + db are operational
	@echo "=== System Check ==="
	@systemctl is-active ollama >/dev/null 2>&1 \
	  && echo "[OK] ollama running" \
	  || { echo "[FAIL] ollama not running"; exit 1; }
	@curl -sf --connect-timeout 2 http://localhost:11434/api/tags >/dev/null \
	  && echo "[OK] ollama API responding" \
	  || { echo "[FAIL] ollama API down"; exit 1; }
	@test -x $(SASHI) && bash -n $(SASHI) \
	  && echo "[OK] sashi valid + executable" \
	  || { echo "[FAIL] sashi broken"; exit 1; }
	@test -f $(DB) && python3 -c "import sqlite3; sqlite3.connect('$(DB)').execute('SELECT 1')" 2>/dev/null \
	  && echo "[OK] database healthy" \
	  || echo "[WARN] database missing (run: make db-init)"

lint: ## ShellCheck sashi + scripts
	@echo "=== Lint ==="
	@command -v shellcheck >/dev/null 2>&1 \
	  && { shellcheck -x --severity=error sashi scripts/*.sh && echo "[OK] all scripts clean"; } \
	  || echo "[SKIP] shellcheck not installed (apt install shellcheck)"
	@command -v ruff >/dev/null 2>&1 \
	  && ruff check scripts/init-db.py && echo "[OK] python clean" \
	  || echo "[SKIP] ruff not installed"

test: ## Run sashi functional tests
	@echo "=== Tests ==="
	@bash tests/test_sashi.sh

status: ## Full system status
	@echo "── Ollama ──" && ollama list 2>/dev/null || echo "down"
	@echo "── DB ──" && test -f $(DB) \
	  && python3 -c "import sqlite3; c=sqlite3.connect('$(DB)'); print('queries:', c.execute('SELECT count(*) FROM queries').fetchone()[0])" 2>/dev/null \
	  || echo "no db"
	@echo "── Git ──" && git status -sb && git log --oneline -5

dev: lint test ## Quick dev loop

push: all ## Validate everything, then smart-push
	@scripts/smart-push.sh

clean: ## Remove caches
	@rm -rf scripts/__pycache__ .ruff_cache __pycache__
	@echo "Cleaned."

db-init: ## Initialize database
	@python3 scripts/init-db.py && echo "DB ready."

docker: ## Build and run Docker container
	docker compose build && docker compose up -d && echo "Sashi container running."
