"""
Authentication module for TrustTune API.

Implements HMAC-based API key authentication for device-based access control.
Each device generates a unique ID, which combined with a server-side salt,
produces a deterministic API key via HMAC-SHA256.
"""

import hashlib
import hmac
import os
from typing import Optional


def get_api_secret_salt() -> str:
    """
    Get the API secret salt from environment variables.

    This salt is used to generate HMAC-based API keys. It should be:
    - Generated using: python -c "import secrets; print(secrets.token_urlsafe(32))"
    - Stored securely in environment variables
    - Never committed to code/git
    - Rotated periodically for security

    Returns:
        str: The secret salt from environment

    Raises:
        RuntimeError: If API_SECRET_SALT environment variable is not set
    """
    salt = os.getenv("API_SECRET_SALT")
    if not salt:
        raise RuntimeError(
            "API_SECRET_SALT environment variable is not set. "
            "Generate one with: python -c \"import secrets; print(secrets.token_urlsafe(32))\""
        )
    return salt


def generate_hmac_key(device_id: str, salt: Optional[str] = None) -> str:
    """
    Generate an HMAC-based API key for a given device ID.

    Uses HMAC-SHA256 to create a deterministic but unpredictable key.
    The same device_id + salt will always produce the same key, but
    the key cannot be derived without knowing the secret salt.

    Args:
        device_id: Unique device identifier (UUID)
        salt: Secret salt (defaults to API_SECRET_SALT from env)

    Returns:
        str: 64-character hexadecimal HMAC-SHA256 hash

    Example:
        >>> generate_hmac_key("550e8400-e29b-41d4-a716-446655440000")
        'a1b2c3d4e5f6...'  # 64 hex characters
    """
    if salt is None:
        salt = get_api_secret_salt()

    # Create HMAC-SHA256 hash
    hmac_hash = hmac.new(
        salt.encode('utf-8'),
        device_id.encode('utf-8'),
        hashlib.sha256
    )

    # Return as hexadecimal string (64 characters)
    return hmac_hash.hexdigest()


def validate_api_key(device_id: str, api_key: str, salt: Optional[str] = None) -> bool:
    """
    Validate an API key against a device ID.

    Regenerates the expected key and compares using constant-time comparison
    to prevent timing attacks.

    Args:
        device_id: Device identifier to validate against
        api_key: API key provided by client
        salt: Secret salt (defaults to API_SECRET_SALT from env)

    Returns:
        bool: True if API key is valid for the device ID, False otherwise

    Example:
        >>> device_id = "550e8400-e29b-41d4-a716-446655440000"
        >>> key = generate_hmac_key(device_id)
        >>> validate_api_key(device_id, key)
        True
        >>> validate_api_key(device_id, "invalid_key")
        False
    """
    if not device_id or not api_key:
        return False

    try:
        expected_key = generate_hmac_key(device_id, salt)
        # Use constant-time comparison to prevent timing attacks
        return hmac.compare_digest(expected_key, api_key)
    except Exception:
        # If any error occurs during validation, fail securely
        return False


def validate_device_id_format(device_id: str) -> bool:
    """
    Validate that a device ID has the correct format.

    Device IDs should be UUIDs (version 4), which are 36 characters long
    with hyphens in specific positions.

    Args:
        device_id: Device ID to validate

    Returns:
        bool: True if format is valid, False otherwise

    Example:
        >>> validate_device_id_format("550e8400-e29b-41d4-a716-446655440000")
        True
        >>> validate_device_id_format("invalid")
        False
    """
    if not device_id or not isinstance(device_id, str):
        return False

    # Basic UUID v4 format check
    # Format: 8-4-4-4-12 hexadecimal characters
    parts = device_id.split('-')
    if len(parts) != 5:
        return False

    if len(parts[0]) != 8 or len(parts[1]) != 4 or len(parts[2]) != 4 or \
       len(parts[3]) != 4 or len(parts[4]) != 12:
        return False

    # Verify all parts are hexadecimal
    try:
        for part in parts:
            int(part, 16)
        return True
    except ValueError:
        return False
