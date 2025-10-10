"""Tests for search engine."""

import pytest
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock
from karma_player.torrent.models import TorrentResult
from karma_player.torrent.search_engine import SearchEngine


class TestSearchEngine:
    """Test SearchEngine orchestrator."""

    @pytest.fixture
    def mock_adapter_healthy(self):
        """Create a mock healthy adapter."""
        adapter = AsyncMock()
        adapter.name = "MockIndexer1"
        adapter.is_healthy = True
        adapter.search.return_value = [
            TorrentResult(
                title="Album [FLAC]",
                magnet_link="magnet:?xt=urn:btih:ABC123",
                size_bytes=1000000000,
                seeders=50,
                leechers=10,
                uploaded_at=datetime.now(timezone.utc),
                indexer="MockIndexer1",
                format="FLAC",
            )
        ]
        return adapter

    @pytest.fixture
    def mock_adapter_unhealthy(self):
        """Create a mock unhealthy adapter."""
        adapter = AsyncMock()
        adapter.name = "MockIndexer2"
        adapter.is_healthy = False
        adapter.search.return_value = []
        return adapter

    @pytest.mark.asyncio
    async def test_search_single_adapter(self, mock_adapter_healthy):
        """Test search with single adapter."""
        engine = SearchEngine(adapters=[mock_adapter_healthy])
        results = await engine.search("test query")

        assert len(results) == 1
        assert results[0].title == "Album [FLAC]"
        mock_adapter_healthy.search.assert_called_once_with("test query")

    @pytest.mark.asyncio
    async def test_search_skips_unhealthy(self, mock_adapter_healthy, mock_adapter_unhealthy):
        """Test search skips unhealthy adapters."""
        engine = SearchEngine(adapters=[mock_adapter_healthy, mock_adapter_unhealthy])
        results = await engine.search("test query")

        assert len(results) == 1
        mock_adapter_healthy.search.assert_called_once()
        mock_adapter_unhealthy.search.assert_not_called()

    @pytest.mark.asyncio
    async def test_search_deduplicates_by_infohash(self):
        """Test search deduplicates results with same infohash."""
        adapter1 = AsyncMock()
        adapter1.name = "Indexer1"
        adapter1.is_healthy = True
        adapter1.search.return_value = [
            TorrentResult(
                title="Album [FLAC]",
                magnet_link="magnet:?xt=urn:btih:ABC123DEF456",
                size_bytes=1000000000,
                seeders=50,
                leechers=10,
                uploaded_at=datetime.now(timezone.utc),
                indexer="Indexer1",
            )
        ]

        adapter2 = AsyncMock()
        adapter2.name = "Indexer2"
        adapter2.is_healthy = True
        adapter2.search.return_value = [
            TorrentResult(
                title="Album [FLAC] Different Title",
                magnet_link="magnet:?xt=urn:btih:ABC123DEF456",  # Same infohash
                size_bytes=1000000000,
                seeders=60,
                leechers=15,
                uploaded_at=datetime.now(timezone.utc),
                indexer="Indexer2",
            )
        ]

        engine = SearchEngine(adapters=[adapter1, adapter2])
        results = await engine.search("test")

        # Should only return 1 result (deduplicated)
        assert len(results) == 1

    @pytest.mark.asyncio
    async def test_search_sorts_by_quality_score(self):
        """Test search sorts results by quality score."""
        adapter = AsyncMock()
        adapter.name = "Indexer"
        adapter.is_healthy = True
        adapter.search.return_value = [
            TorrentResult(
                title="Low Quality",
                magnet_link="magnet:?xt=urn:btih:ABC",
                size_bytes=100000000,
                seeders=10,
                leechers=5,
                uploaded_at=datetime.now(timezone.utc),
                indexer="Indexer",
            ),
            TorrentResult(
                title="High Quality [FLAC]",
                magnet_link="magnet:?xt=urn:btih:DEF",
                size_bytes=1000000000,
                seeders=100,
                leechers=20,
                uploaded_at=datetime.now(timezone.utc),
                indexer="Indexer",
                format="FLAC",
            ),
            TorrentResult(
                title="Medium Quality",
                magnet_link="magnet:?xt=urn:btih:GHI",
                size_bytes=500000000,
                seeders=50,
                leechers=10,
                uploaded_at=datetime.now(timezone.utc),
                indexer="Indexer",
            ),
        ]

        engine = SearchEngine(adapters=[adapter])
        results = await engine.search("test")

        # Should be sorted by quality score (high to low)
        assert results[0].title == "High Quality [FLAC]"
        assert results[1].title == "Medium Quality"
        assert results[2].title == "Low Quality"

    @pytest.mark.asyncio
    async def test_search_filters_by_min_seeders(self, mock_adapter_healthy):
        """Test search filters by minimum seeders."""
        mock_adapter_healthy.search.return_value = [
            TorrentResult(
                title="High Seeders",
                magnet_link="magnet:?xt=urn:btih:ABC",
                size_bytes=1000000000,
                seeders=100,
                leechers=10,
                uploaded_at=datetime.now(timezone.utc),
                indexer="test",
            ),
            TorrentResult(
                title="Low Seeders",
                magnet_link="magnet:?xt=urn:btih:DEF",
                size_bytes=1000000000,
                seeders=2,
                leechers=1,
                uploaded_at=datetime.now(timezone.utc),
                indexer="test",
            ),
        ]

        engine = SearchEngine(adapters=[mock_adapter_healthy])
        results = await engine.search("test", min_seeders=5)

        # Should only return result with seeders >= 5
        assert len(results) == 1
        assert results[0].title == "High Seeders"

    @pytest.mark.asyncio
    async def test_search_filters_by_format(self, mock_adapter_healthy):
        """Test search filters by format."""
        mock_adapter_healthy.search.return_value = [
            TorrentResult(
                title="FLAC Album",
                magnet_link="magnet:?xt=urn:btih:ABC",
                size_bytes=1000000000,
                seeders=50,
                leechers=10,
                uploaded_at=datetime.now(timezone.utc),
                indexer="test",
                format="FLAC",
            ),
            TorrentResult(
                title="MP3 Album",
                magnet_link="magnet:?xt=urn:btih:DEF",
                size_bytes=200000000,
                seeders=60,
                leechers=15,
                uploaded_at=datetime.now(timezone.utc),
                indexer="test",
                format="MP3",
            ),
        ]

        engine = SearchEngine(adapters=[mock_adapter_healthy])
        results = await engine.search("test", format_filter="FLAC")

        # Should only return FLAC results
        assert len(results) == 1
        assert results[0].format == "FLAC"

    @pytest.mark.asyncio
    async def test_search_no_results(self, mock_adapter_healthy):
        """Test search returns empty list when no results."""
        mock_adapter_healthy.search.return_value = []

        engine = SearchEngine(adapters=[mock_adapter_healthy])
        results = await engine.search("nonexistent")

        assert results == []

    @pytest.mark.asyncio
    async def test_search_adapter_exception_handled(self):
        """Test search handles adapter exceptions gracefully."""
        adapter1 = AsyncMock()
        adapter1.name = "FailingIndexer"
        adapter1.is_healthy = True
        adapter1.search.side_effect = Exception("Network error")

        adapter2 = AsyncMock()
        adapter2.name = "WorkingIndexer"
        adapter2.is_healthy = True
        adapter2.search.return_value = [
            TorrentResult(
                title="Working Result",
                magnet_link="magnet:?xt=urn:btih:ABC",
                size_bytes=1000000000,
                seeders=50,
                leechers=10,
                uploaded_at=datetime.now(timezone.utc),
                indexer="WorkingIndexer",
            )
        ]

        engine = SearchEngine(adapters=[adapter1, adapter2])
        results = await engine.search("test")

        # Should still get results from working adapter
        assert len(results) == 1
        assert results[0].title == "Working Result"
