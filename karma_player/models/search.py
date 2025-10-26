"""
Search flow data models
"""
from dataclasses import dataclass
from typing import Optional, Literal


@dataclass
class ParsedQuery:
    """Parsed user query from AI"""
    artist: Optional[str]
    album: Optional[str]
    track: Optional[str]
    year: Optional[int]
    query_type: Literal["album", "track", "artist"]
    confidence: float


@dataclass
class MBResult:
    """MusicBrainz search result"""
    mbid: str
    title: str
    artist: str
    release_date: str
    country: str
    label: Optional[str] = None
    barcode: Optional[str] = None
