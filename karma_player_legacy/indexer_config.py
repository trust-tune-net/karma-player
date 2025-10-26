"""Indexer configuration loader from YAML."""

import os
from pathlib import Path
from typing import Dict, List, Optional, Any

import yaml
from pydantic import BaseModel, Field


class IndexerConfig(BaseModel):
    """Configuration for a single indexer."""

    name: str
    type: str  # jackett, 1337x, etc.
    enabled: bool = True
    base_url: Optional[str] = None
    api_key: Optional[str] = None
    indexer_id: Optional[str] = "all"
    categories: List[int] = Field(default_factory=lambda: [3000, 3010, 3040, 3050])
    timeout: int = 15


class ProfileConfig(BaseModel):
    """Configuration for an indexer profile."""

    description: str
    indexers: List[IndexerConfig]


class IndexerConfigLoader:
    """Load and manage indexer configurations from YAML."""

    def __init__(self, config_path: Optional[Path] = None):
        """Initialize config loader.

        Args:
            config_path: Path to indexers.yaml file. If None, uses default location.
        """
        if config_path is None:
            # Try multiple locations
            locations = [
                Path.home() / ".karma-player" / "indexers.yaml",  # User config
                Path(__file__).parent / "indexers.yaml",  # Package default
            ]
            for loc in locations:
                if loc.exists():
                    config_path = loc
                    break
            else:
                # Use package default (will create user config on first save)
                config_path = Path(__file__).parent / "indexers.yaml"

        self.config_path = config_path
        self._config: Dict[str, Any] = {}
        self._load()

    def _load(self):
        """Load YAML configuration."""
        if not self.config_path.exists():
            raise FileNotFoundError(
                f"Indexer config not found: {self.config_path}\n"
                f"Run 'karma-player init' to create default configuration."
            )

        with open(self.config_path) as f:
            self._config = yaml.safe_load(f)

    def _resolve_variables(self, value: str, context: Dict[str, str]) -> str:
        """Resolve ${VAR} variables in strings.

        Args:
            value: String potentially containing ${VAR} placeholders
            context: Dictionary of variable values

        Returns:
            Resolved string
        """
        if not isinstance(value, str):
            return value

        # Replace ${VAR} with context values
        import re

        def replace_var(match):
            var_name = match.group(1)
            return context.get(var_name, match.group(0))  # Keep ${VAR} if not found

        return re.sub(r"\$\{(\w+)\}", replace_var, value)

    def get_profile(
        self, profile_name: Optional[str] = None, context: Optional[Dict[str, str]] = None
    ) -> ProfileConfig:
        """Get indexer configuration for a profile.

        Args:
            profile_name: Profile name (default: from config file)
            context: Variable context for ${VAR} substitution

        Returns:
            ProfileConfig object
        """
        if context is None:
            context = {}

        if profile_name is None:
            profile_name = self._config.get("default_profile", "local")

        profiles = self._config.get("profiles", {})
        if profile_name not in profiles:
            raise ValueError(
                f"Profile '{profile_name}' not found. "
                f"Available: {', '.join(profiles.keys())}"
            )

        profile_data = profiles[profile_name]

        # Resolve variables in indexer configs
        indexers = []
        for idx_data in profile_data.get("indexers", []):
            # Resolve api_key variable
            if "api_key" in idx_data:
                idx_data["api_key"] = self._resolve_variables(idx_data["api_key"], context)

            # Resolve base_url variable
            if "base_url" in idx_data:
                idx_data["base_url"] = self._resolve_variables(idx_data["base_url"], context)

            indexers.append(IndexerConfig(**idx_data))

        return ProfileConfig(
            description=profile_data.get("description", profile_name), indexers=indexers
        )

    def list_profiles(self) -> List[str]:
        """List available profile names."""
        return list(self._config.get("profiles", {}).keys())

    def get_search_settings(self) -> Dict[str, Any]:
        """Get global search settings."""
        return self._config.get("search", {})

    def get_default_profile(self) -> str:
        """Get default profile name."""
        return self._config.get("default_profile", "local")

    def copy_to_user_config(self):
        """Copy package default config to user config directory."""
        user_config = Path.home() / ".karma-player" / "indexers.yaml"
        user_config.parent.mkdir(parents=True, exist_ok=True)

        if user_config.exists():
            # Backup existing
            import shutil
            from datetime import datetime

            backup = user_config.with_suffix(
                f".yaml.backup-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
            )
            shutil.copy(user_config, backup)

        # Copy default config
        import shutil

        shutil.copy(self.config_path, user_config)
        self.config_path = user_config
        self._load()

        return user_config
