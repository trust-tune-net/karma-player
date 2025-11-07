# 🔧 Troubleshooting Guide

This guide covers common issues and their solutions when using TrustTune.

## Table of Contents

- [Security Warnings](#security-warnings)
- [Common Issues](#common-issues)
- [Debug Logs](#debug-logs)
- [Bug Reporting](#bug-reporting)

---

## Security Warnings

### ⚠️ Expected Security Warnings

**TrustTune is not code-signed**, so you'll see security warnings on first launch. This is normal and expected for open-source software.

### macOS Security Warning

**⚠️ First, make sure you downloaded the correct version for your Mac:**
- **Intel Macs** (2020 and earlier): Use `KarmaPlayer-macOS-Intel.zip`
- **Apple Silicon** (M1/M2/M3+): Use `KarmaPlayer-macOS-AppleSilicon.zip`

When you first run KarmaPlayer on macOS, you'll see:
> **"KarmaPlayer.app cannot be opened because it is from an unidentified developer"**

**How to fix:**

**Option 1: Right-click method**
1. Right-click (or Control+click) on `KarmaPlayer.app`
2. Select **"Open"** from the menu
3. Click **"Open"** in the security dialog

**Option 2: System Settings method**
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

### Windows Security Warning

Windows Defender SmartScreen may show:
> **"Windows protected your PC"**

**How to fix:**
1. Click **"More info"**
2. Click **"Run anyway"**

**Why this happens:**
- Windows flags unsigned applications
- KarmaPlayer is safe - check the source code yourself
- Once allowed, Windows will remember your choice

### Linux Permission Issues

If KarmaPlayer won't run on Linux:

```bash
# Make it executable
chmod +x KarmaPlayer

# If transmission-daemon won't start
chmod +x resources/bin/transmission-daemon
```

---

## Common Issues

### "Bad CPU type in executable" (macOS)

**Cause:** Downloaded wrong architecture version

**Fix:**
- Check your Mac processor: Apple menu () → About This Mac
- **Intel processor**: Download `KarmaPlayer-macOS-Intel.zip`
- **Apple M1/M2/M3**: Download `KarmaPlayer-macOS-AppleSilicon.zip`
- Delete the wrong version and download the correct one

### "Transmission daemon failed to start"

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

### YouTube downloads not working (Windows)

**Cause:** yt-dlp not in PATH or missing ffmpeg

**Fix:**
- KarmaPlayer bundles yt-dlp automatically on Windows
- If issues persist, restart KarmaPlayer
- Check logs: `%APPDATA%\Local\com.example.karma_player\logs\`

### Audio not playing

**Cause:** Missing audio codecs or permissions

**Fix:**
- **macOS:** Grant microphone/audio permissions in System Settings
- **Windows:** Install Windows Media Feature Pack
- **Linux:** Install `libmpv` and `ffmpeg`

### Search not returning results

**Cause:** Remote API connectivity issue

**Fix:**
- Check your internet connection
- Verify no firewall is blocking gRPC connections (port 50051)
- The search uses a remote API - no local configuration needed
- Check the app logs for detailed error messages

### Library not updating

**Cause:** Permission issues or corrupted database

**Fix:**
```bash
# macOS
rm -rf ~/Library/Application\ Support/com.example.karma_player/library.db

# Linux
rm -rf ~/.local/share/com.example.karma_player/library.db

# Windows (PowerShell)
Remove-Item "$env:APPDATA\Local\com.example.karma_player\library.db"
```

---

## Debug Logs

**Log locations:**

- **macOS:**
  - `~/Library/Application Support/com.example.karma_player/logs/`
  - `/tmp/log/karmaplayer.log`

- **Windows:**
  - `%APPDATA%\Local\com.example.karma_player\logs\`

- **Linux:**
  - `~/.local/share/com.example.karma_player/logs/`

**View logs:**

```bash
# macOS - View latest log
cat "$(ls -t ~/Library/Application\ Support/com.example.karma_player/logs/*.log | head -1)"

# macOS - Quick log
cat /tmp/log/karmaplayer.log

# Linux - View latest log
cat "$(ls -t ~/.local/share/com.example.karma_player/logs/*.log | head -1)"
```

Check logs for detailed error messages if something goes wrong.

---

## Bug Reporting

### 🐛 Found a Bug? Help Us Fix It!

If you're experiencing issues, **please help us improve KarmaPlayer** by reporting them.

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
5. Include your system information:
   - Operating system and version
   - CPU architecture (Intel/ARM)
   - TrustTune version
6. Submit!

**Your bug reports help everyone.** Every issue fixed makes KarmaPlayer better for the community. Thank you! 🙏

---

## Still Having Issues?

If you can't find a solution here:

1. **Search GitHub Issues**: Someone may have already reported and solved your issue
2. **Ask in Discussions**: [GitHub Discussions](https://github.com/trust-tune-net/karma-player/discussions)
3. **Report a Bug**: [Create an issue](https://github.com/trust-tune-net/karma-player/issues/new)

---

[← Back to README](README.md)
