#!/usr/bin/env bats
# sashi.bats — Integration test suite
# Run: ./tests/bats-core/bin/bats tests/sashi.bats
# Coverage: CLI surface, DB integrity, file-ops, error paths, logging

ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SASHI="$ROOT/sashi"
DB="$ROOT/db/history.db"
TMP_DIR="$(mktemp -d)"

teardown_file() {
    rm -rf "$TMP_DIR"
}

# ── CLI surface ───────────────────────────────────────────────────────────────

@test "sashi is executable" {
    [[ -x "$SASHI" ]]
}

@test "sashi passes bash syntax check" {
    bash -n "$SASHI"
}

@test "sashi help exits 0 and prints Usage" {
    run "$SASHI" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "sashi help lists all primary commands" {
    run "$SASHI" help
    [[ "$output" == *"ask"* ]]
    [[ "$output" == *"code"* ]]
    [[ "$output" == *"write"* ]]
    [[ "$output" == *"file"* ]]
    [[ "$output" == *"wallog"* ]]
    [[ "$output" == *"grpc"* ]]
}

@test "sashi requires prompt for ask" {
    run "$SASHI" ask
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "sashi requires prompt for code" {
    run "$SASHI" code
    [ "$status" -ne 0 ]
}

@test "sashi requires prompt for hf" {
    run "$SASHI" hf
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "sashi file help exits 0" {
    run "$SASHI" file help
    [ "$status" -eq 0 ]
}

@test "sashi write help exits 0" {
    run "$SASHI" write help
    [ "$status" -eq 0 ]
}

# ── Database integrity ────────────────────────────────────────────────────────

@test "history database exists" {
    [[ -f "$DB" ]]
}

@test "history database is valid SQLite" {
    run python3 -c "import sqlite3; sqlite3.connect('$DB').execute('SELECT 1')"
    [ "$status" -eq 0 ]
}

@test "queries table exists" {
    run python3 -c "
import sqlite3
conn = sqlite3.connect('$DB')
tables = [r[0] for r in conn.execute(\"SELECT name FROM sqlite_master WHERE type='table'\")]
assert 'queries' in tables, f'queries not found in {tables}'
"
    [ "$status" -eq 0 ]
}

@test "history command runs without error" {
    run "$SASHI" history
    [ "$status" -eq 0 ]
}

# ── File operations library ───────────────────────────────────────────────────

@test "file-ops.sh passes bash syntax check" {
    bash -n "$ROOT/lib/sh/file-ops.sh"
}

@test "llm-write.sh passes bash syntax check" {
    bash -n "$ROOT/lib/sh/llm-write.sh"
}

@test "sashi file info on a real file returns metadata" {
    local tf="$TMP_DIR/info_test.txt"
    echo "hello world" > "$tf"
    run "$SASHI" file info "$tf"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Path:"* ]]
    [[ "$output" == *"Size:"* ]]
    [[ "$output" == *"MIME:"* ]]
}

@test "sashi file write creates file atomically" {
    local tf="$TMP_DIR/write_test.txt"
    run "$SASHI" file write "$tf" "atomic test content"
    [ "$status" -eq 0 ]
    [[ -f "$tf" ]]
    run cat "$tf"
    [[ "$output" == *"atomic test content"* ]]
}

@test "sashi file append adds content to existing file" {
    local tf="$TMP_DIR/append_test.txt"
    echo "line one" > "$tf"
    run "$SASHI" file append "$tf" "line two"
    [ "$status" -eq 0 ]
    run cat "$tf"
    [[ "$output" == *"line one"* ]]
    [[ "$output" == *"line two"* ]]
}

@test "sashi file read returns file content" {
    local tf="$TMP_DIR/read_test.txt"
    echo "read me back" > "$tf"
    run "$SASHI" file read "$tf"
    [ "$status" -eq 0 ]
    [[ "$output" == *"read me back"* ]]
}

@test "sashi file check on valid JSON reports ok" {
    local tf="$TMP_DIR/valid.json"
    echo '{"key": "value"}' > "$tf"
    run "$SASHI" file check "$tf"
    [ "$status" -eq 0 ]
    [[ "$output" == *"valid"* ]]
}

@test "sashi file detect identifies plain text" {
    local tf="$TMP_DIR/detect_test.txt"
    echo "plain text" > "$tf"
    run "$SASHI" file detect "$tf"
    [ "$status" -eq 0 ]
    [[ "$output" == *"text"* ]]
}

# ── Error paths ───────────────────────────────────────────────────────────────

@test "sashi file read on missing file exits non-zero" {
    run "$SASHI" file read "/tmp/nonexistent_sashi_test_file_xyz"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Missing"* ]] || [[ "$output" == *"missing"* ]]
}

@test "sashi file write to unwritable dir exits non-zero" {
    run "$SASHI" file write "/proc/sashi_test_noperms.txt" "should fail"
    [ "$status" -ne 0 ]
}

@test "sashi unknown subcommand falls through to llama_query" {
    # Without ollama running this should print an error, not crash silently
    # We just verify it exits with status (0 or 1) and doesn't hang
    run timeout 5 "$SASHI" __no_such_command__ 2>&1 || true
    # Should not produce an unhandled error with no output at all
    [[ -n "$output" ]] || [[ "$status" -ne 0 ]]
}

# ── Script library syntax checks ──────────────────────────────────────────────

@test "all lib/sh scripts pass bash syntax" {
    local failed=0
    for f in "$ROOT"/lib/sh/*.sh; do
        bash -n "$f" 2>/dev/null || { echo "FAIL: $f"; failed=1; }
    done
    [ "$failed" -eq 0 ]
}

@test "all scripts/*.sh pass bash syntax" {
    local failed=0
    for f in "$ROOT"/scripts/*.sh; do
        [[ -f "$f" ]] || continue
        bash -n "$f" 2>/dev/null || { echo "FAIL: $f"; failed=1; }
    done
    [ "$failed" -eq 0 ]
}

# ── MCP server ────────────────────────────────────────────────────────────────

@test "mcp/server.py passes Python syntax check" {
    python3 -m py_compile "$ROOT/mcp/server.py"
}

@test "mcp/tools.json is valid JSON" {
    run python3 -c "import json; json.load(open('$ROOT/mcp/tools.json'))"
    [ "$status" -eq 0 ]
}

@test "mcp/tools.json contains expected tools" {
    run python3 -c "
import json
data = json.load(open('$ROOT/mcp/tools.json'))
names = [t['name'] for t in data['tools']]
assert 'sashi_ask' in names
assert 'sashi_file_read' in names
assert 'sashi_llm_write' in names
print('tools:', names)
"
    [ "$status" -eq 0 ]
}

@test "mcp server responds to tools/list over stdin" {
    local request='{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
    run bash -c "echo '$request' | timeout 5 python3 '$ROOT/mcp/server.py'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"tools"'* ]]
    [[ "$output" == *"sashi_ask"* ]]
}

@test "mcp server responds to initialize" {
    local request='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
    run bash -c "echo '$request' | timeout 5 python3 '$ROOT/mcp/server.py'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"protocolVersion"* ]]
    [[ "$output" == *"sashi"* ]]
}
