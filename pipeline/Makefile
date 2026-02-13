# Pipeline gRPC — Build & Run
SHELL := /bin/bash
PROTO := proto/pipeline.proto
GEN   := generated

.PHONY: help proto server client health clean

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

proto: ## Compile protobuf definitions
	python3 -m grpc_tools.protoc --proto_path=proto --python_out=$(GEN) --grpc_python_out=$(GEN) $(PROTO)
	touch $(GEN)/__init__.py
	@echo "[OK] Proto compiled"

server: ## Start gRPC server (foreground)
	python3 server.py

server-bg: ## Start gRPC server (background)
	python3 server.py &
	@echo "Server started in background"

client: ## Interactive client test
	python3 client.py health

health: ## Quick health check
	python3 client.py health

clean: ## Remove generated files
	rm -f $(GEN)/pipeline_pb2*.py
	@echo "[OK] Cleaned"
