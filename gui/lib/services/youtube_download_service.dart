// YouTube Download Service - yt-dlp Approach
//
// Downloads YouTube Music audio to ~/Music folder with user-friendly filenames.
// Uses yt-dlp to handle all YouTube complexity (signatures, auth, etc.)
//
// Flow:
// 1. User clicks play on YouTube result
// 2. Service extracts metadata (title, artist) from YouTube
// 3. Downloads audio to ~/Music with filename: "Artist - Title.ext"
// 4. Library automatically picks up files from ~/Music
// 5. Returns local file path for playback
// 6. media_kit plays the local file (100% reliable)
//
// Cross-platform: Works on macOS, Windows, and Linux

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'analytics_service.dart';

class YouTubeDownloadService {
  // Cache directory for YouTube downloads (platform-specific)
  String? _cacheDir;

  // Track video ID -> filename mapping for cache lookup
  final Map<String, String> _videoIdToFilename = {};
  
  // Cache extracted metadata to avoid re-fetching on retries
  final Map<String, Map<String, String>> _videoIdToMetadata = {};

  // Track active downloads to avoid duplicates
  final Map<String, Future<String?>> _activeDownloads = {};

  // Track active download processes for cancellation
  final Map<String, Process> _activeProcesses = {};
  String? _currentDownloadId;

  // Track active stream subscriptions for cleanup (prevents SIGPIPE)
  final Map<String, List<StreamSubscription>> _activeSubscriptions = {};

  // Cancellation lock to serialize cancellation operations (prevents race conditions)
  Future<void>? _cancellationLock;

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
  /// Downloads to ~/Music folder so library automatically picks them up
  /// - macOS/Linux: ~/Music
  /// - Windows: C:\Users\...\Music
  Future<String> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;

    // Get home directory (cross-platform)
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (homeDir == null) {
      // Fallback to temp if home not found (shouldn't happen)
      final tempDir = await getTemporaryDirectory();
      _cacheDir = tempDir.path;
      return _cacheDir!;
    }

    // Use ~/Music folder
    final musicDir = path.join(homeDir, 'Music');
    _cacheDir = musicDir;

    // Ensure directory exists
    try {
      await Directory(musicDir).create(recursive: true);
    } catch (e) {
      print('[YouTube Download] Warning: Could not create Music directory: $e');
      // Fallback to temp if Music folder can't be created
      final tempDir = await getTemporaryDirectory();
      _cacheDir = tempDir.path;
    }

    return _cacheDir!;
  }

  /// Download YouTube audio to temp file
  ///
  /// Returns the local file path when ready for playback.
  /// Downloads are cached by video ID to avoid duplicate downloads.
  /// 
  /// [title] and [artist] optional - if provided, will be used for filename instead of extracting metadata
  /// [onProgress] optional callback for download progress (0.0 to 1.0)
  /// [onDownloadComplete] optional callback called after successful download
  Future<String?> downloadAudio(
    String videoId, {
    String? title,
    String? artist,
    void Function(double progress)? onProgress,
    VoidCallback? onDownloadComplete,
  }) async {
    // Wait for any ongoing cancellation to complete (prevents race conditions)
    if (_cancellationLock != null) {
      await _cancellationLock;
    }

    // Check if already downloading this video (BEFORE setting _currentDownloadId)
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

    // Cancel any previous download if a new one is requested
    // This must happen AFTER checking for duplicates to prevent race conditions
    if (_currentDownloadId != null && _currentDownloadId != videoId) {
      // Create cancellation lock to serialize cancellation operations
      final completer = Completer<void>();
      _cancellationLock = completer.future;
      
      try {
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
            
            // Wait for process to actually terminate (prevents race condition)
            // Give it up to 2 seconds to terminate gracefully
            try {
              await prevProcess.exitCode.timeout(
                const Duration(seconds: 2),
                onTimeout: () {
                  print('[YouTube Download] Process did not terminate within timeout, continuing...');
                  return -1; // Process still running, but we'll continue
                },
              );
              print('[YouTube Download] ✅ Previous process terminated');
            } catch (e) {
              print('[YouTube Download] Error waiting for process termination: $e (continuing anyway)');
            }
          } catch (e) {
            print('[YouTube Download] Error killing process: $e (may already be dead)');
            // Don't report to Glitchtip - expected behavior
          }
          _activeProcesses.remove(_currentDownloadId);
        }
        _activeDownloads.remove(_currentDownloadId);
      } finally {
        _cancellationLock = null;
        completer.complete();
      }
    }

    // Set current download ID AFTER cancellation is complete
    _currentDownloadId = videoId;

    // Start new download (callback passed to internal method to be called after rename completes)
    final downloadFuture = _downloadAudioInternal(
      videoId,
      title: title,
      artist: artist,
      onProgress: onProgress,
      onDownloadComplete: onDownloadComplete,
    );
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

  /// Internal download logic with retry support
  Future<String?> _downloadAudioInternal(
    String videoId, {
    String? title,
    String? artist,
    int retryCount = 0,
    void Function(double progress)? onProgress,
    VoidCallback? onDownloadComplete,
  }) async {
    const maxRetries = 2;
    const retryDelayMs = 2000; // 2 seconds
    
    try {
      // Log download start to GlitchTip
      AnalyticsService().addBreadcrumb(
        message: 'Starting yt-dlp download',
        category: 'youtube_download',
        data: {
          'video_id': videoId,
          'retry_count': retryCount,
          'has_title': title != null,
          'has_artist': artist != null,
        },
      );
      
      final cacheDir = await _getCacheDir();
      final url = 'https://music.youtube.com/watch?v=$videoId';

      // Use provided metadata if available, otherwise extract it
      Map<String, String>? metadata;
      
      if (title != null && title.isNotEmpty) {
        // Use provided title and artist (or extract artist from title if needed)
        String? finalTitle = title;
        String? finalArtist = artist;
        
        // If no artist provided, try to parse from title (format: "Artist - Title")
        if (finalArtist == null || finalArtist.isEmpty) {
          final titleParts = finalTitle.split(' - ');
          if (titleParts.length >= 2) {
            finalArtist = titleParts[0].trim();
            finalTitle = titleParts.sublist(1).join(' - ').trim();
          } else {
            finalArtist = 'Unknown Artist';
          }
        }
        
        metadata = {
          'title': finalTitle,
          'artist': finalArtist,
        };
        
        // Cache it for retries
        _videoIdToMetadata[videoId] = metadata;
        
        print('[YouTube Download] Using metadata from search results: "$finalTitle" by "$finalArtist"');
      } else {
        // No metadata provided - try to use cached or extract it
        metadata = _videoIdToMetadata[videoId];
        
        // Extract metadata if not cached (first attempt or cache lost)
        if (metadata == null) {
          print('[YouTube Download] No metadata provided, extracting from YouTube...');
          metadata = await _extractMetadata(videoId);
          // Cache it for retries
          if (metadata != null) {
            _videoIdToMetadata[videoId] = metadata;
          }
        }
      }

      // If we have metadata, download to temp first, then rename to user-friendly name
      // This is more reliable than trying to specify exact filename in yt-dlp
      final useTempDownload = metadata != null;
      final outputTemplate = useTempDownload
          ? path.join(cacheDir, 'youtube_${videoId}_temp.%(ext)s')
          : path.join(cacheDir, 'youtube_%(id)s.%(ext)s');

      print('[YouTube Download] Starting download: $videoId (attempt ${retryCount + 1})');
      print('[YouTube Download]    URL: $url');
      if (metadata != null) {
        print('[YouTube Download]    Target: ${metadata['artist']} - ${metadata['title']}');
      }

      // Log yt-dlp execution
      AnalyticsService().addBreadcrumb(
        message: 'Executing yt-dlp',
        category: 'youtube_download',
        data: {
          'video_id': videoId,
          'yt_dlp_path': ytDlpPath,
          'url': url,
          'has_metadata': metadata != null,
        },
      );
      
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

            // Log progress and report to callback
            if (line.contains('[download]')) {
              // Extract percentage if available
              final match = RegExp(r'\[download\]\s+(\d+\.\d+)%').firstMatch(line);
              if (match != null) {
                final percentStr = match.group(1);
                if (percentStr != null) {
                  final percent = double.tryParse(percentStr);
                  if (percent != null) {
                    final progress = percent / 100.0; // Convert to 0.0-1.0
                    print('[YouTube Download] Progress: ${percent.toStringAsFixed(1)}%');
                    
                    // Report progress to callback
                    if (onProgress != null) {
                      onProgress(progress);
                    }
                  }
                }
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

      // Wait for download to complete with timeout
      final exitCodeFuture = process.exitCode;
      final timeoutDuration = Duration(minutes: 5); // 5 minute timeout

      int exitCode;
      try {
        exitCode = await exitCodeFuture.timeout(
          timeoutDuration,
          onTimeout: () {
            print('[YouTube Download] ⏱️  Timeout after ${timeoutDuration.inMinutes} minutes');
            process.kill(); // Kill hung process
            
            // Report timeout to GlitchTip
            AnalyticsService().captureError(
              TimeoutException('yt-dlp download timeout', timeoutDuration),
              StackTrace.current,
              context: 'youtube_download_timeout',
              extras: {
                'video_id': videoId,
                'url': url,
                'timeout_minutes': timeoutDuration.inMinutes,
                'retry_count': retryCount,
              },
            );
            
            throw TimeoutException('Download timeout', timeoutDuration);
          },
        );
      } catch (e) {
        rethrow;
      }

      // Log success breadcrumb
      if (exitCode == 0) {
        AnalyticsService().addBreadcrumb(
          message: 'yt-dlp completed successfully',
          category: 'youtube_download',
          data: {
            'video_id': videoId,
            'exit_code': exitCode,
          },
        );
      }

      if (exitCode == 0) {
        // Download successful, find the file
        String? filePath = await _findDownloadedFile(videoId);
        
        // If we downloaded to temp and have metadata, rename to user-friendly name
        if (filePath != null && metadata != null && useTempDownload) {
          final tempFile = File(filePath);
          final ext = path.extension(filePath).replaceFirst('.', '');
          final finalFilename = await _generateFilename(videoId, metadata['title'], metadata['artist'], ext);
          final finalPath = path.join(cacheDir, finalFilename);
          
          try {
            // Check if final file already exists (shouldn't happen due to duplicate handling, but be safe)
            if (await File(finalPath).exists()) {
              // Delete existing file (shouldn't happen, but handle it)
              await File(finalPath).delete();
            }
            
            await tempFile.rename(finalPath);
            filePath = finalPath;
            _videoIdToFilename[videoId] = finalFilename;
            print('[YouTube Download] ✅ Renamed to: $finalFilename');
          } catch (e) {
            print('[YouTube Download] ⚠️  Warning: Could not rename file, keeping temp name: $e');
            // Keep using temp filename, but try to clean it up later
            // The file will still work for playback
          }
        }
        
        if (filePath != null) {
          final fileSize = await File(filePath).length();
          final fileName = path.basename(filePath);
          print('[YouTube Download] ✅ Download complete');
          print('[YouTube Download]    File: $filePath');
          print('[YouTube Download]    Size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
          
          // Log filename format info
          if (fileName.startsWith('youtube_') && !fileName.contains(' - ')) {
            print('[YouTube Download]    Note: Using video ID filename (metadata extraction failed or timed out)');
          }
          
          // Call completion callback after all file operations are done
          if (onDownloadComplete != null) {
            print('[YouTube Download] Triggering library refresh...');
            onDownloadComplete();
          }
          
          return filePath;
        } else {
          // File not found after successful download - report this anomaly
          print('[YouTube Download] ❌ Downloaded but file not found');
          
          // List what files ARE in the directory for debugging
          final dir = Directory(cacheDir);
          List<String> filesInCache = [];
          try {
            final files = await dir.list().toList();
            filesInCache = files.map((f) => path.basename(f.path)).toList();
          } catch (e) {
            filesInCache = ['Error listing: $e'];
          }
          
          AnalyticsService().captureError(
            Exception('yt-dlp succeeded but output file not found'),
            StackTrace.current,
            context: 'youtube_download_file_not_found',
            extras: {
              'video_id': videoId,
              'expected_pattern': 'youtube_$videoId.*',
              'cache_dir': cacheDir,
              'files_in_cache': filesInCache.join(', '),
              'exit_code': exitCode,
              'stdout': stdout.join('\n'),
              'stderr': stderr.join('\n'),
            },
          );
          
          return null;
        }
      } else {
        // yt-dlp failed - capture detailed error for GlitchTip
        final stderrText = stderr.join('\n');
        final stdoutText = stdout.join('\n');
        
        print('[YouTube Download] ❌ yt-dlp failed with exit code: $exitCode');
        print('[YouTube Download]    stderr: $stderrText');
        print('[YouTube Download]    stdout: $stdoutText');
        
        // Report to GlitchTip with full details
        final errorMessage = 'yt-dlp failed (exit $exitCode): ${stderrText.isNotEmpty ? stderrText : "No error output"}';
        
        AnalyticsService().captureError(
          Exception(errorMessage),
          StackTrace.current,
          context: 'youtube_download_ytdlp_failed',
          extras: {
            'video_id': videoId,
            'url': url,
            'exit_code': exitCode,
            'stderr': stderrText,
            'stdout': stdoutText,
            'yt_dlp_path': ytDlpPath,
            'cache_dir': cacheDir,
            'retry_count': retryCount,
          },
        );
        
        return null;
      }
    } catch (e, stackTrace) {
      // Check if we should retry
      if (retryCount < maxRetries && _shouldRetry(e)) {
        print('[YouTube Download] 🔄 Retry ${retryCount + 1}/$maxRetries after ${retryDelayMs}ms...');
        await Future.delayed(Duration(milliseconds: retryDelayMs));
        return _downloadAudioInternal(
          videoId,
          title: title,
          artist: artist,
          retryCount: retryCount + 1,
          onProgress: onProgress,
          onDownloadComplete: onDownloadComplete,
        );
      }
      
      // Max retries reached or non-retryable error
      print('[YouTube Download] ❌ Error: $e (after $retryCount retries)');
      print('[YouTube Download]    Stack: $stackTrace');
      
      // Report to Glitchtip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'youtube_download',
        extras: {
          'video_id': videoId,
          'url': 'https://music.youtube.com/watch?v=$videoId',
          'retry_count': retryCount,
          'max_retries': maxRetries,
        },
      );
      
      return null;
    }
  }

  /// Check if an error should trigger a retry
  bool _shouldRetry(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    // Retry on network errors, timeouts, rate limits
    return errorStr.contains('network') ||
           errorStr.contains('timeout') ||
           errorStr.contains('connection') ||
           errorStr.contains('429') || // Rate limit
           errorStr.contains('503'); // Service unavailable
  }

  /// Sanitize filename to remove invalid filesystem characters
  String _sanitizeFilename(String filename) {
    // Remove or replace invalid characters: / \ : * ? " < > |
    final invalidChars = RegExp(r'[/\\:*?"<>|]');
    String sanitized = filename.replaceAll(invalidChars, '_');
    
    // Remove leading/trailing dots and spaces (Windows doesn't like these)
    sanitized = sanitized.trim().replaceAll(RegExp(r'^\.+|\.+$'), '');
    
    // Limit length to platform max (250 to be safe, leave room for extension)
    if (sanitized.length > 250) {
      sanitized = sanitized.substring(0, 250);
    }
    
    return sanitized;
  }

  /// Extract metadata from YouTube video using yt-dlp
  /// Returns map with 'title', 'artist', 'uploader', or null if extraction fails
  /// Timeout errors are not reported to GlitchTip (expected in slow network conditions)
  Future<Map<String, String>?> _extractMetadata(String videoId) async {
    try {
      final url = 'https://music.youtube.com/watch?v=$videoId';
      
      print('[YouTube Download] Extracting metadata for $videoId...');
      
      // Run yt-dlp with --dump-json to get full metadata
      // Increased timeout to 20 seconds for slow connections
      final result = await Process.run(
        ytDlpPath,
        [
          '--dump-json',
          '--no-playlist',
          '--no-warnings',
          url,
        ],
      ).timeout(const Duration(seconds: 20));

      if (result.exitCode != 0) {
        print('[YouTube Download] ⚠️  Metadata extraction failed: ${result.stderr}');
        return null;
      }

      // Parse JSON output
      final jsonData = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      
      final title = jsonData['title'] as String? ?? '';
      final artist = jsonData['artist'] as String? ?? 
                     jsonData['uploader'] as String? ?? 
                     jsonData['channel'] as String? ?? 
                     'Unknown Artist';
      
      if (title.isEmpty) {
        print('[YouTube Download] ⚠️  No title found in metadata');
        return null;
      }

      print('[YouTube Download] ✅ Metadata extracted: "$title" by "$artist"');
      
      return {
        'title': title,
        'artist': artist,
      };
    } on TimeoutException catch (e) {
      // Timeout is expected in slow network conditions - don't report as error
      print('[YouTube Download] ⏱️  Metadata extraction timed out (this is normal on slow networks)');
      return null;
    } catch (e, stackTrace) {
      // Only report unexpected errors (not timeouts)
      if (e is! TimeoutException) {
        print('[YouTube Download] ❌ Unexpected error extracting metadata: $e');
        AnalyticsService().captureError(
          e,
          stackTrace,
          context: 'youtube_metadata_extraction',
          extras: {
            'video_id': videoId,
          },
        );
      }
      return null;
    }
  }

  /// Generate user-friendly filename: Artist - Title.ext
  /// Falls back to youtube_VIDEO_ID.ext if metadata unavailable
  Future<String> _generateFilename(String videoId, String? title, String? artist, String ext) async {
    if (title != null && title.isNotEmpty && artist != null && artist.isNotEmpty) {
      final sanitizedTitle = _sanitizeFilename(title);
      final sanitizedArtist = _sanitizeFilename(artist);
      final filename = '$sanitizedArtist - $sanitizedTitle.$ext';
      
      // Check for duplicates and append number if needed
      final cacheDir = await _getCacheDir();
      var finalFilename = filename;
      int counter = 1;
      
      while (await File(path.join(cacheDir, finalFilename)).exists()) {
        final baseName = '$sanitizedArtist - $sanitizedTitle';
        finalFilename = '$baseName ($counter).$ext';
        counter++;
      }
      
      return finalFilename;
    }
    
    // Fallback to video ID format
    return 'youtube_$videoId.$ext';
  }

  /// Verify yt-dlp binary is working
  /// 
  /// Call this once when the service is first used to ensure yt-dlp is available.
  /// Returns true if yt-dlp is working, false otherwise.
  Future<bool> verifyYtDlp() async {
    try {
      print('[YouTube Download] Verifying yt-dlp binary...');
      
      final result = await Process.run(ytDlpPath, ['--version']);
      
      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        print('[YouTube Download] ✅ yt-dlp version: $version');
        
        AnalyticsService().addBreadcrumb(
          message: 'yt-dlp verified',
          category: 'youtube_download',
          data: {
            'version': version,
            'path': ytDlpPath,
          },
        );
        
        return true;
      } else {
        print('[YouTube Download] ❌ yt-dlp verification failed: ${result.stderr}');
        
        AnalyticsService().captureError(
          Exception('yt-dlp binary verification failed'),
          StackTrace.current,
          context: 'youtube_download_verification',
          extras: {
            'yt_dlp_path': ytDlpPath,
            'exit_code': result.exitCode,
            'stderr': result.stderr.toString(),
            'stdout': result.stdout.toString(),
          },
        );
        
        return false;
      }
    } catch (e, stackTrace) {
      print('[YouTube Download] ❌ yt-dlp verification error: $e');
      
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'youtube_download_verification_error',
        extras: {
          'yt_dlp_path': ytDlpPath,
        },
      );
      
      return false;
    }
  }

  /// Check if file is already cached
  /// Checks both user-friendly filename and old youtube_VIDEO_ID.ext pattern
  Future<String?> _getCachedFile(String videoId) async {
    final cacheDir = await _getCacheDir();

    // First, check if we have a cached user-friendly filename
    if (_videoIdToFilename.containsKey(videoId)) {
      final cachedFilename = _videoIdToFilename[videoId]!;
      final filePath = path.join(cacheDir, cachedFilename);
      final file = File(filePath);
      if (await file.exists()) {
        final size = await file.length();
        if (size > 0) {
          return filePath;
        }
      }
      // Cached filename doesn't exist, remove from cache
      _videoIdToFilename.remove(videoId);
    }

    // Also check for user-friendly filenames by scanning (in case cache was lost)
    // This is slower but handles cases where app was restarted
    try {
      final dir = Directory(cacheDir);
      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = path.basenameWithoutExtension(entity.path);
          // Check if filename contains video ID (unlikely but possible)
          // Skip this check for performance - rely on video ID pattern instead
        }
      }
    } catch (e) {
      // Ignore scanning errors
    }

    // Fallback: Check for old youtube_VIDEO_ID.ext pattern (backward compatibility)
    final extensions = ['webm', 'opus', 'm4a', 'mp3', 'ogg', 'm4a'];

    for (final ext in extensions) {
      final filePath = path.join(cacheDir, 'youtube_$videoId.$ext');
      final file = File(filePath);
      if (await file.exists()) {
        final size = await file.length();
        if (size > 0) {
          return filePath;
        }
      }
    }

    return null;
  }

  /// Find the downloaded file (yt-dlp may use different extensions)
  /// Checks both user-friendly filenames and old youtube_VIDEO_ID.ext pattern
  Future<String?> _findDownloadedFile(String videoId) async {
    final cacheDir = await _getCacheDir();
    final dir = Directory(cacheDir);
    
    // First check cached user-friendly filename
    if (_videoIdToFilename.containsKey(videoId)) {
      final cachedFilename = _videoIdToFilename[videoId]!;
      final filePath = path.join(cacheDir, cachedFilename);
      if (await File(filePath).exists()) {
        return filePath;
      }
    }

    // Check for temp download file (youtube_VIDEO_ID_temp.ext)
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
        // Match: youtube_VIDEO_ID_temp.EXT (temp download)
        if (name.startsWith('youtube_${videoId}_temp.')) {
          return file.path;
        }
        // Match: youtube_VIDEO_ID.EXT (old pattern, backward compatibility)
        if (name.startsWith('youtube_$videoId.')) {
          return file.path;
        }
      }
    }

    return null;
  }

  /// Clean up old cached files
  /// Only cleans temp files (youtube_*_temp.*), not user-friendly named files
  /// User-friendly files in ~/Music should be managed by the user
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
          // Only clean up temp files and old youtube_VIDEO_ID.ext pattern files
          // Don't delete user-friendly named files (Artist - Title.ext)
          if (name.startsWith('youtube_') && (name.contains('_temp.') || !name.contains(' - '))) {
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
        print('[YouTube Download] Cleaned up $deletedCount old temp file(s)');
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

  /// Cancel an active download for a specific video ID
  Future<void> cancelDownload(String videoId) async {
    if (!_activeDownloads.containsKey(videoId)) {
      print('[YouTube Download] No active download to cancel for $videoId');
      return;
    }

    print('[YouTube Download] ⏹️  Canceling download: $videoId');
    
    // Wait for any ongoing cancellation to complete
    if (_cancellationLock != null) {
      await _cancellationLock;
    }

    // Create cancellation lock
    final completer = Completer<void>();
    _cancellationLock = completer.future;

    try {
      // Cancel stream subscriptions first (prevents SIGPIPE)
      final subscriptions = _activeSubscriptions[videoId];
      if (subscriptions != null) {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        _activeSubscriptions.remove(videoId);
      }

      // Small delay to ensure streams are fully closed
      await Future.delayed(const Duration(milliseconds: 50));

      // Kill the process
      final process = _activeProcesses[videoId];
      if (process != null) {
        try {
          process.kill();
          print('[YouTube Download] ✅ Process killed for $videoId');
        } catch (e) {
          print('[YouTube Download] Error killing process: $e (may already be dead)');
        }
        _activeProcesses.remove(videoId);
      }

      // Remove from active downloads
      _activeDownloads.remove(videoId);

      // Clear current download ID if it matches
      if (_currentDownloadId == videoId) {
        _currentDownloadId = null;
      }

      print('[YouTube Download] ✅ Download canceled for $videoId');
    } finally {
      _cancellationLock = null;
      completer.complete();
    }
  }

  /// Check if a download is currently in progress for the given video ID
  bool isDownloading(String videoId) {
    return _activeDownloads.containsKey(videoId);
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
