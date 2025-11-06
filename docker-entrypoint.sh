#!/bin/bash
set -e

# Use PORT env var if set, otherwise default to 3000
HTTP_PORT=${PORT:-3000}
GRPC_PORT=${GRPC_PORT:-50051}

echo "Starting TrustTune Search API..."
echo "  HTTP/WebSocket: 0.0.0.0:$HTTP_PORT"
echo "  gRPC: 0.0.0.0:$GRPC_PORT"

# Start gRPC server in background
python karma_player/api/grpc_server.py &
GRPC_PID=$!

# Start HTTP/WebSocket server in foreground
python -m uvicorn karma_player.api.search_api:app \
    --host 0.0.0.0 \
    --port "$HTTP_PORT" &
HTTP_PID=$!

# Wait for both processes
wait $GRPC_PID $HTTP_PID
