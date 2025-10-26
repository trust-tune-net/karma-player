#!/usr/bin/env python3
"""
Debug Jackett adapter with verbose logging
"""
import asyncio
import os
import aiohttp
import xml.etree.ElementTree as ET


async def test_jackett_direct():
    """Test Jackett API directly with detailed logging"""

    jackett_url = os.getenv("JACKETT_REMOTE_URL", "https://trust-tune-trust-tune-jack.62ickh.easypanel.host")
    jackett_api_key = os.getenv("JACKETT_REMOTE_API_KEY", "ugokmbv2cfeghwcsm27mtnjva5ch7948")

    print("=" * 80)
    print("Testing Jackett adapter with verbose logging")
    print("=" * 80)
    print()

    print(f"URL: {jackett_url}")
    print(f"API Key: {jackett_api_key[:10]}...")
    print()

    # Build request
    url = f"{jackett_url}/api/v2.0/indexers/all/results/torznab/api"

    cat_param = "3000,3010,3020,3030,3040,3050"

    params = {
        "apikey": jackett_api_key,
        "t": "search",
        "q": "radiohead",
        "cat": cat_param,
    }

    headers = {
        "User-Agent": "karma-player/0.1.0"
    }

    print(f"Request URL: {url}")
    print(f"Params: {params}")
    print()

    try:
        timeout = aiohttp.ClientTimeout(total=30)
        connector = aiohttp.TCPConnector(ssl=False)  # Disable SSL verification
        async with aiohttp.ClientSession(headers=headers, timeout=timeout, connector=connector) as session:
            print("Sending request...")
            async with session.get(url, params=params) as response:
                print(f"Response status: {response.status}")
                print(f"Response headers: {dict(response.headers)}")
                print()

                if response.status != 200:
                    print(f"ERROR: Non-200 status code")
                    text = await response.text()
                    print(f"Response body: {text[:500]}")
                    return

                xml_text = await response.text()
                print(f"Response length: {len(xml_text)} bytes")
                print()

                # Parse XML
                print("Parsing XML...")
                root = ET.fromstring(xml_text)

                items = root.findall(".//item")
                print(f"Found {len(items)} items in XML")
                print()

                if items:
                    print("First item:")
                    item = items[0]
                    title = item.findtext("title", "Unknown")
                    print(f"  Title: {title}")

                    # Check for magnet
                    link = item.findtext("link", "")
                    print(f"  Link: {link[:80]}...")

                    # Torznab attrs
                    for attr in item.findall(".//{http://torznab.com/schemas/2015/feed}attr"):
                        name = attr.get("name")
                        value = attr.get("value")
                        if name in ["seeders", "peers", "magneturl"]:
                            print(f"  {name}: {value[:80] if value else 'N/A'}...")

    except aiohttp.ClientError as e:
        print(f"ERROR: aiohttp.ClientError - {e}")
    except asyncio.TimeoutError as e:
        print(f"ERROR: Timeout - {e}")
    except Exception as e:
        print(f"ERROR: {type(e).__name__} - {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(test_jackett_direct())
