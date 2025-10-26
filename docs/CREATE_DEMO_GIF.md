# 🎬 How to Create GUI Demo GIF

## Quick Method (macOS)

### 1. Record Screen
```bash
# Press Cmd+Shift+5
# Select "Record Selected Portion"
# Draw around the TrustTune window
# Click "Record"
# Do your demo (30-45 seconds max)
# Click stop in menu bar
# Video saves to ~/Desktop
```

### 2. Convert to Optimized GIF

**Option A: Using Gifski (Best Quality)**
```bash
# Install Gifski
brew install gifski

# Convert (replace with your video filename)
gifski --width 800 --fps 10 --quality 80 ~/Desktop/Screen\ Recording*.mov -o demo-gui.gif
```

**Option B: Using ffmpeg**
```bash
# Install ffmpeg
brew install ffmpeg

# Convert
ffmpeg -i ~/Desktop/Screen\ Recording*.mov \
  -vf "fps=10,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
  -loop 0 demo-gui.gif
```

## What to Show in Demo

**30-45 second flow:**

1. **Open app** (2s)
   - Show clean interface

2. **Search** (10s)
   - Type: "radiohead ok computer flac"
   - Show AI processing
   - Results appear with quality badges

3. **Browse results** (8s)
   - Scroll through ranked results
   - Hover to show quality indicators
   - Show seeders, size, format

4. **Download** (5s)
   - Click download button
   - Show green "Download started" message
   - Switch to Downloads tab

5. **Downloads tab** (5s)
   - Show torrent downloading
   - Progress bar moving

6. **Library** (10s)
   - Switch to Library tab
   - Show album art grid
   - Hover on album
   - Click play
   - Show player with waveform

## Size Optimization Tips

**Target:** < 3MB for README

- Keep it under 45 seconds
- Use 800px width (not full HD)
- Use 10 fps (not 30fps)
- Use quality 80 (not 100)
- Crop to just the app window (no desktop)

## Tools Comparison

| Tool | Quality | Size | Speed |
|------|---------|------|-------|
| **Gifski** | ⭐⭐⭐⭐⭐ | Medium | Fast |
| **ffmpeg** | ⭐⭐⭐⭐ | Small | Slow |
| **LICEcap** | ⭐⭐⭐ | Large | Real-time |
| **Online converters** | ⭐⭐ | Large | Slow |

## Add to README

Once you have `demo-gui.gif`:

```bash
# Move it to repo root
mv demo-gui.gif /path/to/karma-player/

# Edit README.md - Replace the TODO section with:
![TrustTune Demo](demo-gui.gif)
```

The line in README.md (around line 23):
```markdown
<!-- TODO: Add GUI demo GIF here -->
<p align="center">
  <i>Coming soon: Animated demo of TrustTune GUI</i>
</p>
```

Replace with:
```markdown
<p align="center">
  <img src="demo-gui.gif" alt="TrustTune Demo" width="800">
</p>
```

## Alternative: Multiple Screenshots

If GIF is still too big, use screenshots instead:

```bash
# Take 3-4 key screenshots
# Save as: search.png, results.png, downloads.png, library.png

# Compress them
brew install pngquant
pngquant --quality 65-80 search.png results.png downloads.png library.png

# Move to repo
mv search-fs8.png screenshots/search.png
# etc.
```

Then in README:
```markdown
<p align="center">
  <img src="screenshots/search.png" width="400">
  <img src="screenshots/results.png" width="400">
</p>
<p align="center">
  <img src="screenshots/downloads.png" width="400">
  <img src="screenshots/library.png" width="400">
</p>
```

## Pro Tips

- Record at 2x monitor scale, resize to 1x (sharper)
- Clean up desktop before recording
- Close notification banners
- Use a clean test query everyone knows
- Show the "wow" moments (AI ranking, quality badges, player)
- Keep mouse movements smooth and purposeful
- Add a 1-second pause at key moments
