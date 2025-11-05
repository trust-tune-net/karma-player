"""
Rate limiting configuration for TrustTune API using slowapi.

Provides basic rate limiting per device to prevent abuse.
This is a Phase 0 implementation - will be replaced with Redis-backed
rate limiting in Phase 1.
"""

import os
from slowapi import Limiter
from slowapi.util import get_remote_address
from fastapi import Request


def get_device_id_or_ip(request: Request) -> str:
    """
    Get device ID from request headers for rate limiting key.

    Falls back to IP address if device ID is not present (for health checks, etc.)

    Args:
        request: FastAPI Request object

    Returns:
        str: Device ID or IP address to use as rate limit key
    """
    # Try to get device ID from header
    device_id = request.headers.get("x-device-id")
    if device_id:
        return f"device:{device_id}"

    # Fall back to IP address
    return f"ip:{get_remote_address(request)}"


# Initialize rate limiter
# Default limits - can be overridden via environment variables
DEFAULT_RATE_LIMIT = os.getenv("RATE_LIMIT_DEFAULT", "100/hour")

limiter = Limiter(
    key_func=get_device_id_or_ip,
    default_limits=[DEFAULT_RATE_LIMIT],
    storage_uri="memory://",  # In-memory storage (Phase 0 - will use Redis in Phase 1)
)
