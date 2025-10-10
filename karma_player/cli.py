"""Refactored CLI using service layer."""

import asyncio
import logging
import os
import sys
import threading
import time
from pathlib import Path

import click

from karma_player import __version__
from karma_player.config import ConfigManager, Config
from karma_player.splash import show_splash
from karma_player.selection import SelectionInterface
from karma_player.torrent.display import ResultDisplay
from karma_player.musicbrainz import MusicBrainzError
from karma_player.services.search_orchestrator import SearchOrchestrator, SearchParams


def get_default_ai_model() -> str:
    """Auto-detect AI model based on available API keys.

    Priority order: Anthropic > OpenAI > Gemini

    Returns:
        Default model name

    Raises:
        RuntimeError: If no API keys are found
    """
    if os.environ.get("ANTHROPIC_API_KEY"):
        return "claude-3-5-sonnet-20241022"
    elif os.environ.get("OPENAI_API_KEY"):
        return "gpt-4o-mini"
    elif os.environ.get("GEMINI_API_KEY"):
        return "gemini/gemini-1.5-flash"
    else:
        raise RuntimeError(
            "No AI API key found. Please set one of:\n"
            "  - ANTHROPIC_API_KEY (for Claude)\n"
            "  - OPENAI_API_KEY (for GPT)\n"
            "  - GEMINI_API_KEY (for Gemini)"
        )


async def search_with_format_fallback(torrent_service, query, format_filter, strict, min_seeders):
    """Search for torrents with format preference and fallback logic.

    Args:
        torrent_service: TorrentSearchService instance
        query: Search query string
        format_filter: Preferred format (e.g., "FLAC", "MP3") or None for any
        strict: If True, ONLY return exact format match (no fallback)
        min_seeders: Minimum seeders filter

    Returns:
        List of torrent results
    """
    # If no format preference or strict=False with format, try preferred first
    if format_filter and not strict:
        # Try preferred format first
        torrents = await torrent_service.search(
            query=query,
            format_filter=format_filter,
            min_seeders=min_seeders
        )

        if torrents:
            return torrents

        # Fallback to any format
        click.echo(f"   💡 No {format_filter} found, trying any format...")
        torrents = await torrent_service.search(
            query=query,
            format_filter=None,
            min_seeders=min_seeders
        )
        return torrents

    # Strict mode or no format preference - single search
    return await torrent_service.search(
        query=query,
        format_filter=format_filter,
        min_seeders=min_seeders
    )


async def run_interactive_ai_search(
    orchestrator,
    query_str: str,
    ai_model: str,
    format_filter,
    strict: bool,
    min_seeders: int,
    profile,
    page_size,
    ai_model_auto_detected: bool = False
):
    """Run interactive AI-powered search with MusicBrainz understanding."""

    # Initialize AI session tracker
    from karma_player.ai.session_tracker import AISessionTracker
    ai_tracker = AISessionTracker(model=ai_model)

    # Normalize format filter
    if format_filter == "*":
        format_filter = None  # None means "any format"

    format_display = format_filter or "Any"
    if strict and format_filter:
        format_display = f"{format_filter} (strict)"

    # Show search configuration
    click.echo(f"\n🔧 {click.style('Search Configuration:', fg='blue')}")
    model_display = ai_model
    if ai_model_auto_detected:
        model_display = f"{ai_model} {click.style('(auto-detected)', dim=True)}"
    click.echo(f"   AI Model: {click.style(model_display, fg='cyan')}")
    click.echo(f"   Format: {click.style(format_display, fg='cyan')}")
    click.echo(f"   Min Seeders: {click.style(str(min_seeders), fg='cyan')}")
    click.echo(f"   Profile: {click.style(profile or 'remote (default)', fg='cyan')}")

    # Step 1: AI parses query + MusicBrainz lookup + AI grouping
    from rich.console import Console
    from rich.spinner import Spinner
    from rich.live import Live
    import time

    console = Console()
    start = time.time()

    spinner = Spinner("dots", text=f"🤔 Parsing query with AI and searching MusicBrainz...")

    with Live(spinner, console=console, transient=True):
        result, parsed, mb_selection = await orchestrator.interactive_search(
            query_str,
            ai_model=ai_model,
            format_filter=format_filter,
            min_seeders=min_seeders,
            ai_tracker=ai_tracker
        )

    elapsed = time.time() - start

    # Display what AI understood
    click.echo(f"\n   {click.style('✓ Understood in', fg='green')} {click.style(f'{elapsed:.1f}s', fg='cyan')}")
    click.echo(f"\n   {click.style('AI Understanding:', fg='blue')}")
    if parsed.artist:
        click.echo(f"   Artist: {click.style(parsed.artist, fg='cyan')}")
    if parsed.song:
        click.echo(f"   Song: {click.style(parsed.song, fg='cyan')}")
    if parsed.album:
        click.echo(f"   Album: {click.style(parsed.album, fg='cyan')}")
    click.echo(f"   Type: {parsed.search_type}")

    # Check if we have MusicBrainz results
    if not mb_selection.releases:
        click.echo("\n❌ Not found in MusicBrainz database")
        click.echo("   Falling back to direct torrent search...")

        # Fallback to direct search
        params = SearchParams(
            query=query_str,
            format_filter=format_filter,
            min_seeders=min_seeders,
            skip_musicbrainz=True,
            profile=profile,
            use_ai=True,
            ai_model=ai_model
        )
        search_result = await orchestrator.search(params)
        display_search_results(search_result, page_size, ai_tracker)
        return

    # Step 2: Pre-filter releases by checking torrent availability
    click.echo(f"\n{mb_selection.explanation}")
    click.echo(f"\n🔍 {click.style('Checking torrent availability for each album...', fg='yellow')}")

    from karma_player.services.torrent_service import TorrentSearchService
    from karma_player.services.adapter_factory import AdapterFactory

    adapter_factory = AdapterFactory(orchestrator.config)
    adapters = adapter_factory.create_adapters(profile_name=profile)
    torrent_service = TorrentSearchService(adapters)

    # Check each release for torrent availability
    available_releases = []
    for release in mb_selection.releases:
        artist = release.mb_result.artist
        album = release.mb_result.album

        if not album:
            continue

        # Search for torrents (check availability with user's filters)
        query = f"{artist} {album}"
        torrents = await torrent_service.search(
            query=query,
            format_filter=None,  # Check all formats for availability
            min_seeders=min_seeders  # Use same min_seeders as actual search will use
        )

        if torrents:
            available_releases.append(release)
            total_seeders = sum(t.seeders for t in torrents)
            click.echo(f"   ✓ {album[:50]} - {len(torrents)} torrent(s) ({total_seeders} seeders)")
        else:
            click.echo(f"   ✗ {album[:50]} - no torrents", nl=False)
            click.echo(click.style(" (skipped)", dim=True))

    # If no releases have torrents, fallback to generic artist search
    if not available_releases:
        click.echo(f"\n⚠️  {click.style('No torrents found for any MusicBrainz albums', fg='yellow')}")
        click.echo(f"   Falling back to generic search: {click.style(parsed.artist, fg='cyan', bold=True)}")

        # Search for artist only with format fallback
        generic_query = parsed.artist
        torrents_generic = await search_with_format_fallback(
            torrent_service=torrent_service,
            query=generic_query,
            format_filter=format_filter,
            strict=strict,
            min_seeders=min_seeders
        )

        if torrents_generic:
            click.echo(f"\n   ✓ Found {click.style(str(len(torrents_generic)), fg='green', bold=True)} torrent(s) for '{generic_query}'")

            from karma_player.services.search_orchestrator import SearchResult
            from karma_player.ai.agent import TorrentAgent

            search_result = SearchResult(
                torrents=torrents_generic,
                query_used=generic_query,
                musicbrainz_result=None
            )

            if ai_model:
                agent = TorrentAgent(model=ai_model, tracker=ai_tracker)

                # Build preferences without album constraint (we don't have specific album)
                prefs = {'format': format_filter} if format_filter else {}

                ai_decision = await agent.select_best_torrent(
                    query=generic_query,
                    results=torrents_generic,
                    preferences=prefs
                )
                search_result.ai_decision = ai_decision

            display_search_results(search_result, page_size, ai_tracker)
            return
        else:
            click.echo(f"\n❌ No torrents found even with generic search")
            return

    # Update releases list with only available ones
    mb_selection.releases = available_releases

    click.echo(f"\n📋 {click.style('What would you like to search for?', fg='green', bold=True)}")

    for i, release in enumerate(mb_selection.releases, 1):
        prefix = "🏆" if release.recommended else "  "
        label = click.style(f"[{i}]", fg='yellow')
        title = click.style(release.label, bold=release.recommended)
        click.echo(f"   {prefix} {label} {title}")
        if release.reason:
            click.echo(f"        → {release.reason}")

    # Step 3: User selects
    choice = click.prompt(
        "\nSelect option",
        type=click.IntRange(1, len(mb_selection.releases)),
        default=1
    )

    selected_release = mb_selection.releases[choice - 1]

    # Step 4: Ask user preference if this is a song search
    prefer_song_only = False
    search_other_albums = False
    if parsed.search_type == "song" and parsed.song:
        click.echo(f"\n🎵 {click.style('Song detected:', fg='blue')} \"{parsed.song}\" from album \"{selected_release.mb_result.album}\"")

        # Check if this is a song within an album (not just a standalone single)
        has_album = selected_release.mb_result.album is not None

        click.echo(f"\n   {click.style('Search preference:', fg='yellow')}")
        click.echo(f"   [1] Try to find just this song (single track)")
        click.echo(f"   [2] Open to full album if song-only not available in good quality")

        max_option = 2
        if has_album:
            click.echo(f"   [3] Search other albums containing this song")
            click.echo(f"   [4] 🎲 {click.style('Just get it for me!', fg='magenta', bold=True)} (auto-try: single → album → best available)")
            max_option = 4

        pref = click.prompt(
            "\nYour preference",
            type=click.IntRange(1, max_option),
            default=2
        )
        prefer_song_only = (pref == 1)
        search_other_albums = (pref == 3)
        auto_fallback = (pref == 4)

        # If user wants to search other albums, actually search torrents for them
        if search_other_albums:
            click.echo(f"\n🔍 {click.style('Searching torrents for albums containing', fg='cyan')} '{click.style(parsed.song, fg='yellow')}'...")

            # Get MusicBrainz albums containing this song
            mb_service = orchestrator.mb_service
            search_artist = selected_release.mb_result.artist or parsed.artist
            other_results = mb_service.search_recordings(
                query=parsed.song,
                artist=search_artist,
                limit=30
            )

            # Group by unique album
            original_album = selected_release.mb_result.album
            albums_seen = {}
            for r in other_results:
                if r.album and r.album != original_album and r.album not in albums_seen:
                    albums_seen[r.album] = r

            if not albums_seen:
                click.echo(f"   ⚠️  No other albums found")
                click.echo(f"   Continuing with original selection...")
            else:
                # Search torrents for each album
                total_albums = len(albums_seen)
                click.echo(f"   Found {click.style(str(total_albums), fg='yellow', bold=True)} albums, searching for torrents...\n")

                from karma_player.services.torrent_service import TorrentSearchService
                from karma_player.services.adapter_factory import AdapterFactory

                adapter_factory = AdapterFactory(orchestrator.config)
                adapters = adapter_factory.create_adapters(profile_name=profile)
                torrent_service = TorrentSearchService(adapters)

                albums_with_torrents = []
                for idx, (album_name, mb_result) in enumerate(albums_seen.items(), 1):
                    # Progress indicator
                    progress = f"[{idx}/{total_albums}]"
                    album_short = album_name[:50] + "..." if len(album_name) > 50 else album_name

                    click.echo(f"   {click.style(progress, fg='cyan')} 🔍 Searching: {click.style(album_short, fg='white', bold=True)}", nl=False)

                    # Search torrents for this album
                    query = f"{mb_result.artist} {album_name}"
                    import time
                    start = time.time()
                    torrents = await search_with_format_fallback(
                        torrent_service=torrent_service,
                        query=query,
                        format_filter=format_filter,
                        strict=strict,
                        min_seeders=min_seeders
                    )
                    elapsed = time.time() - start

                    if torrents:
                        # Calculate best torrent quality metrics
                        best_torrent = max(torrents, key=lambda t: (t.seeders, t.size_bytes or 0))
                        albums_with_torrents.append({
                            'mb_result': mb_result,
                            'torrents': torrents,
                            'best_torrent': best_torrent,
                            'total_seeders': sum(t.seeders for t in torrents),
                            'count': len(torrents)
                        })
                        click.echo(f" {click.style('✓', fg='green')} Found {click.style(str(len(torrents)), fg='green', bold=True)} torrents ({elapsed:.1f}s)")
                    else:
                        click.echo(f" {click.style('✗', fg='red')} No torrents ({elapsed:.1f}s)")

                if not albums_with_torrents:
                    click.echo(f"\n   ❌ No torrents found for any album containing '{parsed.song}'")
                    click.echo(f"   Continuing with original selection...")
                else:
                    # Sort by torrent quality (seeders, count)
                    albums_with_torrents.sort(key=lambda x: (x['total_seeders'], x['count']), reverse=True)

                    # Summary
                    total_torrents = sum(x['count'] for x in albums_with_torrents)
                    click.echo(f"\n📊 {click.style('Summary:', fg='cyan')} Found {click.style(str(total_torrents), fg='green', bold=True)} torrents across {click.style(str(len(albums_with_torrents)), fg='yellow', bold=True)} albums")
                    click.echo(f"   {click.style('Sorted by availability: Most seeders first', fg='blue', dim=True)}\n")

                    for i, album_data in enumerate(albums_with_torrents[:10], 1):
                        result = album_data['mb_result']
                        best = album_data['best_torrent']
                        count = album_data['count']
                        total_seeders = album_data['total_seeders']

                        # Determine type
                        title_lower = result.album.lower() if result.album else ""
                        is_compilation = any(word in title_lower for word in ['best of', 'greatest', 'collection', 'anthology', 'compilation'])

                        if is_compilation:
                            album_color = 'yellow'
                            type_icon = '📚'
                        else:
                            album_color = 'green'
                            type_icon = '💿'

                        year_str = f"[{click.style(str(result.year), fg='cyan')}]" if result.year else ""

                        # Main line
                        click.echo(f"   {type_icon} [{click.style(str(i), fg='yellow')}] {click.style(result.album, fg=album_color, bold=True)} {year_str}")

                        # Torrent info
                        click.echo(f"        {click.style('↓ Torrents:', fg='green')} {count} • {click.style('Seeders:', fg='yellow')} {total_seeders} • {click.style('Best:', fg='cyan')} {best.format or 'Unknown'} {best.size_formatted}")

                        click.echo("")

                    click.echo(f"   [0] {click.style('Cancel', fg='red')} - go back to '{original_album}'")

                    album_choice = click.prompt(
                        "\nSelect album",
                        type=click.IntRange(0, len(albums_with_torrents)),
                        default=0
                    )

                    if album_choice > 0:
                        # User selected an album - use the torrents we already found!
                        selected_album_data = albums_with_torrents[album_choice - 1]
                        selected_release.mb_result = selected_album_data['mb_result']

                        click.echo(f"\n✓ Selected: {click.style(selected_album_data['mb_result'].album, fg='green', bold=True)}")
                        click.echo(f"   {selected_album_data['count']} torrents available with {selected_album_data['total_seeders']} total seeders\n")

                        # Create SearchResult with the torrents we already found
                        from karma_player.services.search_orchestrator import SearchResult

                        search_result = SearchResult(
                            torrents=selected_album_data['torrents'],
                            query_used=f"{selected_album_data['mb_result'].artist} {selected_album_data['mb_result'].album}",
                            musicbrainz_result=selected_album_data['mb_result']
                        )

                        # Use AI to select best torrent
                        if ai_model:
                            from karma_player.ai.agent import TorrentAgent
                            agent = TorrentAgent(model=ai_model, tracker=ai_tracker)

                            # Build preferences with album context
                            prefs = {'format': format_filter} if format_filter else {}
                            prefs['expected_album'] = selected_album_data['mb_result'].album
                            prefs['expected_artist'] = selected_album_data['mb_result'].artist

                            ai_decision = await agent.select_best_torrent(
                                query=f"{selected_album_data['mb_result'].artist} {selected_album_data['mb_result'].album}",
                                results=search_result.torrents,
                                preferences=prefs
                            )
                            search_result.ai_decision = ai_decision

                        display_search_results(search_result, page_size, ai_tracker)
                        return  # Done! Skip the normal search flow

        # Auto-fallback mode: Try single → album → best available
        if auto_fallback and has_album:
            click.echo(f"\n🎲 {click.style('Auto mode:', fg='magenta', bold=True)} Finding best option for you...")

            from karma_player.services.torrent_service import TorrentSearchService
            from karma_player.services.adapter_factory import AdapterFactory

            adapter_factory = AdapterFactory(orchestrator.config)
            adapters = adapter_factory.create_adapters(profile_name=profile)
            torrent_service = TorrentSearchService(adapters)

            # Setup for spinners
            from rich.console import Console
            from rich.spinner import Spinner
            from rich.live import Live
            import time

            console = Console()

            # Strategy 1: Try single track
            click.echo(f"\n   {click.style('[1/3]', fg='cyan')} 🎵 Trying single track...")
            query_single = f"{selected_release.mb_result.artist} {parsed.song}"
            click.echo(f"      Query: {click.style(query_single, dim=True)}")

            start = time.time()

            with Live(Spinner("dots", text="Searching indexers..."), console=console, transient=True):
                torrents_single = await search_with_format_fallback(
                    torrent_service=torrent_service,
                    query=query_single,
                    format_filter=format_filter,
                    strict=strict,
                    min_seeders=min_seeders
                )

            elapsed = time.time() - start

            # Filter for likely song-only (< 100MB)
            song_only = [t for t in torrents_single if (t.size_bytes or 0) / (1024 * 1024) < 100]

            if song_only:
                click.echo(f" {click.style('✓', fg='green')} Found {click.style(str(len(song_only)), fg='green', bold=True)} single track(s)! ({elapsed:.1f}s)")

                from karma_player.services.search_orchestrator import SearchResult
                from karma_player.ai.agent import TorrentAgent

                search_result = SearchResult(
                    torrents=song_only,
                    query_used=query_single,
                    musicbrainz_result=selected_release.mb_result
                )

                if ai_model:
                    agent = TorrentAgent(model=ai_model, tracker=ai_tracker)

                    # Build preferences with album context
                    prefs = {'format': format_filter} if format_filter else {}
                    prefs['expected_album'] = selected_release.mb_result.album
                    prefs['expected_artist'] = selected_release.mb_result.artist
                    prefs['prefer_song_only'] = True

                    ai_decision = await agent.select_best_torrent(
                        query=query_single,
                        results=song_only,
                        preferences=prefs
                    )
                    search_result.ai_decision = ai_decision

                    # If AI couldn't match the album, continue to Strategy 2
                    if ai_decision.album_mismatch:
                        click.echo(f"\n   ⚠️  {click.style('Album mismatch detected', fg='yellow')}")
                        click.echo(f"      Expected: {click.style(selected_release.mb_result.album, fg='cyan')}")
                        click.echo(f"      Found torrents from different albums")
                        click.echo(f"      Continuing to Strategy 2 (search for correct album)...")
                        # Don't return, continue to Strategy 2
                    else:
                        # AI found a good match, use it
                        display_search_results(search_result, page_size, ai_tracker)
                        return
                else:
                    # No AI, just display best quality
                    display_search_results(search_result, page_size, ai_tracker)
                    return

            click.echo(f" {click.style('✗', fg='red')} No single tracks ({elapsed:.1f}s)")

            # Strategy 2: Try the original selected album
            album_short = selected_release.mb_result.album[:40] + "..." if len(selected_release.mb_result.album) > 40 else selected_release.mb_result.album
            click.echo(f"\n   {click.style('[2/3]', fg='cyan')} 💿 Trying album: {click.style(album_short, bold=True)}...")
            query_album = f"{selected_release.mb_result.artist} {selected_release.mb_result.album}"
            click.echo(f"      Query: {click.style(query_album, dim=True)}")

            start = time.time()

            with Live(Spinner("dots", text="Searching indexers..."), console=console, transient=True):
                torrents_album = await search_with_format_fallback(
                    torrent_service=torrent_service,
                    query=query_album,
                    format_filter=format_filter,
                    strict=strict,
                    min_seeders=min_seeders
                )

            elapsed = time.time() - start

            if torrents_album:
                click.echo(f" {click.style('✓', fg='green')} Found {click.style(str(len(torrents_album)), fg='green', bold=True)} torrent(s)! ({elapsed:.1f}s)")

                from karma_player.services.search_orchestrator import SearchResult
                from karma_player.ai.agent import TorrentAgent

                search_result = SearchResult(
                    torrents=torrents_album,
                    query_used=query_album,
                    musicbrainz_result=selected_release.mb_result
                )

                if ai_model:
                    agent = TorrentAgent(model=ai_model, tracker=ai_tracker)

                    # Build preferences with album context
                    prefs = {'format': format_filter} if format_filter else {}
                    prefs['expected_album'] = selected_release.mb_result.album
                    prefs['expected_artist'] = selected_release.mb_result.artist

                    ai_decision = await agent.select_best_torrent(
                        query=query_album,
                        results=torrents_album,
                        preferences=prefs
                    )
                    search_result.ai_decision = ai_decision

                display_search_results(search_result, page_size, ai_tracker)
                return

            click.echo(f" {click.style('✗', fg='red')} No torrents ({elapsed:.1f}s)")

            # Strategy 3: Search all albums containing the song and pick best
            click.echo(f"\n   {click.style('[3/3]', fg='cyan')} 🔍 Searching other albums...", nl=False)

            # Get MusicBrainz albums containing this song
            mb_service = orchestrator.mb_service
            search_artist = selected_release.mb_result.artist or parsed.artist
            other_results = mb_service.search_recordings(
                query=parsed.song,
                artist=search_artist,
                limit=30
            )

            # Group by unique album
            albums_seen = {}
            for r in other_results:
                if r.album and r.album not in albums_seen:
                    albums_seen[r.album] = r

            click.echo(f" {len(albums_seen)} albums found, checking torrents...\n")

            albums_with_torrents = []
            for idx, (album_name, mb_result) in enumerate(albums_seen.items(), 1):
                album_short = album_name[:40] + "..." if len(album_name) > 40 else album_name
                click.echo(f"      [{idx}/{len(albums_seen)}] {album_short}")

                try:
                    query = f"{mb_result.artist} {album_name}"
                    start = time.time()

                    with Live(Spinner("dots", text=f"Searching..."), console=console, transient=True):
                        torrents = await search_with_format_fallback(
                            torrent_service=torrent_service,
                            query=query,
                            format_filter=format_filter,
                            strict=strict,
                            min_seeders=min_seeders
                        )

                    elapsed = time.time() - start

                    if torrents:
                        best_torrent = max(torrents, key=lambda t: (t.seeders, t.size_bytes or 0))
                        albums_with_torrents.append({
                            'mb_result': mb_result,
                            'torrents': torrents,
                            'best_torrent': best_torrent,
                            'total_seeders': sum(t.seeders for t in torrents),
                            'count': len(torrents)
                        })
                        click.echo(f"          {click.style('✓', fg='green')} {len(torrents)} torrents ({elapsed:.1f}s)")
                    else:
                        click.echo(f"          {click.style('✗', dim=True)} No torrents ({elapsed:.1f}s)")
                except Exception as e:
                    click.echo(f"          {click.style('ERROR', fg='red')} {str(e)[:50]}")
                    continue

            if albums_with_torrents:
                # Sort by seeders and pick best
                albums_with_torrents.sort(key=lambda x: (x['total_seeders'], x['count']), reverse=True)
                best_album = albums_with_torrents[0]

                click.echo(f"        ✓ Best option: {click.style(best_album['mb_result'].album, fg='green', bold=True)}")
                click.echo(f"           {best_album['count']} torrents • {best_album['total_seeders']} seeders\n")

                from karma_player.services.search_orchestrator import SearchResult
                from karma_player.ai.agent import TorrentAgent

                search_result = SearchResult(
                    torrents=best_album['torrents'],
                    query_used=f"{best_album['mb_result'].artist} {best_album['mb_result'].album}",
                    musicbrainz_result=best_album['mb_result']
                )

                if ai_model:
                    agent = TorrentAgent(model=ai_model, tracker=ai_tracker)

                    # Build preferences with album context
                    prefs = {'format': format_filter} if format_filter else {}
                    prefs['expected_album'] = best_album['mb_result'].album
                    prefs['expected_artist'] = best_album['mb_result'].artist

                    ai_decision = await agent.select_best_torrent(
                        query=f"{best_album['mb_result'].artist} {best_album['mb_result'].album}",
                        results=best_album['torrents'],
                        preferences=prefs
                    )
                    search_result.ai_decision = ai_decision

                display_search_results(search_result, page_size, ai_tracker)
                return
            else:
                click.echo(f"        ✗ No torrents found anywhere\n")
                click.echo(f"   😞 Sorry, couldn't find '{parsed.song}' anywhere with your criteria.")
                return

    # Step 5: Build torrent query from selected MusicBrainz result
    torrent_query = orchestrator.build_torrent_query_from_musicbrainz(
        selected_release.mb_result,
        prefer_song_only=prefer_song_only
    )

    click.echo(f"\n🔎 Searching torrents for: {click.style(torrent_query, fg='cyan')}")
    if prefer_song_only:
        click.echo(f"   Prioritizing: {click.style('Song-only torrents', fg='green')}")
    else:
        click.echo(f"   Accepting: {click.style('Song or Album torrents', fg='green')}")

    click.echo(f"   Format: {click.style(format_filter or 'Any', fg='yellow')}")
    click.echo(f"   Min seeders: {click.style(str(min_seeders), fg='yellow')}")

    # Step 6: Execute torrent search
    params = SearchParams(
        query=torrent_query,
        format_filter=format_filter,
        min_seeders=min_seeders,
        skip_musicbrainz=True,
        profile=profile,
        use_ai=True,
        ai_model=ai_model,
        prefer_song_only=prefer_song_only
    )

    # Show progress
    click.echo(f"\n⏳ {click.style('Querying indexers...', fg='blue')}", nl=False)
    click.echo(f" (this may take a few seconds for remote indexers)")

    import time
    start_time = time.time()

    search_result = await orchestrator.search(params, selected_release.mb_result)

    elapsed = time.time() - start_time

    # Show what was found
    if search_result.torrents:
        click.echo(f"   ✓ Found {click.style(str(len(search_result.torrents)), fg='green')} torrents in {elapsed:.1f}s")

        # Show filtering stats if applicable
        if format_filter:
            click.echo(f"   → Filtered by format: {click.style(format_filter, fg='cyan')}")
        if min_seeders > 0:
            click.echo(f"   → Min seeders applied: {click.style(str(min_seeders), fg='cyan')}")
    else:
        click.echo(f"   ✗ No torrents found (searched for {elapsed:.1f}s)")

    # Step 7: Analyze and categorize results
    if search_result.torrents:
        # Check if we found song-only vs album torrents
        # Heuristics: song-only = small size (<100MB) OR has "single" in title
        def is_likely_song_only(torrent):
            size_mb = torrent.size_bytes / (1024 * 1024) if torrent.size_bytes else 999999
            return size_mb < 100 or 'single' in torrent.title.lower() or '- -' in torrent.title

        def is_likely_discography(torrent):
            title_lower = torrent.title.lower()
            size_gb = torrent.size_bytes / (1024 * 1024 * 1024) if torrent.size_bytes else 0
            return ('discography' in title_lower or 'complete' in title_lower or
                    'collection' in title_lower or size_gb > 3)

        # Categorize torrents
        song_only_torrents = []
        album_torrents = []
        discography_torrents = []

        for t in search_result.torrents:
            if is_likely_discography(t):
                discography_torrents.append(t)
            elif is_likely_song_only(t):
                song_only_torrents.append(t)
            else:
                album_torrents.append(t)

        if parsed.search_type == "song":
            # Show what we found
            click.echo(f"\n📊 {click.style('Torrent Categories:', fg='blue')}")
            if song_only_torrents:
                click.echo(f"   🎵 Song-only: {click.style(str(len(song_only_torrents)), fg='green')}")
            if album_torrents:
                click.echo(f"   💿 Albums: {click.style(str(len(album_torrents)), fg='cyan')}")
                # Confirm song is in the album
                if parsed.song and selected_release.mb_result.album:
                    click.echo(f"   ℹ️  Note: '{parsed.song}' is included in the '{selected_release.mb_result.album}' album")
            if discography_torrents:
                click.echo(f"   📚 Discography/Compilations: {click.style(str(len(discography_torrents)), fg='yellow')}")

            # Inform user based on their preference
            if prefer_song_only:
                if not song_only_torrents:
                    click.echo(f"\n   ⚠️  You wanted song-only, but only albums/compilations available.")
                    click.echo(f"       AI will select best quality album containing '{parsed.song}'.")
                else:
                    click.echo(f"\n   ✓ Found {len(song_only_torrents)} song-only torrents matching your preference!")
            else:
                click.echo(f"\n   ℹ️  Showing best match across all categories (quality prioritized)")

    # Step 6: Display results
    display_search_results(search_result, page_size, ai_tracker)


def display_ai_session_summary(ai_tracker):
    """Display AI session usage summary.

    Args:
        ai_tracker: AISessionTracker instance
    """
    if ai_tracker:
        stats = ai_tracker.stats
        click.echo(f"\n{'─' * 70}")
        click.echo(f"📊 {click.style('AI Session Summary:', fg='blue', bold=True)}")
        click.echo(f"   Model: {click.style(stats.model_name, fg='cyan')}")

        if stats.total_tokens > 0:
            click.echo(f"   Tokens: {click.style(f'{stats.total_tokens:,}', fg='yellow')} "
                      f"({click.style(f'{stats.prompt_tokens:,}', fg='green')} in / "
                      f"{click.style(f'{stats.completion_tokens:,}', fg='magenta')} out)")
            click.echo(f"   API Calls: {click.style(str(stats.api_calls), fg='cyan')}")
            if stats.total_cost > 0:
                cost_str = f"${stats.total_cost:.4f}"
                click.echo(f"   Cost: {click.style(cost_str, fg='yellow', bold=True)}")
        else:
            click.echo(f"   {click.style('No AI calls tracked', dim=True)}")

        click.echo(f"{'─' * 70}")


def display_search_results(search_result, page_size, ai_tracker=None):
    """Display search results (AI or manual)."""
    if not search_result or not search_result.torrents:
        click.echo("\n❌ No torrents found.")
        if ai_tracker:
            display_ai_session_summary(ai_tracker)
        return

    # AI Decision
    if search_result.ai_decision:
        decision = search_result.ai_decision
        torrent = decision.selected_torrent

        click.echo(f"\n🤖 AI Decision")
        click.echo(f"   └─ {click.style('Selected:', fg='green', bold=True)} {torrent.title}")
        click.echo(f"      Format: {click.style(torrent.format or 'Unknown', fg='cyan')}")
        click.echo(f"      Size: {torrent.size_formatted} | Seeders: {click.style(str(torrent.seeders), fg='yellow')}")
        click.echo(f"      Quality Score: {click.style(f'{torrent.quality_score:.1f}', fg='yellow', bold=True)}")
        click.echo(f"\n   {click.style('💭 Reasoning:', fg='blue')}")
        click.echo(f"      {decision.reasoning}")

        if decision.top_candidates:
            click.echo(f"\n   {click.style('🏆 Top Candidates:', fg='green')}")
            for idx, cand, reason in decision.top_candidates[:3]:
                click.echo(f"      [{idx}] {cand.title[:60]}...")
                click.echo(f"          → {reason}")

        if decision.rejected:
            click.echo(f"\n   {click.style('❌ Rejected:', fg='red')}")
            for idx, rej, reason in decision.rejected[:3]:
                click.echo(f"      [{idx}] {rej.title[:60]}...")
                click.echo(f"          → {reason}")

        # Show quality ranking of ALL torrents
        click.echo(f"\n   {click.style('📊 Quality Ranking (All Torrents):', fg='blue')}")
        sorted_torrents = sorted(search_result.torrents, key=lambda t: t.quality_score, reverse=True)
        for rank, t in enumerate(sorted_torrents[:6], 1):
            is_selected = (t.title == torrent.title)
            marker = click.style('✓ SELECTED', fg='green', bold=True) if is_selected else ''
            title_display = t.title[:55] + "..." if len(t.title) > 55 else t.title
            score_display = click.style(f'{t.quality_score:.0f}', fg='yellow', bold=True) if is_selected else f'{t.quality_score:.0f}'

            # Build quality indicators
            quality_tags = []
            title_upper = t.title.upper()

            # Hi-res detection
            if t.bitrate:
                bitrate_upper = t.bitrate.upper()
                if "DSD" in bitrate_upper or "DSD" in title_upper:
                    quality_tags.append(click.style("DSD", fg='magenta', bold=True))
                elif any(m in bitrate_upper or m in title_upper for m in ["24/192", "24/176", "24/96", "24/88", "24BIT", "24-BIT"]):
                    quality_tags.append(click.style("24-bit", fg='cyan', bold=True))

            # LP/Vinyl
            if any(m in title_upper for m in ["[LP]", "(LP)", "VINYL", "ビニール"]):
                quality_tags.append(click.style("LP", fg='green'))

            # Format
            if t.format:
                quality_tags.append(t.format)

            quality_str = " ".join(quality_tags) if quality_tags else "?"

            click.echo(f"      #{rank} [{score_display}] {title_display} {marker}")
            if not is_selected:
                gap = torrent.quality_score - t.quality_score
                click.echo(f"          {click.style(f'-{gap:.0f} pts', dim=True)} | {quality_str} | {t.size_formatted} | {t.seeders} seeders")
            else:
                click.echo(f"          {quality_str} | {t.size_formatted} | {t.seeders} seeders")

        # Show top 3 magnet links from top candidates (or just selected if no candidates)
        click.echo(f"\n🧲 {click.style('Magnet Links (Top 3):', fg='green', bold=True)}")

        # Get top 3 unique torrents (selected + top candidates)
        top_torrents = []
        seen_titles = set()

        # Always include selected torrent first
        top_torrents.append((decision.selected_index, torrent, "SELECTED"))
        seen_titles.add(torrent.title)

        # Add top candidates
        for idx, cand, reason in decision.top_candidates[:5]:  # Check up to 5 to get 3 unique
            if cand.title not in seen_titles and len(top_torrents) < 3:
                top_torrents.append((idx, cand, reason))
                seen_titles.add(cand.title)

        # Display magnet links
        for rank, (idx, t, reason) in enumerate(top_torrents, 1):
            is_selected = (rank == 1)
            marker = click.style('✓ SELECTED', fg='green', bold=True) if is_selected else ''
            title_display = t.title[:70] + "..." if len(t.title) > 70 else t.title

            click.echo(f"\n   [{rank}] {click.style(title_display, bold=is_selected)} {marker}")
            click.echo(f"       Format: {t.format or '?'} | Size: {t.size_formatted} | Seeders: {t.seeders}")
            click.echo(f"       {t.magnet_link}")

        # Show AI session summary
        if ai_tracker:
            display_ai_session_summary(ai_tracker)
    else:
        # Manual selection
        click.echo(f"\n✅ Found {len(search_result.torrents)} torrents")

        display = ResultDisplay()
        if page_size is None:
            import shutil
            terminal_height = shutil.get_terminal_size().lines
            page_size = max(10, terminal_height - 12)

        display.show_results(search_result.torrents, page_size=page_size)

        selected_torrent = display.prompt_selection(search_result.torrents, allow_retry=False)

        # Show AI session summary
        if ai_tracker:
            display_ai_session_summary(ai_tracker)

        if selected_torrent:
            click.echo(f"\n✅ Selected: {selected_torrent.title}")
            click.echo(f"   Format: {selected_torrent.format or 'Unknown'}")
            click.echo(f"   Size: {selected_torrent.size_formatted}")
            click.echo(f"   Seeders: {selected_torrent.seeders}")
            click.echo(f"\n🧲 Magnet link:")
            click.echo(f"   {selected_torrent.magnet_link}")


@click.group()
@click.version_option(version=__version__, prog_name="karma-player")
@click.option("--debug", is_flag=True, help="Enable debug logging")
@click.pass_context
def cli(ctx, debug):
    """Karma Player - AI-powered music search with community verification."""
    ctx.ensure_object(dict)
    ctx.obj["config_manager"] = ConfigManager()
    ctx.obj["show_splash"] = os.environ.get("KARMA_PLAYER_NO_SPLASH") != "1"

    # Configure logging based on debug flag or environment variable
    log_level = logging.DEBUG if (debug or os.environ.get("KARMA_PLAYER_DEBUG")) else logging.WARNING
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )


@cli.command()
@click.argument("query", nargs=-1, required=True)
@click.option("--artist", "-a", help="Filter by artist name")
@click.option("--limit", "-l", default=10, type=int, help="Maximum MusicBrainz results")
@click.option("--format", "-f", default="*", help="Prefer format (FLAC, MP3, or * for best quality). Falls back to best available if preferred not found.")
@click.option("--strict", is_flag=True, help="Strict format filter - ONLY return exact format match, no fallback")
@click.option("--min-seeders", type=int, default=1, help="Minimum seeders (default: 1)")
@click.option("--page-size", type=int, default=None, help="Torrents per page")
@click.option("--skip-musicbrainz", is_flag=True, help="Skip MusicBrainz search")
@click.option("--profile", "-p", default=None, help="Indexer profile to use (default: from indexers.yaml)")
@click.option("--ai/--no-ai", default=True, help="Use AI for intelligent search (default: enabled)")
@click.option("--ai-model", default=None, help="AI model (auto-detected from available API keys: claude-3-5-sonnet-20241022, gpt-4o-mini, gemini/gemini-pro)")
@click.pass_context
def search(
    ctx,
    query,
    artist,
    limit,
    format,
    strict,
    min_seeders,
    page_size,
    skip_musicbrainz,
    profile,
    ai,
    ai_model,
):
    """Search for music and find torrents."""
    # Show splash
    if ctx.obj.get("show_splash", False):
        show_splash()
        ctx.obj["show_splash"] = False

    config_manager: ConfigManager = ctx.obj["config_manager"]

    if not config_manager.is_initialized():
        click.echo("❌ Configuration not initialized.", err=True)
        click.echo("   Run: karma-player init", err=True)
        sys.exit(1)

    query_str = " ".join(query)
    cfg = config_manager.load_config()
    orchestrator = SearchOrchestrator(cfg)

    # Convert format "*" to None (means "any format")
    format_filter = None if format == "*" else format

    # Auto-detect AI model if not specified
    ai_model_auto_detected = False
    if ai and ai_model is None:
        try:
            ai_model = get_default_ai_model()
            ai_model_auto_detected = True
        except RuntimeError as e:
            click.echo(f"❌ {str(e)}", err=True)
            sys.exit(1)

    try:
        # AI Mode: Conversational flow with intelligent understanding
        if ai and not skip_musicbrainz:
            asyncio.run(run_interactive_ai_search(
                orchestrator, query_str, ai_model, format_filter, strict, min_seeders, profile, page_size, ai_model_auto_detected
            ))
            return

        # Standard Mode: Original flow
        selected_mb = None

        if not skip_musicbrainz:
            click.echo(f"\n🔍 Searching MusicBrainz for: {query_str}")
            if artist:
                click.echo(f"   Artist filter: {artist}")

            mb_results = orchestrator.get_musicbrainz_results(query_str, artist, limit)

            if not mb_results:
                click.echo("\n❌ No MusicBrainz results found.")
                sys.exit(0)

            # Display and let user select
            click.echo(f"\n📀 Found {len(mb_results)} recordings:\n")
            for i, result in enumerate(mb_results, 1):
                click.echo(f"[{i}] {result}")
                click.echo(f"    MBID: {result.mbid}\n")

            selection_ui = SelectionInterface()
            selected_mb = selection_ui.prompt_selection(
                mb_results,
                prompt_text="Select a recording to find torrents",
                display_fn=lambda r: f"{r.artist} - {r.title} ({r.album or 'Unknown Album'})",
            )

            if not selected_mb:
                click.echo("\n❌ Selection cancelled.")
                sys.exit(0)

        # Step 2: Search torrents
        params = SearchParams(
            query=query_str,
            artist=artist,
            limit=limit,
            format_filter=format_filter,
            min_seeders=min_seeders,
            skip_musicbrainz=skip_musicbrainz,
            profile=profile,
            use_ai=ai,
            ai_model=ai_model,
        )

        # Run search with progress bar
        result_container = []

        def run_search():
            result = asyncio.run(orchestrator.search(params, selected_mb))
            result_container.append(result)

        click.echo(f"\n🔎 Searching torrents...")
        click.echo(f"   Query: '{query_str}'")
        click.echo(f"   Format: {format or 'Any'}")
        click.echo(f"   Min seeders: {min_seeders}")
        if profile:
            click.echo(f"   Profile: {profile}")
        if ai:
            click.echo(f"   AI: {ai_model}")

        with click.progressbar(
            length=100,
            label="   Searching",
            show_percent=False,
            show_pos=False,
            bar_template="%(label)s %(bar)s",
            fill_char="█",
            empty_char="░",
        ) as bar:
            search_thread = threading.Thread(target=run_search)
            search_thread.start()

            start_time = time.time()
            max_duration = 10

            while search_thread.is_alive():
                elapsed = time.time() - start_time
                if elapsed >= max_duration:
                    break
                progress = min(int((elapsed / max_duration) * 100), 99)
                current_progress = bar.pos or 0
                if progress > current_progress:
                    bar.update(progress - current_progress)
                time.sleep(0.1)

            search_thread.join()
            if bar.pos < 100:
                bar.update(100 - (bar.pos or 0))

        search_result = result_container[0] if result_container else None

        if not search_result or not search_result.torrents:
            click.echo("\n❌ No torrents found.")
            sys.exit(0)

        # Step 3: Display results or auto-select with AI
        if search_result.ai_decision:
            decision = search_result.ai_decision
            torrent = decision.selected_torrent

            click.echo(f"\n🤖 AI Decision")
            click.echo(f"   └─ {click.style('Selected:', fg='green', bold=True)} {torrent.title}")
            click.echo(f"      Format: {click.style(torrent.format or 'Unknown', fg='cyan')}")
            click.echo(f"      Size: {torrent.size_formatted} | Seeders: {click.style(str(torrent.seeders), fg='yellow')}")
            click.echo(f"\n   {click.style('💭 Reasoning:', fg='blue')}")
            click.echo(f"      {decision.reasoning}")

            if decision.top_candidates:
                click.echo(f"\n   {click.style('🏆 Top Candidates:', fg='green')}")
                for idx, cand, reason in decision.top_candidates[:3]:
                    click.echo(f"      [{idx}] {cand.title[:60]}...")
                    click.echo(f"          → {reason}")

            if decision.rejected:
                click.echo(f"\n   {click.style('❌ Rejected:', fg='red')}")
                for idx, rej, reason in decision.rejected[:5]:
                    click.echo(f"      [{idx}] {rej.title[:60]}...")
                    click.echo(f"          → {reason}")

            click.echo(f"\n🧲 Magnet link:")
            click.echo(f"   {torrent.magnet_link}")
        else:
            # Manual selection
            click.echo(f"\n✅ Found {len(search_result.torrents)} torrents")

            display = ResultDisplay()
            if page_size is None:
                import shutil

                terminal_height = shutil.get_terminal_size().lines
                page_size = max(10, terminal_height - 12)

            display.show_results(search_result.torrents, page_size=page_size)

            selected_torrent = display.prompt_selection(
                search_result.torrents, allow_retry=False
            )

            if not selected_torrent:
                click.echo("\n❌ Selection cancelled.")
                sys.exit(0)

            click.echo(f"\n✅ Selected: {selected_torrent.title}")
            click.echo(f"   Format: {selected_torrent.format or 'Unknown'}")
            click.echo(f"   Size: {selected_torrent.size_formatted}")
            click.echo(f"   Seeders: {selected_torrent.seeders}")
            click.echo(f"\n🧲 Magnet link:")
            click.echo(f"   {selected_torrent.magnet_link}")

    except MusicBrainzError as e:
        click.echo(f"\n❌ MusicBrainz error: {e}", err=True)
        sys.exit(1)
    except Exception as e:
        click.echo(f"\n❌ Error: {e}", err=True)
        import traceback

        traceback.print_exc()
        sys.exit(1)


@cli.command()
@click.option(
    "--musicbrainz-key",
    prompt="MusicBrainz API key (get one at https://musicbrainz.org/account/applications)",
    help="MusicBrainz API key for metadata queries",
)
@click.option(
    "--music-dir",
    type=click.Path(exists=False, file_okay=False, dir_okay=True, path_type=Path),
    default=Path.home() / "Music",
    prompt=f"Music directory path (default: {Path.home() / 'Music'})",
    help="Directory where downloaded music will be saved",
)
@click.option(
    "--jackett-url",
    default="",
    prompt="Jackett URL (optional, press Enter to skip)",
    help="Jackett server URL",
)
@click.option(
    "--jackett-key",
    default="",
    prompt="Jackett API key (optional, press Enter to skip)",
    help="Jackett API key",
)
@click.pass_context
def init(ctx, musicbrainz_key: str, music_dir: Path, jackett_url: str, jackett_key: str):
    """Initialize Karma Player configuration."""
    config_manager: ConfigManager = ctx.obj["config_manager"]

    click.echo("\n🎵 Initializing Karma Player configuration...")

    if config_manager.is_initialized():
        if not click.confirm("\nConfiguration already exists. Overwrite?", default=False):
            click.echo("Initialization cancelled.")
            sys.exit(0)

    if not config_manager.validate_musicbrainz_key(musicbrainz_key):
        click.echo("\n❌ Error: MusicBrainz API key appears invalid.", err=True)
        click.echo("Get a valid key at: https://musicbrainz.org/account/applications", err=True)
        sys.exit(1)

    music_dir.mkdir(parents=True, exist_ok=True)
    config_manager.init_database()

    config = Config(
        musicbrainz_api_key=musicbrainz_key,
        music_directory=music_dir,
        jackett_url=jackett_url if jackett_url else None,
        jackett_api_key=jackett_key if jackett_key else None,
    )
    config_manager.save_config(config)

    click.echo(f"\n✅ Configuration saved to: {config_manager.config_dir}")
    click.echo(f"   User ID: {config.user_id}")
    click.echo(f"   Music directory: {config.music_directory}")
    click.echo("\n🎉 Setup complete! Try: karma-player search <artist> <song>")


@cli.command()
def stats():
    """Display download and seeding statistics."""
    click.echo("Statistics:")
    click.echo("  Total downloads: 0")
    click.echo("  Currently seeding: 0")
    click.echo("  Total uploaded: 0 bytes")
    click.echo("  Votes cast: 0")
    click.echo("  Karma: 0")


@cli.command()
def seeding():
    """Show currently seeding torrents."""
    click.echo("Currently seeding: 0 torrents")
    click.echo("Seeding functionality will be implemented in Epic 6")


@cli.command()
def votes():
    """View vote history."""
    click.echo("Vote history:")
    click.echo("No votes yet. Download and rate some music!")


@cli.command()
@click.argument("action", type=click.Choice(["show"]))
@click.pass_context
def config(ctx, action):
    """Manage configuration."""
    config_manager: ConfigManager = ctx.obj["config_manager"]

    if action == "show":
        if not config_manager.is_initialized():
            click.echo("❌ Configuration not initialized.")
            click.echo("   Run: karma-player init")
            sys.exit(1)

        try:
            cfg = config_manager.load_config()
            click.echo("\n📋 Configuration:")
            click.echo(f"   Config directory: {config_manager.config_dir}")
            click.echo(f"   User ID: {cfg.user_id}")
            click.echo(
                f"   MusicBrainz API key: {'*' * 8}{cfg.musicbrainz_api_key[-4:] if cfg.musicbrainz_api_key else 'NOT SET'}"
            )
            click.echo(f"   Music directory: {cfg.music_directory}")
            click.echo(
                f"   Music directory exists: {'✅' if cfg.music_directory.exists() else '❌'}"
            )
            if cfg.jackett_url:
                click.echo(f"   Jackett URL: {cfg.jackett_url}")
                click.echo(
                    f"   Jackett API key: {'*' * 8}{cfg.jackett_api_key[-4:] if cfg.jackett_api_key else 'NOT SET'}"
                )
        except Exception as e:
            click.echo(f"❌ Error loading configuration: {e}", err=True)
            sys.exit(1)


if __name__ == "__main__":
    cli()
