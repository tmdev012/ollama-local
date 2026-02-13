#!/bin/bash
# Functional tests for sashi — tests real behavior, not imports
set -uo pipefail

PASS=0 FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SASHI="$ROOT/sashi"
DB="$ROOT/db/history.db"

pass() { ((PASS++)); echo "  [PASS] $1"; }
fail() { ((FAIL++)); echo "  [FAIL] $1"; }

echo "── CLI ──"
test -x "$SASHI"                         && pass "executable" || fail "sashi not executable"
bash -n "$SASHI" 2>/dev/null             && pass "syntax ok"  || fail "sashi syntax error"
grep -q 'VERSION=' "$SASHI"              && pass "has VERSION" || fail "no VERSION"

help_out=$("$SASHI" help 2>&1)
echo "$help_out" | grep -q "Usage"       && pass "help works"     || fail "help broken"
echo "$help_out" | grep -q "ask"         && pass "has ask cmd"    || fail "missing ask"
echo "$help_out" | grep -q "chat"        && pass "has chat cmd"   || fail "missing chat"
echo "$help_out" | grep -q "status"      && pass "has status cmd" || fail "missing status"

echo "── Database ──"
test -f "$DB"                            && pass "db exists"   || fail "db missing"
if test -f "$DB"; then
  python3 -c "import sqlite3; sqlite3.connect('$DB').execute('SELECT 1')" 2>/dev/null \
    && pass "db valid" || fail "db corrupt"
  python3 -c "import sqlite3; c=sqlite3.connect('$DB'); assert any('queries' in t[0] for t in c.execute('SELECT name FROM sqlite_master WHERE type=\"table\"'))" 2>/dev/null \
    && pass "queries table" || fail "no queries table"
fi

echo "── Ollama ──"
systemctl is-active ollama >/dev/null 2>&1     && pass "service up"  || fail "ollama down"
curl -sf --connect-timeout 2 http://localhost:11434/api/tags >/dev/null && pass "API responds" || fail "API down"

echo "── Scripts ──"
for f in "$ROOT"/scripts/*.sh; do
  name=$(basename "$f")
  bash -n "$f" 2>/dev/null && pass "$name syntax" || fail "$name syntax error"
done
python3 -m py_compile "$ROOT/scripts/init-db.py" 2>/dev/null && pass "init-db.py syntax" || fail "init-db.py error"

echo ""
echo "Results: $PASS passed, $FAIL failed (total $((PASS+FAIL)))"
test "$FAIL" -eq 0
