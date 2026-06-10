#!/usr/bin/env bash
nc -z localhost 50051 2>/dev/null && echo "[OK]" || echo "[WARN]"
