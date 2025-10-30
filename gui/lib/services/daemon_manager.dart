import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'analytics_service.dart';

/// Manages the transmission-daemon lifecycle
class DaemonManager {
  Process? _daemonProcess;
  bool _isRunning = false;
  bool _isRetrying = false;
  DateTime? _lastStartAttempt;

  /// Get the path to the bundled transmission-daemon binary
  String get daemonPath {
    // Try bundled binary first (works in both debug and release)
    String bundledPath;

    if (Platform.isMacOS) {
      // macOS: binary is in app bundle Resources
      final executable = Platform.resolvedExecutable;
      // executable is .../trusttune_gui.app/Contents/MacOS/trusttune_gui
      // we want .../trusttune_gui.app/Contents
      final contentsDir = path.dirname(path.dirname(executable));
      bundledPath = path.join(contentsDir, 'Resources', 'bin', 'transmission-daemon');
    } else if (Platform.isWindows) {
      // Windows: binary is next to executable
      final executable = Platform.resolvedExecutable;
      final appDir = path.dirname(executable);
      bundledPath = path.join(appDir, 'transmission-daemon.exe');
    } else {
      // Linux: binary is in app directory
      final executable = Platform.resolvedExecutable;
      final appDir = path.dirname(executable);
      bundledPath = path.join(appDir, 'bin', 'transmission-daemon');
    }

    // Check if bundled binary exists
    if (File(bundledPath).existsSync()) {
      return bundledPath;
    }

    // Fallback to system transmission (mainly for debug mode without bundled binary)
    if (Platform.isMacOS) {
      // Try Homebrew locations
      final brewPaths = [
        '/opt/homebrew/bin/transmission-daemon',  // Apple Silicon
        '/usr/local/bin/transmission-daemon',     // Intel Mac
      ];
      for (final brewPath in brewPaths) {
        if (File(brewPath).existsSync()) {
          return brewPath;
        }
      }
    } else if (Platform.isLinux) {
      final systemPath = '/usr/bin/transmission-daemon';
      if (File(systemPath).existsSync()) {
        return systemPath;
      }
    }

    // Return bundled path anyway (will fail with helpful error message)
    return bundledPath;
  }

  /// Get platform-appropriate config directory
  String get configDir {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (homeDir == null) throw Exception('Could not find home directory');

    if (Platform.isMacOS || Platform.isLinux) {
      // Use Documents instead of Music to avoid macOS permission issues
      return path.join(homeDir, 'Documents', 'TrustTune', '.transmission');
    } else {
      // Windows
      return path.join(homeDir, 'Documents', 'TrustTune', '.transmission');
    }
  }

  /// Get platform-appropriate download directory
  String getDownloadDir(String? customDir) {
    if (customDir != null && customDir.isNotEmpty) {
      return customDir;
    }
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (homeDir == null) throw Exception('Could not find home directory');
    // Use Documents/TrustTune instead of Music to avoid macOS permission issues
    return path.join(homeDir, 'Documents', 'TrustTune', 'Downloads');
  }

  String get downloadDir => getDownloadDir(null);

  /// Check if daemon is already running
  Future<bool> isDaemonRunning() async {
    try {
      if (Platform.isWindows) {
        // Windows: use tasklist to check for running process
        final result = await Process.run('tasklist', ['/FI', 'IMAGENAME eq transmission-daemon.exe', '/NH']);
        return result.exitCode == 0 && result.stdout.toString().contains('transmission-daemon.exe');
      } else {
        // Unix/Linux/macOS: use pgrep
        final result = await Process.run('pgrep', ['-x', 'transmission-daemon']);
        return result.exitCode == 0;
      }
    } catch (e) {
      return false;
    }
  }

  /// Start the transmission daemon
  /// Returns true if started successfully, false otherwise
  /// Throws Exception with user-friendly message if directory access fails
  Future<bool> startDaemon({String? customDownloadDir}) async {
    if (_isRunning) {
      print('[Daemon] Already running');
      return true;
    }

    // Check if already running system-wide
    if (await isDaemonRunning()) {
      print('[Daemon] Already running system-wide');
      _isRunning = true;
      return true;
    }

    // Track start time for auto-retry logic on Windows
    _lastStartAttempt = DateTime.now();

    try {
      // Ensure directories exist - THIS IS CRITICAL FOR PERMISSIONS
      final config = configDir;
      final download = getDownloadDir(customDownloadDir);

      // Try to create config directory with detailed error handling
      try {
        await Directory(config).create(recursive: true);
        print('[Daemon] ✓ Config directory accessible: $config');
      } on FileSystemException catch (e) {
        print('[Daemon] ❌ ERROR: Cannot create config directory');
        print('[Daemon] Path: $config');
        print('[Daemon] Error: ${e.message}');
        print('[Daemon] OS Error: ${e.osError?.message}');
        
        // Report to Glitchtip
        AnalyticsService().captureError(
          e,
          StackTrace.current,
          context: 'daemon_config_dir_permission',
          extras: {
            'path': config,
            'os_error': e.osError?.message,
            'platform': Platform.operatingSystem,
          },
        );
        
        throw Exception(
          'Cannot access config directory:\n$config\n\n'
          'Error: ${e.osError?.message ?? e.message}\n\n'
          'This directory is required for transmission-daemon to work.'
        );
      }

      // Try to create download directory with detailed error handling
      try {
        await Directory(download).create(recursive: true);
        // Verify we can actually write to it
        final testFile = File('$download/.trusttune_test');
        await testFile.writeAsString('test');
        await testFile.delete();
        print('[Daemon] ✓ Download directory accessible and writable: $download');
      } on FileSystemException catch (e) {
        print('[Daemon] ❌ ERROR: Cannot create or write to download directory');
        print('[Daemon] Path: $download');
        print('[Daemon] Error: ${e.message}');
        print('[Daemon] OS Error: ${e.osError?.message}');

        // Report to Glitchtip
        AnalyticsService().captureError(
          e,
          StackTrace.current,
          context: 'daemon_download_dir_permission',
          extras: {
            'path': download,
            'is_custom_dir': customDownloadDir != null && customDownloadDir.isNotEmpty,
            'os_error': e.osError?.message,
            'platform': Platform.operatingSystem,
          },
        );

        final isCustomDir = customDownloadDir != null && customDownloadDir.isNotEmpty;

        // Platform-specific tips for protected folders
        String protectedFolderTip;
        if (Platform.isMacOS) {
          protectedFolderTip = 'Tip: Avoid protected folders like Music, Photos, or Desktop on macOS.';
        } else if (Platform.isWindows) {
          protectedFolderTip = 'Tip: Avoid system folders like Program Files, Windows, or protected locations.';
        } else {
          protectedFolderTip = 'Tip: Avoid system folders like /usr, /bin, or root-owned directories.';
        }

        throw Exception(
          'Cannot access download directory:\n$download\n\n'
          'Error: ${e.osError?.message ?? e.message}\n\n'
          '${isCustomDir ? "This is a custom directory you selected. " : ""}'
          'Please choose a different location${isCustomDir ? " in Settings" : ""}.\n\n'
          '$protectedFolderTip'
        );
      }

      print('[Daemon] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('[Daemon] Attempting to start transmission-daemon');
      print('[Daemon] Executable: ${Platform.resolvedExecutable}');
      print('[Daemon] Daemon path: $daemonPath');
      print('[Daemon] Config dir: $config');
      print('[Daemon] Download dir: $download');

      // Check if binary exists
      if (!await File(daemonPath).exists()) {
        print('[Daemon] ❌ ERROR: Binary not found at $daemonPath');
        print('[Daemon] Checked locations:');
        print('[Daemon]   - $daemonPath');
        print('[Daemon]   - /opt/homebrew/bin/transmission-daemon');
        print('[Daemon]   - /usr/local/bin/transmission-daemon');
        return false;
      }

      print('[Daemon] ✓ Binary found: $daemonPath');

      // Start transmission-daemon
      print('[Daemon] Starting process...');

      // Build arguments list
      final args = [
        '--config-dir',
        config,
        '--download-dir',
        download,
        '--port',
        '9091',
        '--log-level',
        'info',
        '--no-auth', // Disable authentication for localhost
      ];

      // On Windows, add --foreground flag to prevent daemonization (which fails on Windows)
      if (Platform.isWindows) {
        args.add('--foreground');
        print('[Daemon] Running in foreground mode (Windows)');
      }

      _daemonProcess = await Process.start(daemonPath, args);

      print('[Daemon] Process started with PID: ${_daemonProcess!.pid}');

      // Listen for stdout/stderr
      _daemonProcess!.stdout.transform(utf8.decoder).listen(
        (data) {
          print('[Daemon STDOUT] $data');
        },
        onError: (error, stackTrace) {
          print('[Daemon STDOUT] Stream error: $error');
          AnalyticsService().captureError(
            error,
            stackTrace,
            context: 'daemon_stdout_stream',
            extras: {
              'platform': Platform.operatingSystem,
            },
          );
        },
      );
      _daemonProcess!.stderr.transform(utf8.decoder).listen(
        (data) {
          print('[Daemon STDERR] $data');
        },
        onError: (error, stackTrace) {
          print('[Daemon STDERR] Stream error: $error');
          AnalyticsService().captureError(
            error,
            stackTrace,
            context: 'daemon_stderr_stream',
            extras: {
              'platform': Platform.operatingSystem,
            },
          );
        },
      );

      // Wait a bit for daemon to start
      await Future.delayed(const Duration(seconds: 2));

      // Verify daemon is actually responding on port 9091
      bool daemonHealthy = false;
      print('[Daemon] Verifying daemon is responsive on port 9091...');

      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final socket = await Socket.connect('127.0.0.1', 9091, timeout: const Duration(seconds: 2));
          await socket.close();
          daemonHealthy = true;
          print('[Daemon] ✅ Daemon is responding on port 9091 (attempt $attempt/3)');
          break;
        } catch (e) {
          print('[Daemon] ⚠️  Daemon not responding yet (attempt $attempt/3): $e');
          if (attempt < 3) {
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      // Check if process is still running AND responding
      if (_daemonProcess != null && daemonHealthy) {
        _isRunning = true;
        print('[Daemon] ✅ Started successfully (PID: ${_daemonProcess!.pid})');
        print('[Daemon] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        // Listen for process exit
        _daemonProcess!.exitCode.then((code) async {
          if (code == 0) {
            // On Unix, exit code 0 means daemon forked to background successfully
            // On Windows with --foreground, this shouldn't happen (daemon stays running)
            if (Platform.isWindows) {
              print('[Daemon] ⚠️ Daemon exited unexpectedly with code 0');
              _isRunning = false;
              _daemonProcess = null;

              // Auto-retry once if this was the first attempt (handles UAC prompt scenario)
              if (!_isRetrying && _lastStartAttempt != null) {
                final timeSinceStart = DateTime.now().difference(_lastStartAttempt!);
                if (timeSinceStart.inSeconds < 10) {
                  print('[Daemon] 🔄 Auto-retrying startup (UAC prompt may have interrupted)...');
                  _isRetrying = true;
                  await Future.delayed(const Duration(seconds: 2));
                  await startDaemon();
                  _isRetrying = false;
                }
              }
            } else {
              print('[Daemon] ℹ️ Process forked to background (exit code 0)');
            }
          } else {
            print('[Daemon] ❌ Process exited with error code: $code');
            _isRunning = false;
            _daemonProcess = null;

            // Auto-retry once on Windows if early exit (handles UAC prompt scenario)
            if (Platform.isWindows && !_isRetrying && _lastStartAttempt != null) {
              final timeSinceStart = DateTime.now().difference(_lastStartAttempt!);
              if (timeSinceStart.inSeconds < 10) {
                print('[Daemon] 🔄 Auto-retrying startup (UAC prompt may have interrupted)...');
                _isRetrying = true;
                await Future.delayed(const Duration(seconds: 2));
                await startDaemon();
                _isRetrying = false;
              }
            }
          }
        });

        return true;
      } else if (_daemonProcess != null && !daemonHealthy) {
        // Process exists but not responding - kill it and report failure
        print('[Daemon] ❌ Process started but not responding on port 9091');
        print('[Daemon] Killing unresponsive process...');
        _daemonProcess!.kill();
        _daemonProcess = null;
        _isRunning = false;
        return false;
      }
    } catch (e, stackTrace) {
      print('[Daemon] ❌ ERROR starting daemon: $e');
      print('[Daemon] Stack trace: $stackTrace');
      
      // Report to Glitchtip
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'daemon_startup',
        extras: {
          'daemon_path': daemonPath,
          'config_dir': configDir,
          'download_dir': getDownloadDir(customDownloadDir),
          'platform': Platform.operatingSystem,
        },
      );
      
      _isRunning = false;
      _daemonProcess = null;
    }

    print('[Daemon] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return false;
  }

  /// Stop the transmission daemon
  Future<void> stopDaemon() async {
    print('[Daemon] Stopping all transmission-daemon processes...');

    // First, kill our managed process if it exists
    if (_daemonProcess != null) {
      print('[Daemon] Killing managed process (PID: ${_daemonProcess!.pid})');
      _daemonProcess!.kill();
      _daemonProcess = null;
      _isRunning = false;
    }

    // Then kill any other transmission-daemon processes system-wide
    // This handles cases where daemon was started externally or by previous app instance
    try {
      if (Platform.isWindows) {
        // Windows: taskkill /F /IM transmission-daemon.exe
        await Process.run('taskkill', ['/F', '/IM', 'transmission-daemon.exe']);
        print('[Daemon] Killed all transmission-daemon.exe processes (Windows)');
      } else {
        // Unix/Linux/macOS: pkill -9 transmission-daemon
        await Process.run('pkill', ['-9', 'transmission-daemon']);
        print('[Daemon] Killed all transmission-daemon processes (Unix)');
      }
    } catch (e) {
      print('[Daemon] Note: Error killing system-wide processes (may not exist): $e');
    }

    _isRunning = false;
    print('[Daemon] ✅ Daemon stopped');
  }

  /// Ensure daemon is running
  Future<bool> ensureDaemonRunning() async {
    if (_isRunning || await isDaemonRunning()) {
      return true;
    }
    return await startDaemon();
  }
}
