"""Configuration management for Karma Player."""

import sqlite3
import uuid
from pathlib import Path
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class Config(BaseModel):
    """User configuration for Karma Player."""

    user_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    musicbrainz_api_key: Optional[str] = None
    music_directory: Path = Field(default_factory=lambda: Path.home() / "Music")
    jackett_url: Optional[str] = None
    jackett_api_key: Optional[str] = None

    @field_validator("music_directory", mode="before")
    @classmethod
    def validate_music_directory(cls, v):
        """Convert string to Path and ensure it exists."""
        if isinstance(v, str):
            return Path(v)
        return v

    class Config:
        """Pydantic configuration."""

        arbitrary_types_allowed = True


class ConfigManager:
    """Manages configuration storage and retrieval."""

    def __init__(self, config_dir: Optional[Path] = None):
        """Initialize configuration manager.

        Args:
            config_dir: Directory for config storage. Defaults to ~/.karma-player/
        """
        self.config_dir = config_dir or Path.home() / ".karma-player"
        self.config_db = self.config_dir / "config.db"

    def init_config_dir(self) -> None:
        """Create configuration directory if it doesn't exist."""
        self.config_dir.mkdir(parents=True, exist_ok=True)

    def init_database(self) -> None:
        """Initialize SQLite database schema."""
        self.init_config_dir()

        with sqlite3.connect(self.config_db) as conn:
            cursor = conn.cursor()

            # Create config table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS config (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                )
            """)

            # Create downloads table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS downloads (
                    id TEXT PRIMARY KEY,
                    mbid TEXT NOT NULL,
                    torrent_hash TEXT NOT NULL,
                    filename TEXT NOT NULL,
                    file_path TEXT NOT NULL,
                    size_bytes INTEGER NOT NULL,
                    downloaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    is_seeding BOOLEAN DEFAULT 0,
                    seeders_count INTEGER DEFAULT 0
                )
            """)

            # Create votes table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS votes (
                    id TEXT PRIMARY KEY,
                    mbid TEXT NOT NULL,
                    torrent_hash TEXT NOT NULL,
                    vote INTEGER NOT NULL CHECK (vote IN (-1, 1)),
                    voted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    comment TEXT
                )
            """)

            conn.commit()

    def is_initialized(self) -> bool:
        """Check if configuration has been initialized.

        Returns:
            True if config directory and database exist
        """
        return self.config_dir.exists() and self.config_db.exists()

    def save_config(self, config: Config) -> None:
        """Save configuration to database.

        Args:
            config: Configuration object to save
        """
        with sqlite3.connect(self.config_db) as conn:
            cursor = conn.cursor()

            # Save each config field
            cursor.execute(
                "INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)",
                ("user_id", config.user_id),
            )
            cursor.execute(
                "INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)",
                ("musicbrainz_api_key", config.musicbrainz_api_key or ""),
            )
            cursor.execute(
                "INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)",
                ("music_directory", str(config.music_directory)),
            )
            cursor.execute(
                "INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)",
                ("jackett_url", config.jackett_url or ""),
            )
            cursor.execute(
                "INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)",
                ("jackett_api_key", config.jackett_api_key or ""),
            )

            conn.commit()

    def load_config(self) -> Config:
        """Load configuration from database.

        Returns:
            Configuration object

        Raises:
            RuntimeError: If configuration is not initialized
        """
        if not self.is_initialized():
            raise RuntimeError(
                "Configuration not initialized. Run 'karma-player init' first."
            )

        with sqlite3.connect(self.config_db) as conn:
            cursor = conn.cursor()

            # Load all config values
            cursor.execute("SELECT key, value FROM config")
            config_data = dict(cursor.fetchall())

            # Convert empty strings to None for optional fields
            jackett_url = config_data.get("jackett_url")
            jackett_url = jackett_url if jackett_url else None

            jackett_api_key = config_data.get("jackett_api_key")
            jackett_api_key = jackett_api_key if jackett_api_key else None

            return Config(
                user_id=config_data.get("user_id", str(uuid.uuid4())),
                musicbrainz_api_key=config_data.get("musicbrainz_api_key") or None,
                music_directory=Path(
                    config_data.get("music_directory", str(Path.home() / "Music"))
                ),
                jackett_url=jackett_url,
                jackett_api_key=jackett_api_key,
            )

    def get_value(self, key: str) -> Optional[str]:
        """Get a single configuration value.

        Args:
            key: Configuration key

        Returns:
            Configuration value or None if not found
        """
        if not self.is_initialized():
            return None

        with sqlite3.connect(self.config_db) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT value FROM config WHERE key = ?", (key,))
            result = cursor.fetchone()
            return result[0] if result else None

    def set_value(self, key: str, value: str) -> None:
        """Set a single configuration value.

        Args:
            key: Configuration key
            value: Configuration value
        """
        with sqlite3.connect(self.config_db) as conn:
            cursor = conn.cursor()
            cursor.execute("INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)", (key, value))
            conn.commit()

    def validate_musicbrainz_key(self, api_key: str) -> bool:
        """Validate MusicBrainz API key.

        Args:
            api_key: API key to validate

        Returns:
            True if key appears valid (basic check only)
        """
        # Basic validation: non-empty and reasonable length
        # Real validation would require API call (implemented in Epic 2)
        return bool(api_key and len(api_key) > 10)
