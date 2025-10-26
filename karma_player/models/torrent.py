"""
Torrent-related data models
"""
import re
from dataclasses import dataclass
from datetime import datetime
from typing import Optional, List


@dataclass
class TorrentResult:
    """Torrent search result"""
    title: str
    magnet_link: str
    size_bytes: int
    seeders: int
    leechers: int
    uploaded_at: datetime
    indexer: str
    format: Optional[str] = None  # FLAC, MP3, etc.
    bitrate: Optional[str] = None
    source: Optional[str] = None

    @property
    def infohash(self) -> str:
        """Extract infohash from magnet link"""
        match = re.search(r"xt=urn:btih:([a-fA-F0-9]+)", self.magnet_link)
        if match:
            return match.group(1).lower()

        # For Jackett/download URLs, use URL hash as identifier
        if self.magnet_link and not self.magnet_link.startswith("magnet:"):
            import hashlib
            return hashlib.sha1(self.magnet_link.encode()).hexdigest()[:40].lower()

        return ""

    @property
    def size_formatted(self) -> str:
        """Format size as human-readable string"""
        if self.size_bytes == 0 or self.size_bytes < 1024:
            return "Unknown"

        gb = self.size_bytes / (1024**3)
        if gb >= 1.0:
            return f"{gb:.2f} GB"

        mb = self.size_bytes / (1024**2)
        return f"{mb:.2f} MB"

    @property
    def quality_score(self) -> float:
        """
        Calculate quality score for sorting
        Higher scores = better quality
        Prioritizes: Hi-res FLAC > FLAC > 320kbps > V0 > 256kbps
        """
        format_bonus = 0
        if self.format:
            format_upper = self.format.upper()
            if format_upper == "FLAC":
                format_bonus = 200

                # Hi-res audio bonus
                title_upper = self.title.upper()
                if self.bitrate:
                    bitrate_upper = self.bitrate.upper()
                    # DSD (highest quality)
                    if "DSD" in bitrate_upper or "DSD" in title_upper:
                        format_bonus += 100
                    # 24-bit hi-res
                    elif any(marker in bitrate_upper or marker in title_upper for marker in
                             ["24/192", "24/176", "24/96", "24/88", "24BIT", "24-BIT", "24 BIT"]):
                        format_bonus += 60
                    # 16-bit hi-res
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
                format_bonus = 120
            else:
                format_bonus = 80  # MP3/AAC/other

        # Seeder bonus (availability)
        seeder_bonus = min(self.seeders * 2, 100)

        # Size bonus (larger = higher quality for music)
        size_mb = self.size_bytes / (1024 * 1024)
        size_bonus = min(size_mb / 10, 50)

        return format_bonus + seeder_bonus + size_bonus


@dataclass
class RankedResult:
    """AI-ranked torrent result with explanation"""
    torrent: TorrentResult
    rank: int
    explanation: str
    tags: List[str]  # ["best_quality", "trusted", "fast"]


@dataclass
class DownloadProgress:
    """Download progress information"""
    percent: float
    download_rate: int  # bytes/sec
    upload_rate: int  # bytes/sec
    num_seeds: int
    state: str
