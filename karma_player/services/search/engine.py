"""Search engine orchestrator for music sources."""

import asyncio
import logging
from typing import List, Optional, Callable, Awaitable

from karma_player.models.source import MusicSource, SourceType
from karma_player.services.search.source_adapter import SourceAdapter

logger = logging.getLogger(__name__)


class SearchEngine:
    """Orchestrates searches across multiple music source adapters."""

    def __init__(self, adapters: List[SourceAdapter]):
        """Initialize search engine with adapters.

        Args:
            adapters: List of SourceAdapter instances
        """
        self.adapters = adapters

    async def search(
        self,
        query: str,
        format_filter: Optional[str] = None,
        min_seeders: int = 5,
        timeout_per_adapter: float = 8.0,
        source_type_filter: Optional[str] = None,
        partial_result_callback: Optional[Callable[[str, List[MusicSource]], Awaitable[None]]] = None,
    ) -> List[MusicSource]:
        """Search all healthy sources and return deduplicated, sorted results.

        Args:
            query: Search query string
            format_filter: Optional format filter (FLAC, MP3, etc.)
            min_seeders: Minimum number of seeders (applies to torrent sources only)
            timeout_per_adapter: Maximum time (seconds) to wait for each adapter (default: 8s)
            source_type_filter: Filter by source type: "torrent", "streaming", or None (all)
            partial_result_callback: Optional callback for progressive results (adapter_name, results)

        Returns:
            List of MusicSource objects, deduplicated and sorted by quality
        """
        # Filter to healthy adapters only
        healthy_adapters = [a for a in self.adapters if a.is_healthy]

        # Further filter by source type if specified
        if source_type_filter == "torrent":
            healthy_adapters = [
                a for a in healthy_adapters
                if a.source_type == SourceType.TORRENT
            ]
        elif source_type_filter == "streaming":
            healthy_adapters = [
                a for a in healthy_adapters
                if a.source_type in [SourceType.YOUTUBE, SourceType.PIPED, SourceType.INVIDIOUS]
            ]

        logger.info(f"🔍 Searching with {len(healthy_adapters)} healthy adapters (filter: {source_type_filter or 'all'}, timeout: {timeout_per_adapter}s each)")

        if not healthy_adapters:
            return []

        # Wrap each search with timeout to prevent slow adapters from blocking
        async def search_with_timeout(adapter: SourceAdapter):
            try:
                results = await asyncio.wait_for(
                    adapter.search(query),
                    timeout=timeout_per_adapter
                )

                # Send partial results immediately if callback provided
                if partial_result_callback and results:
                    await partial_result_callback(adapter.name, results)

                adapter._update_health(success=True)
                return results
            except asyncio.TimeoutError:
                logger.warning(f"⏱️  {adapter.name} timed out after {timeout_per_adapter}s")
                adapter._update_health(success=False)
                return []  # Return empty list, continue with other adapters

        # Search all adapters concurrently with timeout protection
        tasks = [search_with_timeout(adapter) for adapter in healthy_adapters]
        results_lists = await asyncio.gather(*tasks, return_exceptions=True)

        # Combine results from all adapters
        all_results = []
        for adapter, results in zip(healthy_adapters, results_lists):
            if isinstance(results, Exception):
                # Adapter failed
                logger.error(f"   ❌ {adapter.name} failed: {results}", exc_info=results)
                adapter._update_health(success=False)
                continue

            logger.info(f"   ✓ {adapter.name}: {len(results)} results")
            all_results.extend(results)

        # Deduplicate by infohash
        seen_hashes = set()
        unique_results = []
        for result in all_results:
            infohash = result.infohash
            if not infohash:
                # No infohash (invalid magnet), include anyway
                unique_results.append(result)
            elif infohash not in seen_hashes:
                seen_hashes.add(infohash)
                unique_results.append(result)
            # else: duplicate, skip

        # Filter by minimum seeders (only applies to torrent sources)
        # Non-torrent sources (streaming) are always included since they don't have seeders
        filtered_results = [
            r for r in unique_results
            if r.seeders is None or r.seeders >= min_seeders
        ]

        # Filter by format if specified
        if format_filter:
            filtered_results = [
                r for r in filtered_results
                if r.format and r.format.upper() == format_filter.upper()
            ]

        # Sort by quality score (highest first)
        filtered_results.sort(key=lambda r: r.quality_score, reverse=True)

        return filtered_results
