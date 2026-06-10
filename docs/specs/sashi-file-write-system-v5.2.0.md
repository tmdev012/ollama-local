# Sashi v3.2.3 — File Write System Spec

## 1. Architecture

```
stdin / prompt
      │
      ▼
 sashi write          ← CLI entry (7 modes)
      │
      ▼
 llm-write.sh         ← LLM layer (217 lines)
      │
      ▼
 file-ops.sh          ← FS layer (516 lines, 24 functions)
      │
      ▼
 ollama run llama3.2  ← inference (streaming, model stays hot)
```

---

## 2. sashi write — 7 Modes

| Mode | Command | Behaviour |
|------|---------|-----------|
| basic | `sashi write <file> <prompt>` | prompt → llama → atomic write |
| read | `sashi write --read <file>` | read file → llama → overwrite |
| append | `sashi write --append <file> <prompt>` | flock-safe append |
| batch | `sashi write --batch <glob> <prompt>` | parallel file processing |
| fmt | `sashi write --fmt json\|csv\|md\|sh <file> <prompt>` | validated format output |
| safe | `sashi write --safe <file> <prompt>` | retry with fast-sashi fallback |
| pipe | `cat file \| sashi write --pipe <file>` | stdin → llama → file |

---

## 3. llm-write.sh — Function Reference

| Function | Sig | Description |
|----------|-----|-------------|
| `llmw_write` | `(outfile, prompt...)` | atomic tmp→mv write |
| `llmw_process` | `(infile, outfile, prompt...)` | read→llama→write |
| `llmw_append` | `(outfile, prompt...)` | flock-safe append |
| `llmw_batch` | `(glob, prompt...)` | processes each match |
| `llmw_write_fmt` | `(fmt, outfile, prompt...)` | json/csv/md/sh + validate |
| `llmw_pipe` | `(outfile, prompt...)` | reads stdin |
| `llmw_safe_write` | `(outfile, prompt...)` | primary fail → fast-sashi |

**Models:** `LLM_MODEL` env (default `llama3.2`), fallback `fast-sashi`

---

## 4. file-ops.sh — Function Reference

### Detection
| Function | Description |
|----------|-------------|
| `fops_detect_op` | Returns op-type + size class (tiny/small/medium/large/huge) |

### Read
| Function | Description |
|----------|-------------|
| `fops_read` | Size-aware text read (head for large files) |
| `fops_read_binary` | Binary-safe read via base64 |

### Write
| Function | Description |
|----------|-------------|
| `fops_write` | Atomic write (tmp→mv), optional backup |
| `fops_write_file` | Write with full integrity check |
| `fops_append` | flock-safe append |
| `fops_rotate` | Log rotation (compress + keep N) |

### Parse
| Function | Description |
|----------|-------------|
| `fops_parse_csv` | CSV → stdout rows |
| `fops_parse_json` | JSON via python3 json.load |
| `fops_parse_jsonl` | JSONL line iterator |
| `fops_parse_text` | Text with encoding detection |

### Transfer
| Function | Description |
|----------|-------------|
| `fops_copy` | rsync + sha256 verify |
| `fops_move` | cross-device safe move |
| `fops_delete` | trash-first (moves to ~/.local/share/Trash) |

### Batch & Check
| Function | Description |
|----------|-------------|
| `fops_batch` | parallel ops across glob |
| `fops_check_missing` | assert file exists |
| `fops_check_missing_or_create` | create if absent |
| `fops_check_perms` | assert r/w/x permissions |
| `fops_check_corrupt` | sha256 vs stored hash |

### Recovery & Info
| Function | Description |
|----------|-------------|
| `fops_recover` | backup → git → truncate fallback chain |
| `fops_info` | full stat card (size, perms, hash, mtime) |
| `fops_stream` | real-time tail -f wrapper |
| `fops_split` | split large files by line count |
| `fops_join` | join split parts in order |

---

## 5. sashi file — 17 Subcommands

```
sashi file info     <path>         # stat card
sashi file detect   <path>         # op-type + size class
sashi file check    <path>         # integrity/corrupt check
sashi file read     <path>         # size-aware read
sashi file write    <path> <data>  # atomic write
sashi file append   <path> <data>  # flock-safe append
sashi file parse    <path>         # csv/json/jsonl/text auto
sashi file copy     <src> <dst>    # rsync + sha256
sashi file move     <src> <dst>    # cross-device safe
sashi file delete   <path>         # trash-first
sashi file batch    <glob> <op>    # parallel batch
sashi file recover  <path>         # backup|git|truncate
sashi file stream   <path>         # tail -f
sashi file split    <path> [N]     # split by lines (default 1000)
sashi file join     <prefix>       # join parts
sashi file rotate   <path> [N]     # rotate, keep N (default 5)
```

---

## 6. Aliases

### sfile-* (17)
```
sfile-info  sfile-detect  sfile-check  sfile-read   sfile-write
sfile-append  sfile-parse  sfile-copy  sfile-move   sfile-delete
sfile-batch  sfile-recover  sfile-stream  sfile-split  sfile-join  sfile-rotate
```

### swrite-* (10)
```
swrite  swrite-read  swrite-append  swrite-batch
swrite-json  swrite-csv  swrite-md  swrite-sh
swrite-safe  swrite-pipe
```

---

## 7. Format Validation

| fmt | Validator |
|-----|-----------|
| `json` | `python3 -m json.tool` |
| `csv` | line count + comma check |
| `md` | heading presence check |
| `sh` | `bash -n` syntax check |

On failure: retry once with explicit format instruction in prompt.

---

## 8. Error Handling

| Condition | Behaviour |
|-----------|-----------|
| Inference empty | `llmw_safe_write` retries with `fast-sashi` |
| Write collision | atomic tmp→mv prevents partial writes |
| Concurrent append | `flock -x` on lockfile |
| Corrupt file | `fops_check_corrupt` → `fops_recover` chain |
| Large file read | `fops_read` caps at head limit, warns |

---

## 9. DB Logging

All file writes tracked in `~/ollama-local/db/history.db → file_cache`:

```sql
file_cache (path, content_hash, size_bytes, version, written_at)
```

`sashi_db.py file-list` — last 20 writes with version + hash.

---

*Sashi v3.2.3 — 2026-03-01*
