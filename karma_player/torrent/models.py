"""Torrent result models."""

import re
from dataclasses import dataclass
from datetime import datetime
from typing import Optional


@dataclass
class TorrentResult:
    """A single torrent search result."""

    title: str
    magnet_link: str
    size_bytes: int
    seeders: int
    leechers: int
    uploaded_at: datetime
    indexer: str
    format: Optional[str] = None
    bitrate: Optional[str] = None
    source: Optional[str] = None

    @property
    def infohash(self) -> str:
        """Extract infohash from magnet link or generate hash for download URLs.

        Returns:
            Lowercase infohash, hash of URL, or empty string
        """
        # Try to extract from magnet link
        match = re.search(r"xt=urn:btih:([a-fA-F0-9]+)", self.magnet_link)
        if match:
            return match.group(1).lower()

        # For Jackett/download URLs, use URL hash as identifier for deduplication
        if self.magnet_link and not self.magnet_link.startswith("magnet:"):
            import hashlib
            return hashlib.sha1(self.magnet_link.encode()).hexdigest()[:40].lower()

        return ""

    @property
    def size_formatted(self) -> str:
        """Format size as human-readable string.

        Returns:
            Size formatted as "X.XX GB", "X.XX MB", or "Unknown"
        """
        # Handle missing/invalid size data
        if self.size_bytes == 0 or self.size_bytes < 1024:  # Less than 1KB is suspicious
            return "Unknown"

        gb = self.size_bytes / (1024**3)
        if gb >= 1.0:
            return f"{gb:.2f} GB"

        mb = self.size_bytes / (1024**2)
        return f"{mb:.2f} MB"

    @property
    def quality_score(self) -> float:
        """Calculate quality score for sorting.

        Higher scores are better. Formula prioritizes music quality:
        1. Format quality (Hi-res FLAC > FLAC > 320 > V0 > 256 > others)
        2. Seeder count (availability)
        3. File size (quality indicator)

        Returns:
            Quality score as float
        """
        # Format bonus (most important for music!)
        format_bonus = 0
        if self.format:
            format_upper = self.format.upper()
            if format_upper == "FLAC":
                format_bonus = 200

                # Hi-res audio bonus (24-bit, DSD, etc.)
                title_upper = self.title.upper()
                if self.bitrate:
                    bitrate_upper = self.bitrate.upper()
                    # DSD (highest quality)
                    if "DSD" in bitrate_upper or "DSD" in title_upper:
                        format_bonus += 100
                    # 24-bit hi-res (various sample rates)
                    elif any(marker in bitrate_upper or marker in title_upper for marker in
                             ["24/192", "24/176", "24/96", "24/88", "24BIT", "24-BIT", "24 BIT"]):
                        format_bonus += 60
                    # 16-bit hi-res (better than CD)
                    elif any(marker in bitrate_upper or marker in title_upper for marker in
                             ["16/192", "16/96", "16/88"]):
                        format_bonus += 30

            elif format_upper == "ALAC":
                format_bonus = 190
            elif self.bitrate and "320" in self.bitrate:
                format_bonus = 150
            elif self.bitrate and "V0" in self.bitrate:
                format_bonus = 140
            elif self.bitrate and "256" in self.bitrate:
                format_bonus = 100
            elif format_upper == "MP3":
                format_bonus = 80
            elif format_upper in ["AAC", "OGG", "OPUS"]:
                format_bonus = 70

        # Vinyl/LP bonus (often better mastering for audiophile releases)
        title_upper = self.title.upper()
        if any(marker in title_upper for marker in ["[LP]", "(LP)", "VINYL", "ビニール"]):
            format_bonus += 15

        # Seeder bonus (availability matters, but not as much as quality)
        seeder_bonus = min(self.seeders * 3, 120)  # Increased weight, cap at 120

        # Size bonus (larger usually means better quality, but capped)
        size_gb = self.size_bytes / (1024**3)
        size_bonus = min(size_gb * 4, 25)  # Slightly reduced, cap at 25

        return format_bonus + seeder_bonus + size_bonus

    def __str__(self) -> str:
        """Human-readable representation."""
        parts = [self.title]
        if self.format:
            parts.append(f"[{self.format}]")
        if self.size_bytes:
            parts.append(f"({self.size_formatted})")
        return " ".join(parts)
