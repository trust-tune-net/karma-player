# Karma Player

```
 ██╗  ██╗ █████╗ ██████╗ ███╗   ███╗ █████╗
 ██║ ██╔╝██╔══██╗██╔══██╗████╗ ████║██╔══██╗
 █████╔╝ ███████║██████╔╝██╔████╔██║███████║
 ██╔═██╗ ██╔══██║██╔══██╗██║╚██╔╝██║██╔══██║
 ██║  ██╗██║  ██║██║  ██║██║ ╚═╝ ██║██║  ██║
 ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝
    Building Trust, One Validation at a Time
```

> **Phase 0 of the Trust Tune Network**
> A distributed trust validation infrastructure where communities validate content quality through a two-tier system.

![Karma Player Demo](demo_full.gif)

---

## 🎯 The Problem

```
You → Search "Radiohead OK Computer" → Get 50 results
                    ↓
      Which one is actually FLAC?
      Which one isn't a transcode?
      Which one has seeders tomorrow?
                    ↓
      30 minutes wasted researching
      Download 3 versions. 2 are fake.
```

**The internet has infinite content. The problem isn't access — it's knowing what to trust.**

---

## 💡 The Trust Tune Network Vision

What if there was a system where:

```
┌─────────────────────────────────────────────────────────────┐
│                    TRUST TUNE NETWORK                       │
│                                                             │
│  ┌──────────────┐         ┌──────────────┐                │
│  │   95% USERS  │         │  5% CORE     │                │
│  │   (Casual)   │ ─vote─→ │ (Validators) │                │
│  │              │         │              │                │
│  │ • Download   │         │ • Validate   │                │
│  │ • Vote       │         │ • Provide    │                │
│  │ • Seed       │         │   Proof      │                │
│  │ • Progress → │         │ • Run Nodes  │                │
│  └──────────────┘         └──────────────┘                │
│         ↓                         ↓                        │
│    +1 karma/vote         +5-20 karma/validation           │
│         ↓                         ↓                        │
│  ┌─────────────────────────────────────────┐              │
│  │   DISTRIBUTED LEDGER (Gun.js)           │              │
│  │   • Pseudonymous votes                  │              │
│  │   • Cryptographic proof certificates    │              │
│  │   • Transparent, auditable              │              │
│  └─────────────────────────────────────────┘              │
│                       ↓                                    │
│              VERIFIED CONTENT                              │
│      (validated once, trusted forever)                     │
└─────────────────────────────────────────────────────────────┘
```

### The Core Insight

**Not expert gatekeeping. Community validation at scale.**

- **Casual Listeners (YOU)** vote on files after listening
- **Core Listeners** validate those votes with cryptographic proof (acoustic fingerprint + spectral analysis)
- **Anyone can progress** from Casual to Core (earn karma → apply → validate)
- **The network is self-governing** — no central authority, no gatekeepers
- **Trust is transparent** — all validation proofs are public and auditable

### Why This Changes Everything

Traditional systems:
- ❌ **Private trackers:** Interviews, invite trees, gatekeeping
- ❌ **Public torrents:** No quality control, decision paralysis
- ❌ **Streaming:** You trust the platform, not the community

**Trust Tune Network:**
- ✅ **Open participation** at your level (Casual or Core)
- ✅ **Community validates quality** with cryptographic proof
- ✅ **Transparent trust** — you can audit the validators
- ✅ **Self-reinforcing** — more users = more validated content
- ✅ **Distributed** — no servers, no central control (Gun.js)

---

## 🎵 What Karma Player Does Today (v0.1.1)

**Karma Player is Phase 0** — proving the basic search/download flow works, before we add the network.

```
User Query → AI Parse → MusicBrainz → Torrent Search → AI Select → Download
     ↓           ↓            ↓              ↓              ↓
   "miles    artist:       MBID:       18+ indexers    Best FLAC
    davis"   Miles Davis   xxx-yyy     (Jackett)       24-bit
```

### Current Features

#### 1. AI-Powered Query Understanding
```bash
$ karma-player search "I know you know - Esperanza Spalding"
```

AI parses natural language:
- Identifies: artist, song, album
- Queries **MusicBrainz** for canonical metadata
- Pre-filters albums by checking torrent availability
- Presents only options that actually exist

**Multi-Provider Support:**
- 🟣 **Anthropic Claude** (recommended)
- 🟢 **OpenAI GPT** (fastest, cheapest)
- 🔵 **Google Gemini**

Auto-detects based on your API keys. No configuration.

#### 2. Intelligent Album Matching
```
Query: "fear of the dark iron maiden"
         ↓
MusicBrainz: Found 2 albums
  • Best of the Beast (compilation)
  • The Book of Souls: Live Chapter (live)
         ↓
User selects: Live Chapter
         ↓
System searches 18+ indexers
Finds 26 torrents
         ↓
AI FILTERS: Wrong album? Reject!
         ↓
Result: "The Book of Souls: Live Chapter" (FLAC 1.45GB)
         ✓ Correct album selected
```

No more downloading the wrong version.

#### 3. Quality-First Ranking

AI prioritizes:
```
Priority 1: CORRECT ALBUM (filters wrong albums first)
Priority 2: AUDIO QUALITY (24-bit > 16-bit > 320kbps)
Priority 3: SEEDERS (availability matters)
Priority 4: COMPLETENESS (proper releases > compilations)
```

Quality scoring detects:
- 🎵 Hi-res: DSD, SACD, 24-bit FLAC (192/176/96/88 kHz)
- 💿 Lossless: 16-bit FLAC, ALAC
- 🎸 Vinyl/LP rips (often superior mastering)
- 📀 Standard: 320kbps MP3, V0

#### 4. Smart Auto-Mode

Choose **[4] Just get it for me!** and the system tries strategies:

```
Strategy 1: Try single track
    ↓
  Wrong album detected?
    ↓
  ⚠️  Album mismatch! Continue...
    ↓
Strategy 2: Try full album
    ↓
  ✓ Found correct album!
    ↓
Strategy 3: Try other albums (if needed)
```

AI explains its decision with full reasoning.

#### 5. Top 3 Torrents

```
🧲 Magnet Links (Top 3):

[1] Iron Maiden - The Book Of Souls: Live Chapter (2017) [FLAC] ✓ SELECTED
    Format: FLAC | Size: 1.45 GB | Seeders: 17
    magnet:?xt=urn:btih:...

[2] Iron Maiden - The Book Of Souls: Live Chapter [2CD Japanese]
    Format: FLAC | Size: 755 MB | Seeders: 8
    magnet:?xt=urn:btih:...

[3] Iron Maiden - The Book Of Souls: Live Chapter (Alternative)
    Format: FLAC | Size: 755 MB | Seeders: 8
    magnet:?xt=urn:btih:...
```

Backup options if primary fails.

---

## 🚀 The Roadmap: From CLI to Trust Network

### Phase 0: ✅ CURRENT (v0.1.x)
**Goal:** Prove basic flow works

What works today:
- ✅ AI query parsing
- ✅ MusicBrainz metadata lookup
- ✅ Multi-indexer torrent search (18+ indexers via Jackett)
- ✅ Album-aware filtering
- ✅ Quality ranking
- ✅ Top 3 recommendations

### Phase 1: Network-First Search (Weeks 3-4)
**Goal:** Add distributed ledger

```
Search Flow Changes:

BEFORE (Phase 0):
User → MusicBrainz → External Indexers → Results

AFTER (Phase 1):
User → MusicBrainz → CHECK NETWORK FIRST → Results
                          ↓
                  Found verified files?
                    ↓              ↓
                   YES            NO
                    ↓              ↓
              Show those    → External Indexers
            (VERIFIED badge)        ↓
                                Merge results
                                    ↓
                        Rank: Verified > Quality > Seeders
```

Adds:
- Gun.js distributed ledger
- Vote tracking (local + network)
- Verified file badges
- Network-first search logic

**Success metric:** 80% of searches hit verified network files

### Phase 2: Two-Tier Validation (Weeks 5-6)
**Goal:** Community validation with proof

```
Vote Validation Flow:

Casual downloads file → Votes (+1/-1)
            ↓
    Vote enters PENDING queue
            ↓
  (visible to Core Listeners)
            ↓
    Core claims validation task
            ↓
  Core already has file?
    Yes → Validate instantly
    No → Download → Validate
            ↓
    Run validation proof:
    • Acoustic fingerprint (Chromaprint)
    • Spectral analysis (detect transcodes)
    • Format verification (ffprobe)
    • Metadata check
    • Sign with Ed25519 key
            ↓
    Core approves OR rejects
            ↓
  Approved: Casual +1 karma, Core +5-15 karma
  Rejected: Casual -2 karma, Core +5 karma
            ↓
  After X Core validations → File = VERIFIED
```

Adds:
- Core Listener role
- Validation queue interface
- Cryptographic proof system
- Karma economy
- Dynamic validation thresholds (popular files need fewer validations)

**Success metric:** Core listeners validate 50+ files, system prevents vote spam

### Phase 3: AI Intelligence (Weeks 7-8)
**Goal:** Learn from validation patterns

Adds:
- AI learns from Core validation decisions
- Ranking algorithm prioritizes verified files
- User preference learning
- Query intent improvements

**Success metric:** Top result is correct 80%+ of time

### Phase 4: Gamification (Weeks 9-10)
**Goal:** Social motivation

Adds:
- Badges (First Core, 100 Validations, Rare Content Seeder)
- Leaderboards (opt-in)
- Public profiles (opt-in)
- Progression milestones

**Success metric:** Users seed longer, vote more, Core recruitment increases

### Phase 5: Economic Sustainability (Month 4+)
**Goal:** Self-sustaining network

```
Revenue Model (IF network achieves scale):

Donations/Crypto
      ↓
Transparent distribution:
  • 95% → Content Creators (artists, labels who opt-in)
  • 5% → Network (split between Core validators & infrastructure)
      ↓
Using blockchain (Solana or similar):
  • Immutable transaction records
  • Transparent allocation
  • Community auditable
  • Team decides details IF traction achieved
```

Adds:
- Fiat/crypto payouts to Core Listeners
- Creator compensation framework (opt-in)
- Foundation/grant funding
- Economic transparency dashboard

**Success metric:** Trusted network established with high-quality validated content, network self-sustains, and transparent creator compensation achieved

---

## 🎓 Core Principles

### 1. Community-Governed, Not Corporate
```
❌ WRONG: Experts decide what's good
✓ RIGHT: Community votes → Core validates with proof
```

- No gatekeepers, only progression paths
- Earn karma → Become Core → Validate
- Transparent validation proofs (auditable)

### 2. Privacy by Default
- Votes are **pseudonymous** (hash of user ID)
- Downloads are **local-only** (SQLite on your machine)
- Identity is **never public** (unless you opt into leaderboards)
- No tracking, no data mining, no surveillance

### 3. Distributed Infrastructure
```
Gun.js Distributed Ledger

Node 1 (You) ←→ Node 2 (Core) ←→ Node 3 (Casual)
      ↓               ↓                ↓
  Local data    Validation        Vote data
      ↓               ↓                ↓
        All nodes sync automatically
              (no central server)
```

- No servers to maintain
- No infrastructure costs at scale
- No single point of failure
- Community runs the nodes

### 4. Open Source & Transparent
- All code is public
- All validation proofs are auditable
- All karma calculations are transparent
- All economic distributions are blockchain-recorded

### 5. Legal & Ethical
- **Respects DMCA takedowns** (network removes flagged content)
- Users responsible for legal compliance in their jurisdiction
- Not a piracy tool — it's music quality validation infrastructure
- Built for music discovery with community trust validation

### 6. Creator-Positive (Future Vision)
- If network achieves scale → transparent creator compensation
- Artists/labels can opt-in to payment distribution
- Blockchain ensures transparency and immutability
- Community decides allocation model

---

## 🛠️ Installation

### Requirements
- Python 3.10+
- MusicBrainz API key (free)
- AI API key (choose one: OpenAI, Anthropic, or Gemini)
- **Jackett API instance** (torrent indexer aggregator) - see setup below

### Quick Setup (Development)

**Option 1: Install in your current environment (easiest)**

```bash
# 1. Clone and install
git clone https://github.com/yourusername/karma-player
cd karma-player
pip install -e .

# 2. Initialize
karma-player init
# Enter MusicBrainz API key when prompted

# 3. Set AI key (choose one)
export ANTHROPIC_API_KEY="sk-ant-..."  # Recommended
# OR
export OPENAI_API_KEY="sk-..."
# OR
export GEMINI_API_KEY="..."

# 4. Search!
karma-player search "radiohead ok computer"
```

**Option 2: Use Poetry (for isolated development)**

```bash
# 1. Clone and install dependencies
git clone https://github.com/yourusername/karma-player
cd karma-player
poetry install

# 2. Run commands with 'poetry run'
poetry run karma-player init
poetry run karma-player search "radiohead ok computer"
```

**Get API Keys:**
- MusicBrainz: https://musicbrainz.org/account/applications
- Anthropic: https://console.anthropic.com/
- OpenAI: https://platform.openai.com/
- Gemini: https://ai.google.dev/

---

### ⚙️ Jackett Setup (Required)

**Karma Player requires a Jackett instance** to search torrent indexers. Jackett is a proxy server that translates queries into tracker-specific formats and aggregates results from 18+ indexers.

#### Option 1: Run Jackett Locally (Recommended for Privacy)

```bash
# Install Jackett
# macOS (Homebrew)
brew install jackett

# Linux (Debian/Ubuntu)
sudo apt install jackett

# Windows: Download from https://github.com/Jackett/Jackett/releases

# Start Jackett
jackett

# Access: http://localhost:9117
# Configure indexers, copy API key
```

Then during `karma-player init`, enter:
- Jackett URL: `http://localhost:9117`
- API key: (from Jackett web interface)

#### Option 2: Use a Remote Jackett Instance

If you're running Jackett on another machine or have access to a shared instance:

```bash
karma-player init
# Enter remote URL: https://your-jackett-instance.com
# Enter API key: (provided by instance admin)
```

#### Option 3: Request Team Access (Non-Technical Users)

**Don't have the technical skills or resources to run Jackett?**

Contact the team to request access to a shared Jackett instance:
- **GitHub Issues:** https://github.com/yourusername/karma-player/issues
  - Title: "Request Jackett Remote Access"
  - Include: Brief intro, why you're interested, commitment to learning self-hosting
- **Discord/Email:** [To be announced]

We provide temporary access to help you get started. Once provided:

```bash
# Set environment variables
export JACKETT_REMOTE_URL="https://provided-by-team.com"
export JACKETT_REMOTE_API_KEY="provided-api-key"

# Use remote profile (default)
karma-player search "radiohead ok computer" --profile remote
```

**Note:** Remote access is temporary and best-effort. We encourage self-hosting for privacy and reliability.

**Why self-hosting is better:**
- Complete privacy (your searches aren't visible to anyone)
- No rate limits or shared capacity issues
- Full control over which indexers to use
- No dependency on external services

---

### 🎛️ Advanced: Indexer Configuration

Karma Player supports **multiple indexer profiles** via `karma_player/indexers.yaml`. This lets you customize which torrent sources to search and switch between local/remote setups.

#### Default Profiles

**`local`** - Your own Jackett instance
```yaml
profiles:
  local:
    indexers:
      - name: jackett_local
        base_url: http://localhost:9117
        api_key: ${JACKETT_API_KEY}  # From config
        indexer_id: all  # Search all configured indexers
```

**`remote`** - Shared Jackett instance (18+ indexers)
```yaml
profiles:
  remote:  # Default profile
    indexers:
      - knaben, therarbg, torrentgalaxy, 1337x
      - thepiratebay, internetarchive, kickasstorrents
      - mixtapetorrent, nyaa, tokyotoshokan
      # ... 18+ indexers total
```

**`hybrid`** - Query both local and remote
**`lossless_only`** - FLAC/ALAC only (category 3040)

#### Switch Profiles

```bash
# Use local Jackett
karma-player search "miles davis" --profile local

# Use remote (default)
karma-player search "miles davis" --profile remote

# Lossless only
karma-player search "radiohead" --profile lossless_only
```

#### Customize Your Setup

Edit `karma_player/indexers.yaml`:

```yaml
# Change default profile
default_profile: local  # or remote, hybrid, lossless_only

# Add your own indexers
profiles:
  my_custom:
    description: "My personal setup"
    indexers:
      - name: my_jackett
        type: jackett
        enabled: true
        base_url: https://my-server.com:9117
        api_key: your-api-key
        indexer_id: all
        categories: [3040]  # Lossless only
        timeout: 20

# Disable specific indexers
profiles:
  remote:
    indexers:
      - name: thepiratebay
        enabled: false  # Skip this indexer
```

#### Audio Categories

Jackett uses category codes for filtering:
- `3000` - Audio (general)
- `3010` - MP3
- `3040` - **Lossless (FLAC, ALAC)** ← Hi-res audio
- `3020` - Video (music videos)
- `3030` - Audiobooks
- `3050` - Other

**Pro tip:** Use `lossless_only` profile for audiophile searches.

> **Note:** PyPI package coming soon. For now, install from source.

---

## 🎮 Usage Examples

> **Note:** Examples assume you installed with `pip install -e .` or activated `poetry shell`. If using Poetry without shell, prefix commands with `poetry run`.

### Basic Search
```bash
karma-player search "Miles Davis Kind of Blue"
```

AI finds the canonical album, searches 18+ indexers, returns best FLAC.

### Format Preference
```bash
# Prefer FLAC, fallback to MP3 if none found
karma-player search "Pink Floyd Dark Side" --format FLAC

# ONLY FLAC (strict, no fallback)
karma-player search "Radiohead OK Computer" --format FLAC --strict
```

### Auto-Mode (Let AI Handle Everything)
```bash
karma-player search "fear of the dark iron maiden"
# Select album → Choose [4] Just get it for me!
# System tries: single track → album → other albums
```

### Fast Mode (Skip MusicBrainz)
```bash
karma-player search "esperanza spalding" --skip-musicbrainz --min-seeders 5
```

Direct torrent search. Faster but less accurate.

### Check Configuration
```bash
karma-player config show
```

---

## 🤝 How This Compares

### vs Spotify / Apple Music
- **Them:** You rent access. They decide what's available.
- **Us:** Community owns the trust network. You decide what to download.

### vs What.CD / Redacted
- **Them:** Interview process. Invite trees. Ratio requirements. Expert gatekeeping.
- **Us:** Open access (donation or invitation). Two-tier validation. Anyone can progress to Core.

### vs Public Torrent Sites
- **Them:** 50 results. No quality control. Decision paralysis. Fake files.
- **Us:** Network validates once. Everyone benefits forever. AI picks best match.

### vs Soulseek
- **Complementary, not competing**
- Soulseek serves audiophiles well (by design, technically complex to maintain quality)
- We believe casual listeners deserve awesome audio too
- Our goal: Make BEST audio quality accessible to everyone through community validation
- If Soulseek wants to integrate as a search source, we're open (MusicBrainz metadata + trust validation could complement their network)

### What Makes TTN Different

```
Private Trackers:  Quality ✓  Access ✗  (gatekeeping)
Public Torrents:   Access ✓  Quality ✗  (no validation)
Trust Tune:        Access ✓  Quality ✓  (community validation)
```

**The bet:** Combining MusicBrainz (canonical metadata) + distributed validation (community proof) + AI (intent understanding) creates something better than gatekeeping OR anarchy.

---

## 📊 Current Status

### ✅ Working Today (v0.1.1)
- AI query parsing (multi-provider)
- MusicBrainz metadata lookup
- Multi-indexer torrent search (18+ indexers)
- Album-aware filtering with mismatch detection
- Quality ranking (hi-res detection)
- Auto-mode with fallback strategies
- Top 3 torrent recommendations
- Detailed AI reasoning

### 🚧 Coming Soon (Phase 1 - Next 2 Weeks)
- Gun.js distributed ledger
- Network-first search (check verified files first)
- Vote tracking (local + network)
- Pending validation queue
- Verified file badges

### 📅 Not Yet Implemented (Phase 2+)
- Core Listener role and application process
- Cryptographic validation proof system
- Karma economy and progression paths
- Creator compensation framework
- Economic sustainability model

---

## 🧪 Development

### Dev Setup
```bash
git clone https://github.com/yourusername/karma-player
cd karma-player
poetry install
poetry run karma-player init
```

### Run Tests
```bash
poetry run pytest              # Run all tests
poetry run pytest --cov        # With coverage
```

**Current test status:** 97/103 passing (94% pass rate)

### Contribute

We're looking for:
- **Early adopters** to test Phase 0
- **Core Listener candidates** (audiophiles, engineers, musicians)
- **Developers** to build Phase 1+
- **Feedback** on the vision

See:
- [docs/EPICS_TASKS.md](docs/EPICS_TASKS.md) - Development tasks
- [docs/mvp_vision.md](docs/mvp_vision.md) - Full technical vision

---

## 💭 Philosophy: Building Trust at Scale

> *"The internet has infinite content. The problem isn't access — it's knowing what/where to trust."*

### The Old Model: Gatekeeping
```
Private trackers solved quality with exclusivity:
  Interviews → Invite trees → Ratio requirements
        ↓
  Only "experts" validate
        ↓
  High quality, low accessibility
```

### The New Model: Community Validation
```
Trust Tune solves quality with distributed proof:
  Casual votes → Core validates with proof → Network trusts
        ↓
  Anyone can participate at their level
        ↓
  High quality, high accessibility
```

### Why This Works

**Network effects:**
- More users → More votes → More validation work
- More Core Listeners → Faster validation → More verified files
- More verified files → Better search results → More users

**Economic alignment:**
- Casuals benefit from validated network
- Core benefits from compensation (future)
- Creators benefit from transparent payments (future)
- Everyone benefits from trust infrastructure

**Technical soundness:**
- Cryptographic proofs prevent spam
- Pseudonymous votes preserve privacy
- Distributed ledger prevents censorship
- Open source enables auditing

**Social scalability:**
- Two-tier system separates participation levels
- Karma progression creates clear path to Core
- Transparent validation builds trust
- Community governance prevents capture

---

## 🌍 Focus: Music Quality First

**Karma Player is built specifically for music.**

Why music?
- Clear, measurable quality metrics (format, bitrate, spectral analysis)
- Canonical metadata already exists (MusicBrainz)
- Passionate community (audiophiles) ready to validate
- Acoustic fingerprinting tech is mature (Chromaprint)
- Audio quality matters deeply to listeners

The validation principles *could* theoretically apply to other content types (software integrity, document preservation, educational materials), but **we're laser-focused on music**. Better to do one thing exceptionally well than many things poorly.

---

## ⚖️ Legal & Ethical Framework

### DMCA Compliance
- Network respects DMCA takedown requests
- Flagged content removed from distributed ledger
- Users notified of removals (transparency)
- Appeal process for false positives

### User Responsibility
- Users responsible for legal compliance in their jurisdiction
- Tool facilitates search and metadata, not distribution
- No hosting, no storage, no servers

### Creator-Positive Approach
**We're committed to building the best open analytics possible for creators.**

**Our belief:**
- Awesome music exists **beyond** label-controlled recordings where creators aren't paid fairly
- Artists **want** their music heard worldwide — it builds awareness, strengthens their brand, and creates opportunities (more shows, more fans, more demand)
- Labels often restrict access and take the lion's share, leaving creators with pennies

Unlike streaming platforms (often black boxes with hidden metrics):
- **Full transparency**: Every play, vote, validation is visible
- **Open analytics dashboard**: Who's listening, where, quality preferences, trending patterns
- **No hidden algorithms**: Creators see exactly how their music performs
- **Direct compensation** (if network achieves scale):
  - 95% of revenue → Creators who opt-in
  - Blockchain-recorded payments (Solana or similar)
  - Community-decided allocation model
  - Immutable, auditable transaction history

**The vision:** Worldwide reach increases artist awareness and opportunities. Better analytics + direct compensation + global distribution = creators actually benefit from sharing their work.

**Goal:** Prove you can build trust infrastructure that empowers creators with transparency, respects users' privacy, and remains decentralized.

---

## 🎯 Success Metrics

### Phase 0 (Current)
- ✅ 10+ users successfully search and download
- ✅ AI selects correct album 80%+ of time
- ✅ System handles edge cases (album mismatch, format fallback)

### Phase 1 (Weeks 3-4)
- 100+ files with vote counts in network
- 80%+ of searches hit verified files
- <500ms network query latency

### Phase 2 (Weeks 5-6)
- 20+ active Core Listeners
- 50+ files with VERIFIED status
- <1 week average validation time for popular files
- Zero vote spam incidents

### Long-Term (Months 4+)
- Trusted network with distributed validation infrastructure
- Exceptional audio quality (verified FLAC, hi-res, proper masters)
- 100,000+ verified files across 1,000+ Core Listeners
- 10,000+ active users contributing votes and seeding
- Self-sustaining economics with transparent creator compensation

---

## 🙏 Credits & Inspiration

### Built With
- [MusicBrainz](https://musicbrainz.org/) - Canonical music metadata
- [Jackett](https://github.com/Jackett/Jackett) - Torrent indexer aggregation
- [LiteLLM](https://github.com/BerriAI/litellm) - Multi-provider AI abstraction
- [Click](https://click.palletsprojects.com/) - CLI framework
- [Gun.js](https://gun.eco/) - Distributed graph database (Phase 1+)

### Inspired By
- **What.CD / Redacted** - Curator-validated quality (but we add: open access, two-tier system)
- **Soulseek** - Decentralized sharing (potential integration partner)
- **BitTorrent** - Distributed protocol (we add: trust layer)
- **Bitcoin** - Proof-of-work validation (we use: proof-of-analysis)
- **Wikipedia** - Community validation (we add: cryptographic proof)

---

## 📧 Get Involved

**Project Status:** Phase 0 (MVP) - Proving the concept

**We're looking for:**
- 🎧 Early adopters to test and provide feedback
- 🎵 Audiophiles interested in becoming Core Listeners
- 💻 Developers to build Phase 1+ (Gun.js, validation proofs)
- 💰 Potential donors to fund development
- 🤝 Partners (Soulseek integration? MusicBrainz collaboration?)

**How to help:**
1. Try Karma Player and give feedback
2. Join discussions about validation approaches
3. Contribute code (see [docs/EPICS_TASKS.md](docs/EPICS_TASKS.md))
4. Spread the word to audiophile communities
5. Donate to fund Phase 1+ development

---

## 📝 License

[License TBD - will be open source]

---

```
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║   The Trust Tune Network is growing.                      ║
║                                                            ║
║   Not by gatekeeping. Not by algorithms.                  ║
║   By community validation, one proof at a time.           ║
║                                                            ║
║   Join us. Build trust.                                   ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
```

**Phase 0 is live. Phase 1 is coming. The network is waiting for you.**
