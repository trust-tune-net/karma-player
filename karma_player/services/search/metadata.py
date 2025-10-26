"""Metadata extraction from torrent titles."""

import re
from typing import Optional


class MetadataExtractor:
    """Extract music metadata from release titles."""

    # Regex patterns (case-insensitive)
    FORMAT_PATTERN = re.compile(
        r"\b(FLAC|MP3|AAC|ALAC|OGG|Opus)\b", re.IGNORECASE
    )
    BITRATE_PATTERN = re.compile(
        r"\b(320|256|192|V0|V2)(?:kbps)?\b", re.IGNORECASE
    )
    SOURCE_PATTERN = re.compile(
        r"\b(WEB|CD|Vinyl|DVD|BD)\b", re.IGNORECASE
    )
    SIZE_PATTERN = re.compile(
        r"([\d,\.]+)\s*(GB|MB|KB)", re.IGNORECASE
    )

    @staticmethod
    def extract_format(title: str) -> Optional[str]:
        """Extract audio format from title.

        Args:
            title: Release title

        Returns:
            Format string (FLAC, MP3, etc.) or None
        """
        if not title:
            return None

        match = MetadataExtractor.FORMAT_PATTERN.search(title)
        if match:
            return match.group(1).upper()
        return None

    @staticmethod
    def extract_bitrate(title: str) -> Optional[str]:
        """Extract bitrate from title.

        Args:
            title: Release title

        Returns:
            Bitrate string (320, V0, etc.) or None
        """
        if not title:
            return None

        match = MetadataExtractor.BITRATE_PATTERN.search(title)
        if match:
            return match.group(1).upper()
        return None

    @staticmethod
    def extract_source(title: str) -> Optional[str]:
        """Extract source from title.

        Args:
            title: Release title

        Returns:
            Source string (WEB, CD, Vinyl, etc.) or None
        """
        if not title:
            return None

        match = MetadataExtractor.SOURCE_PATTERN.search(title)
        if match:
            # Capitalize properly
            source = match.group(1)
            if source.lower() == "vinyl":
                return "Vinyl"
            return source.upper()
        return None

    @staticmethod
    def parse_size(size_str: str) -> int:
        """Parse size string to bytes.

        Args:
            size_str: Size string like "1.5 GB" or "750 MB"

        Returns:
            Size in bytes, or 0 if invalid
        """
        if not size_str:
            return 0

        match = MetadataExtractor.SIZE_PATTERN.search(size_str)
        if not match:
            return 0

        try:
            # Handle comma as decimal separator (European format)
            value_str = match.group(1).replace(",", ".")
            value = float(value_str)
            unit = match.group(2).upper()

            if unit == "GB":
                return int(value * (1024**3))
            elif unit == "MB":
                return int(value * (1024**2))
            elif unit == "KB":
                return int(value * 1024)
            else:
                return 0

        except (ValueError, AttributeError):
            return 0
