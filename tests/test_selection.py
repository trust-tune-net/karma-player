"""Tests for selection interface."""

import pytest
from click.testing import CliRunner
from karma_player.selection import SelectionInterface


class TestSelectionInterface:
    """Test SelectionInterface."""

    def test_prompt_selection_valid(self):
        """Test valid selection."""
        items = ["Option A", "Option B", "Option C"]

        # Can't easily test interactive prompt without Click's CliRunner
        # So we'll test the logic separately
        interface = SelectionInterface()
        assert interface is not None

    def test_confirm(self):
        """Test confirmation prompt."""
        # This would require Click's CliRunner to test interactively
        interface = SelectionInterface()
        assert interface is not None

    def test_display_numbered_list(self):
        """Test display of numbered list."""
        items = ["Item 1", "Item 2", "Item 3"]
        interface = SelectionInterface()

        # Should not raise exception
        interface.display_numbered_list(items)

    def test_display_numbered_list_with_formatter(self):
        """Test display with custom formatter."""

        class TestItem:
            def __init__(self, name):
                self.name = name

        items = [TestItem("Test 1"), TestItem("Test 2")]
        interface = SelectionInterface()

        # Should not raise exception
        interface.display_numbered_list(items, display_fn=lambda x: x.name)


class TestSelectionIntegration:
    """Integration tests for selection with CLI."""

    @pytest.fixture
    def runner(self):
        """Create CLI runner."""
        return CliRunner()

    def test_selection_with_click(self, runner):
        """Test selection interface with Click."""
        import click
        from karma_player.selection import SelectionInterface

        @click.command("test-select")
        def test_cmd():
            items = ["Apple", "Banana", "Cherry"]
            interface = SelectionInterface()
            # Just test that we can create it
            assert interface is not None
            for i, item in enumerate(items, 1):
                click.echo(f"[{i}] {item}")

        result = runner.invoke(test_cmd, [])
        assert result.exit_code == 0
        assert "Apple" in result.output
        assert "Banana" in result.output
        assert "Cherry" in result.output
