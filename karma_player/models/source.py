"""
Unified music source models for torrents, streams, and local files
"""
import re
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Optional, List


class SourceType(Enum):
    """Type of music source"""
    TORRENT = "torrent"
    YOUTUBE = "youtube"
    PIPED = "piped"
    JIOSAAVN = "jiosaavn"
    INVIDIOUS = "invidious"
    LOCAL = "local"


@dataclass
class MusicSource:
    """
    Unified music source supporting torrents, streams, and local files

    Common fields for all source types:
    - id: Unique identifier (infohash, video_id, file_path)
    - title: Display title
    - artist: Artist name(s)
    - format: Audio format (FLAC, MP3, M4A, OPUS, etc.)
    - source_type: Type of source (TORRENT, YOUTUBE, etc.)
    - url: Resource URL (magnet:, https:, file:)
    - quality_score: Unified quality scoring (0-1000)
    - indexer: Source name (Jackett, 1337x, YouTube, etc.)

    Torrent-specific fields (Optional):
    - seeders: Number of seeders
    - leechers: Number of leechers
    - size_bytes: File size in bytes
    - uploaded_at: Upload timestamp

    Streaming-specific fields (Optional):
    - codec: Audio codec (aac, opus, vorbis)
    - bitrate: Bitrate in kbps
    - thumbnail_url: Thumbnail/artwork URL
    - duration_seconds: Track duration
    """

    # Common fields
    id: str
    title: str
    artist: Optional[str] = None
    format: Optional[str] = None  # FLAC, MP3, M4A, OPUS
    source_type: SourceType = SourceType.TORRENT
    url: str = ""
    quality_score: float = 0.0
    indexer: str = "unknown"

    # Torrent-specific fields
    seeders: Optional[int] = None
    leechers: Optional[int] = None
    size_bytes: Optional[int] = None
    uploaded_at: Optional[datetime] = None

    # Streaming-specific fields
    codec: Optional[str] = None  # aac, opus, vorbis
    bitrate: Optional[str] = None  # "128kbps", "320kbps"
    thumbnail_url: Optional[str] = None
    duration_seconds: Optional[int] = None

    # Backward compatibility field for torrent sources
    magnet_link: Optional[str] = None  # Alias for url

    def __post_init__(self):
        """Post-initialization processing"""
        # For backward compatibility with TorrentResult
        if self.magnet_link and not self.url:
            self.url = self.magnet_link
        elif self.url and not self.magnet_link and self.source_type == SourceType.TORRENT:
            self.magnet_link = self.url

        # Auto-calculate quality score if not provided
        if self.quality_score == 0.0:
            self.quality_score = self.calculate_quality_score()

    @property
    def infohash(self) -> str:
        """Extract infohash from magnet link or generate ID hash"""
        if self.source_type == SourceType.TORRENT and self.url:
            match = re.search(r"xt=urn:btih:([a-fA-F0-9]+)", self.url)
            if match:
                return match.group(1).lower()

            # For Jackett/download URLs, use URL hash as identifier
            if not self.url.startswith("magnet:"):
                import hashlib
                return hashlib.sha1(self.url.encode()).hexdigest()[:40].lower()

        return self.id

    @property
    def size_formatted(self) -> str:
        """Format size as human-readable string"""
        if not self.size_bytes or self.size_bytes < 1024:
            return "Unknown"

        gb = self.size_bytes / (1024**3)
        if gb >= 1.0:
            return f"{gb:.2f} GB"

        mb = self.size_bytes / (1024**2)
        return f"{mb:.2f} MB"

    def calculate_quality_score(self) -> float:
        """
        Calculate unified quality score (0-1000 scale)

        For TORRENT sources:
        - Format quality: FLAC (200-360) > ALAC (190) > 320kbps (150) > V0 (140)
        - Seeder bonus: 0-100 based on availability
        - Size bonus: 0-50 based on file size

        For STREAMING sources:
        - Codec quality: FLAC (200) > OPUS (160) > AAC (140) > Vorbis (120)
        - Bitrate bonus: 0-100 based on bitrate
        - Source bonus: 50 for official/verified sources

        Returns: Quality score 0-1000 (higher = better)
        """
        score = 0.0

        if self.source_type == SourceType.TORRENT:
            # Format bonus for torrents
            format_bonus = self._calculate_torrent_format_bonus()

            # Seeder bonus (availability)
            seeder_bonus = min(self.seeders * 2, 100) if self.seeders else 0

            # Size bonus (larger = higher quality for music)
            size_mb = (self.size_bytes / (1024 * 1024)) if self.size_bytes else 0
            size_bonus = min(size_mb / 10, 50)

            score = format_bonus + seeder_bonus + size_bonus

        else:  # Streaming sources (YOUTUBE, PIPED, etc.)
            # Codec/format bonus for streaming
            codec_bonus = self._calculate_streaming_codec_bonus()

            # Bitrate bonus
            bitrate_bonus = self._calculate_bitrate_bonus()

            # Source reliability bonus
            source_bonus = 50  # Base bonus for working streaming source

            score = codec_bonus + bitrate_bonus + source_bonus

        return min(score, 1000.0)  # Cap at 1000

    def _calculate_torrent_format_bonus(self) -> float:
        """Calculate format bonus for torrent sources"""
        if not self.format:
            return 80  # Default for unknown format

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

        return format_bonus

    def _calculate_streaming_codec_bonus(self) -> float:
        """Calculate codec/format bonus for streaming sources"""
        if self.format:
            format_upper = self.format.upper()
            if format_upper == "FLAC":
                return 200
            elif format_upper == "OPUS":
                return 160
            elif format_upper in ["AAC", "M4A"]:
                return 140
            elif format_upper == "VORBIS":
                return 120
            elif format_upper == "MP3":
                return 100

        # Fallback to codec if format not specified
        if self.codec:
            codec_lower = self.codec.lower()
            if "opus" in codec_lower:
                return 160
            elif "aac" in codec_lower:
                return 140
            elif "vorbis" in codec_lower:
                return 120
            elif "mp3" in codec_lower:
                return 100

        return 80  # Unknown codec

    def _calculate_bitrate_bonus(self) -> float:
        """Calculate bitrate bonus (0-100)"""
        if not self.bitrate:
            return 50  # Default mid-range

        # Extract numeric bitrate
        bitrate_str = str(self.bitrate).lower().replace("kbps", "").replace("k", "").strip()
        try:
            bitrate_num = int(bitrate_str)
            # Scale bitrate to 0-100 (128kbps=50, 320kbps=100)
            return min((bitrate_num / 320) * 100, 100)
        except (ValueError, AttributeError):
            return 50

    @classmethod
    def from_torrent_result(cls, torrent: 'TorrentResult') -> 'MusicSource':
        """
        Create MusicSource from legacy TorrentResult
        For backward compatibility during migration
        """
        return cls(
            id=torrent.infohash,
            title=torrent.title,
            format=torrent.format,
            source_type=SourceType.TORRENT,
            url=torrent.magnet_link,
            indexer=torrent.indexer,
            seeders=torrent.seeders,
            leechers=torrent.leechers,
            size_bytes=torrent.size_bytes,
            uploaded_at=torrent.uploaded_at,
            bitrate=torrent.bitrate,
            magnet_link=torrent.magnet_link,
        )

    def to_dict(self) -> dict:
        """Serialize to dictionary for API responses"""
        return {
            "id": self.id,
            "title": self.title,
            "artist": self.artist,
            "format": self.format,
            "source_type": self.source_type.value,
            "url": self.url,
            "quality_score": self.quality_score,
            "indexer": self.indexer,
            # Torrent fields
            "seeders": self.seeders,
            "leechers": self.leechers,
            "size_bytes": self.size_bytes,
            "size_formatted": self.size_formatted if self.size_bytes else None,
            "uploaded_at": self.uploaded_at.isoformat() if self.uploaded_at else None,
            # Streaming fields
            "codec": self.codec,
            "bitrate": self.bitrate,
            "thumbnail_url": self.thumbnail_url,
            "duration_seconds": self.duration_seconds,
        }


@dataclass
class RankedSource:
    """AI-ranked music source with explanation"""
    source: MusicSource
    rank: int
    explanation: str
    tags: List[str]  # ["best_quality", "trusted", "fast", "streaming"]

    def to_dict(self) -> dict:
        """Serialize to dictionary for API responses"""
        return {
            "source": self.source.to_dict(),
            "rank": self.rank,
            "explanation": self.explanation,
            "tags": self.tags,
        }
