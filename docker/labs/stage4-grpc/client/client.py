import grpc, greeter_pb2, greeter_pb2_grpc, sys, time

time.sleep(2)  # wait for server
channel = grpc.insecure_channel("grpc-server:50051")
stub    = greeter_pb2_grpc.GreeterStub(channel)

for name in ["Docker", "gRPC", "tmdev012"]:
    reply = stub.Greet(greeter_pb2.GreetRequest(name=name))
    print(f"client: received → {reply.message}")
