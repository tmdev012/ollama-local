# Process Map — Docker → gRPC → Kafka → Multi-Device
# Rule: don't move to next stage until VERIFY passes. No skipping.
# AI: ask llama3.2 at each stage. Come to Claude only for map corrections.

────────────────────────────────────────────────────────────────────
STAGE 1 — Container Basics (where you are now)
────────────────────────────────────────────────────────────────────
LEARN
  □ image vs container (recipe vs meal)
  □ layers and why order in Dockerfile matters
  □ what `docker ps`, `docker images`, `docker logs` tell you

BUILD
  □ run a single container manually (not compose)
      docker run -it ubuntu:24.04 bash
  □ make a change inside it, exit, see it's gone
  □ run it again — confirm change is gone (containers are disposable)

VERIFY  ← must pass before Stage 2
  □ Q: what is the difference between `docker stop` and `docker rm`?
  □ Q: why does a layer rebuild when you change a line above it?
  □ Q: what does `docker run --rm` do and when would you use it?
  ask llama3.2: "explain docker layers with a simple example"
  □ RUNNABLE: docker/labs/stage2-q1-dns/  → bash run.sh

────────────────────────────────────────────────────────────────────
STAGE 2 — Networking (two containers talking)
────────────────────────────────────────────────────────────────────
LEARN
  □ bridge network — default, same machine, containers find each by name
  □ port mapping — host:container (8080:80 means host 8080 → container 80)
  □ why container name = hostname on the same network

BUILD
  □ run two containers on same bridge network manually
      docker network create testnet
      docker run -d --name ping-target --network testnet alpine sleep 999
      docker run -it --network testnet alpine ping ping-target
  □ confirm name resolves — this is exactly how gRPC will work later
  □ then do same thing via compose (what you already have)

VERIFY  ← must pass before Stage 3
  □ Q: why does `http://ollama:11434` work inside setup-box?
  □ Q: what breaks if you remove `depends_on` in compose.yml?
  □ Q: what is the difference between expose and ports in compose?
  ask llama3.2: "docker bridge network hostname resolution explained simply"

────────────────────────────────────────────────────────────────────
STAGE 3 — Volumes (data that survives containers)
────────────────────────────────────────────────────────────────────
LEARN
  □ named volume — managed by Docker, survives container death
  □ bind mount — maps a host directory into a container
  □ when to use which: code = bind mount, data = named volume

BUILD
  □ create a named volume, write a file into it via one container
      docker volume create testdata
      docker run --rm -v testdata:/data alpine sh -c "echo hello > /data/test.txt"
  □ kill that container, run a new one, confirm file is still there
      docker run --rm -v testdata:/data alpine cat /data/test.txt
  □ identify which volumes in your compose.yml are named vs bind mount

VERIFY  ← must pass before Stage 4
  □ Q: what happens to `ollama-models` volume on `docker compose down`?
  □ Q: what happens to it on `docker compose down -v`?
  □ Q: why does Kafka need a named volume and not a bind mount?
  ask llama3.2: "docker named volumes vs bind mounts when to use each"

────────────────────────────────────────────────────────────────────
STAGE 4 — gRPC between containers
────────────────────────────────────────────────────────────────────
LEARN
  □ what gRPC is: function calls over HTTP/2 using protobuf (typed contracts)
  □ .proto file defines the contract (like an interface)
  □ server container exposes a port, client container calls it by name

BUILD
  □ write a minimal .proto (one function: Greet → returns a string)
  □ generate server stub (Kotlin or Python — pick one)
  □ run server in one container, client in another on same network
  □ client calls server by container name — prove it works

VERIFY  ← must pass before Stage 5
  □ Q: what does protobuf give you that JSON doesn't?
  □ Q: what port does gRPC use by default and why does it matter?
  □ Q: what breaks if server and client .proto files are out of sync?
  ask llama3.2: "minimal grpc server client example two docker containers"

────────────────────────────────────────────────────────────────────
STAGE 5 — Kafka between containers (async load delegation)
────────────────────────────────────────────────────────────────────
LEARN
  □ Kafka is a message queue: producer writes, consumer reads, broker stores
  □ topic = named channel, partition = parallelism unit
  □ consumer group = multiple consumers sharing load on one topic

BUILD
  □ add Kafka (+ Zookeeper or KRaft) to compose.yml
  □ write a producer container that publishes a message every 5s
  □ write a consumer container that reads and prints it
  □ scale consumer to 2 instances — watch load split between them

VERIFY  ← must pass before Stage 6
  □ Q: what happens to unread messages if consumer is down for 10 minutes?
  □ Q: what is a consumer group and why does it matter for load delegation?
  □ Q: why does Kafka need a named volume?
  ask llama3.2: "kafka producer consumer docker compose minimal example"

────────────────────────────────────────────────────────────────────
STAGE 6 — Multi-device (migration + overlay network)
────────────────────────────────────────────────────────────────────
LEARN
  □ Docker Swarm: turns multiple machines into one logical cluster
  □ overlay network: containers on different machines talk by name
  □ service vs container in Swarm context (service = replicated containers)

BUILD
  □ init swarm on machine 1: `docker swarm init`
  □ join machine 2 as worker: `docker swarm join --token ...`
  □ deploy your compose as a stack: `docker stack deploy -c compose.yml myapp`
  □ confirm setup-box on machine 1 reaches ollama on machine 2 by name

VERIFY  ← system is complete when this passes
  □ Q: what is the join token and where does it come from?
  □ Q: how does a service on machine 2 find a service on machine 1?
  □ Q: what happens to your Kafka volume when the node it lives on goes down?
  ask llama3.2: "docker swarm overlay network multi host example"

────────────────────────────────────────────────────────────────────
DEPENDENCY CHAIN (never skip)
────────────────────────────────────────────────────────────────────

  [1 Containers] → [2 Networking] → [3 Volumes]
                                         │
                              ┌──────────┴──────────┐
                         [4 gRPC]              [5 Kafka]
                              └──────────┬──────────┘
                                    [6 Multi-device]

────────────────────────────────────────────────────────────────────
BACK-AND-FORTH REDUCTION RULES
────────────────────────────────────────────────────────────────────
1. Always run VERIFY questions before moving to next stage
2. Use `ask` inside setup-box for stage-specific questions
3. Come to Claude only to correct the map itself — not for setup tasks
4. If a stage breaks, debug the VERIFY questions of the stage below it first
5. One stage at a time. Debt = skipping verify.
