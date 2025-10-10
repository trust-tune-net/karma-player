#!/usr/bin/env python3
"""
Debug script to verify pre-filter vs actual search behavior.

This script reproduces the issue where pre-filter shows N torrents available
but actual search returns different results due to:
1. Different queries (album vs song)
2. Different filters (min_seeders, format)
3. Deduplication differences

Usage:
    poetry run python tests/debug_prefilter_vs_search.py

Test Case:
    Artist: Iron Maiden
    Song: Fear of the Dark
    Album: The Book of Souls: Live Chapter

Expected behavior:
    Pre-filter should accurately predict how many torrents will be found
    in the actual search, using the same parameters.
"""

import asyncio
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from karma_player.config import ConfigManager
from karma_player.services.adapter_factory import AdapterFactory
from karma_player.services.torrent_service import TorrentSearchService


async def debug_prefilter_vs_search():
    """Compare pre-filter behavior vs actual search."""

    # Setup
    config_manager = ConfigManager()
    config = config_manager.load_config()  # Load configuration from database
    adapter_factory = AdapterFactory(config)
    adapters = adapter_factory.create_adapters(profile_name="remote")
    torrent_service = TorrentSearchService(adapters)

    # Test data (from real Iron Maiden issue)
    artist = "Iron Maiden"
    song = "Fear of the Dark"
    album = "The Book of Souls: Live Chapter"

    print("=" * 80)
    print("DEBUG: Pre-filter vs Actual Search Comparison")
    print("=" * 80)
    print(f"\nTest Case:")
    print(f"  Artist: {artist}")
    print(f"  Song: {song}")
    print(f"  Album: {album}")
    print(f"  User params: min_seeders=1, format=*, strict=False")

    # ===== PRE-FILTER CHECK (how it currently works) =====
    print(f"\n{'─' * 80}")
    print("1. PRE-FILTER CHECK (availability check)")
    print(f"{'─' * 80}")

    query_prefilter = f"{artist} {album}"
    print(f"\nQuery: '{query_prefilter}'")
    print(f"Filters: format_filter=None, min_seeders=0")

    try:
        torrents_prefilter = await torrent_service.search(
            query=query_prefilter,
            format_filter=None,
            min_seeders=0
        )
        print(f"\n✓ Found {len(torrents_prefilter)} torrent(s)")

        if torrents_prefilter:
            print(f"\nSample torrents:")
            for i, t in enumerate(torrents_prefilter[:5], 1):
                print(f"  [{i}] {t.title[:80]}")
                print(f"      Seeders: {t.seeders}, Format: {t.format}, Size: {t.size_formatted}")

            # Analyze what would be filtered out
            with_seeders = [t for t in torrents_prefilter if t.seeders >= 1]
            print(f"\n  → {len(with_seeders)} would pass min_seeders=1 filter")

    except Exception as e:
        print(f"✗ Error: {e}")
        torrents_prefilter = []

    # ===== AUTO-MODE STRATEGY 1: Single Track Search =====
    print(f"\n{'─' * 80}")
    print("2. AUTO-MODE STRATEGY 1: Single Track Search")
    print(f"{'─' * 80}")

    query_single = f"{artist} {song}"
    print(f"\nQuery: '{query_single}'")
    print(f"Filters: format_filter=*, min_seeders=1")

    try:
        torrents_single = await torrent_service.search(
            query=query_single,
            format_filter="*",
            min_seeders=1
        )
        print(f"\n✓ Found {len(torrents_single)} torrent(s)")

        if torrents_single:
            # Filter for song-only (< 100MB) as auto-mode does
            song_only = [t for t in torrents_single if (t.size_bytes or 0) / (1024 * 1024) < 100]
            print(f"  → {len(song_only)} are likely single tracks (< 100MB)")

            print(f"\nSample torrents:")
            for i, t in enumerate(torrents_single[:5], 1):
                is_small = (t.size_bytes or 0) / (1024 * 1024) < 100
                marker = "🎵" if is_small else "💿"
                print(f"  {marker} [{i}] {t.title[:80]}")
                print(f"      Seeders: {t.seeders}, Format: {t.format}, Size: {t.size_formatted}")

                # Try to detect album from title
                album_in_title = "The Book of Souls" if "Book of Souls" in t.title else \
                                 "Fear of the Dark" if "Fear of the Dark" in t.title and "Book of Souls" not in t.title else \
                                 "Unknown"
                print(f"      Detected album: {album_in_title}")

    except Exception as e:
        print(f"✗ Error: {e}")
        torrents_single = []

    # ===== AUTO-MODE STRATEGY 2: Album Search =====
    print(f"\n{'─' * 80}")
    print("3. AUTO-MODE STRATEGY 2: Album Search")
    print(f"{'─' * 80}")

    query_album = f"{artist} {album}"
    print(f"\nQuery: '{query_album}'")
    print(f"Filters: format_filter=*, min_seeders=1")

    try:
        torrents_album = await torrent_service.search(
            query=query_album,
            format_filter="*",
            min_seeders=1
        )
        print(f"\n✓ Found {len(torrents_album)} torrent(s)")

        if torrents_album:
            print(f"\nSample torrents:")
            for i, t in enumerate(torrents_album[:5], 1):
                print(f"  [{i}] {t.title[:80]}")
                print(f"      Seeders: {t.seeders}, Format: {t.format}, Size: {t.size_formatted}")

    except Exception as e:
        print(f"✗ Error: {e}")
        torrents_album = []

    # ===== ANALYSIS =====
    print(f"\n{'=' * 80}")
    print("ANALYSIS")
    print(f"{'=' * 80}")

    print(f"\nPre-filter showed: {len(torrents_prefilter)} torrents for album '{album}'")
    print(f"Strategy 1 found: {len(torrents_single)} torrents for song '{song}'")
    print(f"Strategy 2 found: {len(torrents_album)} torrents for album '{album}'")

    # Check for mismatch
    if len(torrents_prefilter) > 0 and len(torrents_album) == 0:
        print(f"\n⚠️  MISMATCH DETECTED!")
        print(f"   Pre-filter said {len(torrents_prefilter)} torrents exist,")
        print(f"   but Strategy 2 (same album query) found {len(torrents_album)} torrents.")
        print(f"\n   Possible causes:")
        print(f"   1. min_seeders filter (pre-filter uses 0, actual uses 1)")
        print(f"   2. format_filter applied in actual search")
        print(f"   3. Deduplication differences")
        print(f"   4. Indexer availability changed between searches")

    if len(torrents_single) > 0 and len(torrents_album) == 0:
        print(f"\n⚠️  QUERY MISMATCH!")
        print(f"   User selected album '{album}'")
        print(f"   But Strategy 1 searches for song '{song}' (different query!)")
        print(f"   This returns torrents from OTHER albums containing that song.")
        print(f"\n   → AI will reject all if they don't match expected album")
        print(f"   → This is the 'index -1' scenario")

    if len(torrents_prefilter) > 0 and len(torrents_single) > 0 and len(torrents_album) > 0:
        print(f"\n✓ All strategies found torrents - system working as expected")

    print(f"\n{'=' * 80}")
    print("RECOMMENDATIONS")
    print(f"{'=' * 80}")
    print("""
1. Pre-filter should use SAME min_seeders as actual search will use
   Current: min_seeders=0
   Should be: min_seeders=<user's value>

2. Auto-mode Strategy 1 searches for song (artist + song name)
   This finds torrents from ANY album containing that song
   → Consider warning user if expected album doesn't match
   → Or skip Strategy 1 if user explicitly selected an album

3. Add logging to show:
   - Exact query used
   - Filters applied
   - Number of results before/after filtering
""")


if __name__ == "__main__":
    asyncio.run(debug_prefilter_vs_search())
