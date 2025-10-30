# 🎵 TrustTune

<div align="center">

<img src="https://img.shields.io/github/stars/trust-tune-net/karma-player?style=social" alt="GitHub stars"/>
<img src="https://github.com/trust-tune-net/karma-player/actions/workflows/build-release.yml/badge.svg" alt="Build Status"/>
<img src="https://img.shields.io/github/v/release/trust-tune-net/karma-player?include_prereleases&label=latest%20release" alt="Latest Release"/>
<img src="https://img.shields.io/github/downloads/trust-tune-net/karma-player/total" alt="Total Downloads"/>
<img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"/>
<img src="https://img.shields.io/badge/python-3.10+-blue.svg" alt="Python"/>
<img src="https://img.shields.io/badge/flutter-3.9+-blue.svg" alt="Flutter"/>

### AI-powered music discovery with quality you can trust

*Talk to it like a friend. Query it like a database. Own your music. Pay artists fairly.*

**[Download](#installation)** • **[Quick Start](#usage)** • **[Documentation](docs/VISION.md)** • **[Plugin Architecture](docs/PLUGIN_ARCHITECTURE.md)**

<br/>

### 🎬 See It In Action

<p align="center">
  <img src="demo-gui.gif" alt="TrustTune Demo" width="800">
</p>

</div>

---

## What and Why

> **Music discovery doesn't have a quality problem—it has a trust problem.**

You can stream anything on Spotify, but artists get **$0.003 per play**. You can find FLAC torrents, but which ones are real? Which are transcodes? Which uploaders are trusted?

**TrustTune solves this:**

- 🗣️ Search naturally ("radiohead ok computer flac") or precisely (`SELECT album WHERE artist="Radiohead" AND format="FLAC"`)
- 🎯 AI ranks by actual quality (DSD > FLAC 24-bit > FLAC > MP3 320)
- 🎵 Built-in player, auto-organized library, zero config
- 🌐 **Protocol-first**: Like BitTorrent, anyone can run a node
- 💰 **Endgame**: 95% revenue to artists (Phase 3+)

This is **Phase 0.5** of a larger vision. Today: Beautiful app. Tomorrow: Decentralized trust network. Future: Fair creator economy.

---

## The Problem

**Streaming services:**
- Artists earn $0.003/stream (~300 plays = $1)
- Compressed audio (256kbps AAC)
- Pay $10/month forever, own nothing

**Torrents:**
- High quality available (FLAC, hi-res)
- Complex (torrent clients, VPNs, ratios)
- **No trust**: Fake files, transcodes, malware
- Hard to find, hard to verify

## The Solution

> **TrustTune = AI-powered search + Quality verification + Fair compensation**

We're building this in phases. Each phase works standalone, each builds toward the vision.

### Phase 0.5 — Available Now

**Desktop app with two interfaces:**
- Talk: *"radiohead ok computer flac"*
- Query: `SELECT album WHERE artist="Radiohead" AND format="FLAC"`

Both get you the same results: AI-ranked, quality-scored, ready to play.

**What it does:**
- ✅ Searches 18+ sources in parallel (Jackett, 1337x, more via plugins)
- ✅ AI ranks by real quality (not just file size)
- ✅ MusicBrainz metadata (35M+ recordings)
- ✅ Built-in player + auto-tagging
- ✅ **Bundled Transmission** - No separate installation!
- ✅ **Dual playback modes:**
  - 🎵 **Torrents:** Download high-quality files (FLAC, DSD, hi-res) to own forever
  - ▶️ **YouTube:** Stream instantly (or "downplay" - download while playing)
- ✅ Works out of the box (your grandma could use it)

### Phases 1-3 — The Vision

**Phase 1:** Community trust network (like Wikipedia for music quality)
**Phase 2:** Federation protocol (anyone can run a node)
**Phase 3:** Creator payments (95% to artists, not Spotify's $0.003)

---

## 🔧 Troubleshooting

### Security Warnings (Expected Behavior)

**⚠️ KarmaPlayer is not code-signed**, so you'll see security warnings on first launch. This is normal and expected.

#### macOS Security Warning

When you first run KarmaPlayer on macOS, you'll see:
> **"KarmaPlayer.app cannot be opened because it is from an unidentified developer"**

**How to fix:**
1. Right-click (or Control+click) on `KarmaPlayer.app`
2. Select **"Open"** from the menu
3. Click **"Open"** in the security dialog

**OR:**

1. Try to open KarmaPlayer normally (it will be blocked)
2. Go to **System Settings** → **Privacy & Security**
3. Scroll down to the **Security** section
4. Look for the message: *"KarmaPlayer.app was blocked from use because it is not from an identified developer"*
5. Click **"Open Anyway"**
6. Confirm by clicking **"Open"** in the dialog

**Why this happens:**
- Code signing certificates cost $99/year
- KarmaPlayer is open-source and community-driven
- You can verify the source code yourself on GitHub
- Once allowed, macOS will remember your choice

#### Windows Security Warning

Windows Defender SmartScreen may show:
> **"Windows protected your PC"**

**How to fix:**
1. Click **"More info"**
2. Click **"Run anyway"**

**Why this happens:**
- Windows flags unsigned applications
- KarmaPlayer is safe - check the source code yourself
- Once allowed, Windows will remember your choice

#### Linux Permission Issues

If KarmaPlayer won't run on Linux:

```bash
# Make it executable
chmod +x KarmaPlayer

# If transmission-daemon won't start
chmod +x resources/bin/transmission-daemon
```

### Common Issues

#### "Transmission daemon failed to start"

**Cause:** Port conflict or permission issue

**Fix:**
```bash
# Check if transmission is already running
ps aux | grep transmission

# Kill existing processes
pkill transmission-daemon

# On macOS, also check for KarmaPlayer processes
pkill karma_player
```

#### YouTube downloads not working (Windows)

**Cause:** yt-dlp not in PATH or missing ffmpeg

**Fix:**
- KarmaPlayer bundles yt-dlp automatically on Windows
- If issues persist, restart KarmaPlayer
- Check logs: `%APPDATA%\Local\com.example.karma_player\logs\`

#### Audio not playing

**Cause:** Missing audio codecs or permissions

**Fix:**
- **macOS:** Grant microphone/audio permissions in System Settings
- **Windows:** Install Windows Media Feature Pack
- **Linux:** Install `libmpv` and `ffmpeg`

### Debug Logs

**Log locations:**
- **macOS:** `~/Library/Application Support/com.example.karma_player/logs/` and `/tmp/log/karmaplayer.log`
- **Windows:** `%APPDATA%\Local\com.example.karma_player\logs\`
- **Linux:** `~/.local/share/com.example.karma_player/logs/`

Check logs for detailed error messages if something goes wrong.

### 🐛 Found a Bug? Help Us Fix It!

If you're experiencing issues, **please help us improve KarmaPlayer** by reporting them:

**Quick bug report (macOS/Linux):**
```bash
# Copy the latest log to your clipboard
cat /tmp/log/karmaplayer.log | pbcopy  # macOS
cat /tmp/log/karmaplayer.log | xclip   # Linux

# Or view the full log
cat "$(ls -t ~/Library/Application\ Support/com.example.karma_player/logs/*.log | head -1)"  # macOS
cat "$(ls -t ~/.local/share/com.example.karma_player/logs/*.log | head -1)"  # Linux
```

**Then:**
1. Go to [GitHub Issues](https://github.com/trust-tune-net/karma-player/issues)
2. Click **"New Issue"**
3. Describe what happened and what you expected
4. **Paste your error log** (it's anonymous - no personal data)
5. Submit!

**Your bug reports help everyone.** Every issue fixed makes KarmaPlayer better for the community. Thank you! 🙏

---

## Installation

### Desktop App (Recommended)

**One-click install for macOS, Windows, Linux:**

| Platform | Download | Notes |
|----------|----------|-------|
| **macOS** | [Download ZIP](https://github.com/trust-tune-net/karma-player/releases/latest/download/KarmaPlayer-macOS.zip) | Intel & Apple Silicon |
| **Windows** | [Download ZIP](https://github.com/trust-tune-net/karma-player/releases/latest/download/KarmaPlayer-Windows.zip) | Windows 10/11 |
| **Linux** | [Download TAR.GZ](https://github.com/trust-tune-net/karma-player/releases/latest/download/KarmaPlayer-Linux.tar.gz) | Ubuntu/Debian/Fedora |

> **✅ Everything Included:** KarmaPlayer now comes with Transmission bundled - just download, extract, and run! No separate installation needed. See **[Setup Guide](SETUP.md)** for details.

### CLI (For Power Users)

```bash
# Install via pip
pip install karma-player

# Or from source
git clone https://github.com/trust-tune-net/karma-player.git
cd karma-player && pip install -e .
```

---

## Usage

### Desktop App — Two Ways to Search

**Natural Language** (talk like a human):
```
radiohead ok computer flac
miles davis kind of blue 24-bit
pink floyd dark side vinyl rip
```

**SQL-Like** (query like a database):
```sql
SELECT album WHERE artist="Radiohead" AND format="FLAC"
SELECT track WHERE title="Paranoid Android" ORDER BY seeders DESC
SELECT album WHERE artist="Miles Davis" AND year BETWEEN 1955 AND 1965
```

Both interfaces → Same AI-ranked results → Choose your playback mode:

### Two Playback Modes

🎵 **Torrent Downloads** (High Quality)
- Download FLAC, DSD, hi-res files to **own forever**
- Quality-verified, seeder-ranked results
- Auto-organized library with metadata
- Built-in Transmission daemon handles everything

▶️ **YouTube Streaming** (Instant Playback)
- Stream instantly or "downplay" (download while playing)
- Perfect for quick listening or previews
- Uses yt-dlp for best quality streams
- Optional: download for offline playback

**Both modes work seamlessly** in the same interface with the built-in player.

### CLI — For Power Users & Scripts

```bash
# Natural language
karma-player search "radiohead ok computer flac"

# SQL-like
karma-player query 'SELECT album WHERE artist="Radiohead" AND format="FLAC"'

# Advanced options
karma-player search "miles davis" --full-ai --min-seeders 10 --skip-musicbrainz
```

**Example output:**
```
🎵 Found 47 results, showing top 10:

✅ #1 Radiohead - OK Computer (1997)
   💎 FLAC 24-bit/96kHz | 1.4 GB | 52 seeders
   🏆 Best quality • Verified uploader
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
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Deploy search API to cloud (Easypanel, Railway, Render, etc.)
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

## Why This Matters

> **Music has a trust problem, not a technology problem.**

The tools exist. Spotify has great UX. Torrents have great quality. MusicBrainz has great metadata. But:
- **Listeners** overpay for compressed audio and own nothing
- **Artists** get $0.003 per stream (~$3,000 for 1M plays)
- **Quality** is unverified (fake FLACs, transcodes everywhere)

**TrustTune fixes this step by step:**

**Phase 0.5 (Now):** Beautiful app that finds quality automatically
**Phase 1-2 (Soon):** Community trust network + federation protocol
**Phase 3+ (Vision):** Fair creator economy (95% to artists)

### Not Building a Company

We're building a **protocol**, like BitTorrent or email:
- Anyone can implement it
- Anyone can run a node
- No single point of control
- Open source, transparent

**Start simple. Scale responsibly. Stay ethical.**

---

<div align="center">

**[Download Now](#installation)** • **[Read the Vision](docs/VISION.md)** • **[Star on GitHub](https://github.com/trust-tune-net/karma-player)**

*Made with ❤️ for music lovers and creators*

</div>
