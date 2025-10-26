"""MusicBrainz API client for metadata queries."""

import time
from typing import List, Optional
from dataclasses import dataclass

import musicbrainzngs


@dataclass
class MusicBrainzResult:
    """A single MusicBrainz search result."""

    mbid: str
    artist: str
    title: str
    album: Optional[str] = None
    year: Optional[int] = None
    duration: Optional[int] = None  # in milliseconds
    score: int = 0  # Search relevance score (0-100)

    def __str__(self) -> str:
        """Human-readable representation."""
        parts = [f"{self.artist} - {self.title}"]
        if self.album:
            parts.append(f"({self.album})")
        if self.year:
            parts.append(f"[{self.year}]")
        return " ".join(parts)

    @property
    def duration_formatted(self) -> str:
        """Format duration as MM:SS."""
        if not self.duration:
            return "Unknown"
        # Convert to int if string
        duration_ms = int(self.duration) if isinstance(self.duration, str) else self.duration
        seconds = duration_ms // 1000
        minutes = seconds // 60
        secs = seconds % 60
        return f"{minutes}:{secs:02d}"


class MusicBrainzClient:
    """Client for querying MusicBrainz API."""

    def __init__(self, app_name: str = "karma-player", app_version: str = "0.1.0", contact: str = ""):
        """Initialize MusicBrainz client.

        Args:
            app_name: Application name for User-Agent
            app_version: Application version
            contact: Contact email or URL
        """
        self.app_name = app_name
        self.app_version = app_version
        self.contact = contact or "https://github.com/your-org/karma-player"

        # Set user agent (required by MusicBrainz)
        musicbrainzngs.set_useragent(app_name, app_version, self.contact)

        # Respect rate limiting (1 request per second)
        musicbrainzngs.set_rate_limit(limit_or_interval=1.0)

    def search_recordings(
        self, query: str, limit: int = 10, artist: Optional[str] = None
    ) -> List[MusicBrainzResult]:
        """Search for recordings (songs) on MusicBrainz.

        Args:
            query: Search query (song title or artist + song)
            limit: Maximum number of results (default 10, max 100)
            artist: Optional artist name to narrow search

        Returns:
            List of MusicBrainzResult objects

        Raises:
            MusicBrainzError: If API request fails
        """
        try:
            # Fetch more results than requested to ensure deterministic sorting
            # MusicBrainz API returns tied scores in non-deterministic order AND
            # returns different result sets across queries (likely due to pagination/sharding).
            # Fetching 100 results ensures we get a stable superset to sort from.
            fetch_limit = min(100, max(100, limit * 5))

            # Build search query
            search_params = {}

            if artist:
                # Specific artist + recording search
                search_params = {
                    "recording": query,
                    "artist": artist,
                    "limit": fetch_limit,
                }
            else:
                # General recording search
                search_params = {
                    "recording": query,
                    "limit": fetch_limit,
                }

            # Execute search
            result = musicbrainzngs.search_recordings(**search_params)

            # Parse results
            recordings = []
            for rec in result.get("recording-list", []):
                # Extract basic info
                mbid = rec.get("id")
                title = rec.get("title", "Unknown Title")
                score = int(rec.get("ext:score", 0))
                duration = rec.get("length")  # in milliseconds

                # Extract artist (first artist credit)
                artist_name = "Unknown Artist"
                if "artist-credit" in rec and rec["artist-credit"]:
                    artist_name = rec["artist-credit"][0].get("name", "Unknown Artist")

                # Extract album and year (from first release)
                album = None
                year = None
                if "release-list" in rec and rec["release-list"]:
                    first_release = rec["release-list"][0]
                    album = first_release.get("title")

                    # Try to get year from date
                    date_str = first_release.get("date", "")
                    if date_str and len(date_str) >= 4:
                        try:
                            year = int(date_str[:4])
                        except ValueError:
                            pass

                recordings.append(
                    MusicBrainzResult(
                        mbid=mbid,
                        artist=artist_name,
                        title=title,
                        album=album,
                        year=year,
                        duration=duration,
                        score=score,
                    )
                )

            # Sort by score (highest first), then by MBID (ascending) for determinism
            # Multiple results can have same score, so secondary sort ensures consistency
            recordings.sort(key=lambda x: (-x.score, x.mbid))

            # Return only the requested number of results
            return recordings[:limit]

        except musicbrainzngs.WebServiceError as e:
            raise MusicBrainzError(f"MusicBrainz API error: {e}") from e
        except musicbrainzngs.NetworkError as e:
            raise MusicBrainzError(f"Network error: {e}") from e
        except musicbrainzngs.ResponseError as e:
            raise MusicBrainzError(f"Invalid response: {e}") from e

    def get_recording_by_mbid(self, mbid: str) -> Optional[MusicBrainzResult]:
        """Get detailed recording information by MBID.

        Args:
            mbid: MusicBrainz ID

        Returns:
            MusicBrainzResult or None if not found
        """
        try:
            result = musicbrainzngs.get_recording_by_id(
                mbid, includes=["artists", "releases"]
            )
            rec = result.get("recording")

            if not rec:
                return None

            # Extract info
            title = rec.get("title", "Unknown Title")
            duration = rec.get("length")

            # Extract artist
            artist_name = "Unknown Artist"
            if "artist-credit" in rec and rec["artist-credit"]:
                artist_name = rec["artist-credit"][0]["artist"]["name"]

            # Extract album and year from first release
            album = None
            year = None
            if "release-list" in rec and rec["release-list"]:
                first_release = rec["release-list"][0]
                album = first_release.get("title")
                date_str = first_release.get("date", "")
                if date_str and len(date_str) >= 4:
                    try:
                        year = int(date_str[:4])
                    except ValueError:
                        pass

            return MusicBrainzResult(
                mbid=mbid,
                artist=artist_name,
                title=title,
                album=album,
                year=year,
                duration=duration,
                score=100,  # Direct lookup = perfect match
            )

        except musicbrainzngs.WebServiceError as e:
            raise MusicBrainzError(f"MusicBrainz API error: {e}") from e


class MusicBrainzError(Exception):
    """Exception raised for MusicBrainz API errors."""

    pass
