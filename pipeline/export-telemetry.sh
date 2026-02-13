#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DB="${SASHI_DB:-$REPO_DIR/db/history.db}"
OUT="${1:-$HOME/portfolio-dashboard/public/telemetry.json}"
python3 - "$DB" "$OUT" << 'PYEOF'
import sqlite3, json, os, socket, sys
from datetime import datetime
db_path, out_path = sys.argv[1], sys.argv[2]
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
try:
    s = socket.create_connection(('127.0.0.1', 11434), timeout=2); s.close(); ollama_up = True
except Exception: ollama_up = False
try:
    s = socket.create_connection(('127.0.0.1', 50051), timeout=2); s.close(); grpc_up = True
except Exception: grpc_up = False
queries = conn.execute("SELECT id, timestamp, model, prompt, response_length, duration_ms FROM queries ORDER BY timestamp DESC LIMIT 20").fetchall()
total_queries = conn.execute("SELECT COUNT(*) FROM queries").fetchone()[0]
avg_duration = conn.execute("SELECT COALESCE(AVG(duration_ms),0) FROM queries").fetchone()[0]
total_rb = conn.execute("SELECT COALESCE(SUM(response_length),0) FROM queries").fetchone()[0]
cache_entries = conn.execute("SELECT COUNT(*) FROM prompt_cache").fetchone()[0]
cache_hits = conn.execute("SELECT COALESCE(SUM(hits),0) FROM prompt_cache").fetchone()[0]
models = conn.execute("SELECT model, COUNT(*) as count, AVG(duration_ms) as avg_ms FROM queries GROUP BY model ORDER BY count DESC").fetchall()
idx_count = conn.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='index'").fetchone()[0]
tbl_count = conn.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table'").fetchone()[0]
commits = conn.execute("SELECT hash, message, branch, files_changed, lines_added, lines_deleted, categories, timestamp FROM commits ORDER BY timestamp DESC LIMIT 10").fetchall()
sessions = conn.execute("SELECT session_id, project, message_count, first_seen, last_seen FROM claude_sessions ORDER BY last_seen DESC LIMIT 5").fetchall()
total_cm = conn.execute("SELECT COUNT(*) FROM claude_messages").fetchone()[0]
mcps = conn.execute("SELECT name, category, description, enabled FROM mcp_groups ORDER BY name").fetchall()
buckets = conn.execute("SELECT CASE WHEN duration_ms < 1000 THEN '<1s' WHEN duration_ms < 3000 THEN '1-3s' WHEN duration_ms < 5000 THEN '3-5s' WHEN duration_ms < 10000 THEN '5-10s' ELSE '>10s' END as bucket, COUNT(*) as count FROM queries GROUP BY bucket ORDER BY MIN(duration_ms)").fetchall()
data = {
    "exported_at": datetime.utcnow().isoformat() + "Z",
    "system": {"ollama": "up" if ollama_up else "down", "grpc_pipeline": "up" if grpc_up else "down", "db_tables": tbl_count, "db_indexes": idx_count},
    "inference": {"total_queries": total_queries, "avg_duration_ms": round(avg_duration, 1), "total_response_bytes": total_rb, "cache_entries": cache_entries, "cache_hits": cache_hits, "cache_hit_rate": round(cache_hits / max(total_queries, 1) * 100, 1)},
    "models": [{"name": m["model"], "queries": m["count"], "avg_ms": round(m["avg_ms"], 1)} for m in models],
    "duration_histogram": [{"bucket": b["bucket"], "count": b["count"]} for b in buckets],
    "recent_queries": [{"id": q["id"], "timestamp": q["timestamp"], "model": q["model"], "prompt": (q["prompt"] or "")[:80], "response_bytes": q["response_length"], "duration_ms": q["duration_ms"]} for q in queries],
    "recent_commits": [{"hash": (c["hash"] or "")[:7], "message": (c["message"] or "")[:80], "branch": c["branch"], "files_changed": c["files_changed"], "lines_added": c["lines_added"], "lines_deleted": c["lines_deleted"], "timestamp": c["timestamp"]} for c in commits],
    "claude_sessions": {"total_messages": total_cm, "recent": [{"project": s["project"], "messages": s["message_count"], "last_seen": s["last_seen"]} for s in sessions]},
    "mcp_tools": [{"name": m["name"], "category": m["category"], "enabled": bool(m["enabled"])} for m in mcps],
}
os.makedirs(os.path.dirname(out_path), exist_ok=True)
with open(out_path, 'w') as f:
    json.dump(data, f, indent=2)
print(f"Exported to {out_path} ({len(json.dumps(data))} bytes)")
PYEOF
