"""
Search orchestrator - Combines AI, MusicBrainz, and torrent search
"""
import os
from typing import List, Optional, Dict, Any
from dataclasses import dataclass

from karma_player.models.search import ParsedQuery
from karma_player.models.torrent import TorrentResult, RankedResult
from karma_player.models.query import QueryIntent, MusicQuery
from karma_player.services.musicbrainz_service import MusicBrainzService
from karma_player.services.search.engine import SearchEngine
from karma_player.services.ai.local_ai import LocalAIClient


@dataclass
class SearchProgress:
    """Progress updates during search"""
    stage: str  # "parsing", "musicbrainz", "searching", "ranking", "complete"
    message: str
    progress_percent: int  # 0-100


@dataclass
class SearchResult:
    """Complete search result"""
    query: str
    parsed_query: Optional[ParsedQuery]
    musicbrainz_match: Optional[str]  # MBID or description
    results: List[RankedResult]
    total_found: int
    search_time_ms: int


class SearchOrchestrator:
    """
    Orchestrates the complete search flow:
    1. Parse natural language query (AI)
    2. Look up canonical metadata (MusicBrainz)
    3. Search torrents (multi-source)
    4. Rank and explain results (AI + scoring)
    """

    def __init__(
        self,
        search_engine: SearchEngine,
        musicbrainz: Optional[MusicBrainzService] = None,
        ai_client: Optional[LocalAIClient] = None
    ):
        self.search_engine = search_engine
        self.musicbrainz = musicbrainz or MusicBrainzService()
        self.ai_client = ai_client

        # Try to initialize AI if not provided
        if not self.ai_client:
            try:
                # Try Groq first (fastest)
                if os.getenv("GROQ_API_KEY"):
                    self.ai_client = LocalAIClient(provider="groq")
                # Fallback to OpenAI
                elif os.getenv("OPENAI_API_KEY"):
                    self.ai_client = LocalAIClient(provider="openai")
            except:
                pass  # No AI available, will use fallback

    async def search(
        self,
        query: str,
        progress_callback: Optional[callable] = None
    ) -> SearchResult:
        """
        Execute complete search flow

        Args:
            query: Natural language search query
            progress_callback: Optional callback for progress updates

        Returns:
            SearchResult with ranked torrents
        """
        import time
        start_time = time.time()

        def report_progress(stage: str, message: str, percent: int):
            if progress_callback:
                progress_callback(SearchProgress(stage, message, percent))

        # Stage 1: Parse query
        report_progress("parsing", "Understanding your request...", 10)

        parsed_query = None
        if self.ai_client:
            try:
                parsed_query = await self.ai_client.parse_query(query)
            except:
                pass  # Fall back to simple parsing

        # Fallback: Extract key terms
        if not parsed_query:
            parsed_query = self._fallback_parse(query)

        # Stage 2: MusicBrainz lookup
        report_progress("musicbrainz", "Looking up music metadata...", 30)

        mb_match = None
        if parsed_query.artist or parsed_query.album:
            mb_results = await self.musicbrainz.search_from_parsed_query(
                parsed_query,
                limit=1
            )
            if mb_results:
                mb_match = self.musicbrainz.format_release_info(mb_results[0])

        # Stage 3: Search torrents
        report_progress("searching", f"Searching for {parsed_query.artist or query}...", 50)

        # Build search query
        search_terms = []
        if parsed_query.artist:
            search_terms.append(parsed_query.artist)
        if parsed_query.album:
            search_terms.append(parsed_query.album)
        if parsed_query.track:
            search_terms.append(parsed_query.track)

        search_query = " ".join(search_terms) if search_terms else query

        # Execute search
        torrent_results = await self.search_engine.search(
            query=search_query,
            min_seeders=1
        )

        # Stage 4: Rank results
        report_progress("ranking", "Ranking results by quality...", 80)

        # Create ranked results with simple explanations
        ranked_results = []
        for i, torrent in enumerate(torrent_results[:50], 1):  # Limit to top 50
            explanation = self._generate_explanation(torrent, i)
            tags = self._generate_tags(torrent, i)

            ranked_results.append(
                RankedResult(
                    torrent=torrent,
                    rank=i,
                    explanation=explanation,
                    tags=tags
                )
            )

        # Complete
        report_progress("complete", "Search complete!", 100)

        search_time_ms = int((time.time() - start_time) * 1000)

        return SearchResult(
            query=query,
            parsed_query=parsed_query,
            musicbrainz_match=mb_match,
            results=ranked_results,
            total_found=len(torrent_results),
            search_time_ms=search_time_ms
        )

    def _fallback_parse(self, query: str) -> ParsedQuery:
        """Simple fallback query parsing without AI"""
        # Very basic: assume it's an album search
        parts = query.split()

        if len(parts) <= 2:
            artist = " ".join(parts)
            return ParsedQuery(
                artist=artist,
                album=None,
                track=None,
                year=None,
                query_type="artist",
                confidence=0.5
            )
        else:
            # Crude: first half = artist, second half = album
            mid = len(parts) // 2
            artist = " ".join(parts[:mid])
            album = " ".join(parts[mid:])

            return ParsedQuery(
                artist=artist,
                album=album,
                track=None,
                year=None,
                query_type="album",
                confidence=0.6
            )

    def _generate_explanation(self, torrent: TorrentResult, rank: int) -> str:
        """Generate explanation for torrent ranking"""
        parts = []

        if rank == 1:
            parts.append("🏆 Best match")
        elif rank <= 3:
            parts.append(f"#{rank} Top result")

        if torrent.format:
            if torrent.format == "FLAC":
                parts.append("Lossless quality")
            else:
                parts.append(f"{torrent.format}")

        if torrent.bitrate:
            parts.append(f"{torrent.bitrate}")

        if torrent.seeders >= 50:
            parts.append(f"{torrent.seeders} seeders (very fast)")
        elif torrent.seeders >= 10:
            parts.append(f"{torrent.seeders} seeders (fast)")
        elif torrent.seeders > 0:
            parts.append(f"{torrent.seeders} seeders")

        size_gb = torrent.size_bytes / (1024 * 1024 * 1024)
        if size_gb >= 1:
            parts.append(f"{size_gb:.1f} GB")
        else:
            size_mb = torrent.size_bytes / (1024 * 1024)
            parts.append(f"{size_mb:.0f} MB")

        if torrent.source:
            parts.append(f"Source: {torrent.source}")

        return " • ".join(parts)

    def _generate_tags(self, torrent: TorrentResult, rank: int) -> List[str]:
        """Generate tags for torrent"""
        tags = []

        if rank == 1:
            tags.append("best_quality")

        if torrent.format == "FLAC":
            tags.append("lossless")

            # Check for hi-res
            if torrent.bitrate:
                if "24" in torrent.bitrate or "DSD" in torrent.bitrate.upper():
                    tags.append("hi-res")

        if torrent.seeders >= 50:
            tags.append("fast")
            tags.append("popular")
        elif torrent.seeders >= 10:
            tags.append("fast")

        if torrent.source:
            if torrent.source.upper() in ["CD", "VINYL", "WEB"]:
                tags.append(torrent.source.lower())

        return tags
