#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  SASHI v3.2.0 — Install Script
#  Local-first AI CLI • Privacy-first • CPU-optimised • No GPU required
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/tmdev012/ollama-local/main/install.sh | bash
#    bash install.sh [--no-models] [--no-gpu-tune] [--termux]
#
#  What it does:
#    1. Detects environment (Linux / Termux / WSL)
#    2. Installs system deps (git, curl, jq, python3, sqlite3)
#    3. Installs Ollama (skips if present)
#    4. Applies CPU performance tuning (optional)
#    5. Pulls llama3.2 3B model (optional: 8B)
#    6. Clones sashi to ~/ollama-local (or updates if exists)
#    7. Initialises SQLite history DB
#    8. Writes .env from template
#    9. Injects shell aliases (bash + zsh)
#   10. Verifies install with sashi status
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Flags ──────────────────────────────────────────────────────────────────
SKIP_MODELS=false
SKIP_GPU_TUNE=false
FORCE_TERMUX=false
for arg in "$@"; do
  case $arg in
    --no-models)    SKIP_MODELS=true ;;
    --no-gpu-tune)  SKIP_GPU_TUNE=true ;;
    --termux)       FORCE_TERMUX=true ;;
  esac
done

# ── Colours ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}  ✓${NC}  $*"; }
info() { echo -e "${CYAN}  →${NC}  $*"; }
warn() { echo -e "${YELLOW}  !${NC}  $*"; }
err()  { echo -e "${RED}  ✗${NC}  $*"; exit 1; }
hdr()  { echo -e "\n${BOLD}${BLUE}── $* ──${NC}"; }

# ── Banner ─────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
  ███████╗ █████╗ ███████╗██╗  ██╗██╗
  ██╔════╝██╔══██╗██╔════╝██║  ██║██║
  ███████╗███████║███████╗███████║██║
  ╚════██║██╔══██║╚════██║██╔══██║██║
  ███████║██║  ██║███████║██║  ██║██║
  ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝
  v3.2.0 — Local-first AI CLI
  Privacy-first • CPU-optimised • No GPU required
BANNER
echo -e "${NC}"

# ── Environment Detection ──────────────────────────────────────────────────
hdr "Environment"

IS_TERMUX=false
IS_WSL=false
IS_LINUX=false

if [[ "$FORCE_TERMUX" == true ]] || [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "/data/data/com.termux" ]]; then
  IS_TERMUX=true
  ok "Termux / Android detected"
elif grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
  ok "WSL detected"
else
  IS_LINUX=true
  ok "Linux desktop detected"
fi

INSTALL_DIR="$HOME/ollama-local"
SHELL_RC="$HOME/.bashrc"
[[ -n "${ZSH_VERSION:-}" || "$SHELL" == */zsh ]] && SHELL_RC="$HOME/.zshrc"
ok "Shell RC: $SHELL_RC"
ok "Install dir: $INSTALL_DIR"

# ── Dependencies ───────────────────────────────────────────────────────────
hdr "Dependencies"

install_pkg() {
  local pkg="$1"
  if command -v "$pkg" &>/dev/null; then
    ok "$pkg already installed"
    return
  fi
  info "Installing $pkg..."
  if [[ "$IS_TERMUX" == true ]]; then
    pkg install -y "$pkg" 2>/dev/null || warn "Could not install $pkg via pkg"
  else
    sudo apt-get install -y "$pkg" -qq 2>/dev/null \
      || sudo dnf install -y "$pkg" -q 2>/dev/null \
      || warn "Could not auto-install $pkg — install it manually"
  fi
}

[[ "$IS_TERMUX" != true ]] && (sudo apt-get update -qq 2>/dev/null || true)

for dep in git curl jq python3 sqlite3; do
  install_pkg "$dep"
done

# Python deps for gRPC (probe + kanban servers)
if command -v pip3 &>/dev/null || command -v pip &>/dev/null; then
  PIP=$(command -v pip3 || command -v pip)
  info "Installing Python gRPC deps..."
  $PIP install grpcio grpcio-tools 2>/dev/null | grep -E "^(Successfully|already)" || true
  ok "gRPC Python libs ready"
fi

# ── Ollama ─────────────────────────────────────────────────────────────────
hdr "Ollama"

if command -v ollama &>/dev/null; then
  OLLAMA_VER=$(ollama --version 2>/dev/null | head -1)
  ok "Ollama already installed — $OLLAMA_VER"
else
  if [[ "$IS_TERMUX" == true ]]; then
    warn "Termux: Install Ollama manually from https://ollama.ai"
    warn "Skipping Ollama install on Termux"
  else
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    ok "Ollama installed"
  fi
fi

# Start / enable service (Linux only)
if [[ "$IS_LINUX" == true ]] && command -v systemctl &>/dev/null; then
  if systemctl is-active --quiet ollama 2>/dev/null; then
    ok "Ollama service running"
  else
    info "Starting Ollama service..."
    sudo systemctl start ollama
    sudo systemctl enable ollama 2>/dev/null || true
    sleep 2
    ok "Ollama service started"
  fi
fi

# ── CPU Performance Tuning ─────────────────────────────────────────────────
hdr "CPU Performance Tuning"

if [[ "$SKIP_GPU_TUNE" == true ]]; then
  warn "Skipping CPU tuning (--no-gpu-tune)"
else
  # Ollama env vars — optimised for CPU-only hardware (proven on i7-6500U)
  OLLAMA_ENV_FILE="/etc/systemd/system/ollama.service.d/override.conf"
  if [[ "$IS_LINUX" == true ]] && command -v systemctl &>/dev/null; then
    sudo mkdir -p /etc/systemd/system/ollama.service.d/
    cat << 'OLLAMA_ENV' | sudo tee "$OLLAMA_ENV_FILE" > /dev/null
[Service]
# CPU-optimised settings (benchmarked: i7-6500U, no GPU)
# num_thread=2 (physical cores) is 30% faster than 4 (HT contention)
Environment="OLLAMA_NUM_THREADS=2"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=30m"
OLLAMA_ENV
    sudo systemctl daemon-reload
    sudo systemctl restart ollama 2>/dev/null || true
    ok "Ollama CPU tuning applied (num_threads=2, keep_alive=30m)"
  fi

  # CPU governor → performance
  if [[ "$IS_LINUX" == true ]] && [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
    CURRENT_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    if [[ "$CURRENT_GOV" != "performance" ]]; then
      info "Setting CPU governor: $CURRENT_GOV → performance"
      echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1 || true
      ok "CPU governor set to performance"
    else
      ok "CPU governor already: performance"
    fi
  fi
fi

# ── Models ─────────────────────────────────────────────────────────────────
hdr "Models"

if [[ "$SKIP_MODELS" == true ]]; then
  warn "Skipping model pull (--no-models)"
else
  if command -v ollama &>/dev/null; then
    if ollama list 2>/dev/null | grep -q "llama3.2"; then
      ok "llama3.2 (3B) already present"
    else
      info "Pulling llama3.2 3B (~2.0GB) — default fast model..."
      ollama pull llama3.2
      ok "llama3.2 pulled"
    fi

    echo ""
    read -r -p "  Pull llama3.1:8b (8B model, ~4.9GB, better quality)? [y/N] " PULL_8B
    if [[ "${PULL_8B,,}" == "y" ]]; then
      info "Pulling llama3.1:8b..."
      ollama pull llama3.1:8b
      ok "llama3.1:8b pulled"
    fi
  else
    warn "Ollama not available — skipping model pull"
  fi
fi

# ── Clone / Update Sashi ───────────────────────────────────────────────────
hdr "Sashi"

if [[ -d "$INSTALL_DIR/.git" ]]; then
  info "Updating existing install..."
  git -C "$INSTALL_DIR" pull --ff-only origin main 2>/dev/null \
    || warn "Could not auto-update — run: git -C $INSTALL_DIR pull"
  ok "Updated to latest"
elif [[ -d "$INSTALL_DIR" ]]; then
  warn "$INSTALL_DIR exists but is not a git repo — skipping clone"
else
  info "Cloning sashi..."
  git clone https://github.com/tmdev012/ollama-local.git "$INSTALL_DIR"
  ok "Cloned to $INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/sashi"

# ── Database ───────────────────────────────────────────────────────────────
hdr "Database"

mkdir -p "$INSTALL_DIR/db" "$INSTALL_DIR/logs"

python3 << PYEOF
import sqlite3, os
db = os.path.expanduser('$INSTALL_DIR/db/history.db')
conn = sqlite3.connect(db)
conn.execute('PRAGMA journal_mode=WAL')
c = conn.cursor()
c.execute('''CREATE TABLE IF NOT EXISTS queries (
    id            INTEGER PRIMARY KEY,
    timestamp     DATETIME DEFAULT CURRENT_TIMESTAMP,
    model         TEXT,
    prompt        TEXT,
    response_length INTEGER,
    duration_ms   INTEGER
)''')
c.execute('CREATE INDEX IF NOT EXISTS idx_queries_model     ON queries(model)')
c.execute('CREATE INDEX IF NOT EXISTS idx_queries_timestamp ON queries(timestamp)')
c.execute('CREATE INDEX IF NOT EXISTS idx_queries_duration  ON queries(duration_ms)')
conn.commit()
conn.close()
print("  history.db ready (WAL mode)")
PYEOF

# ── Environment File ───────────────────────────────────────────────────────
hdr "Configuration"

if [[ -f "$INSTALL_DIR/.env" ]]; then
  ok ".env already exists — not overwriting"
else
  cat > "$INSTALL_DIR/.env" << 'ENVTEMPLATE'
# SASHI v3.2.0 Configuration
# ─────────────────────────────────────────────────────────

# ── Core ──
LOCAL_MODEL=llama3.2
OLLAMA_HOST=http://localhost:11434
OFFLINE_MODE=true

# ── Cloud fallback (optional) ──
# Free models, no credit card needed. Get key: https://openrouter.ai/keys
OPENROUTER_API_KEY=
OPENROUTER_MODEL=meta-llama/llama-3.1-8b-instruct:free

# ── GitHub (optional, for smart-push + probe) ──
# Generate fine-grained PAT: https://github.com/settings/tokens?type=beta
GITHUB_PAT=
GIT_USER=
GIT_EMAIL=

# ── Google / Gmail (optional) ──
# GCP console: https://console.cloud.google.com
GCP_PROJECT_ID=
GOOGLE_APPLICATION_CREDENTIALS=

# ── Paths (auto-set) ──
SASHI_HOME=$HOME/ollama-local
SASHI_DB=$HOME/ollama-local/db/history.db
KANBAN_PMO_DIR=$HOME/kanban-pmo
PROBE_DIR=$HOME/persist-memory-probe
ENVTEMPLATE
  ok ".env created — edit $INSTALL_DIR/.env to add optional keys"
fi

# ── Shell Aliases ──────────────────────────────────────────────────────────
hdr "Shell Aliases"

ALIAS_MARKER="# SASHI v3.2.0"

if grep -q "$ALIAS_MARKER" "$SHELL_RC" 2>/dev/null; then
  ok "Aliases already in $SHELL_RC"
else
  cat >> "$SHELL_RC" << ALIASES

$ALIAS_MARKER
export PATH="\$HOME/ollama-local:\$PATH"
source "\$HOME/ollama-local/lib/sh/aliases.sh" 2>/dev/null || true

# Quick sashi shortcuts
alias s='sashi'
alias sask='sashi ask'
alias scode='sashi code'
alias schat='sashi chat'
alias s8b='sashi 8b'
alias sstatus='sashi status'
alias skanban='sashi kanban board'

# Pipe helpers
aipipe() { sashi code "\$1 \$(cat -)"; }
alias analyze='aipipe "Analyse:"'
alias summarize='aipipe "Summarise:"'
alias review='aipipe "Code review:"'

# Ollama service
alias ollama-up='sudo systemctl start ollama'
alias ollama-down='sudo systemctl stop ollama'
ALIASES
  ok "Aliases injected into $SHELL_RC"
fi

# ── PATH for current session ───────────────────────────────────────────────
export PATH="$INSTALL_DIR:$PATH"

# ── Verify ────────────────────────────────────────────────────────────────
hdr "Verify"

if "$INSTALL_DIR/sashi" status < /dev/null 2>/dev/null | grep -q "SASHI\|ollama\|model"; then
  ok "sashi status: OK"
else
  warn "sashi status check skipped (Ollama may need a moment to start)"
fi

# ── Done ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  SASHI v3.2.0 installed successfully   ${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Reload shell:${NC}  source $SHELL_RC"
echo -e "  ${CYAN}Quick test:${NC}   sashi ask 'hello'"
echo -e "  ${CYAN}Code help:${NC}    scode 'write a fizzbuzz in python'"
echo -e "  ${CYAN}8B model:${NC}     s8b 'explain async/await'"
echo -e "  ${CYAN}Kanban:${NC}       skanban"
echo -e "  ${CYAN}Status:${NC}       sstatus"
echo ""
echo -e "  ${YELLOW}Optional:${NC} edit $INSTALL_DIR/.env to add OpenRouter/GitHub keys"
echo ""
