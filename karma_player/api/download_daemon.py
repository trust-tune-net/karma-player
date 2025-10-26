"""
Download Daemon - Local torrent download service
Runs locally, bundled with Flutter app
"""
import os
import logging
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from karma_player import __version__, __app_name__
from karma_player.config import config
from karma_player.services.torrent.download_manager import DownloadManager, DownloadStatus


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


# Global download manager
download_manager: Optional[DownloadManager] = None


# Lifespan context manager for startup/shutdown
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle startup and shutdown events"""
    global download_manager

    logger.info(f"Starting {__app_name__} Download Daemon v{__version__}")
    logger.info(f"Daemon running on port {config.DOWNLOAD_DAEMON_PORT}")

    # Initialize download manager
    logger.info("Initializing download manager...")
    download_path = config.get_music_directory()

    # Ensure download directory exists
    download_path.mkdir(parents=True, exist_ok=True)

    download_manager = DownloadManager(download_path=str(download_path))
    logger.info(f"✅ Download manager ready! Saving to: {download_path}")

    yield

    # Cleanup on shutdown
    logger.info("Shutting down download daemon...")
    if download_manager:
        download_manager.shutdown()
    download_manager = None


# Create FastAPI app
app = FastAPI(
    title="TrustTune Download Daemon",
    description="Local torrent download service",
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
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "ok",
        "version": __version__,
        "service": "download_daemon",
        "download_manager_ready": download_manager is not None
    }


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


# Run server (for development)
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "karma_player.api.download_daemon:app",
        host=config.DOWNLOAD_DAEMON_HOST,
        port=config.DOWNLOAD_DAEMON_PORT,
        reload=True,
        log_level="info"
    )
