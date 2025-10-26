"""
MusicBrainz service for canonical music metadata
"""
import musicbrainzngs as mb
from typing import List, Optional, Dict, Any
from datetime import datetime

from karma_player.models.search import MBResult, ParsedQuery
from karma_player import __version__


class MusicBrainzService:
    """
    Interface to MusicBrainz API for canonical music metadata
    """

    def __init__(self, app_name: str = "karma-player", app_version: str = __version__, contact: str = ""):
        """
        Initialize MusicBrainz client

        Args:
            app_name: Application name for user agent
            app_version: Application version
            contact: Contact email (optional but recommended)
        """
        mb.set_useragent(app_name, app_version, contact)
        mb.set_rate_limit(True)  # Respect rate limits (1 request/second)

    async def search_release(
        self,
        artist: Optional[str] = None,
        album: Optional[str] = None,
        year: Optional[int] = None,
        limit: int = 10
    ) -> List[MBResult]:
        """
        Search for music releases

        Args:
            artist: Artist name
            album: Album/release name
            year: Release year
            limit: Maximum results to return

        Returns:
            List of MBResult objects
        """
        # Build query string
        query_parts = []

        if artist:
            query_parts.append(f'artist:"{artist}"')
        if album:
            query_parts.append(f'release:"{album}"')
        if year:
            query_parts.append(f'date:{year}')

        if not query_parts:
            return []

        query = " AND ".join(query_parts)

        try:
            # Search releases
            result = mb.search_releases(query=query, limit=limit)

            mb_results = []
            for release in result.get('release-list', []):
                # Extract artist (primary)
                artist_name = "Unknown Artist"
                if 'artist-credit' in release and release['artist-credit']:
                    artist_name = release['artist-credit'][0]['artist']['name']

                # Extract release date
                release_date = release.get('date', '')

                # Extract country
                country = release.get('country', '')

                # Extract label info
                label = None
                if 'label-info-list' in release and release['label-info-list']:
                    label_info = release['label-info-list'][0]
                    if 'label' in label_info and label_info['label']:
                        label = label_info['label'].get('name')

                # Extract barcode
                barcode = release.get('barcode')

                mb_results.append(
                    MBResult(
                        mbid=release['id'],
                        title=release['title'],
                        artist=artist_name,
                        release_date=release_date,
                        country=country,
                        label=label,
                        barcode=barcode
                    )
                )

            return mb_results

        except Exception as e:
            # MusicBrainz errors (rate limit, network, etc.)
            print(f"MusicBrainz search error: {e}")
            return []

    async def get_release_by_id(self, mbid: str) -> Optional[Dict[str, Any]]:
        """
        Get detailed release information by MBID

        Args:
            mbid: MusicBrainz release ID

        Returns:
            Release info dict or None
        """
        try:
            result = mb.get_release_by_id(
                mbid,
                includes=['artists', 'recordings', 'release-groups', 'labels', 'media']
            )
            return result.get('release')
        except Exception as e:
            print(f"MusicBrainz get release error: {e}")
            return None

    async def search_from_parsed_query(self, query: ParsedQuery, limit: int = 10) -> List[MBResult]:
        """
        Search MusicBrainz using a ParsedQuery object

        Args:
            query: Parsed search query
            limit: Maximum results

        Returns:
            List of MBResult objects
        """
        return await self.search_release(
            artist=query.artist,
            album=query.album,
            year=query.year,
            limit=limit
        )

    def format_release_info(self, mb_result: MBResult) -> str:
        """
        Format MBResult as human-readable string

        Args:
            mb_result: MusicBrainz result

        Returns:
            Formatted string
        """
        parts = [f"{mb_result.title} - {mb_result.artist}"]

        if mb_result.release_date:
            # Extract year from date
            year = mb_result.release_date[:4] if len(mb_result.release_date) >= 4 else mb_result.release_date
            parts.append(f"({year})")

        if mb_result.country:
            parts.append(f"[{mb_result.country}]")

        if mb_result.label:
            parts.append(f"- {mb_result.label}")

        return " ".join(parts)
