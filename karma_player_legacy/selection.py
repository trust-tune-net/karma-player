"""User selection interface for search results."""

from typing import List, Optional, TypeVar
import click

T = TypeVar("T")


class SelectionInterface:
    """Interactive selection interface for CLI."""

    @staticmethod
    def prompt_selection(
        items: List[T],
        prompt_text: str = "Select an option",
        display_fn=None,
        allow_quit: bool = True,
    ) -> Optional[T]:
        """Prompt user to select from a list of items.

        Args:
            items: List of items to choose from
            prompt_text: Text to display for prompt
            display_fn: Optional function to format item display
            allow_quit: Allow user to quit selection (return None)

        Returns:
            Selected item or None if user quits
        """
        if not items:
            return None

        # Display items
        click.echo(f"\n{prompt_text}:")
        for i, item in enumerate(items, 1):
            if display_fn:
                click.echo(f"  [{i}] {display_fn(item)}")
            else:
                click.echo(f"  [{i}] {item}")

        # Show quit option
        if allow_quit:
            click.echo("  [q] Quit/Cancel")

        # Get user input
        while True:
            try:
                choice = click.prompt(
                    "\nEnter number",
                    type=str,
                    show_default=False,
                )

                # Handle quit
                if allow_quit and choice.lower() in ["q", "quit", "exit", "cancel"]:
                    return None

                # Parse number
                choice_num = int(choice)

                # Validate range
                if 1 <= choice_num <= len(items):
                    return items[choice_num - 1]
                else:
                    click.echo(
                        f"❌ Invalid selection. Please enter 1-{len(items)}.",
                        err=True,
                    )

            except ValueError:
                click.echo(
                    f"❌ Invalid input. Please enter a number (1-{len(items)}) or 'q' to quit.",
                    err=True,
                )
            except (KeyboardInterrupt, EOFError):
                # Handle Ctrl+C or Ctrl+D
                click.echo("\n")
                return None

    @staticmethod
    def confirm(message: str, default: bool = False) -> bool:
        """Ask user for yes/no confirmation.

        Args:
            message: Confirmation message
            default: Default value if user just presses Enter

        Returns:
            True if user confirms, False otherwise
        """
        return click.confirm(message, default=default)

    @staticmethod
    def display_numbered_list(
        items: List[T], display_fn=None, start: int = 1
    ) -> None:
        """Display a numbered list of items.

        Args:
            items: List of items to display
            display_fn: Optional function to format item display
            start: Starting number (default 1)
        """
        for i, item in enumerate(items, start):
            if display_fn:
                click.echo(f"[{i}] {display_fn(item)}")
            else:
                click.echo(f"[{i}] {item}")
