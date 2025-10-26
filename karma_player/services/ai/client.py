"""
Community API client for AI-powered search features
"""
import os
import hashlib
import platform
from typing import List, Dict, Any
from pathlib import Path

import httpx
from karma_player.models.search import ParsedQuery, MBResult
from karma_player.models.torrent import TorrentResult, RankedResult


class CommunityAPIClient:
    """
    Client for TrustTune Community API
    Handles AI-powered query parsing, MusicBrainz filtering, and torrent ranking
    """

    def __init__(self, base_url: str = None):
        self.base_url = base_url or os.getenv(
            "COMMUNITY_API_URL",
            "https://api.trusttune.community/v1"
        )
        self.device_id = self._get_device_id()
        self.timeout = httpx.Timeout(30.0, connect=10.0)

    def _get_device_id(self) -> str:
        """
        Generate privacy-friendly device ID
        Combines machine info with local salt (not personally identifiable)
        """
        config_dir = Path.home() / ".karma-player"
        config_dir.mkdir(exist_ok=True)
        salt_file = config_dir / "device_salt"

        # Get or create salt
        if salt_file.exists():
            salt = salt_file.read_text().strip()
        else:
            import secrets
            salt = secrets.token_hex(16)
            salt_file.write_text(salt)
            salt_file.chmod(0o600)  # Read/write for owner only

        # Combine machine info (not PII)
        info = f"{platform.machine()}-{platform.system()}"
        device_string = f"{info}-{salt}"

        return hashlib.sha256(device_string.encode()).hexdigest()[:16]

    async def parse_query(self, query: str) -> ParsedQuery:
        """
        Parse natural language query into structured data
        Example: "radiohead ok computer" → ParsedQuery(artist="Radiohead", album="OK Computer", ...)
        """
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.base_url}/search/parse",
                json={"query": query},
                headers={"X-Device-ID": self.device_id}
            )
            response.raise_for_status()
            data = response.json()

            return ParsedQuery(
                artist=data.get("artist"),
                album=data.get("album"),
                track=data.get("track"),
                year=data.get("year"),
                query_type=data.get("query_type", "album"),
                confidence=data.get("confidence", 0.0)
            )

    async def filter_musicbrainz(
        self, results: List[MBResult], query: ParsedQuery
    ) -> Dict[str, Any]:
        """
        Use AI to filter MusicBrainz results and ask clarifying questions
        Returns: {"selected": MBResult, "questions": [...]} or {"questions": [...]}
        """
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.base_url}/search/filter",
                json={
                    "results": [
                        {
                            "mbid": r.mbid,
                            "title": r.title,
                            "artist": r.artist,
                            "release_date": r.release_date,
                            "country": r.country,
                            "label": r.label,
                            "barcode": r.barcode
                        }
                        for r in results
                    ],
                    "query": {
                        "artist": query.artist,
                        "album": query.album,
                        "track": query.track,
                        "year": query.year,
                        "query_type": query.query_type
                    }
                },
                headers={"X-Device-ID": self.device_id}
            )
            response.raise_for_status()
            return response.json()

    async def rank_torrents(
        self, torrents: List[TorrentResult], preferences: Dict[str, Any]
    ) -> List[RankedResult]:
        """
        Use AI to rank torrents and provide explanations
        """
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.base_url}/search/rank",
                json={
                    "torrents": [
                        {
                            "title": t.title,
                            "magnet_link": t.magnet_link,
                            "size_bytes": t.size_bytes,
                            "seeders": t.seeders,
                            "leechers": t.leechers,
                            "format": t.format,
                            "bitrate": t.bitrate,
                            "source": t.source,
                            "quality_score": t.quality_score
                        }
                        for t in torrents
                    ],
                    "preferences": preferences
                },
                headers={"X-Device-ID": self.device_id}
            )
            response.raise_for_status()
            data = response.json()

            ranked_results = []
            for item in data.get("results", []):
                # Find matching torrent
                torrent_data = item["torrent"]
                torrent = next(
                    (t for t in torrents if t.magnet_link == torrent_data["magnet_link"]),
                    None
                )
                if torrent:
                    ranked_results.append(
                        RankedResult(
                            torrent=torrent,
                            rank=item["rank"],
                            explanation=item["explanation"],
                            tags=item.get("tags", [])
                        )
                    )

            return ranked_results

    async def check_quota(self) -> Dict[str, Any]:
        """
        Check current rate limit status
        Returns: {"allowed": bool, "used": int, "limit": int, "resets_at": str}
        """
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.get(
                f"{self.base_url}/quota/status",
                headers={"X-Device-ID": self.device_id}
            )
            response.raise_for_status()
            return response.json()
