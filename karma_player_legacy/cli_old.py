"""CLI entry point for Karma Player."""

import os
import sys
from pathlib import Path

import click
from karma_player import __version__
from karma_player.config import ConfigManager, Config
from karma_player.splash import show_splash


@click.group()
@click.version_option(version=__version__, prog_name="karma-player")
@click.pass_context
def cli(ctx):
    """Karma Player - AI-powered music search with community verification.

    A CLI tool that helps you discover and download high-quality music
    through community-validated torrents.
    """
    ctx.ensure_object(dict)
    ctx.obj["config_manager"] = ConfigManager()

    # Store flag to show splash before first command
    ctx.obj["show_splash"] = os.environ.get("KARMA_PLAYER_NO_SPLASH") != "1"


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
    help="Jackett server URL (e.g., http://localhost:9117)",
)
@click.option(
    "--jackett-key",
    default="",
    prompt="Jackett API key (optional, press Enter to skip)",
    help="Jackett API key",
)
@click.pass_context
def init(ctx, musicbrainz_key: str, music_dir: Path, jackett_url: str, jackett_key: str):
    """Initialize Karma Player configuration.

    Creates ~/.karma-player/ directory and prompts for required settings:
    - MusicBrainz API key
    - Music directory path
    """
    config_manager: ConfigManager = ctx.obj["config_manager"]

    click.echo("\n🎵 Initializing Karma Player configuration...")

    # Check if already initialized
    if config_manager.is_initialized():
        if not click.confirm(
            "\nConfiguration already exists. Overwrite?", default=False
        ):
            click.echo("Initialization cancelled.")
            sys.exit(0)

    # Validate API key
    if not config_manager.validate_musicbrainz_key(musicbrainz_key):
        click.echo(
            "\n❌ Error: MusicBrainz API key appears invalid (too short or empty).",
            err=True,
        )
        click.echo(
            "Get a valid key at: https://musicbrainz.org/account/applications",
            err=True,
        )
        sys.exit(1)

    # Create music directory if it doesn't exist
    music_dir.mkdir(parents=True, exist_ok=True)

    # Initialize database
    config_manager.init_database()

    # Save configuration
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
    click.echo(
        "\n🎉 Setup complete! Try: karma-player search <artist> <song>"
    )


@cli.command()
@click.argument("query", nargs=-1, required=True)
@click.option(
    "--artist",
    "-a",
    help="Filter by artist name",
)
@click.option(
    "--limit",
    "-l",
    default=10,
    type=int,
    help="Maximum number of MusicBrainz results (default: 10)",
)
@click.option(
    "--format",
    "-f",
    help="Filter torrents by format (FLAC, MP3, etc.)",
)
@click.option(
    "--min-seeders",
    type=int,
    default=5,
    help="Minimum number of seeders (default: 5)",
)
@click.option(
    "--page-size",
    type=int,
    default=None,
    help="Number of torrents per page (default: auto-detect from terminal height)",
)
@click.option(
    "--skip-musicbrainz",
    is_flag=True,
    help="Skip MusicBrainz search and go directly to torrents",
)
@click.option(
    "--profile",
    "-p",
    help="Indexer profile to use (default: from YAML config)",
)
@click.pass_context
def search(ctx, query, artist, limit, format, min_seeders, page_size, skip_musicbrainz, profile):
    """Search for music and find torrents.

    Example: karma-player search paranoid android -a radiohead
    Example: karma-player search beatles yesterday --format FLAC
    """
    # Show splash screen if enabled
    if ctx.obj.get("show_splash", False):
        show_splash()
        ctx.obj["show_splash"] = False  # Only show once

    import asyncio
    from karma_player.musicbrainz import MusicBrainzClient, MusicBrainzError
    from karma_player.selection import SelectionInterface
    from karma_player.torrent.search_engine import SearchEngine
    from karma_player.torrent.adapters.adapter_1337x import Adapter1337x
    from karma_player.torrent.adapters.adapter_jackett import AdapterJackett
    from karma_player.torrent.display import ResultDisplay
    from karma_player.indexer_config import IndexerConfigLoader

    config_manager: ConfigManager = ctx.obj["config_manager"]

    # Check if initialized
    if not config_manager.is_initialized():
        click.echo("❌ Configuration not initialized.", err=True)
        click.echo("   Run: karma-player init", err=True)
        sys.exit(1)

    query_str = " ".join(query)

    try:
        # Step 1: MusicBrainz search (optional)
        selected_mb = None
        torrent_query = query_str

        if not skip_musicbrainz:
            # Step 1a: Search MusicBrainz
            click.echo(f"\n🔍 Searching MusicBrainz for: {query_str}")
            if artist:
                click.echo(f"   Artist filter: {artist}")

            mb_client = MusicBrainzClient()
            mb_results = mb_client.search_recordings(query_str, limit=limit, artist=artist)

            if not mb_results:
                click.echo("\n❌ No MusicBrainz results found.")
                click.echo("   Try a different query or remove artist filter.")
                sys.exit(0)

            # Step 1b: Let user select recording
            click.echo(f"\n📀 Found {len(mb_results)} recordings:\n")
            for i, result in enumerate(mb_results, 1):
                click.echo(f"[{i}] {result}")
                click.echo(f"    MBID: {result.mbid}")
                click.echo()

            selection_ui = SelectionInterface()

            def format_mb_result(r):
                return f"{r.artist} - {r.title} ({r.album or 'Unknown Album'})"

            selected_mb = selection_ui.prompt_selection(
                mb_results,
                prompt_text="Select a recording to find torrents",
                display_fn=format_mb_result,
            )

            if not selected_mb:
                click.echo("\n❌ Selection cancelled.")
                sys.exit(0)

            # Build torrent search query from MusicBrainz result
            torrent_query = f"{selected_mb.artist} {selected_mb.title}"
            if selected_mb.album:
                torrent_query += f" {selected_mb.album}"

            # Step 1c: Confirm search query with user
            click.echo(f"\n📝 Torrent search query: '{torrent_query}'")
            if not click.confirm("   Search with this query?", default=True):
                custom_query = click.prompt("   Enter your search query", default=torrent_query)
                torrent_query = custom_query.strip()
                click.echo(f"\n✓ Using query: '{torrent_query}'")
        else:
            # Skip MusicBrainz - use query directly for torrent search
            click.echo(f"\n⚡ Skipping MusicBrainz, searching torrents directly...")
            torrent_query = query_str

        while True:  # Allow retry loop
            if selected_mb:
                click.echo(f"\n🔎 Searching torrents for: {selected_mb.artist} - {selected_mb.title}")
                if selected_mb.album:
                    click.echo(f"   Album: {selected_mb.album}")
            else:
                click.echo(f"\n🔎 Searching torrents...")

            click.echo(f"   Query: '{torrent_query}'")
            click.echo(f"   Format filter: {format or 'Any'}")
            click.echo(f"   Min seeders: {min_seeders}")
            click.echo(f"   MusicBrainz limit: {limit}")

            # Initialize adapters from YAML configuration
            cfg = config_manager.load_config()
            adapters = []

            try:
                # Load indexer configuration from YAML
                loader = IndexerConfigLoader()

                # Build context for variable substitution (e.g., ${JACKETT_API_KEY})
                context = {}
                if cfg.jackett_api_key:
                    context['JACKETT_API_KEY'] = cfg.jackett_api_key

                # Get profile configuration (use --profile option or default from YAML)
                profile_config = loader.get_profile(profile_name=profile, context=context)

                # Show which profile is being used
                profile_display = profile or loader.get_default_profile()
                click.echo(f"   Profile: {profile_display}")

                # Build adapters from profile
                for idx_config in profile_config.indexers:
                    if not idx_config.enabled:
                        continue

                    if idx_config.type == 'jackett':
                        adapter = AdapterJackett(
                            base_url=idx_config.base_url,
                            api_key=idx_config.api_key,
                            indexer_id=idx_config.indexer_id,
                            categories=idx_config.categories,
                        )
                        # Set timeout from config
                        adapter.timeout = idx_config.timeout
                        adapters.append(adapter)
                    elif idx_config.type == '1337x':
                        adapters.append(Adapter1337x())

                # If no adapters enabled in profile, fall back to old behavior
                if not adapters:
                    if cfg.jackett_url and cfg.jackett_api_key:
                        adapters.append(
                            AdapterJackett(
                                base_url=cfg.jackett_url,
                                api_key=cfg.jackett_api_key,
                                indexer_id="all",
                            )
                        )
                    adapters.append(Adapter1337x())

            except (FileNotFoundError, ValueError) as e:
                # YAML config not found or invalid profile - fall back to old behavior
                click.echo(f"⚠️  YAML config issue: {e}")
                click.echo("   Falling back to database configuration...")

                if cfg.jackett_url and cfg.jackett_api_key:
                    adapters.append(
                        AdapterJackett(
                            base_url=cfg.jackett_url,
                            api_key=cfg.jackett_api_key,
                            indexer_id="all",
                        )
                    )
                adapters.append(Adapter1337x())

            # Show which indexers will be queried
            click.echo(f"\n⏳ Querying indexers:")
            for adapter in adapters:
                status = "✓" if adapter.is_healthy else "✗"
                click.echo(f"   {status} {adapter.name}")

            # Initialize search engine
            search_engine = SearchEngine(adapters=adapters)

            # Run async search with progress indicator
            with click.progressbar(
                length=100,
                label="   Searching",
                show_percent=False,
                show_pos=False,
                bar_template="%(label)s %(bar)s",
                fill_char="█",
                empty_char="░"
            ) as bar:
                # Start search
                import threading
                result_container = []

                def run_search():
                    result = asyncio.run(
                        search_engine.search(
                            torrent_query,
                            format_filter=format,
                            min_seeders=min_seeders,
                        )
                    )
                    result_container.append(result)

                search_thread = threading.Thread(target=run_search)
                search_thread.start()

                # Animate progress bar
                import time
                start_time = time.time()
                max_duration = 10  # seconds

                while search_thread.is_alive():
                    elapsed = time.time() - start_time
                    if elapsed >= max_duration:
                        break

                    # Update progress based on elapsed time
                    progress = min(int((elapsed / max_duration) * 100), 99)
                    current_progress = bar.pos or 0
                    if progress > current_progress:
                        bar.update(progress - current_progress)

                    time.sleep(0.1)

                # Wait for search to complete
                search_thread.join()  # Wait indefinitely for search to finish

                # Complete the bar when search finishes
                if bar.pos < 100:
                    bar.update(100 - (bar.pos or 0))

                torrent_results = result_container[0] if result_container else []

            if not torrent_results:
                click.echo("\n❌ No torrents found.")
                click.echo(f"   Searched for: '{torrent_query}'")
                if min_seeders > 0:
                    click.echo(f"   (with {min_seeders}+ seeders)")
                if format:
                    click.echo(f"   (format: {format})")

                # Offer options
                click.echo("\n💡 Options:")
                option_num = 1
                option_actions = {}

                # Always show custom query option first (most useful)
                click.echo(f"   [{option_num}] Change search query (current: '{torrent_query}')")
                option_actions[str(option_num)] = "custom_query"
                option_num += 1

                # Build dynamic option menu
                if format:
                    click.echo(f"   [{option_num}] Remove --format {format} filter")
                    option_actions[str(option_num)] = "remove_format"
                    option_num += 1

                if min_seeders > 0:
                    click.echo(f"   [{option_num}] Change --min-seeders (currently {min_seeders})")
                    option_actions[str(option_num)] = "change_seeders"
                    option_num += 1

                click.echo(f"   [{option_num}] Try different MusicBrainz recording")
                option_actions[str(option_num)] = "change_recording"

                click.echo(f"   [q] Quit")

                choice = click.prompt("\nSelect option", type=str, default="q").strip().lower()

                if choice == "q" or choice == "quit":
                    sys.exit(0)

                action = option_actions.get(choice)

                if action == "remove_format":
                    format = None
                    click.echo("\n✓ Removed format filter")
                    continue  # Retry search
                elif action == "change_seeders":
                    new_seeders = click.prompt(
                        f"\n🔢 Enter minimum seeders (0 for no minimum)",
                        type=int,
                        default=0
                    )
                    if new_seeders >= 0:
                        min_seeders = new_seeders
                        click.echo(f"\n✓ Set min seeders to {min_seeders}")
                        continue  # Retry search
                    else:
                        click.echo("\n❌ Invalid value, keeping original.")
                        continue
                elif action == "change_recording":
                    # Go back to MusicBrainz selection
                    selected_mb = selection_ui.prompt_selection(
                        mb_results,
                        prompt_text="Select a different recording to find torrents",
                        display_fn=format_mb_result,
                    )
                    if not selected_mb:
                        click.echo("\n❌ Selection cancelled.")
                        sys.exit(0)
                    continue  # Retry search with new recording
                elif action == "custom_query":
                    # Allow custom search query
                    custom_query = click.prompt("\n🔍 Enter new search query", default=torrent_query)
                    if custom_query.strip():
                        torrent_query = custom_query.strip()
                        click.echo(f"\n✓ Using query: '{torrent_query}'")
                        continue  # Retry search with custom query
                    else:
                        click.echo("\n❌ Empty query, keeping original.")
                        continue
                else:
                    click.echo("\n❌ Invalid option.")
                    sys.exit(0)

            # Found results - display and allow selection with retry
            click.echo(f"\n✅ Found {len(torrent_results)} torrents")

            # Step 4: Display torrent results with pagination
            display = ResultDisplay()

            # Auto-detect page size from terminal height if not specified
            if page_size is None:
                import shutil
                terminal_height = shutil.get_terminal_size().lines
                # Reserve space for: header (3), page info (4), prompt (5) = 12 lines
                # Each result takes ~1-2 lines depending on title wrap
                page_size = max(10, terminal_height - 12)

            display.show_results(torrent_results, page_size=page_size)

            # Step 5: Let user select torrent (with retry option)
            selected_torrent = display.prompt_selection(torrent_results, allow_retry=True)

            # Handle retry request
            if selected_torrent == "RETRY":
                custom_query = click.prompt("\n🔍 Enter new search query", default=torrent_query)
                torrent_query = custom_query.strip()
                click.echo(f"\n✓ Using query: '{torrent_query}'")
                continue  # Go back to search with new query

            if not selected_torrent:
                click.echo("\n❌ Selection cancelled.")
                sys.exit(0)

            # Got valid selection, break out of retry loop
            break

        # Step 6: Show selected torrent details
        click.echo(f"\n✅ Selected: {selected_torrent.title}")
        click.echo(f"   Format: {selected_torrent.format or 'Unknown'}")
        click.echo(f"   Size: {selected_torrent.size_formatted}")
        click.echo(f"   Seeders: {selected_torrent.seeders}")
        click.echo(f"   Indexer: {selected_torrent.indexer}")
        click.echo(f"\n🧲 Magnet link:")
        click.echo(f"   {selected_torrent.magnet_link}")
        click.echo(
            f"\n💡 Phase 0: Copy magnet link to download in your torrent client."
        )
        click.echo(f"    Phase 1: Automatic download via qBittorrent integration!")

        # Step 7: Ask if user wants to search again
        click.echo("\n")
        if click.confirm("🔍 Search for another song?", default=False):
            # Prompt for new search query
            new_query = click.prompt("\n🎵 Enter song/artist to search", type=str).strip()
            if new_query:
                # Recursively call search with new query
                ctx.invoke(search, query=tuple(new_query.split()), artist=None,
                          limit=limit, format=format, min_seeders=min_seeders,
                          page_size=page_size, skip_musicbrainz=skip_musicbrainz)
        else:
            click.echo("\n👋 Happy listening!")

    except MusicBrainzError as e:
        click.echo(f"\n❌ MusicBrainz error: {e}", err=True)
        sys.exit(1)
    except Exception as e:
        click.echo(f"\n❌ Unexpected error: {e}", err=True)
        import traceback
        traceback.print_exc()
        sys.exit(1)


@cli.command()
def stats():
    """Display your download and seeding statistics."""
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
    """View your vote history."""
    click.echo("Vote history:")
    click.echo("No votes yet. Download and rate some music!")


@cli.command()
@click.argument("action", type=click.Choice(["show"]))
@click.pass_context
def config(ctx, action):
    """Manage configuration.

    \b
    Actions:
      show    Display current configuration
    """
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
                click.echo(f"   Jackett API key: {'*' * 8}{cfg.jackett_api_key[-4:] if cfg.jackett_api_key else 'NOT SET'}")
        except Exception as e:
            click.echo(f"❌ Error loading configuration: {e}", err=True)
            sys.exit(1)


if __name__ == "__main__":
    cli()
