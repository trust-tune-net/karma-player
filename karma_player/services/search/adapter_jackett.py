"""Jackett torrent indexer adapter."""

import asyncio
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from typing import List, Optional
from urllib.parse import quote_plus

import aiohttp

from karma_player.services.search.source_adapter import SourceAdapter
from karma_player.models.source import MusicSource, SourceType
from karma_player.services.search.metadata import MetadataExtractor
from karma_player import __version__


class AdapterJackett(SourceAdapter):
    """Adapter for Jackett proxy (supports 100+ indexers)."""

    # Torznab audio categories (search ALL audio formats)
    DEFAULT_AUDIO_CATEGORIES = [
        3000,  # Audio (general)
        3010,  # Audio/MP3
        3020,  # Audio/Video
        3030,  # Audio/Audiobook
        3040,  # Audio/Lossless (FLAC, ALAC, APE, etc.)
        3050,  # Audio/Other
    ]

    def __init__(
        self,
        base_url: str = "http://localhost:9117",
        api_key: str = "",
        indexer_id: str = "all",
        categories: list[int] | None = None,
    ):
        """Initialize Jackett adapter.

        Args:
            base_url: Jackett base URL (default: http://localhost:9117)
            api_key: Jackett API key (required)
            indexer_id: Indexer ID or 'all' for all configured indexers
            categories: Torznab category IDs (default: all audio categories)
        """
        super().__init__()
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.indexer_id = indexer_id
        self.categories = categories if categories is not None else self.DEFAULT_AUDIO_CATEGORIES
        self.timeout = 15  # Jackett queries multiple indexers

    @property
    def name(self) -> str:
        """Return indexer name."""
        return f"Jackett ({self.indexer_id})"

    @property
    def source_type(self) -> SourceType:
        """Return source type."""
        return SourceType.TORRENT

    async def search(self, query: str) -> List[MusicSource]:
        """Search via Jackett Torznab API.

        Args:
            query: Search query

        Returns:
            List of MusicSource objects
        """
        if not self.api_key:
            # No API key configured, return empty
            return []

        # Retry logic for remote/sleeping instances (Easypanel cold starts)
        max_retries = 2 if "localhost" not in self.base_url else 1
        retry_delay = 3  # seconds

        for attempt in range(max_retries):
            try:
                # Torznab API endpoint
                url = f"{self.base_url}/api/v2.0/indexers/{self.indexer_id}/results/torznab/api"

                # Build category parameter (comma-separated)
                cat_param = ",".join(str(c) for c in self.categories)

                params = {
                    "apikey": self.api_key,
                    "t": "search",  # Generic search (was "music" - too restrictive)
                    "q": query,
                    "cat": cat_param,  # Include ALL audio categories
                }

                headers = {
                    "User-Agent": f"karma-player/{__version__}"
                }

                timeout = aiohttp.ClientTimeout(total=self.timeout)
                async with aiohttp.ClientSession(headers=headers, timeout=timeout) as session:
                    async with session.get(url, params=params) as response:
                        if response.status != 200:
                            if attempt < max_retries - 1:
                                # Wait and retry (might be cold start)
                                await asyncio.sleep(retry_delay)
                                continue
                            self._update_health(success=False)
                            return []

                        xml_text = await response.text()

                # Parse Torznab XML response
                results = self._parse_torznab_xml(xml_text)
                self._update_health(success=True)
                return results

            except (aiohttp.ClientError, asyncio.TimeoutError) as e:
                if attempt < max_retries - 1:
                    # Timeout or connection error - might be cold start, retry
                    await asyncio.sleep(retry_delay)
                    continue
                # Final attempt failed
                self._update_health(success=False)
                return []
            except Exception as e:
                if attempt < max_retries - 1:
                    await asyncio.sleep(retry_delay)
                    continue
                self._update_health(success=False)
                return []

        # If we exit the loop without returning, something went wrong
        self._update_health(success=False)
        return []

    def _parse_torznab_xml(self, xml_text: str) -> List[MusicSource]:
        """Parse Torznab XML response.

        Args:
            xml_text: XML response from Jackett

        Returns:
            List of MusicSource objects
        """
        results = []

        try:
            root = ET.fromstring(xml_text)

            # Torznab uses RSS 2.0 format with custom namespace
            for item in root.findall(".//item"):
                try:
                    # Extract basic fields
                    title = item.findtext("title", "Unknown")
                    link = item.findtext("link", "")

                    # Extract torznab attributes
                    attrs = {}
                    for attr in item.findall(".//{http://torznab.com/schemas/2015/feed}attr"):
                        name = attr.get("name")
                        value = attr.get("value")
                        if name and value:
                            attrs[name] = value

                    # Get magnet link (prefer magneturl over link)
                    magnet_link = attrs.get("magneturl", "")
                    if not magnet_link and link.startswith("magnet:"):
                        magnet_link = link

                    # ONLY accept real magnet URIs (skip Jackett proxy URLs)
                    # Jackett proxy URLs (base_url/dl/) can't be used with libtorrent
                    if not magnet_link or not magnet_link.startswith("magnet:"):
                        continue  # Skip if no valid magnet link

                    # Parse attributes
                    seeders = int(attrs.get("seeders", "0"))
                    leechers = int(attrs.get("peers", "0"))  # peers = leechers in Torznab

                    # Size can be in <size> tag or torznab:attr
                    size_bytes = int(item.findtext("size", "0"))
                    if size_bytes == 0:
                        size_bytes = int(attrs.get("size", "0"))

                    # Parse upload date
                    pub_date = item.findtext("pubDate", "")
                    uploaded_at = self._parse_rfc822_date(pub_date)

                    # Extract indexer name from <jackettindexer> tag
                    indexer_tag = item.find("jackettindexer")
                    if indexer_tag is not None and indexer_tag.text:
                        indexer = indexer_tag.text
                    else:
                        indexer = attrs.get("indexer", "Jackett")

                    # Extract metadata from title
                    extractor = MetadataExtractor()
                    format_type = extractor.extract_format(title)
                    bitrate = extractor.extract_bitrate(title)
                    source = extractor.extract_source(title)

                    # If format not found in title, infer from Torznab category
                    if not format_type:
                        # Use <category> tag (Torznab standard), NOT torznab:attr category
                        category = item.findtext("category", "")
                        if category:
                            try:
                                category_int = int(category)
                            except ValueError:
                                category_int = 0
                        else:
                            category_int = 0

                        if category_int:
                            if category_int == 3040:  # Audio/Lossless
                                format_type = "FLAC"
                            elif category_int == 3010:  # Audio/MP3
                                format_type = "MP3"
                            elif category_int == 3030:  # Audio/Audiobook
                                format_type = "AAC"  # Common audiobook format
                            elif category_int in [3000, 3050]:  # Audio (general/other)
                                # Check title for hints
                                title_lower = title.lower()
                                if "flac" in title_lower or "24bit" in title_lower or "24-bit" in title_lower:
                                    format_type = "FLAC"
                                elif "mp3" in title_lower or "320kbps" in title_lower or "320k" in title_lower or "cbr" in title_lower:
                                    format_type = "MP3"
                                elif "aac" in title_lower:
                                    format_type = "AAC"

                    # Generate infohash for ID
                    import re
                    import hashlib
                    match = re.search(r"xt=urn:btih:([a-fA-F0-9]+)", magnet_link)
                    if match:
                        infohash = match.group(1).lower()
                    else:
                        infohash = hashlib.sha1(magnet_link.encode()).hexdigest()[:40].lower()

                    results.append(
                        MusicSource(
                            id=infohash,
                            title=title,
                            format=format_type,
                            source_type=SourceType.TORRENT,
                            url=magnet_link,
                            indexer=indexer,
                            seeders=seeders,
                            leechers=leechers,
                            size_bytes=size_bytes,
                            uploaded_at=uploaded_at,
                            bitrate=bitrate,
                            magnet_link=magnet_link,  # Backward compatibility
                        )
                    )

                except (ValueError, AttributeError):
                    continue  # Skip malformed items

        except ET.ParseError:
            pass  # Invalid XML

        return results

    def _parse_rfc822_date(self, date_str: str) -> datetime:
        """Parse RFC 822 date format used in RSS.

        Args:
            date_str: Date string (e.g., 'Mon, 01 Jan 2024 12:00:00 +0000')

        Returns:
            datetime object (UTC)
        """
        try:
            from email.utils import parsedate_to_datetime
            return parsedate_to_datetime(date_str)
        except:
            return datetime.now(timezone.utc)
