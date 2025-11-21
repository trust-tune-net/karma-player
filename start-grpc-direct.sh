#!/bin/bash
# Direct start using poetry's virtualenv Python (bypasses conda)

set -e

VENV_PYTHON="/Users/fcavalcanti/Library/Caches/pypoetry/virtualenvs/karma-player-hMECH5Jv-py3.10/bin/python"

if [ ! -f "$VENV_PYTHON" ]; then
    echo "❌ Poetry virtualenv not found at: $VENV_PYTHON"
    echo "Run: poetry install"
    exit 1
fi

# Load .env
set -a
source .env
set +a

echo "🚀 Starting gRPC server with poetry virtualenv Python..."
exec "$VENV_PYTHON" -m karma_player.api.grpc_server
