# 🎵 TrustTune

<div align="center">

**AI-powered music discovery that finds the best quality recordings automatically**

*Natural language or SQL-like queries • Built-in player • Protocol for fair artist payments*

*Search like talking to a friend, or like writing a database query — your choice*

[![Build Status](https://github.com/trust-tune-net/karma-player/actions/workflows/build-release.yml/badge.svg)](https://github.com/trust-tune-net/karma-player/actions)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![Flutter](https://img.shields.io/badge/flutter-3.9+-blue.svg)](https://flutter.dev/)

[Features](#-features) • [Download](#-download) • [Quick Start](#-quick-start) • [Vision](docs/VISION.md) • [Architecture](docs/ARCHITECTURE.md)

![Demo](demo_full.gif)

</div>

---

## 🎯 The Problem

**Streaming services:** Artists earn $0.003/stream, compressed audio (256kbps), pay forever
**Torrents:** High quality but complex, hard to find, no trust/verification

## 💡 The Solution

TrustTune is building a **new music ecosystem** where quality is guaranteed, artists are fairly paid, and discovery is effortless.

**Phase 0.5 (Available Now):**
- 🗣️ **Natural language search** - "radiohead ok computer FLAC" or conversational queries
- 💻 **SQL-like queries** - `SELECT album WHERE artist="Radiohead" AND format="FLAC" ORDER BY seeders DESC`
- 🎼 **MusicBrainz metadata** - Canonical music database (35M+ recordings)
- 🔍 **Smart AI ranking** - Selects best quality (FLAC 24-bit > 16-bit > 320kbps MP3)
- 🎵 **Built-in player** - Listen while downloading
- 📦 **Auto-organization** - Tags and organizes your library
- 🚀 **Zero config** - Works out of the box (even your grandma can use it)

**The Vision (Phases 1-3):**
- 🌐 **Trust network** - Community validation of quality and authenticity
- 🔗 **Federation** - Decentralized protocol (like email, anyone can run a server)
- 💰 **Fair payments** - 95% revenue directly to artists
- 📊 **Transparency** - Artists see exactly who listens and where

---

## ✨ Features

### Current (Phase 0.5 - Available Now)

- ✅ **Desktop GUI** - Cross-platform app with built-in player (macOS/Windows/Linux)
- ✅ **Dual Search Interface**
  - 🗣️ Natural language - "radiohead ok computer flac"
  - 💻 SQL-like queries - `SELECT album WHERE artist="Radiohead" AND format="FLAC"`
- ✅ **AI-Powered** - Understands context, asks smart questions, explains choices
- ✅ **Multi-Source** - 18+ torrent indexers via Jackett + DHT network
- ✅ **Quality Scoring** - Automatic ranking (FLAC 24/192 > FLAC 16/44 > MP3 320)
- ✅ **MusicBrainz Integration** - Accurate metadata for 35M+ recordings
- ✅ **CLI Tool** - Also available for power users and scripting

### Coming Soon (Phase 1-2)

- 🔄 **Community Validation** - Distributed trust network
- 🎯 **Acoustic Fingerprinting** - Cryptographic quality proofs
- 📱 **Mobile Apps** - iOS and Android
- 🌐 **Federation** - Decentralized protocol

### Future Vision (Phase 3+)

- 💰 **Creator Payments** - 95% revenue to artists
- 📊 **Transparent Analytics** - Artists see who listens and where
- 🔗 **Blockchain Payments** - Fair compensation model

---

## 📥 Download

### Desktop GUI (Beta)

<table>
<tr>
<td align="center" width="33%">

#### macOS
[![macOS](https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/trust-tune-net/karma-player/releases)

[**Download ZIP**](https://github.com/trust-tune-net/karma-player/releases/latest/download/TrustTune-macOS.zip)

*Intel & Apple Silicon*

</td>
<td align="center" width="33%">

#### Windows
[![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/trust-tune-net/karma-player/releases)

[**Download ZIP**](https://github.com/trust-tune-net/karma-player/releases/latest/download/TrustTune-Windows.zip)

*Windows 10/11*

</td>
<td align="center" width="33%">

#### Linux
[![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://github.com/trust-tune-net/karma-player/releases)

[**Download TAR.GZ**](https://github.com/trust-tune-net/karma-player/releases/latest/download/TrustTune-Linux.tar.gz)

*Ubuntu/Debian/Fedora*

</td>
</tr>
</table>

> 📦 **Latest Release**: [View all releases](https://github.com/trust-tune-net/karma-player/releases)

### CLI Tool

```bash
# Install via pip
pip install karma-player

# Or install from source
git clone https://github.com/trust-tune-net/karma-player.git
cd karma-player
pip install -e .
```

---

## 🚀 Quick Start

### Desktop GUI

1. **Download** the app for your platform
2. **Install** and launch TrustTune
3. **Search** for music using natural language
4. **Download** and play automatically

### CLI Tool

**Natural Language Search:**
```bash
# Simple search
karma-player search "pink floyd dark side of the moon"

# With quality preference
karma-player search "radiohead" --full-ai --min-seeders 5

# Skip MusicBrainz for faster results
karma-player search "miles davis" --skip-musicbrainz
```

**SQL-Like Queries (Power Users):**
```bash
# Album search with format filter
karma-player query 'SELECT album WHERE artist="Radiohead" AND year=1997 AND format="FLAC"'

# Track search sorted by seeders
karma-player query 'SELECT track WHERE title="Paranoid Android" AND format="FLAC" ORDER BY seeders DESC LIMIT 10'

# Year range search
karma-player query 'SELECT album WHERE artist="Miles Davis" AND year BETWEEN 1955 AND 1965'

# Advanced filters (seeders, source)
karma-player query 'SELECT album WHERE artist="Pink Floyd" AND source="CD" AND seeders>=10'
```

**Example Output:**
```
🎵 Found 3 high-quality matches:

✅ Pink Floyd - The Dark Side of the Moon (1973)
   💎 FLAC 24-bit/192kHz | 1.8 GB | 47 seeders
   ✓ Verified uploader | Remastered from analog tapes

   magnet:?xt=urn:btih:...
```

---

## 🛠️ Configuration

### Setup Jackett (Optional)

For best results, run Jackett locally:

```bash
# Install Jackett
# macOS: brew install jackett
# Windows: Download from https://github.com/Jackett/Jackett/releases

# Configure in TrustTune
export JACKETT_URL="http://localhost:9117"
export JACKETT_API_KEY="your_api_key"
```

### Environment Variables

```bash
# Required for AI features
export OPENAI_API_KEY="sk-..."           # OpenAI API key
export ANTHROPIC_API_KEY="sk-ant-..."   # Anthropic API key

# Optional
export JACKETT_URL="http://localhost:9117"
export JACKETT_API_KEY="..."
export MUSICBRAINZ_API_KEY="..."        # For faster MusicBrainz queries
```

---

## 🎨 How It Works

```
Your Query (Natural Language OR SQL-like)
    ↓
Natural Language: AI parsing ("radiohead ok computer")
SQL-like: Direct parsing (SELECT album WHERE artist="Radiohead")
    ↓
MusicBrainz Lookup (Canonical Metadata)
    ↓
Multi-Source Search (18+ Indexers + DHT)
    ↓
AI Quality Ranking (FLAC 24-bit > 16-bit > MP3 320)
    ↓
Best Results with AI Explanations
```

**Two Search Modes:**
- **Natural Language** - For everyone (even grandma): "radiohead ok computer flac"
- **SQL-Like** - For power users: `SELECT album WHERE artist="Radiohead" AND format="FLAC"`

Both modes produce the same high-quality results, just different input styles.

**Technology Stack:**
- **Backend:** Python + FastAPI
- **Desktop:** Flutter (cross-platform)
- **Search:** Plugin architecture (Jackett, 1337x, DHT - easy to add more)
- **AI:** OpenAI + Anthropic (Groq for speed)
- **Metadata:** MusicBrainz API
- **Player:** media_kit (MPV)
- **Architecture:** See [Plugin Architecture](docs/PLUGIN_ARCHITECTURE.md) for adding sources

---

## 📖 Documentation

- **[Vision Document](docs/VISION.md)** - Full project vision and roadmap
- **[Architecture](docs/ARCHITECTURE.md)** - Technical architecture details
- **[Plugin Architecture](docs/PLUGIN_ARCHITECTURE.md)** - How to add new sources (adapters)
- **[Implementation](docs/IMPLEMENTATION.md)** - Development progress
- **[Progress](docs/PROGRESS.md)** - Current status

---

## 🤝 Contributing

We welcome contributions! **TrustTune is not a company—it's a protocol and movement.**

**We're building:**
- Phase 0.5: Beautiful app anyone can use ✅
- Phase 1-2: Community trust network and federation
- Phase 3+: Fair creator payment system (95% to artists)

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

---

## 🎯 Roadmap

- [x] **Phase 0:** CLI tool with AI search
- [x] **Phase 0.5:** Desktop GUI with built-in player (Available now)
- [ ] **Phase 1:** Community validation network
- [ ] **Phase 2:** Mobile apps + federation
- [ ] **Phase 3:** Creator payment system

See [VISION.md](docs/VISION.md) for detailed roadmap.

---

## ⚖️ Legal

TrustTune is a **decentralized protocol and open-source software** for music discovery and artist compensation. Like BitTorrent, email, or the web itself, it's a protocol that anyone can implement.

**What TrustTune is:**
- A protocol specification (like HTTP, SMTP, BitTorrent)
- Open-source reference implementation
- A vision for fair creator compensation
- Community-driven, decentralized infrastructure

**What we do NOT do:**
- Host any copyrighted content
- Circumvent DRM or encryption
- Encourage piracy or copyright infringement
- Control what users download

**User Responsibility:**
Users are solely responsible for ensuring their downloads comply with local laws and regulations. TrustTune facilitates search and discovery of publicly available content, similar to web search engines or torrent clients.

**DMCA Compliance:**
We respect intellectual property rights and respond to valid DMCA takedown notices. If you believe content indexed by TrustTune infringes your copyright, please contact us with a proper DMCA notice.

**This project is for:**
- Building decentralized music discovery protocols
- Researching fair creator compensation models
- Educational and academic purposes
- Discovering public domain and Creative Commons music
- Finding legitimately free content (indie artists, demos, live recordings)

---

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 💬 Community

- **GitHub Issues:** [Report bugs or request features](https://github.com/trust-tune-net/karma-player/issues)
- **Discussions:** [Join the conversation](https://github.com/trust-tune-net/karma-player/discussions)

---

## 🌟 Why TrustTune?

### Available NOW (Phase 0.5)
**Desktop app that anyone can use** - Natural language + SQL-like search, AI-powered quality ranking, built-in player. Your grandma could use it.

### Building Trust (Phase 1-2)
**Community validation network** - Like Wikipedia for music quality. Curators rate recordings, trust scores emerge, verification becomes distributed. **Protocol-first, not platform** - Anyone can run a TrustTune server (like email). Federation means no single point of failure or control.

### Transforming Music (Phase 3+)
**Fair creator economy** - 95% of revenue goes directly to artists (vs. $0.003/stream on Spotify). Blockchain-verified payments, transparent analytics. Artists see exactly who listens and where. **No middlemen taking 30-50% cuts.**

### Why This Matters

**For listeners:** Own your music, support artists fairly, find authentic quality
**For artists:** Get paid what you deserve, know your audience, keep your rights
**For everyone:** Decentralized, open protocol, ethical by design

**Not building a company. Building a protocol.**

Like BitTorrent transformed file sharing, TrustTune transforms music discovery and artist compensation.

**Start simple. Scale responsibly. Stay ethical.**

---

<div align="center">

**[Download Now](#-download)** • **[Read the Vision](docs/VISION.md)** • **[Star on GitHub](https://github.com/trust-tune-net/karma-player)**

*Made with ❤️ for music lovers and creators*

</div>
