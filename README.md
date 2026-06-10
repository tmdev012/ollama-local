# SASHI v5.2.0 — Local-first AI Orchestration Layer

> **Sashi** is an AI-native CLI providing local LLM inference, MCP-compatible tool dispatch,
> gRPC-backed project intelligence, and a structured agentic write pipeline.
> Designed to run fully offline on constrained hardware. No GPU required.

[![GitHub](https://img.shields.io/badge/GitHub-tmdev012%2Follama--local-blue)](https://github.com/tmdev012/ollama-local)
[![Version](https://img.shields.io/badge/version-5.2.0-green)]()
[![License](https://img.shields.io/badge/license-MIT-yellow)]()

---

## Table of Contents

- [Three-Repo Stack](#three-repo-stack)
- [Incident Report: Unbound Variable (2026-03-11)](#incident-report-unbound-variable-2026-03-11)
- [What v5.2.0 Is](#what-v323-is)
- [Architecture](#architecture)
- [Models](#models)
- [Variables Reference](#variables-reference)
- [Commands](#commands)
- [Aliases Reference](#aliases-reference)
- [Android / USB Hello World](#android--usb-hello-world)
- [Performance Tuning](#performance-tuning)
- [SQLite Schema](#sqlite-schema)
- [JSONL Training Schema](#jsonl-training-schema)
- [Version History](#version-history)
- [Installation](#installation)

---

## Three-Repo Stack

The system is three interdependent repositories sharing a single SQLite WAL database.
**No repo is standalone.** Changes to one affect the others. Any update requires a
multi-tenant review: version strings, gRPC proto compatibility, and training data must
stay in sync across all three before a push is authoritative.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     STACK OVERVIEW v5.2.0                           │
│                                                                     │
│  ollama-local/           kanban-pmo/          persist-memory-probe/ │
│  ┌─────────────┐        ┌─────────────┐       ┌──────────────────┐  │
│  │  sashi CLI  │◄──────►│  Governor   │◄─────►│ Credential Layer │  │
│  │  Inference  │  gRPC  │  :50051     │  gRPC │  :50052          │  │
│  │  File I/O   │        │  Kanban     │       │  probe.db        │  │
│  │  Training   │        │  Repo Auth  │       │  Gatekeeper      │  │
│  └──────┬──────┘        └──────┬──────┘       └────────┬─────────┘  │
│         │                     │                        │            │
│         └─────────────────────┴────────────────────────┘            │
│                               │                                     │
│                    ~/ollama-local/db/history.db                     │
│                    (SQLite WAL — shared via symlinks)               │
└─────────────────────────────────────────────────────────────────────┘
```

### Repo Roles

| Repo | Role | Key Files | gRPC Port |
|------|------|-----------|-----------|
| `ollama-local` | CLI + Inference + File I/O | `sashi`, `lib/sh/`, `Modelfile.*` | client |
| `kanban-pmo` | Governor / CFO — sprint & repo authority | `grpc_server.py`, `config/repos.yml` | :50051 |
| `persist-memory-probe` | Credential layer + repo scanner | `gatekeeper_3_1_0.sh`, `probe_server.py` | :50052 |

### Shared State

- `~/ollama-local/db/history.db` — primary SQLite WAL
- `~/persist-memory-probe/db/sashi_history.db` → symlink to above
- `kanban-pmo/config/repos.yml` — 11 repos registered; governs push authority
- `CHANGELOG.md` — injected into both Modelfile system prompts at build time

### Multi-Tenant Update Rule

Any version bump must touch all three repos in one session:
1. Bump version strings in `sashi`, `Modelfile.fast`, `Modelfile.8b`, SVGs
2. Update `CHANGELOG.md` (feeds model training)
3. Rebuild models: `ollama create fast-sashi -f Modelfile.fast && ollama create sashi-llama-8b -f Modelfile.8b`
4. Push `ollama-local` → then `kanban-pmo` → then `persist-memory-probe`

---

## Incident Report: Unbound Variable (2026-03-11)

**Duration:** ~1 hour downtime on `sashi` startup
**Root cause:** `set -uo pipefail` (line 4) + bare `$TERMUX_VERSION` reference (line 9)
**Symptom:** Every invocation of `sashi` failed immediately:

```
/home/tmdev012/ollama-local/sashi: line 9: TERMUX_VERSION: unbound variable
```

### Why It Happened

The script had `set -u` enabled, which treats any reference to an unset variable as a
fatal error. `TERMUX_VERSION` is an environment variable set automatically by the
[Termux Android app](https://termux.dev) — it is **never present** on a Linux desktop.

The original code:
```bash
# BROKEN — crashes under set -u on any non-Android machine
[[ -n "$TERMUX_VERSION" || -d "/data/data/com.termux" ]] && source .env.termux
```

Two additional bare references survived in `show_status()` and `detect_environment()`,
meaning `sashi status` would also crash even after the first fix.

### Why It Went Undetected

The variable group (`TERMUX_VERSION`, `.env.termux`, `SASHI_ENV`, `SASHI_ROUTE`) was
introduced as a platform-detection block but was never treated as a group when `set -u`
was added. There was no contract tracking which variables needed `:-` guards. Individual
file edits across sessions caused the guard to be added to the startup block but missed
in the two downstream functions.

### Fix Applied

```bash
# CORRECT — uname -o provides ground truth before any variable reference
_OS_TYPE="$(uname -o 2>/dev/null || echo unknown)"
[[ "$_OS_TYPE" == "Android" ]] && source "$SCRIPT_DIR/.env.termux" 2>/dev/null || true
```

All three `TERMUX_VERSION` references replaced with `$_OS_TYPE` comparisons.
`show_status()` now prints `uname -a` output for full environment context.
Commit: `c5af357`

### Lesson

When introducing a platform-specific variable group, guard **every** reference at the
point of introduction. `set -u` is correct and should stay — it caught a real bug.
The fix is at the variable reference, not by removing `set -u`.

---

## What v5.2.0 Is

v5.2.0 introduced a two-layer file I/O architecture and finalized the HuggingFace
training corpus. It is the first version where `sashi write` routes through the local
model before committing output to disk.

### New in v5.2.0

#### `sashi file` — 17 Structured File Operations

```bash
sashi file read   <path> [enc] [head_n]       # size-aware, encoding-safe
sashi file write  <path> <content> [--backup] # atomic (tmp → mv)
sashi file append <path> <content> [max_mb]   # flock concurrent-safe
sashi file rotate <path> [keep_n]             # log rotation
sashi file parse  csv|json|jsonl|text <path>  # format-aware parsing
sashi file copy   <src> <dst> [verify=1]      # rsync + sha256 verify
sashi file move   <src> <dst>                 # cross-device safe
sashi file delete <path> [trash|shred|force]  # trash-first policy
sashi file batch  <op> <pattern> [parallel]   # glob-targeted batch
sashi file check  <path>                      # corrupt/integrity check
sashi file recover <path> [backup|git|truncate]
sashi file info   <path>                      # full info card
sashi file stream <path> [filter]             # real-time tail -f
sashi file split  <path> [lines|size] [val]   # split large files
sashi file join   <pattern> <out>             # join split parts
sashi file detect <path>                      # op-type + size class
```

Backed by `lib/sh/file-ops.sh` (516 lines) — POSIX-safe atomic write, rotate, parse,
stream, split, and join primitives.

#### `sashi write` — 7 LLM-Mediated Write Modes

```bash
sashi write <file> <prompt>              # prompt → file (atomic)
sashi write --read <in> <out> <prompt>   # read file → llama → write
sashi write --append <file> <prompt>     # append AI output to file
sashi write --batch <glob> <dir> <prompt># process multiple files
sashi write --fmt json|csv|md|sh <out> <prompt>  # format-validated
sashi write --pipe <out> <prompt>        # cat file | sashi write --pipe
sashi write --safe <file> <prompt>       # retry with fast-sashi fallback
```

Backed by `lib/sh/llm-write.sh` (227 lines). All writes are atomic. Fallback model
is `fast-sashi` (canonical 3B). Input truncated to 6000 chars to stay within context.

#### Training Corpus

- `training/sashi_v5.2.0_master.jsonl` — 232 ChatML dialogs covering file-ops,
  LLM write modes, and tool-dispatch patterns. Formatted for HuggingFace `datasets`.
- `training/README.md` — dataset card with YAML frontmatter and schema documentation.
- Both Modelfiles rebuilt: `fast-sashi:latest` (2.0GB) + `sashi-llama-8b:latest` (4.9GB)

#### Bug Fixes in v5.2.0

- **[CRITICAL]** `lib/sh/llm-write.sh` fallback model `sashi-llama-fast` corrected
  to canonical `fast-sashi` — silent failures on degraded-path writes eliminated.
- Version references synchronized across `Modelfile.fast` and `Modelfile.8b`.
- Missing `wallog` entry added to `sashi help`.

---

## Architecture

### Directory Structure

```
ollama-local/
├── sashi                       # Main CLI v5.2.0 (bash, set -uo pipefail)
├── .env                        # Config: LOCAL_MODEL, OLLAMA_HOST, gRPC ports
├── .env.termux                 # Android override: LOCAL_MODEL=llama3.2:1b
├── Modelfile.fast              # fast-sashi 3B (default, concise system prompt)
├── Modelfile.8b                # sashi-llama-8b 8B (num_thread 2)
├── CHANGELOG.md                # Canonical release record — injected into Modelfiles
│
├── db/
│   └── history.db              # SQLite WAL (shared across all 3 repos)
│
├── docs/
│   ├── diagrams/               # SVGs: process-map, data-flow, smart-push (v5.2.0)
│   └── sashi-v5.2.0-spec.md   # Architecture spec
│
├── lib/sh/
│   ├── aliases.sh              # Single source for all shell aliases (sourced by .bashrc/.zshrc)
│   ├── banner.sh               # sashi_banner() ASCII art
│   ├── file-ops.sh             # File operations library (516 lines, 17 ops)
│   ├── llm-write.sh            # LLM write pipeline (227 lines, 7 modes)
│   ├── usb-monitor.sh          # USB vendor DB + sysfs scanner
│   └── wifi-debug.sh           # ADB WiFi library
│
├── mcp/
│   ├── claude/                 # Claude Code integration
│   ├── llama/tools/
│   │   └── ai-orchestrator     # v3.1.0, sources banner.sh
│   ├── gmail/tools/gmail-cli   # Gmail search/recent/export
│   ├── voice/tools/            # voice-input, voice-gui, install-voice
│   └── ide/sashi-ide           # Terminal Android/Kotlin IDE (Rich TUI, Python)
│
├── scripts/
│   ├── smart-push.sh           # Git automation (424 lines)
│   ├── android-setup.sh        # Android SDK + platform-tools installer
│   ├── rebuild-models.sh       # Rebuild fast-sashi + sashi-llama-8b
│   └── ollama-boost.sh         # CPU governor + performance tuning
│
├── training/
│   ├── sashi_v5.2.0_master.jsonl  # 232 ChatML training dialogs
│   └── README.md               # HuggingFace dataset card
│
└── old-archive/                # Archived sessions (never deleted)
```

### Data Flow

```
User input (text / pipe / interactive)
          │
          ▼
    sashi (bash, set -uo pipefail)
          │  sources .env, lib/sh/*.sh at startup
          │  _OS_TYPE=$(uname -o) — platform detection
          │
    ┌─────┴──────────────────────────────────┐
    │           Command Router               │
    │  ask/code/local → llama_query()        │
    │  8b            → ollama run sashi-llama-8b
    │  write         → llm-write.sh          │
    │  file          → file-ops.sh           │
    │  online/cloud  → online_query() → hf() │
    │  grpc          → grpc_server.py :50051 │
    │  probe         → probe_server.py :50052│
    │  kanban        → ~/kanban-pmo/kanban/  │
    └─────┬──────────────────────────────────┘
          │
    ┌─────▼──────┐   ┌──────────────┐   ┌────────────┐
    │ ollama run │   │  OpenRouter  │   │ HuggingFace│
    │ fast-sashi │   │  (cloud key) │   │ (free tier)│
    │ (3B local) │   └──────────────┘   └────────────┘
    └─────┬──────┘
          │
    log_query() → history.db (async, non-blocking)
```

### BDPM Governance

The 4-layer BDPM model spans all three repos. Diagram: `kanban-pmo/docs/diagrams/bdpm-swimlanes.svg`

| Layer | Owner | Scope |
|-------|-------|-------|
| **Business** | kanban-pmo | Sprint intake, milestone gates, 11-repo registry |
| **Development** | ollama-local | git push, model build, test, smart-push |
| **Production** | ollama-local | gRPC dispatch, inference, file write, DB log |
| **Monitoring** | persist-memory-probe | Cred audit, health check, doc sync |

---

## Models

| Model | Params | Size | Speed | Modelfile | Use Case |
|-------|--------|------|-------|-----------|----------|
| `fast-sashi` | 3B | 2.0GB | ~4.0 tok/s | `Modelfile.fast` | **Default** — `sashi ask/code/write` |
| `sashi-llama-8b` | 8B | 4.9GB | ~3.7 tok/s | `Modelfile.8b` | `sashi 8b` — better reasoning, needs swap |
| `llama3.2:latest` | 3B | 2.0GB | ~4.0 tok/s | (base) | Fallback when `LOCAL_MODEL=llama3.2` |
| `llama3.2:1b` | 1B | 1.3GB | fast | (base) | Termux/Android auto-selected |

**Stale models** (in `ollama list` but superseded):
- `sashi-llama-fast:latest` — old name for `fast-sashi`, do not use
- `turbo-llama`, `fast-llama`, `sashi-llama` — pre-v5.2.0 iterations

Rebuild canonical models:
```bash
ollama create fast-sashi -f ~/ollama-local/Modelfile.fast
ollama create sashi-llama-8b -f ~/ollama-local/Modelfile.8b
```

---

## Variables Reference

All variables sourced from `.env` at startup. Override individually via environment.

### `.env` — Config Layer

| Variable | Default | Purpose |
|----------|---------|---------|
| `LOCAL_MODEL` | `llama3.2` | Model used by `llama_query()` |
| `OLLAMA_HOST` | `http://localhost:11434` | Ollama API endpoint |
| `OPENROUTER_API_KEY` | *(empty)* | Cloud fallback — get at openrouter.ai/keys |
| `OPENROUTER_MODEL` | `meta-llama/llama-3.1-8b-instruct:free` | Cloud model |
| `HF_TOKEN` | *(empty)* | HuggingFace token (optional, extends rate limit) |
| `HF_MODEL` | `meta-llama/Llama-3.2-3B-Instruct` | HF inference model |
| `SASHI_DB` | `~/ollama-local/db/history.db` | SQLite path override |
| `SASHI_HOME` | `~/ollama-local` | Repo root |
| `KANBAN_DIR` | `~/kanban-pmo/kanban` | Kanban cards directory |
| `PROBE_DIR` | `~/persist-memory-probe` | Probe repo root |
| `GRPC_KANBAN_PORT` | `50051` | kanban-pmo gRPC port |
| `GRPC_PROBE_PORT` | `50052` | persist-memory-probe gRPC port |
| `OFFLINE_MODE` | `true` | Disables outbound network checks |
| `KANBAN_PMO_DIR` | `/home/tmdev012/kanban-pmo` | Governor path |
| `GCP_PROJECT_ID` | `tm012-git-tracking` | Google Cloud project |
| `ANDROID_HOME` | `~/Android/Sdk` | Android SDK root |
| `JAVA_HOME` | `/usr/lib/jvm/java-17-openjdk-amd64` | JDK path |

### Runtime Variables (set by `sashi` at startup)

| Variable | Set From | Purpose |
|----------|----------|---------|
| `SCRIPT_DIR` | `${BASH_SOURCE[0]}` | Absolute path to repo root |
| `_OS_TYPE` | `uname -o` | Platform: `Android` or `GNU/Linux` |
| `VERSION` | hardcoded `5.2.0` | Current version |
| `DB_PATH` | `${SASHI_DB:-$SCRIPT_DIR/db/history.db}` | Active DB path |
| `MODEL` | `${LOCAL_MODEL:-llama3.2}` | Active inference model |
| `OLLAMA_API` | `${OLLAMA_HOST:-http://localhost:11434}` | Active API base |
| `STDIN_DATA` | `cat -` if non-TTY | Piped input captured at startup |
| `RED/GREEN/BLUE/YELLOW/NC` | ANSI codes | Terminal colour constants |

### `llm-write.sh` Sub-Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `LLM_MODEL` | `${MODEL:-llama3.2}` | Model used by `_lw_infer()` |
| `_LW_RED/GRN/YLW/CYN/BLD/DIM/NC` | ANSI codes | Write pipeline colours |

### `aliases.sh` Variable

| Variable | Value | Purpose |
|----------|-------|---------|
| `_SASHI_DIR` | `${_SASHI_DIR:-$HOME/ollama-local}` | Alias path base (exported) |

---

## Commands

```bash
sashi ask <prompt>         # Local 3B inference
sashi code <prompt>        # Code-focused prompt
sashi 8b <prompt>          # 8B inference (90s timeout)
sashi chat                 # Interactive ollama run session
sashi online <prompt>      # OpenRouter → HuggingFace fallback
sashi hf <prompt>          # HuggingFace direct

sashi write <file> <prompt>          # LLM → atomic write
sashi write --read <in> <out> <p>    # File → LLM → write
sashi write --append <file> <p>      # Append AI output
sashi write --fmt json <out> <p>     # Validated format output
sashi write --safe <file> <p>        # With fallback model

sashi file read|write|append|parse|copy|move|delete|batch|check|recover|info|stream|split|join|rotate|detect

sashi status               # Full system status + gRPC health + uname -a
sashi models               # ollama list
sashi history              # Last 20 queries from history.db
sashi wallog [N]           # Modelfile git log + SQL WAL changelog
sashi changelog            # Print CHANGELOG.md

sashi grpc start|stop|restart|status|logs
sashi probe sync|list|recommend|export|write|status
sashi kanban board|state|backlog|wip|open|closed

sashi usb scan|watch|storage|details|tree|search|export
sashi wifi init|connect|scan|status|logcat|shell|disconnect
sashi adb status|devices|wireless|shell|logcat|install|push|pull

sashi android-studio [project-path]   # Terminal Kotlin/Android IDE
sashi hf <prompt>                     # HuggingFace Inference API
```

---

## Aliases Reference

Defined in `~/ollama-local/lib/sh/aliases.sh`.
Sourced by `~/.bashrc` (line 125) and `~/.zshrc` (line 120) — available in both shells.
All aliases use `$_SASHI_DIR` (exported) so they survive shell restarts.

### Core AI

| Alias | Backs To |
|-------|----------|
| `s`, `ai` | `sashi ask` → `llama_query()` |
| `sask` | `sashi ask` |
| `scode` | `sashi code` → `code_query()` |
| `s8b` | `sashi 8b` → `ollama run sashi-llama-8b` |
| `schat` | `sashi chat` → `interactive_chat()` → `ollama run` |
| `sstatus` | `sashi status` → `show_status()` |
| `shistory` | `sashi history` → `show_history()` |
| `smodels` | `sashi models` → `ollama list` |
| `schangelog` | `sashi changelog` → `cat CHANGELOG.md` |
| `swallog` | `sashi wallog` → git log + sqlite3 |
| `skanban` | `sashi kanban board` |
| `sgmail` | `sashi gmail` → `mcp/gmail/tools/gmail-cli` |
| `sonline`, `scloud` | `sashi online` → `online_query()` |
| `shf`, `hf` | `sashi hf` → `hf_query()` |
| `aihelp` | `sashi help` → `show_help()` |

### LLM Write System

| Alias | Backs To |
|-------|----------|
| `swrite` | `sashi write` → `llmw_write()` |
| `swrite-read` | `--read` → `llmw_process()` |
| `swrite-append` | `--append` → `llmw_append()` |
| `swrite-batch` | `--batch` → `llmw_batch()` |
| `swrite-json/csv/md/sh` | `--fmt <fmt>` → `llmw_write_fmt()` |
| `swrite-safe` | `--safe` → `llmw_safe_write()` |
| `swrite-pipe` | `--pipe` → `llmw_pipe()` |

### File Operations

| Alias | Backs To |
|-------|----------|
| `sfile` | `sashi file` → `file-ops.sh` |
| `sfile-info` | `fops_info()` |
| `sfile-detect` | `fops_detect_op()` |
| `sfile-check` | `fops_check_corrupt()` |
| `sfile-read` | `fops_read()` |
| `sfile-write` | `fops_write()` |
| `sfile-append` | `fops_append()` |
| `sfile-parse` | `fops_parse_*()` |
| `sfile-copy` | `fops_copy()` |
| `sfile-move` | `fops_move()` |
| `sfile-delete` | `fops_delete()` |
| `sfile-batch` | `fops_batch()` |
| `sfile-recover` | `fops_recover()` |
| `sfile-stream` | `fops_stream()` |
| `sfile-split` | `fops_split()` |
| `sfile-join` | `fops_join()` |
| `sfile-rotate` | `fops_rotate()` |

### Hardware / Android

| Alias | Backs To |
|-------|----------|
| `usb`, `usb-scan`, `usb-watch`, `usb-storage` | `sashi usb` → `usb-monitor.sh` |
| `wifi`, `wifi-init`, `wifi-connect`, `wifi-scan`, `wifi-status`, `wifi-logcat` | `sashi wifi` → `wifi-debug.sh` |
| `sadb`, `sdev`, `slogcat` | `sashi adb` → `~/Android/platform-tools/adb` |
| `android-studio`, `side` | `sashi android-studio` → `mcp/ide/sashi-ide` (Python Rich TUI) |

### gRPC

| Alias | Backs To |
|-------|----------|
| `sgrpc`, `sgrpc-start`, `sgrpc-status` | `sashi grpc` → `grpc_server.py` :50051 |
| `sprobe`, `sprobe-list`, `sprobe-sync` | `sashi probe` → `probe_server.py` :50052 |

### Ollama Control

| Alias | Backs To |
|-------|----------|
| `ollama-up` | `ollama serve &>/dev/null &` |
| `ollama-down` | `pkill -f "ollama serve"` |
| `ollama-restart` | down + up |
| `ollama-logs` | `journalctl -u ollama` |
| `ollama-boost` | `scripts/ollama-boost.sh` |

### Navigation

| Alias | Backs To |
|-------|----------|
| `cds` | `cd ~/ollama-local` |
| `cdp` | `cd ~/persist-memory-probe` |
| `cdk` | `cd ~/kanban-pmo` |
| `cdf` | `cd ~/football-telemetry` |

### Git

| Alias | Command |
|-------|---------|
| `gs` | `git status -sb` |
| `gd` | `git diff` |
| `gds` | `git diff --staged` |
| `gl` | `git log --oneline -20` |
| `gla` | `git log --all --graph --oneline -30` |
| `ga/gaa/gap` | `git add` / `git add -A` / `git add -p` |
| `gc` | `git commit -m` |
| `gp/gpl` | `git push` / `git pull` |
| `gb/gco` | `git branch` / `git checkout` |
| `smartpush`, `sp`, `gpush` | `scripts/smart-push.sh` |

### Filesystem (30 aliases across 9 categories)

| Category | Aliases |
|----------|---------|
| Find/filter | `ff ffd ffl fmod fsize fnew fdup fempty fdangling` |
| Disk | `duh dua dut dfh dfio` |
| Listing | `lsl lst lsz lsd lsr` |
| Archive | `tarc tarx tarxv tarl tarbz zipr` |
| Copy/move/delete | `cpv cpvr mvv rmv rmrf` |
| Permissions | `chmodr chownr mkexec fixperms` |
| Symlinks | `lnr lna lslinks` |
| Checksum | `fhash fcheck mdiff mdiffu` |
| Watch | `fwatch fwatchp` |

---

## Android / USB Hello World

The `android-studio` alias (`side`) launches `mcp/ide/sashi-ide` — a Python Rich TUI
for managing Android/Kotlin projects. It requires a project path; the default is
`$HOME/projects/hello-android`.

**Current state:** The IDE binary exists and dependencies are installed (`rich`, `adb`
at `~/Android/platform-tools/adb`). The default project directory does not exist yet.

### Create a Hello World project and connect via USB

```bash
# 1. Create project directory
mkdir -p ~/projects/hello-android

# 2. Launch IDE
android-studio ~/projects/hello-android
# or: sashi android-studio ~/projects/hello-android

# 3. Check USB device is visible
sashi usb scan           # List USB devices
sashi adb status         # adb devices -l

# 4. If phone not shown, enable USB debugging on phone:
#    Settings → Developer options → USB debugging ON
#    Then: sashi adb status

# 5. Wireless ADB (optional, after USB pairing)
sashi adb wireless       # Switch device to tcpip mode
sashi wifi status        # Confirm wireless connection
```

### ADB path

```
~/Android/platform-tools/adb  (installed, executable)
```

If not installed: `bash ~/ollama-local/scripts/android-setup.sh`

---

## Performance Tuning

Benchmarked on i7-6500U (2C/4T, 7.6GB RAM, no GPU).

| Setting | Wrong | Right | Effect |
|---------|-------|-------|--------|
| `num_thread` | 4 | **2** | HT contention = 30% slower at 4 |
| CPU governor | `powersave` | **`performance`** | Prevents throttle mid-inference |
| `OLLAMA_MAX_LOADED_MODELS` | default | **1** | Prevents RAM contention |
| `OLLAMA_KEEP_ALIVE` | 5m | **30m** | Model stays hot |

```bash
# CPU governor (one-time, needs sudo)
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Ollama service tuning
sudo mkdir -p /etc/systemd/system/ollama.service.d
cat << 'EOF' | sudo tee /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=30m"
EOF
sudo systemctl daemon-reload && sudo systemctl restart ollama

# Or use the alias:
ollama-boost
```

| Model | tok/s (num_thread=2) | tok/s (num_thread=4) |
|-------|---------------------|---------------------|
| fast-sashi 3B | ~4.0 | ~2.8 (-30%) |
| sashi-llama-8b 8B | ~3.7 | ~3.0 (-19%) |

---

## SQLite Schema

Database: `~/ollama-local/db/history.db` (WAL mode, shared across 3 repos)

```sql
-- Query history
CREATE TABLE queries (
    id              INTEGER PRIMARY KEY,
    timestamp       DATETIME DEFAULT CURRENT_TIMESTAMP,
    model           TEXT,
    prompt          TEXT,
    response_length INTEGER,
    duration_ms     INTEGER
);

-- Starred queries
CREATE TABLE favorites (
    id       INTEGER PRIMARY KEY,
    query_id INTEGER REFERENCES queries(id),
    label    TEXT
);

-- MCP provider registry
CREATE TABLE mcp_groups (
    id          INTEGER PRIMARY KEY,
    name        TEXT UNIQUE,
    category    TEXT,
    description TEXT,
    config_path TEXT,
    enabled     INTEGER,
    created_at  DATETIME,
    updated_at  DATETIME
);

-- Smart push commit tracking
CREATE TABLE commits (
    id               INTEGER PRIMARY KEY,
    hash             TEXT,
    message          TEXT,
    auto_description TEXT,
    issue_number     TEXT,
    version_tag      TEXT,
    branch           TEXT,
    files_changed    INTEGER,
    lines_added      INTEGER,
    lines_deleted    INTEGER,
    categories       TEXT,
    timestamp        DATETIME,
    tree_backup      TEXT
);

-- CHANGELOG entries (populated by wallog)
CREATE TABLE changelog (
    id      INTEGER PRIMARY KEY,
    version TEXT,
    date    TEXT,
    summary TEXT
);
```

---

## JSONL Training Schema

Training data at `training/sashi_v5.2.0_master.jsonl`.
Format: ChatML — compatible with HuggingFace `datasets`, llama.cpp fine-tuning, and
direct Modelfile `TEMPLATE` injection.

```json
{
  "messages": [
    {"role": "system",  "content": "<sashi system prompt>"},
    {"role": "user",    "content": "<user query>"},
    {"role": "assistant","content": "<expected response>"}
  ]
}
```

### Domain Coverage (232 dialogs)

| Domain | Count | Source |
|--------|-------|--------|
| File operations (sashi file) | ~60 | lib/sh/file-ops.sh patterns |
| LLM write modes (sashi write) | ~60 | lib/sh/llm-write.sh patterns |
| Tool dispatch (ask/code/8b/grpc/probe) | ~50 | sashi command surface |
| Multi-ternary shell logic | ~32 | lib/sh/multiternary.sh |
| File-write + gRPC patterns | ~30 | probe.db export |

### Relationship to Modelfiles

`CHANGELOG.md` is injected verbatim into both `Modelfile.fast` and `Modelfile.8b`
system prompts at build time. This means the model's internal knowledge of its own
version history is derived from this file. Keep CHANGELOG accurate — it is a training
artifact, not just documentation.

---

## Version History

| Version | Date | Summary |
|---------|------|---------|
| v3.0.0 | 2026-02-08 | Three-repo foundation, shared SQLite WAL, gRPC contracts, DeepSeek removed |
| v3.1.0 | 2026-02-19 | banner.sh, aliases.sh, kanban CLI, smart-push, ai-orchestrator |
| v3.2.0 | 2026-02-22 | gRPC daemon manager, probe CLI, terminal IDE, 8B routing |
| v3.2.1 | 2026-03-01 | `sashi usb/wifi/hf`, USB vendor DB, WiFi ADB, HuggingFace fallback |
| v3.2.2 | 2026-03-01 | 30 filesystem aliases, `sashi wallog`, SVGs synced |
| **v5.2.0** | **2026-03-01** | **file-ops.sh (516L), llm-write.sh (227L), 232 training dialogs** |
| fix | 2026-03-11 | TERMUX_VERSION unbound var → `_OS_TYPE` from `uname -o` (c5af357) |

---

## Installation

```bash
# 1. Clone
git clone git@github.com:tmdev012/ollama-local.git ~/ollama-local

# 2. Base model + custom models
ollama pull llama3.2
ollama create fast-sashi -f ~/ollama-local/Modelfile.fast

# 3. 8B (needs 8GB+ swap)
ollama pull llama3.1:8b
ollama create sashi-llama-8b -f ~/ollama-local/Modelfile.8b

# 4. Shell aliases
echo 'source ~/ollama-local/lib/sh/aliases.sh' >> ~/.bashrc
echo 'source ~/ollama-local/lib/sh/aliases.sh' >> ~/.zshrc
source ~/.bashrc

# 5. Performance tuning
bash ~/ollama-local/scripts/ollama-boost.sh
```

---

## Tech Stack

| Component | Technology |
|-----------|------------|
| Shell | Bash (`set -uo pipefail`) + Zsh |
| Local AI | Ollama + Llama 3.2 3B / Llama 3.1 8B |
| Cloud AI | OpenRouter (free tier) → HuggingFace (fallback) |
| Database | SQLite 3 WAL (shared, 3 repos) |
| IPC | gRPC (kanban :50051, probe :50052) |
| Android | ADB + Android SDK 34 + platform-tools |
| IDE | Python Rich TUI (`mcp/ide/sashi-ide`) |
| VCS | Git + GitHub (tmdev012/ollama-local) |
| Auth | SSH ED25519 + Google OAuth (Gmail) |

---

*Maintained by tmdev012. Last updated: 2026-03-11*
