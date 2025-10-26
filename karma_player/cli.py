"""
Modern CLI for karma-player
Outputs JSON events for Electron app integration
"""
import asyncio
import json
import os
import sys
from typing import Optional

import click

from karma_player import __version__, __app_name__
from karma_player.services.simple_search import SimpleSearch
from karma_player.services.search.engine import SearchEngine
from karma_player.services.search.adapter_jackett import AdapterJackett

# Store real stdout for JSON events
_REAL_STDOUT = sys.stdout


def emit_event(event_type: str, **data):
    """Emit JSON event to stdout for Electron consumption"""
    event = {"type": event_type, **data}
    _REAL_STDOUT.write(json.dumps(event) + '\n')
    _REAL_STDOUT.flush()


def redirect_output():
    """Redirect prints to stderr to keep stdout clean for JSON"""
    sys.stdout = sys.stderr


@click.group()
@click.version_option(version=__version__, prog_name=__app_name__)
def cli():
    """karma-player - AI-powered music torrent search"""
    pass


@cli.command()
@click.argument("query")
@click.option("--format", "-f", "format_filter", help="Format filter (FLAC, MP3, etc.)")
@click.option("--min-seeders", "-s", default=1, help="Minimum seeders (default: 1)")
@click.option("--limit", "-l", default=50, help="Max results (default: 50)")
@click.option("--profile", "-p", default="remote", help="Indexer profile (default: remote)")
@click.option("--output-json-events", is_flag=True, help="Output JSON events for Electron/GUI")
def search(
    query: str,
    format_filter: Optional[str],
    min_seeders: int,
    limit: int,
    profile: str,
    output_json_events: bool
):
    """
    Search for music torrents

    Examples:
        karma-player search "pink floyd"
        karma-player search "radiohead ok computer" --format FLAC
        karma-player search "miles davis" --output-json-events
    """
    asyncio.run(_search(
        query=query,
        format_filter=format_filter,
        min_seeders=min_seeders,
        limit=limit,
        profile=profile,
        json_output=output_json_events
    ))


async def _search(
    query: str,
    format_filter: Optional[str],
    min_seeders: int,
    limit: int,
    profile: str,
    json_output: bool
):
    """Execute search"""

    if json_output:
        redirect_output()
        emit_event("start", query=query)

    try:
        # Setup Jackett adapter
        jackett_url = os.getenv(
            "JACKETT_REMOTE_URL",
            "https://trust-tune-trust-tune-jack.62ickh.easypanel.host"
        )
        jackett_api_key = os.getenv(
            "JACKETT_REMOTE_API_KEY",
            "ugokmbv2cfeghwcsm27mtnjva5ch7948"
        )

        jackett = AdapterJackett(
            base_url=jackett_url,
            api_key=jackett_api_key,
            indexer_id="all"
        )

        # Create search engine and simple search
        engine = SearchEngine(adapters=[jackett])
        search_service = SimpleSearch(engine)

        # Progress callback
        def progress_callback(percent: int, message: str):
            if json_output:
                emit_event("progress", percent=percent, message=message)
            else:
                print(f"[{percent:3d}%] {message}")

        # Execute search
        result = await search_service.search(
            query=query,
            format_filter=format_filter,
            min_seeders=min_seeders,
            limit=limit,
            progress_callback=progress_callback
        )

        # Output results
        if json_output:
            # Emit result event
            results_data = []
            for ranked in result.results:
                t = ranked.torrent
                results_data.append({
                    "rank": ranked.rank,
                    "title": t.title,
                    "magnet_link": t.magnet_link,
                    "size_bytes": t.size_bytes,
                    "size_formatted": t.size_formatted,
                    "seeders": t.seeders,
                    "leechers": t.leechers,
                    "format": t.format,
                    "bitrate": t.bitrate,
                    "source": t.source,
                    "quality_score": t.quality_score,
                    "indexer": t.indexer,
                    "explanation": ranked.explanation,
                    "tags": ranked.tags
                })

            emit_event(
                "result",
                query=result.query,
                sql_query=result.sql_query,
                total_found=result.total_found,
                search_time_ms=result.search_time_ms,
                results=results_data
            )
            emit_event("complete")
        else:
            # Human-readable output
            print()
            print(f"✅ Found {result.total_found} results in {result.search_time_ms}ms")
            print()

            if result.sql_query and result.sql_query != query:
                print(f"SQL: {result.sql_query}")
                print()

            if result.results:
                print("Top results:")
                print()
                for ranked in result.results[:10]:
                    t = ranked.torrent
                    print(f"{ranked.rank}. {t.title[:75]}")
                    print(f"   {ranked.explanation}")
                    if ranked.tags:
                        print(f"   Tags: {', '.join(ranked.tags)}")
                    print()

    except Exception as e:
        if json_output:
            emit_event("error", message=str(e))
        else:
            print(f"❌ Error: {e}", file=sys.stderr)
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    cli()
