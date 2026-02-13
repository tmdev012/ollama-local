# SASHI - Smart AI Shell Interface
# Docker container for portable AI assistant

FROM ubuntu:24.04

LABEL maintainer="tmdev012"
LABEL version="3.0.0"
LABEL description="SASHI MCP AI System with Ollama"

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/root
ENV PATH="/root/ollama-local:/root/.local/bin:${PATH}"

# Ollama tuning for CPU-only hardware
ENV OLLAMA_NUM_PARALLEL=1
ENV OLLAMA_MAX_LOADED_MODELS=1
ENV OLLAMA_KEEP_ALIVE=30m

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    sqlite3 \
    ca-certificates \
    zstd \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.ai/install.sh | sh

# Create directory structure
WORKDIR /root/ollama-local
COPY . .

# Make scripts executable
RUN chmod +x sashi scripts/*.py scripts/*.sh 2>/dev/null || true \
    && chmod +x mcp/*/tools/* 2>/dev/null || true

# Initialize SQLite database with indexes
RUN python3 scripts/init-db.py

# Pull base model and build fast-sashi custom model
RUN ollama serve & sleep 3 \
    && ollama pull llama3.2 \
    && ollama create fast-sashi -f Modelfile.fast \
    && pkill ollama || true

# Create shell aliases
RUN printf '\n# SASHI Aliases\nalias s="/root/ollama-local/sashi"\nalias sask="/root/ollama-local/sashi ask"\nalias scode="/root/ollama-local/sashi code"\nalias slocal="/root/ollama-local/sashi local"\nalias schat="/root/ollama-local/sashi chat"\nalias sstatus="/root/ollama-local/sashi status"\nalias ai="/root/ollama-local/sashi"\n' >> /root/.bashrc

# Expose Ollama port
EXPOSE 11434

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:11434/api/tags || exit 1

# Start Ollama and drop into shell
CMD ["bash", "-c", "ollama serve & sleep 3 && exec bash"]
