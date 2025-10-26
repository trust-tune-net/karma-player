import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// Manages the transmission-daemon lifecycle
class DaemonManager {
  Process? _daemonProcess;
  bool _isRunning = false;

  /// Get the path to the bundled transmission-daemon binary
  String get daemonPath {
    if (kDebugMode) {
      // In debug mode, use system-installed transmission-daemon
      return '/opt/homebrew/bin/transmission-daemon';
    } else {
      // In release mode, use bundled binary
      if (Platform.isMacOS) {
        // macOS: binary is in app bundle Resources
        final executable = Platform.resolvedExecutable;
        // executable is .../trusttune_gui.app/Contents/MacOS/trusttune_gui
        // we want .../trusttune_gui.app/Contents
        final contentsDir = path.dirname(path.dirname(executable));
        return path.join(contentsDir, 'Resources', 'bin', 'transmission-daemon');
      } else if (Platform.isWindows) {
        // Windows: binary is next to executable
        final executable = Platform.resolvedExecutable;
        final appDir = path.dirname(executable);
        return path.join(appDir, 'transmission-daemon.exe');
      } else {
        // Linux: binary is in app directory
        final executable = Platform.resolvedExecutable;
        final appDir = path.dirname(executable);
        return path.join(appDir, 'bin', 'transmission-daemon');
      }
    }
  }

  /// Get platform-appropriate config directory
  String get configDir {
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (homeDir == null) throw Exception('Could not find home directory');

    if (Platform.isMacOS || Platform.isLinux) {
      return path.join(homeDir, 'Music', '.transmission');
    } else {
      // Windows
      return path.join(homeDir, 'Music', '.transmission');
    }
  }

  /// Get platform-appropriate download directory
  String getDownloadDir(String? customDir) {
    if (customDir != null && customDir.isNotEmpty) {
      return customDir;
    }
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (homeDir == null) throw Exception('Could not find home directory');
    return path.join(homeDir, 'Music');
  }

  String get downloadDir => getDownloadDir(null);

  /// Check if daemon is already running
  Future<bool> isDaemonRunning() async {
    try {
      final result = await Process.run('pgrep', ['-x', 'transmission-daemon']);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// Start the transmission daemon
  Future<bool> startDaemon({String? customDownloadDir}) async {
    if (_isRunning) {
      print('Daemon already running');
      return true;
    }

    // Check if already running system-wide
    if (await isDaemonRunning()) {
      print('Daemon already running system-wide');
      _isRunning = true;
      return true;
    }

    try {
      // Ensure directories exist
      final config = configDir;
      final download = getDownloadDir(customDownloadDir);
      await Directory(config).create(recursive: true);
      await Directory(download).create(recursive: true);

      print('Starting daemon from: $daemonPath');
      print('Config dir: $config');
      print('Download dir: $download');

      // Check if binary exists
      if (!await File(daemonPath).exists()) {
        print('ERROR: Daemon binary not found at $daemonPath');
        return false;
      }

      // Start transmission-daemon
      _daemonProcess = await Process.start(
        daemonPath,
        [
          '--config-dir',
          config,
          '--download-dir',
          download,
          '--port',
          '9091',
          '--log-level',
          'info',
          '--no-auth', // Disable authentication for localhost
        ],
      );

      // Wait a bit for daemon to start
      await Future.delayed(const Duration(seconds: 2));

      // Check if process is still running
      if (_daemonProcess != null) {
        _isRunning = true;
        print('Daemon started successfully (PID: ${_daemonProcess!.pid})');

        // Listen for process exit
        _daemonProcess!.exitCode.then((code) {
          print('Daemon exited with code: $code');
          _isRunning = false;
          _daemonProcess = null;
        });

        return true;
      }
    } catch (e) {
      print('Error starting daemon: $e');
      _isRunning = false;
      _daemonProcess = null;
    }

    return false;
  }

  /// Stop the transmission daemon
  Future<void> stopDaemon() async {
    if (_daemonProcess != null) {
      print('Stopping daemon (PID: ${_daemonProcess!.pid})');
      _daemonProcess!.kill();
      _daemonProcess = null;
      _isRunning = false;
    }
  }

  /// Ensure daemon is running
  Future<bool> ensureDaemonRunning() async {
    if (_isRunning || await isDaemonRunning()) {
      return true;
    }
    return await startDaemon();
  }
}
