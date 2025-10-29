"""Base adapter interface for music sources (torrents, streams, etc.)."""

from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import List

from karma_player.models.source import MusicSource, SourceType


class SourceAdapter(ABC):
    """
    Abstract base class for music source adapters.

    Supports multiple source types:
    - Torrent indexers (Jackett, 1337x, TPB, etc.)
    - Streaming sources (YouTube, Piped, JioSaavn, etc.)
    - Local file sources

    Features:
    - Circuit breaker pattern for fault tolerance
    - Health tracking with automatic cooldown
    - Pluggable architecture for easy extension
    """

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
        """Human-readable source name (e.g., 'Jackett', 'YouTube', '1337x')."""
        pass

    @property
    @abstractmethod
    def source_type(self) -> SourceType:
        """Type of sources this adapter provides."""
        pass

    @property
    def is_healthy(self) -> bool:
        """
        Check if adapter is healthy.

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
    async def search(self, query: str) -> List[MusicSource]:
        """
        Execute search and return normalized results.

        Args:
            query: Search query string (e.g., "Radiohead OK Computer FLAC")

        Returns:
            List of MusicSource objects

        Raises:
            Exception: On failure (handled by SearchEngine)
        """
        pass

    def _update_health(self, success: bool):
        """
        Update health status based on request outcome.

        Args:
            success: True if request succeeded, False otherwise
        """
        if success:
            self._consecutive_failures = 0
            self._last_success = datetime.now(timezone.utc).timestamp()
        else:
            self._consecutive_failures += 1
            self._last_failure = datetime.now(timezone.utc).timestamp()

    @property
    def health_status(self) -> dict:
        """
        Get current health status for diagnostics.

        Returns:
            Dictionary with health metrics
        """
        return {
            "name": self.name,
            "source_type": self.source_type.value,
            "is_healthy": self.is_healthy,
            "consecutive_failures": self._consecutive_failures,
            "last_success": datetime.fromtimestamp(self._last_success, tz=timezone.utc).isoformat()
            if self._last_success
            else None,
            "last_failure": datetime.fromtimestamp(self._last_failure, tz=timezone.utc).isoformat()
            if self._last_failure
            else None,
        }
