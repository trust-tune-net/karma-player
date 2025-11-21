"""
Simple search orchestrator - No MusicBrainz complexity
Just: Query → Parse → Search → Rank → Return
"""
from typing import List, Optional, Callable, Awaitable
from dataclasses import dataclass
import time
import logging
import inspect

from karma_player.models.source import MusicSource, RankedSource
from karma_player.models.query import MusicQuery
from karma_player.services.search.engine import SearchEngine
from karma_player.services.ai.query_parser import SQLLikeParser, NaturalLanguageToSQL

logger = logging.getLogger(__name__)


@dataclass
class SimpleSearchResult:
    """Simple search result"""
    query: str
    sql_query: Optional[str]
    results: List[RankedSource]
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
        limit: int = 20,
        offset: int = 0,
        use_ai_parsing: bool = False,
        source_type_filter: Optional[str] = None,
        use_dedup: bool = True,
        max_results: int = 30,
        progress_callback: Optional[Callable] = None,
        partial_result_callback: Optional[Callable[[str, List[MusicSource]], Awaitable[None]]] = None
    ) -> SimpleSearchResult:
        """
        Execute simple search

        Args:
            query: Natural language query or SQL-like syntax
            format_filter: Optional format (FLAC, MP3, etc.)
            min_seeders: Minimum seeders
            limit: Max results to return
            offset: Number of results to skip (for pagination)
            use_ai_parsing: Enable AI query parsing (default: False for performance)
            source_type_filter: Filter by source type: "torrent", "streaming", or None (all)
            use_dedup: Apply deduplication to results (default: True)
            max_results: Maximum number of results to fetch and cache (default: 30)
            progress_callback: Optional progress updates
            partial_result_callback: Optional partial result streaming

        Returns:
            SimpleSearchResult with ranked results
        """
        start_time = time.time()

        # Log incoming query
        logger.info(f"🔍 Search query received: '{query}' (AI parsing: {use_ai_parsing})")

        async def progress(percent: int, message: str):
            if progress_callback:
                # Handle both sync and async callbacks
                if inspect.iscoroutinefunction(progress_callback):
                    await progress_callback(percent, message)
                else:
                    progress_callback(percent, message)

        await progress(10, "Parsing query...")

        # Query parsing logic
        music_query = None
        sql_query = None

        if use_ai_parsing and query.upper().startswith("SELECT"):
            # Already SQL-like query (for power users)
            music_query = SQLLikeParser.parse(query)
            sql_query = query
            logger.info(f"   → SQL query detected: {sql_query}")
        elif use_ai_parsing:
            # AI conversion (opt-in for power users)
            sql_query = await NaturalLanguageToSQL.convert(query)
            music_query = SQLLikeParser.parse(sql_query)
            logger.info(f"   → AI converted to SQL: {sql_query}")
        else:
            # Default: Direct pass-through (FAST! No AI overhead)
            # Create minimal MusicQuery for filters only
            music_query = MusicQuery(
                query_type="album",  # Default type (doesn't matter for direct search)
                min_seeders=min_seeders,
                limit=limit,
                format=format_filter
            )
            sql_query = None
            logger.info(f"   → Direct pass-through (no AI)")

        # Override with explicit filters
        if format_filter:
            music_query.format = format_filter
        if min_seeders > music_query.min_seeders:
            music_query.min_seeders = min_seeders
        if limit:
            music_query.limit = limit

        # Log parsed query details (if AI parsing was used)
        if use_ai_parsing:
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

        await progress(30, "Searching...")

        # Build search string - use original query for direct pass-through
        if use_ai_parsing:
            # AI parsing: build from extracted fields
            search_terms = []
            if music_query.artist:
                search_terms.append(music_query.artist)
            if music_query.album:
                search_terms.append(music_query.album)
            if music_query.track:
                search_terms.append(music_query.track)
            search_str = " ".join(search_terms) if search_terms else query
        else:
            # Direct pass-through: use original query as-is
            search_str = query

        logger.info(f"   → Searching: '{search_str}' (min_seeders={min_seeders}, limit={limit}, use_dedup={use_dedup}, max_results={max_results})")

        # Search
        torrents = await self.search_engine.search(
            query=search_str,
            format_filter=music_query.format,
            min_seeders=music_query.min_seeders,
            source_type_filter=source_type_filter,
            use_dedup=use_dedup,
            max_results=max_results,
            partial_result_callback=partial_result_callback
        )

        logger.info(f"   → Found {len(torrents)} sources from search engine")
        await progress(70, "Ranking results...")

        # Rank (already sorted by quality_score)
        # Return all sources - pagination is handled at gRPC layer
        ranked = []
        for i, source in enumerate(torrents, start=1):
            explanation = self._explain(source, i)
            tags = self._tag(source, i)

            ranked.append(RankedSource(
                source=source,
                rank=i,
                explanation=explanation,
                tags=tags
            ))

        await progress(100, "Complete!")

        search_time_ms = int((time.time() - start_time) * 1000)

        # Log final results
        logger.info(f"   ✅ Returning {len(ranked)} results at offset {offset} (from {len(torrents)} total) in {search_time_ms}ms")

        return SimpleSearchResult(
            query=query,
            sql_query=sql_query,
            results=ranked,
            total_found=len(torrents),
            search_time_ms=search_time_ms
        )

    def _explain(self, source: MusicSource, rank: int) -> str:
        """Generate simple explanation"""
        parts = []

        if rank == 1:
            parts.append("🏆")

        if source.format:
            parts.append(source.format)

        if source.bitrate:
            parts.append(source.bitrate)

        if source.seeders is not None:
            parts.append(f"{source.seeders} seeders")

        if source.size_formatted:
            parts.append(source.size_formatted)

        return " • ".join(parts)

    def _tag(self, source: MusicSource, rank: int) -> List[str]:
        """Generate tags"""
        tags = []

        if rank == 1:
            tags.append("best")

        if source.format == "FLAC":
            tags.append("lossless")
            if source.bitrate and ("24" in source.bitrate or "DSD" in source.bitrate.upper()):
                tags.append("hi-res")

        if source.seeders is not None and source.seeders >= 50:
            tags.append("fast")

        return tags
