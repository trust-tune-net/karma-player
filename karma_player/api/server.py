"""
FastAPI server for karma_player
Provides HTTP/WebSocket API for Flutter GUI
"""
import os
import logging
from contextlib import asynccontextmanager
from typing import Optional, List

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from slowapi.errors import RateLimitExceeded
import json

from karma_player import __version__, __app_name__
from karma_player.services.simple_search import SimpleSearch
from karma_player.services.search.engine import SearchEngine
from karma_player.services.search.adapter_jackett import AdapterJackett
from karma_player.api.middleware import verify_api_key, verify_websocket_auth, log_request_middleware
from karma_player.api.rate_limit import limiter


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


# Global search instance
search_service: Optional[SimpleSearch] = None


# Lifespan context manager for startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle startup and shutdown events"""
    global search_service

    logger.info(f"Starting {__app_name__} v{__version__}")
    logger.info(f"API server running on port {os.getenv('PORT', 8765)}")

    # Initialize search infrastructure
    logger.info("Initializing search infrastructure...")

    # Jackett adapter
    # Support both JACKETT_REMOTE_URL and JACKETT_URL for backward compatibility
    jackett_url = os.getenv("JACKETT_REMOTE_URL") or os.getenv("JACKETT_URL")
    jackett_api_key = os.getenv("JACKETT_REMOTE_API_KEY") or os.getenv("JACKETT_API_KEY")

    if not jackett_url or not jackett_api_key:
        logger.error("Jackett configuration missing. Set JACKETT_REMOTE_URL (or JACKETT_URL) and JACKETT_REMOTE_API_KEY (or JACKETT_API_KEY)")
        raise RuntimeError("Missing required Jackett configuration. Please set JACKETT_REMOTE_URL and JACKETT_REMOTE_API_KEY (or JACKETT_URL and JACKETT_API_KEY) environment variables.")

    jackett = AdapterJackett(
        base_url=jackett_url,
        api_key=jackett_api_key,
        indexer_id="all"
    )

    # YouTube Music streaming adapter
    from karma_player.services.search.adapter_youtube_music import AdapterYouTubeMusic
    youtube_music = AdapterYouTubeMusic()

    # Search engine with both torrent and streaming sources
    search_engine = SearchEngine(adapters=[jackett, youtube_music])

    # Simple search service
    search_service = SimpleSearch(search_engine)

    logger.info("✅ Search infrastructure ready!")

    yield

    # Cleanup on shutdown
    logger.info("Shutting down...")
    search_service = None


# Create FastAPI app
app = FastAPI(
    title="karma_player API",
    description="AI-powered music search and download service",
    version=__version__,
    lifespan=lifespan
)

# Add CORS middleware (allow Flutter desktop app)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Flutter desktop runs on random ports
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add request logging middleware
app.middleware("http")(log_request_middleware)

# Add rate limiter to app state
app.state.limiter = limiter

# Add exception handler for rate limit exceeded
from slowapi import _rate_limit_exceeded_handler
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


# Request/Response models
class SearchRequest(BaseModel):
    query: str
    format_filter: Optional[str] = None
    min_seeders: int = 1
    limit: int = 20
    offset: int = 0  # For pagination


class TorrentInfo(BaseModel):
    title: str
    magnet_link: str
    size_bytes: int
    size_formatted: str
    seeders: int
    leechers: int
    format: Optional[str]
    bitrate: Optional[str]
    source: Optional[str]
    quality_score: float
    indexer: str


class RankedTorrent(BaseModel):
    rank: int
    torrent: TorrentInfo
    explanation: str
    tags: List[str]


class SearchResponse(BaseModel):
    query: str
    sql_query: Optional[str]
    total_found: int
    search_time_ms: int
    results: List[RankedTorrent]


class HealthResponse(BaseModel):
    status: str
    version: str
    search_ready: bool


# Routes
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="ok",
        version=__version__,
        search_ready=search_service is not None
    )


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "name": __app_name__,
        "version": __version__,
        "status": "running",
        "search_ready": search_service is not None
    }


@app.post("/api/search", response_model=SearchResponse)
@limiter.limit("100/hour")  # Limit to 100 searches per hour per device
async def search(req: Request, request: SearchRequest, device_id: str = Depends(verify_api_key)):
    """
    Execute music search

    Requires authentication via X-Device-ID and X-API-Key headers.
    Rate limit: 100 requests per hour per device.

    Args:
        req: FastAPI Request (for rate limiting)
        request: SearchRequest with query and filters
        device_id: Authenticated device ID (from dependency)

    Returns:
        SearchResponse with ranked results
    """
    if not search_service:
        raise HTTPException(status_code=503, detail="Search service not initialized")

    logger.info(f"Search request: {request.query}")

    try:
        # Execute search
        result = await search_service.search(
            query=request.query,
            format_filter=request.format_filter,
            min_seeders=request.min_seeders,
            limit=request.limit
        )

        # Convert to response model
        ranked_torrents = []
        for ranked in result.results:
            t = ranked.torrent
            ranked_torrents.append(
                RankedTorrent(
                    rank=ranked.rank,
                    torrent=TorrentInfo(
                        title=t.title,
                        magnet_link=t.magnet_link,
                        size_bytes=t.size_bytes,
                        size_formatted=t.size_formatted,
                        seeders=t.seeders,
                        leechers=t.leechers,
                        format=t.format,
                        bitrate=t.bitrate,
                        source=t.source,
                        quality_score=t.quality_score,
                        indexer=t.indexer
                    ),
                    explanation=ranked.explanation,
                    tags=ranked.tags
                )
            )

        return SearchResponse(
            query=result.query,
            sql_query=result.sql_query,
            total_found=result.total_found,
            search_time_ms=result.search_time_ms,
            results=ranked_torrents
        )

    except Exception as e:
        logger.error(f"Search error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.websocket("/ws/search")
async def websocket_search(websocket: WebSocket):
    """
    WebSocket endpoint for real-time search with progress updates

    Client sends: {
        "auth": {"device_id": "...", "api_key": "..."},
        "query": "artist name",
        "format_filter": "FLAC",
        "min_seeders": 1,
        "limit": 50
    }
    Server sends:
        - Progress: {"type": "progress", "percent": 50, "message": "Searching..."}
        - Result: {"type": "result", "data": {...}}
        - Error: {"type": "error", "message": "..."}
    """
    await websocket.accept()
    logger.info("WebSocket connection established")

    try:
        # Receive search request
        data = await websocket.receive_text()
        request_data = json.loads(data)

        # Validate authentication
        auth_data = request_data.get("auth")
        if not auth_data:
            await websocket.send_json({
                "type": "error",
                "message": "Authentication required"
            })
            return

        try:
            device_id = verify_websocket_auth(auth_data)
            logger.debug(f"WebSocket authenticated: device {device_id[:8]}...")
        except ValueError as e:
            logger.warning(f"WebSocket authentication failed: {e}")
            await websocket.send_json({
                "type": "error",
                "message": f"Authentication failed: {e}"
            })
            return

        query = request_data.get("query")
        format_filter = request_data.get("format_filter")
        min_seeders = request_data.get("min_seeders", 1)
        limit = request_data.get("limit", 20)
        offset = request_data.get("offset", 0)

        if not query:
            await websocket.send_json({
                "type": "error",
                "message": "Query is required"
            })
            return

        logger.info(f"🔍 WebSocket search: '{query}' (offset={offset}, limit={limit}, min_seeders={min_seeders})")

        # Progress callback
        async def send_progress(percent: int, message: str):
            await websocket.send_json({
                "type": "progress",
                "percent": percent,
                "message": message
            })

        # Partial result callback - send results as each adapter completes
        async def send_partial_results(adapter_name: str, sources: List):
            # Limit partial results to the requested limit
            limited_sources = sources[:limit]

            # Determine source type
            source_type = "unknown"
            if limited_sources:
                source_type = limited_sources[0].source_type.value

            logger.info(f"   📦 {adapter_name}: Sending {len(limited_sources)} {source_type} results (filtered from {len(sources)} total)")

            # Build ranked results for this adapter
            partial_results = []
            for i, source in enumerate(limited_sources, 1):
                partial_results.append({
                    "rank": i,  # Temporary rank, will be re-ranked in final result
                    "source": {
                        "id": source.id,
                        "title": source.title,
                        "url": source.url,
                        "source_type": source.source_type.value,
                        "format": source.format,
                        "quality_score": source.quality_score,
                        "indexer": source.indexer,
                        # Torrent-specific
                        "magnet_link": source.magnet_link,
                        "size_bytes": source.size_bytes,
                        "size_formatted": source.size_formatted if source.size_bytes else None,
                        "seeders": source.seeders,
                        "leechers": source.leechers,
                        # Streaming-specific
                        "codec": source.codec,
                        "bitrate": source.bitrate,
                        "thumbnail_url": source.thumbnail_url,
                        "duration_seconds": source.duration_seconds
                    },
                    "explanation": f"{source.format or 'Unknown'} • {source.indexer}",
                    "tags": []
                })

            await websocket.send_json({
                "type": "partial_result",
                "adapter": adapter_name,
                "count": len(partial_results),
                "results": partial_results
            })

        # Execute search with progress and partial result updates
        result = await search_service.search(
            query=query,
            format_filter=format_filter,
            min_seeders=min_seeders,
            limit=limit,
            offset=offset,
            use_ai_parsing=False,
            progress_callback=send_progress,
            partial_result_callback=send_partial_results
        )

        # Convert to response format
        ranked_torrents = []
        for ranked in result.results:
            s = ranked.source  # MusicSource object (FIXED: was ranked.torrent)
            ranked_torrents.append({
                "rank": ranked.rank,
                "source": {
                    "id": s.id,
                    "title": s.title,
                    "url": s.url,
                    "source_type": s.source_type.value,
                    "format": s.format,
                    "quality_score": s.quality_score,
                    "indexer": s.indexer,
                    # Torrent-specific
                    "magnet_link": s.magnet_link,
                    "size_bytes": s.size_bytes,
                    "size_formatted": s.size_formatted if s.size_bytes else None,
                    "seeders": s.seeders,
                    "leechers": s.leechers,
                    # Streaming-specific
                    "codec": s.codec,
                    "bitrate": s.bitrate,
                    "thumbnail_url": s.thumbnail_url,
                    "duration_seconds": s.duration_seconds
                },
                "explanation": ranked.explanation,
                "tags": ranked.tags
            })

        # Count by source type
        streaming_count = sum(1 for r in ranked_torrents if r["source"]["source_type"] in ["youtube", "piped", "invidious"])
        torrent_count = sum(1 for r in ranked_torrents if r["source"]["source_type"] == "torrent")

        # Send final result
        await websocket.send_json({
            "type": "complete",
            "total_found": result.total_found,
            "search_time_ms": result.search_time_ms,
            "results": ranked_torrents
        })

        logger.info(f"   ✅ Search complete: {len(ranked_torrents)} results ({streaming_count} streaming, {torrent_count} torrents) in {result.search_time_ms}ms")

    except WebSocketDisconnect:
        logger.info("WebSocket disconnected")
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON: {e}")
        try:
            await websocket.send_json({
                "type": "error",
                "message": "Invalid JSON format"
            })
        except RuntimeError:
            pass  # Connection already closed
    except Exception as e:
        logger.error(f"WebSocket search error: {e}", exc_info=True)
        try:
            await websocket.send_json({
                "type": "error",
                "message": str(e)
            })
        except RuntimeError:
            pass  # Connection already closed
    finally:
        try:
            await websocket.close()
        except RuntimeError:
            pass  # Connection already closed


# Run server (for development)
if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8765))

    uvicorn.run(
        "karma_player.api.server:app",
        host="127.0.0.1",
        port=port,
        reload=True,
        log_level="info"
    )
