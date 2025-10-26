#!/usr/bin/env python3
"""
Debug script to trace search flow
"""
import asyncio
import os

from karma_player.services.simple_search import SimpleSearch
from karma_player.services.search.engine import SearchEngine
from karma_player.services.search.adapter_jackett import AdapterJackett


async def debug_search():
    print("=" * 80)
    print("DEBUG: Tracing search flow")
    print("=" * 80)
    print()

    # Setup
    jackett_url = os.getenv("JACKETT_REMOTE_URL", "https://trust-tune-trust-tune-jack.62ickh.easypanel.host")
    jackett_api_key = os.getenv("JACKETT_REMOTE_API_KEY", "ugokmbv2cfeghwcsm27mtnjva5ch7948")

    print(f"Jackett URL: {jackett_url}")
    print(f"Jackett API Key: {jackett_api_key[:10]}...")
    print()

    # Create adapter
    jackett = AdapterJackett(
        base_url=jackett_url,
        api_key=jackett_api_key,
        indexer_id="all"
    )

    print(f"Adapter created: {jackett.name}")
    print(f"Adapter healthy: {jackett.is_healthy}")
    print()

    # Test direct adapter search
    print("Testing direct Jackett adapter search...")
    direct_results = await jackett.search("radiohead")
    print(f"Direct adapter results: {len(direct_results)}")
    if direct_results:
        print(f"First result: {direct_results[0].title}")
    print()

    # Create search engine
    engine = SearchEngine(adapters=[jackett])
    print(f"Search engine created with {len(engine.adapters)} adapters")
    print()

    # Test engine search
    print("Testing SearchEngine search...")
    engine_results = await engine.search(
        query="radiohead",
        min_seeders=1
    )
    print(f"Engine results: {len(engine_results)}")
    if engine_results:
        print(f"First result: {engine_results[0].title}")
    print()

    # Test SimpleSearch
    print("Testing SimpleSearch...")
    search = SimpleSearch(engine)
    result = await search.search(
        query="radiohead",
        min_seeders=1,
        limit=5
    )
    print(f"SimpleSearch results: {result.total_found}")
    print(f"SQL query: {result.sql_query}")
    if result.results:
        print(f"First result: {result.results[0].torrent.title}")
    print()


if __name__ == "__main__":
    asyncio.run(debug_search())
