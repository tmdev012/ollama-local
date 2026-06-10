#!/usr/bin/env python3
"""
mcp/server.py — Sashi MCP Server (stdio transport, JSON-RPC 2.0)

Implements the Model Context Protocol (MCP) over stdin/stdout.
Dispatches tool calls to sashi CLI subcommands via subprocess.

Protocol: https://spec.modelcontextprotocol.io/specification/
Transport: stdio (newline-delimited JSON-RPC 2.0)

Usage (from Claude Desktop or any MCP client):
    python3 ~/ollama-local/mcp/server.py
"""

import sys
import json
import os
import subprocess
import sqlite3
from pathlib import Path

SASHI = Path(__file__).parent.parent / "sashi"
DB_PATH = Path(os.environ.get("SASHI_DB", Path.home() / "ollama-local/db/history.db"))
TOOLS_PATH = Path(__file__).parent / "tools.json"


# ── Tool dispatch ──────────────────────────────────────────────────────────────

def _run_sashi(*args: str, timeout: int = 70) -> str:
    """Run a sashi subcommand, return stdout. Raises on non-zero exit."""
    try:
        result = subprocess.run(
            [str(SASHI), *args],
            capture_output=True, text=True, timeout=timeout
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or f"sashi exited {result.returncode}")
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"sashi timed out after {timeout}s")


def tool_sashi_ask(params: dict) -> str:
    prompt = params["prompt"]
    model = params.get("model")
    if model:
        env = {**os.environ, "LOCAL_MODEL": model}
        result = subprocess.run(
            [str(SASHI), "ask", prompt],
            capture_output=True, text=True, timeout=70, env=env
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip())
        return result.stdout.strip()
    return _run_sashi("ask", prompt)


def tool_sashi_code(params: dict) -> str:
    return _run_sashi("code", params["prompt"])


def tool_sashi_file_read(params: dict) -> str:
    args = ["file", "read", params["path"]]
    if params.get("encoding"):
        args.append(params["encoding"])
    if params.get("head_n", 0) > 0:
        args.append(str(params["head_n"]))
    return _run_sashi(*args)


def tool_sashi_file_write(params: dict) -> str:
    path = params["path"]
    content = params["content"]
    backup = "1" if params.get("backup") else "0"
    # Use file-ops directly via Python for safety (avoids shell quoting issues)
    lib = Path(__file__).parent.parent / "lib/sh/file-ops.sh"
    script = f'source {lib} && fops_write {json.dumps(path)} {json.dumps(content)} {backup}'
    result = subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=10)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())
    return result.stdout.strip()


def tool_sashi_file_append(params: dict) -> str:
    return _run_sashi("file", "append", params["path"], params["content"],
                      str(params.get("max_mb", 100)))


def tool_sashi_llm_write(params: dict) -> str:
    return _run_sashi("write", params["outfile"], params["prompt"], timeout=90)


def tool_sashi_llm_process(params: dict) -> str:
    return _run_sashi("write", "--read", params["infile"], params["outfile"],
                      params["prompt"], timeout=90)


def tool_sashi_history(params: dict) -> str:
    limit = int(params.get("limit", 20))
    if not DB_PATH.exists():
        return "No history database found."
    conn = sqlite3.connect(str(DB_PATH))
    c = conn.cursor()
    try:
        c.execute(
            "SELECT id, timestamp, model, substr(prompt,1,60), duration_ms "
            "FROM queries ORDER BY id DESC LIMIT ?", (limit,)
        )
        rows = c.fetchall()
    except sqlite3.OperationalError:
        return "History table not yet initialised."
    finally:
        conn.close()
    if not rows:
        return "No history yet."
    lines = [f"{'ID':<4} {'Time':<20} {'Model':<14} {'Prompt':<60} ms"]
    lines.append("-" * 102)
    for r in rows:
        p = (r[3] or "").replace("\n", " ")
        lines.append(f"{r[0]:<4} {r[1]:<20} {r[2]:<14} {p:<60} {r[4] or 0}")
    return "\n".join(lines)


def tool_sashi_status(_params: dict) -> str:
    return _run_sashi("status")


def tool_sashi_kanban(params: dict) -> str:
    view = params.get("view", "board")
    return _run_sashi("kanban", view)


DISPATCH = {
    "sashi_ask":          tool_sashi_ask,
    "sashi_code":         tool_sashi_code,
    "sashi_file_read":    tool_sashi_file_read,
    "sashi_file_write":   tool_sashi_file_write,
    "sashi_file_append":  tool_sashi_file_append,
    "sashi_llm_write":    tool_sashi_llm_write,
    "sashi_llm_process":  tool_sashi_llm_process,
    "sashi_history":      tool_sashi_history,
    "sashi_status":       tool_sashi_status,
    "sashi_kanban":       tool_sashi_kanban,
}


# ── JSON-RPC helpers ───────────────────────────────────────────────────────────

def _reply(req_id, result=None, error=None) -> dict:
    r: dict = {"jsonrpc": "2.0", "id": req_id}
    if error:
        r["error"] = {"code": error[0], "message": error[1]}
    else:
        r["result"] = result
    return r


def _send(obj: dict) -> None:
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


# ── Request handlers ───────────────────────────────────────────────────────────

def handle_initialize(req_id, _params: dict) -> dict:
    return _reply(req_id, {
        "protocolVersion": "2024-11-05",
        "serverInfo": {"name": "sashi", "version": "5.2.0"},
        "capabilities": {"tools": {}}
    })


def handle_tools_list(req_id, _params: dict) -> dict:
    with open(TOOLS_PATH) as f:
        manifest = json.load(f)
    return _reply(req_id, {"tools": manifest["tools"]})


def handle_tools_call(req_id, params: dict) -> dict:
    name = params.get("name", "")
    args = params.get("arguments", {})
    fn = DISPATCH.get(name)
    if fn is None:
        return _reply(req_id, error=(-32601, f"Unknown tool: {name}"))
    try:
        output = fn(args)
        return _reply(req_id, {
            "content": [{"type": "text", "text": output}],
            "isError": False
        })
    except Exception as exc:
        return _reply(req_id, {
            "content": [{"type": "text", "text": str(exc)}],
            "isError": True
        })


METHOD_MAP = {
    "initialize":        handle_initialize,
    "tools/list":        handle_tools_list,
    "tools/call":        handle_tools_call,
}


# ── Main loop ──────────────────────────────────────────────────────────────────

def main() -> None:
    for raw in sys.stdin:
        raw = raw.strip()
        if not raw:
            continue
        try:
            req = json.loads(raw)
        except json.JSONDecodeError as e:
            _send(_reply(None, error=(-32700, f"Parse error: {e}")))
            continue

        req_id = req.get("id")
        method = req.get("method", "")
        params = req.get("params") or {}

        handler = METHOD_MAP.get(method)
        if handler is None:
            _send(_reply(req_id, error=(-32601, f"Method not found: {method}")))
            continue

        response = handler(req_id, params)
        _send(response)


if __name__ == "__main__":
    main()
