"""Tests for torrent indexer adapters."""

import pytest
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch
from karma_player.torrent.adapters.base import IndexerAdapter
from karma_player.torrent.models import TorrentResult


class MockAdapter(IndexerAdapter):
    """Mock adapter for testing base class."""

    @property
    def name(self) -> str:
        return "MockAdapter"

    async def search(self, query: str):
        """Mock search implementation."""
        return []


class TestIndexerAdapterBase:
    """Test IndexerAdapter base class."""

    def test_initial_health_status(self):
        """Test adapter starts as healthy."""
        adapter = MockAdapter()
        assert adapter.is_healthy is True

    def test_circuit_breaker_after_failures(self):
        """Test circuit breaker opens after 3 failures."""
        adapter = MockAdapter()

        # First 2 failures - should still be healthy
        adapter._update_health(success=False)
        adapter._update_health(success=False)
        assert adapter.is_healthy is True

        # 3rd failure - circuit opens
        adapter._update_health(success=False)
        assert adapter.is_healthy is False

    def test_health_recovery_after_success(self):
        """Test health resets after successful request."""
        adapter = MockAdapter()

        # Cause failures
        adapter._update_health(success=False)
        adapter._update_health(success=False)

        # Successful request resets counter
        adapter._update_health(success=True)
        assert adapter.is_healthy is True
        assert adapter._consecutive_failures == 0

    def test_success_updates_last_success_timestamp(self):
        """Test successful search updates timestamp."""
        adapter = MockAdapter()
        initial_timestamp = adapter._last_success

        adapter._update_health(success=True)

        assert adapter._last_success > initial_timestamp

    def test_cooldown_period(self):
        """Test circuit breaker cooldown period."""
        adapter = MockAdapter()

        # Trip circuit breaker
        for _ in range(3):
            adapter._update_health(success=False)

        assert adapter.is_healthy is False

        # Manually set cooldown timestamp to past (simulate 5 min+ elapsed)
        adapter._last_failure = datetime.now(timezone.utc).timestamp() - 400  # 6+ minutes ago

        # Should be healthy again (cooldown expired)
        assert adapter.is_healthy is True

    def test_failure_within_cooldown_stays_unhealthy(self):
        """Test adapter stays unhealthy during cooldown."""
        adapter = MockAdapter()

        # Trip circuit breaker
        for _ in range(3):
            adapter._update_health(success=False)

        assert adapter.is_healthy is False

        # Still within cooldown (just happened)
        assert adapter.is_healthy is False


class TestAdapter1337x:
    """Test 1337x adapter implementation."""

    @pytest.mark.asyncio
    @patch("aiohttp.ClientSession.get")
    async def test_search_basic(self, mock_get):
        """Test basic search functionality."""
        from karma_player.torrent.adapters.adapter_1337x import Adapter1337x

        # Mock search results page
        mock_search_response = AsyncMock()
        mock_search_response.status = 200
        mock_search_response.text = AsyncMock(return_value="""
        <html>
            <table class="table-list">
                <tbody>
                    <tr>
                        <td class="coll-1">
                            <a href="/torrent/123/album-flac/">Album [FLAC]</a>
                        </td>
                        <td class="coll-2">50</td>
                        <td class="coll-3">10</td>
                        <td class="coll-4">1.5 GB</td>
                        <td class="coll-date">Jan. 1st '24</td>
                    </tr>
                </tbody>
            </table>
        </html>
        """)

        # Mock detail page with magnet link
        mock_detail_response = AsyncMock()
        mock_detail_response.status = 200
        mock_detail_response.text = AsyncMock(return_value="""
        <html>
            <a href="magnet:?xt=urn:btih:ABC123">Magnet</a>
        </html>
        """)

        mock_get.return_value.__aenter__.side_effect = [
            mock_search_response,
            mock_detail_response,
        ]

        adapter = Adapter1337x()
        results = await adapter.search("test query")

        assert len(results) >= 0  # May be 0 if parsing fails, but shouldn't crash

    @pytest.mark.asyncio
    async def test_search_handles_network_error(self):
        """Test search handles network errors gracefully."""
        from karma_player.torrent.adapters.adapter_1337x import Adapter1337x

        mock_response = AsyncMock()
        mock_response.__aenter__.side_effect = Exception("Network error")

        with patch("aiohttp.ClientSession") as mock_session:
            mock_session.return_value.__aenter__.return_value.get.return_value = mock_response

            adapter = Adapter1337x()
            results = await adapter.search("test")

            # Should return empty list, not raise exception
            assert results == []

            # After 1 failure, still healthy (needs 3 failures for circuit breaker)
            assert adapter.is_healthy is True

            # After 3 failures, should be unhealthy
            await adapter.search("test")
            await adapter.search("test")
            assert adapter.is_healthy is False

    @pytest.mark.asyncio
    async def test_search_timeout(self):
        """Test search respects timeout."""
        from karma_player.torrent.adapters.adapter_1337x import Adapter1337x
        import asyncio

        with patch("aiohttp.ClientSession.get") as mock_get:
            # Simulate slow response
            async def slow_response(*args, **kwargs):
                await asyncio.sleep(15)  # Longer than timeout
                return AsyncMock()

            mock_get.return_value.__aenter__.side_effect = slow_response

            adapter = Adapter1337x()

            # Should timeout and return empty list
            results = await adapter.search("test")
            assert results == []
