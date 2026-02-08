# SASHI / ollama-local Changelog

## Pre-Session State Archive (2026-02-05 b55cee5)

**Archived to:** `old-archive/` (restorable via `git show HEAD:<file>`)

| Artifact | Archive Path | Restore |
|----------|-------------|---------|
| CHANGELOG v2.0 | `old-archive/CHANGELOG-v2.0-pre-session.md` | `git checkout HEAD -- CHANGELOG.md` |
| sashi v2.0 | `old-archive/sashi-v2.0-pre-session.sh` | `git checkout HEAD -- sashi` |
| .env (with deepseek) | `old-archive/env-pre-session.txt` | `git checkout HEAD -- .env` |
| .gitignore (original) | `old-archive/gitignore-pre-session.txt` | `git checkout HEAD -- .gitignore` |
| Full file tree | `old-archive/tree-pre-session-b55cee5.txt` | `git stash pop` equivalent |

### Pre-Session File Count: 56 tracked files
### Post-Session File Count: 69 files

### Pre-Session Tree (committed at b55cee5)

```
ollama-local/ (249MB, 56 tracked files)
├── sashi                    # v2.0 CLI (deepseek + llama dual router)
├── .env                     # DEEPSEEK_API_KEY present, DEFAULT_MODEL=deepseek-chat
├── .gitignore               # 5 rules (.env, *.key, logs, db, .DS_Store)
├── install.sh               # one-command installer
├── Dockerfile               # ubuntu 24.04 + ollama
├── docker-compose.yml       # sashi-ai service
├── README.md                # 20K comprehensive docs
├── CHANGELOG.md             # v2.0 session report
├── history.txt              # 361 lines command history
├── lastseen.md              # session notes
├── alist-v0.3.txt           # resource listing
│
├── db/
│   └── history.db           # 68KB, 4 tables (queries, favorites, mcp_groups, commits)
│                            # 11 indexes
│
├── mcp/
│   ├── claude/              # config + matt-pocock-workflow.md
│   ├── deepseek/            # 5 tools (ask, chat, deepseek.sh, deepseek-cli, deepseek-check.sh)
│   │                        # config/model.json (v3, /usr/bin/zsh.14/M tokens, 64K context)
│   ├── llama/               # 5 tools (ai-code, ai-fast, ai-general, ai-orchestrator, ollama-chat.sh)
│   │                        # config/model.json (v3.2, 2GB, 8192 context)
│   ├── gmail/               # 7 tools (gmail-cli, setup, gcp, oauth, service-account)
│   │                        # config/service-account.json (EMPTY - 0 bytes)
│   └── voice/               # 3 tools (voice-input, voice-gui, install-voice)
│                            # config/model.json (google-speech)
│
├── scripts/
│   ├── git-setup.sh         # SSH/GitHub interactive setup
│   ├── git-aliases.sh       # git alias installer
│   ├── smart-push.sh        # auto-categorize + version tag + sqlite tracking
│   └── termux-sync.sh       # cross-device backup
│
├── archive/                 # 244KB old backups (ai-orchestrator, ai-system tarballs)
├── backups/                 # 6 tree snapshots (tree_*.txt)
├── docs/diagrams/           # 6 SVGs (data-flow, process-map, smart-push, animated variants)
├── logs/                    # empty
│
├── node_modules/            # 184MB - 23,000+ files - NO package.json
│   ├── abort-controller/    #   orphaned npm dependency tree
│   ├── acorn/               #   antlr4, chevrotain, lodash-es, anymatch...
│   ├── agent-base/          #   AWS resource icons (Res_Amazon-*.js)
│   ├── antlr4/              #   parser generators, DFA serializers
│   ├── @chevrotain/         #   CST generators, prediction contexts
│   └── ... (500+ packages) #   TOTAL: 184MB of unused JavaScript
│
├── kafka/                   # 2 items (unknown purpose)
├── git/                     # 2 items
├── git-snippets/            # 2 items
├── show/                    # 2 items
└── 4c1981b/                 # directory (possibly from git hash)
```

### What The 1000+ Files Actually Were

The node_modules/ directory contained full npm dependency trees including:
- **antlr4** - Parser generator (ATN simulators, DFA states, prediction contexts)
- **@chevrotain** - CST/DST generators with lodash-es vendored
- **AWS Resource icons** - Hundreds of `Res_Amazon-*.js` files (EventBridge, RDS, Redshift, Route53, OpenSearch, etc.)
- **abort-controller, agent-base, anymatch, any-promise** - Node.js utility packages

None of these were referenced by sashi (pure bash), had no package.json, and consumed 184MB / 23,000+ files.

---

## Session 2026-02-08 (v2.0 -> v3.0)

### Deletions (192MB recovered)

| Deleted | Size | Files | Reason |
|---------|------|-------|--------|
| `node_modules/` | 184MB | 23,000+ | Orphaned, no package.json |
| `mcp/deepseek/` | ~15KB | 6 | Cloud API costs money |
| `archive/` | 244KB | ~10 | Already in git history |
| `~/.claude/debug/` | 7.8MB | 13 | Regenerated per session |

### Additions (modular framework)

| Added | Purpose | CMMI |
|-------|---------|------|
| `lib/py/sashi_db.py` | Single CRUD surface (18 cmds, 10 tables, 27 idx) | L4-measurement |
| `lib/sh/aliases/` | 6 grouped alias files + loader | L3-defined |
| `lib/sh/env-guard.sh` | Pre-commit hook blocks secrets | L4-process-control |
| `lib/sh/git-autonomous.sh` | Lombok-style repo creation | L4-standardization |
| `config/weekend-tasks.json` | 8 tasks exported as JSON | L4-quantitative |
| `docs/FAQ.md` | Heredoc Q&A | L3-documented |
| `old-archive/` | Pre-session state (restorable) | L4-audit |

### sashi v2.0 -> v3.0

| Change | v2.0 (before) | v3.0 (after) |
|--------|--------------|-------------|
| Default model | deepseek-chat (cloud) | llama3.2 (local) |
| Prompt cache | None | SQLite MD5 hash (0ms) |
| Cost | $0.14/M tokens | $0 |
| Tables | 4 | 10 |
| Indexes | 11 | 27 |
| Alias location | Inline .bashrc (250 lines) | lib/sh/aliases/ (6 files) |
| Cross-repo | Isolated | Symlinked (3 repos) |
| Secret guard | None | Pre-commit hook |

### Matt Pocock grpc Mapping

Matt's pattern: plan -> execute -> preserve context -> review diffs

grpc services in `persist-memory-probe/webhooks/grpc/probe.proto`:
- **RepoService** (SyncRepo, SyncAll, GetStatus) -> `sashi_db.py sync-*`
- **CredentialService** (GetRecommendation, LogUsage) -> `sashi_db.py cred-*`
- **TrainingService** (ExportTrainingData, GetContext) -> `sashi_db.py bridge-*`

The proto defines the contract. sashi_db.py implements it locally via SQLite.
grpc would be the wire protocol if/when this goes multi-node.

### Glossary (30 terms)

| # | Term | Definition |
|---|------|-----------|
| 1 | MCP | Model Context Protocol - modular AI provider framework |
| 2 | SASHI | Smart AI Shell Interface - main CLI router |
| 3 | Ollama | Local LLM runtime, HTTP API on :11434 |
| 4 | llama3.2 | Meta 2GB local model, primary in v3 |
| 5 | SQLite | Embedded DB, WAL mode for async |
| 6 | WAL | Write-Ahead Logging, concurrent read/write |
| 7 | Prompt cache | MD5 hash table, 0ms repeat queries |
| 8 | Symlink | Filesystem pointer, one file many repos |
| 9 | Heredoc | Shell inline string (<<'EOF') |
| 10 | CMMI | Capability Maturity Model Integration |
| 11 | Lombok | Auto-wiring pattern (credential auto-select) |
| 12 | grpc | Google RPC, binary protocol |
| 13 | Proto | Protocol Buffers definition (.proto) |
| 14 | PAT | Personal Access Token (GitHub API) |
| 15 | GPG | GNU Privacy Guard (commit signing) |
| 16 | SSH | Secure Shell (key auth for git) |
| 17 | ED25519 | Elliptic curve SSH key algorithm |
| 18 | Pre-commit | Git hook, runs before commit |
| 19 | Async | Non-blocking background operation |
| 20 | JSONL | JSON Lines, one object per line |
| 21 | Cron | Scheduled task runner |
| 22 | Pipe | Unix stdin chaining (\|) |
| 23 | Alias | Shell shortcut to full command |
| 24 | Loader | Single source file for all alias groups |
| 25 | Bridge | JSONL->SQLite session sync |
| 26 | env-guard | Pre-commit hook blocking secrets |
| 27 | Termux | Android terminal, sync target |
| 28 | Docker | Container runtime |
| 29 | Smart-push | Auto-categorize git commits + SQLite |
| 30 | Scope creep | Unplanned growth, extracted as test case |

### Keyboard Shortcuts

| Key | Context | Action |
|-----|---------|--------|
| Shift+Tab | Claude CLI | Cycle completions |
| Ctrl+O | Claude CLI | Open file in editor |
| Ctrl+E | Claude CLI | End of line / toggle edit |
| --interactive | sashi suffix | Enter chat loop |

### curl vs grep

| | curl | grep |
|-|------|------|
| Domain | Network (HTTP API) | Filesystem (content search) |
| In sashi | `curl localhost:11434/api/generate` | Not used (SQLite instead) |
| Speed | ~2.2s (model inference) | <1ms (OS file cache) |
| Cacheable | Yes (prompt_cache) | No (live scan) |
| Replaced by | prompt_cache (0ms on hit) | SQLite indexed SELECT |

### .config vs .ini

| | .config (JSON) | .ini |
|-|---------------|------|
| Structure | Nested objects | Flat sections |
| SASHI use | `mcp/*/config/model.json` | `persist-memory-probe/config/*.ini` |
| Parse | `jq` / `json.load()` | `configparser` / `grep` |
| When | Complex params | Simple key=value lists |

### Weekend Tasks (8/8 done)

| # | Task | CMMI | Done |
|---|------|------|------|
| 1 | Enforce .gitignore across all repos | L4-measurement | Y |
| 2 | Install env-guard pre-commit hook | L4-process-control | Y |
| 3 | Sync claude sessions to SQLite | L4-quantitative | Y |
| 4 | Prompt cache for llama3.2 | L4-performance | Y |
| 5 | Consolidate aliases to dir | L3-defined | Y |
| 6 | Remove deepseek, zero cost | L4-cost-control | Y |
| 7 | Symlink across repos | L4-standardization | Y |
| 8 | Credential lombok | L4-audit | Y |

### FAQ

**Q: Can I restore the pre-session state?**
A: `cd ~/ollama-local && git checkout HEAD -- .` restores all tracked files. Or copy from `old-archive/`.

**Q: Where did node_modules come from?**
A: Orphaned npm install. No package.json. 184MB of AWS icons, parsers, lodash. Never used by sashi.

**Q: Why archive instead of delete?**
A: `old-archive/` keeps pre-session snapshots. Git history has the rest. Scope creep = test case, not permanent.

**Q: What's the node_modules Res_Amazon-*.js files?**
A: AWS Architecture Icons package. JavaScript SVG components for EventBridge, RDS, Redshift, Route53, OpenSearch, etc. Not related to SASHI.

---

## Bash History Trace (1000+ line commit story)

**Source:** `history.txt` (361 lines) + `~/.bash_history`
**Archived:** `old-archive/history-full-trace.txt`

### Timeline: How 1000+ files accumulated

```
# Day 1: Claude CLI installed, token exported (leaked to OAuth.txt - env-guard now blocks this)
291  curl -fsSL https://claude.ai/install.sh | bash
293  claude setup-token
294  sk-ant-oat01-... > OAuth.txt          # SECRET LEAKED TO FILE (now blocked by env-guard)

# Day 1: AI orchestrator exploration
299  ai-orchestrator --interactive
302  ai-orchestrator --interactive          # ran twice (no cache, 5-8s each)
306  ai-orchestrator --interactive          # ran AGAIN (with cache: would be 0ms)

# Day 1: Audio setup (scope creep - not AI related)
310  sudo apt install qjackctl
311  mkdir -p ~/.config/pipewire/pipewire.conf.d
313  sudo usermod -aG audio $USER

# Day 2: First git operations
320  cd ollama-local; tree; git status
321  git add .                              # THIS added node_modules/ (184MB)
328  git add .                              # did it AGAIN
330  source ~/.zshrc                        # aliases loaded (250 inline lines)
336  smartpush                              # pushed 23,000+ files to remote
```

### The node_modules incident

`git add .` at line 321/328 staged `node_modules/` (184MB, 23,000+ files).
No `.gitignore` rule blocked it at the time. Original `.gitignore` was only:

```
.env
*.key
logs/*.log
db/*.db
.DS_Store
*.swp
archive/
```

Missing: `node_modules/`, `*.credentials*`, `*.pem`, `service-account.json`

**v3.0 fix:** `env-guard.sh` pre-commit hook + CMMI4-enforced `.gitignore` with 9 rules.

### The OAuth token incident

Line 294: `sk-ant-oat01-... > OAuth.txt` wrote an OAuth token to a plain text file.
Line 295-297: Attempted to `export` the token as an env var (wrong syntax).

**v3.0 fix:** `env-guard.sh` blocks `*.credentials*`, `OAuth.txt` patterns.
`.gitignore` now includes `*.credentials*` across all 3 repos.

### Scope creep extracted as test case

| History Line | Action | Classification |
|-------------|--------|---------------|
| 291-298 | Claude CLI install + token | Core setup |
| 299-309 | AI orchestrator testing | Core usage |
| 310-318 | PipeWire audio + qjackctl | Scope creep (audio, not AI) |
| 319 | pip3 install google-auth | Gmail module dep |
| 320-336 | Git operations + smartpush | Core git |
| 321,328 | `git add .` (staged node_modules) | Incident |

### Test Case: Monolithic Repo Anti-Pattern

**Symptoms:**
1. `git add .` without proper `.gitignore` -> 23,000 unwanted files
2. No pre-commit hook -> secrets committed (OAuth.txt)
3. Aliases inline in `.bashrc` (250 lines) -> duplicates, breakage
4. No prompt cache -> same query re-runs at full inference cost
5. Cloud API as default -> costs money when local works

**Fixes applied (v3.0):**
1. `.gitignore` enforced across 3 repos (9 rules, CMMI4)
2. `env-guard.sh` pre-commit hook blocks secrets
3. Aliases moved to `lib/sh/aliases/` (6 sourced files)
4. SQLite prompt cache (MD5 hash, 0ms repeat, 27 indexes)
5. Deepseek removed, llama3.2 primary, $0 cost

**Verification:**
```bash
# Prove env-guard blocks secrets
echo "test" > .env.test && git add .env.test
# env-guard.sh exits 1: "BLOCKED: .env.test"

# Prove cache works
sashi ask "what is grpc"     # ~2.2s (cold, ollama inference)
sashi ask "what is grpc"     # ~0ms  (cached, SQLite hash hit)

# Prove aliases load from dir not bashrc
grep -c "alias" ~/.bashrc    # 4 (only ls/grep/fgrep/egrep system defaults)
grep -c "alias" ~/.zshrc     # 0
ls lib/sh/aliases/            # core.sh git.sh nav.sh ollama.sh pipe.sh loader.sh
```
