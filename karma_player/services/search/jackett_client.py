"""
Jackett API client utilities.

Handles communication with Jackett Torznab API for indexer discovery
and configuration queries.
"""

import logging
import xml.etree.ElementTree as ET
from typing import Dict, List, Optional

import aiohttp

logger = logging.getLogger(__name__)


class JackettClient:
    """
    Client for interacting with Jackett Torznab API.

    Provides methods to discover configured indexers and parse XML responses.
    """

    def __init__(self, base_url: str, api_key: str):
        """
        Initialize Jackett client.

        Args:
            base_url: Base URL of Jackett instance (e.g., "https://jackett.example.com")
            api_key: Jackett API key for authentication
        """
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key

    async def list_indexers(self, timeout: float = 10.0) -> List[Dict[str, str]]:
        """
        Fetch list of configured indexers from Jackett.

        Uses the Torznab API endpoint: /api/v2.0/indexers/all/results/torznab/api?t=indexers

        Args:
            timeout: Request timeout in seconds

        Returns:
            List of indexer dictionaries with keys: id, name, configured

        Raises:
            aiohttp.ClientError: On network or HTTP errors
            ET.ParseError: On XML parsing errors
        """
        url = f"{self.base_url}/api/v2.0/indexers/all/results/torznab/api"
        params = {
            "apikey": self.api_key,
            "t": "indexers",
            "configured": "true"
        }

        logger.debug(f"🔍 Fetching indexers from Jackett: {url}")

        async with aiohttp.ClientSession() as session:
            async with session.get(
                url,
                params=params,
                timeout=aiohttp.ClientTimeout(total=timeout)
            ) as response:
                response.raise_for_status()

                xml_text = await response.text()
                logger.debug(f"📄 Received XML response ({len(xml_text)} bytes)")

                indexers = self._parse_indexers_xml(xml_text)
                logger.info(f"✅ Discovered {len(indexers)} configured indexers")

                return indexers

    def _parse_indexers_xml(self, xml_text: str) -> List[Dict[str, str]]:
        """
        Parse Jackett indexers XML response.

        Expected format:
        <indexers>
            <indexer id="..." configured="true">
                <title>Indexer Name</title>
                ...
            </indexer>
            ...
        </indexers>

        Args:
            xml_text: XML response string

        Returns:
            List of indexer dictionaries
        """
        try:
            root = ET.fromstring(xml_text)
        except ET.ParseError as e:
            logger.error(f"❌ Failed to parse indexers XML: {e}")
            logger.debug(f"XML content: {xml_text[:500]}...")
            raise

        indexers = []

        for indexer_elem in root.findall("indexer"):
            indexer_id = indexer_elem.get("id")
            configured = indexer_elem.get("configured", "false").lower() == "true"

            # Only include configured indexers
            if not configured:
                continue

            # Extract title
            title_elem = indexer_elem.find("title")
            name = title_elem.text if title_elem is not None else indexer_id

            if indexer_id:
                indexers.append({
                    "id": indexer_id,
                    "name": name,
                    "configured": "true"
                })
                logger.debug(f"  → {name} ({indexer_id})")

        return indexers

    async def test_indexer(
        self,
        indexer_id: str,
        query: str,
        timeout: float = 5.0
    ) -> tuple[bool, Optional[float], Optional[str]]:
        """
        Test an indexer with a search query.

        Args:
            indexer_id: Jackett indexer ID to test
            query: Search query (e.g., "radiohead")
            timeout: Request timeout in seconds

        Returns:
            Tuple of (success, response_time, error_message)
            - success: True if indexer responded
            - response_time: Time in seconds (None if failed)
            - error_message: Error description (None if success)
        """
        url = f"{self.base_url}/api/v2.0/indexers/{indexer_id}/results/torznab/api"
        params = {
            "apikey": self.api_key,
            "t": "search",
            "q": query,
            "cat": "3000,3010,3020,3030,3040,3050"  # Music categories
        }

        import time
        start_time = time.time()

        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    url,
                    params=params,
                    timeout=aiohttp.ClientTimeout(total=timeout)
                ) as response:
                    response_time = time.time() - start_time

                    # Check for HTTP errors
                    if response.status >= 400:
                        error_msg = f"HTTP {response.status}"
                        logger.warning(f"❌ {indexer_id}: {error_msg} ({response_time:.2f}s)")
                        return False, response_time, error_msg

                    # Read response to ensure it's valid
                    _ = await response.text()

                    logger.debug(f"✅ {indexer_id}: Success ({response_time:.2f}s)")
                    return True, response_time, None

        except asyncio.TimeoutError:
            response_time = time.time() - start_time
            logger.warning(f"⏱️  {indexer_id}: Timeout after {response_time:.2f}s")
            return False, response_time, "timeout"

        except aiohttp.ClientError as e:
            response_time = time.time() - start_time
            error_msg = str(e)
            logger.warning(f"❌ {indexer_id}: {error_msg} ({response_time:.2f}s)")
            return False, response_time, error_msg

        except Exception as e:
            response_time = time.time() - start_time
            error_msg = f"Unexpected error: {e}"
            logger.error(f"❌ {indexer_id}: {error_msg} ({response_time:.2f}s)")
            return False, response_time, error_msg

    def build_search_url(self, indexer_id: str, query: str) -> str:
        """
        Build a Jackett search URL for an indexer.

        Args:
            indexer_id: Jackett indexer ID (or "all" for all indexers)
            query: Search query

        Returns:
            Full Jackett search URL
        """
        url = f"{self.base_url}/api/v2.0/indexers/{indexer_id}/results/torznab/api"
        return url


# Add missing import
import asyncio
