"""
Local AI service using litellm for development/testing
Falls back to direct API calls when Community API is not available
"""
import os
import json
from typing import List, Dict, Any

try:
    from litellm import completion
    LITELLM_AVAILABLE = True
except ImportError:
    LITELLM_AVAILABLE = False

from karma_player.models.search import ParsedQuery, MBResult
from karma_player.models.torrent import TorrentResult, RankedResult


class LocalAIClient:
    """
    Direct AI provider client for local development
    Uses litellm to support multiple providers (Groq, OpenAI, Anthropic, etc.)
    """

    def __init__(self, provider: str = "groq", model: str = None):
        if not LITELLM_AVAILABLE:
            raise ImportError(
                "litellm not available. Install with: poetry add litellm"
            )

        self.provider = provider
        self.model = model or self._get_default_model(provider)

        # Ensure API key is set
        self._check_api_key()

    def _get_default_model(self, provider: str) -> str:
        """Get default model for provider"""
        defaults = {
            "groq": "groq/llama-3.1-70b-versatile",
            "openai": "gpt-4o-mini",
            "anthropic": "claude-3-5-sonnet-20241022",
        }
        return defaults.get(provider, "groq/llama-3.1-70b-versatile")

    def _check_api_key(self):
        """Check if required API key is set"""
        key_map = {
            "groq": "GROQ_API_KEY",
            "openai": "OPENAI_API_KEY",
            "anthropic": "ANTHROPIC_API_KEY",
        }

        env_var = key_map.get(self.provider)
        if env_var and not os.getenv(env_var):
            raise ValueError(
                f"{env_var} not set. Required for provider: {self.provider}"
            )

    async def parse_query(self, query: str) -> ParsedQuery:
        """
        Parse natural language query into structured data using AI
        """
        prompt = f"""Parse this music search query into structured data.
Extract: artist, album, track (song name), year, and determine query_type (album/track/artist).

Query: "{query}"

Return ONLY a JSON object with this exact structure (no markdown, no explanation):
{{
    "artist": "artist name or null",
    "album": "album name or null",
    "track": "track name or null",
    "year": year_number or null,
    "query_type": "album" or "track" or "artist",
    "confidence": 0.0 to 1.0
}}

Examples:
Query: "radiohead ok computer"
{{"artist": "Radiohead", "album": "OK Computer", "track": null, "year": null, "query_type": "album", "confidence": 0.95}}

Query: "paranoid android"
{{"artist": null, "album": null, "track": "Paranoid Android", "year": null, "query_type": "track", "confidence": 0.8}}

Now parse: "{query}"
"""

        response = completion(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
        )

        content = response.choices[0].message.content.strip()

        # Remove markdown code blocks if present
        if content.startswith("```"):
            content = content.split("\n", 1)[1]
            content = content.rsplit("```", 1)[0]

        data = json.loads(content)

        return ParsedQuery(
            artist=data.get("artist"),
            album=data.get("album"),
            track=data.get("track"),
            year=data.get("year"),
            query_type=data.get("query_type", "album"),
            confidence=data.get("confidence", 0.0)
        )

    async def filter_musicbrainz(
        self, results: List[MBResult], query: ParsedQuery
    ) -> Dict[str, Any]:
        """
        Use AI to filter MusicBrainz results
        For MVP: Return first result if confidence > 0.7, otherwise ask questions
        """
        if len(results) == 0:
            return {"questions": ["No results found. Try a different search?"]}

        if len(results) == 1 or query.confidence > 0.7:
            return {"selected": results[0]}

        # Generate questions for ambiguous results
        return {
            "questions": [
                {
                    "type": "choice",
                    "question": f"Which release of '{query.album or query.track}' do you want?",
                    "options": [
                        f"{r.title} - {r.artist} ({r.release_date[:4]} - {r.country})"
                        for r in results[:5]
                    ]
                }
            ]
        }

    async def rank_torrents(
        self, torrents: List[TorrentResult], preferences: Dict[str, Any]
    ) -> List[RankedResult]:
        """
        Rank torrents using deterministic scoring (legacy algorithm)
        For MVP: Use quality_score already calculated, add AI explanations later
        """
        # Sort by quality_score (already calculated by search service)
        sorted_torrents = sorted(
            torrents, key=lambda t: t.quality_score, reverse=True
        )

        ranked_results = []
        for rank, torrent in enumerate(sorted_torrents, start=1):
            # Generate simple explanation
            explanation = self._explain_torrent(torrent, rank)
            tags = self._generate_tags(torrent, rank)

            ranked_results.append(
                RankedResult(
                    torrent=torrent,
                    rank=rank,
                    explanation=explanation,
                    tags=tags
                )
            )

        return ranked_results

    def _explain_torrent(self, torrent: TorrentResult, rank: int) -> str:
        """Generate explanation for torrent ranking"""
        parts = []

        if rank == 1:
            parts.append("🏆 Best match")

        if torrent.format:
            parts.append(f"{torrent.format}")

        if torrent.bitrate:
            parts.append(f"{torrent.bitrate}")

        if torrent.seeders > 10:
            parts.append(f"{torrent.seeders} seeders (fast download)")
        elif torrent.seeders > 0:
            parts.append(f"{torrent.seeders} seeders")
        else:
            parts.append("No seeders (may be slow)")

        size_mb = torrent.size_bytes / (1024 * 1024)
        parts.append(f"{size_mb:.0f} MB")

        return " • ".join(parts)

    def _generate_tags(self, torrent: TorrentResult, rank: int) -> List[str]:
        """Generate tags for torrent"""
        tags = []

        if rank == 1:
            tags.append("best_quality")

        if torrent.format == "FLAC":
            tags.append("lossless")

        if torrent.seeders >= 10:
            tags.append("fast")

        if torrent.seeders >= 50:
            tags.append("popular")

        return tags
