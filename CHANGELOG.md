# Sashi — Release Changelog

> **Sashi** is an AI-native CLI orchestration layer for local and remote LLM inference, providing
> MCP-compatible tool dispatch, gRPC-backed project intelligence, and a structured agentic write
> pipeline — designed to run fully offline on constrained hardware.
>
> This file is the single canonical release record. Injected into all model system prompts at build time.

---

## v3.2.3-patch — 2026-03-11
> **Critical: Unbound Variable Fix + SVG / README Sync**
>
> `set -uo pipefail` + bare `$TERMUX_VERSION` caused ~1hr startup downtime on every
> non-Android machine. All three occurrences replaced with `uname -o`-derived `_OS_TYPE`.
> DeepSeek purged from all diagrams (removed from code at v3.0.0, diagrams lagged).

### Bug Fixes
- **[CRITICAL]** `sashi` startup crash: `TERMUX_VERSION: unbound variable` under `set -u`
  — replaced all 3 bare `$TERMUX_VERSION` refs with `_OS_TYPE="$(uname -o)"` guard.
  `show_status()` now prints full `uname -a` for environment context. Commit: `c5af357`.

### Docs / Diagrams
- README fully rewritten for v3.2.3: three-repo stack, incident report, variable reference,
  JSONL training schema, Android/USB Hello World, multi-tenant update rule.
- `process-map-animated.svg`, `process-map.svg`: DeepSeek node → HuggingFace.
- `data-flow-animated.svg`, `data-flow.svg`: DeepSeek node → HuggingFace.
- All SVGs bumped v3.2.2 → v3.2.3. Desktop `SASHI-CHANGELOG.md` synced.

---

## v3.2.3 — 2026-03-01
> **LLM-Integrated File I/O + Training Corpus Finalization**
>
> Introduced a two-layer file I/O architecture: a POSIX-safe operations library and an LLM-in-the-loop
> write pipeline that routes inference through the local model before committing output to disk. Shipped
> the v3.2.3 master training corpus for HuggingFace fine-tuning.

### Features
- **`sashi file <op>`** — 17 structured file-operation subcommands (info, detect, check, read, write,
  append, parse, copy, move, delete, batch, recover, stream, split, join, rotate) exposing a consistent
  MCP-style tool interface over the local filesystem.
- **`sashi write` extended modes** — seven write strategies: `--read` (LLM-mediated rewrite),
  `--append` (flock-safe concurrent append), `--batch` (glob-targeted), `--fmt` (schema-validated output
  for json/csv/md/sh), `--safe` (write-with-fallback), `--pipe` (stdin passthrough).
- **`lib/sh/file-ops.sh`** — low-level file operations library covering 9 operation categories with
  atomic write, rotate, parse, stream, split, and join primitives.
- **`lib/sh/llm-write.sh`** — agentic write pipeline library: `llmw_write` (atomic), `llmw_process`
  (read → llama → write), `llmw_append` (flock-safe), `llmw_batch` (glob-scoped), `llmw_write_fmt`
  (format-validated), `llmw_pipe` (stdin), `llmw_safe_write` (graceful degradation).
- **27 shell aliases** — `sfile-*` (17) and `swrite-*` (10) alias groups registered in `lib/sh/aliases.sh`.

### Training & Model Layer
- **`training/sashi_v3.2.3_master.jsonl`** — 232-dialog ChatML dataset covering file-ops, LLM write
  modes, and tool-dispatch patterns. Formatted for direct HuggingFace `datasets` ingestion.
- **`training/README.md`** — Dataset card with YAML frontmatter, schema documentation, and split rationale.
- Both Modelfiles rebuilt from updated corpus: `fast-sashi:latest` + `sashi-llama-8b:latest`.

### Bug Fixes / Reliability
- **[CRITICAL]** Resolved broken inference fallback in `lib/sh/llm-write.sh` — fallback model name
  `sashi-llama-fast` corrected to canonical `fast-sashi`; silent failures on degraded-path writes
  eliminated.
- Synchronized all version references across `Modelfile.fast` and `Modelfile.8b` to prevent
  model-version drift between CLI and loaded system prompts.
- Restored missing `wallog` entry in `sashi help` output.

---

## v3.2.2 — 2026-03-01
> **Observability Layer + Filesystem Ergonomics**
>
> Added a unified audit surface correlating git history, SQL WAL state, and changelog records in a
> single command. Shipped a comprehensive filesystem alias library covering find, disk, archive,
> permissions, symlinks, checksumming, and real-time watch operations.

### Features
- **`sashi wallog [N]`** — four-section audit command providing: model file git history (tagged by
  model variant), changelog table entries from history.db, commit provenance records, and live WAL
  checkpoint status with file-size reporting. Replaces ad-hoc `git log` + `sqlite3` inspection.
- **`swallog`** — short-form alias.
- **Filesystem alias library** (30 aliases across 9 categories in `lib/sh/aliases.sh`):
  find/filter, disk usage, directory listing, archiving, copy/move/delete, permissions management,
  symlink inspection, checksum/diff, and real-time filesystem watch.

### Developer Experience
- Architecture diagrams synced to v3.2.2: `bdpm-swimlanes.svg`, `kanban-architecture.svg`,
  `process-map-animated.svg`.
- README version badge and alias reference section updated.

---

## v3.2.1 — 2026-03-01
> **Hardware I/O Tooling + Multi-Provider Inference Fallback**
>
> Extended the tool dispatch surface to physical hardware: USB device enumeration via sysfs and
> ADB-based WiFi debugging. Added HuggingFace Inference API as a graceful fallback inference
> provider for environments without a local OpenRouter key.

### Features
- **`sashi usb [scan|watch|storage|details|tree|search|export]`** — USB device intelligence via
  sysfs and lsusb, including vendor identification (Huawei, Samsung, Arduino, STM32, and others),
  real-time attach/detach watch, and structured export.
- **`sashi wifi [init|connect|scan|status|logcat|shell]`** — ADB WiFi wireless debugging: auto IP
  detection, LAN scanning via nmap/arp, tcpip handshake flow, logcat streaming, and interactive shell.
- **`sashi hf <prompt>`** — HuggingFace Inference API integration (free tier). Acts as a secondary
  inference provider when no OpenRouter key is present, ensuring `online_query()` never silently
  fails.

### Infrastructure
- `lib/sh/usb-monitor.sh` — sysfs-native USB scanner with embedded vendor database and inotify watch.
- `lib/sh/wifi-debug.sh` — ADB WiFi automation library with network probe utilities.
- `online_query()` updated to cascade: OpenRouter → HuggingFace → local model, with explicit
  provider attribution in output.

### Reliability
- Restored `lib/sh/banner.sh` (had been zeroed); `sashi_banner()` now reliably sourced by all tools.
- Restored full alias set in `lib/sh/aliases.sh` after partial loss in prior session.

---

## v3.2.0 — 2026-02-22
> **gRPC Service Mesh + Probe Intelligence Layer**
>
> Promoted gRPC from a stub to a first-class runtime: dual-port daemon management (:50051/:50052),
> a probe intelligence CLI wired to a live gRPC server, and a terminal Android/Kotlin IDE. Resolved
> a model data loss incident and trained out a reproducible 3B hallucination pattern.

### Features
- **`sashi grpc [start|stop|restart|status|logs]`** — unified process lifecycle manager for both
  gRPC servers, replacing manual process management.
- **`sashi probe [sync|list|recommend|export|write|status]`** — full probe intelligence CLI over
  gRPC, providing repo scanning, credential introspection, training data export, and recommendation
  queries against `persist-memory-probe`.
- **`sashi 8b <prompt>`** — explicit 8B model routing, bypassing the 3B fast path for
  higher-quality inference on complex prompts.
- **`sashi ide [project]`** — terminal-native Android/Kotlin IDE: Rich TUI, Monokai syntax theme,
  ADB device watcher, project scaffold navigation.
- **`probe_server.py`** — production gRPC server on :50052 implementing RepoService,
  CredentialService, and TrainingService over probe.db.
- **245 structured training dialogs** in probe.db across four domains: multi-ternary logic (79),
  file-write/gRPC patterns (60), system Q&A (56), Android IDE interaction (50).

### Infrastructure
- `android-setup.sh` — automated Android SDK, platform-tools, and adb provisioning.
- `CHANGELOG.md` established as canonical release record; symlinked to Desktop for ambient
  visibility. Injected into both Modelfile system prompts at build.
- `sashi status` extended to surface gRPC server health alongside model and history metrics.

### Bug Fixes / Reliability
- **[DATA LOSS]** `Modelfile.8b` zeroed by `sed` version-bump operation — fully rebuilt from
  scratch. Automated model integrity check added to version bump workflow.
- Eliminated reproducible 3B hallucination: process substitution (`<(...)`) incorrectly generated
  in place of pipe (`|`) — trained out via targeted dialog pairs in corpus.
- Resolved double-output on `sashi probe status` in non-TTY contexts using `< /dev/null` stdin
  suppression pattern.

### Removed
- **Co-Authored-By trailers** purged from 68 commits across 7 repos via `git-filter-repo` rewrite.
- **DeepSeek integration** permanently removed (decommissioned 2026-02-08).

---

## v3.1.0 — 2026-02-19
> **Cross-Repo Version Authority + Kanban Integration**
>
> Established a single version source of truth across all tools, wired the ProbeSyncServicer to
> live integration data, and promoted the kanban board to a first-class CLI surface.

### Features
- **`sashi kanban [board|state|backlog|wip|open|closed]`** — kanban board CLI backed by the
  kanban-pmo gRPC authority, surfacing project state without leaving the terminal.
- **`scripts/smart-push.sh`** — git automation script providing branch validation, conflict
  detection, SQLite commit tracking, and push confirmation workflow.
- **`mcp/llama/tools/ai-orchestrator`** v3.1.0 — consolidated inference orchestrator sourcing
  shared banner and version from canonical CLI.

### Infrastructure
- **`lib/sh/banner.sh`** — extracted `sashi_banner()` into a shared library, eliminating
  duplicated banner logic across tools.
- gRPC Python stubs generated from proto definitions: `kanban_pb2.py`, `kanban_pb2_grpc.py`.
- ProbeSyncServicer wired to `integrate.py` — previously a hollow stub with no backing data source.
- Version singleton: all tools now resolve VERSION by sourcing the sashi CLI, eliminating
  out-of-sync version strings across the ecosystem.
- `lib/sh/aliases.sh` promoted to single source of truth for all shell aliases.

---

## v3.0.0 — 2026-02-08
> **Three-Repo Ecosystem Foundation**
>
> Established the core architecture: a tri-repo workspace sharing a single SQLite WAL database,
> a gRPC service contract between repos, and the sashi CLI as the unified operator interface.

### Features
- **`sashi` CLI** — core command surface: `ask`, `code`, `chat`, `write`, `history`, `status`,
  `models`. Unified entrypoint to all local inference and repo operations.
- **`lib/sh/multiternary.sh`** — `multiternary()` and `range_ternary()` — composable conditional
  evaluation helpers for complex shell logic; form the basis of downstream training dialogs.
- **Shared `history.db`** — SQLite in WAL mode, symlinked across all three repos. Single source
  of truth for inference history, commit provenance, and changelog records.
- **gRPC service contracts** — `kanban.proto` + `probe.proto` define the inter-repo service
  boundary between ollama-local, kanban-pmo, and persist-memory-probe.
- **11 repos registered** in `kanban-pmo/config/repos.yml` — full project inventory under
  kanban-pmo governance.

### Removed
- DeepSeek integration decommissioned. API key expired; provider removed from all inference paths.

---

*Maintained by tmdev012. Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) +
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).*
