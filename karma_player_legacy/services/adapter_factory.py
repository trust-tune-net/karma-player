"""Factory for creating torrent indexer adapters from configuration."""

from typing import List

from karma_player.config import Config
from karma_player.indexer_config import IndexerConfigLoader
from karma_player.torrent.adapters.base import IndexerAdapter
from karma_player.torrent.adapters.adapter_jackett import AdapterJackett
from karma_player.torrent.adapters.adapter_1337x import Adapter1337x


class AdapterFactory:
    """Factory for creating indexer adapters."""

    def __init__(self, config: Config):
        """Initialize factory.

        Args:
            config: User configuration from database
        """
        self.config = config

    def create_adapters(self, profile_name: str = None) -> List[IndexerAdapter]:
        """Create adapters from YAML profile or fallback to database config.

        Args:
            profile_name: Optional profile name from YAML config

        Returns:
            List of configured adapters
        """
        adapters = []

        try:
            # Try to load from YAML configuration
            loader = IndexerConfigLoader()

            # Build context for variable substitution
            import os
            context = {}
            if self.config.jackett_api_key:
                context['JACKETT_API_KEY'] = self.config.jackett_api_key

            # Add environment variables for remote Jackett
            if os.environ.get('JACKETT_REMOTE_URL'):
                context['JACKETT_REMOTE_URL'] = os.environ['JACKETT_REMOTE_URL']
            if os.environ.get('JACKETT_REMOTE_API_KEY'):
                context['JACKETT_REMOTE_API_KEY'] = os.environ['JACKETT_REMOTE_API_KEY']

            # Get profile configuration
            profile_config = loader.get_profile(profile_name=profile_name, context=context)

            # Build adapters from profile
            for idx_config in profile_config.indexers:
                if not idx_config.enabled:
                    continue

                if idx_config.type == 'jackett':
                    adapter = AdapterJackett(
                        base_url=idx_config.base_url,
                        api_key=idx_config.api_key,
                        indexer_id=idx_config.indexer_id,
                        categories=idx_config.categories,
                    )
                    adapter.timeout = idx_config.timeout
                    adapters.append(adapter)
                elif idx_config.type == '1337x':
                    adapters.append(Adapter1337x())

            # If no adapters enabled in profile, fall back to database
            if not adapters:
                adapters = self._create_from_database()

        except (FileNotFoundError, ValueError):
            # YAML config not found or invalid - use database config
            adapters = self._create_from_database()

        return adapters

    def _create_from_database(self) -> List[IndexerAdapter]:
        """Create adapters from database configuration (fallback).

        Returns:
            List of adapters from database config
        """
        adapters = []

        # Add Jackett if configured
        if self.config.jackett_url and self.config.jackett_api_key:
            adapters.append(
                AdapterJackett(
                    base_url=self.config.jackett_url,
                    api_key=self.config.jackett_api_key,
                    indexer_id="all",
                )
            )

        # Always add 1337x as fallback
        adapters.append(Adapter1337x())

        return adapters
