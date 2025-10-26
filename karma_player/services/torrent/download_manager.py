"""
Download Manager - Thin wrapper around Transmission RPC.

This is NOT an embedded torrent engine. It communicates with the
transmission-daemon that is started and managed by the Flutter app.

Architecture:
  - transmission-daemon: Started by Flutter, runs independently
  - DownloadManager: This class, wraps RPC calls
  - Download Daemon API: FastAPI server using this wrapper
"""

import os
import logging
from typing import Dict, Optional
from dataclasses import dataclass
from enum import Enum

try:
    import transmission_rpc
except ImportError:
    # Fallback for development without transmission-rpc installed
    transmission_rpc = None


logger = logging.getLogger(__name__)


class DownloadStatus(Enum):
    """Download status states"""
    QUEUED = "queued"
    DOWNLOADING = "downloading"
    COMPLETED = "completed"
    ERROR = "error"
    PAUSED = "paused"
    SEEDING = "seeding"


@dataclass
class DownloadInfo:
    """Information about an active download"""
    magnet_link: str
    title: str
    save_path: str
    status: DownloadStatus
    progress: float  # 0.0 to 1.0
    download_rate: float  # bytes/sec
    upload_rate: float  # bytes/sec
    num_peers: int
    error_message: Optional[str] = None


class DownloadManager:
    """
    Thin wrapper around Transmission RPC.

    Does NOT run its own torrent engine - delegates to transmission-daemon.
    """

    def __init__(
        self,
        download_path: str = None,
        transmission_host: str = "localhost",
        transmission_port: int = 9091,
        transmission_user: str = "",
        transmission_password: str = ""
    ):
        """
        Initialize the download manager.

        Args:
            download_path: Default path to save downloads (used when adding torrents)
            transmission_host: Transmission daemon host (default: localhost)
            transmission_port: Transmission RPC port (default: 9091)
            transmission_user: RPC username (empty if no auth)
            transmission_password: RPC password (empty if no auth)
        """
        if transmission_rpc is None:
            raise ImportError(
                "transmission-rpc is not installed. "
                "Install with: pip install transmission-rpc"
            )

        self.download_path = download_path or os.path.expanduser("~/Music")
        self.transmission_host = transmission_host
        self.transmission_port = transmission_port

        # Connect to Transmission daemon
        try:
            self.client = transmission_rpc.Client(
                host=transmission_host,
                port=transmission_port,
                username=transmission_user if transmission_user else None,
                password=transmission_password if transmission_password else None,
                timeout=10
            )
            logger.info(
                f"✅ Connected to Transmission daemon at {transmission_host}:{transmission_port}"
            )
        except Exception as e:
            logger.error(f"❌ Failed to connect to Transmission daemon: {e}")
            raise ConnectionError(
                f"Cannot connect to Transmission daemon at {transmission_host}:{transmission_port}. "
                f"Make sure transmission-daemon is running. Error: {e}"
            )

        # Cache for download metadata (Transmission doesn't store our custom titles)
        self._metadata: Dict[str, dict] = {}

    def add_magnet(
        self,
        magnet_link: str,
        title: str,
        save_path: Optional[str] = None
    ) -> str:
        """
        Add a magnet link to Transmission.

        Args:
            magnet_link: The magnet URI to download
            title: Display title for the download
            save_path: Optional custom save path (overrides default)

        Returns:
            Download ID (torrent hash string)
        """
        if not magnet_link.startswith("magnet:"):
            raise ValueError(f"Invalid magnet link: must start with 'magnet:'")

        download_dir = save_path or self.download_path

        try:
            # Add torrent to Transmission
            torrent = self.client.add_torrent(
                magnet_link,
                download_dir=download_dir
            )

            download_id = torrent.hashString

            # Store metadata (Transmission doesn't have a "title" field)
            self._metadata[download_id] = {
                "title": title,
                "magnet_link": magnet_link,
                "save_path": download_dir
            }

            logger.info(f"✅ Added torrent: {title} (ID: {download_id[:8]}...)")
            return download_id

        except Exception as e:
            logger.error(f"❌ Failed to add torrent: {e}")
            raise

    def get_download_info(self, download_id: str) -> Optional[DownloadInfo]:
        """
        Get current download information from Transmission.

        Args:
            download_id: The torrent hash string

        Returns:
            DownloadInfo object or None if not found
        """
        try:
            # Get torrent from Transmission
            torrent = self.client.get_torrent(download_id)
        except KeyError:
            logger.warning(f"Torrent not found: {download_id}")
            return None
        except Exception as e:
            logger.error(f"Error getting torrent info: {e}")
            return None

        # Get metadata
        metadata = self._metadata.get(download_id, {})
        title = metadata.get("title", torrent.name)
        magnet_link = metadata.get("magnet_link", torrent.magnetLink or "")
        save_path = torrent.downloadDir

        # Map Transmission status to our DownloadStatus
        status = self._map_status(torrent)

        # Get error message if any
        error_message = None
        if torrent.error != 0:
            error_message = torrent.errorString

        return DownloadInfo(
            magnet_link=magnet_link,
            title=title,
            save_path=save_path,
            status=status,
            progress=torrent.progress / 100.0,  # Transmission returns 0-100, we use 0-1
            download_rate=float(torrent.rateDownload),  # bytes/sec
            upload_rate=float(torrent.rateUpload),  # bytes/sec
            num_peers=torrent.peersConnected,
            error_message=error_message
        )

    def get_all_downloads(self) -> Dict[str, DownloadInfo]:
        """
        Get information for all downloads.

        Returns:
            Dict mapping download_id to DownloadInfo
        """
        result = {}
        try:
            torrents = self.client.get_torrents()
            for torrent in torrents:
                download_id = torrent.hashString
                info = self.get_download_info(download_id)
                if info:
                    result[download_id] = info
        except Exception as e:
            logger.error(f"Error getting all downloads: {e}")

        return result

    def pause_download(self, download_id: str) -> bool:
        """
        Pause a download.

        Args:
            download_id: The torrent hash string

        Returns:
            True if successful, False otherwise
        """
        try:
            self.client.stop_torrent(download_id)
            logger.info(f"⏸️  Paused download: {download_id[:8]}...")
            return True
        except Exception as e:
            logger.error(f"Failed to pause download: {e}")
            return False

    def resume_download(self, download_id: str) -> bool:
        """
        Resume a paused download.

        Args:
            download_id: The torrent hash string

        Returns:
            True if successful, False otherwise
        """
        try:
            self.client.start_torrent(download_id)
            logger.info(f"▶️  Resumed download: {download_id[:8]}...")
            return True
        except Exception as e:
            logger.error(f"Failed to resume download: {e}")
            return False

    def remove_download(self, download_id: str, delete_files: bool = False) -> bool:
        """
        Remove a download from Transmission.

        Args:
            download_id: The torrent hash string
            delete_files: If True, also delete downloaded files

        Returns:
            True if removed successfully, False otherwise
        """
        try:
            self.client.remove_torrent(download_id, delete_data=delete_files)

            # Clean up metadata
            if download_id in self._metadata:
                del self._metadata[download_id]

            logger.info(
                f"🗑️  Removed download: {download_id[:8]}... "
                f"(files {'deleted' if delete_files else 'kept'})"
            )
            return True
        except Exception as e:
            logger.error(f"Failed to remove download: {e}")
            return False

    def shutdown(self):
        """
        Shutdown the download manager.

        Note: This does NOT stop transmission-daemon (that's managed by Flutter).
        Just cleans up this wrapper's resources.
        """
        logger.info("Download manager shutting down...")
        # Clear metadata cache
        self._metadata.clear()
        # Close client connection
        self.client = None
        logger.info("✅ Download manager shut down")

    def _map_status(self, torrent) -> DownloadStatus:
        """
        Map Transmission torrent status to our DownloadStatus enum.

        Transmission status values:
        - 'stopped': Torrent is stopped
        - 'check pending': Queued for file check
        - 'checking': Checking files
        - 'download pending': Queued for download
        - 'downloading': Currently downloading
        - 'seed pending': Queued for seeding
        - 'seeding': Currently seeding
        """
        status_str = torrent.status

        # Check for errors first
        if torrent.error != 0:
            return DownloadStatus.ERROR

        # Map Transmission statuses
        if status_str in ['stopped', 'check pending']:
            return DownloadStatus.PAUSED
        elif status_str in ['checking', 'download pending']:
            return DownloadStatus.QUEUED
        elif status_str == 'downloading':
            # Check if actually complete (progress = 100%)
            if torrent.progress >= 100:
                return DownloadStatus.COMPLETED
            return DownloadStatus.DOWNLOADING
        elif status_str in ['seeding', 'seed pending']:
            return DownloadStatus.SEEDING
        else:
            # Unknown status, default to downloading if progress < 100
            if torrent.progress < 100:
                return DownloadStatus.DOWNLOADING
            return DownloadStatus.COMPLETED

    def get_session_stats(self) -> dict:
        """Get Transmission session statistics."""
        try:
            stats = self.client.session_stats()
            return {
                "download_speed": stats.downloadSpeed,
                "upload_speed": stats.uploadSpeed,
                "active_torrents": stats.activeTorrentCount,
                "paused_torrents": stats.pausedTorrentCount,
                "total_torrents": stats.torrentCount
            }
        except Exception as e:
            logger.error(f"Failed to get session stats: {e}")
            return {}
