---
language:
- en
license: mit
tags:
- sashi
- llama
- bash
- cli
- local-ai
- instruction-tuning
task_categories:
- text-generation
pretty_name: Sashi v3.2.3 Training Dataset
size_categories:
- n<1K
---

# Sashi v3.2.3 — Instruction Tuning Dataset

Training dialogs for fine-tuning llama3.2 (3B) and llama3.1 (8B) on the Sashi
local-first AI shell assistant ecosystem.

## Dataset

| File | Dialogs | Coverage |
|------|---------|----------|
| `sashi_v3.2.3_master.jsonl` | **232** | All versions consolidated |
| `training_sashi_v3.2.3.jsonl` | 37 | v3.2.3 new (file-write, file-ops, aliases) |
| `training_sashi_v3.2.0.jsonl` | 56 | v3.2.0 baseline |
| `multi-ternary-80-examples.jsonl` | 79 | multi-ternary bash patterns |
| `filewrite-grpc-60-examples.jsonl` | 60 | gRPC + file write patterns |

## Format

ChatML / HuggingFace messages format:

```json
{
  "messages": [
    {"role": "system", "content": "You are Sashi v3.2.3 ..."},
    {"role": "user",   "content": "How do I write AI output to a file?"},
    {"role": "assistant", "content": "```bash\nsashi write output.md 'prompt'\n```..."}
  ]
}
```

## Coverage — v3.2.3

- **LLM File Write System** (`sashi write` — 7 modes)
  - `--read` file→llama→write, `--append` flock-safe, `--batch` glob,
    `--fmt` json/csv/md/sh validated, `--pipe` stdin, `--safe` fallback
- **File Operations Library** (`sashi file` — 17 subcommands)
  - read, write, append, parse (csv/json/jsonl/text), copy, move, delete,
    batch, check, recover, info, stream, split, join, rotate, detect
- **30 Filesystem Aliases** (9 categories)
  - find/filter, disk, listing, archive, copy/move/delete,
    permissions, symlinks, checksum/compare, watch
- **USB/WiFi/HF** bare commands (usb, wifi, hf, android-studio)
- **sashi wallog** — Modelfile git log + SQL WAL changelog
- **Error handling** — corrupt/missing/perms/partial recovery patterns

## Hardware Target

- CPU-only: i7-6500U 2C/4T, 7.6GB RAM, no GPU
- Model: llama3.2 3B (`sashi-llama-fast`) primary, llama3.1 8B quality
- Inference: `ollama run` (native streaming, model stays hot)
- Speed: 3B ~4.0 tok/s, 8B ~3.7 tok/s

## Training Config (Modelfile)

```
FROM llama3.2
PARAMETER num_thread 2       # physical cores only — HT contention kills speed
PARAMETER temperature 0.3
PARAMETER num_ctx 4096
```

## Usage

```python
from datasets import load_dataset
ds = load_dataset("json", data_files="sashi_v3.2.3_master.jsonl", split="train")
```

Or with transformers/trl SFTTrainer (ChatML format, apply chat template).
