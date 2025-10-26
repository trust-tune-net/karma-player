"""
Download Manager for handling torrent downloads using libtorrent.
"""

import libtorrent as lt
import time
import os
from pathlib import Path
from typing import Dict, Optional, Callable
from dataclasses import dataclass
from enum import Enum


class DownloadStatus(Enum):
    """Download status states"""
    QUEUED = "queued"
    DOWNLOADING = "downloading"
    COMPLETED = "completed"
    ERROR = "error"
    PAUSED = "paused"


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
    """Manages torrent downloads using libtorrent"""

    def __init__(self, download_path: str = None):
        """
        Initialize the download manager.

        Args:
            download_path: Default path to save downloads. Defaults to ~/Downloads
        """
        if download_path is None:
            download_path = str(Path.home() / "Downloads" / "TrustTune")

        self.download_path = download_path
        os.makedirs(download_path, exist_ok=True)

        # Create libtorrent session
        self.session = lt.session()
        self.session.listen_on(6881, 6891)

        # Configure session settings for better performance
        settings = {
            'user_agent': 'TrustTune/1.0',
            'listen_interfaces': '0.0.0.0:6881',
            'enable_outgoing_utp': True,
            'enable_incoming_utp': True,
            'enable_outgoing_tcp': True,
            'enable_incoming_tcp': True,
        }

        self.session.apply_settings(settings)

        # Track active downloads
        self.downloads: Dict[str, lt.torrent_handle] = {}
        self.download_info: Dict[str, DownloadInfo] = {}

    def add_magnet(
        self,
        magnet_link: str,
        title: str,
        save_path: Optional[str] = None,
        progress_callback: Optional[Callable[[DownloadInfo], None]] = None
    ) -> str:
        """
        Add a magnet link to download.

        Args:
            magnet_link: The magnet link to download
            title: Display title for the download
            save_path: Optional custom save path
            progress_callback: Optional callback for progress updates

        Returns:
            Download ID (hash info)
        """
        if save_path is None:
            save_path = self.download_path

        # Add magnet to session
        params = {
            'save_path': save_path,
            'storage_mode': lt.storage_mode_t.storage_mode_sparse,
        }

        handle = lt.add_magnet_uri(self.session, magnet_link, params)

        # Get info hash as download ID
        download_id = str(handle.info_hash())

        # Store handle and info
        self.downloads[download_id] = handle
        self.download_info[download_id] = DownloadInfo(
            magnet_link=magnet_link,
            title=title,
            save_path=save_path,
            status=DownloadStatus.QUEUED,
            progress=0.0,
            download_rate=0.0,
            upload_rate=0.0,
            num_peers=0
        )

        return download_id

    def get_download_info(self, download_id: str) -> Optional[DownloadInfo]:
        """Get current download information"""
        if download_id not in self.downloads:
            return None

        handle = self.downloads[download_id]
        status = handle.status()

        info = self.download_info[download_id]

        # Update status
        if status.paused:
            info.status = DownloadStatus.PAUSED
        elif status.is_finished:
            info.status = DownloadStatus.COMPLETED
        elif status.error:
            info.status = DownloadStatus.ERROR
            info.error_message = status.error
        else:
            info.status = DownloadStatus.DOWNLOADING

        # Update progress and rates
        info.progress = status.progress
        info.download_rate = status.download_rate
        info.upload_rate = status.upload_rate
        info.num_peers = status.num_peers

        return info

    def get_all_downloads(self) -> Dict[str, DownloadInfo]:
        """Get information for all downloads"""
        result = {}
        for download_id in self.downloads.keys():
            info = self.get_download_info(download_id)
            if info:
                result[download_id] = info
        return result

    def pause_download(self, download_id: str) -> bool:
        """Pause a download"""
        if download_id not in self.downloads:
            return False

        self.downloads[download_id].pause()
        return True

    def resume_download(self, download_id: str) -> bool:
        """Resume a paused download"""
        if download_id not in self.downloads:
            return False

        self.downloads[download_id].resume()
        return True

    def remove_download(self, download_id: str, delete_files: bool = False) -> bool:
        """
        Remove a download.

        Args:
            download_id: The download to remove
            delete_files: If True, also delete downloaded files

        Returns:
            True if removed successfully
        """
        if download_id not in self.downloads:
            return False

        handle = self.downloads[download_id]

        if delete_files:
            self.session.remove_torrent(handle, lt.options_t.delete_files)
        else:
            self.session.remove_torrent(handle)

        del self.downloads[download_id]
        del self.download_info[download_id]

        return True

    def wait_for_download(self, download_id: str, timeout: int = 3600) -> bool:
        """
        Wait for a download to complete.

        Args:
            download_id: The download to wait for
            timeout: Maximum time to wait in seconds

        Returns:
            True if completed, False if timeout or error
        """
        if download_id not in self.downloads:
            return False

        handle = self.downloads[download_id]
        start_time = time.time()

        while time.time() - start_time < timeout:
            status = handle.status()

            if status.is_finished:
                return True

            if status.error:
                return False

            time.sleep(1)

        return False

    def shutdown(self):
        """Shutdown the download manager"""
        # Pause all downloads
        for handle in self.downloads.values():
            handle.pause()

        # Save resume data
        for handle in self.downloads.values():
            if handle.is_valid():
                handle.save_resume_data()

        # Clear session
        self.session.pause()
        time.sleep(1)
