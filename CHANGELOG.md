# Sashi CHANGELOG
> Single source of truth. Symlinked to Desktop. Injected into both model system prompts at build.

---

## v3.2.1 — 2026-03-01

### Added
- `sashi usb [scan|watch|storage|details|tree|search|export]` — full USB device detection (sysfs + lsusb)
- `sashi wifi [init|connect|scan|status|logcat|shell]` — ADB WiFi wireless debugging
- `sashi hf <prompt>` — HuggingFace Inference API (free tier, fallback when no OpenRouter key)
- `lib/sh/usb-monitor.sh` — vendor DB (Huawei/Samsung/Arduino/STM32/etc), sysfs scan, real-time watch
- `lib/sh/wifi-debug.sh` — auto IP detect, nmap/arp LAN scan, tcpip init flow

### Changed
- `Modelfile.fast` v4.2 — USB/WiFi/HF docs added to system prompt, version bumped
- `Modelfile.8b` — version bumped to 3.2.1, USB/WiFi/HF commands added
- `online_query()` — falls back to HuggingFace Inference API when OpenRouter key absent
- `lib/sh/banner.sh` — restored sashi_banner() (was 0 bytes)
- `lib/sh/aliases.sh` — restored all aliases incl. usb-scan, wifi-*, s8b, sp
- VERSION: 3.2.0 → 3.2.1

---

## v3.2.0 — 2026-02-22

### Added
- `sashi grpc start/stop/restart/status/logs` — unified daemon manager for :50051 + :50052
- `sashi probe sync/list/recommend/export/write/status` — full probe CLI via gRPC
- `sashi ide [project]` — terminal Android/Kotlin IDE (rich TUI, monokai, ADB watcher)
- `sashi 8b <prompt>` — routes to sashi-llama-8b (8B quality model)
- `android-setup.sh` — downloads + installs Android SDK, platform-tools, adb
- `probe_server.py` — gRPC :50052 (RepoService, CredentialService, TrainingService)
- 245 training dialogs in probe.db (multi_ternary:79, filewrite_grpc:60, system_qa:56, android_ide:50)
- `CHANGELOG.md` — single canonical changelog, symlinked to Desktop

### Changed
- `Modelfile.fast` bumped to v4.1 — gRPC + probe + IDE + Android docs added
- `Modelfile.8b` rebuilt from scratch — multi-ternary as core section, temp 0.25, num_ctx 4096
- All version strings v3.0.0/v3.1.0 → v3.2.0 across all repos, SVGs, MDs
- `sashi status` now shows gRPC server health + latest changelog entry

### Fixed
- Modelfile.8b was wiped to 0 bytes during sed version bump — fully rebuilt
- 3B hallucination: `<(process substitution)` instead of `|` pipe — trained out
- sashi probe status double output in non-tty — fixed with `< /dev/null` pattern

### Removed
- Co-Authored-By from 68 commits across 7 repos (git-filter-repo rewrite)
- DeepSeek: permanently removed 2026-02-08

---

## v3.1.0 — 2026-02-19

### Added
- `sashi kanban board/state/backlog/wip/open/closed` subcommand
- `lib/sh/banner.sh` — shared sashi_banner() ASCII art sourced by all tools
- `mcp/llama/tools/ai-orchestrator` v3.1.0 — sources banner.sh
- `scripts/smart-push.sh` — 424-line git automation with SQLite tracking
- gRPC stubs generated: kanban_pb2.py, kanban_pb2_grpc.py
- ProbeSyncServicer wired to integrate.py (was hollow stub)

### Changed
- Version system: all tools now source VERSION from sashi CLI
- aliases.sh — single source for all shell aliases (s8b, skanban, etc.)

---

## v3.0.0 — 2026-02-08

### Added
- Three-repo ecosystem: ollama-local + kanban-pmo + persist-memory-probe
- Shared SQLite history.db (WAL mode, symlinked across all repos)
- `sashi ask/code/chat/write/history/status/models` core CLI
- `lib/sh/multiternary.sh` — multiternary() + range_ternary() Bash helpers
- kanban.proto + probe.proto — gRPC service definitions
- 11 repos registered in kanban-pmo/config/repos.yml

### Removed
- DeepSeek integration (API key expired, removed permanently)
