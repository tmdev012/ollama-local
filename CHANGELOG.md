# SASHI v0.5.0 — Providerless Roadworthy IDE

Run: 20260610-085622

Added:
- providerless IDE baseline
- provider registry
- Ollama/Gemini/Antigravity/OpenClaw lanes
- roadworthy test harness
- cache queue smoke path
- archive smoke path
- PMO Ollama Modelfile + JSONL eval seed

Safety:
- missing provider falls back to none
- no destructive file operations
- old Sashi command preserved as legacy path when detectable

## v0.5.0 — Roadworthy Providerless IDE Baseline

Passed:
- providerless IDE boot
- provider discovery
- provider failover
- cache queue smoke
- archive dry-run smoke
- evidence write
- Ollama PMO Modelfile present
- PMO JSONL task seed present

Provider state:
- none: ok
- ollama: ok
- openclaw: ok
- gemini-cli: optional missing
- antigravity: optional missing

Decision:
- freeze providerless mode as mandatory baseline
- treat Ollama and OpenClaw as current working provider lanes
- treat Gemini CLI and Antigravity as optional future plugins
