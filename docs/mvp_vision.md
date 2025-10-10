# Updated MVP Vision: Network-First, Two-Tier Validation

You're absolutely right. Let me think high-level.

---

## Core Concept

**An AI-powered music search tool that abstracts torrent complexity by maintaining a distributed network of verified files, validated by a two-tier community of casual listeners and expert curators.**

### The Key Insight

Instead of sending users into the wild west of torrent sites, we build a **trust network** where:
- Files are validated once by experts
- Everyone benefits from that validation forever
- The network becomes self-reinforcing (more users = more validated content)

---

## Architecture Philosophy

### 1. Search Flow: Network First, External Fallback

```
User searches "radiohead paranoid android"
  ↓
AI parses intent → MusicBrainz gets canonical MBID
  ↓
CHECK OUR NETWORK FIRST (Gun.js distributed ledger)
  ↓
Found verified files? → Show those (prioritized)
  ↓
Not found? → Search external indexers as fallback
  ↓
Merge results, rank by: verification > quality > seeders
```

**Why this matters:** 80% of searches hit verified network files. Users skip the "which torrent?" decision entirely.

### 2. Two-Tier User System

**Casual Listeners (95% of users)**
- Search, download, listen
- Vote on files (but votes need Core approval)
- Optional seeding
- Limited karma (0-100 range)
- Can progress to Core status

**Core Listeners (5% of users - the validators)**
- Validate pending votes from Casuals
- Run network infrastructure (Gun.js nodes)
- Seed rare content long-term
- High karma (100-10,000+)
- Future: Compensated in fiat/crypto

**Think of Core listeners as "miners"** - they do computational/verification work to validate transactions (votes), earn rewards (karma/money), and maintain network integrity.

### 3. Vote Validation Flow

```
Casual downloads file → Upvotes it
  ↓
Vote enters PENDING queue (visible to Core listeners)
  ↓
Core listener claims task:
  - Already has file? → Validate instantly
  - Don't have it? → Download, then validate
  ↓
Core runs validation proof:
  - Acoustic fingerprint (proves correct song)
  - Spectral analysis (proves quality/no transcode)
  - Format check (proves claimed format)
  - Size sanity check
  ↓
Core approves OR rejects
  ↓
If approved: Casual +1 karma, Core +5-15 karma
If rejected: Casual -2 karma, Core +5 karma
  ↓
After X Core approvals → File marked VERIFIED
```

**Dynamic thresholds:**
- Popular files (50+ seeders) need 2-3 Core validations
- Rare files (<5 seeders) need 5-7 Core validations  
- New MBID mappings need extra scrutiny
- High-karma Casuals need fewer validations

### 4. Validation Proof (The Technical Core)

Core listeners don't just "vote" - they provide **cryptographic proof** they actually listened and analyzed:

**Certificate contains:**
- File hash (SHA256)
- Acoustic fingerprint (Chromaprint via AcoustID)
- Format analysis (ffprobe output)
- Spectral analysis results (frequency cutoff, transcode detection)
- Metadata check
- Signed with validator's Ed25519 key

**This prevents:**
- Vote spam (must download + analyze)
- Collusion (can verify validators did the work)
- Bad actors (certificates are public, auditable)

### 5. Access Control: Invitation + Donation

Following Soulseek's proven model:

**Option A: Invitation code**
- Distributed personally or on Reddit
- Each user earns invitation codes via karma milestones
- Creates trusted onboarding path

**Option B: Donate**
- $5-20 suggested donation
- Funds infrastructure (Gun.js bootstrap nodes)
- Future: Funds Core listener rewards

**Why both?**
- Invitations = community trust chain
- Donations = open access + funding
- Prevents spam while remaining accessible

---

## Ranking Algorithm (High Level)

### Results Shown in Tiers:

**Tier 1: VERIFIED network files (our gold standard)**
- Score: 80-100 points
- Factors: verification strength, validator quality, format match, seeders

**Tier 2: LIKELY_GOOD network files (trending positive)**
- Score: 60-80 points
- Has some Core approvals, no rejections yet

**Tier 3: PENDING network files (new/unvalidated)**
- Score: 40-60 points
- In network but awaiting validation

**Tier 4: External files (unknown quality)**
- Score: 20-70 points
- From torrent indexers, ranked by seeders + heuristics

**Tier 5: REJECTED files (shown as warning only)**
- Score: 0 points
- Core listeners rejected, avoid

**User sees:** Top option first (usually Tier 1), then descending. 80% of time, top result is what they want.

---

## Karma Economy

### Casual Listeners Earn Karma By:
- +1: Vote approved by Core listeners
- +1: Seeding for 7+ days
- -2: Vote rejected by Core listeners
- -5: Not seeding after download

### Core Listeners Earn Karma By:
- +5: Correctly validate standard file
- +10: Validate rare file (<5 seeders)
- +20: Long-term seed rare content (30+ days)
- +50: First to validate new MBID mapping
- -10: Incorrectly validate (approve bad file)
- -20: Pattern of collusion detected

### Progression Path:
```
New User (0 karma)
  → Active Casual (10+ karma)
  → Trusted Casual (50+ karma)
  → Core Candidate (100+ karma)
  → Apply for Core status (pass validation test)
  → Core Listener (validated)
```

**Core application:** Must pass 3 test validations (pre-validated files, candidate doesn't know) with 90%+ accuracy.

---

## Data Architecture

### Local (SQLite on user's machine):
- User identity, API keys
- Download history
- Play counts, search history
- Seeding sessions
- Vote history (what you voted on)

### Distributed (Gun.js public ledger):
- Votes per MBID+hash (pseudonymous)
- Validation certificates (signed proofs)
- Aggregate verification status
- Public karma scores (if user opts in)
- Leaderboard (opt-in only)

**Privacy:** User identity never public. Votes are pseudonymous (hash of user ID). Can't link votes across MBIDs unless user opts into leaderboard.

---

## Phase 0 MVP (Weeks 1-2)

**Goal:** Prove basic flow works

**Scope:**
- CLI only
- Search → MusicBrainz → external torrents → download → vote (local)
- NO network yet
- NO validation yet
- Just prove: people can use it

**Success:** 10 users successfully download music

---

## Phase 1 (Weeks 3-4)

**Goal:** Add network-first search

**Adds:**
- Gun.js distributed ledger
- Network-first search logic
- Casual votes enter pending queue
- Basic voting (no Core validation yet)

**Success:** Network has 100+ files with vote counts

---

## Phase 2 (Weeks 5-6)

**Goal:** Two-tier validation

**Adds:**
- Core listener role
- Validation queue interface
- Proof of validation (acoustic fingerprint + spectral analysis)
- Dynamic validation thresholds
- Karma tracking

**Success:** Core listeners validate 50+ files, Casuals see VERIFIED badges

---

## Phase 3 (Weeks 7-8)

**Goal:** AI intelligence

**Adds:**
- Query intent parsing (Ollama local or API fallback)
- Smart ranking algorithm
- User preference learning

**Success:** Top result is correct 80%+ of time

---

## Phase 4 (Weeks 9-10)

**Goal:** Gamification

**Adds:**
- Badges, leaderboards
- Public profiles (opt-in)
- Social motivation

**Success:** Users seed longer, vote more

---

## Phase 5 (Month 4+)

**Goal:** Economic sustainability

**Adds:**
- Revenue generation (how? TBD)
- Fiat/crypto payouts to Core listeners
- Foundation/grant funding

**Success:** Core listeners compensated, network self-sustaining

---

## Critical Success Factors

### Must Have:
✅ Network-first search actually works (low latency)
✅ Core validation is trustworthy (no spam/collusion)
✅ Proof system is auditable (transparency)
✅ Ranking puts best result first (80%+ accuracy)
✅ Bootstrap problem solved (invitation + donation)

### Nice to Have:
- Soulseek integration (Phase 2+)
- Mobile apps (far future)
- Web interface (maybe never - CLI is the vibe)

### Must Avoid:
❌ Complex token economics (karma only, no crypto in MVP)
❌ Over-engineering (start simple, add complexity only when needed)
❌ Centralization (Gun.js distributed, not our servers)
❌ Privacy violations (all data local or pseudonymous)

---

## Open Questions

1. **Gun.js scaling:** Does it actually work at 10,000 users? 100,000?

2. **Core listener recruitment:** How do we find first 20 validators? Personal invites? Reddit?

3. **Validation speed:** If rare file needs 7 Core validations, how long does that take? Days? Weeks?

4. **Economic model:** Where does money for Core rewards come from? Donations? Premium features?

5. **Legal:** Are we comfortable with torrent association? Even legal content carries stigma.

6. **Moderation:** What happens with malware? CSAM? Who's responsible?

---

## What Makes This Different

**vs Spotify:** We don't host. We coordinate. No infrastructure costs.

**vs What.CD/RED:** Open to all (donation/invite). No interview process. AI-powered ranking.

**vs Soulseek:** Better discovery (MusicBrainz + AI). Community verification. Quality guarantees.

**vs Public torrents:** Curated network. No fake files. No decision paralysis.

---

**The bet:** Combining MusicBrainz (canonical metadata) + torrent networks (distribution) + AI (intent understanding) + community validation (trust) creates something better than any of those pieces alone.