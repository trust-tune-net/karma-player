# 🚀 TrustTune Implementation Plan

> Week-by-week guide to building Phase 0 MVP

---

## Overview

**Goal:** Working desktop app in 8-12 weeks
**Target:** macOS + Windows (Linux bonus)
**MVP Features:** Search, download, play—Grandma-ready

---

## Week 1-2: Foundation & Spike

### Goals
1. Set up project structure
2. Deploy minimal Community API
3. Prove Flutter ↔ Python ↔ API communication
4. Make first successful AI search

### Tasks

**Day 1-2: Project Setup**
```bash
# Create project structure
cd /Users/fcavalcanti/dev/karma-player

# Python service
mkdir -p karma_player/{api,services,models,database}
touch karma_player/api/server.py
touch karma_player/services/{ai_client,musicbrainz,torrent_search}.py

# Flutter app
cd /Users/fcavalcanti/dev/trust-tune-network
flutter create karma_player_gui
cd karma_player_gui

# Install dependencies
flutter pub add http web_socket_channel riverpod media_kit

# Python dependencies
cd /Users/fcavalcanti/dev/karma-player
poetry add fastapi uvicorn httpx musicbrainzngs libtorrent
```

**Day 3-4: Community API Spike**
```bash
# Deploy minimal API to Railway.app
mkdir api-server
cd api-server

# Create FastAPI app
cat > main.py <<EOF
from fastapi import FastAPI
from groq import Groq
import os

app = FastAPI()
groq = Groq(api_key=os.getenv("GROQ_API_KEY"))

@app.post("/search/parse")
async def parse_query(query: str):
    response = groq.chat.completions.create(
        model="llama-3.1-70b-versatile",
        messages=[{
            "role": "system",
            "content": "Parse music query. Return JSON: {artist, album, track, type}"
        }, {
            "role": "user",
            "content": query
        }]
    )
    return response.choices[0].message.content
EOF

# Deploy to Railway
railway init
railway up
# Get URL: https://trusttune-api-production.up.railway.app
```

**Day 5-7: Integration Spike**

```dart
// Flutter: Call Community API
import 'package:http/http.dart' as http;

Future<void> testSearch() async {
  final response = await http.post(
    Uri.parse('https://trusttune-api-production.up.railway.app/search/parse'),
    body: {'query': 'radiohead ok computer'}
  );

  print(response.body);  // Should print parsed query
}
```

```python
# Python: Start local service
# karma_player/api/server.py
from fastapi import FastAPI
import uvicorn

app = FastAPI()

@app.post("/search")
async def search(query: str):
    # Call Community API
    ai_client = CommunityAPIClient()
    parsed = await ai_client.parse_query(query)

    # For now, return mock results
    return {"query": parsed, "results": []}

if __name__ == "__main__":
    uvicorn.run(app, host="localhost", port=8765)
```

```dart
// Flutter: Call local Python service
Future<void> searchMusic(String query) async {
  final response = await http.post(
    Uri.parse('http://localhost:8765/search'),
    body: {'query': query}
  );

  print(response.body);
}
```

**Milestone:** End-to-end test: Flutter → Python → Community API → Response

---

## Week 3-4: Conversational Search UI

### Goals
1. Beautiful search screen
2. AI question flow
3. MusicBrainz integration
4. Display results (no download yet)

### Tasks

**Flutter Search Screen**
```dart
// lib/screens/search_screen.dart
class SearchScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      body: Column(
        children: [
          // Search input
          TextField(
            decoration: InputDecoration(
              hintText: 'What music are you looking for?',
              prefixIcon: Icon(Icons.music_note)
            ),
            onSubmitted: (query) {
              ref.read(searchProvider.notifier).search(query);
            }
          ),

          // Loading / Questions / Results
          searchState.when(
            loading: () => LoadingIndicator(),
            data: (data) => ResultsList(results: data),
            error: (err, stack) => ErrorMessage(error: err)
          )
        ]
      )
    );
  }
}
```

**Question Flow**
```dart
// lib/widgets/question_dialog.dart
class QuestionDialog extends StatelessWidget {
  final Question question;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(question.title),
      content: Column(
        children: question.options.map((opt) =>
          RadioListTile(
            title: Text(opt.label),
            subtitle: Text(opt.description),
            value: opt.value,
            onChanged: (value) {
              // Send answer to API
              ref.read(searchProvider.notifier).answer(value);
              Navigator.pop(context);
            }
          )
        ).toList()
      )
    );
  }
}
```

**Python: MusicBrainz Integration**
```python
# karma_player/services/musicbrainz.py
import musicbrainzngs as mb

mb.set_useragent("TrustTune", "0.1.0", "contact@trusttune.dev")

async def search_releases(artist: str, album: str, limit: int = 25):
    result = mb.search_releases(
        artist=artist,
        release=album,
        limit=limit
    )

    return [
        MBResult(
            mbid=r["id"],
            title=r["title"],
            artist=r["artist-credit-phrase"],
            release_date=r.get("date", ""),
            country=r.get("country", ""),
        )
        for r in result["release-list"]
    ]
```

**Community API: MusicBrainz Filtering**
```python
# api-server/routes/search.py
@app.post("/musicbrainz/filter")
async def filter_musicbrainz(
    results: List[dict],
    query: dict
):
    prompt = f"""
    Given these MusicBrainz results:
    {json.dumps(results, indent=2)}

    User searched for: {query}

    Which is the best match? Consider:
    - Original release date
    - Country (prefer original)
    - Remaster vs original
    - Label reputation

    Return JSON:
    {{
      "best_match_index": 0,
      "reasoning": "...",
      "confidence": 0.95
    }}
    """

    response = groq.chat.completions.create(
        model="llama-3.1-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        response_format={"type": "json_object"}
    )

    return json.loads(response.choices[0].message.content)
```

**Milestone:** User can search, AI asks 1-2 questions, shows curated results (mock torrents)

---

## Week 5-6: Torrent Search & Download

### Goals
1. Integrate libtorrent
2. DHT search working
3. Download with progress bar
4. File organization

### Tasks

**Torrent Engine**
```python
# karma_player/services/torrent_engine.py
import libtorrent as lt
from pathlib import Path

class TorrentEngine:
    def __init__(self, download_dir: Path):
        self.session = lt.session()
        self.session.listen_on(6881, 6891)
        self.downloads = {}

    def add_magnet(self, magnet: str, download_id: str):
        params = {
            "save_path": str(self.download_dir),
        }
        handle = lt.add_magnet_uri(self.session, magnet, params)
        self.downloads[download_id] = handle

        return download_id

    def get_progress(self, download_id: str):
        handle = self.downloads[download_id]
        status = handle.status()

        return {
            "percent": status.progress * 100,
            "download_rate": status.download_rate,
            "upload_rate": status.upload_rate,
            "state": str(status.state)
        }
```

**WebSocket for Progress**
```python
# karma_player/api/websocket.py
from fastapi import WebSocket
import asyncio

@app.websocket("/ws/download/{download_id}")
async def download_progress(websocket: WebSocket, download_id: str):
    await websocket.accept()

    while True:
        progress = torrent_engine.get_progress(download_id)
        await websocket.send_json(progress)

        if progress["percent"] >= 100:
            break

        await asyncio.sleep(1)
```

**Flutter: Download Manager**
```dart
// lib/services/download_service.dart
class DownloadService {
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8765/ws/download/...')
  );

  Stream<DownloadProgress> watchDownload() {
    return channel.stream.map((data) =>
      DownloadProgress.fromJson(jsonDecode(data))
    );
  }
}
```

**File Organization**
```python
# karma_player/services/file_manager.py
from mutagen.flac import FLAC
from mutagen.mp3 import MP3
from mutagen.id3 import TIT2, TPE1, TALB

def organize_download(file_path: Path, metadata: MBResult):
    # Tag file
    if file_path.suffix == ".flac":
        audio = FLAC(file_path)
        audio["title"] = metadata.title
        audio["artist"] = metadata.artist
        audio["album"] = metadata.album
        audio.save()

    # Move to organized folder
    dest = music_dir / metadata.artist / metadata.album / file_path.name
    dest.parent.mkdir(parents=True, exist_ok=True)
    file_path.rename(dest)

    return dest
```

**Milestone:** User can download a torrent, see progress, file auto-organized

---

## Week 7-8: Built-in Player

### Goals
1. Integrate media_kit
2. Play downloaded tracks
3. Queue management
4. Basic controls

### Tasks

**Player Integration**
```dart
// lib/services/player_service.dart
import 'package:media_kit/media_kit.dart';

class PlayerService {
  late final Player player;

  PlayerService() {
    player = Player();
  }

  Future<void> play(String filePath) async {
    await player.open(Media(filePath));
    await player.play();
  }

  Future<void> pause() async {
    await player.pause();
  }

  Stream<Duration> get positionStream => player.stream.position;
  Stream<Duration> get durationStream => player.stream.duration;
}
```

**Player UI**
```dart
// lib/widgets/player_bar.dart
class PlayerBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);

    return Container(
      height: 80,
      child: Row(
        children: [
          // Album art
          Image.file(player.currentTrack?.albumArt),

          // Track info
          Column(
            children: [
              Text(player.currentTrack?.title),
              Text(player.currentTrack?.artist)
            ]
          ),

          // Controls
          IconButton(
            icon: Icon(Icons.skip_previous),
            onPressed: player.previous
          ),
          IconButton(
            icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: player.isPlaying ? player.pause : player.play
          ),
          IconButton(
            icon: Icon(Icons.skip_next),
            onPressed: player.next
          ),

          // Progress slider
          Slider(
            value: player.position.inSeconds.toDouble(),
            max: player.duration.inSeconds.toDouble(),
            onChanged: (value) {
              player.seek(Duration(seconds: value.toInt()));
            }
          )
        ]
      )
    );
  }
}
```

**Milestone:** Downloaded music plays in-app, with controls

---

## Week 9-10: Polish & Testing

### Goals
1. Error handling
2. Loading states
3. First-run wizard
4. Settings screen
5. Alpha testing

### Tasks

**First-Run Wizard**
```dart
// lib/screens/onboarding_screen.dart
class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String musicFolder = "";

  @override
  void initState() {
    super.initState();
    // Auto-detect ~/Music
    musicFolder = "${Platform.environment['HOME']}/Music";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text("Welcome to TrustTune!"),
          Text("Where should I save your music?"),

          TextField(
            controller: TextEditingController(text: musicFolder),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                icon: Icon(Icons.folder),
                onPressed: _pickFolder
              )
            )
          ),

          ElevatedButton(
            child: Text("Get Started"),
            onPressed: () {
              // Save settings
              ref.read(settingsProvider).setMusicFolder(musicFolder);

              // Navigate to search
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => SearchScreen())
              );
            }
          )
        ]
      )
    );
  }
}
```

**Error Handling**
```dart
// Show user-friendly errors
try {
  await search(query);
} on NetworkException {
  showSnackBar("Can't connect to TrustTune servers. Check your internet.");
} on RateLimitException {
  showSnackBar("Daily search limit reached. Try again tomorrow or upgrade.");
} on Exception catch (e) {
  showSnackBar("Something went wrong: $e");
}
```

**Alpha Testing**
- Recruit 10 testers (mix of technical + non-technical)
- Set up feedback form (Typeform / Google Forms)
- Monitor Community API usage
- Track errors in Sentry

**Milestone:** 10 users can search, download, play—with <5 bugs reported

---

## Week 11-12: Packaging & Distribution

### Goals
1. Build installers
2. Code signing (macOS)
3. Create website landing page
4. Public beta launch

### Tasks

**macOS Installer**
```bash
# Build release
flutter build macos --release

# Create DMG
npm install -g create-dmg
create-dmg build/macos/Build/Products/Release/TrustTune.app

# Code sign (requires Apple Developer account)
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name" \
  TrustTune.app

# Notarize
xcrun notarytool submit TrustTune.dmg \
  --apple-id your@email.com \
  --password your-app-password \
  --team-id YOUR_TEAM_ID
```

**Windows Installer**
```bash
# Build release
flutter build windows --release

# Create installer with Inno Setup
iscc windows-installer.iss
```

**Landing Page** (trusttune.dev)
```html
<!DOCTYPE html>
<html>
<head>
  <title>TrustTune - Music Discovery for Everyone</title>
</head>
<body>
  <h1>Find Music. Simply.</h1>
  <p>AI-powered music discovery that anyone can use.</p>

  <a href="https://github.com/trusttune/trusttune/releases/latest/download/TrustTune-macos.dmg">
    Download for macOS
  </a>

  <a href="https://github.com/trusttune/trusttune/releases/latest/download/TrustTune-windows.exe">
    Download for Windows
  </a>

  <video src="demo.mp4" autoplay loop></video>
</body>
</html>
```

**Milestone:** Public beta launch with 100 users

---

## Community API Deployment Checklist

### Pre-Launch
- [ ] Set up Railway.app account
- [ ] Get Groq API key (free tier)
- [ ] Get Together.ai API key (backup)
- [ ] Set up Redis (Railway add-on)
- [ ] Set up PostgreSQL (Railway add-on)
- [ ] Configure rate limiting (50/day anonymous)
- [ ] Set up Cloudflare (CDN + DDoS)

### Monitoring
- [ ] Set up Sentry (error tracking)
- [ ] Prometheus + Grafana (metrics)
- [ ] Status page (status.trusttune.community)
- [ ] Alerts (PagerDuty / email)

### Scaling Plan
- [ ] 100 users: Free tier
- [ ] 1,000 users: Add Together.ai fallback
- [ ] 10,000 users: Upgrade Railway plan ($20/mo)
- [ ] 100,000 users: Move to AWS/GCP

---

## Testing Strategy

### Unit Tests (Python)
```bash
pytest karma_player/tests/
```

### Widget Tests (Flutter)
```bash
flutter test
```

### Integration Tests
```bash
# Start Python service
python -m karma_player.main &

# Run Flutter integration tests
flutter test integration_test/search_flow_test.dart
```

### E2E Tests (Manual)
1. **Grandma Test:**
   - Give app to non-technical person
   - Can they find and play music?
   - Time: <5 minutes?

2. **Stress Test:**
   - 10 simultaneous downloads
   - App remains responsive?

3. **Edge Cases:**
   - No internet (graceful error)
   - Rate limit hit (clear message)
   - Bad torrent (handle timeout)

---

## Success Criteria (MVP)

**User Experience:**
- ✅ Install in <3 clicks
- ✅ Search to music playing in <2 minutes
- ✅ 80% find it "easy to use"
- ✅ Works offline after download

**Technical:**
- ✅ <5 second search latency (p95)
- ✅ Community API 99.5% uptime
- ✅ <5 critical bugs in beta
- ✅ Works on macOS 12+ and Windows 10+

**Growth:**
- ✅ 100 beta users (Month 3)
- ✅ 50% weekly retention
- ✅ 10 searches/user/week

---

## Next Steps After MVP

### Phase 1 (Months 4-6)
- User accounts (optional)
- Curator system
- Mobile apps (iOS/Android)

### Phase 2 (Months 7-12)
- Federation protocol
- P2P trust network
- Self-hosting support

### Phase 3 (Year 2)
- Creator payments
- Blockchain integration
- Full decentralization

---

**Ready to start Week 1?** Let's build! 🚀

---

*Last updated: January 2025*
