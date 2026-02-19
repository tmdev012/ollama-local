from concurrent import futures
import grpc, greeter_pb2, greeter_pb2_grpc

class GreeterServicer(greeter_pb2_grpc.GreeterServicer):
    def Greet(self, request, context):
        print(f"server: got request for '{request.name}'")
        return greeter_pb2.GreetReply(message=f"Hello, {request.name}! from gRPC server")

server = grpc.server(futures.ThreadPoolExecutor(max_workers=2))
greeter_pb2_grpc.add_GreeterServicer_to_server(GreeterServicer(), server)
server.add_insecure_port("[::]:50051")
server.start()
print("server: listening on :50051")
server.wait_for_termination()
