#!/bin/bash
# env-guard.sh - Git pre-commit hook: blocks .env, *.key, creds
# CMMI4: Transactional check before any push
# Install: ln -sf ~/ollama-local/lib/sh/env-guard.sh ~/ollama-local/.git/hooks/pre-commit

BLOCKED_PATTERNS=(.env .env.* *.key *.pem *.credentials* service-account.json *.db)
STAGED=$(git diff --cached --name-only 2>/dev/null)
VIOLATIONS=""

for file in $STAGED; do
    for pattern in "${BLOCKED_PATTERNS[@]}"; do
        case "$file" in
            $pattern) VIOLATIONS="$VIOLATIONS $file" ;;
        esac
    done
done

if [ -n "$VIOLATIONS" ]; then
    echo "ENV-GUARD BLOCKED COMMIT - secrets detected:"
    for v in $VIOLATIONS; do echo "  BLOCKED: $v"; done
    echo ""
    echo "To fix: git reset HEAD $VIOLATIONS"
    echo "These files must stay in .gitignore"
    exit 1
fi
exit 0
