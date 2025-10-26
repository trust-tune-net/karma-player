# 🎵 TrustTune

<div align="center">

**AI-powered music discovery that finds the best quality recordings automatically**

*Like talking to a music-savvy friend who knows where to find everything*

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

TrustTune combines **conversational AI** with **multi-source search** to make high-quality music discovery as simple as asking a question.

- 🗣️ **Natural language search** - "radiohead ok computer FLAC"
- 🎼 **MusicBrainz metadata** - Canonical music database (35M+ recordings)
- 🔍 **Smart ranking** - AI selects best quality (FLAC 24-bit > 16-bit > 320kbps MP3)
- 🎵 **Built-in player** - Listen while downloading
- 📦 **Auto-organization** - Tags and organizes your library
- 🚀 **Zero config** - Works out of the box

---

## ✨ Features

### Current (Phase 0 - Working Today)

- ✅ **CLI Tool** - Search and download from terminal
- ✅ **AI-Powered Search** - Understands natural language queries
- ✅ **Multi-Source** - 18+ torrent indexers via Jackett
- ✅ **Quality Scoring** - Automatic best quality selection
- ✅ **MusicBrainz Integration** - Accurate metadata
- ✅ **Desktop GUI** - Flutter app with built-in player (Beta)

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
[![macOS](https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/fcavalcanti/karma-player/releases)

[**TrustTune.dmg**](https://github.com/fcavalcanti/karma-player/releases/latest/download/TrustTune.dmg)

*Intel & Apple Silicon*

</td>
<td align="center" width="33%">

#### Windows
[![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/fcavalcanti/karma-player/releases)

[**TrustTune-Setup.exe**](https://github.com/fcavalcanti/karma-player/releases/latest/download/TrustTune-Setup.exe)

*Windows 10/11*

</td>
<td align="center" width="33%">

#### Linux
[![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://github.com/fcavalcanti/karma-player/releases)

[**TrustTune.AppImage**](https://github.com/fcavalcanti/karma-player/releases/latest/download/TrustTune.AppImage)

*Ubuntu/Debian/Fedora*

</td>
</tr>
</table>

### CLI Tool

```bash
# Install via pip
pip install karma-player

# Or install from source
git clone https://github.com/fcavalcanti/karma-player.git
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

```bash
# Search for music
karma-player search "pink floyd dark side of the moon"

# With quality preference
karma-player search "radiohead" --full-ai --min-seeders 5

# Skip MusicBrainz for faster results
karma-player search "miles davis" --skip-musicbrainz
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
Your Query
    ↓
Natural Language Processing (AI)
    ↓
MusicBrainz Lookup (Canonical Metadata)
    ↓
Multi-Source Search (18+ Indexers)
    ↓
AI Quality Ranking (FLAC 24-bit > 16-bit > MP3 320)
    ↓
Best Results with Explanations
```

**Technology Stack:**
- **Backend:** Python + FastAPI
- **Desktop:** Flutter (cross-platform)
- **Search:** Jackett + DHT
- **AI:** OpenAI + Anthropic
- **Metadata:** MusicBrainz API
- **Player:** media_kit (MPV)

---

## 📖 Documentation

- **[Vision Document](docs/VISION.md)** - Full project vision and roadmap
- **[Architecture](docs/ARCHITECTURE.md)** - Technical architecture details
- **[Implementation](docs/IMPLEMENTATION.md)** - Development progress
- **[Progress](docs/PROGRESS.md)** - Current status

---

## 🤝 Contributing

We welcome contributions! TrustTune is Phase 0 of a larger vision to build a fair music ecosystem.

**How to contribute:**
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 🎯 Roadmap

- [x] **Phase 0:** CLI tool with AI search (Working today)
- [x] **Phase 0.5:** Desktop GUI with built-in player (Beta)
- [ ] **Phase 1:** Community validation network
- [ ] **Phase 2:** Mobile apps + federation
- [ ] **Phase 3:** Creator payment system

See [VISION.md](docs/VISION.md) for detailed roadmap.

---

## ⚖️ Legal

TrustTune is a **search tool** that helps users find publicly available content. Users are responsible for ensuring their downloads comply with local laws and regulations.

**We do not:**
- Host any copyrighted content
- Circumvent DRM
- Encourage piracy

**This project is for:**
- Educational purposes
- Discovering public domain music
- Finding legitimately free content
- Building decentralized music discovery protocols

---

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 💬 Community

- **GitHub Issues:** [Report bugs or request features](https://github.com/fcavalcanti/karma-player/issues)
- **Discussions:** [Join the conversation](https://github.com/fcavalcanti/karma-player/discussions)

---

## 🌟 Why TrustTune?

**Phase 0 is useful NOW** - Better torrent search saves you time today.

**Phase 1-2 builds trust** - Community validation makes quality reliable.

**Phase 3+ transforms music** - Fair compensation for creators (95% revenue).

**Start simple. Scale responsibly. Stay ethical.**

---

<div align="center">

**[Download Now](#-download)** • **[Read the Vision](docs/VISION.md)** • **[Star on GitHub](https://github.com/fcavalcanti/karma-player)**

*Made with ❤️ for music lovers and creators*

</div>
