"""Tests for CLI entry point."""

import pytest
from click.testing import CliRunner
from karma_player.cli import cli
from karma_player import __version__


@pytest.fixture
def runner():
    """Create a CLI runner for testing."""
    return CliRunner()


class TestCLI:
    """Test CLI commands."""

    def test_version(self, runner):
        """Test --version flag."""
        result = runner.invoke(cli, ["--version"])
        assert result.exit_code == 0
        assert __version__ in result.output
        assert "karma-player" in result.output

    def test_help(self, runner):
        """Test --help flag."""
        result = runner.invoke(cli, ["--help"])
        assert result.exit_code == 0
        assert "Karma Player" in result.output
        assert "AI-powered music search" in result.output
        assert "init" in result.output
        assert "search" in result.output
        assert "stats" in result.output

    def test_init_command(self, runner, monkeypatch, tmp_path):
        """Test init command exists and prompts for input."""
        # Use a temp home to avoid polluting real config
        monkeypatch.setenv("HOME", str(tmp_path))
        # Input: API key, music dir (default), jackett url (skip), jackett key (skip)
        result = runner.invoke(cli, ["init"], input="test-api-key-123456\n\n\n\n")
        assert result.exit_code == 0
        assert "Initializing" in result.output

    def test_search_command(self, runner, monkeypatch, tmp_path):
        """Test search command requires initialization."""
        # Use temp home without config
        monkeypatch.setenv("HOME", str(tmp_path))
        result = runner.invoke(cli, ["search", "test", "query"])
        assert result.exit_code == 1
        assert "not initialized" in result.output

    def test_search_requires_query(self, runner):
        """Test search command requires query argument."""
        result = runner.invoke(cli, ["search"])
        assert result.exit_code != 0

    def test_stats_command(self, runner):
        """Test stats command exists."""
        result = runner.invoke(cli, ["stats"])
        assert result.exit_code == 0
        assert "Total downloads" in result.output
        assert "Karma" in result.output

    def test_seeding_command(self, runner):
        """Test seeding command exists."""
        result = runner.invoke(cli, ["seeding"])
        assert result.exit_code == 0
        assert "seeding" in result.output.lower()

    def test_votes_command(self, runner):
        """Test votes command exists."""
        result = runner.invoke(cli, ["votes"])
        assert result.exit_code == 0
        assert "vote" in result.output.lower()

    def test_config_show(self, runner, monkeypatch, tmp_path):
        """Test config show command shows error when not initialized."""
        # Use a temp directory that doesn't have config
        monkeypatch.setenv("HOME", str(tmp_path))
        result = runner.invoke(cli, ["config", "show"])
        assert result.exit_code == 1
        assert "not initialized" in result.output

    def test_config_requires_action(self, runner):
        """Test config command requires action."""
        result = runner.invoke(cli, ["config"])
        assert result.exit_code != 0


class TestCLIIntegration:
    """Integration tests for CLI."""

    def test_help_shows_all_commands(self, runner):
        """Test that --help shows all expected commands."""
        result = runner.invoke(cli, ["--help"])
        assert result.exit_code == 0

        expected_commands = ["init", "search", "stats", "seeding", "votes", "config"]
        for cmd in expected_commands:
            assert cmd in result.output

    def test_search_help(self, runner):
        """Test search command help."""
        result = runner.invoke(cli, ["search", "--help"])
        assert result.exit_code == 0
        assert "Search for music" in result.output

    def test_config_help(self, runner):
        """Test config command help."""
        result = runner.invoke(cli, ["config", "--help"])
        assert result.exit_code == 0
        assert "show" in result.output
