"""
Search orchestrator - Combines AI, MusicBrainz, and torrent search
"""
import os
from typing import List, Optional, Dict, Any
from dataclasses import dataclass

from karma_player.models.search import ParsedQuery
from karma_player.models.source import MusicSource, RankedSource
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
    results: List[RankedSource]
    total_found: int
    search_time_ms: int


class SearchOrchestrator:
    """
    Orchestrates the complete search flow:
    1. Parse natural language query (AI)
    2. Look up canonical metadata (MusicBrainz)
    3. Search music sources (torrents, streams, etc.)
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
            SearchResult with ranked music sources
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

        # Stage 3: Search music sources
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
        source_results = await self.search_engine.search(
            query=search_query,
            min_seeders=1
        )

        # Stage 4: Rank results
        report_progress("ranking", "Ranking results by quality...", 80)

        # Create ranked results with simple explanations
        ranked_results = []
        for i, source in enumerate(source_results[:50], 1):  # Limit to top 50
            explanation = self._generate_explanation(source, i)
            tags = self._generate_tags(source, i)

            ranked_results.append(
                RankedSource(
                    source=source,
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
            total_found=len(source_results),
            search_time_ms=search_time_ms
        )

    def _fallback_parse(self, query: str) -> ParsedQuery:
        """Improved fallback query parsing without AI"""

        # Check for explicit separators (dash, slash, etc.)
        for separator in [' - ', ' / ', ' | ']:
            if separator in query:
                parts = query.split(separator, 1)
                return ParsedQuery(
                    artist=parts[0].strip(),
                    album=parts[1].strip() if len(parts) > 1 else None,
                    track=None,
                    year=None,
                    query_type="album",
                    confidence=0.8
                )

        words = query.split()

        # Single word or two words = artist only
        if len(words) <= 2:
            return ParsedQuery(
                artist=" ".join(words),
                album=None,
                track=None,
                year=None,
                query_type="artist",
                confidence=0.5
            )

        # Smarter heuristic: Look for common album indicators
        # Common pattern: "artist [album words including 'the', 'of', 'in', etc.]"
        # Strategy: First 1-2 words are usually artist, rest is album

        # If 3-4 words, likely "Artist Album Name"
        if len(words) == 3:
            return ParsedQuery(
                artist=words[0],
                album=" ".join(words[1:]),
                track=None,
                year=None,
                query_type="album",
                confidence=0.6
            )

        if len(words) == 4:
            # Try "Artist Name Album Album" or "Artist Album Album Album"
            # Default to first word as artist, rest as album
            return ParsedQuery(
                artist=words[0],
                album=" ".join(words[1:]),
                track=None,
                year=None,
                query_type="album",
                confidence=0.6
            )

        # 5+ words: First 1-2 words artist, rest album
        # Check if first two words could be band name (both capitalized or common patterns)
        if len(words[0]) <= 3 or (len(words) > 1 and words[1][0].isupper()):
            # Likely two-word artist like "Pink Floyd", "Daft Punk", "The Beatles"
            artist = " ".join(words[:2])
            album = " ".join(words[2:])
        else:
            # Single-word artist
            artist = words[0]
            album = " ".join(words[1:])

        return ParsedQuery(
            artist=artist,
            album=album,
            track=None,
            year=None,
            query_type="album",
            confidence=0.6
        )

    def _generate_explanation(self, source: MusicSource, rank: int) -> str:
        """Generate explanation for music source ranking"""
        parts = []

        if rank == 1:
            parts.append("🏆 Best match")
        elif rank <= 3:
            parts.append(f"#{rank} Top result")

        if source.format:
            if source.format == "FLAC":
                parts.append("Lossless quality")
            else:
                parts.append(f"{source.format}")

        if source.bitrate:
            parts.append(f"{source.bitrate}")

        # Torrent-specific info
        if source.seeders is not None:
            if source.seeders >= 50:
                parts.append(f"{source.seeders} seeders (very fast)")
            elif source.seeders >= 10:
                parts.append(f"{source.seeders} seeders (fast)")
            elif source.seeders > 0:
                parts.append(f"{source.seeders} seeders")

        # Size info (for torrents)
        if source.size_bytes:
            size_gb = source.size_bytes / (1024 * 1024 * 1024)
            if size_gb >= 1:
                parts.append(f"{size_gb:.1f} GB")
            else:
                size_mb = source.size_bytes / (1024 * 1024)
                parts.append(f"{size_mb:.0f} MB")

        # Source type indicator
        if source.source_type.value != "torrent":
            parts.append(f"Source: {source.source_type.value}")

        return " • ".join(parts)

    def _generate_tags(self, source: MusicSource, rank: int) -> List[str]:
        """Generate tags for music source"""
        tags = []

        if rank == 1:
            tags.append("best_quality")

        if source.format == "FLAC":
            tags.append("lossless")

            # Check for hi-res
            if source.bitrate:
                if "24" in source.bitrate or "DSD" in source.bitrate.upper():
                    tags.append("hi-res")

        # Torrent-specific tags
        if source.seeders is not None:
            if source.seeders >= 50:
                tags.append("fast")
                tags.append("popular")
            elif source.seeders >= 10:
                tags.append("fast")

        # Source type tag
        if source.source_type.value != "torrent":
            tags.append(source.source_type.value)

        return tags
