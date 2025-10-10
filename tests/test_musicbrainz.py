"""Tests for MusicBrainz API client."""

import pytest
from unittest.mock import MagicMock, patch
from karma_player.musicbrainz import (
    MusicBrainzClient,
    MusicBrainzResult,
    MusicBrainzError,
)


class TestMusicBrainzResult:
    """Test MusicBrainzResult dataclass."""

    def test_basic_result(self):
        """Test basic result creation."""
        result = MusicBrainzResult(
            mbid="test-mbid",
            artist="Radiohead",
            title="Paranoid Android",
            album="OK Computer",
            year=1997,
            duration=383000,  # 6:23 in ms
            score=100,
        )

        assert result.mbid == "test-mbid"
        assert result.artist == "Radiohead"
        assert result.title == "Paranoid Android"
        assert result.album == "OK Computer"
        assert result.year == 1997
        assert result.duration == 383000
        assert result.score == 100

    def test_str_representation(self):
        """Test string representation."""
        result = MusicBrainzResult(
            mbid="test-mbid",
            artist="The Beatles",
            title="Yesterday",
            album="Help!",
            year=1965,
        )

        string = str(result)
        assert "The Beatles" in string
        assert "Yesterday" in string
        assert "Help!" in string
        assert "1965" in string

    def test_duration_formatted(self):
        """Test duration formatting."""
        result = MusicBrainzResult(
            mbid="test",
            artist="Test",
            title="Test",
            duration=383000,  # 6:23
        )
        assert result.duration_formatted == "6:23"

        # Test short duration
        result.duration = 45000  # 0:45
        assert result.duration_formatted == "0:45"

        # Test no duration
        result.duration = None
        assert result.duration_formatted == "Unknown"


class TestMusicBrainzClient:
    """Test MusicBrainzClient."""

    @pytest.fixture
    def client(self):
        """Create a MusicBrainz client."""
        return MusicBrainzClient()

    def test_client_initialization(self, client):
        """Test client initializes correctly."""
        assert client.app_name == "karma-player"
        assert client.app_version == "0.1.0"
        assert "github.com" in client.contact

    @patch("karma_player.musicbrainz.musicbrainzngs.search_recordings")
    def test_search_recordings_basic(self, mock_search, client):
        """Test basic recording search."""
        # Mock API response
        mock_search.return_value = {
            "recording-list": [
                {
                    "id": "mbid-123",
                    "title": "Paranoid Android",
                    "ext:score": "100",
                    "length": "383000",
                    "artist-credit": [{"name": "Radiohead"}],
                    "release-list": [
                        {"title": "OK Computer", "date": "1997-05-21"}
                    ],
                }
            ]
        }

        results = client.search_recordings("paranoid android")

        assert len(results) == 1
        assert results[0].mbid == "mbid-123"
        assert results[0].title == "Paranoid Android"
        assert results[0].artist == "Radiohead"
        assert results[0].album == "OK Computer"
        assert results[0].year == 1997
        assert results[0].duration == "383000"
        assert results[0].score == 100

        # Verify API was called correctly
        mock_search.assert_called_once_with(recording="paranoid android", limit=10)

    @patch("karma_player.musicbrainz.musicbrainzngs.search_recordings")
    def test_search_with_artist_filter(self, mock_search, client):
        """Test search with artist filter."""
        mock_search.return_value = {"recording-list": []}

        client.search_recordings("yesterday", artist="The Beatles", limit=5)

        mock_search.assert_called_once_with(
            recording="yesterday", artist="The Beatles", limit=5
        )

    @patch("karma_player.musicbrainz.musicbrainzngs.search_recordings")
    def test_search_no_results(self, mock_search, client):
        """Test search with no results."""
        mock_search.return_value = {"recording-list": []}

        results = client.search_recordings("nonexistent song")

        assert results == []

    @patch("karma_player.musicbrainz.musicbrainzngs.search_recordings")
    def test_search_handles_missing_fields(self, mock_search, client):
        """Test search handles missing optional fields gracefully."""
        mock_search.return_value = {
            "recording-list": [
                {
                    "id": "mbid-456",
                    "title": "Unknown Song",
                    # Missing artist-credit, release-list, duration, score
                }
            ]
        }

        results = client.search_recordings("unknown")

        assert len(results) == 1
        assert results[0].artist == "Unknown Artist"
        assert results[0].album is None
        assert results[0].year is None
        assert results[0].duration is None
        assert results[0].score == 0

    @patch("karma_player.musicbrainz.musicbrainzngs.search_recordings")
    def test_search_sorts_by_score(self, mock_search, client):
        """Test results are sorted by score."""
        mock_search.return_value = {
            "recording-list": [
                {
                    "id": "low-score",
                    "title": "Song A",
                    "ext:score": "50",
                    "artist-credit": [{"name": "Artist"}],
                },
                {
                    "id": "high-score",
                    "title": "Song B",
                    "ext:score": "100",
                    "artist-credit": [{"name": "Artist"}],
                },
                {
                    "id": "mid-score",
                    "title": "Song C",
                    "ext:score": "75",
                    "artist-credit": [{"name": "Artist"}],
                },
            ]
        }

        results = client.search_recordings("song")

        # Should be sorted high to low
        assert results[0].score == 100
        assert results[1].score == 75
        assert results[2].score == 50

    @patch("karma_player.musicbrainz.musicbrainzngs.search_recordings")
    def test_search_api_error(self, mock_search, client):
        """Test API error handling."""
        from musicbrainzngs import WebServiceError

        mock_search.side_effect = WebServiceError("API error")

        with pytest.raises(MusicBrainzError, match="MusicBrainz API error"):
            client.search_recordings("test")

    @patch("karma_player.musicbrainz.musicbrainzngs.get_recording_by_id")
    def test_get_recording_by_mbid(self, mock_get, client):
        """Test getting recording by MBID."""
        mock_get.return_value = {
            "recording": {
                "id": "test-mbid",
                "title": "Test Song",
                "length": "240000",
                "artist-credit": [{"artist": {"name": "Test Artist"}}],
                "release-list": [{"title": "Test Album", "date": "2020-01-01"}],
            }
        }

        result = client.get_recording_by_mbid("test-mbid")

        assert result is not None
        assert result.mbid == "test-mbid"
        assert result.title == "Test Song"
        assert result.artist == "Test Artist"
        assert result.album == "Test Album"
        assert result.year == 2020
        assert result.score == 100  # Direct lookup = perfect score

    @patch("karma_player.musicbrainz.musicbrainzngs.get_recording_by_id")
    def test_get_recording_not_found(self, mock_get, client):
        """Test getting non-existent recording."""
        mock_get.return_value = {}

        result = client.get_recording_by_mbid("nonexistent")

        assert result is None


class TestMusicBrainzIntegration:
    """Integration tests for MusicBrainz (with mocked responses)."""

    @pytest.fixture
    def client(self):
        """Create client."""
        return MusicBrainzClient()

    @patch("karma_player.musicbrainz.musicbrainzngs.search_recordings")
    def test_realistic_search_flow(self, mock_search, client):
        """Test realistic search scenario."""
        # Simulate searching for "Radiohead Paranoid Android"
        mock_search.return_value = {
            "recording-list": [
                {
                    "id": "8a8c35b1-4fa7-449c-88f7-f8e6c2e7f6e1",
                    "title": "Paranoid Android",
                    "ext:score": "100",
                    "length": "383000",
                    "artist-credit": [{"name": "Radiohead"}],
                    "release-list": [
                        {"title": "OK Computer", "date": "1997-05-21"}
                    ],
                },
                {
                    "id": "different-mbid",
                    "title": "Paranoid Android (live)",
                    "ext:score": "85",
                    "length": "400000",
                    "artist-credit": [{"name": "Radiohead"}],
                    "release-list": [{"title": "Live Album", "date": "2001"}],
                },
            ]
        }

        results = client.search_recordings("paranoid android", artist="Radiohead")

        # Should get 2 results, studio version first (higher score)
        assert len(results) == 2
        assert results[0].title == "Paranoid Android"
        assert results[0].score == 100
        assert results[1].title == "Paranoid Android (live)"
        assert results[1].score == 85
