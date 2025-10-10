"""AI agent for intelligent torrent selection."""

import json
import logging
from typing import List, Optional, Callable, Tuple
from dataclasses import dataclass

from litellm import acompletion

from karma_player.torrent.models import TorrentResult

# Setup logging
logger = logging.getLogger(__name__)


@dataclass
class AIDecision:
    """AI decision with reasoning."""

    selected_torrent: TorrentResult
    selected_index: int
    reasoning: str
    top_candidates: List[tuple[int, TorrentResult, str]]  # (index, torrent, reason)
    rejected: List[tuple[int, TorrentResult, str]]  # (index, torrent, reason)
    fallback_used: bool = False  # Track if quality score fallback was used
    album_mismatch: bool = False  # Track if AI rejected due to album mismatch


class TorrentSelector:
    """Decoupled torrent selection logic (fallback strategy)."""

    @staticmethod
    def select_by_quality_score(results: List[TorrentResult]) -> Tuple[TorrentResult, int]:
        """Select torrent with highest quality score.

        Args:
            results: List of torrent results

        Returns:
            Tuple of (best_torrent, index)

        Raises:
            ValueError: If results list is empty
        """
        if not results:
            raise ValueError("Cannot select from empty results list")

        best = max(results, key=lambda r: r.quality_score)
        idx = results.index(best)

        logger.info(
            f"Quality score fallback: selected torrent with score {best.quality_score:.1f} "
            f"(format={best.format}, seeders={best.seeders})"
        )

        return best, idx

    @staticmethod
    def create_fallback_decision(
        results: List[TorrentResult],
        reason: str = "Quality score fallback",
        album_mismatch: bool = False
    ) -> AIDecision:
        """Create AIDecision using quality score fallback.

        Args:
            results: List of torrent results
            reason: Reason for fallback
            album_mismatch: Whether fallback was due to album mismatch

        Returns:
            AIDecision with best quality torrent selected
        """
        best, idx = TorrentSelector.select_by_quality_score(results)

        return AIDecision(
            selected_torrent=best,
            selected_index=idx,
            reasoning=reason,
            top_candidates=[(idx, best, "Highest quality score")],
            rejected=[],
            fallback_used=True,
            album_mismatch=album_mismatch
        )


class TorrentAgent:
    """AI agent that analyzes and selects optimal torrents."""

    def __init__(
        self,
        model: str = "gpt-4o-mini",
        api_key: Optional[str] = None,
        logger: Optional[Callable[[str], None]] = None,
        tracker=None
    ):
        """Initialize agent.

        Args:
            model: LiteLLM model identifier (e.g., gpt-4o-mini, claude-3-5-sonnet-20241022, ollama/llama3.2)
            api_key: API key for the provider (optional, can use env vars)
            logger: Optional logging function for progress updates
            tracker: Optional AI session tracker
        """
        self.model = model
        self.api_key = api_key
        self.logger = logger or (lambda x: None)
        self.tracker = tracker

    async def select_best_torrent(
        self,
        query: str,
        results: List[TorrentResult],
        preferences: Optional[dict] = None,
    ) -> AIDecision:
        """Use AI to select the best torrent from results.

        This is the primary selection method. If AI parsing fails for any reason,
        it automatically falls back to quality score selection to ensure robust operation.

        Args:
            query: User's original search query
            results: List of torrent results to analyze
            preferences: Optional user preferences (format, min_quality, etc.)

        Returns:
            AIDecision with selected torrent and reasoning

        Raises:
            ValueError: If no results provided
        """
        if not results:
            raise ValueError("No torrents to analyze")

        self.logger("🤖 AI analyzing torrents...")
        self.logger(f"   Total candidates: {len(results)}")

        # Try AI selection
        try:
            return await self._try_ai_selection(query, results, preferences)
        except Exception as e:
            # Log the error and use quality score fallback
            logger.error(
                f"AI selection failed for query '{query}': {type(e).__name__}: {str(e)}",
                exc_info=True
            )
            self.logger(f"   ⚠️  AI failed, using quality score fallback")

            return TorrentSelector.create_fallback_decision(
                results,
                reason=f"AI error ({type(e).__name__}), selected highest quality score"
            )

    async def _try_ai_selection(
        self,
        query: str,
        results: List[TorrentResult],
        preferences: Optional[dict]
    ) -> AIDecision:
        """Attempt AI-based selection (may raise exceptions).

        Args:
            query: User's search query
            results: List of torrent results
            preferences: Optional preferences

        Returns:
            AIDecision from AI

        Raises:
            Exception: Any error during AI call or parsing
        """
        # Format torrents for LLM
        torrents_text = self._format_torrents(results)

        # Build prompt
        prompt = self._build_selection_prompt_verbose(query, torrents_text, preferences)

        # Call LLM
        self.logger(f"   Querying {self.model}...")

        response = await acompletion(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            api_key=self.api_key,
            temperature=0,  # Deterministic results
        )

        # Track token usage
        if self.tracker:
            self.tracker.track_response(response)

        content = response.choices[0].message.content.strip()

        logger.debug(f"AI response for query '{query}': {content[:200]}...")

        # Parse detailed response (may fallback internally)
        decision = self._parse_detailed_selection(content, results)

        self.logger(f"   ✓ Selected: {decision.selected_torrent.title[:60]}...")

        return decision

    async def optimize_query(self, original_query: str, context: Optional[str] = None) -> str:
        """Use AI to optimize search query for better torrent results.

        Args:
            original_query: User's original search query
            context: Optional context (e.g., "no results found", "too many low-quality results")

        Returns:
            Optimized search query
        """
        prompt = f"""You are a music torrent search expert. Optimize this search query for better results.

Original query: "{original_query}"
{f"Context: {context}" if context else ""}

Return ONLY the optimized query, nothing else. Consider:
- Adding album names for better specificity
- Removing ambiguous terms
- Including artist name if missing
- Standardizing format (e.g., "feat." vs "featuring")

Optimized query:"""

        try:
            response = await acompletion(
                model=self.model,
                messages=[{"role": "user", "content": prompt}],
                api_key=self.api_key,
                temperature=0,  # Deterministic results
            )

            # Track token usage
            if self.tracker:
                self.tracker.track_response(response)

            return response.choices[0].message.content.strip().strip('"')

        except Exception:
            # Fallback to original query
            return original_query

    def _format_torrents(self, results: List[TorrentResult]) -> str:
        """Format torrent results for LLM analysis."""
        lines = []
        for i, torrent in enumerate(results):
            lines.append(f"""[{i}] {torrent.title}
    Format: {torrent.format or 'Unknown'}
    Bitrate: {torrent.bitrate or 'Unknown'}
    Size: {torrent.size_formatted}
    Seeders: {torrent.seeders}
    Source: {torrent.indexer}
    Quality Score: {torrent.quality_score:.1f}
""")
        return "\n".join(lines)

    def _build_selection_prompt(
        self, query: str, torrents_text: str, preferences: Optional[dict]
    ) -> str:
        """Build prompt for torrent selection."""
        pref_text = ""
        if preferences:
            if preferences.get("format"):
                pref_text += f"\n- Prefer format: {preferences['format']}"
            if preferences.get("min_quality"):
                pref_text += f"\n- Minimum quality: {preferences['min_quality']}"

        return f"""You are a music quality expert. Select the BEST torrent for this search.

Search query: "{query}"

Available torrents:
{torrents_text}

Selection criteria (in order of importance):
1. Audio quality: FLAC/Lossless > 320kbps MP3 > V0 > lower bitrates
2. Availability: Higher seeders = better availability
3. Completeness: Reasonable file size for format
4. Source reputation: Known indexers preferred{pref_text}

Return ONLY the index number [0-{len(torrents_text.split('[')) - 2}] of the best torrent.
If multiple are equally good, prefer the one with most seeders.

Best torrent index:"""

    def _build_selection_prompt_verbose(
        self, query: str, torrents_text: str, preferences: Optional[dict]
    ) -> str:
        """Build verbose prompt with reasoning."""
        pref_text = ""
        prefer_song_only = False
        expected_album = None
        expected_artist = None

        if preferences:
            if preferences.get("format"):
                pref_text += f"\n- MUST match format: {preferences['format']}"
            if preferences.get("prefer_song_only"):
                prefer_song_only = True
                pref_text += f"\n- IMPORTANT: User wants single-track/song-only torrents, NOT full albums"
                pref_text += f"\n  Prioritize: smaller size, single file, 'single' in title"
                pref_text += f"\n  Avoid: large albums, multiple discs, compilations"
            if preferences.get("expected_album"):
                expected_album = preferences["expected_album"]
            if preferences.get("expected_artist"):
                expected_artist = preferences["expected_artist"]

        completeness_criteria = "Single tracks/songs > Albums" if prefer_song_only else "Proper album releases > compilations"

        # Build album matching requirement
        album_requirement = ""
        if expected_album and expected_artist:
            album_requirement = f"""
🚨 CRITICAL FILTER - ALBUM VERIFICATION (MANDATORY):
   User specifically selected: "{expected_album}" by {expected_artist}

   FILTERING RULES:
   - ONLY consider torrents that contain the album name "{expected_album}" in their title
   - IMMEDIATELY REJECT any torrent from a different album
   - If unsure whether a torrent matches, REJECT it

   AFTER filtering to correct album only, then rank by:
   → Audio quality (24-bit > 16-bit, etc.) - HIGHEST PRIORITY
   → Seeders
   → Size

   Example decision flow:
   ✅ "{expected_album}" 24-bit FLAC (SELECT - correct album, best quality)
   ✅ "{expected_album}" 16-bit FLAC (OK - correct album, lower quality)
   ❌ "Wrong Album" 24-bit FLAC (REJECT - wrong album, filtered out immediately)

   If NO torrents match "{expected_album}", state this clearly in reasoning.

"""
        elif expected_album:
            album_requirement = f"""
⚠️  ALBUM FILTER:
   User is looking for album: "{expected_album}"
   ONLY select torrents matching this album name.

"""

        return f"""You are an audiophile music expert analyzing torrents for the BEST audio quality.

Search query: "{query}"
{album_requirement}
Available torrents:
{torrents_text}

Selection criteria (STRICT priority order):
1. Album verification (if specified above) - MANDATORY FILTER (not a ranking factor)
2. Audio quality (HIGHEST PRIORITY for ranking):
   - DSD/SACD (highest) > 24-bit FLAC (192/176/96/88 kHz) > 16-bit FLAC > 320kbps MP3 > V0 > lower
   - Hi-res markers: Look for [24/96], [24/192], [24-bit], DSD, SACD in titles
   - Vinyl/LP rips often have superior mastering quality
3. Seeders: More seeders = better availability
4. Completeness: {completeness_criteria}
5. Source quality: Known release groups preferred{pref_text}

CRITICAL RULES:
- If album filter is specified, it acts as a FILTER (exclude wrong albums), NOT a ranking factor
- AFTER filtering, select the HIGHEST QUALITY torrent from remaining candidates
- REJECT torrents that don't match the artist/genre (e.g., anime soundtracks for jazz searches)
- Hi-res audio (24-bit, DSD) should ALWAYS win over standard FLAC among filtered results

IMPORTANT: In your reasoning, confirm which specific tracks/songs are included in the selected torrent if known from the title or metadata. For example: "This album contains 'Watermelon Man' along with other tracks from the Takin' Off album."

Respond in JSON format:
{{
  "selected_index": <number>,
  "reasoning": "<why this torrent is best - include album verification if applicable>",
  "top_3": [
    {{"index": <num>, "reason": "<why it's good>"}},
    ...
  ],
  "rejected_sample": [
    {{"index": <num>, "reason": "<why rejected - e.g., wrong album>"}},
    ...
  ]
}}

Select the BEST torrent for this query."""

    def _parse_detailed_selection(self, content: str, results: List[TorrentResult]) -> AIDecision:
        """Parse detailed JSON response from AI with comprehensive error handling.

        Args:
            content: AI response content
            results: List of torrent results

        Returns:
            AIDecision (falls back to quality score if parsing fails)
        """
        import re

        # Try to extract and parse JSON
        json_match = re.search(r'\{.*\}', content, re.DOTALL)

        if not json_match:
            logger.warning("No JSON found in AI response, using quality score fallback")
            logger.debug(f"AI response content: {content[:500]}...")
            return TorrentSelector.create_fallback_decision(
                results,
                reason="No valid JSON in AI response, selected highest quality score"
            )

        try:
            data = json.loads(json_match.group(0))
            logger.debug(f"Successfully parsed AI JSON: {data}")

            # Validate required fields
            if "selected_index" not in data:
                logger.warning("Missing 'selected_index' in AI response")
                return TorrentSelector.create_fallback_decision(
                    results,
                    reason="Invalid AI response format, selected highest quality score"
                )

            selected_idx = data["selected_index"]

            # Validate index is in bounds
            if not (0 <= selected_idx < len(results)):
                logger.error(
                    f"AI selected invalid index {selected_idx} (valid range: 0-{len(results)-1})"
                )
                # Index -1 typically means AI couldn't find matching album
                is_album_mismatch = (selected_idx == -1)
                return TorrentSelector.create_fallback_decision(
                    results,
                    reason=f"AI selected invalid index ({selected_idx}), using quality score",
                    album_mismatch=is_album_mismatch
                )

            # Parse reasoning
            reasoning = data.get("reasoning", "No reasoning provided")

            # Parse top candidates
            top_candidates = []
            for item in data.get("top_3", [])[:3]:
                idx = item.get("index")
                if idx is not None and 0 <= idx < len(results):
                    top_candidates.append((idx, results[idx], item.get("reason", "")))

            # Parse rejected torrents
            rejected = []
            for item in data.get("rejected_sample", [])[:5]:
                idx = item.get("index")
                if idx is not None and 0 <= idx < len(results):
                    rejected.append((idx, results[idx], item.get("reason", "")))

            # Successful parse
            selected = results[selected_idx]
            logger.info(
                f"AI selected torrent #{selected_idx}: {selected.title[:50]} "
                f"(score={selected.quality_score:.1f}, format={selected.format})"
            )

            return AIDecision(
                selected_torrent=selected,
                selected_index=selected_idx,
                reasoning=reasoning,
                top_candidates=top_candidates,
                rejected=rejected,
                fallback_used=False
            )

        except json.JSONDecodeError as e:
            logger.error(f"JSON decode error: {e}")
            logger.debug(f"Failed JSON content: {json_match.group(0)[:500]}...")
            return TorrentSelector.create_fallback_decision(
                results,
                reason=f"JSON parse error, selected highest quality score"
            )

        except KeyError as e:
            logger.error(f"Missing required field in AI response: {e}")
            return TorrentSelector.create_fallback_decision(
                results,
                reason=f"Incomplete AI response, selected highest quality score"
            )

        except Exception as e:
            logger.error(f"Unexpected error parsing AI response: {type(e).__name__}: {e}")
            return TorrentSelector.create_fallback_decision(
                results,
                reason=f"Parse error ({type(e).__name__}), selected highest quality score"
            )
