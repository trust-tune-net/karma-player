"""Tests for configuration management."""

import sqlite3
import tempfile
from pathlib import Path

import pytest
from karma_player.config import Config, ConfigManager


@pytest.fixture
def temp_config_dir():
    """Create a temporary config directory for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def config_manager(temp_config_dir):
    """Create a ConfigManager with temporary directory."""
    return ConfigManager(config_dir=temp_config_dir)


class TestConfig:
    """Test Config model."""

    def test_default_values(self):
        """Test Config creates with defaults."""
        config = Config()
        assert config.user_id is not None
        assert len(config.user_id) == 36  # UUID length
        assert config.musicbrainz_api_key is None
        assert config.music_directory == Path.home() / "Music"

    def test_custom_values(self):
        """Test Config with custom values."""
        config = Config(
            user_id="test-user-id",
            musicbrainz_api_key="test-api-key",
            music_directory=Path("/custom/music"),
        )
        assert config.user_id == "test-user-id"
        assert config.musicbrainz_api_key == "test-api-key"
        assert config.music_directory == Path("/custom/music")

    def test_music_directory_string_conversion(self):
        """Test music_directory converts string to Path."""
        config = Config(music_directory="/test/path")
        assert isinstance(config.music_directory, Path)
        assert config.music_directory == Path("/test/path")


class TestConfigManager:
    """Test ConfigManager."""

    def test_init_creates_directory(self, config_manager):
        """Test initialization creates config directory."""
        # Remove if exists from fixture
        if config_manager.config_dir.exists():
            import shutil
            shutil.rmtree(config_manager.config_dir)

        assert not config_manager.config_dir.exists()
        config_manager.init_config_dir()
        assert config_manager.config_dir.exists()

    def test_init_database_creates_tables(self, config_manager):
        """Test database initialization creates all required tables."""
        config_manager.init_database()
        assert config_manager.config_db.exists()

        with sqlite3.connect(config_manager.config_db) as conn:
            cursor = conn.cursor()

            # Check config table exists
            cursor.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='config'"
            )
            assert cursor.fetchone() is not None

            # Check downloads table exists
            cursor.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='downloads'"
            )
            assert cursor.fetchone() is not None

            # Check votes table exists
            cursor.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='votes'"
            )
            assert cursor.fetchone() is not None

    def test_is_initialized(self, config_manager):
        """Test is_initialized check."""
        assert not config_manager.is_initialized()
        config_manager.init_database()
        assert config_manager.is_initialized()

    def test_save_and_load_config(self, config_manager):
        """Test saving and loading configuration."""
        config_manager.init_database()

        # Create and save config
        original_config = Config(
            user_id="test-id",
            musicbrainz_api_key="test-key-12345",
            music_directory=Path("/test/music"),
        )
        config_manager.save_config(original_config)

        # Load config
        loaded_config = config_manager.load_config()

        assert loaded_config.user_id == original_config.user_id
        assert loaded_config.musicbrainz_api_key == original_config.musicbrainz_api_key
        assert loaded_config.music_directory == original_config.music_directory

    def test_load_config_not_initialized(self, config_manager):
        """Test loading config when not initialized raises error."""
        with pytest.raises(RuntimeError, match="not initialized"):
            config_manager.load_config()

    def test_get_value(self, config_manager):
        """Test getting individual config values."""
        config_manager.init_database()
        config = Config(musicbrainz_api_key="test-key-123")
        config_manager.save_config(config)

        value = config_manager.get_value("musicbrainz_api_key")
        assert value == "test-key-123"

    def test_get_value_not_initialized(self, config_manager):
        """Test getting value when not initialized returns None."""
        value = config_manager.get_value("some_key")
        assert value is None

    def test_set_value(self, config_manager):
        """Test setting individual config values."""
        config_manager.init_database()
        config_manager.set_value("test_key", "test_value")

        value = config_manager.get_value("test_key")
        assert value == "test_value"

    def test_validate_musicbrainz_key_valid(self, config_manager):
        """Test validation of valid API key."""
        assert config_manager.validate_musicbrainz_key("valid-api-key-12345")

    def test_validate_musicbrainz_key_invalid(self, config_manager):
        """Test validation of invalid API keys."""
        assert not config_manager.validate_musicbrainz_key("")
        assert not config_manager.validate_musicbrainz_key("short")
        assert not config_manager.validate_musicbrainz_key("   ")


class TestConfigManagerIntegration:
    """Integration tests for ConfigManager."""

    def test_complete_workflow(self, config_manager):
        """Test complete config workflow: init -> save -> load -> update."""
        # Initialize
        config_manager.init_database()
        assert config_manager.is_initialized()

        # Save initial config
        config1 = Config(musicbrainz_api_key="key1")
        config_manager.save_config(config1)

        # Load and verify
        loaded = config_manager.load_config()
        assert loaded.musicbrainz_api_key == "key1"

        # Update config
        config2 = Config(
            user_id=loaded.user_id,  # Keep same user ID
            musicbrainz_api_key="key2",
        )
        config_manager.save_config(config2)

        # Verify update
        updated = config_manager.load_config()
        assert updated.musicbrainz_api_key == "key2"
        assert updated.user_id == loaded.user_id  # User ID should persist

    def test_database_schema(self, config_manager):
        """Test database schema is correct."""
        config_manager.init_database()

        with sqlite3.connect(config_manager.config_db) as conn:
            cursor = conn.cursor()

            # Check downloads table schema
            cursor.execute("PRAGMA table_info(downloads)")
            columns = {row[1]: row[2] for row in cursor.fetchall()}
            assert "id" in columns
            assert "mbid" in columns
            assert "torrent_hash" in columns
            assert "file_path" in columns
            assert "downloaded_at" in columns

            # Check votes table schema
            cursor.execute("PRAGMA table_info(votes)")
            columns = {row[1]: row[2] for row in cursor.fetchall()}
            assert "id" in columns
            assert "mbid" in columns
            assert "vote" in columns
            assert "voted_at" in columns
