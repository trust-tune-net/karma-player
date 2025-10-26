#!/usr/bin/env python3
"""
End-to-end search flow test
Demonstrates: Query → AI Parse → MusicBrainz → Torrent Search → Ranked Results
"""
import asyncio
import os

from karma_player.services.search_orchestrator import SearchOrchestrator, SearchProgress
from karma_player.services.search.engine import SearchEngine
from karma_player.services.search.adapter_jackett import AdapterJackett
from karma_player.services.musicbrainz_service import MusicBrainzService


async def test_end_to_end():
    """Test complete search flow"""

    print("=" * 90)
    print("🎵 TrustTune - End-to-End Search Flow Test")
    print("=" * 90)
    print()

    # Setup
    print("🔧 Setting up search infrastructure...")
    print()

    # Jackett adapter
    jackett = AdapterJackett(
        base_url=os.getenv("JACKETT_REMOTE_URL", "https://trust-tune-trust-tune-jack.62ickh.easypanel.host"),
        api_key=os.getenv("JACKETT_REMOTE_API_KEY", "ugokmbv2cfeghwcsm27mtnjva5ch7948"),
        indexer_id="all"
    )

    # Search engine
    search_engine = SearchEngine(adapters=[jackett])

    # MusicBrainz
    musicbrainz = MusicBrainzService(
        app_name="karma-player",
        app_version="0.1.0"
    )

    # Orchestrator (will auto-detect AI if available)
    orchestrator = SearchOrchestrator(
        search_engine=search_engine,
        musicbrainz=musicbrainz
    )

    # Progress callback
    def show_progress(progress: SearchProgress):
        bar_length = 30
        filled = int(bar_length * progress.progress_percent / 100)
        bar = "█" * filled + "░" * (bar_length - filled)
        print(f"\r[{bar}] {progress.progress_percent}% - {progress.message}", end="", flush=True)

    # Test queries
    test_queries = [
        "radiohead ok computer",
        "pink floyd dark side of the moon",
        "miles davis kind of blue"
    ]

    for i, query in enumerate(test_queries, 1):
        print(f"\n{'─' * 90}")
        print(f"Test {i}: '{query}'")
        print('─' * 90)
        print()

        # Execute search
        result = await orchestrator.search(
            query=query,
            progress_callback=show_progress
        )

        print()  # New line after progress bar
        print()

        # Show results
        print(f"✅ Search completed in {result.search_time_ms}ms")
        print()

        if result.parsed_query:
            print(f"📝 Parsed query:")
            print(f"   Artist: {result.parsed_query.artist}")
            print(f"   Album: {result.parsed_query.album}")
            print(f"   Type: {result.parsed_query.query_type}")
            print(f"   Confidence: {result.parsed_query.confidence:.0%}")
            print()

        if result.musicbrainz_match:
            print(f"🎼 MusicBrainz match:")
            print(f"   {result.musicbrainz_match}")
            print()

        print(f"💿 Found {result.total_found} torrents")
        print()

        if result.results:
            print("Top 3 results:")
            print()
            for ranked in result.results[:3]:
                torrent = ranked.torrent
                print(f"{ranked.rank}. {torrent.title[:75]}")
                print(f"   {ranked.explanation}")
                if ranked.tags:
                    print(f"   Tags: {', '.join(ranked.tags)}")
                print(f"   Infohash: {torrent.infohash[:16]}...")
                print()

    # Final summary
    print("=" * 90)
    print("✨ END-TO-END FLOW COMPLETE!")
    print("=" * 90)
    print()
    print("Demonstrated:")
    print("  ✅ Query parsing (with AI fallback)")
    print("  ✅ MusicBrainz canonical metadata")
    print("  ✅ Multi-source torrent search")
    print("  ✅ Quality-based ranking")
    print("  ✅ AI-generated explanations")
    print("  ✅ Progress tracking")
    print()


if __name__ == "__main__":
    asyncio.run(test_end_to_end())
