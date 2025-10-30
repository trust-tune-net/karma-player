// YouTube Download Service - yt-dlp Approach
//
// Downloads YouTube Music audio to temp files for playback.
// Uses yt-dlp to handle all YouTube complexity (signatures, auth, etc.)
//
// Flow:
// 1. User clicks play on YouTube result
// 2. Service downloads audio to temp directory using yt-dlp
// 3. Returns local file path
// 4. media_kit plays the local file (100% reliable)
//
// Cross-platform: Works on macOS, Windows, and Linux

import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'analytics_service.dart';

class YouTubeDownloadService {
  // Cache directory for YouTube downloads (platform-specific)
  String? _cacheDir;

  // Track active downloads to avoid duplicates
  final Map<String, Future<String?>> _activeDownloads = {};

  // Track active download processes for cancellation
  final Map<String, Process> _activeProcesses = {};
  String? _currentDownloadId;

  // Track active stream subscriptions for cleanup (prevents SIGPIPE)
  final Map<String, List<StreamSubscription>> _activeSubscriptions = {};

  /// Get the path to the yt-dlp binary
  /// 
  /// Resolves to bundled binary first, then falls back to system installation.
  /// This prevents "No such file or directory" errors when macOS app is launched
  /// from Finder with minimal PATH (doesn't include Homebrew directories).
  String get ytDlpPath {
    String bundledPath;

    if (Platform.isMacOS) {
      // macOS: binary is in app bundle Resources
      final executable = Platform.resolvedExecutable;
      // executable is .../KarmaPlayer.app/Contents/MacOS/KarmaPlayer
      // we want .../KarmaPlayer.app/Contents
      final contentsDir = path.dirname(path.dirname(executable));
      bundledPath = path.join(contentsDir, 'Resources', 'bin', 'yt-dlp');
    } else if (Platform.isWindows) {
      // Windows: binary is next to executable
      final executable = Platform.resolvedExecutable;
      final appDir = path.dirname(executable);
      bundledPath = path.join(appDir, 'yt-dlp.exe');
    } else {
      // Linux: binary is in app directory
      final executable = Platform.resolvedExecutable;
      final appDir = path.dirname(executable);
      bundledPath = path.join(appDir, 'bin', 'yt-dlp');
    }

    // Check if bundled binary exists
    if (File(bundledPath).existsSync()) {
      return bundledPath;
    }

    // Fallback to system yt-dlp (mainly for debug mode without bundled binary)
    if (Platform.isMacOS) {
      // Try Homebrew locations
      final brewPaths = [
        '/opt/homebrew/bin/yt-dlp',  // Apple Silicon
        '/usr/local/bin/yt-dlp',     // Intel Mac
      ];
      for (final brewPath in brewPaths) {
        if (File(brewPath).existsSync()) {
          return brewPath;
        }
      }
    } else if (Platform.isLinux) {
      const systemPath = '/usr/bin/yt-dlp';
      if (File(systemPath).existsSync()) {
        return systemPath;
      }
    }

    // Return bundled path anyway (will fail with helpful error message)
    return bundledPath;
  }

  /// Get platform-specific cache directory
  ///
  /// - macOS/Linux: /tmp
  /// - Windows: C:\Users\...\AppData\Local\Temp
  Future<String> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;

    final tempDir = await getTemporaryDirectory();
    _cacheDir = tempDir.path;
    return _cacheDir!;
  }

  /// Download YouTube audio to temp file
  ///
  /// Returns the local file path when ready for playback.
  /// Downloads are cached by video ID to avoid duplicate downloads.
  Future<String?> downloadAudio(String videoId) async {
    // Cancel any previous download if a new one is requested
    if (_currentDownloadId != null && _currentDownloadId != videoId) {
      print('[YouTube Download] ⏹️  Canceling previous download: $_currentDownloadId');
      
      // Cancel stream subscriptions first (prevents SIGPIPE)
      final subscriptions = _activeSubscriptions[_currentDownloadId!];
      if (subscriptions != null) {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        _activeSubscriptions.remove(_currentDownloadId);
      }

      // Small delay to ensure streams are fully closed
      await Future.delayed(const Duration(milliseconds: 50));

      // Now safe to kill the process
      final prevProcess = _activeProcesses[_currentDownloadId!];
      if (prevProcess != null) {
        try {
          prevProcess.kill();
        } catch (e) {
          print('[YouTube Download] Error killing process: $e (may already be dead)');
          // Don't report to Glitchtip - expected behavior
        }
        _activeProcesses.remove(_currentDownloadId);
      }
      _activeDownloads.remove(_currentDownloadId);
    }

    _currentDownloadId = videoId;

    // Check if already downloading this video
    if (_activeDownloads.containsKey(videoId)) {
      print('[YouTube Download] Already downloading $videoId, waiting...');
      return await _activeDownloads[videoId];
    }

    // Check if already downloaded (file exists)
    final cachedFile = await _getCachedFile(videoId);
    if (cachedFile != null) {
      print('[YouTube Download] ✅ Using cached file: $cachedFile');
      return cachedFile;
    }

    // Start new download
    final downloadFuture = _downloadAudioInternal(videoId);
    _activeDownloads[videoId] = downloadFuture;

    try {
      final result = await downloadFuture;
      return result;
    } finally {
      _activeDownloads.remove(videoId);
      _activeProcesses.remove(videoId);
      
      // Clean up subscriptions (prevents SIGPIPE and memory leaks)
      final subs = _activeSubscriptions.remove(videoId);
      if (subs != null) {
        for (final sub in subs) {
          await sub.cancel();
        }
      }
      
      if (_currentDownloadId == videoId) {
        _currentDownloadId = null;
      }
    }
  }

  /// Internal download logic
  Future<String?> _downloadAudioInternal(String videoId) async {
    try {
      final cacheDir = await _getCacheDir();
      final url = 'https://music.youtube.com/watch?v=$videoId';
      final outputTemplate = path.join(cacheDir, 'youtube_%(id)s.%(ext)s');

      print('[YouTube Download] Starting download: $videoId');
      print('[YouTube Download]    URL: $url');

      // Run yt-dlp to download audio
      // -f bestaudio: Get best audio quality
      // --no-playlist: Don't download playlists
      // --newline: Progress on separate lines (easier to parse)
      // --no-warnings: Reduce output noise
      final process = await Process.start(
        ytDlpPath,  // Use full path instead of relying on system PATH
        [
          '-f', 'bestaudio',
          '--no-playlist',
          '--newline',
          '--no-warnings',
          '-o', outputTemplate,
          url,
        ],
      );

      // Store process for potential cancellation
      _activeProcesses[videoId] = process;

      // Monitor download progress
      final stdout = <String>[];
      final stderr = <String>[];

      final stdoutSub = process.stdout.listen(
        (data) {
          try {
            final line = String.fromCharCodes(data).trim();
            stdout.add(line);

            // Log progress
            if (line.contains('[download]')) {
              // Extract percentage if available
              final match = RegExp(r'\[download\]\s+(\d+\.\d+)%').firstMatch(line);
              if (match != null) {
                final percent = match.group(1);
                print('[YouTube Download] Progress: $percent%');
              }
            }
          } catch (e) {
            print('[YouTube Download] Error parsing stdout: $e');
          }
        },
        onError: (error, stackTrace) {
          print('[YouTube Download] stdout stream error: $error');
          // Report to Glitchtip
          AnalyticsService().captureError(
            error,
            stackTrace,
            context: 'youtube_download_stdout_stream',
            extras: {
              'video_id': videoId,
            },
          );
        },
        cancelOnError: false, // Continue listening even if error occurs
      );

      final stderrSub = process.stderr.listen(
        (data) {
          try {
            final line = String.fromCharCodes(data).trim();
            stderr.add(line);
            if (line.isNotEmpty) {
              print('[YouTube Download] stderr: $line');
            }
          } catch (e) {
            print('[YouTube Download] Error parsing stderr: $e');
          }
        },
        onError: (error, stackTrace) {
          print('[YouTube Download] stderr stream error: $error');
          // Report to Glitchtip
          AnalyticsService().captureError(
            error,
            stackTrace,
            context: 'youtube_download_stderr_stream',
            extras: {
              'video_id': videoId,
            },
          );
        },
        cancelOnError: false,
      );

      // Store subscriptions for cleanup (prevents SIGPIPE on process kill)
      _activeSubscriptions[videoId] = [stdoutSub, stderrSub];

      // Wait for download to complete
      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        // Download successful, find the file
        final filePath = await _findDownloadedFile(videoId);
        if (filePath != null) {
          final fileSize = await File(filePath).length();
          print('[YouTube Download] ✅ Download complete');
          print('[YouTube Download]    File: $filePath');
          print('[YouTube Download]    Size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
          return filePath;
        } else {
          print('[YouTube Download] ❌ Downloaded but file not found');
          return null;
        }
      } else {
        print('[YouTube Download] ❌ yt-dlp failed with exit code: $exitCode');
        print('[YouTube Download]    stdout: ${stdout.join("\n")}');
        print('[YouTube Download]    stderr: ${stderr.join("\n")}');
        return null;
      }
    } catch (e, stackTrace) {
      print('[YouTube Download] ❌ Error: $e');
      print('[YouTube Download]    Stack: $stackTrace');
      
      // Report to Glitchtip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'youtube_download',
        extras: {
          'video_id': videoId,
          'url': 'https://music.youtube.com/watch?v=$videoId',
        },
      );
      
      return null;
    }
  }

  /// Check if file is already cached
  Future<String?> _getCachedFile(String videoId) async {
    final cacheDir = await _getCacheDir();

    // Check for common extensions
    final extensions = ['webm', 'opus', 'm4a', 'mp3', 'ogg'];

    for (final ext in extensions) {
      final filePath = path.join(cacheDir, 'youtube_$videoId.$ext');
      final file = File(filePath);
      if (await file.exists()) {
        final size = await file.length();
        if (size > 0) {  // Make sure file is not empty
          return filePath;
        }
      }
    }

    return null;
  }

  /// Find the downloaded file (yt-dlp may use different extensions)
  Future<String?> _findDownloadedFile(String videoId) async {
    final cacheDir = await _getCacheDir();
    final dir = Directory(cacheDir);
    
    List<FileSystemEntity> files;
    try {
      files = await dir.list().toList();
    } catch (e, stackTrace) {
      print('[YouTube Download] Error listing directory: $e');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'youtube_find_downloaded_file',
        extras: {
          'video_id': videoId,
          'cache_dir': cacheDir,
        },
      );
      return null;
    }

    for (final file in files) {
      if (file is File) {
        final name = path.basename(file.path);
        // Match: youtube_VIDEO_ID.EXT
        if (name.startsWith('youtube_$videoId.')) {
          return file.path;
        }
      }
    }

    return null;
  }

  /// Clean up old cached files
  Future<void> cleanOldFiles({Duration maxAge = const Duration(hours: 24)}) async {
    try {
      final cacheDir = await _getCacheDir();
      final dir = Directory(cacheDir);
      final now = DateTime.now();

      final files = await dir.list().toList();
      int deletedCount = 0;

      for (final file in files) {
        if (file is File) {
          final name = path.basename(file.path);
          if (name.startsWith('youtube_')) {
            final stat = await file.stat();
            final age = now.difference(stat.modified);

            if (age > maxAge) {
              await file.delete();
              deletedCount++;
              print('[YouTube Download] Deleted old cache file: $name');
            }
          }
        }
      }

      if (deletedCount > 0) {
        print('[YouTube Download] Cleaned up $deletedCount old file(s)');
      }
    } catch (e, stackTrace) {
      print('[YouTube Download] Error cleaning cache: $e');
      
      // Report to Glitchtip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'youtube_cache_cleanup',
        extras: {
          'max_age_hours': maxAge.inHours,
        },
      );
    }
  }

  /// Delete a specific cached file
  Future<void> deleteFile(String videoId) async {
    try {
      final filePath = await _getCachedFile(videoId);
      if (filePath != null) {
        await File(filePath).delete();
        print('[YouTube Download] Deleted cached file: $filePath');
      }
    } catch (e, stackTrace) {
      print('[YouTube Download] Error deleting file: $e');
      
      // Report to Glitchtip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'youtube_delete_cached_file',
        extras: {
          'video_id': videoId,
        },
      );
    }
  }

  /// Dispose of the service and clean up resources
  /// 
  /// Cancels all active downloads and stream subscriptions to prevent
  /// SIGPIPE crashes and memory leaks when the service is destroyed.
  Future<void> dispose() async {
    print('[YouTube Download] Disposing service, canceling ${_activeProcesses.length} active download(s)');
    
    // Cancel all active downloads
    for (final videoId in _activeProcesses.keys.toList()) {
      // Cancel subscriptions first
      final subs = _activeSubscriptions[videoId];
      if (subs != null) {
        for (final sub in subs) {
          await sub.cancel();
        }
      }
      
      // Kill the process
      try {
        _activeProcesses[videoId]?.kill();
      } catch (e) {
        print('[YouTube Download] Error killing process during dispose: $e');
      }
    }
    
    // Clear all tracking maps
    _activeDownloads.clear();
    _activeProcesses.clear();
    _activeSubscriptions.clear();
    _currentDownloadId = null;
    
    print('[YouTube Download] ✅ Service disposed successfully');
  }
}
