"""Orchestrator for the complete music search workflow."""

from dataclasses import dataclass
from typing import List, Optional

from karma_player.config import Config
from karma_player.musicbrainz import MusicBrainzResult
from karma_player.torrent.models import TorrentResult
from karma_player.services.adapter_factory import AdapterFactory
from karma_player.services.musicbrainz_service import MusicBrainzService
from karma_player.services.torrent_service import TorrentSearchService
from karma_player.ai.agent import TorrentAgent, AIDecision
from karma_player.ai.query_parser import QueryParser, ParsedQuery
from karma_player.ai.musicbrainz_filter import MusicBrainzFilter, MusicBrainzSelection


@dataclass
class SearchParams:
    """Parameters for search operation."""

    query: str
    artist: Optional[str] = None
    limit: int = 10
    format_filter: Optional[str] = None
    min_seeders: int = 5
    skip_musicbrainz: bool = False
    profile: Optional[str] = None
    use_ai: bool = False
    ai_model: str = "gpt-4o-mini"
    prefer_song_only: bool = False  # Prioritize single-track torrents over albums


@dataclass
class SearchResult:
    """Result of search operation."""

    torrents: List[TorrentResult]
    musicbrainz_result: Optional[MusicBrainzResult] = None
    query_used: str = ""
    ai_decision: Optional[AIDecision] = None
    parsed_query: Optional[ParsedQuery] = None
    mb_selection: Optional[MusicBrainzSelection] = None


class SearchOrchestrator:
    """Orchestrates the complete search workflow."""

    def __init__(self, config: Config):
        """Initialize orchestrator.

        Args:
            config: User configuration
        """
        self.config = config
        self.mb_service = MusicBrainzService()
        self.adapter_factory = AdapterFactory(config)

    async def search(
        self,
        params: SearchParams,
        selected_recording: Optional[MusicBrainzResult] = None,
    ) -> SearchResult:
        """Execute complete search workflow.

        Args:
            params: Search parameters
            selected_recording: Optional pre-selected MusicBrainz recording

        Returns:
            SearchResult with torrents and metadata
        """
        result = SearchResult(torrents=[], query_used=params.query)

        # Step 1: Determine search query
        if selected_recording:
            result.musicbrainz_result = selected_recording
            result.query_used = self.build_torrent_query_from_musicbrainz(selected_recording)
        elif params.skip_musicbrainz:
            result.query_used = params.query
        else:
            # MusicBrainz search will be handled by CLI for user selection
            # This is just torrent search
            result.query_used = params.query

        # Step 2: Create adapters
        adapters = self.adapter_factory.create_adapters(profile_name=params.profile)

        # Step 3: Search torrents
        torrent_service = TorrentSearchService(adapters)
        result.torrents = await torrent_service.search(
            query=result.query_used,
            format_filter=params.format_filter,
            min_seeders=params.min_seeders,
        )

        # Step 4: AI selection (if enabled)
        if params.use_ai and result.torrents:
            # If user wants song-only, filter to small torrents first
            torrents_to_analyze = result.torrents
            if params.prefer_song_only:
                # Prioritize small torrents (<150MB) that are likely song-only
                def is_likely_song_only(t):
                    size_mb = t.size_bytes / (1024 * 1024) if t.size_bytes else 999999
                    return size_mb < 150 or 'single' in t.title.lower()

                song_only_candidates = [t for t in result.torrents if is_likely_song_only(t)]
                # Use song-only torrents if available, otherwise fallback to all
                if song_only_candidates:
                    torrents_to_analyze = song_only_candidates

            agent = TorrentAgent(model=params.ai_model)
            try:
                result.ai_decision = await agent.select_best_torrent(
                    query=result.query_used,
                    results=torrents_to_analyze,
                    preferences={
                        "format": params.format_filter,
                        "prefer_song_only": params.prefer_song_only,
                    },
                )
            except Exception:
                # Fallback handled in agent
                pass

        return result

    def get_musicbrainz_results(
        self, query: str, artist: Optional[str] = None, limit: int = 10
    ) -> List[MusicBrainzResult]:
        """Search MusicBrainz for recordings.

        Args:
            query: Search query
            artist: Optional artist filter
            limit: Maximum results

        Returns:
            List of MusicBrainz recordings
        """
        return self.mb_service.search_recordings(query, artist=artist, limit=limit)

    async def optimize_query(
        self, original_query: str, context: Optional[str] = None, ai_model: str = "gpt-4o-mini"
    ) -> str:
        """Use AI to optimize search query.

        Args:
            original_query: Original search query
            context: Optional context about search results
            ai_model: AI model to use

        Returns:
            Optimized query
        """
        agent = TorrentAgent(model=ai_model)
        return await agent.optimize_query(original_query, context=context)

    async def interactive_search(
        self,
        query: str,
        ai_model: str = "gpt-4o-mini",
        format_filter: Optional[str] = None,
        min_seeders: int = 5,
        ai_tracker=None
    ) -> tuple[SearchResult, ParsedQuery, MusicBrainzSelection]:
        """Interactive search with AI understanding and MusicBrainz integration.

        This is Phase 1 of conversational search:
        1. AI parses query to understand intent
        2. MusicBrainz lookup for metadata
        3. AI filters/groups results
        4. Return for CLI to prompt user
        5. CLI calls search() with selected option

        Args:
            query: User's natural language query
            ai_model: AI model to use
            format_filter: Optional format filter
            min_seeders: Minimum seeders
            ai_tracker: Optional AI session tracker

        Returns:
            Tuple of (empty SearchResult, ParsedQuery, MusicBrainzSelection)
        """
        # Step 1: AI parses query
        parser = QueryParser(model=ai_model, tracker=ai_tracker)
        parsed = await parser.parse_query(query)

        # Step 2: MusicBrainz lookup
        mb_results = []
        if parsed.artist or parsed.song or parsed.album:
            # Build MusicBrainz query
            mb_query = self._build_musicbrainz_query(parsed)
            mb_results = self.mb_service.search_recordings(
                mb_query,
                artist=parsed.artist,
                limit=20
            )

        # Step 3: AI filters and groups MusicBrainz results
        mb_filter = MusicBrainzFilter(model=ai_model, tracker=ai_tracker)
        mb_selection = await mb_filter.filter_and_group(mb_results, parsed)

        # Return for CLI to handle user selection
        result = SearchResult(
            torrents=[],
            query_used=query,
            parsed_query=parsed,
            mb_selection=mb_selection
        )

        return result, parsed, mb_selection

    def _build_musicbrainz_query(self, parsed: ParsedQuery) -> str:
        """Build MusicBrainz query from parsed query."""
        parts = []

        if parsed.song:
            parts.append(parsed.song)
        if parsed.album:
            parts.append(parsed.album)
        if parsed.artist and not parsed.song and not parsed.album:
            # Artist-only search
            parts.append(parsed.artist)

        return " ".join(parts) if parts else ""

    def build_torrent_query_from_musicbrainz(
        self,
        mb_result: MusicBrainzResult,
        prefer_song_only: bool = False,
        include_year: bool = True
    ) -> str:
        """Build precise torrent query from MusicBrainz result.

        Args:
            mb_result: Selected MusicBrainz result
            prefer_song_only: If True, prioritize song title over album
            include_year: Include year in query

        Returns:
            Formatted torrent search query
        """
        # Sanitize function to clean up album/song names for torrent search
        def sanitize_for_torrent(text: str) -> str:
            # Remove everything after common delimiters (years, edition info, etc.)
            # "OK Computer: OKNOTOK 1997 2017" → "OK Computer"
            if ":" in text:
                text = text.split(":")[0]

            # Remove years and extra info in parentheses/brackets
            import re
            text = re.sub(r'\b(19|20)\d{2}\b', '', text)  # Remove years
            text = re.sub(r'\[.*?\]', '', text)  # Remove [brackets]
            text = re.sub(r'\(.*?\)', '', text)  # Remove (parens)

            return " ".join(text.split())  # Normalize whitespace

        # Always include artist name
        query = mb_result.artist

        # If user wants song-only, prioritize song title
        if prefer_song_only and mb_result.title:
            title_clean = sanitize_for_torrent(mb_result.title)
            query = f"{mb_result.artist} {title_clean}"
        # Otherwise prefer album over song title for better torrent matches
        elif mb_result.album:
            # Album search - more likely to find torrents
            album_clean = sanitize_for_torrent(mb_result.album)
            query = f"{mb_result.artist} {album_clean}"
        elif mb_result.title:
            # Song-only search - fallback
            title_clean = sanitize_for_torrent(mb_result.title)
            query = f"{mb_result.artist} {title_clean}"

        return query
