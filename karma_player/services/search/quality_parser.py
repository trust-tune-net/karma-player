"""Quality metadata parser for torrent titles."""

import re
import logging
from typing import Optional, Tuple

logger = logging.getLogger(__name__)


def parse_flac_quality(title: str) -> Optional[str]:
    """
    Extract FLAC quality specs from torrent title.

    Args:
        title: Torrent title

    Returns:
        Quality string like "24-96", "16-44", "24-192", or None if not found

    Examples:
        "Album [FLAC 24Bit-96kHz]" -> "24-96"
        "Album (FLAC 24/192)" -> "24-192"
        "Album [24-Bit 44.1kHz FLAC]" -> "24-44"
        "Album [24 96]" -> "24-96"
        "Album [FLAC]" -> None (no specific quality)
    """
    title_upper = title.upper()

    # Pattern 1: "24Bit-96kHz", "24BIT-192KHZ", "24 BIT 96 KHZ", "16BITS 44 1KHZ"
    match = re.search(r'(\d+)\s*[-\s]*BITS?[-\s]*(\d+)(?:\s+|\.)?(\d+)?\s*KHZ', title_upper)
    if match:
        bit_depth = match.group(1)
        sample_rate_high = match.group(2)
        sample_rate_low = match.group(3) or ""
        # Handle "44 1" as "44", "96" as "96", "44.1" as "44"
        sample_rate = sample_rate_high + (sample_rate_low if sample_rate_low else "")
        sample_rate = sample_rate.replace('.', '')
        return f"{bit_depth}-{sample_rate}"

    # Pattern 2: "24/96", "24/192", "16/44"
    match = re.search(r'(\d+)/(\d+)', title_upper)
    if match:
        bit_depth = match.group(1)
        sample_rate = match.group(2)
        # Only accept valid bit depths (16, 24, 32) and sample rates
        if bit_depth in ['16', '24', '32'] and sample_rate in ['44', '48', '88', '96', '176', '192']:
            return f"{bit_depth}-{sample_rate}"

    # Pattern 3: "24-96", "24-192" (already in desired format)
    match = re.search(r'(\d+)-(\d+)', title_upper)
    if match:
        bit_depth = match.group(1)
        sample_rate = match.group(2)
        if bit_depth in ['16', '24', '32'] and sample_rate in ['44', '48', '88', '96', '176', '192']:
            return f"{bit_depth}-{sample_rate}"

    # Pattern 4: "[24 96]", "(24 192)" - space-separated inside brackets/parens
    match = re.search(r'[\[\(]\s*(\d+)\s+(\d+)\s*[\]\)]', title_upper)
    if match:
        bit_depth = match.group(1)
        sample_rate = match.group(2)
        if bit_depth in ['16', '24', '32'] and sample_rate in ['44', '48', '88', '96', '176', '192']:
            return f"{bit_depth}-{sample_rate}"

    # All patterns failed
    return None


def normalize_title_for_dedup(title: str) -> str:
    """
    Normalize a torrent title for deduplication.

    Removes:
    - Quality markers: [FLAC], (MP3), 24-bit, etc.
    - Years in brackets: (2023), [1999]
    - Common suffixes: [RG], vtwin88cube, PMEDIA, etc.
    - Extra whitespace and punctuation
    - Edition markers: deluxe, remaster, anniversary, etc.

    Args:
        title: Original torrent title

    Returns:
        Normalized title for comparison

    Examples:
        "Jimi Hendrix - Discography 1967-2018 [FLAC] 88" -> "jimi hendrix discography"
        "Album (2023) [24Bit-96kHz] FLAC [PMEDIA]" -> "album"
        "The Who - Who Are You (Super Deluxe Edition)" -> "the who who are you"
    """
    normalized = title.lower()

    # Remove bracketed/parenthesized content (years, quality, tags)
    normalized = re.sub(r'\[.*?\]', '', normalized)
    normalized = re.sub(r'\(.*?\)', '', normalized)
    normalized = re.sub(r'\{.*?\}', '', normalized)

    # Remove common edition markers
    normalized = re.sub(r'\b(deluxe|remaster|remastered|anniversary|edition|super|expanded|bonus)\b', '', normalized)

    # Remove quality specs: "16bits 44 1khz", "24bit 96khz", etc.
    # This must come BEFORE word-based removal to catch compound patterns
    normalized = re.sub(r'\d+\s*bits?\s+\d+\s+\d+\s*khz', '', normalized)  # "16bits 44 1khz"
    normalized = re.sub(r'\d+\s*bits?\s*\d+\s*khz', '', normalized)  # "16bit 96khz"
    normalized = re.sub(r'\d+\s*/\s*\d+', '', normalized)  # "24/96"

    # Remove common quality markers (words)
    normalized = re.sub(r'\b(flac|mp3|aac|alac|opus|320|v0|bit|bits|khz|rock|jazz|pop|dsd|lossless|tracks|cue)\b', '', normalized)

    # Remove common uploader tags
    normalized = re.sub(r'\b(vtwin88cube|pmedia|rg|88|eichbaum)\b', '', normalized)

    # Remove years (4-digit numbers that look like years)
    normalized = re.sub(r'\b(19|20)\d{2}\b', '', normalized)

    # Remove ALL special characters (dashes, dots, underscores, etc.)
    normalized = re.sub(r'[^\w\s]', ' ', normalized)

    # Collapse multiple spaces into one
    normalized = re.sub(r'\s+', ' ', normalized)

    # Remove standalone numbers (especially trailing ones like "16", "24", "96", "192")
    # These are often truncated quality specs or leftover numbers
    normalized = re.sub(r'\b\d+\b', '', normalized)

    # Final cleanup - collapse spaces again after number removal
    normalized = re.sub(r'\s+', ' ', normalized)

    return normalized.strip()


def extract_quality_metadata(title: str, format: Optional[str]) -> Tuple[Optional[str], Optional[str]]:
    """
    Extract codec and bitrate metadata from torrent title.

    Args:
        title: Torrent title
        format: Format from torrent metadata (FLAC, MP3, etc.)

    Returns:
        Tuple of (codec, bitrate) where:
        - codec: "FLAC", "MP3", "AAC", etc.
        - bitrate: Quality spec like "24-96", "320 kbps", "V0", etc.

    Examples:
        ("Album [FLAC 24-96]", "FLAC") -> ("FLAC", "24-96")
        ("Album [MP3 320]", "MP3") -> ("MP3", "320 kbps")
        ("Album [FLAC]", "FLAC") -> ("FLAC", None)
        ("Album [24 96]", "Unknown") -> ("UNKNOWN", None) - don't assume
    """
    codec = format.upper() if format else None
    bitrate = None
    title_upper = title.upper()

    # If format is missing/unknown but title explicitly contains FLAC, treat as FLAC
    if (not codec or codec == "UNKNOWN") and "FLAC" in title_upper:
        codec = "FLAC"

    if codec == "FLAC":
        # Try to extract FLAC quality specs
        quality = parse_flac_quality(title)
        if quality:
            bitrate = quality
            logger.debug(f"✓ Extracted FLAC bitrate '{bitrate}' from: {title[:60]}")
        else:
            # We KNOW it's FLAC (from metadata) but couldn't extract quality specs
            logger.info(
                f"⚠️  Failed to parse FLAC bitrate (will use 'unknown'): {title[:80]}"
            )
    elif codec == "MP3":
        # Look for MP3 bitrate markers
        if "320" in title_upper:
            bitrate = "320 kbps"
            logger.debug(f"✓ Extracted MP3 bitrate '320 kbps' from: {title[:60]}")
        elif "V0" in title_upper:
            bitrate = "V0"
            logger.debug(f"✓ Extracted MP3 bitrate 'V0' from: {title[:60]}")
        elif "256" in title_upper:
            bitrate = "256 kbps"
            logger.debug(f"✓ Extracted MP3 bitrate '256 kbps' from: {title[:60]}")
        else:
            logger.info(f"⚠️  Failed to parse MP3 bitrate (will use 'unknown'): {title[:80]}")

    return codec, bitrate
