# 🚀 Release Checklist

## Before Tagging Release

- [ ] Update version in `gui/pubspec.yaml`
- [ ] Update version in `pyproject.toml` (if needed)
- [ ] Update `CHANGELOG.md`
- [ ] Commit changes: `git commit -m "Bump version to X.X.X"`
- [ ] Push to main: `git push origin main`

## Create Release

```bash
git tag vX.X.X
git push origin vX.X.X
```

This triggers GitHub Actions to:
1. Build macOS/Windows/Linux apps
2. Bundle Transmission in each
3. Create GitHub Release with downloads

## After Release (Manual Testing)

### Test macOS Build

1. **Download from Release:**
   - Go to: https://github.com/trust-tune-net/karma-player/releases/latest
   - Download: `TrustTune-macOS.zip`

2. **Test on fresh Mac (no Homebrew, no Transmission):**
   ```bash
   # Extract
   unzip TrustTune-macOS.zip

   # Open
   open trusttune_gui.app
   ```

3. **Verify:**
   - [ ] App opens without errors
   - [ ] Search for "radiohead" works
   - [ ] Click download button
   - [ ] Transmission daemon starts automatically (check Activity Monitor)
   - [ ] Download progresses in Downloads tab
   - [ ] File appears in ~/Music

4. **Check daemon:**
   ```bash
   # Should show transmission-daemon running
   ps aux | grep transmission-daemon

   # Should work
   transmission-remote -l
   ```

### Test Windows Build

1. **Download:** `TrustTune-Windows.zip`
2. **Extract and run:** `trusttune_gui.exe`
3. **Verify same steps as macOS**

### Test Linux Build

1. **Download:** `TrustTune-Linux.tar.gz`
2. **Extract and run:** `./trusttune_gui`
3. **Verify same steps as macOS**

## If Tests Fail

### Transmission not starting?

**Debug:**
```bash
# Check if binary exists
ls -la TrustTune.app/Contents/Resources/bin/transmission-daemon

# Try running manually
TrustTune.app/Contents/Resources/bin/transmission-daemon --version

# Check library paths
otool -L TrustTune.app/Contents/Resources/bin/transmission-daemon
```

**Common Issues:**
- ❌ Library paths not relative → Re-run release with fixed workflow
- ❌ Binary not executable → `chmod +x` missing in workflow
- ❌ Libraries not copied → Check workflow copy step

### App crashes on launch?

**Check logs:**
```bash
# macOS
log show --predicate 'process == "trusttune_gui"' --last 1m

# Or Console.app → search for "trusttune_gui"
```

## Success Criteria

✅ **Users can:**
1. Download ZIP from GitHub
2. Extract and open app
3. Search for music
4. Download torrents **without installing Transmission**
5. Everything works out of the box

## Rollback Plan

If release is broken:
1. Delete GitHub release
2. Delete tag: `git tag -d vX.X.X && git push origin :refs/tags/vX.X.X`
3. Fix issues
4. Re-release with new version

---

**The Goal:** Grandma downloads the app, double-clicks, searches "beatles", clicks download, it works. Zero technical knowledge required.
