# 🎵 TrustTune

<div align="center">

<img src="https://img.shields.io/github/stars/trust-tune-net/karma-player?style=social" alt="GitHub stars"/>
<img src="https://github.com/trust-tune-net/karma-player/actions/workflows/build-release.yml/badge.svg" alt="Build Status"/>
<img src="https://img.shields.io/github/v/release/trust-tune-net/karma-player?include_prereleases&label=latest%20release" alt="Latest Release"/>
<img src="https://img.shields.io/github/downloads/trust-tune-net/karma-player/total" alt="Total Downloads"/>
<img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"/>
<img src="https://img.shields.io/badge/python-3.10+-blue.svg" alt="Python"/>
<img src="https://img.shields.io/badge/flutter-3.9+-blue.svg" alt="Flutter"/>

### Music discovery with quality you can verify, not just trust

*Build 200-year censorship-resistant libraries where permanence is protocol-guaranteed, quality is cryptographically proven, and artists receive 70-85% of revenue transparently (tiered by file size).*

**[Download](#1-download)** • **[How It Works](#-how-it-works)** • **[White Paper](WHITE_PAPER.md)** • **[Documentation](docs/VISION.md)**

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

- 🔍 **Simple search:** Find quality-ranked music ("radiohead ok computer flac")
- 🎯 **Quality ranking:** Server ranks by quality - DSD > FLAC 24-bit > FLAC > MP3 320
- 🎵 **Dual download modes:** Torrents (high quality, slower) OR YouTube (quick download, converted to m4a with artwork)
- 📦 **Zero config:** Everything bundled - just download and run
- 🌐 **Protocol-first:** Like BitTorrent, anyone can run a node (Phase 2+)
- 💰 **Endgame:** 70-85% revenue to artists via tiered pricing (Phase 3+)

This is **Phase 0.5** of a larger vision—building **200-year tamper-proof music libraries** where quality is cryptographically verified and artists earn 70-85% of revenue (tiered by file size). See the **[White Paper](WHITE_PAPER.md)** for the complete protocol specification.

> **⚠️ Trust Status:** TrustTune is trust-minimized, not fully trustless. Phase 1 depends on Worldcoin biometric verification, MusicBrainz/AcoustID APIs, and Gun.js relay infrastructure. We're working toward full decentralization in Phase 2-3. See [WHITE_PAPER.md](WHITE_PAPER.md#trust-assumptions--dependencies) for details.

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

**TrustTune vs Competitors:**
- **Spotify:** 20-30% to artists, compressed audio, own nothing
- **iTunes:** 70% to artists (DRM-locked, no permanence)
- **Bandcamp:** 82% to artists (no permanence guarantee, no cryptographic verification)
- **TrustTune:** 70-85% to artists (tiered by file size, cryptographically verified, 200-year permanence)

**TrustTune fixes streaming and torrents:** Quality ranked automatically, community validates authenticity (Phase 1+), validators get rewarded (reputation scores, token earnings when economics arrive), you own the files, artists get paid fairly (Phase 3+).

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

Search for quality-ranked music:

```
radiohead ok computer flac
miles davis kind of blue 24-bit
pink floyd dark side vinyl rip
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
└─────────────────────────────────────────────────────────┘
```

**Key point:** Search is **remote** (no local setup needed), but downloads, playback, and library are all **local** (you own your files).

---

## 🎯 Key Features

### High-Quality Search

Search for music ("radiohead ok computer flac") and TrustTune returns cryptographically verified, quality-ranked results ready for permanent archival.

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

---

## 📖 Documentation

- **[WHITE_PAPER](WHITE_PAPER.md)** - Complete protocol specification and technical architecture
- **[ROADMAP](ROADMAP.md)** - User-facing roadmap (Phase 0.5 → Phase 3)
- **[ROADMAP_LEGACY](ROADMAP_LEGACY.md)** - Original phased development plan (historical reference)
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
# Search example
karma-player search "radiohead ok computer flac"

# Advanced options
karma-player search "miles davis" --full-ai --min-seeders 10 --skip-musicbrainz
```

### Technology Stack

**Current (Phase 0.5):**
- **Backend:** Python + FastAPI + gRPC
- **Desktop:** Flutter (cross-platform)
- **Search:** Plugin architecture (Jackett, 1337x, DHT)
- **Player:** media_kit (MPV)
- **Torrents:** Transmission daemon (bundled)
- **YouTube:** yt-dlp with opus→m4a conversion

**Protocol Stack (Phase 1 Dependencies):**
- **Gun.js** - Distributed ledger (community-operated relays from day 1)
- **Worldcoin** - Biometric authentication (⚠️ centralized dependency, evaluating alternatives Phase 3)
- **Solana** - Smart contracts for transparent tiered payment splits (70-85% to artists, 15-30% protocol costs: validators + Arweave + gas)
- **Arweave** - Permanent decentralized storage uploaded by community validators (200+ year guarantee)
- **MusicBrainz** - Metadata validation (fallback to human validation for rare content)

**Critical:** All infrastructure operated by community validators (permissionless participation). Core team develops code only—never runs production nodes.

See **[WHITE_PAPER.md](WHITE_PAPER.md)** for complete technical specifications and protocol architecture.

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

See the **[White Paper](WHITE_PAPER.md)** for the complete technical roadmap and **[ROADMAP.md](ROADMAP.md)** for user-facing feature timeline.

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

**TrustTune is a protocol and open-source software** for music discovery. Like BitTorrent or web search engines, we index content hashes from publicly available sources.

**Users are solely responsible** for ensuring their downloads comply with local laws and regulations.

**DMCA Compliance:** The protocol implements a permissionless blocklist system via Gun.js distributed ledger. Community validators receive DMCA notices directly and publish blocklist entries. No central coordinator required—validators operate independently with distributed legal liability.

See **[WHITE_PAPER.md](WHITE_PAPER.md#dmca-compliance)** for complete DMCA procedures and **[LEGAL.md](LEGAL.md)** for full legal disclaimers and user responsibility.

---

## 🎯 Roadmap

- [x] **Phase 0:** CLI tool with AI search
- [x] **Phase 0.5:** Desktop GUI with built-in player (Available now)
- [ ] **Phase 1:** Community validation network (Q2-Q3 2025)
- [ ] **Phase 2:** Pressing Layer - Permanent storage + artist payments (2026)
- [ ] **Phase 3:** Mobile + Scale - iOS/Android apps, federation (2027+)

See the **[White Paper](WHITE_PAPER.md)** for detailed phase breakdown, technical specifications, and economic model.

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
**Phase 3+ (Vision):** Fair creator economy (70-85% to artists, tiered by file size)

We're building a **protocol**, like BitTorrent or email:
- Anyone can implement it
- Anyone can run a node
- No single point of control
- Open source, transparent

**Read the complete vision:** [White Paper](WHITE_PAPER.md)

---

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 💬 Community

- **GitHub Issues:** [Report bugs or request features](https://github.com/trust-tune-net/karma-player/issues)
- **Discussions:** [Join the conversation](https://github.com/trust-tune-net/karma-player/discussions)
- **White Paper:** [Read the protocol specification](WHITE_PAPER.md)
- **Roadmap:** [See feature timeline](ROADMAP.md)

---

<div align="center">

**[Download Now](#-quick-start)** • **[Read the White Paper](WHITE_PAPER.md)** • **[Star on GitHub](https://github.com/trust-tune-net/karma-player)**

*Made with ❤️ for music lovers and creators*

<br/>

<a href="https://buymeacoffee.com/fcavalcantirj" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

</div>
