"""Tests for metadata extraction."""

import pytest
from karma_player.torrent.metadata import MetadataExtractor


class TestMetadataExtractor:
    """Test MetadataExtractor."""

    @pytest.fixture
    def extractor(self):
        """Create extractor instance."""
        return MetadataExtractor()

    # Format extraction tests
    def test_extract_format_flac(self, extractor):
        """Test FLAC format extraction."""
        assert extractor.extract_format("Album [FLAC]") == "FLAC"
        assert extractor.extract_format("Album (FLAC)") == "FLAC"
        assert extractor.extract_format("Album - FLAC - 2024") == "FLAC"

    def test_extract_format_mp3(self, extractor):
        """Test MP3 format extraction."""
        assert extractor.extract_format("Album [MP3 320]") == "MP3"
        assert extractor.extract_format("Album (MP3)") == "MP3"
        assert extractor.extract_format("Album mp3 VBR") == "MP3"

    def test_extract_format_various(self, extractor):
        """Test various format extractions."""
        assert extractor.extract_format("Album [AAC]") == "AAC"
        assert extractor.extract_format("Album (ALAC)") == "ALAC"
        assert extractor.extract_format("Album [OGG]") == "OGG"
        assert extractor.extract_format("Album Opus") == "OPUS"

    def test_extract_format_case_insensitive(self, extractor):
        """Test case-insensitive format extraction."""
        assert extractor.extract_format("Album [flac]") == "FLAC"
        assert extractor.extract_format("Album [FLaC]") == "FLAC"
        assert extractor.extract_format("Album [mp3]") == "MP3"

    def test_extract_format_none(self, extractor):
        """Test no format returns None."""
        assert extractor.extract_format("Album Name") is None
        assert extractor.extract_format("Artist - Album") is None
        assert extractor.extract_format("") is None

    def test_extract_format_first_match(self, extractor):
        """Test returns first format if multiple."""
        # FLAC appears first
        assert extractor.extract_format("Album [FLAC MP3]") == "FLAC"

    # Bitrate extraction tests
    def test_extract_bitrate_320(self, extractor):
        """Test 320kbps bitrate extraction."""
        assert extractor.extract_bitrate("Album [MP3 320]") == "320"
        assert extractor.extract_bitrate("Album (320kbps)") == "320"
        assert extractor.extract_bitrate("Album 320") == "320"

    def test_extract_bitrate_vbr(self, extractor):
        """Test VBR bitrate extraction."""
        assert extractor.extract_bitrate("Album [MP3 V0]") == "V0"
        assert extractor.extract_bitrate("Album (V2)") == "V2"

    def test_extract_bitrate_various(self, extractor):
        """Test various bitrate extractions."""
        assert extractor.extract_bitrate("Album [256]") == "256"
        assert extractor.extract_bitrate("Album 192kbps") == "192"

    def test_extract_bitrate_none(self, extractor):
        """Test no bitrate returns None."""
        assert extractor.extract_bitrate("Album [FLAC]") is None
        assert extractor.extract_bitrate("Album Name") is None
        assert extractor.extract_bitrate("") is None

    # Source extraction tests
    def test_extract_source_web(self, extractor):
        """Test WEB source extraction."""
        assert extractor.extract_source("Album [WEB FLAC]") == "WEB"
        assert extractor.extract_source("Album (WEB)") == "WEB"
        assert extractor.extract_source("Album WEB-DL") == "WEB"

    def test_extract_source_cd(self, extractor):
        """Test CD source extraction."""
        assert extractor.extract_source("Album [CD FLAC]") == "CD"
        assert extractor.extract_source("Album (CD Rip)") == "CD"
        assert extractor.extract_source("Album CD") == "CD"

    def test_extract_source_vinyl(self, extractor):
        """Test Vinyl source extraction."""
        assert extractor.extract_source("Album [Vinyl]") == "Vinyl"
        assert extractor.extract_source("Album (Vinyl Rip)") == "Vinyl"

    def test_extract_source_various(self, extractor):
        """Test various source extractions."""
        assert extractor.extract_source("Album [DVD]") == "DVD"
        assert extractor.extract_source("Album BD") == "BD"

    def test_extract_source_case_insensitive(self, extractor):
        """Test case-insensitive source extraction."""
        assert extractor.extract_source("Album [web]") == "WEB"
        assert extractor.extract_source("Album [Cd]") == "CD"
        assert extractor.extract_source("Album [VINYL]") == "Vinyl"

    def test_extract_source_none(self, extractor):
        """Test no source returns None."""
        assert extractor.extract_source("Album [MP3]") is None
        assert extractor.extract_source("Album Name") is None
        assert extractor.extract_source("") is None

    # Size parsing tests
    def test_parse_size_gb(self, extractor):
        """Test GB size parsing."""
        assert extractor.parse_size("1.5 GB") == 1610612736  # 1.5 * 1024^3
        assert extractor.parse_size("2 GB") == 2147483648
        assert extractor.parse_size("0.5 GB") == 536870912

    def test_parse_size_mb(self, extractor):
        """Test MB size parsing."""
        assert extractor.parse_size("500 MB") == 524288000  # 500 * 1024^2
        assert extractor.parse_size("750 MB") == 786432000
        assert extractor.parse_size("100 MB") == 104857600

    def test_parse_size_kb(self, extractor):
        """Test KB size parsing."""
        assert extractor.parse_size("1024 KB") == 1048576  # 1024 * 1024
        assert extractor.parse_size("500 KB") == 512000

    def test_parse_size_case_insensitive(self, extractor):
        """Test case-insensitive size parsing."""
        assert extractor.parse_size("1 gb") == 1073741824
        assert extractor.parse_size("500 mb") == 524288000
        assert extractor.parse_size("1 Gb") == 1073741824

    def test_parse_size_with_comma(self, extractor):
        """Test size parsing with comma separator."""
        assert extractor.parse_size("1,5 GB") == 1610612736

    def test_parse_size_invalid(self, extractor):
        """Test invalid size returns 0."""
        assert extractor.parse_size("invalid") == 0
        assert extractor.parse_size("") == 0
        assert extractor.parse_size("ABC GB") == 0

    def test_parse_size_no_unit(self, extractor):
        """Test size without unit returns 0."""
        assert extractor.parse_size("1000") == 0
