"""Terminal UI for displaying torrent search results."""

from typing import List, Optional

from rich.console import Console
from rich.table import Table
from rich.style import Style

from karma_player.torrent.models import TorrentResult


class ResultDisplay:
    """Display torrent search results in terminal with color coding."""

    # Color scheme per EPIC_3.md
    COLOR_FLAC = "green"
    COLOR_MP3_320 = "yellow"
    COLOR_DEFAULT = "white"

    def __init__(self):
        """Initialize display with Rich console."""
        self.console = Console()

    def show_results(
        self,
        results: List[TorrentResult],
        page_size: int = 20,
    ) -> None:
        """Display search results in formatted table with pagination.

        Args:
            results: List of TorrentResult objects
            page_size: Number of results per page
        """
        if not results:
            self.console.print("\n❌ No results found.", style="red")
            return

        current_page = 0
        total_pages = (len(results) - 1) // page_size + 1

        while True:
            start_idx = current_page * page_size
            end_idx = min(start_idx + page_size, len(results))
            page_results = results[start_idx:end_idx]

            # Create table with full width for title
            table = Table(show_header=True, header_style="bold cyan", expand=True)
            table.add_column("#", style="dim", width=5)
            table.add_column("Title", no_wrap=False, overflow="fold")  # Full width
            table.add_column("Format", width=12, no_wrap=False)
            table.add_column("Size", width=12, justify="right")
            table.add_column("Seeds", width=8, justify="right")
            table.add_column("Score", width=8, justify="right")

            # Add rows for current page
            for i, result in enumerate(page_results, start=start_idx + 1):
                # Generate letter label: A-Z, then AA-AZ, BA-BZ, etc.
                letter = self._number_to_letter(i)

                # Determine row color based on format
                color = self._get_format_color(result.format, result.bitrate)

                # Format values
                format_str = result.format or "-"
                if result.bitrate:
                    format_str = f"{format_str} {result.bitrate}"

                size_str = result.size_formatted
                seeds_str = str(result.seeders)
                score_str = f"{result.quality_score:.1f}"

                table.add_row(
                    f"[{letter}]",
                    result.title,  # Full title, no truncation
                    format_str,
                    size_str,
                    seeds_str,
                    score_str,
                    style=color,
                )

            # Show table
            self.console.print("\n")
            self.console.print(table)

            # Show pagination info
            if total_pages > 1:
                self.console.print(
                    f"\n📄 Page {current_page + 1}/{total_pages} "
                    f"(showing {start_idx + 1}-{end_idx} of {len(results)})",
                    style="dim"
                )

                import click
                choice = click.prompt(
                    "\n[n]ext | [p]revious | [c]ontinue",
                    type=str,
                    default="c",
                    show_default=True
                ).strip().lower()

                if choice == "n" and current_page < total_pages - 1:
                    current_page += 1
                    self.console.clear()  # Clear screen before showing next page
                    continue
                elif choice == "p" and current_page > 0:
                    current_page -= 1
                    self.console.clear()  # Clear screen before showing previous page
                    continue
                elif choice == "c" or choice == "":
                    break
                else:
                    break
            else:
                break

    def prompt_selection(
        self,
        results: List[TorrentResult],
        allow_quit: bool = True,
        allow_retry: bool = False,
    ) -> Optional[TorrentResult]:
        """Prompt user to select a result.

        Args:
            results: List of TorrentResult objects
            allow_quit: Allow quitting selection
            allow_retry: Allow retrying with new query (returns special "RETRY" marker)

        Returns:
            Selected TorrentResult, None if quit, or "RETRY" string if retry requested
        """
        if not results:
            return None

        while True:
            # Build prompt with clear options
            max_letter = self._number_to_letter(len(results))

            # Show options clearly
            self.console.print("\n💡 Options:", style="bold")
            self.console.print(f"   Select torrent: [A-{max_letter}]", style="dim")

            if allow_retry:
                self.console.print("   [R]etry with new search query", style="dim")

            if allow_quit:
                self.console.print("   [Q]uit", style="dim")

            prompt = "\nYour choice: "

            try:
                choice = self.console.input(prompt).strip().upper()

                # Handle retry
                if allow_retry and choice in ["R", "RETRY"]:
                    return "RETRY"  # Special marker for retry

                # Handle quit
                if allow_quit and choice in ["Q", "QUIT", "EXIT"]:
                    return None

                # Parse letter selection
                selected = self._parse_letter_selection(choice, results)
                if selected:
                    return selected

                self.console.print(
                    f"❌ Invalid selection. Please enter A-{max_letter}.",
                    style="red",
                )

            except (KeyboardInterrupt, EOFError):
                self.console.print("\n")
                return None

    def _number_to_letter(self, num: int) -> str:
        """Convert number to letter label.

        Args:
            num: Number (1-indexed)

        Returns:
            Letter label (A, B, ..., Z, AA, AB, ...)
        """
        result = ""
        num -= 1  # Convert to 0-indexed

        while True:
            result = chr(65 + (num % 26)) + result
            num = num // 26
            if num == 0:
                break
            num -= 1  # Adjust for AA, BA, etc.

        return result

    def _letter_to_number(self, letter: str) -> Optional[int]:
        """Convert letter label to number.

        Args:
            letter: Letter label (A, B, AA, etc.)

        Returns:
            Number (1-indexed) or None if invalid
        """
        try:
            letter = letter.upper()
            num = 0

            for char in letter:
                if not ('A' <= char <= 'Z'):
                    return None
                num = num * 26 + (ord(char) - 64)

            return num
        except:
            return None

    def _parse_letter_selection(
        self,
        letter: str,
        results: List[TorrentResult],
    ) -> Optional[TorrentResult]:
        """Parse letter input and return selected result.

        Args:
            letter: User input (A, B, AA, etc.)
            results: List of results

        Returns:
            Selected TorrentResult or None if invalid
        """
        num = self._letter_to_number(letter)
        if num is None or num < 1 or num > len(results):
            return None

        return results[num - 1]

    def _get_format_color(self, format_type: Optional[str], bitrate: Optional[str]) -> str:
        """Determine color based on format and bitrate.

        Args:
            format_type: Audio format (FLAC, MP3, etc.)
            bitrate: Bitrate (320, V0, etc.)

        Returns:
            Color name for Rich styling
        """
        if not format_type:
            return self.COLOR_DEFAULT

        format_upper = format_type.upper()

        # FLAC/lossless = green
        if format_upper in ["FLAC", "ALAC", "APE", "WAV"]:
            return self.COLOR_FLAC

        # MP3 320 = yellow
        if format_upper == "MP3" and bitrate == "320":
            return self.COLOR_MP3_320

        # Everything else = default
        return self.COLOR_DEFAULT
