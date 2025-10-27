# 🚀 TrustTune Setup Guide

## First-Time Setup (1 minute!)

**Good news!** TrustTune now comes with Transmission bundled - no separate installation needed!

The app will automatically start the Transmission daemon when you first search for music.

## How It Works

TrustTune includes a bundled Transmission daemon that runs in the background:

- **macOS**: Automatically starts when needed
- **Windows**: Automatically starts when needed
- **Linux**: Automatically starts when needed

You don't need to install or configure anything!

## Quick Start

1. **Download TrustTune** for your platform (macOS/Windows/Linux)
2. **Launch the app** - It will auto-start Transmission in the background
3. **Search for music** - Try: "radiohead ok computer flac"
4. **Click Download** - Your music will start downloading automatically!

That's it! The app handles everything else.

## Troubleshooting

### "Cannot connect to Transmission" Error

**Solution:** The bundled daemon failed to start. Try:
1. Restart TrustTune
2. Check if another Transmission instance is running and close it
3. On Linux, ensure you have the required libraries (they're usually pre-installed)

### Downloads Not Starting

**Solution:**
1. Check the "Downloads" tab in TrustTune
2. Verify you have disk space in your Music folder
3. Some torrents may have 0 seeders - try a different result

### Using Your Own Transmission

If you prefer to use your own Transmission installation:
1. Install Transmission normally (see "Advanced Setup" below)
2. Start it before launching TrustTune
3. TrustTune will detect and use your existing installation

## Advanced Setup (Optional)

### Using External Transmission

If you want more control, you can install Transmission separately:

**macOS:**
```bash
brew install transmission
brew services start transmission
```

**Windows:**
Download from: https://transmissionbt.com/download

**Linux:**
```bash
sudo apt install transmission-daemon
sudo systemctl start transmission-daemon
```

## First Download Test

Once Transmission is running:

1. Open TrustTune
2. Search: `radiohead ok computer flac`
3. Click any result's download button
4. Switch to "Downloads" tab
5. You should see progress!

If you see "Transmission Not Running" dialog:
- Follow the instructions in the dialog
- Or refer back to this guide

## Need Help?

- Check if daemon is running: `transmission-remote -l`
- Check logs: `~/.config/transmission-daemon/` (Linux) or Console.app (macOS)
- Open an issue: https://github.com/trust-tune-net/karma-player/issues

---

**That's it!** Once Transmission is running, TrustTune handles everything else automatically.
