# TrustTune Search API - Production Dockerfile
# Lightweight search-only service (NO downloads, NO local file access)
# Deploy to: Easypanel, Railway, Render, Fly.io, etc.

FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN pip install --no-cache-dir poetry==1.7.1

# Copy dependency files
COPY pyproject.toml poetry.lock ./

# Configure Poetry to not create virtual env (using container isolation)
RUN poetry config virtualenvs.create false

# Install dependencies (production only, no dev dependencies)
RUN poetry install --no-dev --no-interaction --no-ansi

# Copy application code
COPY karma_player/ ./karma_player/

# Create non-root user for security
RUN useradd -m -u 1000 trusttune && \
    chown -R trusttune:trusttune /app

USER trusttune

# Expose port (configurable via PORT env var)
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/health || exit 1

# Run search API (not server.py - this is cloud-only search service)
CMD ["python", "-m", "uvicorn", "karma_player.api.search_api:app", "--host", "0.0.0.0", "--port", "3000"]
