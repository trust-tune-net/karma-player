# 🚀 TrustTune Setup Guide

## First-Time Setup (5 minutes)

TrustTune needs **Transmission** to download music. Here's how to set it up:

### macOS

**Option 1: Homebrew (Recommended)**
```bash
# Install Transmission
brew install transmission

# Start the daemon
transmission-daemon

# Done! TrustTune can now download torrents
```

**Option 2: Download GUI App**
1. Download from: https://transmissionbt.com/download
2. Install Transmission.app
3. Open Transmission.app
4. It will auto-start the daemon
5. Keep it running in the background

### Windows

1. Download from: https://transmissionbt.com/download
2. Install Transmission
3. Run Transmission (keep it open)
4. TrustTune will connect automatically

### Linux

**Ubuntu/Debian:**
```bash
sudo apt install transmission-daemon
sudo systemctl start transmission-daemon
sudo systemctl enable transmission-daemon
```

**Fedora:**
```bash
sudo dnf install transmission-daemon
sudo systemctl start transmission-daemon
sudo systemctl enable transmission-daemon
```

## Verify It's Working

Run this command:
```bash
transmission-remote -l
```

You should see:
```
ID   Done  Have  ETA  Up   Down  Ratio  Status  Name
Sum:       None              0.0    0.0  None
```

If you see `Connection refused`, Transmission isn't running.

## Common Issues

### "Connection refused" Error

**Problem:** Transmission daemon isn't running

**Fix (macOS):**
```bash
# Check if it's running
ps aux | grep transmission-daemon

# If not running, start it:
transmission-daemon

# To auto-start on login (optional):
brew services start transmission
```

**Fix (Linux):**
```bash
# Check status
sudo systemctl status transmission-daemon

# Start it
sudo systemctl start transmission-daemon
```

### Permission Errors

**Fix (Linux):**
```bash
# Add your user to transmission group
sudo usermod -a -G debian-transmission $USER

# Reload groups
newgrp debian-transmission
```

### Wrong Port

By default, Transmission uses port `9091`. If you changed it:

1. Open TrustTune
2. Go to Settings
3. Change "Transmission RPC URL" to match your port
4. Save

## Advanced: Auto-Start on Boot

**macOS:**
```bash
brew services start transmission
```

**Linux (systemd):**
```bash
sudo systemctl enable transmission-daemon
```

**Windows:**
- Right-click Transmission icon in system tray
- Enable "Start when Windows starts"

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
