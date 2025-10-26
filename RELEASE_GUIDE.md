# 🚀 Release Guide

## Quick Release

```bash
./release.sh
```

That's it! The script will guide you through the process interactively.

## What the Script Does

**1. Safety Checks**
- ✅ Verifies you're on `main` branch
- ✅ Ensures working directory is clean

**2. Version Selection**
Shows current version and offers:
- `1` → Patch release (v0.1.2-beta) - Bug fixes
- `2` → Minor release (v0.2.0-beta) - New features
- `3` → Major release (v1.0.0-beta) - Breaking changes
- `4` → Custom version

**3. Release Description**
- Simple one-line input
- Just type and press Enter
- Leave empty to auto-generate

**4. Beautiful Summary**
Shows exactly what will happen:
- New version number
- Previous version
- Your description
- Build targets (macOS, Windows, Linux)

**5. Confirmation**
- Type `y` to proceed
- Type `n` to cancel

**6. Automatic Build & Release**
Once you confirm:
- Creates git tag
- Pushes to GitHub
- GitHub Actions automatically:
  - Builds macOS binary
  - Builds Windows binary
  - Builds Linux binary
  - Creates GitHub Release
  - Uploads all downloads

## Example Flow

```bash
$ ./release.sh

═══════════════════════════════════════════════════
   🚀 TrustTune Release Script 🚀
═══════════════════════════════════════════════════

✅ On main branch
✅ Working directory clean
ℹ️ Current version: v0.1.1-beta

Select version to release:
1) v0.1.2-beta  (patch - bug fixes)
2) v0.2.0-beta  (minor - new features)
3) v1.0.0-beta  (major - breaking changes)
4) Custom version

Enter choice [1-4]: 1

🏷️ Selected version: v0.1.2-beta

Release description: Library refresh now updates top bar stats

═══════════════════════════════════════════════════
                Release Summary
═══════════════════════════════════════════════════
Version:      v0.1.2-beta
Previous:     v0.1.1-beta
Branch:       main
Description:  Library refresh now updates top bar stats

🔨 This will trigger GitHub Actions to:
  ✅ Build macOS binary
  ✅ Build Windows binary
  ✅ Build Linux binary
  ✅ Create GitHub Release with all downloads
═══════════════════════════════════════════════════

Proceed with release? [y/N]: y

⬆️ Creating and pushing release...
ℹ️ Pulling latest changes...
ℹ️ Creating tag v0.1.2-beta...
ℹ️ Pushing tag to origin...

═══════════════════════════════════════════════════
   🚀 Release v0.1.2-beta created successfully! 🚀
═══════════════════════════════════════════════════

ℹ️ GitHub Actions is now building your release...
ℹ️ Track progress at:
   https://github.com/trust-tune-net/karma-player/actions

ℹ️ Release will be available at:
   https://github.com/trust-tune-net/karma-player/releases/tag/v0.1.2-beta

📦 Downloads will automatically be available via:
   • macOS:   releases/latest/download/TrustTune-macOS.zip
   • Windows: releases/latest/download/TrustTune-Windows.zip
   • Linux:   releases/latest/download/TrustTune-Linux.tar.gz

✅ All done! 🚀
```

## After Release

**GitHub Actions will automatically:**
1. Build all 3 platforms (takes ~5-10 minutes)
2. Create GitHub Release with your description
3. Upload all binaries
4. Make them available at `/releases/latest/` URLs

**README badges automatically update:**
- Latest release version
- Build status (passing/failing)
- Total download count

## Troubleshooting

**"Not on main branch"**
```bash
git checkout main
git pull
```

**"Working directory has uncommitted changes"**
```bash
git status  # See what's changed
git add .
git commit -m "Your changes"
# Then run ./release.sh again
```

**Release build failed?**
- Check GitHub Actions: https://github.com/trust-tune-net/karma-player/actions
- Look for error messages in workflow logs
- Common issues: Flutter version, dependencies, signing

## Manual Release (Not Recommended)

If the script doesn't work for some reason:

```bash
# Create tag manually
git tag -a v0.1.2-beta -m "Your release description"
git push origin v0.1.2-beta
```

This will still trigger GitHub Actions to build everything.
