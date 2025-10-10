"""Base adapter interface for torrent indexers."""

from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import List

from karma_player.torrent.models import TorrentResult


class IndexerAdapter(ABC):
    """Abstract base class for torrent indexer adapters."""

    def __init__(self):
        """Initialize adapter with health tracking."""
        self._consecutive_failures = 0
        self._last_success = datetime.now(timezone.utc).timestamp()
        self._last_failure = 0.0
        self._circuit_breaker_threshold = 3
        self._cooldown_seconds = 300  # 5 minutes

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable indexer name."""
        pass

    @property
    def is_healthy(self) -> bool:
        """Check if adapter is healthy.

        Returns False if:
        - 3+ consecutive failures (circuit breaker open)
        - Still within cooldown period after failures

        Returns:
            True if healthy, False otherwise
        """
        # Circuit breaker open
        if self._consecutive_failures >= self._circuit_breaker_threshold:
            # Check if cooldown expired
            time_since_failure = datetime.now(timezone.utc).timestamp() - self._last_failure
            if time_since_failure < self._cooldown_seconds:
                return False
            # Cooldown expired, reset and allow retry
            self._consecutive_failures = 0
            return True

        return True

    @abstractmethod
    async def search(self, query: str) -> List[TorrentResult]:
        """Execute search and return normalized results.

        Args:
            query: Search query string

        Returns:
            List of TorrentResult objects

        Raises:
            Exception: On failure (handled by SearchEngine)
        """
        pass

    def _update_health(self, success: bool):
        """Update health status based on request outcome.

        Args:
            success: True if request succeeded, False otherwise
        """
        if success:
            self._consecutive_failures = 0
            self._last_success = datetime.now(timezone.utc).timestamp()
        else:
            self._consecutive_failures += 1
            self._last_failure = datetime.now(timezone.utc).timestamp()
