"""Integration tests for CLI with configuration."""

import tempfile
from pathlib import Path

import pytest
from click.testing import CliRunner
from karma_player.cli import cli
from karma_player.config import ConfigManager


@pytest.fixture
def runner():
    """Create a CLI runner for testing."""
    return CliRunner()


@pytest.fixture
def temp_home(monkeypatch):
    """Create a temporary home directory for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        temp_home_path = Path(tmpdir)
        monkeypatch.setenv("HOME", str(temp_home_path))
        yield temp_home_path


class TestCLIConfigIntegration:
    """Integration tests for CLI configuration commands."""

    def test_init_command_interactive(self, runner, temp_home):
        """Test init command with interactive prompts."""
        result = runner.invoke(
            cli,
            ["init"],
            input="test-api-key-123456\n\n\n\n",  # API key, music dir, jackett url (skip), jackett key (skip)
        )

        assert result.exit_code == 0
        assert "Initializing Karma Player" in result.output
        assert "Configuration saved" in result.output
        assert "User ID:" in result.output

        # Verify config was created
        config_dir = temp_home / ".karma-player"
        assert config_dir.exists()
        assert (config_dir / "config.db").exists()

    def test_init_command_with_options(self, runner, temp_home):
        """Test init command with command-line options."""
        music_dir = temp_home / "CustomMusic"

        result = runner.invoke(
            cli,
            [
                "init",
                "--musicbrainz-key",
                "test-api-key-123456",
                "--music-dir",
                str(music_dir),
            ],
            input="\n\n",  # Skip jackett url and key prompts
        )

        assert result.exit_code == 0
        assert music_dir.exists()  # Should be created

        # Verify config
        config_manager = ConfigManager(config_dir=temp_home / ".karma-player")
        config = config_manager.load_config()
        assert config.musicbrainz_api_key == "test-api-key-123456"
        assert config.music_directory == music_dir

    def test_init_invalid_api_key(self, runner, temp_home):
        """Test init with invalid API key."""
        result = runner.invoke(
            cli,
            ["init", "--musicbrainz-key", "short", "--music-dir", str(temp_home / "Music")],
            input="\n\n",  # Skip jackett prompts
        )

        assert result.exit_code == 1
        assert "appears invalid" in result.output

    def test_init_overwrite_confirmation(self, runner, temp_home):
        """Test init prompts for confirmation when config exists."""
        # First init
        runner.invoke(
            cli,
            [
                "init",
                "--musicbrainz-key",
                "test-api-key-123456",
                "--music-dir",
                str(temp_home / "Music"),
            ],
            input="\n\n",  # Skip jackett prompts
        )

        # Try to init again - decline overwrite
        result = runner.invoke(
            cli,
            ["init"],
            input="test-api-key-654321\n\n\n\nn\n",  # API key, music dir, jackett url, jackett key, no to overwrite
        )

        assert result.exit_code == 0
        assert "already exists" in result.output
        assert "cancelled" in result.output

    def test_config_show_not_initialized(self, runner, temp_home):
        """Test config show when not initialized."""
        result = runner.invoke(cli, ["config", "show"])

        assert result.exit_code == 1
        assert "not initialized" in result.output

    def test_config_show_after_init(self, runner, temp_home):
        """Test config show displays configuration."""
        # Initialize first
        runner.invoke(
            cli,
            [
                "init",
                "--musicbrainz-key",
                "test-api-key-123456",
                "--music-dir",
                str(temp_home / "Music"),
            ],
            input="\n\n",  # Skip jackett prompts
        )

        # Show config
        result = runner.invoke(cli, ["config", "show"])

        assert result.exit_code == 0
        assert "Configuration:" in result.output
        assert "User ID:" in result.output
        assert "MusicBrainz API key:" in result.output
        assert "*" in result.output  # API key should be masked
        assert "3456" in result.output  # Last 4 digits shown
        assert "Music directory:" in result.output

    def test_complete_workflow(self, runner, temp_home):
        """Test complete workflow: init -> config show -> verify files exist."""
        music_dir = temp_home / "TestMusic"

        # Step 1: Initialize
        init_result = runner.invoke(
            cli,
            [
                "init",
                "--musicbrainz-key",
                "my-test-api-key-123",
                "--music-dir",
                str(music_dir),
            ],
            input="\n\n",  # Skip jackett prompts
        )
        assert init_result.exit_code == 0

        # Step 2: Verify config directory created
        config_dir = temp_home / ".karma-player"
        assert config_dir.exists()
        assert (config_dir / "config.db").exists()

        # Step 3: Verify music directory created
        assert music_dir.exists()

        # Step 4: Show config
        show_result = runner.invoke(cli, ["config", "show"])
        assert show_result.exit_code == 0
        assert "my-test-api-key-123"[-4:] in show_result.output

        # Step 5: Verify database tables exist
        config_manager = ConfigManager(config_dir=config_dir)
        config = config_manager.load_config()
        assert config.musicbrainz_api_key == "my-test-api-key-123"
        assert config.music_directory == music_dir
