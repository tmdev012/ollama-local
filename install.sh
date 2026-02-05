#!/bin/bash
# SASHI Installer - One-command setup for any Linux system
# Usage: curl -fsSL <url>/install.sh | bash

set -e

echo "============================================"
echo "  SASHI - Smart AI Shell Interface v2.0.0"
echo "============================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[+]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[x]${NC} $1"; }

INSTALL_DIR="$HOME/ollama-local"

# Check dependencies
check_deps() {
    print_status "Checking dependencies..."

    local missing=()
    command -v curl &>/dev/null || missing+=("curl")
    command -v jq &>/dev/null || missing+=("jq")
    command -v python3 &>/dev/null || missing+=("python3")

    if [ ${#missing[@]} -gt 0 ]; then
        print_warn "Installing missing: ${missing[*]}"
        sudo apt-get update
        sudo apt-get install -y "${missing[@]}"
    fi
}

# Install Ollama
install_ollama() {
    if command -v ollama &>/dev/null; then
        print_status "Ollama already installed"
    else
        print_status "Installing Ollama..."
        curl -fsSL https://ollama.ai/install.sh | sh
    fi

    # Start service
    if systemctl is-active ollama &>/dev/null; then
        print_status "Ollama service running"
    else
        print_status "Starting Ollama service..."
        sudo systemctl start ollama
        sudo systemctl enable ollama
    fi
}

# Download models
download_models() {
    print_status "Checking models..."

    if ollama list 2>/dev/null | grep -q "llama3.2"; then
        print_status "llama3.2 already downloaded"
    else
        print_status "Downloading llama3.2 (2GB)..."
        ollama pull llama3.2
    fi
}

# Setup SASHI
setup_sashi() {
    print_status "Setting up SASHI..."

    # Create directories
    mkdir -p "$INSTALL_DIR"/{db,logs,mcp/{claude,deepseek,llama,gmail,voice}/{config,tools,prompts,resources}}

    # Initialize database
    python3 << PYEOF
import sqlite3
conn = sqlite3.connect('$INSTALL_DIR/db/history.db')
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

    print_status "Database initialized with indexes"
}

# Setup shell aliases
setup_aliases() {
    print_status "Setting up shell aliases..."

    local shell_rc="$HOME/.bashrc"
    [ -n "$ZSH_VERSION" ] && shell_rc="$HOME/.zshrc"

    # Check if already configured
    if grep -q "MCP AI SYSTEM" "$shell_rc" 2>/dev/null; then
        print_warn "Aliases already configured"
        return
    fi

    cat >> "$shell_rc" << 'ALIASES'

# ============================================
# MCP AI SYSTEM (SASHI)
# ============================================
export PATH="$HOME/ollama-local:$PATH"

# SASHI Primary
alias s='~/ollama-local/sashi'
alias sask='~/ollama-local/sashi ask'
alias scode='~/ollama-local/sashi code'
alias slocal='~/ollama-local/sashi local'
alias schat='~/ollama-local/sashi chat'
alias sstatus='~/ollama-local/sashi status'
alias smodels='~/ollama-local/sashi models'

# Ollama Service
alias ollama-up='sudo systemctl start ollama'
alias ollama-down='sudo systemctl stop ollama'
alias ollama-status='systemctl is-active ollama && ollama list'

# Pipe Support
aipipe() { ~/ollama-local/sashi code "$1 $(cat -)"; }
alias analyze='aipipe "Analyze:"'
alias summarize='aipipe "Summarize:"'
alias review='aipipe "Code review:"'

# Legacy
alias ai='~/ollama-local/sashi'
alias aicode='~/ollama-local/sashi code'

# Help
mcp-help() {
    echo "SASHI Commands: s, sask, scode, slocal, schat, sstatus"
    echo "Pipe: cat file | analyze"
    echo "Voice: sashi voice --gui"
}
ALIASES

    print_status "Aliases added to $shell_rc"
}

# Create .env template
create_env() {
    if [ -f "$INSTALL_DIR/.env" ]; then
        print_warn ".env already exists"
    else
        cat > "$INSTALL_DIR/.env" << 'ENVFILE'
# SASHI Configuration
# Get DeepSeek API key: https://platform.deepseek.com/

DEEPSEEK_API_KEY=your-api-key-here
DEFAULT_MODEL=deepseek-chat
LOCAL_MODEL=llama3.2
OLLAMA_HOST=http://localhost:11434
ENVFILE
        print_warn "Created .env template - add your DeepSeek API key!"
    fi
}

# Main
main() {
    echo ""
    check_deps
    install_ollama
    download_models
    setup_sashi
    setup_aliases
    create_env

    echo ""
    echo "============================================"
    print_status "Installation complete!"
    echo "============================================"
    echo ""
    echo "Next steps:"
    echo "  1. Add DeepSeek API key to: $INSTALL_DIR/.env"
    echo "  2. Reload shell: source ~/.bashrc"
    echo "  3. Test: sashi status"
    echo "  4. Try: s 'Hello world'"
    echo ""
    echo "Voice input: sashi voice --install"
    echo "Help: mcp-help"
    echo ""
}

main "$@"
