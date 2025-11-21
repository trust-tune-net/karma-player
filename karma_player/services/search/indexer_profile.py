"""
Indexer performance profiling and adaptive timeout management.

This module tracks the performance of individual Jackett indexers and provides
adaptive timeout calculations based on observed behavior.
"""

import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Dict, Optional

logger = logging.getLogger(__name__)


class IndexerPerformanceClass(str, Enum):
    """Performance classification for indexers based on response time."""
    FAST = "fast"           # < 3s response time
    MEDIUM = "medium"       # 3-8s response time
    SLOW = "slow"          # > 8s response time
    FAILED = "failed"      # Timeout or error


@dataclass
class IndexerPerformance:
    """
    Performance profile for a single indexer.

    Tracks response times, success rates, and performance classification
    to enable adaptive timeout adjustments.
    """
    indexer_id: str
    indexer_name: str
    performance_class: IndexerPerformanceClass
    avg_response_time: float  # Rolling average in seconds
    last_test_time: datetime
    test_count: int = 0
    failure_count: int = 0
    timeout_count: int = 0
    suggested_timeout: float = 6.0  # Dynamic timeout recommendation

    def update_from_test(
        self,
        response_time: Optional[float],
        success: bool,
        timeout: bool,
        fast_threshold: float = 3.0,
        medium_threshold: float = 8.0
    ) -> None:
        """
        Update performance metrics based on a test result.

        Args:
            response_time: Time taken for the request (None if failed)
            success: Whether the request succeeded
            timeout: Whether the request timed out
            fast_threshold: Maximum response time for FAST classification
            medium_threshold: Maximum response time for MEDIUM classification
        """
        self.test_count += 1
        self.last_test_time = datetime.now(timezone.utc)

        if timeout:
            self.timeout_count += 1
        if not success:
            self.failure_count += 1

        # Update rolling average (70% old, 30% new)
        if response_time is not None:
            if self.avg_response_time == 0:
                self.avg_response_time = response_time
            else:
                self.avg_response_time = (self.avg_response_time * 0.7 + response_time * 0.3)

        # Classify performance
        if not success or timeout:
            self.performance_class = IndexerPerformanceClass.FAILED
        elif response_time is not None:
            if response_time < fast_threshold:
                self.performance_class = IndexerPerformanceClass.FAST
            elif response_time < medium_threshold:
                self.performance_class = IndexerPerformanceClass.MEDIUM
            else:
                self.performance_class = IndexerPerformanceClass.SLOW

        # Adjust suggested timeout dynamically
        self._adjust_suggested_timeout()

    def _adjust_suggested_timeout(self) -> None:
        """
        Dynamically adjust the suggested timeout based on performance history.

        Strategy:
        - FAST indexers: 2x average response time (aggressive)
        - MEDIUM indexers: 2.5x average response time (balanced)
        - SLOW indexers: 3x average response time (conservative)
        - FAILED indexers: Reduce to minimum (1s) to fail fast
        """
        if self.performance_class == IndexerPerformanceClass.FAILED:
            # Fail fast for broken indexers
            self.suggested_timeout = 1.0
        elif self.avg_response_time > 0:
            if self.performance_class == IndexerPerformanceClass.FAST:
                multiplier = 2.0
            elif self.performance_class == IndexerPerformanceClass.MEDIUM:
                multiplier = 2.5
            else:  # SLOW
                multiplier = 3.0

            self.suggested_timeout = max(1.0, min(15.0, self.avg_response_time * multiplier))
        else:
            # No data yet, use default
            self.suggested_timeout = 6.0

    @property
    def success_rate(self) -> float:
        """Calculate success rate as percentage."""
        if self.test_count == 0:
            return 0.0
        return ((self.test_count - self.failure_count) / self.test_count) * 100

    @property
    def timeout_rate(self) -> float:
        """Calculate timeout rate as percentage."""
        if self.test_count == 0:
            return 0.0
        return (self.timeout_count / self.test_count) * 100

    def __str__(self) -> str:
        """Human-readable summary of performance."""
        emoji = {
            IndexerPerformanceClass.FAST: "🚀",
            IndexerPerformanceClass.MEDIUM: "⚡",
            IndexerPerformanceClass.SLOW: "🐌",
            IndexerPerformanceClass.FAILED: "❌"
        }.get(self.performance_class, "❓")

        return (
            f"{emoji} {self.indexer_name} ({self.indexer_id}): "
            f"{self.performance_class.value.upper()} | "
            f"avg={self.avg_response_time:.2f}s | "
            f"timeout={self.suggested_timeout:.1f}s | "
            f"success={self.success_rate:.0f}% | "
            f"tests={self.test_count}"
        )


class IndexerProfileStore:
    """
    Manages performance profiles for multiple indexers.

    Provides methods to update profiles, query performance data,
    and calculate adaptive timeouts for the search system.
    """

    def __init__(self):
        self._profiles: Dict[str, IndexerPerformance] = {}
        self._fast_threshold: float = 3.0
        self._medium_threshold: float = 8.0

    def update_profile(
        self,
        indexer_id: str,
        indexer_name: str,
        response_time: Optional[float],
        success: bool,
        timeout: bool
    ) -> IndexerPerformance:
        """
        Update or create a performance profile for an indexer.

        Args:
            indexer_id: Unique identifier for the indexer
            indexer_name: Human-readable name
            response_time: Time taken for the request (None if failed)
            success: Whether the request succeeded
            timeout: Whether the request timed out

        Returns:
            Updated performance profile
        """
        if indexer_id not in self._profiles:
            self._profiles[indexer_id] = IndexerPerformance(
                indexer_id=indexer_id,
                indexer_name=indexer_name,
                performance_class=IndexerPerformanceClass.MEDIUM,
                avg_response_time=0.0,
                last_test_time=datetime.now(timezone.utc)
            )

        profile = self._profiles[indexer_id]
        profile.update_from_test(
            response_time=response_time,
            success=success,
            timeout=timeout,
            fast_threshold=self._fast_threshold,
            medium_threshold=self._medium_threshold
        )

        return profile

    def get_profile(self, indexer_id: str) -> Optional[IndexerPerformance]:
        """Get performance profile for an indexer."""
        return self._profiles.get(indexer_id)

    def get_all_profiles(self) -> Dict[str, IndexerPerformance]:
        """Get all performance profiles."""
        return self._profiles.copy()

    def get_fast_indexers(self) -> list[IndexerPerformance]:
        """Get all FAST-classified indexers."""
        return [
            p for p in self._profiles.values()
            if p.performance_class == IndexerPerformanceClass.FAST
        ]

    def get_working_indexers(self) -> list[IndexerPerformance]:
        """Get all non-FAILED indexers."""
        return [
            p for p in self._profiles.values()
            if p.performance_class != IndexerPerformanceClass.FAILED
        ]

    def get_suggested_timeout(self, indexer_id: str, default: float = 6.0) -> float:
        """
        Get the suggested timeout for an indexer.

        Args:
            indexer_id: Indexer to query
            default: Default timeout if no profile exists

        Returns:
            Suggested timeout in seconds
        """
        profile = self._profiles.get(indexer_id)
        if profile is None:
            return default
        return profile.suggested_timeout

    def log_performance_summary(self) -> None:
        """Log a summary of all indexer performance."""
        if not self._profiles:
            logger.info("📊 No indexer profiles yet")
            return

        fast = [p for p in self._profiles.values() if p.performance_class == IndexerPerformanceClass.FAST]
        medium = [p for p in self._profiles.values() if p.performance_class == IndexerPerformanceClass.MEDIUM]
        slow = [p for p in self._profiles.values() if p.performance_class == IndexerPerformanceClass.SLOW]
        failed = [p for p in self._profiles.values() if p.performance_class == IndexerPerformanceClass.FAILED]

        logger.info("=" * 80)
        logger.info("📊 INDEXER PERFORMANCE SUMMARY")
        logger.info("=" * 80)
        logger.info(f"🚀 FAST ({len(fast)}): {[p.indexer_name for p in fast]}")
        logger.info(f"⚡ MEDIUM ({len(medium)}): {[p.indexer_name for p in medium]}")
        logger.info(f"🐌 SLOW ({len(slow)}): {[p.indexer_name for p in slow]}")
        logger.info(f"❌ FAILED ({len(failed)}): {[p.indexer_name for p in failed]}")
        logger.info("=" * 80)

        # Log detailed stats for each
        for profile in sorted(self._profiles.values(), key=lambda p: p.avg_response_time):
            logger.info(str(profile))

        logger.info("=" * 80)

    def clear(self) -> None:
        """Clear all profiles (for testing or reset)."""
        self._profiles.clear()
