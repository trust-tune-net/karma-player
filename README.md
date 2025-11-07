# 🎵 TrustTune

<div align="center">

<img src="https://img.shields.io/github/stars/trust-tune-net/karma-player?style=social" alt="GitHub stars"/>
<img src="https://github.com/trust-tune-net/karma-player/actions/workflows/build-release.yml/badge.svg" alt="Build Status"/>
<img src="https://img.shields.io/github/v/release/trust-tune-net/karma-player?include_prereleases&label=latest%20release" alt="Latest Release"/>
<img src="https://img.shields.io/github/downloads/trust-tune-net/karma-player/total" alt="Total Downloads"/>
<img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"/>
<img src="https://img.shields.io/badge/python-3.10+-blue.svg" alt="Python"/>
<img src="https://img.shields.io/badge/flutter-3.9+-blue.svg" alt="Flutter"/>

### Music discovery with quality you can trust

*Search naturally or query like a database. Own your music. Pay artists fairly.*

**[Download](#-installation)** • **[Quick Start](#-quick-start)** • **[Roadmap](ROADMAP.md)** • **[Documentation](docs/VISION.md)**

<br/>

### 🎬 See It In Action

<p align="center">
  <img src="demo-gui.gif" alt="TrustTune Demo" width="800">
</p>

</div>

---

## What is TrustTune?

> **The future of music shouldn't be controlled by algorithms, middlemen, or opaque platforms.**

TrustTune is a **music discovery app** that finds high-quality music ranked by format:

- 🗣️ **Two search modes:** Natural language ("radiohead ok computer flac")
- 🎯 **Quality ranking:** Server ranks by quality - DSD > FLAC 24-bit > FLAC > MP3 320
- 🎵 **Dual download modes:** Torrents (high quality, slower) OR YouTube (quick download, converted to m4a with artwork)
- 📦 **Zero config:** Everything bundled - just download and run
- 🌐 **Protocol-first:** Like BitTorrent, anyone can run a node (Phase 2+)
- 💰 **Endgame:** 95% revenue to artists (Phase 3+)

This is **Phase 0.5** of a larger vision. See **[ROADMAP.md](ROADMAP.md)** for the full plan.

---

## The Problem

**Streaming services:**
- Artists earn $0.003/stream (~300 plays = $1)
- Compressed audio (256kbps AAC)
- Pay $10/month forever, own nothing

**Torrents:**
- High quality available (FLAC, hi-res)
- No trust: Fake files, transcodes, malware
- Hard to find, hard to verify

**TrustTune fixes both:** Quality ranked automatically, community validates authenticity (Phase 1+), validators get rewarded (karma, platform benefits, money when economics arrive), you own the files, artists get paid fairly (Phase 3+).

---

## 🚀 Quick Start

### 1. Download

| Platform | Download | Notes |
|----------|----------|-------|
| **macOS Intel** | [Download ZIP](https://github.com/trust-tune-net/karma-player/releases/latest/download/KarmaPlayer-macOS-Intel.zip) | Intel Macs (2020 and earlier) |
| **macOS Apple Silicon** | [Download ZIP](https://github.com/trust-tune-net/karma-player/releases/latest/download/KarmaPlayer-macOS-AppleSilicon.zip) | M1/M2/M3+ Macs (2020+) |
| **Windows** | [Download ZIP](https://github.com/trust-tune-net/karma-player/releases/latest/download/KarmaPlayer-Windows.zip) | Windows 10/11 |
| **Linux** | [Download TAR.GZ](https://github.com/trust-tune-net/karma-player/releases/latest/download/KarmaPlayer-Linux.tar.gz) | Ubuntu/Debian/Fedora |

> **✅ Everything Included:** Transmission bundled, no separate installation needed!

### 2. Search

Two ways to search - your choice:

**Natural Language:**
```
radiohead ok computer flac
miles davis kind of blue 24-bit
pink floyd dark side vinyl rip
```

**SQL-Like:**
```sql
SELECT album WHERE artist="Radiohead" AND format="FLAC"
SELECT track WHERE title="Paranoid Android" ORDER BY seeders DESC
SELECT album WHERE artist="Miles Davis" AND year BETWEEN 1955 AND 1965
```

### 3. Play

Choose your download mode:

🎵 **Torrent Downloads** (High Quality)
- Download FLAC, DSD, hi-res files to **own forever**
- Quality-ranked results, depends on seeders
- Built-in Transmission daemon handles everything

⚡ **YouTube Downloads** (Quick - Under 1 Minute)
- Fast download, converted from opus to m4a
- Album artwork added automatically
- Both modes save to library for offline playback

**That's it!** Built-in player, auto-organized library, zero configuration.

---

## 🎨 How It Works

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Computer (LOCAL)                 │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Desktop App (Flutter)                            │  │
│  │  - Built-in player (MPV)                          │  │
│  │  - Auto-organized library                         │  │
│  │  - Transmission daemon (bundled)                  │  │
│  │  - YouTube downloader (yt-dlp + opus→m4a)         │  │
│  └───────────────────────────────────────────────────┘  │
│                          │                               │
│                          │ Search queries                │
│                          ↓                               │
└─────────────────────────────────────────────────────────┘
                           │
                           │ gRPC
                           ↓
┌─────────────────────────────────────────────────────────┐
│              Remote Search API (REMOTE)                  │
│  - Multi-source aggregation (Jackett, 1337x, DHT)       │
│  - Quality ranking (DSD > FLAC 24-bit > FLAC > MP3)     │
│  - MusicBrainz metadata enrichment                       │
└─────────────────────────────────────────────────────────┘
```

**Key point:** Search is **remote** (no local setup needed), but downloads, playback, and library are all **local** (you own your files).

---

## 🎯 Key Features

### Two Search Modes

**Natural Language** - For everyone (even grandma):
```
radiohead ok computer flac
```

**SQL-Like** - For power users:
```sql
SELECT album WHERE artist="Radiohead" AND format="FLAC"
```

Both modes produce the same quality-ranked results, just different input styles.

### Dual Download Modes

🎵 **Torrent Downloads:**
- High quality: FLAC, DSD, hi-res formats
- Download speed depends on seeders
- Auto-organized with metadata
- Built-in Transmission (no config)

⚡ **YouTube Downloads:**
- Fast: Downloads complete in under 1 minute
- Converted from opus to m4a with album artwork
- Perfect for quick listening
- Both modes save to library for offline playback

### Quality Ranking

Server ranks torrents by audio quality:
- DSD (Direct Stream Digital) - Best
- FLAC 24-bit/96kHz or higher
- FLAC 16-bit/44.1kHz (CD quality)
- MP3 320kbps
- Lower quality formats

**Example output:**
```
🎵 Found 47 results, showing top 10:

✅ #1 Radiohead - OK Computer (1997)
   💎 FLAC 24-bit/96kHz | 1.4 GB | 52 seeders
   🏆 Best quality
   magnet:?xt=urn:btih:...
```

### MusicBrainz Integration

Canonical metadata from MusicBrainz (35M+ recordings):
- Artist disambiguation
- Release year and country
- Track listings
- Album art
- Auto-tagging for downloads

---

## 📖 Documentation

- **[ROADMAP](ROADMAP.md)** - Full project roadmap (Phase 0.5 → Phase 3)
- **[TROUBLESHOOTING](TROUBLESHOOTING.md)** - Common issues and solutions
- **[LEGAL](LEGAL.md)** - Legal disclaimers and user responsibility
- **[Vision Document](docs/VISION.md)** - Full project vision and philosophy
- **[Architecture](docs/ARCHITECTURE.md)** - Technical architecture details
- **[Plugin Architecture](docs/PLUGIN_ARCHITECTURE.md)** - How to add new sources

---

## 🛠️ For Developers

### CLI Installation

```bash
# Install via pip
pip install karma-player

# Or from source
git clone https://github.com/trust-tune-net/karma-player.git
cd karma-player && pip install -e .
```

### CLI Usage

```bash
# Natural language
karma-player search "radiohead ok computer flac"

# SQL-like
karma-player query 'SELECT album WHERE artist="Radiohead" AND format="FLAC"'

# Advanced options
karma-player search "miles davis" --full-ai --min-seeders 10 --skip-musicbrainz
```

### Technology Stack

- **Backend:** Python + FastAPI + gRPC
- **Desktop:** Flutter (cross-platform)
- **Search:** Plugin architecture (Jackett, 1337x, DHT)
- **Metadata:** MusicBrainz API
- **Player:** media_kit (MPV)
- **Torrents:** Transmission daemon (bundled)
- **YouTube:** yt-dlp with opus→m4a conversion

### Running the Backend Locally

**Only needed if developing the backend.** End users don't need this - search happens via remote API.

```bash
# Install dependencies
poetry install

# Set up environment (for backend development only)
export JACKETT_REMOTE_URL="your-jackett-url"
export JACKETT_REMOTE_API_KEY="your-jackett-api-key"

# Run gRPC search API
poetry run python -m karma_player.api.grpc_server
```

See **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** for deploying your own search API.

---

## 🤝 Contributing

We welcome contributions! **TrustTune is not a company—it's a protocol and movement.**

**How to contribute:**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

**Areas we need help:**
- UI/UX design for conversational search flow
- Federation protocol design (ActivityPub-like for music)
- Community validation algorithms
- Mobile app development (iOS/Android)
- Documentation and tutorials
- Adding new search sources (adapters)

See **[ROADMAP.md](ROADMAP.md)** for what's coming next.

---

## 🔧 Troubleshooting

**Security warnings on first launch?** This is normal and expected for open-source software.

- **macOS:** Right-click → Open, or use System Settings → Privacy & Security
- **Windows:** Click "More info" → "Run anyway"

**Other issues?** See **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for:
- Architecture-specific issues ("Bad CPU type")
- Transmission daemon problems
- YouTube download issues
- Debug log locations
- Bug reporting

---

## ⚖️ Legal

**TrustTune is a protocol and open-source software** for music discovery. Like BitTorrent or web search engines, we facilitate discovery of publicly available content.

**Users are solely responsible** for ensuring their downloads comply with local laws and regulations.

See **[LEGAL.md](LEGAL.md)** for full legal disclaimers, DMCA compliance, and user responsibility.

---

## 🎯 Roadmap

- [x] **Phase 0:** CLI tool with AI search
- [x] **Phase 0.5:** Desktop GUI with built-in player (Available now)
- [ ] **Phase 1:** Community validation network (Q2-Q3 2025)
- [ ] **Phase 2:** Mobile apps + federation (Q4 2025 - Q1 2026)
- [ ] **Phase 3:** Creator payment system (2026+)

See **[ROADMAP.md](ROADMAP.md)** for detailed phase breakdown, timelines, and success metrics.

---

## 💡 The Vision

> **Music has a trust problem, not a technology problem.**

**Streaming services** are broken:
- Artists earn $0.003/stream
- Listeners own nothing
- Compressed audio only

**TrustTune fixes this:**

**Phase 0.5 (Now):** Beautiful app with quality-ranked search
**Phase 1-2 (Soon):** Community trust network + federation protocol
**Phase 3+ (Vision):** Fair creator economy (95% to artists)

We're building a **protocol**, like BitTorrent or email:
- Anyone can implement it
- Anyone can run a node
- No single point of control
- Open source, transparent

**Read the full vision:** [ROADMAP.md](ROADMAP.md)

---

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 💬 Community

- **GitHub Issues:** [Report bugs or request features](https://github.com/trust-tune-net/karma-player/issues)
- **Discussions:** [Join the conversation](https://github.com/trust-tune-net/karma-player/discussions)
- **Roadmap:** [See what's coming next](ROADMAP.md)

---

<div align="center">

**[Download Now](#-quick-start)** • **[Read the Roadmap](ROADMAP.md)** • **[Star on GitHub](https://github.com/trust-tune-net/karma-player)**

*Made with ❤️ for music lovers and creators*

<br/>

<a href="https://buymeacoffee.com/fcavalcantirj" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

</div>
