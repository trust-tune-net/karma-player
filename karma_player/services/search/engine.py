"""Search engine orchestrator for torrent indexers."""

import asyncio
from typing import List, Optional

from karma_player.models.torrent import TorrentResult
from karma_player.services.search.adapter_base import IndexerAdapter


class SearchEngine:
    """Orchestrates searches across multiple torrent indexers."""

    def __init__(self, adapters: List[IndexerAdapter]):
        """Initialize search engine with adapters.

        Args:
            adapters: List of IndexerAdapter instances
        """
        self.adapters = adapters

    async def search(
        self,
        query: str,
        format_filter: Optional[str] = None,
        min_seeders: int = 5,
    ) -> List[TorrentResult]:
        """Search all healthy indexers and return deduplicated, sorted results.

        Args:
            query: Search query string
            format_filter: Optional format filter (FLAC, MP3, etc.)
            min_seeders: Minimum number of seeders (default 5)

        Returns:
            List of TorrentResult objects, deduplicated and sorted by quality
        """
        # Filter to healthy adapters only
        healthy_adapters = [a for a in self.adapters if a.is_healthy]

        if not healthy_adapters:
            return []

        # Search all adapters concurrently
        tasks = [adapter.search(query) for adapter in healthy_adapters]
        results_lists = await asyncio.gather(*tasks, return_exceptions=True)

        # Combine results from all adapters
        all_results = []
        for adapter, results in zip(healthy_adapters, results_lists):
            if isinstance(results, Exception):
                # Adapter failed, mark unhealthy and continue
                adapter._update_health(success=False)
                continue

            adapter._update_health(success=True)
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

        # Filter by minimum seeders
        filtered_results = [r for r in unique_results if r.seeders >= min_seeders]

        # Filter by format if specified
        if format_filter:
            filtered_results = [
                r for r in filtered_results
                if r.format and r.format.upper() == format_filter.upper()
            ]

        # Sort by quality score (highest first)
        filtered_results.sort(key=lambda r: r.quality_score, reverse=True)

        return filtered_results
