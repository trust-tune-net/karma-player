# 🎵 TrustTune Vision: Music Discovery for Everyone

> **Mission:** Make high-quality music discovery as simple as asking a question.
> **For:** Your grandmother, your friend, anyone who loves music.
> **No:** Complex settings, API keys, torrent knowledge required.

---

## Table of Contents

- [The Problem](#the-problem)
- [The Solution](#the-solution)
- [The Experience](#the-experience)
- [Technical Architecture](#technical-architecture)
- [Community API Model](#community-api-model)
- [Revenue Model](#revenue-model)
- [Roadmap](#roadmap)
- [Success Metrics](#success-metrics)

---

## The Problem

### Current State of Music Discovery

**Streaming Services (Spotify, Apple Music):**
- ✅ Easy to use
- ❌ Artists earn $0.003 per stream
- ❌ Compressed audio (256kbps AAC)
- ❌ Requires subscription ($10-15/month)
- ❌ Music disappears when you stop paying

**Torrent Sites:**
- ✅ High quality (FLAC, lossless)
- ✅ Own your music forever
- ❌ Complex (need torrent client, VPN knowledge)
- ❌ Hard to find quality files
- ❌ No trust/verification
- ❌ Technical users only

**Current karma-player CLI:**
- ✅ AI-guided search
- ✅ Quality scoring
- ✅ Smart filtering
- ❌ Command-line only
- ❌ Requires Python knowledge
- ❌ Manual file management
- ❌ For developers only

### The Gap

**There's no tool that:**
1. Makes high-quality music discovery **simple**
2. Works for **non-technical users**
3. Provides **conversational guidance**
4. Handles **everything automatically**
5. Is **free and sustainable**

---

## The Solution

### TrustTune: Conversational Music Discovery

**One-sentence pitch:**
> "Like talking to a music-savvy friend who finds you the perfect recordings—and downloads them for you."

### Core Principles

1. **Conversational** - AI asks questions, understands context
2. **Intelligent** - Multi-source search (torrents, Reddit, RYM)
3. **Automatic** - Download, organize, tag, play—all built-in
4. **Simple** - Zero configuration, works out of box
5. **Free** - Community API with generous limits
6. **Protocol-First** - Federation-ready for Phase 2+

---

## The Experience

### Installation (One-Click)

**macOS:**
```
1. Download TrustTune.dmg
2. Drag to Applications
3. Open → First-run wizard (30 seconds)
4. Done. Start searching.
```

**Windows:**
```
1. Download TrustTune-Setup.exe
2. Run installer (auto-installs everything)
3. Launch → First-run wizard
4. Done. Start searching.
```

**First-Run Wizard:**
```
┌─────────────────────────────────────────┐
│  Welcome to TrustTune! 🎵               │
│                                         │
│  Quick setup:                           │
│                                         │
│  Where should I save your music?        │
│  [~/Music] [Choose Folder...]          │
│                                         │
│  That's it! Let's find some music.     │
│  [Get Started]                          │
└─────────────────────────────────────────┘
```

### Search Flow (Conversational)

**Step 1: User Input**
```
┌─────────────────────────────────────────┐
│  🎵 What music are you looking for?     │
│  ┌─────────────────────────────────┐   │
│  │ radiohead ok computer           │   │
│  └─────────────────────────────────┘   │
│  [Search]                               │
└─────────────────────────────────────────┘
```

**Step 2: AI Questions (2-3 max)**
```
┌─────────────────────────────────────────┐
│  💬 Quick Questions                     │
│                                         │
│  Which version?                         │
│  ● Studio Album (1997)                  │
│  ○ Live Performances                    │
│  ○ Rare Demos & B-Sides                 │
│                                         │
│  Quality preference?                    │
│  ● Best Available (FLAC, slower)        │
│  ○ Good Quality (MP3 320, faster)       │
│                                         │
│  [Continue]                             │
└─────────────────────────────────────────┘
```

**Step 3: Proactive Discovery**
```
┌─────────────────────────────────────────┐
│  💡 I Found Something Special           │
│                                         │
│  While searching, I found Reddit posts  │
│  mentioning these amazing recordings:   │
│                                         │
│  • Live at Glastonbury 1997            │
│    (r/radiohead: "Best live version")  │
│                                         │
│  • OKNOTOK 1997-2017 Remaster          │
│    (r/vinyl: "Definitive edition")     │
│                                         │
│  Include these in search?               │
│  [Yes, show all]  [No, just album]     │
└─────────────────────────────────────────┘
```

**Step 4: Results (AI-Ranked)**
```
┌─────────────────────────────────────────┐
│  ✨ Here's What I Found                 │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ ✅ BEST MATCH                    │  │
│  │ Radiohead - OK Computer (1997)   │  │
│  │                                  │  │
│  │ 💎 FLAC 24-bit/96kHz | 1.2 GB   │  │
│  │ 🌱 52 seeders | Fast download    │  │
│  │ ✓ Verified uploader              │  │
│  │                                  │  │
│  │ "Original studio masters,        │  │
│  │  remastered from analog tapes.   │  │
│  │  Audiophile quality."            │  │
│  │                                  │  │
│  │  [▶ Download & Play]             │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ Good Alternative                 │  │
│  │ OK Computer (1997)               │  │
│  │ MP3 320kbps | 145 MB | 98 seeds  │  │
│  │ "Fast download, excellent quality"│ │
│  │  [Download]                      │  │
│  └──────────────────────────────────┘  │
│                                         │
│  + 3 more options [Show More ▼]        │
└─────────────────────────────────────────┘
```

**Step 5: Download Progress**
```
┌─────────────────────────────────────────┐
│  ⏬ Downloading OK Computer             │
│                                         │
│  ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░ 68% (820 MB/1.2 GB)│
│  ↓ 8.4 MB/s | ⏱ 45 seconds left        │
│                                         │
│  Saving to: ~/Music/Radiohead/         │
│  Auto-seeding: ↑ 2.1 MB/s (sharing)   │
│                                         │
│  [Pause] [Play While Downloading]      │
└─────────────────────────────────────────┘
```

**Step 6: Ready to Enjoy**
```
┌─────────────────────────────────────────┐
│  ✅ OK Computer Ready!                  │
│                                         │
│  🎵 Now Playing: Airbag                │
│  ──●────────────── 1:23 / 4:44         │
│  [⏮] [⏸] [⏭]  🔊 ────●────           │
│                                         │
│  📁 Saved to: ~/Music/Radiohead/       │
│  📊 Album: 12 tracks, all tagged       │
│  🌱 Still seeding (helping others)     │
│                                         │
│  [Open Folder] [Add to Library]        │
└─────────────────────────────────────────┘
```

### What User Never Sees

- ❌ API keys or configuration
- ❌ Torrent clients or magnet links
- ❌ File paths or folders (unless they want to)
- ❌ MusicBrainz or metadata complexity
- ❌ Quality scoring algorithms
- ❌ Indexer selection

**Just: Search → Questions → Download → Play**

---

## Technical Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────┐
│  TrustTune Desktop App (Flutter)            │
│  ┌───────────────────────────────────────┐  │
│  │ UI Layer                              │  │
│  │ - Search screen (conversational)      │  │
│  │ - Results display (AI explanations)   │  │
│  │ - Download manager (progress bars)    │  │
│  │ - Music player (built-in)             │  │
│  └───────────────────────────────────────┘  │
└──────────────────┬──────────────────────────┘
                   │ HTTP/WebSocket
┌──────────────────▼──────────────────────────┐
│  Local Python Service (FastAPI)             │
│  ┌───────────────────────────────────────┐  │
│  │ Core Services                         │  │
│  │ - Transmission RPC wrapper            │  │
│  │ - File organizer (tagging, moving)    │  │
│  │ - Audio player backend (mpv)          │  │
│  │ - Local database (SQLite)             │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────────────────────────────┐  │
│  │ Search Aggregator                     │  │
│  │ - DHT search (torrent network)        │  │
│  │ - Jackett integration (optional)      │  │
│  │ - Reddit scraper (quality signals)    │  │
│  │ - RateYourMusic scraper               │  │
│  └───────────────────────────────────────┘  │
└──────────────────┬──────────────────────────┘
                   │ HTTPS (rate-limited)
┌──────────────────▼──────────────────────────┐
│  TrustTune Community API                    │
│  api.trusttune.community                    │
│  ┌───────────────────────────────────────┐  │
│  │ AI Services (rate-limited)            │  │
│  │ - Query parsing (Groq Llama 3.1)      │  │
│  │ - MusicBrainz filtering (GPT-4o-mini) │  │
│  │ - Result explanation (Claude Haiku)   │  │
│  │ - Reddit analysis (local Mistral)     │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────────────────────────────┐  │
│  │ Rate Limiting & Auth                  │  │
│  │ - Anonymous: 50 searches/day          │  │
│  │ - Free account: 200 searches/day      │  │
│  │ - Contributor: 1000 searches/day      │  │
│  │ - API key: Custom limits              │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### Technology Stack

| Component | Technology | Why |
|-----------|-----------|-----|
| **Desktop GUI** | Flutter | Cross-platform, beautiful, native |
| **Backend** | Python + FastAPI | Existing codebase, rich ecosystem |
| **Torrent Client** | Transmission (via RPC) | Mature, stable, process isolation |
| **Audio Player** | media_kit (MPV) | Like Spotube, plays everything |
| **Database** | SQLite | Local-first, zero config |
| **AI (Community)** | Groq (Llama 3.1 70B) | Free tier, 500 tok/sec |
| **AI (Fallback)** | Together.ai, Mistral | Multiple free providers |
| **Metadata** | MusicBrainz API | Canonical music database |
| **Search** | DHT + Jackett | Distributed + centralized |
| **Packaging** | electron-builder | Easy distribution |

### Data Flow

```
User Input: "radiohead ok computer"
     ↓
Flutter GUI
     ↓ (WebSocket)
Local Python Service
     ↓ (HTTPS)
Community API: Parse query
     ← {artist: "Radiohead", album: "OK Computer"}
     ↓
MusicBrainz Lookup
     ← {mbid: "abc123", year: 1997, ...}
     ↓ (HTTPS)
Community API: Filter 25 MB results
     ← {best_match: {...}, reasoning: "..."}
     ↓
Multi-Source Search:
  - DHT torrent search
  - Jackett (if configured)
  - Reddit scraper (r/radiohead, r/vinyl)
     ↓
Aggregate 50+ results
     ↓ (HTTPS)
Community API: Rank & explain
     ← {top_3: [...], explanations: [...]}
     ↓
Display to User
     ↓ (User clicks Download)
Transmission daemon: Download torrent
     ↓ (Progress updates via WebSocket)
Flutter: Show progress bar
     ↓ (Download complete)
Python: Tag files, move to ~/Music
     ↓
Flutter: "Ready to play!"
```

---

## Community API Model

### Why Community API?

**Testing Results:**
- ✅ Local LLM (Ollama Phi-3.5): Too slow on M1 16GB (2-5s per query)
- ✅ Cloud API (Groq): Fast (200ms), free tier generous
- ✅ Hybrid: Best UX without cost

**Problem with Local:**
```
M1 MacBook Pro 16GB:
- Ollama Phi-3.5 (3.8B): 2-3 seconds per query
- User perception: "App is frozen"
- Bad UX for conversational flow
```

**Solution: Community API**
```
Groq Llama 3.1 70B:
- 200ms per query (15x faster!)
- Free tier: 14,400 requests/day
- User perception: "Instant response"
- Great UX
```

### API Endpoints

```
https://api.trusttune.community/v1/

POST /search/parse
  Input: {query: "radiohead ok computer"}
  Output: {artist: "Radiohead", album: "OK Computer", ...}
  Cost: 1 token (of daily limit)

POST /musicbrainz/filter
  Input: {results: [...25 albums], query: {...}}
  Output: {best_match: {...}, reasoning: "..."}
  Cost: 2 tokens

POST /torrents/rank
  Input: {torrents: [...50 results], preferences: {...}}
  Output: {ranked: [...], explanations: [...]}
  Cost: 3 tokens

GET /user/quota
  Output: {used: 15, limit: 50, resets_at: "..."}
```

### Rate Limiting Tiers

| Tier | Daily Limit | Signup | Cost |
|------|-------------|--------|------|
| **Anonymous** | 50 searches | None | Free |
| **Free Account** | 200 searches | Email | Free |
| **Contributor** | 1,000 searches | Seed + validate | Free |
| **Supporter** | 5,000 searches | $5/month | Paid |
| **API Key** | Custom | $20/month | Paid |

**Anonymous Usage:**
- No account needed
- Device fingerprint (privacy-friendly)
- 50 searches/day ≈ 17 searches if all steps used
- Perfect for trial users

**Free Account:**
- Email verification (no spam)
- 200 searches/day ≈ 66 full searches
- Enough for daily power users

**Contributor:**
- Earn searches by:
  - Seeding torrents (1 search per 10GB uploaded)
  - Validating quality (listen + rate)
  - Reporting bad results
- Gamification + sustainability

### Infrastructure Cost

**Free Tier Budget:**

```
Groq Free Tier:
- 14,400 requests/day per account
- 10 accounts = 144,000 requests/day
- Average search = 3 API calls
- = 48,000 searches/day capacity
- = Support 240 daily active users (200 searches each)

Together.ai:
- $25/month free credits × 10 accounts
- = $250/month compute
- Fallback for overflow

Total cost: $0/month (pure free tiers)
```

**When we need to pay (at scale):**

```
1,000 daily users × 10 searches/day × 3 API calls
= 30,000 API calls/day

Cost:
- Groq: $0 (within free tier)
- Together.ai fallback: ~$50/month
- Server hosting: $20/month (small VPS)
= $70/month total

Revenue (if 10% become supporters):
- 100 users × $5/month = $500/month
- Profit: $430/month
- Sustainable!
```

### API Server Stack

```
api.trusttune.community/

Tech:
- FastAPI (Python)
- Redis (rate limiting)
- PostgreSQL (user accounts, quota tracking)
- Multiple AI providers (Groq, Together, Mistral)
- Automatic failover

Hosting:
- Railway.app / Fly.io (free tier initially)
- Cloudflare (CDN + DDoS protection)
- Backup: Vercel serverless functions
```

### Privacy & Security

**Data We Store:**
- ✅ Search queries (for improving AI)
- ✅ API usage stats (rate limiting)
- ❌ Downloaded files (never)
- ❌ Music library (never)
- ❌ Personal info beyond email (never)

**Encryption:**
- TLS 1.3 for all API calls
- Optional: E2E encryption for queries (user choice)
- No tracking cookies
- No third-party analytics

**Open Source:**
- API server code: Open source (community can run own)
- AI prompts: Public (transparency)
- Rate limiting rules: Public

---

## Revenue Model

### Phase 0: Free (Community-Funded)

**No monetization initially.** Focus on:
1. Building great product
2. Growing user base
3. Community engagement

**Funding:**
- Personal funds
- Patreon/Ko-fi donations
- Open Collective (transparent)

### Phase 1: Freemium (Sustainability)

**Free Tier (95% of users):**
- 200 searches/day (generous)
- All core features
- Community support

**Supporter Tier ($5/month):**
- 5,000 searches/day
- Priority support
- Early access to features
- Support development

**What We DON'T Do:**
- ❌ Ads (never)
- ❌ Sell user data (never)
- ❌ Paywalled core features
- ❌ Dark patterns

### Phase 2: Protocol (Decentralization)

**TrustTune as a Protocol:**
- Anyone can run API server
- Federation between servers
- Users choose provider
- Compete on quality/price

**Official API:**
- Still free tier (flagship)
- Premium for convenience
- But alternatives available

### Phase 3: Creator Payments (The Vision)

**95% to Artists:**
- Users pay $10/month
- $9.50 goes to artists they listen to
- Blockchain-verified payments
- Transparent split

**This is the REAL revenue model.**
Phase 0-2 are stepping stones.

---

## Roadmap

### Phase 0: MVP (Months 1-3)

**Goal:** Beautiful, working GUI that Grandma can use

**Features:**
- ✅ Flutter desktop app (macOS, Windows, Linux)
- ✅ Conversational search (2-3 questions max)
- ✅ Multi-source search (DHT + Jackett + Reddit)
- ✅ AI ranking & explanation (Community API)
- ✅ Built-in torrent download (Transmission)
- ✅ Built-in music player (media_kit)
- ✅ Auto file organization
- ✅ Zero configuration

**Metrics:**
- 100 beta testers
- 80% find it "easy to use"
- Average 5 searches/day/user

### Phase 1: Community (Months 4-6)

**Goal:** Build trust network foundations

**Features:**
- User accounts (optional)
- Curator feeds (follow people with good taste)
- Quality validation (rate downloads)
- Trust scores (community reputation)
- Contributor rewards (earn searches)

**Metrics:**
- 1,000 active users
- 50 active curators
- 10,000 validated torrents

### Phase 2: Federation (Months 7-12)

**Goal:** Decentralize the network

**Features:**
- TrustTune protocol spec (open standard)
- Federation (servers talk to each other)
- P2P trust network (Gun.js)
- Run your own instance
- Mobile apps (iOS, Android)

**Metrics:**
- 10,000 active users
- 10 federated servers
- 100% uptime (distributed)

### Phase 3: Economics (Year 2+)

**Goal:** Fair creator compensation

**Features:**
- Blockchain payments
- Creator verification
- Revenue split (95% to artists)
- Validator rewards
- Full decentralization

**Metrics:**
- $100,000/month to artists
- 50,000 active users
- 500 verified creators

---

## Success Metrics

### Product Metrics (Phase 0)

**Grandma Test:**
- Can a non-technical person use it? (Yes/No)
- Do they find music in <2 minutes? (Yes/No)
- Do they understand what's happening? (Yes/No)

**Usage Metrics:**
- Daily active users (DAU)
- Searches per user per day
- Download success rate (%)
- Time from search to playing (seconds)

**Quality Metrics:**
- User satisfaction (1-10 rating)
- Download quality issues reported (%)
- App crash rate (%)

### Community Metrics (Phase 1)

**Engagement:**
- Curator signups
- Torrents validated per day
- Trust score distribution
- Contributor earn rate

**Health:**
- Community moderation needed
- False positives reported
- Trust network density

### Network Metrics (Phase 2)

**Decentralization:**
- Federated servers count
- Server uptime (%)
- Cross-server queries per day
- Protocol adoption (external clients)

**Scale:**
- Total users across network
- Data replicated (GB)
- Search latency (p95, ms)

### Economic Metrics (Phase 3)

**Revenue:**
- Monthly recurring revenue (MRR)
- Churn rate (%)
- Average revenue per user (ARPU)

**Creator Value:**
- Total paid to artists ($)
- Average payment per artist
- Artist signup rate

---

## Why This Will Work

### 1. **Real Problem**
People want high-quality music without complexity. Current solutions force tradeoffs.

### 2. **Simple Solution**
Conversational AI + automated everything = Grandma-friendly.

### 3. **Sustainable Model**
Free tier (Community API) → Paid tier (Supporters) → Creator payments (Long-term)

### 4. **Protocol-First**
Not building a company, building a protocol. Decentralization prevents lock-in.

### 5. **Community-Driven**
Curators, validators, contributors = Network effects.

### 6. **Transparent & Ethical**
- Open source
- Privacy-first
- No ads
- Fair to artists

---

## Risks & Mitigations

### Risk 1: Legal (Torrent Liability)

**Concern:** Napster precedent, DMAA takedowns

**Mitigation:**
- No hosted torrents (just search)
- No DRM circumvention
- Community API geofenced (if needed)
- Protocol is legal (like BitTorrent itself)
- Users responsible for downloads

### Risk 2: API Costs at Scale

**Concern:** Free tier can't support 10k users

**Mitigation:**
- Freemium converts 5-10% (industry standard)
- 500 supporters × $5 = $2,500/month
- API costs: ~$500/month at 10k users
- Profit margin: 80%

### Risk 3: AI Quality

**Concern:** Community API AI makes mistakes

**Mitigation:**
- Multiple fallback providers
- User can always see all results
- Community validation (Phase 1)
- Continuous prompt improvement

### Risk 4: User Adoption

**Concern:** People stick with Spotify

**Mitigation:**
- Target audiophiles first (quality matters)
- Vinyl collectors (own music mentality)
- Privacy advocates (no tracking)
- Musicians (fair payment story)

---

## Next Steps

### Immediate (This Week)

1. **Set up project structure**
   - karma_player/ (Python core)
   - karma-player-gui/ (Flutter)
   - docs/ (vision, specs)

2. **Spike: Community API**
   - Deploy simple FastAPI server
   - Integrate Groq
   - Test rate limiting

3. **Spike: Flutter + FastAPI**
   - Basic search UI
   - HTTP client
   - WebSocket connection

### Short-Term (Month 1)

1. **Build MVP core:**
   - Conversational search UI
   - Community API integration
   - MusicBrainz + torrent search
   - Basic download manager

2. **Deploy Community API:**
   - Railway.app hosting
   - Groq integration
   - Rate limiting (50/day anonymous)

3. **Alpha testing:**
   - 10 users
   - Gather feedback
   - Iterate

### Medium-Term (Months 2-3)

1. **Complete MVP features:**
   - Built-in player
   - File organization
   - Installer packages

2. **Public beta:**
   - 100 users
   - Community API monitoring
   - Scale infrastructure

3. **Documentation:**
   - User guide
   - API docs
   - Contributing guide

---

## Conclusion

**TrustTune is not just an app—it's a new way to discover music.**

**Phase 0:** Beautiful GUI anyone can use
**Phase 1:** Community trust network
**Phase 2:** Federated protocol
**Phase 3:** Fair creator economy

**Start simple. Scale responsibly. Stay ethical.**

---

*Last updated: January 2025*
*Version: 1.0.0*
*Status: Pre-MVP*
