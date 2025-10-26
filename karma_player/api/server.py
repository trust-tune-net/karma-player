"""
FastAPI server for karma_player
Provides HTTP/WebSocket API for Flutter GUI
"""
import os
import logging
from contextlib import asynccontextmanager
from typing import Optional, List

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import json

from karma_player import __version__, __app_name__
from karma_player.services.simple_search import SimpleSearch
from karma_player.services.search.engine import SearchEngine
from karma_player.services.search.adapter_jackett import AdapterJackett
from karma_player.services.torrent.download_manager import DownloadManager, DownloadStatus


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


# Global search instance
search_service: Optional[SimpleSearch] = None

# Global download manager
download_manager: Optional[DownloadManager] = None


# Lifespan context manager for startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle startup and shutdown events"""
    global search_service, download_manager

    logger.info(f"Starting {__app_name__} v{__version__}")
    logger.info(f"API server running on port {os.getenv('PORT', 8765)}")

    # Initialize search infrastructure
    logger.info("Initializing search infrastructure...")

    # Jackett adapter
    jackett_url = os.getenv("JACKETT_REMOTE_URL", "https://trust-tune-trust-tune-jack.62ickh.easypanel.host")
    jackett_api_key = os.getenv("JACKETT_REMOTE_API_KEY", "ugokmbv2cfeghwcsm27mtnjva5ch7948")

    jackett = AdapterJackett(
        base_url=jackett_url,
        api_key=jackett_api_key,
        indexer_id="all"
    )

    # Search engine
    search_engine = SearchEngine(adapters=[jackett])

    # Simple search service
    search_service = SimpleSearch(search_engine)

    logger.info("✅ Search infrastructure ready!")

    # Initialize download manager
    logger.info("Initializing download manager...")
    download_path = os.path.expanduser("~/Music")
    download_manager = DownloadManager(download_path=download_path)
    logger.info(f"✅ Download manager ready! Saving to: {download_path}")

    yield

    # Cleanup on shutdown
    logger.info("Shutting down...")
    if download_manager:
        download_manager.shutdown()
    search_service = None
    download_manager = None


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


# Request/Response models
class SearchRequest(BaseModel):
    query: str
    format_filter: Optional[str] = None
    min_seeders: int = 1
    limit: int = 50


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


class DownloadRequest(BaseModel):
    magnet_link: str
    title: str


class DownloadResponse(BaseModel):
    download_id: str
    title: str
    status: str
    message: str


class DownloadInfoResponse(BaseModel):
    download_id: str
    title: str
    status: str
    progress: float
    download_rate: float
    upload_rate: float
    num_peers: int
    error_message: Optional[str] = None


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


@app.post("/api/download", response_model=DownloadResponse)
async def start_download(request: DownloadRequest):
    """
    Start downloading a torrent

    Args:
        request: DownloadRequest with magnet link and title

    Returns:
        DownloadResponse with download_id and status
    """
    if not download_manager:
        raise HTTPException(status_code=503, detail="Download manager not available")

    # Validate magnet link format
    if not request.magnet_link.startswith("magnet:"):
        logger.error(f"Invalid magnet link format: {request.magnet_link[:100]}")
        raise HTTPException(
            status_code=400,
            detail="Invalid magnet link. Only magnet URIs are supported."
        )

    try:
        download_id = download_manager.add_magnet(
            magnet_link=request.magnet_link,
            title=request.title
        )

        logger.info(f"Started download: {request.title} (ID: {download_id})")

        return DownloadResponse(
            download_id=download_id,
            title=request.title,
            status="queued",
            message=f"Download started successfully"
        )

    except Exception as e:
        logger.error(f"Download start error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/downloads")
async def get_downloads():
    """Get all active downloads"""
    if not download_manager:
        raise HTTPException(status_code=503, detail="Download manager not available")

    try:
        downloads = download_manager.get_all_downloads()

        return {
            "downloads": [
                {
                    "download_id": download_id,
                    "title": info.title,
                    "status": info.status.value,
                    "progress": info.progress,
                    "download_rate": info.download_rate,
                    "upload_rate": info.upload_rate,
                    "num_peers": info.num_peers,
                    "error_message": info.error_message
                }
                for download_id, info in downloads.items()
            ]
        }

    except Exception as e:
        logger.error(f"Get downloads error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/download/{download_id}", response_model=DownloadInfoResponse)
async def get_download_info(download_id: str):
    """Get information about a specific download"""
    if not download_manager:
        raise HTTPException(status_code=503, detail="Download manager not available")

    try:
        info = download_manager.get_download_info(download_id)

        if not info:
            raise HTTPException(status_code=404, detail="Download not found")

        return DownloadInfoResponse(
            download_id=download_id,
            title=info.title,
            status=info.status.value,
            progress=info.progress,
            download_rate=info.download_rate,
            upload_rate=info.upload_rate,
            num_peers=info.num_peers,
            error_message=info.error_message
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Get download info error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/api/download/{download_id}")
async def delete_download(download_id: str):
    """
    Delete a download.

    This removes the download from the download manager but keeps any completed files.

    Args:
        download_id: The download ID to delete

    Returns:
        Success message
    """
    if not download_manager:
        raise HTTPException(status_code=503, detail="Download manager not available")

    try:
        # Check if download exists
        info = download_manager.get_download_info(download_id)
        if not info:
            raise HTTPException(status_code=404, detail="Download not found")

        # Remove download (keep files)
        success = download_manager.remove_download(download_id, delete_files=False)

        if not success:
            raise HTTPException(status_code=500, detail="Failed to delete download")

        logger.info(f"Deleted download: {download_id}")

        return {
            "status": "success",
            "message": f"Download {download_id} deleted successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Delete download error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


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
            t = ranked.torrent
            ranked_torrents.append({
                "rank": ranked.rank,
                "torrent": {
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
                    "indexer": t.indexer
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

    port = int(os.getenv("PORT", 8765))

    uvicorn.run(
        "karma_player.api.server:app",
        host="127.0.0.1",
        port=port,
        reload=True,
        log_level="info"
    )
