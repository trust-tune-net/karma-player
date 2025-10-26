#!/usr/bin/env python3
"""
Debug test for Jackett adapter
"""
import asyncio
import os
import aiohttp


async def test_jackett_direct():
    """Test direct Jackett API call"""

    jackett_url = os.getenv("JACKETT_REMOTE_URL")
    jackett_api_key = os.getenv("JACKETT_REMOTE_API_KEY")

    if not jackett_url or not jackett_api_key:
        print("❌ Missing environment variables")
        return

    # Direct API call
    url = f"{jackett_url}/api/v2.0/indexers/all/results/torznab/api"
    params = {
        "apikey": jackett_api_key,
        "t": "search",
        "q": "radiohead",
        "cat": "3000,3010,3020,3030,3040,3050",
    }

    print(f"🔍 Testing direct Jackett API call")
    print(f"   URL: {url}")
    print(f"   Query: radiohead")
    print()

    try:
        timeout = aiohttp.ClientTimeout(total=30)  # Longer timeout for cold start
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.get(url, params=params) as response:
                print(f"📡 Response status: {response.status}")
                print(f"📡 Content-Type: {response.headers.get('Content-Type')}")
                print()

                if response.status != 200:
                    text = await response.text()
                    print(f"❌ Error response:")
                    print(text[:500])
                    return

                xml_text = await response.text()
                print(f"✅ Response length: {len(xml_text)} bytes")
                print()
                print("First 500 characters:")
                print(xml_text[:500])
                print()

                # Count items
                import xml.etree.ElementTree as ET
                root = ET.fromstring(xml_text)
                items = root.findall(".//item")
                print(f"✅ Found {len(items)} items in XML response")

    except Exception as e:
        print(f"❌ Exception: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(test_jackett_direct())
