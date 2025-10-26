"""
Cross-platform configuration management for Karma Player
Supports environment variables, .env files, and platform-aware defaults
"""
import os
import platform
from pathlib import Path
from typing import Optional
from dotenv import load_dotenv


# Load .env file if it exists
env_file = Path(__file__).parent.parent / ".env"
if env_file.exists():
    load_dotenv(env_file)


def get_platform_music_directory() -> Path:
    """
    Get the default music directory based on the platform.

    Returns:
        Path: Platform-appropriate music directory
    """
    system = platform.system()

    if system == "Windows":
        # Windows: C:\Users\<username>\Music
        return Path.home() / "Music"
    elif system == "Darwin":
        # macOS: ~/Music
        return Path.home() / "Music"
    elif system == "Linux":
        # Linux: ~/Music (most common) or XDG Music directory
        xdg_music = os.getenv("XDG_MUSIC_DIR")
        if xdg_music:
            return Path(xdg_music)
        return Path.home() / "Music"
    else:
        # Fallback for unknown systems
        return Path.home() / "Music"


def get_platform_config_directory() -> Path:
    """
    Get the platform-appropriate configuration directory.

    Returns:
        Path: Configuration directory
    """
    system = platform.system()

    if system == "Windows":
        # Windows: %APPDATA%\TrustTune
        appdata = os.getenv("APPDATA")
        if appdata:
            return Path(appdata) / "TrustTune"
        return Path.home() / ".trusttune"
    elif system == "Darwin":
        # macOS: ~/Library/Application Support/TrustTune
        return Path.home() / "Library" / "Application Support" / "TrustTune"
    elif system == "Linux":
        # Linux: ~/.config/trusttune
        xdg_config = os.getenv("XDG_CONFIG_HOME")
        if xdg_config:
            return Path(xdg_config) / "trusttune"
        return Path.home() / ".config" / "trusttune"
    else:
        # Fallback
        return Path.home() / ".trusttune"


class Config:
    """
    Centralized configuration for Karma Player.
    Uses environment variables with sensible platform-aware defaults.
    """

    # === Application Info ===
    APP_NAME = "TrustTune"
    VERSION = "0.1.0"

    # === Directories ===
    @staticmethod
    def get_music_directory() -> Path:
        """Get music download directory (configurable via MUSIC_DIRECTORY env var)"""
        env_path = os.getenv("MUSIC_DIRECTORY")
        if env_path:
            return Path(env_path)
        return get_platform_music_directory()

    @staticmethod
    def get_config_directory() -> Path:
        """Get configuration directory (configurable via CONFIG_DIRECTORY env var)"""
        env_path = os.getenv("CONFIG_DIRECTORY")
        if env_path:
            return Path(env_path)
        return get_platform_config_directory()

    # === API Configuration ===

    # Search API (can be remote)
    SEARCH_API_HOST = os.getenv("SEARCH_API_HOST", "0.0.0.0")
    SEARCH_API_PORT = int(os.getenv("SEARCH_API_PORT", "3000"))

    # Download Daemon (always local)
    DOWNLOAD_DAEMON_HOST = os.getenv("DOWNLOAD_DAEMON_HOST", "127.0.0.1")
    DOWNLOAD_DAEMON_PORT = int(os.getenv("DOWNLOAD_DAEMON_PORT", "3001"))

    # === Jackett Configuration ===
    JACKETT_URL = os.getenv(
        "JACKETT_REMOTE_URL",
        os.getenv("JACKETT_URL", "https://trust-tune-trust-tune-jack.62ickh.easypanel.host")
    )
    JACKETT_API_KEY = os.getenv(
        "JACKETT_REMOTE_API_KEY",
        os.getenv("JACKETT_API_KEY", "ugokmbv2cfeghwcsm27mtnjva5ch7948")
    )
    JACKETT_INDEXER = os.getenv("JACKETT_INDEXER", "all")

    # === AI Configuration ===
    # Support multiple AI providers
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
    ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")

    # Default AI provider (openai or anthropic)
    AI_PROVIDER = os.getenv("AI_PROVIDER", "openai")

    # === MusicBrainz ===
    MUSICBRAINZ_API_KEY = os.getenv("MUSICBRAINZ_API_KEY")

    # === Torrent Settings ===
    MIN_SEEDERS = int(os.getenv("MIN_SEEDERS", "1"))
    MAX_TORRENTS = int(os.getenv("MAX_TORRENTS", "50"))

    # === Feature Flags ===
    SKIP_MUSICBRAINZ = os.getenv("SKIP_MUSICBRAINZ", "false").lower() in ("true", "1", "yes")
    USE_FULL_AI = os.getenv("USE_FULL_AI", "false").lower() in ("true", "1", "yes")
    USE_PARTIAL_AI = os.getenv("USE_PARTIAL_AI", "true").lower() in ("true", "1", "yes")

    # === Development ===
    DEBUG = os.getenv("DEBUG", "false").lower() in ("true", "1", "yes")
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

    @classmethod
    def validate(cls) -> list[str]:
        """
        Validate configuration and return list of warnings/errors.

        Returns:
            List of validation messages (empty if all good)
        """
        warnings = []

        # Check music directory
        music_dir = cls.get_music_directory()
        if not music_dir.exists():
            warnings.append(f"Music directory does not exist: {music_dir}")
        elif not os.access(music_dir, os.W_OK):
            warnings.append(f"Music directory is not writable: {music_dir}")

        # Check AI keys if AI features are enabled
        if cls.USE_FULL_AI or cls.USE_PARTIAL_AI:
            if cls.AI_PROVIDER == "openai" and not cls.OPENAI_API_KEY:
                warnings.append("AI features enabled but OPENAI_API_KEY not set")
            elif cls.AI_PROVIDER == "anthropic" and not cls.ANTHROPIC_API_KEY:
                warnings.append("AI features enabled but ANTHROPIC_API_KEY not set")

        # Check Jackett configuration
        if not cls.JACKETT_URL:
            warnings.append("JACKETT_URL not configured")
        if not cls.JACKETT_API_KEY:
            warnings.append("JACKETT_API_KEY not configured")

        return warnings

    @classmethod
    def print_config(cls):
        """Print current configuration (for debugging)"""
        print(f"=== {cls.APP_NAME} Configuration ===")
        print(f"Version: {cls.VERSION}")
        print(f"Platform: {platform.system()}")
        print(f"\nDirectories:")
        print(f"  Music: {cls.get_music_directory()}")
        print(f"  Config: {cls.get_config_directory()}")
        print(f"\nAPIs:")
        print(f"  Search API: {cls.SEARCH_API_HOST}:{cls.SEARCH_API_PORT}")
        print(f"  Download Daemon: {cls.DOWNLOAD_DAEMON_HOST}:{cls.DOWNLOAD_DAEMON_PORT}")
        print(f"\nJackett:")
        print(f"  URL: {cls.JACKETT_URL}")
        print(f"  API Key: {'*' * len(cls.JACKETT_API_KEY) if cls.JACKETT_API_KEY else 'Not set'}")
        print(f"  Indexer: {cls.JACKETT_INDEXER}")
        print(f"\nAI:")
        print(f"  Provider: {cls.AI_PROVIDER}")
        print(f"  OpenAI Key: {'Set' if cls.OPENAI_API_KEY else 'Not set'}")
        print(f"  Anthropic Key: {'Set' if cls.ANTHROPIC_API_KEY else 'Not set'}")
        print(f"  Full AI: {cls.USE_FULL_AI}")
        print(f"  Partial AI: {cls.USE_PARTIAL_AI}")
        print(f"\nFeatures:")
        print(f"  Skip MusicBrainz: {cls.SKIP_MUSICBRAINZ}")
        print(f"  Min Seeders: {cls.MIN_SEEDERS}")
        print(f"  Max Torrents: {cls.MAX_TORRENTS}")

        # Show warnings
        warnings = cls.validate()
        if warnings:
            print(f"\n⚠️  Warnings:")
            for warning in warnings:
                print(f"  - {warning}")
        else:
            print(f"\n✅ Configuration valid!")


# Singleton instance
config = Config()


if __name__ == "__main__":
    # For testing: print configuration
    config.print_config()
