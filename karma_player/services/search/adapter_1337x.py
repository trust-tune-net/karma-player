"""1337x.to torrent indexer adapter."""

import asyncio
import re
from datetime import datetime, timezone
from typing import List
from urllib.parse import quote_plus

import aiohttp
from bs4 import BeautifulSoup

from karma_player.services.search.source_adapter import SourceAdapter
from karma_player.models.source import MusicSource, SourceType
from karma_player.services.search.metadata import MetadataExtractor


class Adapter1337x(SourceAdapter):
    """Adapter for 1337x.to torrent indexer."""

    BASE_URL = "https://1337x.to"
    SEARCH_URL = f"{BASE_URL}/search"
    TIMEOUT = 10  # seconds

    @property
    def name(self) -> str:
        """Return indexer name."""
        return "1337x"

    @property
    def source_type(self) -> SourceType:
        """Return source type."""
        return SourceType.TORRENT

    async def search(self, query: str) -> List[MusicSource]:
        """Search 1337x for torrents.

        Args:
            query: Search query

        Returns:
            List of MusicSource objects
        """
        try:
            headers = {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            }
            async with aiohttp.ClientSession(headers=headers) as session:
                # Search for torrents
                search_url = f"{self.SEARCH_URL}/{quote_plus(query)}/1/"

                async with asyncio.timeout(self.TIMEOUT):
                    async with session.get(search_url) as response:
                        if response.status != 200:
                            self._update_health(success=False)
                            return []

                        html = await response.text()

                # Parse search results
                soup = BeautifulSoup(html, "html.parser")
                table = soup.find("table", class_="table-list")

                if not table:
                    self._update_health(success=True)
                    return []

                rows = table.find("tbody").find_all("tr") if table.find("tbody") else []

                # Extract torrent details from rows
                detail_urls = []
                for row in rows[:20]:  # Top 20 results
                    try:
                        # Get detail page URL
                        link_cell = row.find("td", class_="coll-1")
                        if not link_cell:
                            continue

                        links = link_cell.find_all("a")
                        if len(links) < 2:
                            continue

                        detail_path = links[1].get("href")
                        if detail_path:
                            detail_urls.append(f"{self.BASE_URL}{detail_path}")
                    except (AttributeError, IndexError):
                        continue

                # Fetch detail pages in parallel to get magnet links
                results = []
                if detail_urls:
                    tasks = [
                        self._fetch_torrent_details(session, url, html)
                        for url in detail_urls
                    ]
                    results = await asyncio.gather(*tasks, return_exceptions=True)

                    # Filter out None and exceptions
                    results = [r for r in results if isinstance(r, MusicSource)]

                self._update_health(success=True)
                return results

        except asyncio.TimeoutError:
            self._update_health(success=False)
            return []
        except Exception as e:
            self._update_health(success=False)
            return []

    async def _fetch_torrent_details(
        self, session: aiohttp.ClientSession, detail_url: str, search_html: str
    ) -> MusicSource | None:
        """Fetch torrent details from detail page.

        Args:
            session: aiohttp session
            detail_url: URL of detail page
            search_html: HTML from search page (for extracting metadata)

        Returns:
            MusicSource or None if failed
        """
        try:
            async with asyncio.timeout(self.TIMEOUT):
                async with session.get(detail_url) as response:
                    if response.status != 200:
                        return None

                    html = await response.text()

            soup = BeautifulSoup(html, "html.parser")

            # Extract magnet link
            magnet_link = None
            magnet_tag = soup.find("a", href=re.compile(r"^magnet:\?"))
            if magnet_tag:
                magnet_link = magnet_tag.get("href")

            if not magnet_link:
                return None

            # Extract title
            title_tag = soup.find("h1")
            title = title_tag.text.strip() if title_tag else "Unknown"

            # Extract metadata from info list
            info_items = soup.find_all("li")
            seeders = 0
            leechers = 0
            size_bytes = 0
            uploaded_at = datetime.now(timezone.utc)

            for item in info_items:
                text = item.get_text(strip=True)

                # Seeders
                if "Seeders" in text:
                    try:
                        seeders = int(re.search(r"\d+", text).group())
                    except (AttributeError, ValueError):
                        pass

                # Leechers
                elif "Leechers" in text:
                    try:
                        leechers = int(re.search(r"\d+", text).group())
                    except (AttributeError, ValueError):
                        pass

                # Size
                elif "Total size" in text or "Size" in text:
                    size_match = re.search(r"([\d,\.]+\s*[KMGT]?B)", text, re.IGNORECASE)
                    if size_match:
                        size_bytes = MetadataExtractor.parse_size(size_match.group(1))

                # Date
                elif "Date uploaded" in text or "Uploaded" in text:
                    # Try to parse date (1337x uses various formats)
                    date_match = re.search(r"(\w+\.\s+\d+\w+\s+'\d+)", text)
                    if date_match:
                        try:
                            # Parse dates like "Jan. 1st '24"
                            date_str = date_match.group(1)
                            # Simplified: just use current time for now
                            uploaded_at = datetime.now(timezone.utc)
                        except:
                            pass

            # Extract format, bitrate, source from title
            extractor = MetadataExtractor()
            format_type = extractor.extract_format(title)
            bitrate = extractor.extract_bitrate(title)
            source = extractor.extract_source(title)

            # Generate infohash for ID
            import hashlib
            match = re.search(r"xt=urn:btih:([a-fA-F0-9]+)", magnet_link)
            if match:
                infohash = match.group(1).lower()
            else:
                infohash = hashlib.sha1(magnet_link.encode()).hexdigest()[:40].lower()

            return MusicSource(
                id=infohash,
                title=title,
                format=format_type,
                source_type=SourceType.TORRENT,
                url=magnet_link,
                indexer=self.name,
                seeders=seeders,
                leechers=leechers,
                size_bytes=size_bytes,
                uploaded_at=uploaded_at,
                bitrate=bitrate,
                magnet_link=magnet_link,  # Backward compatibility
            )

        except asyncio.TimeoutError:
            return None
        except Exception:
            return None
