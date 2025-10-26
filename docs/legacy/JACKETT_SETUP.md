# Jackett Integration Setup

## What is Jackett?

Jackett is a proxy server that provides a unified API to query 100+ torrent indexers. By installing Jackett locally, karma-player can search multiple indexers simultaneously without writing individual scrapers.

## Benefits

- **100+ indexers** supported (1337x, RARBG, Nyaa, Rutracker, private trackers, etc.)
- **No scraping fragility** - Jackett maintains the adapters
- **Private tracker support** - if you have accounts
- **Automatic updates** - Jackett team handles site changes

## Installation

### macOS (Homebrew)
```bash
brew install jackett
brew services start jackett
```

### Linux (apt)
```bash
sudo apt install jackett
sudo systemctl enable --now jackett
```

### Docker
```bash
docker run -d \
  --name=jackett \
  -p 9117:9117 \
  -v /path/to/config:/config \
  linuxserver/jackett
```

### Manual Installation
Download from: https://github.com/Jackett/Jackett/releases

## Configuration

1. **Start Jackett** (should run on `http://localhost:9117`)

2. **Get API Key:**
   - Open http://localhost:9117
   - Top right corner: copy API key

3. **Add Indexers:**
   - Click "Add indexer"
   - Search for indexers (e.g., "1337x", "RARBG", "Nyaa")
   - Configure each (most are automatic, some need login)
   - For **music**, recommended:
     * 1337x
     * RuTracker (requires login)
     * Nyaa (anime/music)
     * RED/OPS (private, if you have access)

4. **Configure karma-player:**
   ```bash
   karma-player init
   # When prompted:
   # Jackett URL: http://localhost:9117
   # Jackett API key: <paste your API key>
   ```

## Usage

Once configured, karma-player will automatically query **all your configured Jackett indexers** when searching:

```bash
karma-player search radiohead ok computer --format FLAC
```

Output will show:
```
⏳ Querying indexers:
   ✓ Jackett (all)    # Queries all your indexers
   ✓ 1337x            # Fallback direct scraper
```

## Troubleshooting

### Jackett not accessible
```bash
# Check if running
curl http://localhost:9117/api/v2.0/indexers/all/results?apikey=YOUR_KEY&q=test

# Restart Jackett
brew services restart jackett  # macOS
sudo systemctl restart jackett # Linux
```

### No results from Jackett
- Verify indexers are added in Jackett UI
- Check indexer health (some may be down)
- Test individual indexer in Jackett manual search

### Wrong API key
```bash
# Reconfigure
karma-player config show  # View current config
karma-player init  # Re-initialize with correct key
```

## Phase 2 Enhancement

In Phase 2, we'll add:
- Per-indexer selection (not just "all")
- Indexer health dashboard
- Custom category filtering
- Result caching per indexer

## Without Jackett

karma-player works without Jackett using built-in scrapers (1337x, etc.), but Jackett provides:
- More indexers
- Better reliability (maintained by Jackett team)
- Private tracker support

Built-in scrapers are fallbacks for users who don't want to run Jackett.
