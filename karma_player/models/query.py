"""
SQL-like query models for expressive music search
"""
from dataclasses import dataclass
from typing import Optional, List, Literal
from datetime import datetime


@dataclass
class MusicQuery:
    """
    SQL-like structured music query

    Examples:
        SELECT album WHERE artist="Radiohead" AND year=1997 AND format="FLAC"
        SELECT track WHERE title="Paranoid Android" AND format="FLAC" LIMIT 10
        SELECT artist WHERE name="Miles Davis" AND genre="Jazz"
    """

    # SELECT clause
    query_type: Literal["album", "track", "artist", "compilation"]

    # WHERE clause
    artist: Optional[str] = None
    album: Optional[str] = None
    track: Optional[str] = None
    year: Optional[int] = None
    year_range: Optional[tuple[int, int]] = None  # (min, max)

    # Quality filters
    format: Optional[str] = None  # FLAC, MP3, AAC, ALAC
    bitrate: Optional[str] = None  # 320, V0, 24/96, etc.
    min_bitrate: Optional[int] = None  # kbps
    source: Optional[str] = None  # CD, Vinyl, WEB, etc.

    # Torrent filters
    min_seeders: int = 1
    min_size_mb: Optional[int] = None
    max_size_mb: Optional[int] = None

    # Metadata filters
    country: Optional[str] = None  # Release country
    label: Optional[str] = None  # Record label
    catalog_number: Optional[str] = None

    # LIMIT/OFFSET
    limit: int = 50
    offset: int = 0

    # ORDER BY
    order_by: Literal["quality", "seeders", "size", "date", "relevance"] = "quality"
    order_desc: bool = True

    def to_natural_language(self) -> str:
        """Convert query to natural language string"""
        parts = []

        if self.artist:
            parts.append(f"artist '{self.artist}'")
        if self.album:
            parts.append(f"album '{self.album}'")
        if self.track:
            parts.append(f"track '{self.track}'")
        if self.year:
            parts.append(f"from {self.year}")
        elif self.year_range:
            parts.append(f"from {self.year_range[0]}-{self.year_range[1]}")

        if self.format:
            parts.append(f"in {self.format}")
        if self.bitrate:
            parts.append(f"at {self.bitrate}")
        if self.source:
            parts.append(f"sourced from {self.source}")

        if self.min_seeders > 1:
            parts.append(f"with {self.min_seeders}+ seeders")

        return " ".join(parts)

    def to_sql_like(self) -> str:
        """Convert query to SQL-like syntax"""
        where_clauses = []

        if self.artist:
            where_clauses.append(f'artist="{self.artist}"')
        if self.album:
            where_clauses.append(f'album="{self.album}"')
        if self.track:
            where_clauses.append(f'track="{self.track}"')
        if self.year:
            where_clauses.append(f'year={self.year}')
        elif self.year_range:
            where_clauses.append(f'year BETWEEN {self.year_range[0]} AND {self.year_range[1]}')

        if self.format:
            where_clauses.append(f'format="{self.format}"')
        if self.bitrate:
            where_clauses.append(f'bitrate="{self.bitrate}"')
        if self.source:
            where_clauses.append(f'source="{self.source}"')

        if self.min_seeders > 1:
            where_clauses.append(f'seeders>={self.min_seeders}')

        query = f"SELECT {self.query_type}"

        if where_clauses:
            query += " WHERE " + " AND ".join(where_clauses)

        query += f" ORDER BY {self.order_by}"
        if self.order_desc:
            query += " DESC"

        query += f" LIMIT {self.limit}"
        if self.offset > 0:
            query += f" OFFSET {self.offset}"

        return query


@dataclass
class QueryIntent:
    """
    User's search intent parsed by AI
    Can be converted to MusicQuery
    """
    raw_query: str
    parsed_at: datetime

    # Extracted entities
    artist: Optional[str] = None
    album: Optional[str] = None
    track: Optional[str] = None
    year: Optional[int] = None

    # Inferred preferences
    quality_preference: Literal["highest", "lossless", "high", "any"] = "highest"
    format_preference: Optional[str] = None  # User explicitly asked for format
    speed_preference: Literal["fast", "balanced", "patient"] = "balanced"  # How many seeders

    # Confidence scores
    confidence: float = 0.0  # 0.0 to 1.0
    ambiguity_flags: List[str] = None  # ["multiple_artists", "year_uncertain", etc.]

    def to_music_query(self) -> MusicQuery:
        """Convert intent to executable query"""
        query_type = "album"
        if self.track and not self.album:
            query_type = "track"
        elif not self.album and not self.track:
            query_type = "artist"

        # Map quality preference to format
        format_filter = self.format_preference
        if not format_filter and self.quality_preference == "lossless":
            format_filter = "FLAC"

        # Map speed preference to min_seeders
        min_seeders = {
            "fast": 10,
            "balanced": 5,
            "patient": 1
        }[self.speed_preference]

        return MusicQuery(
            query_type=query_type,
            artist=self.artist,
            album=self.album,
            track=self.track,
            year=self.year,
            format=format_filter,
            min_seeders=min_seeders,
            order_by="quality" if self.quality_preference in ["highest", "lossless"] else "seeders"
        )
