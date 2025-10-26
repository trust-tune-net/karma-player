"""MusicBrainz search service."""

from typing import List, Optional

from karma_player.musicbrainz import MusicBrainzClient, MusicBrainzResult


class MusicBrainzService:
    """Service for MusicBrainz operations."""

    def __init__(self):
        """Initialize service."""
        self.client = MusicBrainzClient()

    def search_recordings(
        self, query: str, artist: Optional[str] = None, limit: int = 10
    ) -> List[MusicBrainzResult]:
        """Search MusicBrainz for recordings.

        Args:
            query: Search query
            artist: Optional artist filter
            limit: Maximum results

        Returns:
            List of recording results
        """
        return self.client.search_recordings(query, limit=limit, artist=artist)

    def build_torrent_query(self, recording: MusicBrainzResult) -> str:
        """Build torrent search query from MusicBrainz recording.

        Args:
            recording: Selected recording

        Returns:
            Formatted torrent search query
        """
        query = f"{recording.artist} {recording.title}"
        if recording.album:
            query += f" {recording.album}"
        return query
