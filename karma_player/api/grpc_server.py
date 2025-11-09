"""
gRPC server for TrustTune

Provides SearchService via gRPC with streaming results.
Runs alongside FastAPI on a different port (50051).
"""
import os
import logging
import asyncio
from typing import Optional, List
import grpc
from grpc import aio

from karma_player import __version__, __app_name__
from karma_player.proto import search_pb2, search_pb2_grpc, auth_pb2_grpc
from karma_player.api.auth import validate_api_key, validate_device_id_format
from karma_player.api.auth_service import AuthServicer
from karma_player.services.simple_search import SimpleSearch
from karma_player.services.search.engine import SearchEngine
from karma_player.services.search.adapter_jackett import AdapterJackett
from karma_player.services.search.adapter_youtube_music import AdapterYouTubeMusic

logger = logging.getLogger(__name__)

# Global search instance (shared with FastAPI)
_search_service: Optional[SimpleSearch] = None


def set_search_service(service: SimpleSearch):
    """Set the shared search service instance"""
    global _search_service
    _search_service = service


class AuthInterceptor(aio.ServerInterceptor):
    """
    gRPC authentication interceptor.

    Validates device_id and api_key from call metadata.
    Rejects unauthenticated requests with UNAUTHENTICATED status.
    """

    async def intercept_service(self, continuation, handler_call_details):
        """Intercept RPC calls to validate authentication"""
        # Skip auth for reflection service
        method = handler_call_details.method
        if method.startswith('/grpc.reflection'):
            return await continuation(handler_call_details)

        # Extract metadata
        metadata = dict(handler_call_details.invocation_metadata)
        device_id = metadata.get('device_id')
        api_key = metadata.get('api_key')

        # Validate presence
        if not device_id or not api_key:
            logger.warning(f"gRPC auth failed: missing credentials for {method}")
            return self._create_abort_handler(
                grpc.StatusCode.UNAUTHENTICATED,
                "Missing device_id or api_key in metadata"
            )

        # Validate device ID format
        if not validate_device_id_format(device_id):
            logger.warning(f"gRPC auth failed: invalid device_id format")
            return self._create_abort_handler(
                grpc.StatusCode.UNAUTHENTICATED,
                "Invalid device ID format"
            )

        # Validate API key
        if not validate_api_key(device_id, api_key):
            logger.warning(f"gRPC auth failed: invalid API key for {device_id[:8]}...")
            return self._create_abort_handler(
                grpc.StatusCode.UNAUTHENTICATED,
                "Invalid API key"
            )

        logger.debug(f"gRPC auth successful: {device_id[:8]}...")
        return await continuation(handler_call_details)

    def _create_abort_handler(self, status_code, details):
        """Create a handler that aborts the RPC with the given status"""
        async def abort_handler(request, context):
            await context.abort(status_code, details)

        return grpc.unary_unary_rpc_method_handler(abort_handler)


class SearchServiceServicer(search_pb2_grpc.SearchServiceServicer):
    """
    Implementation of SearchService gRPC service.

    Provides streaming search results from multiple adapters.
    """

    async def Search(
        self,
        request: search_pb2.SearchRequest,
        context: grpc.aio.ServicerContext
    ) -> search_pb2.SearchResponse:
        """
        Stream search results to client.

        Sends:
        1. Progress updates as search progresses
        2. Partial results as each adapter completes
        3. Final complete result with all ranked sources
        """
        if not _search_service:
            await context.abort(
                grpc.StatusCode.UNAVAILABLE,
                "Search service not initialized"
            )
            return

        logger.info(f"gRPC search: '{request.query}'")

        try:
            # Progress callback - send progress updates to client
            async def send_progress(percent: int, message: str):
                response = search_pb2.SearchResponse(
                    type=search_pb2.RESPONSE_TYPE_PROGRESS,
                    progress=search_pb2.ProgressUpdate(
                        percent=percent,
                        message=message
                    )
                )
                await context.write(response)

            # Partial result callback - send results as each adapter completes
            async def send_partial_results(adapter_name: str, sources: List):
                # Convert MusicSource objects to protobuf
                pb_sources = []
                for source in sources[:request.limit]:
                    pb_source = search_pb2.MusicSource(
                        id=source.id,
                        title=source.title,
                        url=source.url,
                        source_type=_convert_source_type(source.source_type.value),
                        format=source.format or "",
                        quality_score=source.quality_score,
                        indexer=source.indexer,
                        # Torrent fields
                        magnet_link=source.magnet_link or "",
                        size_bytes=source.size_bytes or 0,
                        size_formatted=source.size_formatted if source.size_bytes else "",
                        seeders=source.seeders or 0,
                        leechers=source.leechers or 0,
                        # Streaming fields
                        codec=source.codec or "",
                        bitrate=source.bitrate or "",
                        thumbnail_url=source.thumbnail_url or "",
                        duration_seconds=source.duration_seconds or 0
                    )
                    pb_sources.append(pb_source)

                response = search_pb2.SearchResponse(
                    type=search_pb2.RESPONSE_TYPE_PARTIAL_RESULT,
                    partial_result=search_pb2.PartialResult(
                        adapter_name=adapter_name,
                        count=len(pb_sources),
                        sources=pb_sources
                    )
                )
                await context.write(response)

            # Map protobuf source_type_filter to string filter
            source_type_filter = None
            if request.HasField('source_type_filter'):
                if request.source_type_filter == search_pb2.SOURCE_TYPE_FILTER_TORRENT:
                    source_type_filter = "torrent"
                elif request.source_type_filter == search_pb2.SOURCE_TYPE_FILTER_STREAMING:
                    source_type_filter = "streaming"
                # SOURCE_TYPE_FILTER_ALL or unspecified = None (all sources)

            # Execute search
            result = await _search_service.search(
                query=request.query,
                format_filter=request.format_filter if request.HasField('format_filter') else None,
                min_seeders=request.min_seeders,
                limit=request.limit,
                offset=request.offset,
                use_ai_parsing=False,
                source_type_filter=source_type_filter,
                progress_callback=send_progress,
                partial_result_callback=send_partial_results
            )

            # Convert final results to protobuf
            ranked_sources = []
            for ranked in result.results:
                source = ranked.source
                pb_source = search_pb2.MusicSource(
                    id=source.id,
                    title=source.title,
                    url=source.url,
                    source_type=_convert_source_type(source.source_type.value),
                    format=source.format or "",
                    quality_score=source.quality_score,
                    indexer=source.indexer,
                    magnet_link=source.magnet_link or "",
                    size_bytes=source.size_bytes or 0,
                    size_formatted=source.size_formatted if source.size_bytes else "",
                    seeders=source.seeders or 0,
                    leechers=source.leechers or 0,
                    codec=source.codec or "",
                    bitrate=source.bitrate or "",
                    thumbnail_url=source.thumbnail_url or "",
                    duration_seconds=source.duration_seconds or 0
                )

                ranked_source = search_pb2.RankedSource(
                    rank=ranked.rank,
                    source=pb_source,
                    explanation=ranked.explanation,
                    tags=ranked.tags
                )
                ranked_sources.append(ranked_source)

            # Send final complete result
            response = search_pb2.SearchResponse(
                type=search_pb2.RESPONSE_TYPE_COMPLETE,
                complete_result=search_pb2.CompleteResult(
                    total_found=result.total_found,
                    search_time_ms=result.search_time_ms,
                    ranked_sources=ranked_sources
                )
            )
            await context.write(response)

            logger.info(f"gRPC search complete: {len(ranked_sources)} results in {result.search_time_ms}ms")

        except Exception as e:
            logger.error(f"gRPC search error: {e}", exc_info=True)
            response = search_pb2.SearchResponse(
                type=search_pb2.RESPONSE_TYPE_ERROR,
                error=search_pb2.Error(
                    code=search_pb2.STATUS_CODE_ERROR,
                    message=str(e)
                )
            )
            await context.write(response)

    async def GetSearchStats(
        self,
        request: search_pb2.SearchStatsRequest,
        context: grpc.aio.ServicerContext
    ) -> search_pb2.SearchStatsResponse:
        """Get search statistics (admin only - Phase 2)"""
        await context.abort(
            grpc.StatusCode.UNIMPLEMENTED,
            "GetSearchStats not implemented yet (Phase 2)"
        )
        return search_pb2.SearchStatsResponse()


def _convert_source_type(source_type_str: str) -> search_pb2.SourceType:
    """Convert string source type to protobuf enum"""
    type_map = {
        "torrent": search_pb2.SOURCE_TYPE_TORRENT,
        "youtube": search_pb2.SOURCE_TYPE_YOUTUBE,
        "piped": search_pb2.SOURCE_TYPE_PIPED,
        "invidious": search_pb2.SOURCE_TYPE_INVIDIOUS,
    }
    return type_map.get(source_type_str, search_pb2.SOURCE_TYPE_UNSPECIFIED)


async def serve_grpc(port: int = 50051):
    """
    Start gRPC server on specified port.

    Runs alongside FastAPI server (different port).
    Shares the same search_service instance.
    """
    server = aio.server(
        interceptors=[AuthInterceptor()],
        options=[
            ('grpc.max_send_message_length', 50 * 1024 * 1024),  # 50 MB
            ('grpc.max_receive_message_length', 50 * 1024 * 1024),
        ]
    )

    # Register services
    search_pb2_grpc.add_SearchServiceServicer_to_server(
        SearchServiceServicer(),
        server
    )
    auth_pb2_grpc.add_AuthServiceServicer_to_server(
        AuthServicer(),
        server
    )

    listen_addr = f'0.0.0.0:{port}'
    server.add_insecure_port(listen_addr)

    logger.info(f"Starting gRPC server on {listen_addr}")
    await server.start()
    logger.info(f"✅ gRPC server ready on port {port}")

    try:
        await server.wait_for_termination()
    except KeyboardInterrupt:
        logger.info("gRPC server shutting down...")
        await server.stop(grace=5)


if __name__ == "__main__":
    # Standalone gRPC server for testing
    import sys
    from karma_player.config import Config

    logging.basicConfig(
        level=getattr(logging, Config.LOG_LEVEL.upper(), logging.INFO),
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )

    # Initialize search infrastructure
    jackett_url = os.getenv("JACKETT_REMOTE_URL") or os.getenv("JACKETT_URL")
    jackett_api_key = os.getenv("JACKETT_REMOTE_API_KEY") or os.getenv("JACKETT_API_KEY")
    jackett_gui_url = os.getenv("JACKETT_REMOTE_GUI_URL")  # Optional: FQDN for GUI proxy URLs

    if not jackett_url or not jackett_api_key:
        logger.error("Missing Jackett configuration")
        sys.exit(1)

    jackett = AdapterJackett(
        base_url=jackett_url,
        api_key=jackett_api_key,
        indexer_id="all",
        gui_base_url=jackett_gui_url  # Use FQDN for proxy URL normalization
    )

    youtube_music = AdapterYouTubeMusic()
    search_engine = SearchEngine(adapters=[jackett, youtube_music])
    search_service = SimpleSearch(search_engine)

    set_search_service(search_service)

    port = int(os.getenv("GRPC_PORT", 50051))

    asyncio.run(serve_grpc(port))
