"""
Search API - Remote music search service
Can be deployed to cloud (Easypanel, etc.)
NO downloads, NO local file access - ONLY search
"""
import os
import logging
import json
from contextlib import asynccontextmanager
from typing import Optional, List

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from karma_player import __version__, __app_name__
from karma_player.config import config
from karma_player.services.simple_search import SimpleSearch
from karma_player.services.search.engine import SearchEngine
from karma_player.services.search.adapter_jackett import AdapterJackett
from karma_player.services.search.adapter_youtube_music import AdapterYouTubeMusic


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

    logger.info(f"Starting {__app_name__} Search API v{__version__}")
    logger.info(f"API server running on port {config.SEARCH_API_PORT}")

    # Initialize search infrastructure
    logger.info("Initializing search infrastructure...")

    # Jackett adapter from config
    jackett = AdapterJackett(
        base_url=config.JACKETT_URL,
        api_key=config.JACKETT_API_KEY,
        indexer_id=config.JACKETT_INDEXER
    )

    # YouTube Music streaming adapter
    # Search works fine from server (no bot detection)
    # URL resolution will be handled client-side (uses residential IP)
    youtube_music = AdapterYouTubeMusic()

    # Search engine with both torrent and streaming sources
    # Torrent: Jackett (remote)
    # YouTube: Search only (remote), URL resolution (client-side)
    search_engine = SearchEngine(adapters=[jackett, youtube_music])

    # Simple search service
    search_service = SimpleSearch(search_engine)

    logger.info("✅ Search infrastructure ready (Jackett + YouTube search, URL resolution client-side)!")

    yield

    # Cleanup on shutdown
    logger.info("Shutting down search API...")
    search_service = None


# Create FastAPI app
app = FastAPI(
    title="TrustTune Search API",
    description="AI-powered music search service",
    version=__version__,
    lifespan=lifespan
)

# Add CORS middleware (allow any origin for public API)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request/Response models
class SearchRequest(BaseModel):
    query: str
    format_filter: Optional[str] = None
    min_seeders: int = 1
    limit: int = 50


class MusicSourceInfo(BaseModel):
    """Music source information (torrent, stream, or local)"""
    id: str
    title: str
    url: str
    source_type: str  # "torrent", "youtube", "local", etc.
    format: Optional[str]
    quality_score: float
    indexer: str

    # Torrent-specific fields (optional)
    magnet_link: Optional[str] = None  # For backward compatibility
    size_bytes: Optional[int] = None
    size_formatted: Optional[str] = None
    seeders: Optional[int] = None
    leechers: Optional[int] = None

    # Streaming-specific fields (optional)
    codec: Optional[str] = None
    bitrate: Optional[str] = None
    thumbnail_url: Optional[str] = None
    duration_seconds: Optional[int] = None


class RankedSource(BaseModel):
    rank: int
    source: MusicSourceInfo
    explanation: str
    tags: List[str]


# Backward compatibility alias
class TorrentInfo(MusicSourceInfo):
    """Deprecated: Use MusicSourceInfo instead"""
    pass


class RankedTorrent(RankedSource):
    """Deprecated: Use RankedSource instead"""
    torrent: MusicSourceInfo = None  # Alias for source

    def __init__(self, **data):
        # Map 'torrent' field to 'source' for backward compatibility
        if 'torrent' in data and 'source' not in data:
            data['source'] = data.pop('torrent')
        elif 'source' in data and 'torrent' not in data:
            data['torrent'] = data['source']
        super().__init__(**data)


class SearchResponse(BaseModel):
    query: str
    sql_query: Optional[str]
    total_found: int
    search_time_ms: int
    results: List[RankedSource]


class HealthResponse(BaseModel):
    status: str
    version: str
    service: str
    search_ready: bool


# Routes
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="ok",
        version=__version__,
        service="search_api",
        search_ready=search_service is not None
    )


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "name": __app_name__,
        "version": __version__,
        "service": "search_api",
        "status": "running",
        "search_ready": search_service is not None
    }


@app.post("/api/search", response_model=SearchResponse)
async def search(request: SearchRequest):
    """
    Execute music search

    Args:
        request: SearchRequest with query and filters

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
        ranked_sources = []
        for ranked in result.results:
            s = ranked.source  # MusicSource object
            # Use the to_dict() method for proper serialization
            source_dict = s.to_dict()

            ranked_sources.append(
                RankedSource(
                    rank=ranked.rank,
                    source=MusicSourceInfo(
                        id=s.id,
                        title=s.title,
                        url=s.url,
                        source_type=s.source_type.value,
                        format=s.format,
                        quality_score=s.quality_score,
                        indexer=s.indexer,
                        # Torrent-specific
                        magnet_link=s.magnet_link,
                        size_bytes=s.size_bytes,
                        size_formatted=s.size_formatted if s.size_bytes else None,
                        seeders=s.seeders,
                        leechers=s.leechers,
                        # Streaming-specific
                        codec=s.codec,
                        bitrate=s.bitrate,
                        thumbnail_url=s.thumbnail_url,
                        duration_seconds=s.duration_seconds
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
            results=ranked_sources
        )

    except Exception as e:
        logger.error(f"Search error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


class ResolveRequest(BaseModel):
    """Request model for URL resolution"""
    video_id: str


class ResolveResponse(BaseModel):
    """Response model for URL resolution"""
    video_id: str
    stream_url: Optional[str]
    success: bool
    error: Optional[str] = None


@app.post("/api/resolve", response_model=ResolveResponse)
async def resolve_youtube_url(request: ResolveRequest):
    """
    Resolve YouTube Music video ID to playable stream URL

    This endpoint is called on-demand when user clicks "Stream",
    not during search (to avoid slow searches and bot detection)

    Args:
        request: ResolveRequest with video_id

    Returns:
        ResolveResponse with stream URL or error
    """
    logger.info(f"Resolving URL for video_id: {request.video_id}")

    try:
        # Get YouTube Music adapter from search engine
        youtube_adapter = None
        if search_service and search_service.search_engine:
            for adapter in search_service.search_engine.adapters:
                if isinstance(adapter, AdapterYouTubeMusic):
                    youtube_adapter = adapter
                    break

        if not youtube_adapter:
            return ResolveResponse(
                video_id=request.video_id,
                stream_url=None,
                success=False,
                error="YouTube Music adapter not available"
            )

        # Resolve URL using yt-dlp
        stream_url = await youtube_adapter._resolve_stream_url(request.video_id)

        if stream_url:
            logger.info(f"✅ Resolved {request.video_id} successfully")
            return ResolveResponse(
                video_id=request.video_id,
                stream_url=stream_url,
                success=True
            )
        else:
            logger.warning(f"⚠️  Failed to resolve {request.video_id}")
            return ResolveResponse(
                video_id=request.video_id,
                stream_url=None,
                success=False,
                error="Failed to resolve stream URL"
            )

    except Exception as e:
        logger.error(f"❌ Error resolving {request.video_id}: {e}")
        return ResolveResponse(
            video_id=request.video_id,
            stream_url=None,
            success=False,
            error=str(e)
        )


@app.websocket("/ws/search")
async def websocket_search(websocket: WebSocket):
    """
    WebSocket endpoint for real-time search with progress updates

    Client sends: {"query": "artist name", "format_filter": "FLAC", "min_seeders": 1, "limit": 50}
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

        query = request_data.get("query")
        format_filter = request_data.get("format_filter")
        min_seeders = request_data.get("min_seeders", 1)
        limit = request_data.get("limit", 50)

        if not query:
            await websocket.send_json({
                "type": "error",
                "message": "Query is required"
            })
            await websocket.close()
            return

        logger.info(f"WebSocket search request: {query}")

        # Progress callback
        async def send_progress(percent: int, message: str):
            await websocket.send_json({
                "type": "progress",
                "percent": percent,
                "message": message
            })

        # Execute search with progress updates
        result = await search_service.search(
            query=query,
            format_filter=format_filter,
            min_seeders=min_seeders,
            limit=limit,
            progress_callback=send_progress
        )

        # Convert to response format
        ranked_torrents = []
        for ranked in result.results:
            s = ranked.source  # MusicSource object
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
                # Backward compatibility: also include as "torrent"
                "torrent": {
                    "title": s.title,
                    "magnet_link": s.magnet_link,
                    "size_bytes": s.size_bytes,
                    "size_formatted": s.size_formatted if s.size_bytes else None,
                    "seeders": s.seeders,
                    "leechers": s.leechers,
                    "format": s.format,
                    "bitrate": s.bitrate,
                    "source": s.indexer,  # Legacy field mapping
                    "quality_score": s.quality_score,
                    "indexer": s.indexer
                },
                "explanation": ranked.explanation,
                "tags": ranked.tags
            })

        # Send final result
        await websocket.send_json({
            "type": "result",
            "data": {
                "query": result.query,
                "sql_query": result.sql_query,
                "total_found": result.total_found,
                "search_time_ms": result.search_time_ms,
                "results": ranked_torrents
            }
        })

        logger.info(f"WebSocket search completed: {result.total_found} results")

    except WebSocketDisconnect:
        logger.info("WebSocket disconnected")
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON: {e}")
        await websocket.send_json({
            "type": "error",
            "message": "Invalid JSON format"
        })
    except Exception as e:
        logger.error(f"WebSocket search error: {e}", exc_info=True)
        await websocket.send_json({
            "type": "error",
            "message": str(e)
        })
    finally:
        await websocket.close()


# Run server (for development)
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "karma_player.api.search_api:app",
        host=config.SEARCH_API_HOST,  # Allow external connections for remote deployment
        port=config.SEARCH_API_PORT,
        reload=True,
        log_level="info"
    )
