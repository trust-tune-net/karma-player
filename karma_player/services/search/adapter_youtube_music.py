"""
YouTube Music streaming adapter using ytmusicapi
"""
import asyncio
import logging
from typing import List, Optional
from ytmusicapi import YTMusic

from karma_player.models.source import MusicSource, SourceType

from .source_adapter import SourceAdapter

logger = logging.getLogger(__name__)


class AdapterYouTubeMusic(SourceAdapter):
    """YouTube Music streaming source adapter"""

    def __init__(self):
        super().__init__()
        self.client = YTMusic()
        logger.info("✅ YouTube Music adapter initialized")

    @property
    def name(self) -> str:
        return "YouTube Music"

    @property
    def source_type(self) -> SourceType:
        return SourceType.YOUTUBE

    async def search(self, query: str) -> List[MusicSource]:
        """
        Search YouTube Music for songs, albums, and artists

        Args:
            query: Search query string

        Returns:
            List of MusicSource objects with streaming metadata
        """
        try:
            logger.info(f"🎵 Searching YouTube Music: '{query}'")

            # Search YouTube Music (supports artist, album, song queries)
            # Filter types: songs, videos, albums, artists, playlists
            # We'll focus on songs for music streaming
            # ytmusicapi is synchronous, so run in thread pool
            results = await asyncio.to_thread(
                self.client.search, query, filter="songs", limit=20
            )

            sources = []
            for item in results:
                try:
                    # Extract basic info
                    video_id = item.get("videoId")
                    if not video_id:
                        continue

                    title = item.get("title", "Unknown")
                    artists = item.get("artists", [])
                    artist_name = artists[0]["name"] if artists else "Unknown Artist"
                    album = item.get("album", {})
                    album_name = album.get("name") if album else None

                    # Build full title
                    full_title = f"{artist_name} - {title}"
                    if album_name:
                        full_title += f" ({album_name})"

                    # Duration
                    duration_seconds = None
                    duration_str = item.get("duration")
                    if duration_str:
                        # Parse "MM:SS" or "H:MM:SS"
                        parts = duration_str.split(":")
                        try:
                            if len(parts) == 2:  # MM:SS
                                duration_seconds = int(parts[0]) * 60 + int(parts[1])
                            elif len(parts) == 3:  # H:MM:SS
                                duration_seconds = int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
                        except ValueError:
                            pass

                    # Thumbnail
                    thumbnails = item.get("thumbnails", [])
                    thumbnail_url = thumbnails[-1]["url"] if thumbnails else None

                    # Build YouTube URL
                    url = f"https://music.youtube.com/watch?v={video_id}"

                    # Create MusicSource
                    source = MusicSource(
                        id=video_id,
                        title=full_title,
                        url=url,
                        source_type=SourceType.YOUTUBE,
                        indexer="youtube_music",
                        # Streaming-specific fields
                        codec="OPUS",  # YouTube Music uses OPUS codec
                        bitrate="256 kbps",  # YouTube Music standard quality
                        thumbnail_url=thumbnail_url,
                        duration_seconds=duration_seconds,
                        # Format for compatibility
                        format="OPUS",
                    )

                    # Calculate quality score
                    source.quality_score = source.calculate_quality_score()

                    sources.append(source)

                except Exception as e:
                    logger.warning(f"Failed to parse YouTube Music result: {e}")
                    continue

            logger.info(f"   → Found {len(sources)} YouTube Music tracks")
            return sources

        except Exception as e:
            logger.error(f"YouTube Music search error: {e}", exc_info=True)
            return []
