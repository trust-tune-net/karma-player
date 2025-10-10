"""Tests for torrent models."""

import pytest
from datetime import datetime, timezone
from karma_player.torrent.models import TorrentResult


class TestTorrentResult:
    """Test TorrentResult dataclass."""

    def test_basic_result(self):
        """Test basic result creation."""
        result = TorrentResult(
            title="Radiohead - OK Computer [FLAC]",
            magnet_link="magnet:?xt=urn:btih:ABC123",
            size_bytes=500000000,  # ~500 MB
            seeders=50,
            leechers=10,
            uploaded_at=datetime(2024, 1, 1, tzinfo=timezone.utc),
            indexer="1337x",
            format="FLAC",
            bitrate=None,
            source="CD",
        )

        assert result.title == "Radiohead - OK Computer [FLAC]"
        assert result.magnet_link == "magnet:?xt=urn:btih:ABC123"
        assert result.size_bytes == 500000000
        assert result.seeders == 50
        assert result.leechers == 10
        assert result.indexer == "1337x"
        assert result.format == "FLAC"
        assert result.bitrate is None
        assert result.source == "CD"

    def test_infohash_extraction(self):
        """Test infohash extraction from magnet link."""
        result = TorrentResult(
            title="Test",
            magnet_link="magnet:?xt=urn:btih:ABC123DEF456&dn=test",
            size_bytes=0,
            seeders=0,
            leechers=0,
            uploaded_at=datetime.now(timezone.utc),
            indexer="test",
        )

        assert result.infohash == "abc123def456"  # infohash is lowercase

    def test_infohash_lowercase(self):
        """Test infohash is lowercase."""
        result = TorrentResult(
            title="Test",
            magnet_link="magnet:?xt=urn:btih:ABCDEF123456",
            size_bytes=0,
            seeders=0,
            leechers=0,
            uploaded_at=datetime.now(timezone.utc),
            indexer="test",
        )

        assert result.infohash == "abcdef123456"

    def test_infohash_invalid_magnet(self):
        """Test infohash with invalid magnet link."""
        result = TorrentResult(
            title="Test",
            magnet_link="not-a-magnet-link",
            size_bytes=0,
            seeders=0,
            leechers=0,
            uploaded_at=datetime.now(timezone.utc),
            indexer="test",
        )

        assert result.infohash == ""

    def test_size_formatted_gb(self):
        """Test size formatting in GB."""
        result = TorrentResult(
            title="Test",
            magnet_link="magnet:?xt=urn:btih:ABC123",
            size_bytes=1610612736,  # 1.5 GB
            seeders=0,
            leechers=0,
            uploaded_at=datetime.now(timezone.utc),
            indexer="test",
        )

        assert result.size_formatted == "1.50 GB"

    def test_size_formatted_mb(self):
        """Test size formatting in MB."""
        result = TorrentResult(
            title="Test",
            magnet_link="magnet:?xt=urn:btih:ABC123",
            size_bytes=52428800,  # 50 MB
            seeders=0,
            leechers=0,
            uploaded_at=datetime.now(timezone.utc),
            indexer="test",
        )

        assert result.size_formatted == "50.00 MB"

    def test_quality_score_flac_high_seeders(self):
        """Test quality score favors FLAC with high seeders."""
        result = TorrentResult(
            title="Album [FLAC]",
            magnet_link="magnet:?xt=urn:btih:ABC123",
            size_bytes=1073741824,  # 1 GB
            seeders=50,
            leechers=10,
            uploaded_at=datetime.now(timezone.utc),
            indexer="test",
            format="FLAC",
        )

        # New scoring: format_bonus + seeder_bonus + size_bonus
        # FLAC = 200, seeders = min(50*2, 100) = 100, size = min(1*5, 30) = 5
        # Total = 200 + 100 + 5 = 305
        assert result.quality_score == 305.0

    def test_quality_score_mp3_many_seeders(self):
        """Test quality score for MP3 320 with many seeders."""
        result = TorrentResult(
            title="Album [MP3 320]",
            magnet_link="magnet:?xt=urn:btih:ABC123",
            size_bytes=104857600,  # 100 MB
            seeders=100,
            leechers=20,
            uploaded_at=datetime.now(timezone.utc),
            indexer="test",
            format="MP3",
            bitrate="320",
        )

        # New scoring: MP3 320 = 150, seeders = min(100*2, 100) = 100, size ≈ 0.5
        # Total ≈ 250.5
        assert result.quality_score > 250.0

    def test_quality_score_caps_size_bonus(self):
        """Test quality score caps size bonus at 30."""
        result = TorrentResult(
            title="Album [FLAC]",
            magnet_link="magnet:?xt=urn:btih:ABC123",
            size_bytes=10737418240,  # 10 GB
            seeders=10,
            leechers=5,
            uploaded_at=datetime.now(timezone.utc),
            indexer="test",
            format="FLAC",
        )

        # New scoring: FLAC = 200, seeders = 10*2 = 20, size = min(10*5, 30) = 30
        # Total = 200 + 20 + 30 = 250
        assert result.quality_score == 250.0

    def test_quality_score_zero_seeders(self):
        """Test quality score with zero seeders and no format."""
        result = TorrentResult(
            title="Album",
            magnet_link="magnet:?xt=urn:btih:ABC123",
            size_bytes=524288000,  # 500 MB
            seeders=0,
            leechers=0,
            uploaded_at=datetime.now(timezone.utc),
            indexer="test",
        )

        # New scoring: format = 0 (unknown), seeders = 0, size = min(0.488*5, 30) ≈ 2.44
        # Total ≈ 2.44
        assert 2.4 < result.quality_score < 2.5
