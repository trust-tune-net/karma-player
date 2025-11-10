"""Search engine orchestrator for music sources."""

import asyncio
import logging
from typing import List, Optional, Callable, Awaitable

from karma_player.models.source import MusicSource, SourceType
from karma_player.services.search.source_adapter import SourceAdapter
from karma_player.services.search.quality_parser import (
    normalize_title_for_dedup,
    extract_quality_metadata
)

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
        timeout_per_adapter: float = 60.0,
        source_type_filter: Optional[str] = None,
        use_dedup: bool = True,
        max_results: int = 30,
        partial_result_callback: Optional[Callable[[str, List[MusicSource]], Awaitable[None]]] = None,
    ) -> List[MusicSource]:
        """Search all healthy sources and return deduplicated, sorted results.

        Args:
            query: Search query string
            format_filter: Optional format filter (FLAC, MP3, etc.)
            min_seeders: Minimum number of seeders (applies to torrent sources only)
            timeout_per_adapter: Maximum time (seconds) to wait for each adapter (default: 60s)
            source_type_filter: Filter by source type: "torrent", "streaming", or None (all)
            use_dedup: Apply deduplication to results (default: True)
            max_results: Maximum number of results to return (default: 30)
            partial_result_callback: Optional callback for progressive results (adapter_name, results)

        Returns:
            List of MusicSource objects, optionally deduplicated and sorted by quality
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

        adapter_names = ", ".join([a.name for a in healthy_adapters])
        logger.info(f"🔍 Searching with {len(healthy_adapters)} adapters: [{adapter_names}] (filter: {source_type_filter or 'all'}, timeout: {timeout_per_adapter}s)")

        if not healthy_adapters:
            return []

        # Wrap each search with timeout to prevent slow adapters from blocking
        async def search_with_timeout(adapter: SourceAdapter):
            try:
                results = await asyncio.wait_for(
                    adapter.search(query),
                    timeout=timeout_per_adapter
                )

                # Extract quality metadata BEFORE sending partial results
                for result in results:
                    if result.source_type == SourceType.TORRENT and result.format:
                        codec, bitrate = extract_quality_metadata(result.title, result.format)
                        if codec and not result.codec:
                            result.codec = codec
                        if bitrate and not result.bitrate:
                            result.bitrate = bitrate
                            logger.debug(f"✓ Extracted bitrate '{bitrate}' from: {result.title[:60]}")

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
                logger.error(f"   ❌ {adapter.name} failed: {results}")
                adapter._update_health(success=False)
                continue

            # Determine source type for better logging
            source_type = results[0].source_type.value if results else "unknown"
            logger.info(f"   ✓ {adapter.name}: {len(results)} {source_type} results")
            all_results.extend(results)

        # Conditional deduplication based on use_dedup parameter
        if use_dedup:
            logger.info(f"🔧 Deduplication: ENABLED (processing {len(all_results)} raw results)")

            # Step 1: Deduplicate by infohash (exact torrent matches)
            seen_hashes = set()
            infohash_deduped = []
            for result in all_results:
                infohash = result.infohash
                if not infohash:
                    # No infohash (non-torrent sources), include anyway
                    infohash_deduped.append(result)
                elif infohash not in seen_hashes:
                    seen_hashes.add(infohash)
                    infohash_deduped.append(result)
                # else: duplicate infohash, skip

            # Step 2: Parse quality metadata from torrent titles (needed for dedup key)
            for result in infohash_deduped:
                if result.source_type == SourceType.TORRENT and result.format:
                    codec, bitrate = extract_quality_metadata(result.title, result.format)
                    if codec and not result.codec:
                        result.codec = codec
                    if bitrate and not result.bitrate:
                        result.bitrate = bitrate
                        logger.debug(f"✓ Extracted bitrate '{bitrate}' from: {result.title[:60]}")

            # Step 3: Title + format + quality based deduplication
            # Different quality levels of the same release are kept separate
            quality_groups = {}
            non_torrents = []

            for result in infohash_deduped:
                if result.source_type == SourceType.TORRENT:
                    # Group torrents by normalized title + format + quality
                    normalized_title = normalize_title_for_dedup(result.title)
                    format_str = (result.format or "unknown").upper()
                    quality_str = result.bitrate or "unknown"
                    dedup_key = f"{normalized_title}|{format_str}|{quality_str}"

                    logger.debug(f"   Dedup key: {dedup_key} (title={result.title[:50]}, seeders={result.seeders})")

                    if dedup_key not in quality_groups:
                        quality_groups[dedup_key] = []
                    quality_groups[dedup_key].append(result)
                else:
                    # Streaming sources don't need title dedup
                    non_torrents.append(result)

            # For each quality group, keep the best variant (most seeders)
            unique_results = non_torrents
            for dedup_key, group in quality_groups.items():
                if len(group) == 1:
                    # Only one torrent for this quality level, keep it
                    unique_results.append(group[0])
                else:
                    # Multiple torrents with same title/format/quality, keep the one with most seeders
                    best = max(group, key=lambda x: x.seeders or 0)
                    logger.debug(f"   📦 Deduped {len(group)} torrents for key '{dedup_key[:80]}' → keeping best ({best.seeders} seeders)")
                    unique_results.append(best)

            logger.info(f"   → After dedup: {len(unique_results)} unique results")
        else:
            logger.info(f"🔧 Deduplication: DISABLED (raw results mode, {len(all_results)} results)")
            # No deduplication - use raw results from adapters
            # Still extract quality metadata for better display
            for result in all_results:
                if result.source_type == SourceType.TORRENT and result.format:
                    codec, bitrate = extract_quality_metadata(result.title, result.format)
                    if codec and not result.codec:
                        result.codec = codec
                    if bitrate and not result.bitrate:
                        result.bitrate = bitrate
            unique_results = all_results

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

        # Apply max_results limit
        if max_results > 0 and len(filtered_results) > max_results:
            logger.info(f"   → Limiting results from {len(filtered_results)} to {max_results}")
            filtered_results = filtered_results[:max_results]

        return filtered_results
