# Changelog

All notable changes to karma-player will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2025-10-10

### Fixed
- **Size display**: Shows "Unknown" instead of "0.00 MB" when torrent indexer doesn't provide size data
- **Pre-filter accuracy**: Pre-filter now uses same `min_seeders` parameter as actual search (was hardcoded to 0, causing inaccurate availability counts)
- **Format filter wildcard**: Fixed `--format *` (default) being treated as literal string instead of "any format", which was causing 0 results
- **Auto-mode album mismatch**: Auto-mode now properly detects when Strategy 1 (single track search) finds wrong album and continues to Strategy 2 (album search) instead of silently using fallback

### Added
- **Seeder count display**: Pre-filter now shows total seeders per album for better availability assessment
- **Album mismatch warning**: Clear warning message when AI detects album mismatch in auto-mode before continuing to next strategy
- **Top 3 magnet links**: Now displays top 3 torrent options with magnet links instead of just the selected one, providing backup alternatives
- **Debug script**: Added `/tests/debug_prefilter_vs_search.py` for debugging pre-filter vs actual search discrepancies

### Changed
- **AIDecision model**: Added `album_mismatch` field to track when AI rejects torrents due to wrong album

## [0.1.0] - 2025-10-09

### Added
- AI-powered music search with intelligent query parsing
- Multi-provider AI support (OpenAI, Anthropic Claude, Google Gemini) via LiteLLM
- Automatic AI model detection based on available API keys (priority: Anthropic > OpenAI > Gemini)
- MusicBrainz integration for canonical music metadata
- Multi-indexer torrent search via Jackett (18+ indexers)
- Smart quality ranking prioritizing hi-res audio (24-bit FLAC, DSD, vinyl rips)
- Album-aware filtering ensuring correct album selection
- Interactive AI search with album pre-filtering by torrent availability
- Auto-mode with fallback strategies (single track → album → other albums)
- Format preference with smart fallback (e.g., prefer FLAC, fallback to MP3)
- Comprehensive AI reasoning and rejection explanations
- Session cost tracking for AI API usage

### Initial Release
- Core search functionality
- AI agent for intelligent torrent selection
- Configuration management
- CLI interface with rich output formatting
