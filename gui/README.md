# TrustTune Desktop GUI

Flutter desktop app for TrustTune - AI-powered music torrent search.

## Quick Start

**Note:** Start scripts are located at repo root: `/Users/fcavalcanti/dev/karma-player/`

### Option 1: Simple Mode (Recommended for beginners)

```bash
cd /Users/fcavalcanti/dev/karma-player
./start.sh
```

Shows Flutter output in terminal. API logs saved to `/tmp/trusttune-api.log`.

### Option 2: Split-Screen Mode (Recommended for development)

```bash
cd /Users/fcavalcanti/dev/karma-player
./start-split.sh
```

**Split-screen layout with tmux:**

```
┌─────────────────────────────────────────┐
│  BACKEND API LOGS (port 3000)           │  ← Real-time API logs
│─────────────────────────────────────────│
│  FLUTTER DESKTOP APP                    │  ← App output
└─────────────────────────────────────────┘
```

**Features:**
- 📊 Real-time logs for both backend and frontend
- 🎨 Color-coded output (INFO=cyan, WARNING=yellow, ERROR=red)
- ⌨️ Easy navigation with keyboard shortcuts

**tmux Controls:**
- `Ctrl+B` then `↑/↓` - Switch between panes
- `Ctrl+B` then `[` - Scroll mode (press `q` to exit)
- `Ctrl+B` then `d` - Detach (keeps running in background)
- Type `q` in Flutter pane - Quit app and exit

Both scripts automatically:
1. ✅ Kill any existing processes
2. 📦 Install Python dependencies (via `poetry install`)
3. 🖥️ Start the Python API server (port 3000)
4. 🧹 Clean Flutter build artifacts
5. 🚀 Launch the Flutter desktop app
6. 🛑 Auto-cleanup when you close the app

## Architecture

```
┌─────────────────────┐         WebSocket         ┌──────────────────────┐
│   Flutter Desktop   │ ◄───────────────────────► │   Python FastAPI     │
│   (GUI)             │   ws://localhost:3000     │   (Backend)          │
│                     │                           │                      │
│  - Real-time UI     │                           │  - SimpleSearch      │
│  - Progress updates │                           │  - Quality scoring   │
│  - Results display  │                           │  - Jackett adapter   │
└─────────────────────┘                           └──────────────────────┘
```

## Features

- 🔍 **Real-time Search** - WebSocket-based live progress updates
- 🎯 **Quality Scoring** - Intelligent ranking (FLAC 24/192 = 360pts, FLAC = 200pts, etc.)
- 🌐 **Jackett Integration** - Access to multiple torrent indexers
- 🎨 **Material Design 3** - Modern, clean interface
- ⚡ **Fast** - ~9 second searches with deterministic scoring

## Monitoring Logs

### Simple Mode (`./start.sh`)
- Flutter output shows in main terminal
- API logs: `tail -f /tmp/trusttune-api.log` (in separate terminal)

### Split-Screen Mode (`./start-split.sh`)
- Both logs visible simultaneously in split panes
- Color-coded for easy reading:
  - 🔵 INFO - Cyan
  - 🟡 WARNING - Yellow
  - 🔴 ERROR - Red
  - 🟣 WebSocket - Magenta

## Development

### API Server (Python)
```bash
cd /Users/fcavalcanti/dev/karma-player
poetry run python -m karma_player.api.server
```

### Flutter App
```bash
cd /Users/fcavalcanti/dev/karma-player/gui
flutter run -d macos
```

## Troubleshooting

### Port Already in Use

```bash
# Kill existing processes
pkill -f "python -m karma_player.api.server"
pkill -f "flutter run"

# Or just run the start script - it does this automatically!
./start.sh
```

## What's Next

See `docs/ARCHITECTURE.md` for the full roadmap:

- [ ] Download functionality (libtorrent)
- [ ] Music player (media_kit)
- [ ] File organization
- [ ] App packaging (.dmg)

## Tech Stack

- **Frontend:** Flutter 3.35.7, Dart 3.9.2
- **Backend:** Python 3.10+, FastAPI
- **WebSocket:** web_socket_channel ^3.0.1
- **Search:** SimpleSearch (no MusicBrainz complexity)
- **Indexers:** Jackett remote instance
