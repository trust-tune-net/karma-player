"""Torrent search service."""

from typing import List, Optional

from karma_player.torrent.search_engine import SearchEngine
from karma_player.torrent.models import TorrentResult
from karma_player.torrent.adapters.base import IndexerAdapter


class TorrentSearchService:
    """Service for torrent search operations."""

    def __init__(self, adapters: List[IndexerAdapter]):
        """Initialize service.

        Args:
            adapters: List of indexer adapters to use
        """
        self.search_engine = SearchEngine(adapters=adapters)
        self.adapters = adapters

    async def search(
        self,
        query: str,
        format_filter: Optional[str] = None,
        min_seeders: int = 5,
    ) -> List[TorrentResult]:
        """Search for torrents.

        Args:
            query: Search query
            format_filter: Optional format filter (FLAC, MP3, etc.)
            min_seeders: Minimum number of seeders

        Returns:
            List of torrent results
        """
        return await self.search_engine.search(
            query=query,
            format_filter=format_filter,
            min_seeders=min_seeders,
        )

    def get_healthy_adapters(self) -> List[IndexerAdapter]:
        """Get list of healthy adapters.

        Returns:
            List of adapters that are currently healthy
        """
        return [adapter for adapter in self.adapters if adapter.is_healthy]

    def get_adapter_status(self) -> List[tuple[str, bool]]:
        """Get status of all adapters.

        Returns:
            List of (adapter_name, is_healthy) tuples
        """
        return [(adapter.name, adapter.is_healthy) for adapter in self.adapters]
