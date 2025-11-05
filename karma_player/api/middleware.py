"""
Authentication middleware for TrustTune API.

Provides FastAPI dependencies for request authentication using HMAC-based API keys.
"""

import logging
from typing import Optional

from fastapi import Header, HTTPException, Request, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from karma_player.api.auth import validate_api_key, validate_device_id_format

logger = logging.getLogger(__name__)

# Security scheme for OpenAPI documentation
security = HTTPBearer(auto_error=False)


async def get_device_id(
    x_device_id: Optional[str] = Header(None, description="Unique device identifier (UUID)")
) -> str:
    """
    Extract and validate device ID from request headers.

    Args:
        x_device_id: Device ID from X-Device-ID header

    Returns:
        str: Validated device ID

    Raises:
        HTTPException: 401 if device ID is missing or invalid format
    """
    if not x_device_id:
        logger.warning("Authentication failed: Missing X-Device-ID header")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing X-Device-ID header",
            headers={"WWW-Authenticate": "ApiKey"},
        )

    if not validate_device_id_format(x_device_id):
        logger.warning(f"Authentication failed: Invalid device ID format: {x_device_id[:8]}...")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid device ID format (expected UUID)",
            headers={"WWW-Authenticate": "ApiKey"},
        )

    return x_device_id


async def get_api_key(
    x_api_key: Optional[str] = Header(None, description="HMAC-based API key")
) -> str:
    """
    Extract API key from request headers.

    Args:
        x_api_key: API key from X-API-Key header

    Returns:
        str: API key

    Raises:
        HTTPException: 401 if API key is missing
    """
    if not x_api_key:
        logger.warning("Authentication failed: Missing X-API-Key header")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing X-API-Key header",
            headers={"WWW-Authenticate": "ApiKey"},
        )

    return x_api_key


async def verify_api_key(
    device_id: Optional[str] = Header(None, alias="x-device-id"),
    api_key: Optional[str] = Header(None, alias="x-api-key"),
    request: Request = None
) -> str:
    """
    Verify that the API key is valid for the given device ID.

    This is the main authentication dependency to use on protected endpoints.

    Args:
        device_id: Device ID from X-Device-ID header (optional)
        api_key: API key from X-API-Key header (optional)
        request: FastAPI request object (for logging)

    Returns:
        str: Validated device ID

    Raises:
        HTTPException: 401 if authentication fails

    Example:
        @app.get("/protected", dependencies=[Depends(verify_api_key)])
        async def protected_endpoint():
            return {"message": "Access granted"}
    """
    # Check for missing headers first (return 401, not 422)
    if not device_id:
        logger.warning(f"Authentication failed: Missing X-Device-ID header from {request.client.host if request else 'unknown'}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing X-Device-ID header",
            headers={"WWW-Authenticate": "ApiKey"},
        )

    if not api_key:
        logger.warning(f"Authentication failed: Missing X-API-Key header from {request.client.host if request else 'unknown'}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing X-API-Key header",
            headers={"WWW-Authenticate": "ApiKey"},
        )

    # Validate device ID format
    if not validate_device_id_format(device_id):
        logger.warning(
            f"Authentication failed: Invalid device ID format from {request.client.host if request else 'unknown'}"
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid device ID format",
            headers={"WWW-Authenticate": "ApiKey"},
        )

    # Validate API key
    if not validate_api_key(device_id, api_key):
        logger.warning(
            f"Authentication failed: Invalid API key for device {device_id[:8]}... "
            f"from {request.client.host if request else 'unknown'}"
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
            headers={"WWW-Authenticate": "ApiKey"},
        )

    # Log successful authentication (at debug level)
    if request:
        logger.debug(
            f"Authentication successful: device {device_id[:8]}... from {request.client.host}"
        )

    return device_id


async def verify_api_key_optional(
    device_id: Optional[str] = Header(None, alias="x-device-id"),
    api_key: Optional[str] = Header(None, alias="x-api-key"),
) -> Optional[str]:
    """
    Optional authentication dependency.

    Returns device_id if auth headers are present and valid, None otherwise.
    Does not raise exceptions, allowing endpoints to handle unauthenticated requests.

    Args:
        device_id: Device ID from X-Device-ID header (optional)
        api_key: API key from X-API-Key header (optional)

    Returns:
        Optional[str]: Validated device ID if authenticated, None otherwise

    Example:
        @app.get("/public-or-private")
        async def flexible_endpoint(device_id: Optional[str] = Depends(verify_api_key_optional)):
            if device_id:
                return {"message": "Authenticated user", "device_id": device_id}
            else:
                return {"message": "Anonymous access"}
    """
    if not device_id or not api_key:
        return None

    if not validate_device_id_format(device_id):
        return None

    if not validate_api_key(device_id, api_key):
        return None

    return device_id


# WebSocket authentication helper
def verify_websocket_auth(auth_data: dict) -> str:
    """
    Verify authentication data from WebSocket initial message.

    WebSockets don't support custom headers the same way HTTP does,
    so authentication data is sent in the first message payload.

    Args:
        auth_data: Dictionary with 'device_id' and 'api_key' keys

    Returns:
        str: Validated device ID

    Raises:
        ValueError: If authentication fails

    Example:
        # Client sends first message:
        {
            "auth": {
                "device_id": "550e8400-e29b-41d4-a716-446655440000",
                "api_key": "a1b2c3..."
            },
            "query": "search term"
        }

        # Server validates:
        device_id = verify_websocket_auth(message["auth"])
    """
    if not isinstance(auth_data, dict):
        raise ValueError("Invalid auth data format")

    device_id = auth_data.get("device_id")
    api_key = auth_data.get("api_key")

    if not device_id or not api_key:
        raise ValueError("Missing device_id or api_key")

    if not validate_device_id_format(device_id):
        raise ValueError("Invalid device ID format")

    if not validate_api_key(device_id, api_key):
        raise ValueError("Invalid API key")

    return device_id


# Logging middleware
async def log_request_middleware(request: Request, call_next):
    """
    Middleware to log all requests with authentication info.

    Logs:
    - Method and path
    - Client IP
    - Device ID (if authenticated)
    - Response status code

    This is useful for monitoring API usage and detecting abuse patterns.

    Args:
        request: FastAPI request
        call_next: Next middleware/handler in chain

    Returns:
        Response from next handler
    """
    # Extract auth headers for logging (don't validate yet)
    device_id = request.headers.get("x-device-id", "anonymous")[:16]
    client_ip = request.client.host if request.client else "unknown"

    logger.info(
        f"{request.method} {request.url.path} "
        f"device={device_id} ip={client_ip}"
    )

    response = await call_next(request)

    logger.info(
        f"Response {response.status_code} for "
        f"{request.method} {request.url.path} "
        f"device={device_id}"
    )

    return response
