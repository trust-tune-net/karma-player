"""
Query parser for SQL-like music search syntax
"""
import re
from typing import Optional
from karma_player.models.query import MusicQuery


class SQLLikeParser:
    """
    Parse SQL-like music queries

    Supported syntax:
        SELECT album WHERE artist="Radiohead" AND year=1997 AND format="FLAC"
        SELECT track WHERE title="Karma Police" ORDER BY seeders DESC LIMIT 10
        SELECT artist WHERE name LIKE "%Davis%" AND genre="Jazz"
    """

    # Regex patterns
    SELECT_PATTERN = re.compile(r'SELECT\s+(album|track|artist|compilation)', re.IGNORECASE)
    WHERE_PATTERN = re.compile(r'WHERE\s+(.+?)(?:\s+ORDER\s+BY|\s+LIMIT|$)', re.IGNORECASE)
    ORDER_PATTERN = re.compile(r'ORDER\s+BY\s+(\w+)(?:\s+(ASC|DESC))?', re.IGNORECASE)
    LIMIT_PATTERN = re.compile(r'LIMIT\s+(\d+)(?:\s+OFFSET\s+(\d+))?', re.IGNORECASE)

    # WHERE clause patterns
    EQUALS_PATTERN = re.compile(r'(\w+)\s*=\s*["\']([^"\']+)["\']', re.IGNORECASE)
    NUMBER_PATTERN = re.compile(r'(\w+)\s*=\s*(\d+)', re.IGNORECASE)
    RANGE_PATTERN = re.compile(r'(\w+)\s+BETWEEN\s+(\d+)\s+AND\s+(\d+)', re.IGNORECASE)
    COMPARISON_PATTERN = re.compile(r'(\w+)\s*([><=]+)\s*(\d+)', re.IGNORECASE)

    @staticmethod
    def parse(query_str: str) -> Optional[MusicQuery]:
        """
        Parse SQL-like query string into MusicQuery object

        Args:
            query_str: SQL-like query string

        Returns:
            MusicQuery object or None if parsing fails

        Examples:
            >>> parse('SELECT album WHERE artist="Radiohead" AND format="FLAC"')
            MusicQuery(query_type='album', artist='Radiohead', format='FLAC')
        """

        # Parse SELECT clause
        select_match = SQLLikeParser.SELECT_PATTERN.search(query_str)
        if not select_match:
            return None

        query_type = select_match.group(1).lower()

        # Initialize query
        query = MusicQuery(query_type=query_type)

        # Parse WHERE clause
        where_match = SQLLikeParser.WHERE_PATTERN.search(query_str)
        if where_match:
            where_clause = where_match.group(1)
            SQLLikeParser._parse_where_clause(where_clause, query)

        # Parse ORDER BY
        order_match = SQLLikeParser.ORDER_PATTERN.search(query_str)
        if order_match:
            order_by = order_match.group(1).lower()
            order_dir = order_match.group(2)

            # Map common column names
            column_map = {
                "quality": "quality",
                "score": "quality",
                "seeders": "seeders",
                "size": "size",
                "date": "date",
                "uploaded": "date",
                "relevance": "relevance"
            }

            query.order_by = column_map.get(order_by, "quality")
            query.order_desc = (order_dir is None or order_dir.upper() == "DESC")

        # Parse LIMIT/OFFSET
        limit_match = SQLLikeParser.LIMIT_PATTERN.search(query_str)
        if limit_match:
            query.limit = int(limit_match.group(1))
            if limit_match.group(2):
                query.offset = int(limit_match.group(2))

        return query

    @staticmethod
    def _parse_where_clause(where_clause: str, query: MusicQuery):
        """Parse WHERE clause and populate query object"""

        # String equality (artist="Radiohead")
        for match in SQLLikeParser.EQUALS_PATTERN.finditer(where_clause):
            field, value = match.groups()
            field = field.lower()

            if field in ["artist", "name"]:
                query.artist = value
            elif field in ["album", "release"]:
                query.album = value
            elif field in ["track", "title", "song"]:
                query.track = value
            elif field == "format":
                query.format = value.upper()
            elif field == "bitrate":
                query.bitrate = value
            elif field == "source":
                query.source = value.upper()
            elif field == "country":
                query.country = value
            elif field == "label":
                query.label = value

        # Numeric equality (year=1997)
        for match in SQLLikeParser.NUMBER_PATTERN.finditer(where_clause):
            field, value = match.groups()
            field = field.lower()
            value = int(value)

            if field == "year":
                query.year = value
            elif field == "limit":
                query.limit = value

        # Ranges (year BETWEEN 1990 AND 2000)
        for match in SQLLikeParser.RANGE_PATTERN.finditer(where_clause):
            field, min_val, max_val = match.groups()
            field = field.lower()

            if field == "year":
                query.year_range = (int(min_val), int(max_val))

        # Comparisons (seeders>=10)
        for match in SQLLikeParser.COMPARISON_PATTERN.finditer(where_clause):
            field, operator, value = match.groups()
            field = field.lower()
            value = int(value)

            if field in ["seeders", "seeds"] and operator == ">=":
                query.min_seeders = value
            elif field == "size" and operator == ">=":
                query.min_size_mb = value
            elif field == "size" and operator == "<=":
                query.max_size_mb = value


class NaturalLanguageToSQL:
    """
    Convert natural language queries to SQL-like syntax
    Can be enhanced with AI for better parsing
    """

    @staticmethod
    async def convert(natural_query: str) -> str:
        """
        Convert natural language to SQL-like syntax using AI

        Examples:
            "radiohead ok computer flac" →
                SELECT album WHERE artist="Radiohead" AND album="OK Computer" AND format="FLAC"

            "paranoid android high quality" →
                SELECT track WHERE track="Paranoid Android" AND format="FLAC"

            "miles davis from 1959" →
                SELECT artist WHERE artist="Miles Davis" AND year=1959
        """
        try:
            # Try AI-powered parsing first
            from karma_player.config import Config
            if Config.OPENAI_API_KEY:
                from openai import AsyncOpenAI
                import json

                # Use OpenAI directly
                client = AsyncOpenAI(api_key=Config.OPENAI_API_KEY)

                response = await client.chat.completions.create(
                    model="gpt-4o-mini",
                    messages=[{
                        "role": "system",
                        "content": "Extract artist, album, track, and year from music search queries. Return JSON with keys: artist, album, track, year. Set values to null if not present."
                    }, {
                        "role": "user",
                        "content": natural_query
                    }],
                    response_format={"type": "json_object"},
                    temperature=0
                )

                result = json.loads(response.choices[0].message.content)

                # Create ParsedQuery from result
                from karma_player.models.search import ParsedQuery
                parsed = ParsedQuery(
                    artist=result.get("artist"),
                    album=result.get("album"),
                    track=result.get("track"),
                    year=result.get("year"),
                    query_type="album" if result.get("album") else ("track" if result.get("track") else "artist"),
                    confidence=0.9
                )

                # Convert ParsedQuery to SQL
                where_clauses = []
                query_type = "album"  # default

                if parsed.artist:
                    where_clauses.append(f'artist="{parsed.artist}"')
                if parsed.album:
                    where_clauses.append(f'album="{parsed.album}"')
                    query_type = "album"
                elif parsed.track:
                    where_clauses.append(f'track="{parsed.track}"')
                    query_type = "track"
                else:
                    query_type = "artist"

                if parsed.year:
                    where_clauses.append(f'year={parsed.year}')

                sql_query = f"SELECT {query_type}"
                if where_clauses:
                    sql_query += " WHERE " + " AND ".join(where_clauses)
                sql_query += " ORDER BY quality DESC LIMIT 50"

                return sql_query

        except Exception as e:
            # Fall back to heuristic parsing
            pass

        # Fallback: Simple heuristic-based conversion
        return NaturalLanguageToSQL._fallback_convert(natural_query)

    @staticmethod
    def _fallback_convert(natural_query: str) -> str:
        """Fallback heuristic converter when AI is unavailable"""
        query_str = natural_query.lower().strip()

        # Detect format requests
        format_filter = None
        for format_name in ["flac", "mp3", "aac", "alac"]:
            if format_name in query_str:
                format_filter = format_name.upper()
                query_str = query_str.replace(format_name, "").strip()

        # Detect year
        year_match = re.search(r'\b(19|20)\d{2}\b', query_str)
        year = int(year_match.group()) if year_match else None
        if year:
            query_str = re.sub(r'\b(from\s+)?(19|20)\d{2}\b', '', query_str).strip()

        # Artist/album extraction - just search the whole thing
        parts = query_str.split()

        if len(parts) <= 2:
            # Artist only
            query_type = "artist"
            artist = " ".join(parts).title()
            album = None
        else:
            # Use whole query as search term, let torrent results decide
            query_type = "album"
            artist = " ".join(parts).title()
            album = None

        # Build SQL-like query
        where_clauses = []

        if artist:
            where_clauses.append(f'artist="{artist}"')
        if album:
            where_clauses.append(f'album="{album}"')
        if year:
            where_clauses.append(f'year={year}')
        if format_filter:
            where_clauses.append(f'format="{format_filter}"')

        sql_query = f"SELECT {query_type}"
        if where_clauses:
            sql_query += " WHERE " + " AND ".join(where_clauses)

        sql_query += " ORDER BY quality DESC LIMIT 50"

        return sql_query
