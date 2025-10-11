"""AI-powered query understanding and conversation."""

from dataclasses import dataclass
from typing import Optional, List
from litellm import acompletion


@dataclass
class ParsedQuery:
    """Structured representation of user's search intent."""

    artist: Optional[str] = None
    song: Optional[str] = None
    album: Optional[str] = None
    format_preference: Optional[str] = None
    ambiguous: bool = False
    search_type: str = "unknown"  # song, album, discography, unknown
    confidence: float = 0.0


class QueryParser:
    """Parse natural language queries with AI."""

    def __init__(self, model: str = "gpt-4o-mini", api_key: Optional[str] = None, tracker=None):
        """Initialize parser."""
        self.model = model
        self.api_key = api_key
        self.tracker = tracker

        # Set api_base for Ollama models
        import os
        self.api_base = None
        if model.startswith("ollama/"):
            self.api_base = os.environ.get("OLLAMA_API_BASE", "http://localhost:11434")

    async def parse_query(self, query: str) -> ParsedQuery:
        """Parse user query to understand intent.

        Args:
            query: Natural language search query

        Returns:
            ParsedQuery with structured information
        """
        prompt = f"""Parse this music search query and extract structured information.

Query: "{query}"

Respond in JSON format:
{{
  "artist": "<artist name or null>",
  "song": "<song title or null>",
  "album": "<album name or null>",
  "search_type": "song|album|discography|unknown",
  "confidence": <0.0-1.0>,
  "ambiguous": <true|false>
}}

Examples:
- "Esperanza Spalding I know" → {{"artist": "Esperanza Spalding", "song": "I Know You Know", "search_type": "song", "confidence": 0.8}}
- "radiohead ok computer" → {{"artist": "Radiohead", "album": "OK Computer", "search_type": "album", "confidence": 0.95}}
- "Miles Davis" → {{"artist": "Miles Davis", "search_type": "discography", "confidence": 0.9}}
- "yesterday" → {{"song": "Yesterday", "search_type": "song", "ambiguous": true, "confidence": 0.4}}

Parse the query above:"""

        try:
            kwargs = {
                "model": self.model,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0,  # Deterministic results
            }
            if self.api_key:
                kwargs["api_key"] = self.api_key
            if self.api_base:
                kwargs["api_base"] = self.api_base

            response = await acompletion(**kwargs)

            # Track token usage
            if self.tracker:
                self.tracker.track_response(response)

            content = response.choices[0].message.content.strip()

            # Extract JSON
            import re
            import json

            json_match = re.search(r'\{.*\}', content, re.DOTALL)
            if json_match:
                data = json.loads(json_match.group(0))

                return ParsedQuery(
                    artist=data.get("artist"),
                    song=data.get("song"),
                    album=data.get("album"),
                    search_type=data.get("search_type", "unknown"),
                    confidence=data.get("confidence", 0.0),
                    ambiguous=data.get("ambiguous", False),
                )
        except Exception:
            pass

        # Fallback: treat whole query as search
        return ParsedQuery(
            search_type="unknown",
            confidence=0.0,
            ambiguous=True,
        )

    async def suggest_search_options(
        self,
        parsed: ParsedQuery,
        musicbrainz_results: Optional[List] = None
    ) -> List[tuple[str, str]]:
        """Generate search options based on parsed query.

        Args:
            parsed: Parsed query
            musicbrainz_results: Optional MusicBrainz results

        Returns:
            List of (option_text, search_query) tuples
        """
        options = []

        if parsed.search_type == "song" and parsed.artist and parsed.song:
            # Song-specific search
            options.append((
                f"Just the song \"{parsed.song}\"",
                f"{parsed.artist} {parsed.song}"
            ))

            # Album search (if we know from MusicBrainz)
            if musicbrainz_results:
                for mb in musicbrainz_results[:3]:
                    if mb.album:
                        options.append((
                            f"Album \"{mb.album}\" (contains \"{parsed.song}\")",
                            f"{parsed.artist} {mb.album}"
                        ))

            # Discography fallback
            options.append((
                f"{parsed.artist} discography",
                f"{parsed.artist} discography"
            ))

        elif parsed.search_type == "album" and parsed.artist and parsed.album:
            # Album search
            options.append((
                f"Album \"{parsed.album}\"",
                f"{parsed.artist} {parsed.album}"
            ))

        elif parsed.search_type == "discography" and parsed.artist:
            # Discography
            options.append((
                f"{parsed.artist} complete discography",
                f"{parsed.artist} discography"
            ))
            options.append((
                f"{parsed.artist} greatest hits / best of",
                f"{parsed.artist} greatest hits"
            ))

        # Always add MusicBrainz option if ambiguous
        if parsed.ambiguous or parsed.confidence < 0.7:
            options.append((
                "Search MusicBrainz to see all options",
                "MUSICBRAINZ"
            ))

        return options
