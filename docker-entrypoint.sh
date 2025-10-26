#!/bin/bash
set -e

# Use PORT env var if set, otherwise default to 3000
PORT=${PORT:-3000}

echo "Starting TrustTune Search API on port $PORT..."

# Run uvicorn with dynamic port
exec python -m uvicorn karma_player.api.search_api:app \
    --host 0.0.0.0 \
    --port "$PORT"
