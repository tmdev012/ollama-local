#!/usr/bin/env python3
"""Initialize SQLite database with indexes for SASHI."""
import os
import sqlite3

db_dir = os.environ.get("SASHI_DB_DIR", "/root/ollama-local/db")
os.makedirs(db_dir, exist_ok=True)
db_path = os.path.join(db_dir, "history.db")

conn = sqlite3.connect(db_path)
c = conn.cursor()
c.execute('''CREATE TABLE IF NOT EXISTS queries (
    id INTEGER PRIMARY KEY,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    model TEXT,
    prompt TEXT,
    response_length INTEGER,
    duration_ms INTEGER
)''')
c.execute('''CREATE TABLE IF NOT EXISTS favorites (
    id INTEGER PRIMARY KEY,
    query_id INTEGER,
    label TEXT
)''')
c.execute('CREATE INDEX IF NOT EXISTS idx_queries_model ON queries(model)')
c.execute('CREATE INDEX IF NOT EXISTS idx_queries_timestamp ON queries(timestamp)')
c.execute('CREATE INDEX IF NOT EXISTS idx_queries_duration ON queries(duration_ms)')
c.execute('CREATE INDEX IF NOT EXISTS idx_favorites_query ON favorites(query_id)')
conn.commit()
conn.close()
print(f"Database initialized: {db_path}")
