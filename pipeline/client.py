#!/usr/bin/env python3
"""
gRPC Pipeline Client — Python CLI for testing and scripting.
Usage:
  python3 client.py health
  python3 client.py infer "explain quicksort"
  python3 client.py stream "write a haiku"
  python3 client.py write /tmp/test.txt "hello world"
  python3 client.py pipeline "summarize this" /tmp/out.txt
"""

import grpc
import sys
import os
import json

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'generated'))
import pipeline_pb2
import pipeline_pb2_grpc

GRPC_ADDR = os.environ.get('PIPELINE_ADDR', 'localhost:50051')


def get_channel():
    return grpc.insecure_channel(GRPC_ADDR)


def cmd_health():
    with get_channel() as ch:
        stub = pipeline_pb2_grpc.PipelineServiceStub(ch)
        resp = stub.HealthCheck(pipeline_pb2.HealthRequest())
        print(json.dumps({
            'ok': resp.ok,
            'ollama': resp.ollama_status,
            'db': resp.db_status,
            'uptime_sec': round(resp.uptime_sec, 1),
            'model': resp.model,
            'info': dict(resp.info)
        }, indent=2))


def cmd_infer(prompt, model=''):
    with get_channel() as ch:
        stub = pipeline_pb2_grpc.InferenceServiceStub(ch)
        resp = stub.RunInferenceUnary(pipeline_pb2.InferenceRequest(
            prompt=prompt, model=model
        ))
        print(resp.text)
        print(f'\n---\n[{resp.token_count} tokens, {resp.duration_sec:.1f}s]',
              file=sys.stderr)


def cmd_stream(prompt, model=''):
    with get_channel() as ch:
        stub = pipeline_pb2_grpc.InferenceServiceStub(ch)
        for chunk in stub.RunInference(pipeline_pb2.InferenceRequest(
            prompt=prompt, model=model
        )):
            if chunk.done:
                break
            print(chunk.token, end='', flush=True)
        print()


def cmd_write(path, content, mode='644'):
    with get_channel() as ch:
        stub = pipeline_pb2_grpc.FileWriterServiceStub(ch)
        resp = stub.WriteFiles(pipeline_pb2.WriteFilesRequest(
            files=[pipeline_pb2.FileSpec(
                path=path, content=content, mode=mode
            )],
            atomic=True
        ))
        for r in resp.results:
            status = 'OK' if r.ok else f'FAIL: {r.error}'
            print(f'{r.path}: {status} ({r.bytes_written}b)')


def cmd_pipeline(prompt, output_path='', model=''):
    with get_channel() as ch:
        stub = pipeline_pb2_grpc.PipelineServiceStub(ch)
        for event in stub.RunPipeline(pipeline_pb2.PipelineRequest(
            prompt=prompt, output_path=output_path, model=model
        )):
            etype = pipeline_pb2.PipelineEvent.EventType.Name(event.type)
            if event.type == pipeline_pb2.PipelineEvent.INFERENCE_TOKEN:
                print(event.message, end='\n', flush=True)
            else:
                print(f'[{etype}] {event.message} ({event.elapsed_sec:.1f}s)',
                      file=sys.stderr)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]
    args = sys.argv[2:]

    if cmd == 'health':
        cmd_health()
    elif cmd == 'infer':
        cmd_infer(args[0] if args else '', args[1] if len(args) > 1 else '')
    elif cmd == 'stream':
        cmd_stream(args[0] if args else '', args[1] if len(args) > 1 else '')
    elif cmd == 'write':
        cmd_write(args[0], args[1] if len(args) > 1 else '',
                  args[2] if len(args) > 2 else '644')
    elif cmd == 'pipeline':
        cmd_pipeline(
            args[0] if args else '',
            args[1] if len(args) > 1 else '',
            args[2] if len(args) > 2 else ''
        )
    else:
        print(f'Unknown command: {cmd}')
        print(__doc__)
        sys.exit(1)


if __name__ == '__main__':
    main()
