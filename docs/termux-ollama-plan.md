# Termux + Ollama Plan

## What the 8GB Swap Unlocks

Desktop now has 15.6GB addressable (7.6GB RAM + 8GB swap).

| Model | Params | Size (Q4) | RAM Needed | Desktop | Termux | Notes |
|-------|--------|-----------|------------|---------|--------|-------|
| llama3.2:1b | 1B | 1.3GB | ~2GB | ✅ fast | ✅ best fit | Ideal for phones |
| llama3.2:3b | 3B | 2.0GB | ~3GB | ✅ current | ✅ 6GB+ phone | Current sashi model |
| phi4-mini | 3.8B | 2.5GB | ~4GB | ✅ fast | ⚠️ tight | Microsoft, strong coding |
| smollm2:1.7b | 1.7B | 1.0GB | ~2GB | ✅ fast | ✅ best fit | Beats llama3.2:1b in accuracy |
| gemma3:4b | 4B | 2.5GB | ~4GB | ✅ good | ⚠️ tight | Google, multimodal |
| llama3.1:8b | 8B | 4.7GB | ~6GB | ✅ NEW w/swap | ❌ too big | Major upgrade - now possible |
| qwen2.5:7b | 7B | 4.4GB | ~6GB | ✅ NEW w/swap | ❌ too big | Strong reasoning |
| llama4:scout | 17B active | 67GB | ~70GB | ❌ impossible | ❌ impossible | Needs H100 GPU |

### Key Takeaway
- **Desktop**: llama3.1:8b Q4 is now viable with swap. 2x the brains of llama3.2:3b.
- **Termux**: llama3.2:1b or smollm2:1.7b. Stay under 2GB model size.
- **Llama 4**: Dead on arrival for this hardware. Not even close.

---

## Termux Setup Guide

### Prerequisites
- Android phone with 4GB+ RAM
- Termux from **F-Droid or GitHub** (NOT Google Play - that version is broken)
- ~3GB free storage

### Install Steps

```bash
# 1. Install Termux from F-Droid
# https://f-droid.org/en/packages/com.termux/

# 2. Update packages
pkg update && pkg upgrade -y

# 3. Install ollama (now in Termux repos)
pkg install ollama

# 4. Start ollama server
ollama serve &

# 5. Pull the right model for your phone
# 4GB RAM phone:
ollama pull llama3.2:1b

# 6GB+ RAM phone:
ollama pull llama3.2:3b

# 6. Test it
ollama run llama3.2:1b "hello from termux"
```

### Sashi on Termux

```bash
# 1. Install git + clone repo
pkg install git openssh
git clone git@github.com:tmdev012/ollama-local.git ~/ollama-local

# 2. Pull configs from desktop
cd ~/ollama-local
bash scripts/termux-sync.sh pull

# 3. Create Termux-specific .env override
cat > ~/ollama-local/.env.termux << 'TERMUX'
LOCAL_MODEL=llama3.2:1b
OLLAMA_HOST=http://localhost:11434
SASHI_HOME=$HOME/ollama-local
SASHI_DB=$HOME/ollama-local/db/history.db
TERMUX=true
TERMUX'

# 4. Link sashi
ln -sf ~/ollama-local/sashi ~/bin/sashi

# 5. Test
sashi ask "what device am I on?"
```

### Termux Model Strategy

| Phone RAM | Model | Context | Speed |
|-----------|-------|---------|-------|
| 3-4GB | smollm2:1.7b | 2048 | Fast |
| 4-6GB | llama3.2:1b | 2048 | Fast |
| 6-8GB | llama3.2:3b | 2048 | Medium |
| 8GB+ | llama3.2:3b | 4096 | Medium |

### Sync Between Desktop <-> Termux

The `scripts/termux-sync.sh` already handles config sync.
SQLite DB can sync via git (WAL mode, single-writer safe).

```
Desktop (Ubuntu)                    Phone (Termux)
┌────────────────┐                 ┌────────────────┐
│ sashi v3.0     │   git push/    │ sashi v3.0     │
│ llama3.1:8b    │◄──pull─────────►│ llama3.2:1b    │
│ 15.6GB total   │                │ 4-8GB RAM      │
│ history.db     │   termux-sync  │ history.db     │
└────────────────┘                └────────────────┘
```

---

## Desktop Model Upgrade Path (enabled by swap)

### Phase 1: Now
```bash
# Pull llama3.1:8b (the swap makes this possible)
ollama pull llama3.1:8b

# Test it
ollama run llama3.1:8b "explain the difference between you and llama3.2:3b"

# Benchmark against current model
time ollama run sashi-llama "write a python function to parse JSON" --verbose
time ollama run llama3.1:8b "write a python function to parse JSON" --verbose
```

### Phase 2: If 8B works well
```bash
# Create sashi-llama-8b with system prompt
cat > ~/ollama-local/Modelfile.8b << 'MF'
FROM llama3.1:8b
SYSTEM """<copy system prompt from Modelfile.system, update RAM line>"""
PARAMETER temperature 0.7
PARAMETER num_ctx 4096
MF

ollama create sashi-llama-8b -f ~/ollama-local/Modelfile.8b

# Update .env
# LOCAL_MODEL=sashi-llama-8b
```

### Phase 3: Try other strong small models
```bash
ollama pull phi4-mini      # 3.8B, strong at coding
ollama pull qwen2.5:7b     # 7B, strong reasoning
ollama pull gemma3:4b      # 4B, multimodal
```

---

## What's NOT Viable

| Model | Why Not |
|-------|---------|
| llama4:scout | 67GB Q4 - needs enterprise GPU |
| llama4:maverick | Even bigger |
| llama3.1:70b | 40GB+ Q4 |
| deepseek-r1:7b | Works but DeepSeek is dead to us |
| Any 14B+ model | Swap thrashing, unusable speed |

---

## Release Checklist

- [ ] Pull llama3.1:8b on desktop
- [ ] Benchmark 8b vs 3b (speed, quality)
- [ ] Create Modelfile.8b if 8b passes
- [ ] Test sashi with .env.termux override
- [ ] Install Termux + ollama on phone
- [ ] Run termux-sync pull on phone
- [ ] Verify history.db syncs clean
- [ ] Update CHANGELOG
- [ ] Commit + push
