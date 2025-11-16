# TrustTune Network: A Protocol for Artist Sovereignty

**Version 1.0 | January 2026**

## Abstract

Thirty years ago, crypto-anarchists predicted that cryptographic protocols would shatter gatekeepers. Music became the testing ground: Napster proved peer networks could route around traditional distribution, even as legal pressure killed the messenger. We abandoned vinyl's warmth for MP3's convenience, then surrendered ownership entirely to streaming platforms that compressed both audio and artist compensation into opaque black boxes.

TrustTune Network returns music to its roots—not just lossless audio quality rivaling vinyl, but *trust-minimized protocol* where permanence, quality, and compensation are cryptographically verifiable rather than corporate promises. Downloads replace streams. Fans press tracks for permanent archival, triggering validation that generates acoustic fingerprint proofs. Artists receive 70-85% of revenue (tiered by file size) through transparent on-chain distribution, not quarterly statements from intermediaries—still industry-leading compared to iTunes (70%), Bandcamp (82%), and Spotify (20-30%).

This is not streaming with blockchain bolted on. It is a protocol for **200-year tamper-proof music libraries** where inclusion depends on cryptographic proof, not platform permission. Where quality validation is mathematically verifiable, not editorial discretion. Where compensation flows directly from listeners to creators, not through rent-seeking middlemen. Where music survives not because a company hosts it, but because the network itself guarantees permanence.

The music industry taught us to accept compressed audio through unreliable internet pipes and opaque royalty calculations. We choose verification over blind trust. We choose quality and fair-to-creators economics. We choose systems whose correctness depends on math and consensus, never on the goodwill of intermediaries.

We not only enjoy music—we love music, we live music. This protocol is built by and for those who understand that music is not a commodity to be compressed and monetized, but a cultural artifact worthy of permanence, verification, and fair compensation.

> **⚠️ RESEARCH STATUS:** This white paper describes a protocol under active development. Key components—including token economics, Gun.js scaling at 10,000+ nodes, worker reputation systems, and optimal treasury mechanisms—remain unproven at scale. This is a living document subject to revision as we learn from implementation and community feedback. Treat economic projections as directional rather than definitive.

---

## Trust Assumptions & Dependencies

TrustTune is a **trust-minimized protocol**, not fully trustless. We are transparent about dependencies:

### Phase 1 Dependencies (Current)
- **Worldcoin biometric verification**: Third-party service for permanent ownership (evaluating alternatives for Phase 3)
- **AcoustID/MusicBrainz APIs**: Metadata validation for popular releases (fallback to permissionless human validation for rare content)
- **Gun.js infrastructure**: Distributed ledger relay nodes (community-operated; core team may contribute as community participants with no special privileges)

### What IS Trustless (Cryptographically Enforced)
✅ **Algorithmic validation**: Chromaprint, ffprobe, essentia analysis (deterministic, reproducible by anyone)
✅ **Permissionless validator nodes**: Anyone can run validation software (open source, no credentials needed)
✅ **Payment transparency**: All transactions on Solana blockchain (publicly verifiable)
✅ **Permissionless participation**: Anyone can validate, anyone can press content, anyone can step in
✅ **Open source code**: Full auditability and forkability (github.com/trusttune/protocol)
✅ **Human validation fallback**: When automated systems fail, anyone can attest (permissionless)
✅ **Distributed legal liability**: No single operator controls validation (reduces legal attack surface)

### Core Team Role (Development Only - No Infrastructure Operation)
The core team develops validator node software (open source) but **NEVER operates production validator nodes**:
- Core team writes code, community runs infrastructure
- Anyone can run validator nodes (permissionless participation)
- Validation is algorithmic (no editorial decisions)
- Core team has zero operational control or special privileges
- This eliminates centralized liability - no Grooveshark-style "employees upload content" risk

### Roadmap to Full Trustlessness
- **Phase 2**: Immutable smart contracts (no upgrade keys, or DAO-governed with timelocks)
- **Phase 2**: Community Gun.js relay network (published addresses, consumer-friendly setup)
- **Phase 3**: Evaluate Worldcoin alternatives OR acknowledge as permanent dependency with risks
- **Phase 3**: Local MusicBrainz replication (eliminate API dependency)

**TrustTune is MORE trustless than Spotify/Apple/iTunes, LESS trustless than Bitcoin (due to Worldcoin dependency).**

---

## The Problem

**Artists cannot verify their own earnings. Fans cannot audit platform claims. Distribution requires permission from gatekeepers who optimize for their own margins.**

The music industry operates on trust enforced through gatekeeping. Labels control releases. Platforms control distribution. Both report numbers through proprietary systems months after the fact. Revenue calculations happen in black boxes. Play counts exist in private databases. Artists receive what they're told they earned.

**This architecture creates systematic extraction:**
- Intermediaries capture 70-85% of revenue
- Artists cannot independently verify their statistics
- Fans own nothing—access terminates when platforms decide
- Quality degrades to optimize bandwidth costs
- Discovery serves platform incentives, not listener preference

We traded vinyl ownership for streaming convenience, then discovered "convenience" meant surrendering control entirely. The problem isn't that specific platforms pay too little—it's that **centralized architecture makes verification impossible and exit impractical**.

We propose a different path for music. Music can thrive without gatekeepers because of protocols, cryptography, and the humans who built these foundations. We're just building on what they showed us was possible.

---

## The Vision

**200-year music libraries where quality is provable, compensation is transparent, and survival depends on cryptography—not corporate goodwill.**

TrustTune builds on existing peer networks and enables artists to publish using standard decentralized tools. Fans press tracks for permanent archival, triggering validation that generates acoustic fingerprint proofs. Files stay distributed across networks minimizing centralized control. Compensation flows on-chain where anyone can audit.

**What this means:**

**For artists discovering their music spreading through networks:**
- Publish content to BitTorrent/IPFS/Arweave using standard tools (qBittorrent, IPFS Desktop, Arweave CLI)
- TrustTune indexes your content hashes - no upload infrastructure operated by protocol
- See downloads happening in real-time (Gun.js distributed ledger)
- Track plays across countries, sources, completion rates
- Verify search trends and listener engagement
- **All visible immediately, not months later in proprietary dashboards**
- Independent verification—anyone can audit the same ledger

**Artist Content Publishing Options:**

1. **BitTorrent Publishing:**
   - Create torrent using qBittorrent/Transmission
   - Seed the torrent yourself or through seedboxes
   - TrustTune indexes your .torrent file or magnet link
   - No TrustTune upload infrastructure involved

2. **Arweave Direct Upload:**
   - Upload files to Arweave using Arweave CLI/SDK
   - Pay Arweave storage costs directly (one-time fee)
   - TrustTune indexes your Arweave transaction ID
   - You control the content, not the protocol

**Then, when economics layer activates:**
- 70-85% revenue from pressing (tiered by file size, still beats all competitors)
- Transparent on-chain payments (verify every transaction)
- Direct compensation whether content spreads via P2P networks or your own Arweave uploads
- **Public archive option:** Both creator and presser can opt to make content fully public—no gates, just pure content on a 200-year Arweave drive, easily accessible on TrustTune Network

**For listeners:**
- Permanent access via biometric authentication (works on any client, not just TrustTune GUI)
- Cryptographically proven quality (not marketing claims) - verifiable on any client
- Music survives because the protocol guarantees it, not because a platform hosts it

**For preservationists:**
- Years of careful rips, rare recordings, bootlegs—finally verifiable and compensated instead of just shared
- Community validation through acoustic fingerprints proves authenticity
- Economic incentives for long-term seeding and preservation

**The result:** Existing peer networks gain cryptographic proof. Artists gain real-time analytics AND compensation. Listeners gain permanence. Minimal platform dependencies.

---

We build for permanence, not convenience.  
The music industry taught us ownership is obsolete.  
We choose artist sovereignty instead.

---

## System Architecture

### Three-Layer Protocol

**Discovery Layer** - Pluggable sources (BitTorrent, YouTube, Soulseek, Arweave) aggregated through open interface. Search checks Gun.js for verified content first, falls back to all sources. DMCA blocklist filtering. All code open source. TrustTune indexes content hashes—never hosts uploads.

**Validation Layer** - Pressing triggers validation tasks. Validators (nodes or volunteers) claim tasks, download files, run cryptographic analysis (acoustic fingerprinting, spectral analysis, format verification), publish signed certificates. Like blockchain mining but for quality proof.

**Pressing Layer** - Worldcoin biometric authentication. Solana smart contract splits payment (70-85% artist tiered by file size, 15-30% protocol costs: validator fees + Arweave storage + Solana gas). Validator nodes automatically upload verified files to Arweave permanent storage (distributed, permissionless, core team never uploads). On-chain mapping: biometric → content. Protocol-level access survives any platform death.

### Technology Stack

- **Client**: Flutter/Dart (cross-platform)
- **Distributed Ledger**: Gun.js (certificates, analytics, DMCA blocklist)
- **Validation**: Chromaprint, ffprobe, essentia (automatic cryptographic proofs)
- **Identity**: Worldcoin (biometric authentication)
- **Payments**: Solana (transparent 70-85% artist splits, tiered by file size)
- **Storage**: Arweave (permanent, 200+ years)
- **Discovery**: Open interface, pluggable sources

---

## Discovery Layer: Pluggable Architecture

### The Interface

Discovery operates through simple Python async interface. Any class implementing the interface can be added as a source:

**Core methods:**
- `search(query)` → returns list of results
- `download(result, output_path)` → saves file locally
- `name` → identifies the source

Reference implementations exist for BitTorrent networks, YouTube audio extraction, Soulseek (future maybe), and Arweave content indexing. Artists publish to these networks using standard tools (qBittorrent, Arweave CLI)—TrustTune only indexes content hashes. Community can add new sources, audit existing ones, fork the protocol. All code is public.

### How Search Works
```
User searches "radiohead ok computer flac"
  ↓
Check Gun.js distributed ledger: verified certificates?
  ↓
IF verified content exists:
  - Return those sources
  - Badge: ✓ VERIFIED
  - Priority: highest
  ↓
ELSE query all enabled sources in parallel:
  - Each source.search(query)
  - Results from torrents, YouTube, Soulseek, uploads
  - Badge: 🔍 EXTERNAL
  - Priority: by quality/seeders
  ↓
Cross-check distributed DMCA blocklist
  ↓
Filter blocked content hashes
  ↓
Merge and rank results
  ↓
Display to user
```

**Critical insight**: Validation certificates point to content sources (BitTorrent swarms, YouTube videos, Soulseek shares, Arweave transaction IDs). When content is pressed, community validators upload verified files to Arweave and certificates point to the permanent Arweave address. TrustTune never hosts content—it certifies quality and indexes publicly available content hashes for discovery.

### Real-Time Analytics (Immediate Value)

**The moment music starts spreading, artists see it happening.**

Every search recorded pseudonymously:
```
search_events: {
  query: "artist album",
  timestamp: now,
  user_hash: keccak256(pubkey), // pseudonymous
  geolocation: "BR" // country only
}
```

Every download tracked:
```
download_events: {
  file_hash: sha256(file),
  mbid: "musicbrainz_id" | null, // optional: populated if AcoustID lookup succeeds (validation phase)
  user_hash: keccak256(pubkey),
  source: "bittorrent" | "youtube" | "soulseek",
  timestamp: now,
  geolocation: "BR"
}
```

Every play logged:
```
play_events: {
  file_hash: sha256(file),
  mbid: "musicbrainz_id" | null, // optional: populated if AcoustID lookup succeeds (validation phase)
  user_hash: keccak256(pubkey),
  duration_played: 243, // seconds
  full_listen: true, // >80% completion
  timestamp: now
}
```

**Note:** MusicBrainz IDs (mbid) are optional and only populated when AcoustID lookup successfully matches a recording. This is a validation phase enhancement, not required for Phase 0.5 or 1.0 core functionality.

**Artists query Gun.js directly:**
```
Downloads:
  total: 1,247
  by_country: {BR: 423, US: 349, DE: 187, ...}
  by_source: {bittorrent: 892, youtube: 201, soulseek: 154}
  trend: "+18% vs last month"

Plays:
  total: 14,329
  full_listens: 11,847 // 83% completion rate
  average_duration: 227 seconds
  skip_rate: 0.17
  retention: {first_30s: 0.98, first_minute: 0.89, full: 0.83}
  
  by_song: {
    "Song Title 1": {
      total_plays: 3,421,
      full_listens: 2,987, // 87% completion
      by_region: {
        BR: {plays: 892, full_listens: 801, completion: 0.90},
        US: {plays: 1,234, full_listens: 1,089, completion: 0.88},
        DE: {plays: 567, full_listens: 445, completion: 0.78}
      }
    },
    "Song Title 2": {
      total_plays: 2,156,
      full_listens: 1,623, // 75% completion
      by_region: {
        BR: {plays: 423, full_listens: 289, completion: 0.68},
        US: {plays: 987, full_listens: 812, completion: 0.82},
        DE: {plays: 445, full_listens: 312, completion: 0.70}
      }
    }
  }
  
  by_region: {
    BR: {
      total_plays: 4,523,
      full_listens: 3,789, // 84% completion
      top_songs: ["Song Title 1", "Song Title 3"],
      avg_completion: 0.84
    },
    US: {
      total_plays: 5,234,
      full_listens: 4,567, // 87% completion
      top_songs: ["Song Title 1", "Song Title 2"],
      avg_completion: 0.87
    }
  }

Searches:
  queries: ["artist name", "album title", ...]
  trend: "rising" | "stable" | "declining"
  geographic_spread: 47 countries
```

**This happens BEFORE any pressing. BEFORE any payments. BEFORE any economics.**

Artists see their music spreading in real-time on a distributed ledger anyone can verify. No waiting months for proprietary dashboards. No trusting platform statistics. Just transparent, pseudonymous events recorded publicly.

### DMCA Compliance

Blocklist distributed via Gun.js:
```
dmca_blocklist: {
  [content_hash]: {
    artist: "Artist Name",
    title: "Track Title",
    reporter: "Rights Holder",
    notice_date: timestamp,
    status: "blocked"
  }
}
```

All nodes sync automatically. Blocked content never appears in results. Takedown process: 24 hours. Counter-notice restoration: standard DMCA timeline.

**Permissionless Blocklist (No Central DMCA Coordinator):**

Any validator can publish blocklist entries to Gun.js:
- Validator receives DMCA notice directly (via email, legal contact)
- Validator verifies notice legitimacy (sender identity, copyright ownership, content hash)
- Validator signs content hash into Gun.js blocklist with their Ed25519 signature
- Entry includes: content hash, notice date, reporter, validator signature, notice text

**Why permissionless:**
- No central authority required for protocol operation
- Validators act independently (distributed legal liability)
- If one validator stops honoring DMCA, others continue
- Rights holders can send notices to multiple validators for redundancy
- Community can run their own validators with different blocklist policies

**Validator choice:**
- Search nodes can choose which validators' blocklists to honor
- Mainstream nodes likely honor all major validators (legal safety)
- Alternative nodes may use different filtering policies
- Users can switch between search nodes

**Counter-notice process**:
- Artists dispute via standard DMCA counter-notice
- Validators publish counter-notices alongside takedowns
- Both sides visible on Gun.js ledger
- Community validators decide restoration independently

**Transparency**: All blocklist entries on Gun.js include: content hash, notice date, claimant, validator signature, counter-notices (if any)

**Legal positioning**: Protocol indexes content hashes from open networks (BitTorrent, YouTube, Arweave). Artists publish using standard decentralized tools—TrustTune never operates upload infrastructure. Responds to takedowns via permissionless Gun.js blocklist. Never hosts content. This is a protocol, not publishing.

---

## Validation Layer: Competitive Worker Nodes

### How Press-Triggered Validation Works
```
User downloads track from any source (BitTorrent, YouTube, etc.)
  ↓
Listens, decides to press track for permanent archival ($0.99-29.99 payment, tiered by file size/quality)
  ↓
Pressing triggers validation task → Added to Gun.js queue with token bounty
  ↓
Validator (core node, community node, or manual volunteer) claims task
  ↓
Validator:
  1. Downloads file if not cached
  2. Runs automatic cryptographic validation
  3. Generates signed certificate
  4. Publishes to Gun.js
  5. Earns TRUST tokens (100-450 based on bonuses/reputation)
  ↓
Artist receives 70-85% payment (tiered by file size) after validation completes
```

**No human approval. No editorial decisions. Pressing triggers cryptography. Validators earn tokens.**

### Why Algorithmic Validation is Trustless

**No human approval. No editorial decisions. No central authority.**

The validation process is fully deterministic and reproducible:

1. **Chromaprint acoustic fingerprinting** - Mathematical perceptual hash (anyone gets same result)
2. **ffprobe format analysis** - Codec, bitrate, sample rate extraction (deterministic)
3. **essentia spectral analysis** - Frequency spectrum verification (pure math)

**Anyone can verify:**
- Download same file
- Run same open-source tools (Chromaprint, ffprobe, essentia)
- Get identical results
- Reproduce validator's certificate

**No trust required:**
- Validators don't decide anything (algorithm decides)
- Core team develops code only - never runs production infrastructure
- Anyone can run validator nodes with consumer hardware (permissionless)
- Code is open source (audit the algorithm)

**Legal distribution:**
- No single entity "operates" validation
- Validators act independently (distributed liability)
- No central coordinator can be legally targeted
- Protocol survives if any operator is shut down

### What Validation Proves

**1. Audio Authenticity (Automated - Always Runs):**

**Acoustic Fingerprinting (Identity Verification):**
- Chromaprint generates perceptual hash of audio
- AcoustID database lookup finds matches
- **If match found:** Returns MusicBrainz Recording ID
  - MusicBrainz lookup retrieves canonical metadata:
    - Artist: Radiohead
    - Track: Paranoid Android
    - Album: OK Computer (1997)
    - Recording ID: 8f4e3d1a-4b28-4a9e-9c1d-2f3e4d5a6b7c
  - **Proves:** This file IS "Radiohead - Paranoid Android" from OK Computer (1997)
  - Confidence score: 0.97 (97% acoustic match to canonical recording)
- **If no match:** Falls back to human validation (see below)

**Format Verification:**
- ffprobe extracts technical metadata: codec, bitrate, sample rate, bit depth
- **Proves:** Format claims are accurate (FLAC is actually FLAC, not renamed MP3)

**Spectral Analysis (Transcode Detection):**
- essentia analyzes frequency spectrum
- Max frequency ≥22kHz → LOSSLESS_VERIFIED
- Max frequency ~15-16kHz → TRANSCODE_MP3 (MP3 encoder cuts high frequencies)
- **Proves:** FLAC is genuine lossless, not upsampled/transcoded MP3

The math doesn't lie. MP3 compression removes frequencies above ~16kHz. A file claiming lossless but showing 15kHz cutoff is a transcode. Spectral analysis proves it cryptographically.

**2. Human Validation Fallback (When MusicBrainz Lookup Fails):**

**This is a TRUST-MINIMIZING feature, not a weakness.**

When AcoustID returns no MusicBrainz match (rare bootlegs, unreleased demos, live recordings, classical performances):
- **Anyone can act as validator** (permissionless participation, no credentials)
- Validators extract embedded ID3/FLAC tags
- Cross-reference with community databases (Discogs, Rate Your Music, Setlist.fm)
- Mark confidence level in certificate:
  - **HIGH:** Multiple independent sources confirm metadata
  - **MEDIUM:** Probable match based on tags + partial evidence
  - **LOW:** Unverified, relies solely on embedded tags
- Publish certificate with human attestation signature
- Community can dispute/vote on uncertain metadata (Phase 1+)

**Why this preserves trustlessness:**
- ✅ Validators don't decide IF content gets validated (anyone can press anything)
- ✅ Validators only attest to HOW CONFIDENT they are (transparency, not gatekeeping)
- ✅ Anyone can step in and validate (no special credentials needed)
- ✅ Multiple validators can provide competing attestations (consensus emerges)
- ✅ Distributed legal liability (no single entity responsible for metadata accuracy)

This prevents "MusicBrainz or nothing" single point of failure. Human judgment is permissionless, transparent, and distributed.

### Validation Certificate
```
{
  file_hash: sha256,
  worker_id: identifier,
  timestamp: unix_time,
  
  acoustid: {
    mbid: "musicbrainz_recording_id" | null, // optional: only if MusicBrainz lookup succeeds
    confidence: 0.97,
    fingerprint_hash: sha256
  },
  
  format: {
    codec: "FLAC",
    bitrate: 998000,
    sample_rate: 44100,
    bits_per_sample: 16
  },
  
  quality: {
    max_frequency: 22050,
    dynamic_range_db: 87,
    flag: "LOSSLESS_VERIFIED"
  },
  
  verdict: "APPROVED",
  signature: ed25519_signature
}
```

Anyone can verify the signature. Anyone can check the acoustic fingerprint. Anyone can run spectral analysis on the same file. The proof is public and reproducible.

### Validation Economics: Hybrid Task Queue

**Critical Change:** Validation happens **when users press tracks**. This ensures every validation is pre-funded and sustainable.

**The Flow:**
```
User presses track ($0.99-29.99, tiered pricing) → Validation task created with token bounty
  ↓
Task appears in validation queue (Gun.js distributed ledger)
  ↓
Two ways validators can claim (fully permissionless):

  1. Community Node Operators (Open Source)
     - Anyone downloads and runs validator node software
     - Nodes scan Gun.js queue, auto-claim available tasks
     - Scale up organically as demand grows
     - Core team provides code only - never operates nodes

  2. Manual Volunteers (Task Board)
     - Browse validation task board in desktop app
     - Choose tasks manually: "I'll validate this rare bootleg"
     - Run validation via app or CLI
     - More like "bounty hunting" than automated mining

  ↓
Validator (node or volunteer):
  - Downloads file if not cached
  - Runs Chromaprint (acoustic fingerprinting)
  - Runs ffprobe (format verification)
  - Runs essentia (spectral analysis / transcode detection)
  - Publishes signed certificate to Gun.js
  ↓
Validator earns TRUST tokens (100-450 depending on bonuses)
  ↓
Artist receives 70-85% payment (tiered by file size) after validation completes
```

**Why Press-Triggered Works:**
- ✅ **Temporal alignment:** User pays → Validation funded → Worker compensated (all in same flow)
- ✅ **Sustainable:** Every validation is pre-funded (no treasury deficit risk)
- ✅ **Flexible:** Mix of automation (nodes) + human choice (volunteers)
- ✅ **No race condition:** Task queue with one claimer per task
- ✅ **Volunteer-friendly:** Choose what you care about (rare content, favorite artists)

**Token Compensation (ALL in TRUST, no fiat):**
```
Base rate: 100 TRUST tokens per validation
Conversion: 1,000 TRUST = $1 USD (algorithmically adjusted by smart contract)

Phase 1 (Bootstrap): Fixed rate for research and calibration
Phase 2+: Automatic adjustment based on treasury health:
  - Treasury > 6 months runway: 1,000 TRUST = $1.00 USD
  - Treasury 3-6 months runway: 1,000 TRUST = $0.75 USD
  - Treasury < 3 months runway: 1,000 TRUST = $0.50 USD

Smart contract reads on-chain treasury balance → adjusts rate automatically
No human intervention, no governance votes, fully algorithmic

Bonuses:
  - Rare content (<5 seeders): +50 tokens (preserving hard-to-find music)
  - Popular content (>100 seeders): +25 tokens (high demand, speed matters)
  - Standard content (5-100 seeders): No bonus

Reputation Multiplier:
  - New validator (unproven): 1.0x
  - Good validator (90%+ accuracy): 2.0x
  - Excellent validator (98%+ accuracy, 6+ months): 3.0x

Reputation based on:
  - Validation accuracy (consensus with other validators)
  - Uptime and response time (for automated nodes)
  - Cross-verification thoroughness
  - Low false positive rate
```

**Example Token Earnings:**
```
New volunteer, standard track:
  100 tokens

Veteran node (3x reputation), rare bootleg:
  (100 + 50 bonus) × 3.0 multiplier = 450 tokens

Community node (2x reputation), popular release:
  (100 + 25 bonus) × 2.0 = 250 tokens

Manual volunteer, rare content (no reputation yet):
  100 + 50 = 150 tokens
```

**Token → USD Conversion:**
At current rate (1000 TRUST = $1 USD):
- 100 tokens ≈ $0.10
- 450 tokens ≈ $0.45
- Average ≈ 150-200 tokens ≈ $0.15-0.20 per validation

**Note:** USD values are illustrative only. Validators earn TRUST tokens. Conversion rate adjusts algorithmically based on treasury health (Phase 2+). Phase 1 uses fixed rate while collecting data to calibrate the algorithm. No governance control—smart contract enforces objective rules.

**Who Runs Validators (Fully Permissionless):**

**Community Node Operators:**
- Download open-source validator software
- Run on VPS, home server, or cloud instance
- Auto-claim tasks from Gun.js queue
- Core team provides code only - never operates production nodes
- Example economics (at 1000 TRUST=$1):
  - 100 validations/month × 150 tokens = 15,000 tokens ≈ $15
  - VPS cost: $45/month
  - Net: -$30 (not profitable at low volume)
  - At scale: 500 validations/month × 150 tokens = 75,000 tokens ≈ $75 gross - $45 cost = $30 profit

**Manual Volunteers:**
- No VPS cost (use own computer)
- Choose tasks from board (validate what you care about)
- Ideal for collectors, enthusiasts, archivists
- Example: 20 rare bootleg validations/month × 150 tokens = 3,000 tokens ≈ $3 (pure profit, no costs)

**Critical Legal Clarity:**
Core team develops validator software (open source) but NEVER runs production validator nodes. This eliminates Grooveshark-style liability where employees directly operated infrastructure.

**Revenue Source:**
- **Phase 1:** Pressing fees fund validation pool
  - User pays $0.99-29.99 to press (tiered by file size) → Smart contract allocates tokens for validator
  - Break-even: 1 press = 1 validation (perfect 1:1 ratio)
  - No treasury subsidy needed (validation only happens when pre-funded)
- **Phase 2+:** Subscription model adds recurring pool
  - $10/month subscription → 20% to worker pool
  - Funds validations for all subscribers
  - Supplements pressing revenue

**Why Tokens Work Better:**
- **Flexible:** Conversion rate adjusts algorithmically as protocol matures (no human intervention)
- **Incentive-aligned:** Reputation multiplier rewards quality over quantity
- **Transparent:** All token grants public on Gun.js ledger
- **Sustainable:** No direct fiat exposure, rate adjusts to economic reality automatically
- **Trustless:** Conversion rate adjusts algorithmically via smart contract (no governance control)

**Trustless Properties:**
- ✅ Task queue visible to all (Gun.js distributed ledger)
- ✅ No central approval (first to claim wins)
- ✅ Cryptographic signatures (unforgeable certificates)
- ✅ Public token grants (anyone audits)
- ✅ Open participation (anyone runs nodes or volunteers)
- ✅ Meritocratic (reputation = higher earnings)

---

## Pressing Layer: 200-Year Permanence

### What Pressing Means

User pays to archive verified content on Arweave with biometric access control.

**Why:**
- 200+ year guarantee (Arweave endowment model)
- Biometric access (no passwords, no seed phrases)
- Protocol-level permanence (works if TrustTune dies)
- Artist receives 70-85% instantly (tiered by file size, still industry-leading)

### Pressing Economics: Tiered Pricing Model

Pressing costs reflect actual storage requirements. Larger files cost more to store permanently on Arweave.

**Single Tracks:**

| Quality | Size | Price | Artist (%) | Protocol (%) | Breakdown |
|---------|------|-------|------------|--------------|-----------|
| MP3 | 5-10MB | $0.99 | $0.79 (80%) | $0.20 (20%) | Arweave $0.05, Validation $0.10, Profit $0.05 |
| FLAC | 30-50MB | $1.99 | $1.59 (80%) | $0.40 (20%) | Arweave $0.25, Validation $0.10, Profit $0.05 |
| Hi-Res | 100-200MB | $2.99 | $2.24 (75%) | $0.75 (25%) | Arweave $0.90, Validation $0.10, Margin -$0.25* |

*Hi-res singles subsidized by album sales to keep pricing competitive

**Albums (Full Releases):**

| Tier | Size | Price | Artist | Protocol | Costs (Arweave + Validation) | Margin |
|------|------|-------|--------|----------|------------------------------|--------|
| **Basic** | <200MB | $9.99 | $8.49 (85%) | $1.50 (15%) | $1.35 | $0.15 (2%) |
| **Standard** | 200-500MB | $14.99 | $11.99 (80%) | $3.00 (20%) | $2.35 | $0.65 (4%) |
| **Premium** | 500MB-1GB | $19.99 | $14.99 (75%) | $5.00 (25%) | $4.10 | $0.90 (5%) |
| **Hi-Res** | 1-2GB | $29.99 | $21.59 (72%) | $8.40 (28%) | $7.40 | $1.00 (3%) |

**Why Tiered:**
- Arweave storage is $5-8/GB for 200+ year permanence
- Large hi-res albums (2GB) cost $11+ just for storage
- Protocol must cover: Arweave storage + validator fees + Solana gas + Gun.js relay costs
- Artists still get 72-85% (vs. iTunes 70%, Bandcamp 82%, Spotify 20-30%)

**Validation per Album:**
One validation covers entire album (checks 3 random tracks thoroughly). Saves costs while ensuring quality.

**Protocol sustainability:**
Target 2-5% net margin after all costs. Transparent pricing reflects real distributed network costs (Arweave, validators, blockchain fees).

### Arweave Economics

**Rates (January 2026):**
- $5-8 per GB (one-time, not subscription)
- 200+ year minimum guarantee
- Endowment model (0.5% annual storage cost decline)

**Examples:**
- 5MB FLAC track: $0.03
- 40MB album: $0.25
- 400MB discography: $2.50

**Break-even vs IPFS pinning:**
- IPFS: $240-1,200/year
- Arweave: $0.30 one-time (40MB)
- Break-even: 4-7 years

Any content expected >5 years availability favors Arweave dramatically.

### Pressing Flow
```
User discovers track from any source (BitTorrent, YouTube, Soulseek, Arweave)
  ↓
Downloads and listens (UNVERIFIED at this point - just raw content)
  ↓
Decides to press for permanent verified ownership
  - Pricing: $0.99-29.99 based on file size/quality
  ↓
Pressing payment triggers validation task
  - Task added to Gun.js queue with token bounty
  ↓
Validator (core node, community node, or volunteer) claims task
  ↓
Validator performs cryptographic validation:
  - Chromaprint acoustic fingerprinting
  - ffprobe format verification
  - essentia spectral analysis (transcode detection)
  - Publishes signed certificate to Gun.js
  ↓
Worldcoin biometric authentication (user)
  - Iris scan or phone verification
  - Zero-knowledge proof generated
  - Nullifier hash = anonymous user ID
  ↓
Smart contract executes payment:
  - 70-85% → Artist wallet (instant, tiered by file size)
  - 15-30% → Protocol costs (Arweave storage + validator fees + Solana gas)
  ↓
Validator node automatically uploads VERIFIED file to Arweave
  - Smart contract triggers upload as final validation step
  - Any validator can perform upload (distributed, permissionless)
  - Core team NEVER uploads content (no centralized liability)
  - Community nodes, algorithm-driven process
  ↓
On-chain mapping stored:
  biometric_hash → arweave_transaction_id + certificate_hash
  ↓
User receives permanent biometric-linked access to VERIFIED content
```

**Worldcoin Dependency Risk Disclosure:**

TrustTune's pressing layer depends on Worldcoin for biometric verification. This is a **centralized dependency** we acknowledge transparently:

**Risks:**
- If Worldcoin shuts down: No new users can press (existing users retain access via on-chain nullifiers)
- If Worldcoin changes terms: Users subject to new policies
- If Worldcoin is compromised: Sybil attacks possible
- If Worldcoin is regulated: Service may be unavailable in certain jurisdictions

**Why we chose Worldcoin (Phase 1-2):**
- Only mature biometric protocol with 200+ year permanence vision
- Zero-knowledge proofs preserve privacy (iris scan never stored)
- Global orb network already deployed (accessibility)
- On-chain nullifiers enable permanent ownership

**Phase 3 alternatives being evaluated:**
- Proof-of-Humanity (decentralized, but less robust against Sybil attacks)
- Ethereum ENS + wallet signatures (self-sovereign, but no Sybil resistance)
- Decentralized identity protocols (BrightID, Gitcoin Passport)
- Federated biometrics (multiple providers, user choice)

**Honest assessment**: We have not yet found a fully decentralized alternative that matches Worldcoin's permanence + Sybil resistance. This may remain a dependency, OR we may accept weaker guarantees for decentralization.

**User informed consent**: Pressing requires trust in Worldcoin Inc. during Phase 1-2. Users should understand this trade-off.

### Protocol Permanence

**Year 0 (2026):** TrustTune app exists
```
Biometric auth → Query Solana contract → Returns arweave_cids → Stream from Arweave
```

**Year 50 (2076):** TrustTune app extinct
```
Developer reads public contract → Builds new client → Same biometric → Same query → Same content
```

**The protocol is immortal. Apps are ephemeral.**

This is what "censorship-resistant" means: not that platforms can't be shut down, but that **no platform is required** once content is pressed.

---

## Analytics: Verification Over Trust

### The Problem

Spotify: "You had 1.2M streams. Here's $3,600. Trust us."

No proof. No audit trail. No independent verification.

### The Solution

**All events publicly verifiable on Gun.js:**

Downloads by country, by source, trending
Plays with completion rates, skip rates, retention curves
Searches with geographic spread, query trends

**Payments publicly verifiable on Solana:**
```
Query blockchain:
  ContentPressed events
  Artist wallet
  Amount paid
  Timestamp
  Transaction signature
```

Third parties independently verify:
- How many presses
- Exact artist payment
- When it occurred
- That protocol took only 5%

**No black boxes. No quarterly statements. Just cryptographic proof.**

---

## Legal Framework

### Positioning

TrustTune = search aggregation protocol, not content host/publisher.

| Platform | Hosts? | Status |
|----------|--------|---------|
| Napster | No | Shut down (contributory) |
| Grooveshark | Yes | Shut down ($736M) |
| Google Search | No | Operating (passive conduit) |
| **TrustTune** | **No** | **Active** |

**Distinctions:**
- Aggregates via pluggable sources
- DMCA compliance (24hr blocklist)
- No editorial control (automatic validation)
- Open source (audit, fork, extend)

### DMCA Compliance

**Traditional §512 Safe Harbor Requirements (NOT used by TrustTune):**
- Designated agent (centralized coordinator)
- Repeat infringer policy
- Expeditious takedown

**TrustTune's Distributed Approach:**
✅ Permissionless blocklist via Gun.js (no central coordinator required)
✅ Community validators receive DMCA notices independently
✅ Validators publish blocklist entries with Ed25519 signatures
✅ 24-hour distributed takedown process (blocklist syncs across network)
✅ Counter-notice procedure (published to Gun.js ledger, publicly auditable)
✅ Distributed legal liability (no single operator controls DMCA compliance)

**Why distributed approach:**
- No centralized DMCA coordinator = no central point of legal attack
- Each validator operates independently (distributed liability)
- Rights holders can send notices to multiple validators for redundancy
- Protocol survives if any single validator stops operating

See "Permissionless Blocklist (No Central DMCA Coordinator)" section (lines 314-343) for complete technical implementation.

### Why TrustTune ≠ Grooveshark

**Grooveshark's errors (we avoid):**

❌ Employees uploaded content → TrustTune employees never upload
❌ Centralized hosting → TrustTune aggregates search only (no hosting)
❌ Ignored DMCA → TrustTune full compliance
❌ No infringer policy → TrustTune 3-strike termination

**Legal theory:**

Passive conduits (protected): Google Search, DNS, ISPs
Active publishers (liable): Grooveshark, Megaupload

**TrustTune = passive conduit:**
- Aggregates publicly available information
- Responds to takedowns via filtering
- No editorial control (cryptographic validation)
- Cannot host (pluggable architecture points externally)

### Who Uploads to Arweave? (Critical Legal Clarification)

**Core team NEVER uploads content to Arweave. Ever.**

**Phase 2+ Arweave Upload Process:**

When a user presses content, the smart contract triggers the final validation step:
1. **Validator node** that completed the validation automatically uploads the verified file to Arweave
2. **Any validator can perform upload** (permissionless, distributed)
3. **Smart contract pays for upload** from protocol fee allocation (15-30% of pressing payment: Arweave + validator + gas)
4. **Validator receives TRUST tokens** for successful upload + mapping storage
5. **On-chain mapping published**: biometric_hash → arweave_transaction_id + certificate_hash

**Why this matters legally:**

✅ **Distributed liability**: No single entity "operates" upload infrastructure
✅ **Permissionless participation**: Anyone can run validator nodes that perform uploads
✅ **Algorithm-driven**: Smart contract logic triggers upload, not human decision
✅ **Community nodes**: Validators are independent actors, not employees
✅ **No central coordinator**: Protocol survives if any validator is shut down

**Core team role:**
- Develops open-source smart contract code (freely auditable)
- Does NOT operate validator nodes in any official capacity
- Individual core team members may run nodes in their personal capacity as community participants, with no coordination with core team entity, following same permissionless process as any community member
- Does NOT have special upload privileges or central control

**This architecture protects against Grooveshark-style liability where employees directly uploaded copyrighted content.**

---

## Implementation Roadmap

### Phase 1: Validation Network

**Goal:** Add automatic validation via competitive worker nodes

**Tasks:**
- [ ] Gun.js distributed ledger integration
- [ ] Worker node daemon (monitors Gun.js, claims tasks competitively)
- [ ] Chromaprint acoustic fingerprinting integration
- [ ] ffprobe format verification
- [ ] essentia spectral analysis
- [ ] Certificate generation and signing
- [ ] DMCA blocklist (distributed via Gun.js)
- [ ] Search/play/download tracking (pseudonymous)
- [ ] Basic analytics dashboard (query Gun.js)

**Success criteria:**
- [ ] 1,000+ downloads tracked
- [ ] 10+ worker nodes active
- [ ] 50+ tracks verified
- [ ] 0 DMCA violations

### Phase 2: Pressing Layer

**Goal:** Add permanent storage + transparent payments

**Tasks:**
- [ ] Worldcoin SDK integration (biometric authentication)
- [ ] Solana smart contract development (tiered split logic: 70-85% artist, 15-30% protocol)
- [ ] Smart contract security audits (2 independent firms)

**Smart Contract Governance Model:**

Phase 1 (Bootstrap - 2025):
- Upgradeable contracts with multi-sig governance (3-of-5 signers: core team + community members)
- 7-day timelock on all upgrades (validators can exit if they disagree)
- All upgrades announced publicly via GitHub + Gun.js
- Emergency pause (security only, not economic parameter changes)

Phase 2 (Decentralization - 2026):
- Transition to DAO governance (validator token holders vote)
- 14-day timelocks, 66% supermajority required
- Multi-sig reduced to emergency-only role

Phase 3 (Immutability - 2027+):
- Deploy immutable contract versions OR
- Minimal governance (only security fixes, economic parameters locked on-chain)
- Community consensus on final model

**Transparency commitment**: All contract addresses, upgrade history, multi-sig signers, and timelock status published at trusttune.network/contracts

- [ ] Arweave upload pipeline (validator nodes automatically upload verified files, NOT core team)
- [ ] On-chain content mapping (biometric → arweave_cid)
- [ ] Artist payment distribution automation
- [ ] Payment verification tooling
- [ ] Artist analytics dashboard (downloads + plays + payments)
- [ ] Transaction history explorer

**Success criteria:**
- [ ] 100+ biometric verifications
- [ ] 50+ tracks pressed to Arweave
- [ ] $500+ artist payments distributed
- [ ] 0 security incidents
- [ ] 0 payment failures
- [ ] Independent audit confirms all payments verifiable

### Phase 3: Mobile + Scale

**Goal:** Platform expansion and adoption

**Tasks:**
- [ ] Flutter mobile apps (iOS + Android)
- [ ] Additional MusicSource implementations (community contributions)
- [ ] MusicBrainz deep integration (local DB replication)
- [ ] Advanced analytics (retention curves, geographic heatmaps)
- [ ] Optional subscription tier ($10/month)
- [ ] Subscription royalty pool distribution (70% to artists pro-rata)
- [ ] Worker incentive refinement (dynamic compensation rates)
- [ ] Community node operator onboarding
- [ ] Marketing and public launch

**Success criteria:**
- [ ] 10,000+ total users
- [ ] 5,000+ mobile users
- [ ] 1,000+ tracks pressed
- [ ] $10,000+ monthly artist payments
- [ ] 50+ active worker nodes
- [ ] 10+ community-contributed MusicSource implementations

---

## Technical Specifications

### Gun.js Schema

**Certificate:**
```
file_hash, worker_id, timestamp, acoustid{mbid, confidence, fingerprint_hash}, format{codec, bitrate, sample_rate, bits}, quality{max_frequency, dynamic_range_db, flag}, verdict, signature
```

**DMCA blocklist:**
```
content_hash, artist, title, reporter, notice_date, status
```

### Solana Smart Contract
```
ContentMapping:
  user_hash (Worldcoin nullifier)
  file_hash (SHA256)
  arweave_cid (transaction ID)
  pressed_at (timestamp)
  artist (wallet)
  amount_paid (lamports)

press_content():
  VERIFY worldcoin_proof
  CALCULATE splits (tiered: 70-85% artist, 15-30% protocol based on file size)
  TRANSFER funds
  STORE mapping
  EMIT event
```

### Cryptographic Primitives

- **Hashing:** SHA-256 (files), Keccak-256 (user identity)
- **Signatures:** Ed25519 (certificates), Secp256k1 (Solana)
- **Keys:** Ed25519 keypairs (32-byte public, 64-byte private)

---

## Security & Privacy

### Threat Model

- **Sybil attacks:** Worker validation required (cryptographic proofs prevent fake content)
- **Worker collusion:** High validator count (5-7), public certificates
- **Contract exploits:** 2 audits, formal verification, bug bounty
- **Proof forgery:** On-chain verification, ZK cryptography
- **Blocklist spam:** Signature requirements, legal consequences

### Privacy

**User:** No email, no name, no KYC. Biometric never stored (ZK proof only). Downloads local. Plays aggregated.

**Artist:** Wallet public (required for payments). Analytics aggregated. Optional KYC at legal thresholds.

**Network:** Gun.js encrypted. Standard protocols. Optional Tor (Phase 3+).

---

## Economic Model

### Revenue: Tiered Pressing Model

**Phase 1:** Pressing fees (tiered by file size and quality)

**Single Tracks:**
| Quality | Size | Price | Artist | Protocol | Breakdown |
|---------|------|-------|--------|----------|-----------|
| MP3 320kbps | 5-10MB | $0.99 | $0.79 (80%) | $0.20 (20%) | Arweave $0.05 + Validation $0.10 + Ops $0.05 |
| FLAC 16-bit | 30-50MB | $1.99 | $1.59 (80%) | $0.40 (20%) | Arweave $0.25 + Validation $0.10 + Ops $0.05 |
| Hi-Res 24-bit | 100-200MB | $2.99 | $2.24 (75%) | $0.75 (25%) | Arweave $0.90 + Validation $0.10 + Margin -$0.25* |

*Hi-Res singles operate at thin margin due to storage costs

**Albums (Full Releases):**
| Tier | Size | Price | Artist | Protocol | Costs | Margin |
|------|------|-------|--------|----------|-------|--------|
| **Basic** | <200MB | $9.99 | $8.49 (85%) | $1.50 (15%) | $1.35 | $0.15 (2%) |
| **Standard** | 200-500MB | $14.99 | $11.99 (80%) | $3.00 (20%) | $2.35 | $0.65 (4%) |
| **Premium** | 500MB-1GB | $19.99 | $14.99 (75%) | $5.00 (25%) | $4.10 | $0.90 (5%) |
| **Hi-Res** | 1-2GB | $29.99 | $21.59 (72%) | $8.40 (28%) | $7.40 | $1.00 (3%) |

**Example Protocol Costs (Standard Album: 500MB):**
```
Price: $14.99
Artist: $11.99 (80%)
Protocol: $3.00 (20%)

Protocol cost breakdown:
  - Arweave storage (500MB × $0.00462/MB): $2.31
  - Validator fees (150 TRUST tokens): $0.15 (at 1000=$1 conversion)
  - Solana transaction gas: $0.002
  - Worldcoin biometric verification: $0.01
  - Gun.js relay + operations: $0.53
Total costs: $3.002 | Margin: -$0.002 (near break-even)
```

**Why Not 95% Like We Originally Hoped?**

We wanted to promise 95% to artists. Here's why tiered pricing (70-85%) is actually honest and sustainable:

1. **Arweave storage isn't free:** 500MB album = $2.31 permanent storage cost
2. **Validator fees are real:** Each pressing triggers cryptographic validation ($0.10-0.15)
3. **Blockchain gas exists:** Solana transactions, Worldcoin verification add up
4. **Protocol needs sustainability:** Without covering costs, network dies and artists get $0

**Still Industry-Leading:**
| System | Artist Share | Payment Speed | Ownership | Verification |
|--------|--------------|---------------|-----------|--------------|
| **TrustTune** | **70-85%** | Instant (on-chain) | Permanent | Cryptographic |
| Bandcamp | 82% | 24-48 hours | No (streaming) | None |
| iTunes | 70% | 45-60 days | No (DRM) | None |
| Spotify | 20-30% | 3-6 months | No (streaming) | Opaque |

**Multi-Wallet Splits (Roadmap):**
- **Phase 1:** Single artist wallet (shipping now)
- **Phase 2:** Multi-wallet splits (artist 60%, producer 20%, mixer 10%, protocol 10%)
- Smart contract automatically distributes percentages on each press

**Phase 2:** Optional Subscription ($10/month, coming 2026)
```
70% artist pool (distributed pro-rata by plays)
20% worker compensation pool
10% protocol operations
```

**Phase 3:** Hybrid model (press-to-own + subscribe for streaming access)

**Example Comparison:**
```
1,000 fans press Standard Album ($14.99)
  TrustTune: Artist earns $11,990 instantly
  Spotify equivalent: 4+ million streams needed
  ~400x better per transaction
```

---

## Acknowledgments

This manifesto draws inspiration from **[The Trustless Manifesto](https://trustlessness.eth.limo/general/2025/11/11/the-trustless-manifesto.html)** and the crypto-anarchist visions that predicted cryptographic protocols would shatter centralized gatekeepers. We stand on the shoulders of peer-to-peer pioneers who proved that distribution doesn't require permission and that verification beats trust.

---

## Alignment with The Trustless Manifesto

This protocol draws inspiration from **[The Trustless Manifesto](https://trustlessness.eth.limo/general/2025/11/11/the-trustless-manifesto.html)** which defines trustlessness as: *"Any honest participant can join, verify, and act without permission and without fear."*

### Where TrustTune Meets Manifesto Standards

✅ **Algorithmic validation**: Chromaprint, ffprobe, essentia = deterministic, reproducible proofs
✅ **Verifiability**: All payments on-chain, all validation certificates public on Gun.js
✅ **Permissionless participation**: Anyone can run validators, claim tasks, press content
✅ **Censorship resistance**: Content inclusion permissionless (subject to DMCA compliance)
✅ **Incentive transparency**: Token economics, payment splits, reputation publicly visible
✅ **No editorial control**: Algorithm validates, humans don't decide
✅ **Distributed liability**: No single operator controls validation
✅ **Open source**: Full code auditability and forkability

### Where TrustTune Has Trust Assumptions (Phase 1)

⚠️ **Worldcoin dependency**: Biometric verification requires third-party service (evaluating alternatives Phase 3)
⚠️ **External APIs**: MusicBrainz/AcoustID for mainstream metadata (permissionless human fallback for rare content)
⚠️ **Smart contract upgradeability**: Phase 1 uses upgradeable contracts with timelocks (transitioning to immutable Phase 3)
⚠️ **Gun.js relay infrastructure**: Community-operated relay nodes (core team may participate as community members with no special privileges or coordination role)

### Honest Self-Assessment

**TrustTune is a trust-minimized protocol**, not fully trustless by manifesto's strict definition:

- **MORE trustless than**: Spotify, Apple Music, iTunes, Bandcamp (orders of magnitude improvement)
- **LESS trustless than**: Bitcoin, Ethereum (due to Worldcoin dependency and Phase 1 bootstrapping)
- **Working toward**: Full trustlessness while acknowledging some dependencies may be permanent trade-offs for UX and permanence guarantees

**Key distinction**: Validation itself is trustless (algorithmic), but pressing layer has Worldcoin dependency. Users can verify quality without trust; permanent ownership requires trust in Worldcoin.

---

## Open Questions & Research Areas

This protocol is under active development. Several key components require real-world testing and iteration:

### Economics & Token System

**Unproven assumptions:**
- TRUST token conversion rate (1000 tokens = $1 USD) - needs market validation
- Reputation multiplier optimal range (1x-3x) - may need adjustment based on validator behavior
- Press conversion rates - assumed 1-5%, actual rates unknown until live
- Subscription adoption - Phase 2 sustainability depends on >10% subscriber conversion

**Open questions:**
- Algorithmic adjustment thresholds - are 6/3 month runway targets optimal?
- Should algorithm consider validation velocity (demand) in addition to treasury balance?
- How to handle token inflation if validation volume exceeds revenue?
- What's the optimal treasury reserve size for 6-12 month runway?
- Should workers be able to stake tokens for higher reputation faster?

**Pricing unknowns:**
- User willingness to pay $9.99-29.99 for albums vs. Spotify $10/month all-you-can-stream
- Will tiered pricing complexity confuse users or feel fair/transparent?
- Press-to-own conversion rates (assumed 1-5% but no real data until launch)
- Single vs. album preferences - will users only press favorite tracks, leaving albums incomplete?
- Price sensitivity by genre/artist (indie bands vs. major label catalog)
- Geographic pricing variations - can $14.99 work globally or need regional tiers?

### Protocol Scaling

**Gun.js at scale:**
- Tested up to ~1,000 nodes in existing deployments
- TrustTune targets 10,000+ worker nodes
- Unknown performance at 100K+ daily validation events
- Potential need for Gun.js optimization or alternative (e.g., OrbitDB, IPFS pubsub)

**Gun.js Relay Infrastructure Roadmap:**

Phase 1: Community-operated Gun.js relay network (from day 1)
- Community relay setup instructions: trusttune.network/relay-setup
- Anyone can run relay (consumer hardware: 4GB RAM, 100GB storage, 100Mbps connection)
- Core team may contribute relays AS COMMUNITY PARTICIPANTS (no special privileges)

Phase 1.5 (Q2 2025): Community relay incentive program
- TRUST token rewards for reliable relay operators
- Publish all relay addresses publicly: trusttune.network/relays
- Target: 10+ independent relay operators

Phase 2 (Q3 2025): Mature relay network
- Validator nodes can choose which relays to trust
- Direct peer-to-peer sync fallback (if all relays offline)
- No single entity controls majority of relays

**No single point of failure**: Gun.js syncs across multiple relays + direct P2P

**Worker node economics:**
- Assumed $45/month VPS costs - may vary by region/provider
- Bandwidth costs for large files (FLAC albums 1-2GB) not modeled in detail
- Race condition dynamics (multiple workers downloading same file) need monitoring
- Optimal worker-to-validation ratio unknown

### Reputation System

**Design questions:**
- How to bootstrap reputation for new workers? (cold start problem)
- Should reputation decay over time (incentivize ongoing quality)?
- How to detect and punish collusion between workers?
- Can we use zero-knowledge proofs to prevent validator identity gaming?

**Consensus mechanism:**
- Single validator vs. multi-validator consensus (2-3 workers per track)?
- If multi-validator: How to split compensation fairly?
- How to handle disagreements (e.g., 2 say FLAC, 1 says transcode)?

### Legal & Compliance

**Untested in court:**
- "Passive conduit" legal positioning is theory, not precedent
- DMCA compliance via distributed blocklist is novel - no case law
- Worldcoin biometric authentication in multiple jurisdictions (GDPR, CCPA)
- Solana smart contract jurisdiction (which country's laws apply?)

**Risks:**
- Platform could be targeted despite DMCA compliance
- Arweave permanence may conflict with "right to be forgotten" (EU)
- Worker nodes in hostile jurisdictions may face legal pressure
- Artist tax reporting (1099 equivalent) for on-chain payments

### Technology Maturity

**Dependencies still maturing:**
- Worldcoin SDK (beta, limited device support)
- Arweave storage costs (declining but not proven at 200+ years)
- Solana network stability (occasional congestion/downtime)
- AcoustID/MusicBrainz API rate limits at scale

**Integration challenges:**
- Flutter + Worldcoin SDK (mobile integration complexity)
- Gun.js + Solana (cross-chain coordination)
- Arweave upload pipeline (retry logic, failure handling)
- Real-time analytics queries on distributed ledger (performance)

### Community & Governance

**Open design questions:**
- Token conversion rate: Fully algorithmic (treasury-health-based), no governance control
- How to handle disputes (fake DMCA claims, malicious workers)?
- Should validators vote on protocol changes beyond economics? (on-chain governance for features)
- Artist onboarding: Self-service or curated? (quality vs. openness)

**Success unknown:**
- Will users care enough about quality to press tracks?
- Will artists promote TrustTune to fans? (chicken-and-egg)
- Will worker node operators emerge organically or need recruitment?
- Can we achieve network effects despite no VC marketing budget?

---

## Conclusion
TrustTune proves decentralized music distribution is feasible, superior, and defensible.
Technical:

Press-triggered validation (hybrid: nodes + volunteers)
Pluggable discovery (open source)
Biometric permanence (protocol-level)
70-85% transparent splits to artists (on-chain, tiered by file size)
Distributed compliance (Gun.js blocklist)

Economic:

Artists: 70-85% revenue (vs. Spotify 20-30%, iTunes 70%, Bandcamp 82%) - still industry-leading with permanent ownership
Workers: Token-based earnings (TRUST tokens, 100-450 per validation)
Protocol: 15-30% covers Arweave storage + validator fees + Solana gas + Gun.js relay costs + operations
Users: Permanent ownership via biometric access

Legal:

Search protocol (not host)
DMCA compliant (distributed blocklist)
Passive conduit (protected)
Protocol survives shutdown

If TrustTune disappears:

✅ Smart contracts on Solana
✅ Content on Arweave
✅ Biometric access persists
✅ Anyone builds new client
✅ Worker nodes continue
✅ Gun.js ledger survives

Music distribution operated under centralized control for a century. TrustTune proves an alternative where artists control compensation, listeners own libraries, workers compete to validate, and protocol survives corporate extinction.
The protocol is open. The code will be open source. The music belongs to those who create and cherish it.

TrustTune Network Whitepaper v1.0
Published: January 2026
Repository: github.com/trusttune/protocol
Contact: dev@trusttune.network | legal@trusttune.network

Note: For DMCA notices, contact individual validators directly. See permissionless blocklist section for distributed DMCA compliance approach.