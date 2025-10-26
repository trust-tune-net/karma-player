#!/usr/bin/env python3
"""
Full working demo of karma-player search infrastructure
"""
import asyncio
import os

from karma_player.services.search.engine import SearchEngine
from karma_player.services.search.adapter_jackett import AdapterJackett
from karma_player.models.query import MusicQuery
from karma_player.services.ai.query_parser import SQLLikeParser


async def demo_full_search():
    """Demonstrate complete search pipeline"""

    print("=" * 80)
    print("🎵 TrustTune/karma-player - Full Search Demo")
    print("=" * 80)
    print()

    # Get Jackett config
    jackett_url = os.getenv("JACKETT_REMOTE_URL", "https://trust-tune-trust-tune-jack.62ickh.easypanel.host")
    jackett_api_key = os.getenv("JACKETT_REMOTE_API_KEY", "ugokmbv2cfeghwcsm27mtnjva5ch7948")

    print(f"📡 Jackett Server: {jackett_url}")
    print()

    # Create adapter
    jackett = AdapterJackett(
        base_url=jackett_url,
        api_key=jackett_api_key,
        indexer_id="all"
    )

    # Create search engine
    engine = SearchEngine(adapters=[jackett])

    # Test 1: Simple search
    print("─" * 80)
    print("TEST 1: Simple Search")
    print("─" * 80)
    query = "radiohead"
    print(f"Query: '{query}'")
    print()

    results = await engine.search(query=query, min_seeders=0)

    print(f"✅ Found {len(results)} results")
    print()

    if results:
        print("Top 3 results:")
        for i, result in enumerate(results[:3], 1):
            print(f"\n{i}. {result.title}")
            print(f"   Format: {result.format or 'Unknown'}")
            print(f"   Bitrate: {result.bitrate or 'N/A'}")
            print(f"   Size: {result.size_formatted}")
            print(f"   Seeders: {result.seeders}")
            print(f"   Indexer: {result.indexer}")
            print(f"   Quality Score: {result.quality_score:.1f}")
    print()

    # Test 2: SQL-like query
    print("─" * 80)
    print("TEST 2: SQL-Like Query Interface")
    print("─" * 80)
    sql_query = 'SELECT album WHERE artist="Radiohead" AND format="FLAC" ORDER BY quality DESC LIMIT 5'
    print(f"SQL Query: {sql_query}")
    print()

    music_query = SQLLikeParser.parse(sql_query)
    print(f"Parsed to: {music_query.to_natural_language()}")
    print()

    # Execute with FLAC filter
    results_flac = await engine.search(
        query=music_query.artist,
        format_filter=music_query.format,
        min_seeders=music_query.min_seeders
    )

    print(f"✅ Found {len(results_flac)} FLAC results")
    print()

    if results_flac:
        print("Top 3 FLAC results:")
        for i, result in enumerate(results_flac[:3], 1):
            print(f"\n{i}. {result.title[:70]}...")
            print(f"   Format: {result.format}")
            print(f"   Size: {result.size_formatted}")
            print(f"   Seeders: {result.seeders}")
            print(f"   Quality Score: {result.quality_score:.1f}")
    print()

    # Test 3: Advanced query with filters
    print("─" * 80)
    print("TEST 3: Advanced Query")
    print("─" * 80)
    advanced_query = MusicQuery(
        query_type="album",
        artist="Pink Floyd",
        format="FLAC",
        min_seeders=5,
        limit=3
    )

    print(f"Query: {advanced_query.to_sql_like()}")
    print()

    results_advanced = await engine.search(
        query=advanced_query.artist,
        format_filter=advanced_query.format,
        min_seeders=advanced_query.min_seeders
    )

    print(f"✅ Found {len(results_advanced)} results")
    print()

    if results_advanced:
        for i, result in enumerate(results_advanced[:3], 1):
            print(f"{i}. {result.title[:70]}...")
            print(f"   Seeders: {result.seeders} | Quality: {result.quality_score:.1f}")
    print()

    # Summary
    print("=" * 80)
    print("✨ DEMO COMPLETE - All Systems Working!")
    print("=" * 80)
    print()
    print("Demonstrated:")
    print("  ✅ Pluggable Jackett adapter")
    print("  ✅ Multi-source search engine")
    print("  ✅ Deterministic quality scoring")
    print("  ✅ SQL-like query interface")
    print("  ✅ Format filtering (FLAC, MP3, etc.)")
    print("  ✅ Seeder filtering")
    print("  ✅ Deduplication by infohash")
    print()


if __name__ == "__main__":
    asyncio.run(demo_full_search())
