"""
Simple search orchestrator - No MusicBrainz complexity
Just: Query → Parse → Search → Rank → Return
"""
from typing import List, Optional, Callable
from dataclasses import dataclass
import time
import logging

from karma_player.models.torrent import TorrentResult, RankedResult
from karma_player.models.query import MusicQuery
from karma_player.services.search.engine import SearchEngine
from karma_player.services.ai.query_parser import SQLLikeParser, NaturalLanguageToSQL

logger = logging.getLogger(__name__)


@dataclass
class SimpleSearchResult:
    """Simple search result"""
    query: str
    sql_query: Optional[str]
    results: List[RankedResult]
    total_found: int
    search_time_ms: int


class SimpleSearch:
    """
    Simple search - no complexity, just works

    Flow:
    1. Natural language → SQL-like query (optional)
    2. Search torrents
    3. Rank by quality
    4. Return results
    """

    def __init__(self, search_engine: SearchEngine):
        self.search_engine = search_engine

    async def search(
        self,
        query: str,
        format_filter: Optional[str] = None,
        min_seeders: int = 1,
        limit: int = 50,
        progress_callback: Optional[Callable] = None
    ) -> SimpleSearchResult:
        """
        Execute simple search

        Args:
            query: Natural language query or SQL-like syntax
            format_filter: Optional format (FLAC, MP3, etc.)
            min_seeders: Minimum seeders
            limit: Max results to return
            progress_callback: Optional progress updates

        Returns:
            SimpleSearchResult with ranked torrents
        """
        start_time = time.time()

        # Log incoming query
        logger.info(f"🔍 Search query received: '{query}'")

        async def progress(percent: int, message: str):
            if progress_callback:
                await progress_callback(percent, message)

        await progress(10, "Parsing query...")

        # Try to parse as SQL-like query
        music_query = None
        sql_query = None

        if query.upper().startswith("SELECT"):
            # Already SQL-like
            music_query = SQLLikeParser.parse(query)
            sql_query = query
            logger.info(f"   → SQL query detected: {sql_query}")
        else:
            # Convert natural language to SQL
            sql_query = await NaturalLanguageToSQL.convert(query)
            music_query = SQLLikeParser.parse(sql_query)
            logger.info(f"   → Converted to SQL: {sql_query}")

        # Override with explicit filters
        if format_filter:
            music_query.format = format_filter
        if min_seeders > music_query.min_seeders:
            music_query.min_seeders = min_seeders
        if limit:
            music_query.limit = limit

        # Log parsed query details
        parsed_details = []
        if music_query.artist:
            parsed_details.append(f"artist='{music_query.artist}'")
        if music_query.album:
            parsed_details.append(f"album='{music_query.album}'")
        if music_query.track:
            parsed_details.append(f"track='{music_query.track}'")
        if music_query.format:
            parsed_details.append(f"format={music_query.format}")
        logger.info(f"   → Parsed: {', '.join(parsed_details) if parsed_details else 'no specific fields'}")

        await progress(30, "Searching torrents...")

        # Build search string
        search_terms = []
        if music_query.artist:
            search_terms.append(music_query.artist)
        if music_query.album:
            search_terms.append(music_query.album)
        if music_query.track:
            search_terms.append(music_query.track)

        search_str = " ".join(search_terms) if search_terms else query
        logger.info(f"   → Search terms: '{search_str}' (min_seeders={music_query.min_seeders})")

        # Search
        torrents = await self.search_engine.search(
            query=search_str,
            format_filter=music_query.format,
            min_seeders=music_query.min_seeders
        )

        logger.info(f"   → Found {len(torrents)} torrents from indexers")
        await progress(70, "Ranking results...")

        # Rank (already sorted by quality_score)
        ranked = []
        for i, torrent in enumerate(torrents[:music_query.limit], 1):
            explanation = self._explain(torrent, i)
            tags = self._tag(torrent, i)

            ranked.append(RankedResult(
                torrent=torrent,
                rank=i,
                explanation=explanation,
                tags=tags
            ))

        await progress(100, "Complete!")

        search_time_ms = int((time.time() - start_time) * 1000)

        # Log final results
        logger.info(f"   ✅ Returning {len(ranked)} results (from {len(torrents)} total) in {search_time_ms}ms")

        return SimpleSearchResult(
            query=query,
            sql_query=sql_query,
            results=ranked,
            total_found=len(torrents),
            search_time_ms=search_time_ms
        )

    def _explain(self, torrent: TorrentResult, rank: int) -> str:
        """Generate simple explanation"""
        parts = []

        if rank == 1:
            parts.append("🏆")

        if torrent.format:
            parts.append(torrent.format)

        if torrent.bitrate:
            parts.append(torrent.bitrate)

        parts.append(f"{torrent.seeders} seeders")
        parts.append(torrent.size_formatted)

        return " • ".join(parts)

    def _tag(self, torrent: TorrentResult, rank: int) -> List[str]:
        """Generate tags"""
        tags = []

        if rank == 1:
            tags.append("best")

        if torrent.format == "FLAC":
            tags.append("lossless")
            if torrent.bitrate and ("24" in torrent.bitrate or "DSD" in torrent.bitrate.upper()):
                tags.append("hi-res")

        if torrent.seeders >= 50:
            tags.append("fast")

        return tags
