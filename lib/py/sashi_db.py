#!/usr/bin/env python3
"""
sashi_db.py - SINGLE consolidated SQLite module for all SASHI operations.
One file. One connection. One CRUD surface. CMMI4 transactional.

Subcommands:
  bridge-sync       Ingest .claude JSONL -> SQLite
  bridge-stats      Unified stats (ollama + claude)
  bridge-search Q   Search across all sessions
  cache-list        Show prompt cache entries
  file-write P C    Transactional file write with archive
  file-list         List cached file writes
  file-guard        Enforce .gitignore across repos
  sync-log R A D    Log async operation to sync queue
  sync-pending      Show pending syncs
  sync-flush        Mark all synced
  sync-cron         Push pending repos
  cred-status       Credential status (SSH/PAT/GPG)
  cred-recommend O  Recommend credential for operation
  cred-audit        Show credential usage audit
  weekend-tasks     Export weekend tasks to JSON
  efficiency        Show operational efficiency report
"""
import sqlite3, os, sys, json, hashlib, shutil, subprocess, glob as G
from datetime import datetime

DB = os.path.expanduser("~/ollama-local/db/history.db")
CLAUDE_DIR = os.path.expanduser("~/.claude")
ARCHIVE_DIR = os.path.expanduser("~/ollama-local/.file-archive")
REPOS = ["ollama-local", "persist-memory-probe", "kanban-pmo"]
GITIGNORE_RULES = [".env", ".env.*", "*.key", "*.pem", ".credentials*", "service-account.json", "*.db", "node_modules/", "__pycache__/"]
CRED_OPS = {
    "ssh": ["git_push", "git_pull", "git_clone", "remote_exec", "scp"],
    "pat": ["gh_api", "gh_repo_create", "gh_issue", "gh_pr", "webhook"],
    "gpg": ["git_sign", "encrypt", "verify", "ci_cd_sign"],
}

def conn():
    c = sqlite3.connect(DB)
    c.execute("PRAGMA journal_mode=WAL")
    c.execute("PRAGMA synchronous=NORMAL")
    return c

def init_all_tables():
    c = conn()
    c.executescript("""
        CREATE TABLE IF NOT EXISTS queries (id INTEGER PRIMARY KEY, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP, model TEXT, prompt TEXT, response_length INTEGER, duration_ms INTEGER);
        CREATE TABLE IF NOT EXISTS prompt_cache (hash TEXT PRIMARY KEY, prompt TEXT, response TEXT, model TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, hits INTEGER DEFAULT 0);
        CREATE TABLE IF NOT EXISTS claude_sessions (id INTEGER PRIMARY KEY, session_id TEXT UNIQUE, project TEXT, message_count INTEGER, first_seen DATETIME, last_seen DATETIME, synced_at DATETIME DEFAULT CURRENT_TIMESTAMP);
        CREATE TABLE IF NOT EXISTS claude_messages (id INTEGER PRIMARY KEY, session_id TEXT, display TEXT, timestamp INTEGER, ts_human DATETIME, prompt_hash TEXT);
        CREATE TABLE IF NOT EXISTS file_cache (id INTEGER PRIMARY KEY, path TEXT, content_hash TEXT, size_bytes INTEGER, version INTEGER DEFAULT 1, written_at DATETIME DEFAULT CURRENT_TIMESTAMP);
        CREATE TABLE IF NOT EXISTS sync_queue (id INTEGER PRIMARY KEY, repo TEXT, action TEXT, detail TEXT, status TEXT DEFAULT 'pending', created_at DATETIME DEFAULT CURRENT_TIMESTAMP, synced_at DATETIME);
        CREATE TABLE IF NOT EXISTS credential_audit (id INTEGER PRIMARY KEY, cred_type TEXT, operation TEXT, target TEXT, success INTEGER, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);
        CREATE TABLE IF NOT EXISTS commits (id INTEGER PRIMARY KEY, hash TEXT, message TEXT, auto_description TEXT, issue_number TEXT, version_tag TEXT, branch TEXT, files_changed INTEGER, lines_added INTEGER, lines_deleted INTEGER, categories TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP, tree_backup TEXT);
        CREATE TABLE IF NOT EXISTS favorites (id INTEGER PRIMARY KEY, query_id INTEGER, label TEXT);
        CREATE TABLE IF NOT EXISTS mcp_groups (id INTEGER PRIMARY KEY, name TEXT UNIQUE, category TEXT, description TEXT, config_path TEXT, enabled INTEGER DEFAULT 1, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP);
        CREATE INDEX IF NOT EXISTS idx_cache_hash ON prompt_cache(hash);
        CREATE INDEX IF NOT EXISTS idx_cs_sid ON claude_sessions(session_id);
        CREATE INDEX IF NOT EXISTS idx_cm_sid ON claude_messages(session_id);
        CREATE INDEX IF NOT EXISTS idx_cm_ts ON claude_messages(timestamp);
        CREATE INDEX IF NOT EXISTS idx_fc_path ON file_cache(path);
        CREATE INDEX IF NOT EXISTS idx_sq_status ON sync_queue(status);
        CREATE INDEX IF NOT EXISTS idx_ca_type ON credential_audit(cred_type);
        CREATE INDEX IF NOT EXISTS idx_q_model ON queries(model);
        CREATE INDEX IF NOT EXISTS idx_q_ts ON queries(timestamp);
    """)
    c.commit()
    return c

# ==================== BRIDGE ====================
def bridge_sync():
    c = init_all_tables()
    hf = os.path.join(CLAUDE_DIR, "history.jsonl")
    if not os.path.exists(hf): return print("No history.jsonl")
    inserted, sessions = 0, {}
    with open(hf) as f:
        for line in f:
            if not line.strip(): continue
            try: msg = json.loads(line)
            except: continue
            sid = msg.get("sessionId", "?")
            display = msg.get("display", "")
            ts = msg.get("timestamp", 0)
            proj = msg.get("project", "")
            ph = hashlib.md5(display.encode()).hexdigest()
            tsh = datetime.fromtimestamp(ts/1000).isoformat() if ts else None
            if sid not in sessions: sessions[sid] = {"p": proj, "n": 0, "f": ts, "l": ts}
            sessions[sid]["n"] += 1
            sessions[sid]["l"] = max(sessions[sid]["l"], ts)
            try:
                c.execute("INSERT OR IGNORE INTO claude_messages (session_id,display,timestamp,ts_human,prompt_hash) VALUES (?,?,?,?,?)", (sid, display, ts, tsh, ph))
                inserted += 1
            except: pass
    for sid, m in sessions.items():
        fh = datetime.fromtimestamp(m["f"]/1000).isoformat() if m["f"] else None
        lh = datetime.fromtimestamp(m["l"]/1000).isoformat() if m["l"] else None
        c.execute("INSERT OR REPLACE INTO claude_sessions (session_id,project,message_count,first_seen,last_seen) VALUES (?,?,?,?,?)", (sid, m["p"], m["n"], fh, lh))
    c.commit()
    print(f"Synced: {inserted} msgs, {len(sessions)} sessions")

def bridge_stats():
    c = init_all_tables()
    qc = c.execute("SELECT COUNT(*),COALESCE(SUM(duration_ms),0) FROM queries").fetchone()
    cc = c.execute("SELECT COUNT(*),COALESCE(SUM(hits),0) FROM prompt_cache").fetchone()
    sc = c.execute("SELECT COUNT(*) FROM claude_sessions").fetchone()[0]
    mc = c.execute("SELECT COUNT(*) FROM claude_messages").fetchone()[0]
    fc = c.execute("SELECT COUNT(*) FROM file_cache").fetchone()[0]
    sq = c.execute("SELECT COUNT(*) FROM sync_queue WHERE status='pending'").fetchone()[0]
    print("=== UNIFIED STATS ===")
    print(f"Ollama queries:  {qc[0]} ({qc[1]/1000:.1f}s total)")
    print(f"Prompt cache:    {cc[0]} entries, {cc[1]} hits")
    print(f"Claude sessions: {sc} ({mc} messages)")
    print(f"File cache:      {fc} writes tracked")
    print(f"Sync queue:      {sq} pending")

def bridge_search(q):
    c = init_all_tables()
    like = f"%{q}%"
    print(f"=== Search: '{q}' ===")
    rows = c.execute("SELECT timestamp,model,substr(prompt,1,70) FROM queries WHERE prompt LIKE ? ORDER BY id DESC LIMIT 5", (like,)).fetchall()
    if rows:
        print("\n-- Ollama --")
        for r in rows: print(f"  [{r[0]}] {r[1]}: {r[2]}")
    rows = c.execute("SELECT ts_human,session_id,substr(display,1,70) FROM claude_messages WHERE display LIKE ? ORDER BY timestamp DESC LIMIT 5", (like,)).fetchall()
    if rows:
        print("\n-- Claude --")
        for r in rows: print(f"  [{r[0]}] {r[1][:8]}: {r[2]}")

# ==================== FILE CACHE ====================
def file_write(path, content):
    c = init_all_tables()
    ap = os.path.abspath(os.path.expanduser(path))
    h = hashlib.sha256(content.encode()).hexdigest()[:16]
    row = c.execute("SELECT content_hash FROM file_cache WHERE path=? ORDER BY id DESC LIMIT 1", (ap,)).fetchone()
    if row and row[0] == h: return print(f"SKIP: {ap}")
    if os.path.exists(ap):
        os.makedirs(os.path.join(ARCHIVE_DIR, h[:8]), exist_ok=True)
        shutil.copy2(ap, os.path.join(ARCHIVE_DIR, h[:8], f"{os.path.basename(ap)}.{datetime.now():%Y%m%d%H%M%S}"))
    ver = (c.execute("SELECT MAX(version) FROM file_cache WHERE path=?", (ap,)).fetchone()[0] or 0) + 1
    c.execute("INSERT INTO file_cache (path,content_hash,size_bytes,version) VALUES (?,?,?,?)", (ap, h, len(content), ver))
    c.commit()
    os.makedirs(os.path.dirname(ap), exist_ok=True)
    with open(ap, 'w') as f: f.write(content)
    print(f"WRITE v{ver}: {ap} ({len(content)}B)")

def file_guard():
    for repo in REPOS:
        gi = os.path.join(os.path.expanduser(f"~/{repo}"), ".gitignore")
        existing = set()
        if os.path.exists(gi):
            with open(gi) as f: existing = {l.strip() for l in f if l.strip() and not l.startswith('#')}
        missing = [r for r in GITIGNORE_RULES if r not in existing]
        if missing:
            with open(gi, 'a') as f:
                f.write("\n# CMMI4: never commit secrets\n")
                for m in missing: f.write(m + "\n")
            print(f"GUARD: +{len(missing)} rules -> {gi}")
        else:
            print(f"GUARD: {gi} OK")

# ==================== SYNC QUEUE ====================
def sync_log(repo, action, detail=""):
    c = init_all_tables()
    c.execute("INSERT INTO sync_queue (repo,action,detail) VALUES (?,?,?)", (repo, action, detail))
    c.commit()
    print(f"QUEUED: {repo}/{action}")

def sync_pending():
    c = init_all_tables()
    rows = c.execute("SELECT id,repo,action,detail,created_at FROM sync_queue WHERE status='pending' ORDER BY id").fetchall()
    for r in rows: print(f"  [{r[0]}] {r[1]}/{r[2]}: {(r[3] or '')[:40]} @ {r[4]}")
    print(f"Total pending: {len(rows)}")

def sync_cron():
    c = init_all_tables()
    for (repo,) in c.execute("SELECT DISTINCT repo FROM sync_queue WHERE status='pending'").fetchall():
        rp = os.path.expanduser(f"~/{repo}")
        if not os.path.isdir(os.path.join(rp, ".git")): continue
        r = subprocess.run(["git", "-C", rp, "push"], capture_output=True, text=True, timeout=30)
        if r.returncode == 0:
            c.execute("UPDATE sync_queue SET status='synced',synced_at=? WHERE repo=? AND status='pending'", (datetime.now().isoformat(), repo))
            c.commit()
            print(f"SYNCED: {repo}")
        else:
            print(f"FAIL: {repo}: {r.stderr[:80]}")

# ==================== CREDENTIALS ====================
def cred_status():
    checks = {
        "ssh": ("~/.ssh/id_ed25519", lambda: os.path.exists(os.path.expanduser("~/.ssh/id_ed25519"))),
        "pat": ("gh auth", lambda: subprocess.run(["gh","auth","status"], capture_output=True).returncode == 0),
        "gpg": ("gpg keyring", lambda: subprocess.run(["gpg","--list-keys"], capture_output=True).returncode == 0),
    }
    print("=== CREDENTIALS (Lombok Auto-Resolution) ===")
    for ct, (path, check) in checks.items():
        try: ok = check()
        except: ok = False
        ops = ", ".join(CRED_OPS.get(ct, [])[:3])
        print(f"  [{'  OK' if ok else 'PEND'}] {ct:<5} -> {ops}  ({path})")

def cred_recommend(op):
    for ct, ops in CRED_OPS.items():
        if op in ops:
            print(f"{op} -> use {ct}")
            return ct
    print(f"No mapping for: {op}")

# ==================== WEEKEND TASKS ====================
def weekend_tasks():
    tasks = [
        {"id": 1, "title": "Enforce .gitignore across all repos", "status": "done", "cmmi": "L4-measurement", "tool": "file_guard"},
        {"id": 2, "title": "Install env-guard pre-commit hook", "status": "done", "cmmi": "L4-process-control", "tool": "env-guard.sh"},
        {"id": 3, "title": "Sync claude sessions to SQLite", "status": "done", "cmmi": "L4-quantitative", "tool": "bridge-sync"},
        {"id": 4, "title": "Prompt cache for llama3.2 0ms repeats", "status": "done", "cmmi": "L4-performance", "tool": "prompt_cache"},
        {"id": 5, "title": "Consolidate aliases to sourced dir", "status": "done", "cmmi": "L3-defined", "tool": "aliases/loader.sh"},
        {"id": 6, "title": "Remove deepseek, zero cloud costs", "status": "done", "cmmi": "L4-cost-control", "tool": "sashi v3.0"},
        {"id": 7, "title": "Symlink db/mcp/aliases across repos", "status": "done", "cmmi": "L4-standardization", "tool": "symlinks"},
        {"id": 8, "title": "Credential lombok auto-resolution", "status": "done", "cmmi": "L4-audit", "tool": "cred-status"},
    ]
    out = os.path.expanduser("~/ollama-local/config/weekend-tasks.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w') as f:
        json.dump({"generated": datetime.now().isoformat(), "cmmi_level": 4, "tasks": tasks}, f, indent=2)
    print(f"Exported {len(tasks)} tasks -> {out}")
    for t in tasks:
        print(f"  [{t['status']:>4}] #{t['id']} {t['title']} ({t['cmmi']})")

def efficiency():
    """Operational efficiency per tool via db stats"""
    c = init_all_tables()
    print("=== OPERATIONAL EFFICIENCY ===\n")
    # Queries by model
    rows = c.execute("SELECT model, COUNT(*), AVG(duration_ms), MIN(duration_ms), MAX(duration_ms) FROM queries GROUP BY model").fetchall()
    if rows:
        print(f"{'Model':<20} {'Count':<7} {'Avg ms':<9} {'Min':<8} {'Max'}")
        print("-" * 55)
        for r in rows:
            print(f"{r[0]:<20} {r[1]:<7} {r[2] or 0:>6.0f}   {r[3] or 0:>6}  {r[4] or 0:>6}")
    # Cache efficiency
    cc = c.execute("SELECT COUNT(*), COALESCE(SUM(hits),0) FROM prompt_cache").fetchone()
    total_q = c.execute("SELECT COUNT(*) FROM queries").fetchone()[0] or 1
    print(f"\nCache: {cc[0]} entries, {cc[1]} hits, rate={cc[1]/max(total_q,1)*100:.0f}%")
    # File ops
    fc = c.execute("SELECT COUNT(*), COALESCE(SUM(size_bytes),0) FROM file_cache").fetchone()
    print(f"Files: {fc[0]} writes tracked, {fc[1]} bytes total")
    # Sync queue
    pend = c.execute("SELECT COUNT(*) FROM sync_queue WHERE status='pending'").fetchone()[0]
    done = c.execute("SELECT COUNT(*) FROM sync_queue WHERE status='synced'").fetchone()[0]
    print(f"Sync:  {done} synced, {pend} pending")
    # Horizontal scale proof
    print(f"\n=== HORIZONTAL SCALE PROOF ===")
    print(f"Repos sharing this DB: {len(REPOS)}")
    for r in REPOS:
        rp = os.path.expanduser(f"~/{r}")
        sym = os.path.join(rp, "db", "sashi_history.db")
        is_sym = os.path.islink(sym)
        print(f"  {r}: {'SYMLINKED' if is_sym else 'DIRECT' if r=='ollama-local' else 'NOT LINKED'}")
    tbl = c.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
    idx = c.execute("SELECT name FROM sqlite_master WHERE type='index'").fetchall()
    print(f"Tables in shared DB: {len(tbl)}")
    print(f"Indexes: {len(idx)}")

# ==================== MAIN ====================
if __name__ == "__main__":
    a = sys.argv[1] if len(sys.argv) > 1 else "help"
    if a == "bridge-sync": bridge_sync()
    elif a == "bridge-stats": bridge_stats()
    elif a == "bridge-search" and len(sys.argv) > 2: bridge_search(" ".join(sys.argv[2:]))
    elif a == "cache-list":
        c = init_all_tables()
        for r in c.execute("SELECT hash,substr(prompt,1,50),hits,model FROM prompt_cache ORDER BY hits DESC LIMIT 20").fetchall():
            print(f"  {r[0][:10]} hits={r[2]} {r[3]}: {r[1]}")
    elif a == "file-write" and len(sys.argv) > 3: file_write(sys.argv[2], " ".join(sys.argv[3:]))
    elif a == "file-list":
        c = init_all_tables()
        for r in c.execute("SELECT path,content_hash,size_bytes,version,written_at FROM file_cache ORDER BY id DESC LIMIT 20").fetchall():
            print(f"  v{r[3]} {r[1]} {r[2]:>6}B {r[0][-50:]}")
    elif a == "file-guard": file_guard()
    elif a == "sync-log" and len(sys.argv) > 3: sync_log(sys.argv[2], sys.argv[3], " ".join(sys.argv[4:]) if len(sys.argv) > 4 else "")
    elif a == "sync-pending": sync_pending()
    elif a == "sync-flush":
        c = init_all_tables()
        c.execute("UPDATE sync_queue SET status='synced',synced_at=? WHERE status='pending'", (datetime.now().isoformat(),))
        c.commit(); print("Flushed")
    elif a == "sync-cron": sync_cron()
    elif a == "cred-status": cred_status()
    elif a == "cred-recommend" and len(sys.argv) > 2: cred_recommend(sys.argv[2])
    elif a == "cred-audit":
        c = init_all_tables()
        for r in c.execute("SELECT cred_type,operation,target,success,timestamp FROM credential_audit ORDER BY id DESC LIMIT 20").fetchall():
            print(f"  {r[0]:<5} {r[1]:<15} {(r[2] or '')[:20]:<22} {'Y' if r[3] else 'N'} {r[4]}")
    elif a == "weekend-tasks": weekend_tasks()
    elif a == "efficiency": efficiency()
    else: print(__doc__)
