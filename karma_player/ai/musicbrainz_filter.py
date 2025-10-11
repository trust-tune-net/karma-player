"""AI-powered MusicBrainz result filtering and grouping."""

import json
from dataclasses import dataclass
from typing import List, Optional
from litellm import acompletion

from karma_player.musicbrainz import MusicBrainzResult
from karma_player.ai.query_parser import ParsedQuery


@dataclass
class GroupedRelease:
    """A grouped/filtered MusicBrainz release."""

    label: str  # Display label for user
    mb_result: MusicBrainzResult  # Original MusicBrainz result
    reason: str  # Why this is relevant
    recommended: bool = False  # AI recommendation
    track_count: Optional[int] = None


@dataclass
class MusicBrainzSelection:
    """User's final MusicBrainz selection."""

    releases: List[GroupedRelease]
    search_type: str  # "song", "album", "discography"
    explanation: str  # What we found


class MusicBrainzFilter:
    """Filter and group MusicBrainz results intelligently."""

    def __init__(self, model: str = "gpt-4o-mini", api_key: Optional[str] = None, tracker=None):
        """Initialize filter."""
        self.model = model
        self.api_key = api_key
        self.tracker = tracker

        # Set api_base for Ollama models
        import os
        self.api_base = None
        if model.startswith("ollama/"):
            self.api_base = os.environ.get("OLLAMA_API_BASE", "http://localhost:11434")

    async def filter_and_group(
        self,
        mb_results: List[MusicBrainzResult],
        parsed: ParsedQuery,
        max_groups: int = 5
    ) -> MusicBrainzSelection:
        """Filter and group MusicBrainz results for user selection.

        Args:
            mb_results: Raw MusicBrainz results
            parsed: Parsed user query
            max_groups: Maximum groups to return

        Returns:
            MusicBrainzSelection with grouped releases
        """
        if not mb_results:
            return MusicBrainzSelection(
                releases=[],
                search_type="unknown",
                explanation="No results found in MusicBrainz"
            )

        # Format results for AI
        mb_text = self._format_musicbrainz_results(mb_results)

        # Build prompt
        prompt = self._build_grouping_prompt(mb_text, parsed, max_groups)

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

            # Parse AI response
            selection = self._parse_grouping_response(content, mb_results)

            return selection

        except Exception as e:
            # Fallback: simple grouping
            return self._fallback_grouping(mb_results, parsed)

    def _format_musicbrainz_results(self, results: List[MusicBrainzResult]) -> str:
        """Format MusicBrainz results for AI."""
        lines = []
        for i, mb in enumerate(results[:20]):  # Limit to top 20
            lines.append(f"[{i}] {mb.artist} - {mb.title}")
            if mb.album:
                lines.append(f"    Album: {mb.album}")
            lines.append(f"    MBID: {mb.mbid}")
            lines.append("")
        return "\n".join(lines)

    def _build_grouping_prompt(
        self,
        mb_text: str,
        parsed: ParsedQuery,
        max_groups: int
    ) -> str:
        """Build AI prompt for grouping."""
        return f"""You are a music library expert. Group and filter these MusicBrainz results for user selection.

User's query intent:
  Artist: {parsed.artist or 'unknown'}
  Song: {parsed.song or 'unknown'}
  Album: {parsed.album or 'unknown'}
  Search type: {parsed.search_type}

MusicBrainz Results:
{mb_text}

Task:
1. If query is a SONG and multiple albums contain it:
   - Group by album/release
   - Prioritize: Deluxe > Original > Compilation > Live
   - Recommend the most complete version

2. If query is an ALBUM and multiple editions exist:
   - Show different editions (Deluxe, Remaster, Original)
   - Recommend based on completeness and quality

3. If query is ARTIST ONLY:
   - Group into: Popular Albums, Discography, Greatest Hits
   - Recommend most popular album or complete discography

4. If AMBIGUOUS (multiple artists with same song):
   - Group by artist
   - Show top 3-5 artists

Return JSON (max {max_groups} groups):
{{
  "search_type": "song|album|discography|artist",
  "explanation": "<what you found>",
  "groups": [
    {{
      "index": <number from mb results>,
      "label": "<display label>",
      "reason": "<why this is good>",
      "recommended": <true|false>
    }},
    ...
  ]
}}

Be concise. User wants to download music, not read essays."""

    def _parse_grouping_response(
        self,
        content: str,
        mb_results: List[MusicBrainzResult]
    ) -> MusicBrainzSelection:
        """Parse AI grouping response."""
        import re

        # Extract JSON
        json_match = re.search(r'\{.*\}', content, re.DOTALL)
        if not json_match:
            return self._fallback_grouping(mb_results, ParsedQuery())

        try:
            data = json.loads(json_match.group(0))

            releases = []
            for group in data.get("groups", [])[:10]:  # Max 10
                idx = group.get("index", 0)
                if 0 <= idx < len(mb_results):
                    releases.append(GroupedRelease(
                        label=group.get("label", "Unknown"),
                        mb_result=mb_results[idx],
                        reason=group.get("reason", ""),
                        recommended=group.get("recommended", False)
                    ))

            return MusicBrainzSelection(
                releases=releases,
                search_type=data.get("search_type", "unknown"),
                explanation=data.get("explanation", "")
            )

        except json.JSONDecodeError:
            return self._fallback_grouping(mb_results, ParsedQuery())

    def _fallback_grouping(
        self,
        mb_results: List[MusicBrainzResult],
        parsed: ParsedQuery
    ) -> MusicBrainzSelection:
        """Simple fallback grouping when AI fails."""
        releases = []

        # Just take top 5 results
        for i, mb in enumerate(mb_results[:5]):
            label = f"{mb.artist} - {mb.title}"
            if mb.album:
                label = f"{mb.artist} - {mb.album}"

            releases.append(GroupedRelease(
                label=label,
                mb_result=mb,
                reason="MusicBrainz result",
                recommended=(i == 0)  # First is recommended
            ))

        return MusicBrainzSelection(
            releases=releases,
            search_type=parsed.search_type if parsed else "unknown",
            explanation=f"Found {len(mb_results)} results"
        )
