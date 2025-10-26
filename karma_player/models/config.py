"""
Configuration and settings models
"""
from dataclasses import dataclass
from typing import Optional
from pathlib import Path


@dataclass
class AppConfig:
    """Application configuration"""
    music_folder: Path
    download_folder: Path
    api_port: int = 8765
    community_api_url: str = "https://api.trusttune.community/v1"
    device_id: Optional[str] = None
    telemetry_enabled: bool = False


@dataclass
class RateLimitStatus:
    """Rate limit status from Community API"""
    allowed: bool
    used: int
    limit: int
    resets_at: Optional[str] = None
