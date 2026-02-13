#!/usr/bin/env python3
"""
gRPC Pipeline Server — ollama-local automation engine.
Runs inference via 'ollama run', writes files atomically, executes pipelines.
Designed for CPU-only i7-6500U (num_thread=2 optimal).

DB Optimizations (O(log n) via B-tree indexes):
- Connection pool (reuse, not open/close per call)
- WAL + synchronous=NORMAL (safe for WAL, 2x write speed)
- mmap_size=256MB (memory-mapped reads, zero-copy)
- prompt_cache integration (skip inference on cache hit)
- Duplicate index cleanup on startup
"""

import grpc
import hashlib
import os
import socket
import sys
import time
import subprocess
import shutil
import sqlite3
import signal
import threading
from concurrent import futures
from pathlib import Path

# Add generated stubs to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'generated'))
import pipeline_pb2
import pipeline_pb2_grpc

# --- Config ---
SCRIPT_DIR = Path(__file__).parent
REPO_DIR = SCRIPT_DIR.parent
ENV_FILE = REPO_DIR / '.env'
DB_PATH = os.environ.get('SASHI_DB', str(REPO_DIR / 'db' / 'history.db'))
DEFAULT_MODEL = 'llama3.2'
DEFAULT_THREADS = 2
GRPC_PORT = 50051
START_TIME = time.time()

# --- Connection Pool ---
_db_local = threading.local()

# Duplicate indexes to drop (same column, wasted write I/O)
DUPLICATE_INDEXES = [
    'idx_cm_sid',        # dup of idx_claude_msg_sess (claude_messages.session_id)
    'idx_cm_ts',         # dup of idx_claude_msg_ts (claude_messages.timestamp)
    'idx_cs_sid',        # dup of idx_claude_sess (claude_sessions.session_id)
    'idx_q_model',       # dup of idx_queries_model (queries.model)
    'idx_q_ts',          # dup of idx_queries_timestamp (queries.timestamp)
]


def load_env():
    """Load .env file into environment."""
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, _, val = line.partition('=')
                os.environ.setdefault(key.strip(), val.strip())


load_env()


def get_model():
    return os.environ.get('LOCAL_MODEL', DEFAULT_MODEL)


def get_db():
    """Thread-local connection pool. One connection per thread, reused."""
    conn = getattr(_db_local, 'conn', None)
    if conn is None:
        conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        # O(log n) pragmas — WAL + NORMAL is crash-safe and 2x faster writes
        conn.execute('PRAGMA journal_mode=WAL')
        conn.execute('PRAGMA synchronous=NORMAL')
        conn.execute('PRAGMA cache_size=-8000')       # 8MB cache (up from 2MB)
        conn.execute('PRAGMA mmap_size=268435456')     # 256MB mmap reads
        conn.execute('PRAGMA temp_store=MEMORY')       # temp tables in RAM
        conn.execute('PRAGMA busy_timeout=5000')       # 5s retry on lock
        _db_local.conn = conn
    return conn


def optimize_db():
    """One-time startup: drop duplicate indexes, analyze for query planner."""
    conn = get_db()
    dropped = 0
    for idx in DUPLICATE_INDEXES:
        try:
            conn.execute(f'DROP INDEX IF EXISTS {idx}')
            dropped += 1
        except sqlite3.OperationalError:
            pass
    if dropped:
        conn.commit()
    # ANALYZE updates sqlite_stat1 so the query planner picks optimal indexes
    conn.execute('ANALYZE')
    conn.commit()
    print(f'[pipeline] DB optimized: dropped {dropped} duplicate indexes, ANALYZE complete')
    # Report index health
    count = conn.execute(
        "SELECT COUNT(*) FROM sqlite_master WHERE type='index'"
    ).fetchone()[0]
    print(f'[pipeline] DB indexes: {count} (all B-tree, O(log n) lookups)')


def prompt_hash(prompt, model):
    """Deterministic hash for prompt cache lookup."""
    return hashlib.sha256(f'{model}:{prompt}'.encode()).hexdigest()


def cache_lookup(prompt, model):
    """O(log n) cache hit via indexed hash lookup on prompt_cache table."""
    h = prompt_hash(prompt, model)
    conn = get_db()
    row = conn.execute(
        'SELECT response FROM prompt_cache WHERE hash = ?', (h,)
    ).fetchone()
    if row:
        conn.execute(
            'UPDATE prompt_cache SET hits = hits + 1 WHERE hash = ?', (h,)
        )
        conn.commit()
        return row['response']
    return None


def cache_store(prompt, model, response):
    """Store inference result in prompt_cache for future O(log n) hits."""
    h = prompt_hash(prompt, model)
    conn = get_db()
    conn.execute(
        'INSERT OR REPLACE INTO prompt_cache (hash, prompt, response, model, hits) '
        'VALUES (?, ?, ?, ?, 0)',
        (h, prompt, response, model)
    )
    conn.commit()


def log_query(model, prompt, response_length, duration_ms):
    """Non-blocking query log to queries table."""
    try:
        conn = get_db()
        conn.execute(
            'INSERT INTO queries (model, prompt, response_length, duration_ms) '
            'VALUES (?, ?, ?, ?)',
            (model, prompt, response_length, int(duration_ms))
        )
        conn.commit()
    except Exception:
        pass  # logging should never crash the pipeline


# ============================================================
# Inference Service
# ============================================================

class InferenceServicer(pipeline_pb2_grpc.InferenceServiceServicer):

    def RunInference(self, request, context):
        """Stream tokens from ollama run. Cache hit returns instantly."""
        model = request.model or get_model()
        prompt = request.prompt
        if not prompt:
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            context.set_details('prompt is required')
            return

        # O(log n) cache check before spawning subprocess
        cached = cache_lookup(prompt, model)
        if cached:
            yield pipeline_pb2.InferenceChunk(token=cached, done=False)
            yield pipeline_pb2.InferenceChunk(token='', done=True)
            return

        num_thread = request.num_thread or DEFAULT_THREADS
        cmd = ['ollama', 'run', model, prompt]
        env = os.environ.copy()
        env['OLLAMA_NUM_THREADS'] = str(num_thread)

        t0 = time.time()
        full_text = []
        try:
            proc = subprocess.Popen(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                text=True, bufsize=1, env=env
            )
            for line in proc.stdout:
                full_text.append(line)
                yield pipeline_pb2.InferenceChunk(token=line, done=False)
            proc.wait()
            yield pipeline_pb2.InferenceChunk(token='', done=True)

            # Store in cache + log
            response = ''.join(full_text)
            elapsed_ms = (time.time() - t0) * 1000
            cache_store(prompt, model, response)
            log_query(model, prompt, len(response), elapsed_ms)
        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))

    def RunInferenceUnary(self, request, context):
        """Collect all tokens, return single response. Cache hit skips inference."""
        model = request.model or get_model()
        prompt = request.prompt
        if not prompt:
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            context.set_details('prompt is required')
            return pipeline_pb2.InferenceResponse()

        # O(log n) cache check — instant return on hit
        cached = cache_lookup(prompt, model)
        if cached:
            return pipeline_pb2.InferenceResponse(
                text=cached,
                duration_sec=0.0,
                token_count=len(cached.split())
            )

        num_thread = request.num_thread or DEFAULT_THREADS
        cmd = ['ollama', 'run', model, prompt]
        env = os.environ.copy()
        env['OLLAMA_NUM_THREADS'] = str(num_thread)

        t0 = time.time()
        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=120, env=env
            )
            elapsed = time.time() - t0
            text = result.stdout.strip()
            tokens = len(text.split())

            # Store in cache + log
            cache_store(prompt, model, text)
            log_query(model, prompt, len(text), elapsed * 1000)

            return pipeline_pb2.InferenceResponse(
                text=text,
                duration_sec=elapsed,
                token_count=tokens
            )
        except subprocess.TimeoutExpired:
            context.set_code(grpc.StatusCode.DEADLINE_EXCEEDED)
            context.set_details('inference timed out after 120s')
            return pipeline_pb2.InferenceResponse()
        except Exception as e:
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return pipeline_pb2.InferenceResponse()


# ============================================================
# FileWriter Service
# ============================================================

class FileWriterServicer(pipeline_pb2_grpc.FileWriterServiceServicer):

    def WriteFiles(self, request, context):
        """Write files atomically (all or none if atomic=True)."""
        results = []
        temp_files = []

        for fspec in request.files:
            path = Path(fspec.path).expanduser().resolve()
            mode = fspec.mode or '644'

            try:
                # Ensure parent directory exists
                path.parent.mkdir(parents=True, exist_ok=True)

                if request.atomic:
                    # Write to temp, then move
                    tmp = path.with_suffix(path.suffix + '.tmp')
                    temp_files.append((tmp, path, mode))
                    if fspec.append and path.exists():
                        shutil.copy2(path, tmp)
                        with open(tmp, 'a') as f:
                            f.write(fspec.content)
                    else:
                        tmp.write_text(fspec.content)
                    results.append(pipeline_pb2.FileResult(
                        path=str(path), ok=True,
                        bytes_written=len(fspec.content.encode())
                    ))
                else:
                    # Direct write
                    if fspec.append:
                        with open(path, 'a') as f:
                            f.write(fspec.content)
                    else:
                        path.write_text(fspec.content)
                    os.chmod(path, int(mode, 8))
                    results.append(pipeline_pb2.FileResult(
                        path=str(path), ok=True,
                        bytes_written=len(fspec.content.encode())
                    ))
            except Exception as e:
                if request.atomic:
                    # Rollback: remove all temp files
                    for tmp, _, _ in temp_files:
                        tmp.unlink(missing_ok=True)
                    return pipeline_pb2.WriteFilesResponse(
                        ok=False,
                        results=[pipeline_pb2.FileResult(
                            path=str(path), ok=False, error=str(e)
                        )]
                    )
                results.append(pipeline_pb2.FileResult(
                    path=str(path), ok=False, error=str(e)
                ))

        # Atomic commit: move all temp files to final paths
        if request.atomic and temp_files:
            for tmp, final, mode in temp_files:
                shutil.move(str(tmp), str(final))
                os.chmod(final, int(mode, 8))

        all_ok = all(r.ok for r in results)
        return pipeline_pb2.WriteFilesResponse(ok=all_ok, results=results)

    def ReadFile(self, request, context):
        """Read a file's contents."""
        path = Path(request.path).expanduser().resolve()
        try:
            content = path.read_text()
            return pipeline_pb2.ReadFileResponse(ok=True, content=content)
        except Exception as e:
            return pipeline_pb2.ReadFileResponse(ok=False, error=str(e))


# ============================================================
# Pipeline Service
# ============================================================

class PipelineServicer(pipeline_pb2_grpc.PipelineServiceServicer):

    def RunPipeline(self, request, context):
        """Full pipeline: resolve prompt → inference → write output."""
        t0 = time.time()

        yield pipeline_pb2.PipelineEvent(
            type=pipeline_pb2.PipelineEvent.STARTED,
            message='Pipeline started',
            elapsed_sec=0
        )

        # Resolve prompt: from task_id (kanban DB) or direct
        prompt = request.prompt
        if request.task_id and not prompt:
            try:
                prompt = self._load_task_prompt(request.task_id)
                yield pipeline_pb2.PipelineEvent(
                    type=pipeline_pb2.PipelineEvent.STARTED,
                    message=f'Loaded task {request.task_id} from kanban',
                    elapsed_sec=time.time() - t0
                )
            except Exception as e:
                yield pipeline_pb2.PipelineEvent(
                    type=pipeline_pb2.PipelineEvent.ERROR,
                    message=f'Failed to load task: {e}',
                    elapsed_sec=time.time() - t0
                )
                return

        if not prompt:
            yield pipeline_pb2.PipelineEvent(
                type=pipeline_pb2.PipelineEvent.ERROR,
                message='No prompt provided and no task_id to resolve',
                elapsed_sec=time.time() - t0
            )
            return

        # Run inference
        model = request.model or get_model()
        cmd = ['ollama', 'run', model, prompt]
        env = os.environ.copy()
        env['OLLAMA_NUM_THREADS'] = str(DEFAULT_THREADS)

        try:
            proc = subprocess.Popen(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                text=True, bufsize=1, env=env
            )
            full_output = []
            for line in proc.stdout:
                full_output.append(line)
                yield pipeline_pb2.PipelineEvent(
                    type=pipeline_pb2.PipelineEvent.INFERENCE_TOKEN,
                    message=line.rstrip('\n'),
                    elapsed_sec=time.time() - t0
                )
            proc.wait()

            yield pipeline_pb2.PipelineEvent(
                type=pipeline_pb2.PipelineEvent.INFERENCE_DONE,
                message=f'Inference complete ({len(full_output)} lines)',
                elapsed_sec=time.time() - t0
            )
        except Exception as e:
            yield pipeline_pb2.PipelineEvent(
                type=pipeline_pb2.PipelineEvent.ERROR,
                message=f'Inference failed: {e}',
                elapsed_sec=time.time() - t0
            )
            return

        # Write output if path specified
        output_text = ''.join(full_output)
        if request.output_path:
            try:
                out = Path(request.output_path).expanduser().resolve()
                out.parent.mkdir(parents=True, exist_ok=True)
                out.write_text(output_text)
                yield pipeline_pb2.PipelineEvent(
                    type=pipeline_pb2.PipelineEvent.FILE_WRITTEN,
                    message=f'Written to {out} ({len(output_text)} bytes)',
                    elapsed_sec=time.time() - t0
                )
            except Exception as e:
                yield pipeline_pb2.PipelineEvent(
                    type=pipeline_pb2.PipelineEvent.ERROR,
                    message=f'File write failed: {e}',
                    elapsed_sec=time.time() - t0
                )
                return

        yield pipeline_pb2.PipelineEvent(
            type=pipeline_pb2.PipelineEvent.COMPLETED,
            message='Pipeline completed successfully',
            elapsed_sec=time.time() - t0
        )

    def _load_task_prompt(self, task_id):
        """Load task from kanban DB. O(log n) via PRIMARY KEY index."""
        conn = get_db()
        # Try kanban-style tables
        try:
            row = conn.execute(
                "SELECT title, description FROM tasks WHERE id = ?",
                (task_id,)
            ).fetchone()
            if row:
                return f"{row['title']}: {row['description']}"
        except sqlite3.OperationalError:
            pass
        # Fallback: query history (O(log n) via PRIMARY KEY)
        try:
            row = conn.execute(
                "SELECT prompt FROM queries WHERE id = ?",
                (task_id,)
            ).fetchone()
            if row:
                return row['prompt']
        except sqlite3.OperationalError:
            pass
        raise ValueError(f'Task {task_id} not found in DB')

    def HealthCheck(self, request, context):
        """System health: ollama, DB, uptime. Direct socket check (no curl fork)."""
        info = {}

        # Ollama — direct TCP connect (no subprocess fork, ~1ms vs ~50ms)
        try:
            s = socket.create_connection(('127.0.0.1', 11434), timeout=2)
            s.close()
            ollama_ok = True
        except (socket.timeout, ConnectionRefusedError, OSError):
            ollama_ok = False

        # DB — use pooled connection
        try:
            conn = get_db()
            conn.execute('SELECT 1')
            db_ok = True
        except Exception:
            db_ok = False

        uptime = time.time() - START_TIME

        # Cache stats
        try:
            conn = get_db()
            cache_rows = conn.execute('SELECT COUNT(*) FROM prompt_cache').fetchone()[0]
            cache_hits = conn.execute('SELECT COALESCE(SUM(hits),0) FROM prompt_cache').fetchone()[0]
            query_count = conn.execute('SELECT COUNT(*) FROM queries').fetchone()[0]
            info['cache_entries'] = str(cache_rows)
            info['cache_hits'] = str(cache_hits)
            info['total_queries'] = str(query_count)
        except Exception:
            pass

        info['grpc_port'] = str(GRPC_PORT)
        info['pid'] = str(os.getpid())
        info['db_path'] = DB_PATH
        idx_count = 0
        try:
            idx_count = get_db().execute(
                "SELECT COUNT(*) FROM sqlite_master WHERE type='index'"
            ).fetchone()[0]
        except Exception:
            pass
        info['index_count'] = str(idx_count)

        return pipeline_pb2.HealthResponse(
            ok=ollama_ok and db_ok,
            ollama_status='up' if ollama_ok else 'down',
            db_status='up' if db_ok else 'down',
            uptime_sec=uptime,
            model=get_model(),
            info=info
        )


# ============================================================
# Server Bootstrap
# ============================================================

def serve():
    # DB optimization pass (drop dups, ANALYZE, set pragmas)
    optimize_db()

    server = grpc.server(futures.ThreadPoolExecutor(max_workers=4))
    pipeline_pb2_grpc.add_InferenceServiceServicer_to_server(
        InferenceServicer(), server)
    pipeline_pb2_grpc.add_FileWriterServiceServicer_to_server(
        FileWriterServicer(), server)
    pipeline_pb2_grpc.add_PipelineServiceServicer_to_server(
        PipelineServicer(), server)

    addr = f'0.0.0.0:{GRPC_PORT}'
    server.add_insecure_port(addr)
    server.start()
    print(f'[pipeline] gRPC server started on {addr}')
    print(f'[pipeline] model={get_model()} threads={DEFAULT_THREADS} db={DB_PATH}')

    # Graceful shutdown
    stop_event = threading.Event()

    def _shutdown(signum, frame):
        print(f'\n[pipeline] Shutting down (signal {signum})...')
        server.stop(grace=5)
        stop_event.set()

    signal.signal(signal.SIGINT, _shutdown)
    signal.signal(signal.SIGTERM, _shutdown)

    stop_event.wait()


if __name__ == '__main__':
    serve()
