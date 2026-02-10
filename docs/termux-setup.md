# Ollama on Termux (Android) Setup Guide

## Prerequisites
- Android phone with 4GB+ RAM
- Termux from F-Droid (NOT Play Store - Play Store version is outdated)
- ~3GB free storage for ollama + llama3.2

## Option A: Full Local Ollama (6GB+ RAM recommended)

Steps:
```bash
# In Termux:
pkg update && pkg install golang cmake git
git clone https://github.com/ollama/ollama.git
cd ollama && go generate ./... && go build .
./ollama serve &
./ollama pull llama3.2    # 2GB download
```

Test:
```bash
./ollama run llama3.2 "hello"
```

## Option B: OpenRouter Cloud Route (Lighter, any phone)
For phones with less RAM or to save battery:
```bash
# Install sashi via termux-sync
termux-sync pull

# Set up OpenRouter (free tier)
echo 'OPENROUTER_API_KEY=your-key-here' >> ~/ollama-local/.env
echo 'OPENROUTER_MODEL=meta-llama/llama-3.1-8b-instruct:free' >> ~/ollama-local/.env

# Use cloud route
sashi online "hello"
```

## Syncing Sashi to Termux

From the laptop:
```bash
termux-sync push   # pushes sashi CLI + config to phone
```

From Termux:
```bash
termux-sync pull   # pulls latest sashi from laptop
```

## Environment Detection
Sashi auto-detects Termux and routes intelligently:
- If ollama is running locally on phone -> uses local route
- If not -> falls back to OpenRouter online route
- If no internet and no local model -> graceful offline message

## Tips
- Use `tmux` in Termux for persistent sessions: `pkg install tmux`
- Battery: Local ollama uses significant CPU. Use OpenRouter route when on battery.
- Storage: llama3.2 needs ~2GB. Check space with `df -h`
- The 3B param model (llama3.2) is the sweet spot for mobile - small enough to run, smart enough to be useful.
