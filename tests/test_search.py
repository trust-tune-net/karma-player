#!/usr/bin/env python3
"""
Test script for torrent search functionality
"""
import asyncio
import os

from karma_player.services.search.engine import SearchEngine
from karma_player.services.search.adapter_jackett import AdapterJackett


async def test_search():
    """Test basic search with Jackett"""

    # Get Jackett config from environment
    jackett_url = os.getenv("JACKETT_REMOTE_URL")
    jackett_api_key = os.getenv("JACKETT_REMOTE_API_KEY")

    if not jackett_url or not jackett_api_key:
        print("❌ Missing JACKETT_REMOTE_URL or JACKETT_REMOTE_API_KEY environment variables")
        print("\nSet them with:")
        print("export JACKETT_REMOTE_URL='https://your-jackett-instance'")
        print("export JACKETT_REMOTE_API_KEY='your-api-key'")
        return

    print(f"🔍 Testing search with Jackett")
    print(f"   URL: {jackett_url}")
    print()

    # Create Jackett adapter
    jackett = AdapterJackett(
        base_url=jackett_url,
        api_key=jackett_api_key,
        indexer_id="all"  # Search all configured indexers
    )

    # Create search engine
    engine = SearchEngine(adapters=[jackett])

    # Test search
    query = "radiohead"
    print(f"🎵 Searching for: {query}")
    print("⏳ Waiting for response (remote server may need to wake up)...")
    print()

    results = await engine.search(
        query=query,
        min_seeders=0  # No seeder filter for testing
    )

    if not results:
        print("❌ No results found")
        print()
        print("This could mean:")
        print("  - Remote Jackett instance is sleeping (cold start)")
        print("  - No indexers configured in Jackett")
        print("  - Network/connectivity issue")
        return

    print(f"✅ Found {len(results)} results\n")

    # Show top 5 results
    for i, result in enumerate(results[:5], 1):
        print(f"{i}. {result.title}")
        print(f"   Indexer: {result.indexer}")
        print(f"   Format: {result.format or 'Unknown'}")
        print(f"   Bitrate: {result.bitrate or 'N/A'}")
        print(f"   Size: {result.size_formatted}")
        print(f"   Seeders: {result.seeders}")
        print(f"   Quality Score: {result.quality_score:.1f}")
        print()


if __name__ == "__main__":
    asyncio.run(test_search())
