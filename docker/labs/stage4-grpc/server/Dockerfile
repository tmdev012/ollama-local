FROM python:3.11-alpine
RUN pip install -q grpcio grpcio-tools
WORKDIR /app
COPY greeter.proto .
RUN python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. greeter.proto
COPY server.py .
CMD ["python", "server.py"]
