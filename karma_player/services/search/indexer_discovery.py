"""
Indexer auto-discovery and performance profiling service.

Discovers configured Jackett indexers on startup, tests their performance,
and continuously monitors and adjusts timeouts based on observed behavior.
"""

import asyncio
import logging
import os
from typing import Optional

from .indexer_profile import IndexerPerformanceClass, IndexerProfileStore
from .jackett_client import JackettClient

logger = logging.getLogger(__name__)


class IndexerDiscovery:
    """
    Auto-discovery service for Jackett indexers.

    Responsibilities:
    - Discover configured indexers from Jackett on startup
    - Test each indexer with a test query to measure performance
    - Build performance profiles for adaptive timeout calculations
    - Periodically re-discover and re-test indexers to adapt to changes
    """

    def __init__(
        self,
        base_url: str,
        api_key: str,
        test_query: str = "radiohead",
        test_timeout: float = 5.0,
        fast_threshold: float = 3.0,
        medium_threshold: float = 8.0
    ):
        """
        Initialize indexer discovery service.

        Args:
            base_url: Jackett base URL
            api_key: Jackett API key
            test_query: Query to use for testing indexers
            test_timeout: Timeout for individual indexer tests
            fast_threshold: Max response time for FAST classification
            medium_threshold: Max response time for MEDIUM classification
        """
        self.jackett_client = JackettClient(base_url, api_key)
        self.profile_store = IndexerProfileStore()
        self.profile_store._fast_threshold = fast_threshold
        self.profile_store._medium_threshold = medium_threshold

        self.test_query = test_query
        self.test_timeout = test_timeout

        self._discovery_task: Optional[asyncio.Task] = None
        self._running = False

    async def discover_and_test_indexers(self) -> None:
        """
        Discover all configured indexers and test their performance.

        This is the main discovery workflow:
        1. Fetch list of configured indexers from Jackett
        2. Test each indexer with the test query
        3. Update performance profiles based on results
        4. Log performance summary
        """
        logger.info("=" * 80)
        logger.info("🔍 INDEXER DISCOVERY STARTING")
        logger.info("=" * 80)
        logger.info(f"   Jackett URL: {self.jackett_client.base_url}")
        logger.info(f"   Test query: '{self.test_query}'")
        logger.info(f"   Test timeout: {self.test_timeout}s")
        logger.info("=" * 80)

        try:
            # Step 1: Discover indexers
            indexers = await self.jackett_client.list_indexers(timeout=10.0)

            if not indexers:
                logger.warning("⚠️  No configured indexers found in Jackett")
                return

            logger.info(f"✅ Found {len(indexers)} configured indexers")

            # Step 2: Test each indexer
            logger.info("")
            logger.info("🧪 Testing indexers...")
            logger.info("-" * 80)

            test_tasks = []
            for indexer in indexers:
                task = self._test_and_profile_indexer(
                    indexer["id"],
                    indexer["name"]
                )
                test_tasks.append(task)

            # Run all tests concurrently
            await asyncio.gather(*test_tasks, return_exceptions=True)

            # Step 3: Log summary
            logger.info("-" * 80)
            self.profile_store.log_performance_summary()

            # Log recommended action
            working = self.profile_store.get_working_indexers()
            fast = self.profile_store.get_fast_indexers()

            if not working:
                logger.error("❌ NO WORKING INDEXERS - All indexers failed or timed out!")
            elif len(fast) == len(indexers):
                logger.info(f"🚀 ALL {len(indexers)} indexers are FAST - excellent performance!")
            else:
                logger.info(f"✅ {len(working)}/{len(indexers)} indexers working ({len(fast)} FAST)")

        except Exception as e:
            logger.error(f"❌ Error during indexer discovery: {e}", exc_info=True)

    async def _test_and_profile_indexer(self, indexer_id: str, indexer_name: str) -> None:
        """
        Test a single indexer and update its performance profile.

        Args:
            indexer_id: Jackett indexer ID
            indexer_name: Human-readable name
        """
        success, response_time, error = await self.jackett_client.test_indexer(
            indexer_id=indexer_id,
            query=self.test_query,
            timeout=self.test_timeout
        )

        # Determine if timeout occurred
        timeout_occurred = error == "timeout" or (
            response_time is not None and response_time >= self.test_timeout
        )

        # Update profile
        profile = self.profile_store.update_profile(
            indexer_id=indexer_id,
            indexer_name=indexer_name,
            response_time=response_time,
            success=success,
            timeout=timeout_occurred
        )

        # Log result
        logger.info(str(profile))

    async def periodic_discovery_loop(self, interval_minutes: int = 60) -> None:
        """
        Periodically re-run discovery to adapt to indexer changes.

        This runs indefinitely as a background task until cancelled.

        Args:
            interval_minutes: How often to re-discover indexers
        """
        self._running = True
        logger.info(f"🔄 Periodic discovery enabled (every {interval_minutes} minutes)")

        try:
            while self._running:
                # Wait for the interval
                await asyncio.sleep(interval_minutes * 60)

                if not self._running:
                    break

                logger.info("🔄 Running periodic indexer discovery...")
                await self.discover_and_test_indexers()

        except asyncio.CancelledError:
            logger.info("🛑 Periodic discovery cancelled")
            raise
        finally:
            self._running = False

    def start_background_discovery(
        self,
        interval_minutes: int = 60,
        run_immediately: bool = True
    ) -> asyncio.Task:
        """
        Start periodic discovery as a background task.

        Args:
            interval_minutes: How often to re-discover
            run_immediately: Whether to run discovery immediately before starting loop

        Returns:
            The background task (so caller can cancel it)
        """
        async def _background_task():
            if run_immediately:
                await self.discover_and_test_indexers()

            await self.periodic_discovery_loop(interval_minutes)

        self._discovery_task = asyncio.create_task(_background_task())
        return self._discovery_task

    def stop_background_discovery(self) -> None:
        """Stop the periodic discovery background task."""
        self._running = False
        if self._discovery_task and not self._discovery_task.done():
            self._discovery_task.cancel()

    def get_profile_store(self) -> IndexerProfileStore:
        """Get the profile store for querying performance data."""
        return self.profile_store


async def create_discovery_service(
    jackett_url: str,
    jackett_api_key: str,
    test_query: Optional[str] = None,
    test_timeout: Optional[float] = None,
    fast_threshold: Optional[float] = None,
    medium_threshold: Optional[float] = None
) -> IndexerDiscovery:
    """
    Factory function to create and initialize discovery service from environment.

    Args:
        jackett_url: Jackett base URL
        jackett_api_key: Jackett API key
        test_query: Override test query (default from env or "radiohead")
        test_timeout: Override test timeout (default from env or 5.0)
        fast_threshold: Override fast threshold (default from env or 3.0)
        medium_threshold: Override medium threshold (default from env or 8.0)

    Returns:
        Initialized IndexerDiscovery instance
    """
    # Load configuration from environment
    test_query = test_query or os.getenv("JACKETT_DISCOVERY_QUERY", "radiohead")
    test_timeout = test_timeout or float(os.getenv("JACKETT_DISCOVERY_TIMEOUT", "5"))
    fast_threshold = fast_threshold or float(os.getenv("JACKETT_FAST_THRESHOLD", "3"))
    medium_threshold = medium_threshold or float(os.getenv("JACKETT_MEDIUM_THRESHOLD", "8"))

    discovery = IndexerDiscovery(
        base_url=jackett_url,
        api_key=jackett_api_key,
        test_query=test_query,
        test_timeout=test_timeout,
        fast_threshold=fast_threshold,
        medium_threshold=medium_threshold
    )

    return discovery
