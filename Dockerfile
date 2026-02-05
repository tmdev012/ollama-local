# SASHI - Smart AI Shell Interface
# Docker container for portable AI assistant

FROM ubuntu:24.04

LABEL maintainer="tmdev012"
LABEL version="2.0.0"
LABEL description="SASHI MCP AI System with DeepSeek + Ollama"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/root
ENV PATH="/root/ollama-local:/root/.local/bin:${PATH}"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    sqlite3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.ai/install.sh | sh

# Create directory structure
WORKDIR /root/ollama-local
COPY . .

# Make scripts executable
RUN chmod +x sashi \
    && chmod +x mcp/*/tools/* 2>/dev/null || true

# Initialize SQLite database with indexes
RUN python3 << 'PYEOF'
import sqlite3
import os
os.makedirs('/root/ollama-local/db', exist_ok=True)
conn = sqlite3.connect('/root/ollama-local/db/history.db')
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
PYEOF

# Create shell aliases
RUN echo '\n\
# SASHI Aliases\n\
alias s="/root/ollama-local/sashi"\n\
alias sask="/root/ollama-local/sashi ask"\n\
alias scode="/root/ollama-local/sashi code"\n\
alias slocal="/root/ollama-local/sashi local"\n\
alias schat="/root/ollama-local/sashi chat"\n\
alias sstatus="/root/ollama-local/sashi status"\n\
alias ai="/root/ollama-local/sashi"\n\
' >> /root/.bashrc

# Expose Ollama port
EXPOSE 11434

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:11434/api/tags || exit 1

# Default: start Ollama and interactive shell
CMD ["bash", "-c", "ollama serve & sleep 3 && ollama pull llama3.2 && exec bash"]
