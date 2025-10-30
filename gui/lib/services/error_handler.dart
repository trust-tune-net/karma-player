import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'analytics_service.dart';

/// Global error handling service
///
/// Captures and logs all errors including:
/// - Flutter framework errors
/// - Async errors
/// - Uncaught exceptions
/// - Startup errors
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  File? _logFile;
  File? _tmpLogFile; // /tmp/log/karmaplayer.log for easy debugging
  bool _initialized = false;

  /// Initialize error handling (call this FIRST in main())
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Setup log file
      await _setupLogFile();

      // Capture Flutter framework errors
      FlutterError.onError = (FlutterErrorDetails details) {
        _handleFlutterError(details);
      };

      // Capture async errors (PlatformDispatcher)
      PlatformDispatcher.instance.onError = (error, stack) {
        _handleAsyncError(error, stack);
        return true; // Handled
      };

      _initialized = true;
      await _logMessage('═══════════════════════════════════════');
      await _logMessage('ErrorHandler initialized');
      await _logMessage('App started: ${DateTime.now()}');
      await _logMessage('═══════════════════════════════════════');
    } catch (e) {
      print('[ERROR HANDLER] Failed to initialize: $e');
    }
  }

  /// Setup log file location
  Future<void> _setupLogFile() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final logsDir = Directory(path.join(appDir.path, 'logs'));

      // Create logs directory if it doesn't exist
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      // Create log file with timestamp
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      _logFile = File(path.join(logsDir.path, 'trusttune_$timestamp.log'));

      print('[ERROR HANDLER] Log file: ${_logFile!.path}');

      // Also log to /tmp/log/karmaplayer.log on Mac/Linux for easy access
      if (Platform.isMacOS || Platform.isLinux) {
        try {
          final tmpLogDir = Directory('/tmp/log');
          if (!await tmpLogDir.exists()) {
            await tmpLogDir.create(recursive: true);
          }
          _tmpLogFile = File('/tmp/log/karmaplayer.log');
          print('[ERROR HANDLER] Also logging to: ${_tmpLogFile!.path}');
        } catch (e) {
          print('[ERROR HANDLER] Could not create /tmp log file: $e');
        }
      }
    } catch (e) {
      print('[ERROR HANDLER] Could not create log file: $e');
    }
  }

  /// Handle Flutter framework errors
  void _handleFlutterError(FlutterErrorDetails details) {
    // Log to console (debug mode)
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }

    // Log to file
    _logError(
      'FLUTTER ERROR',
      details.exception,
      details.stack,
      details.context?.toString(),
    );

    // Report to GlitchTip (global error reporting)
    AnalyticsService().captureError(
      details.exception,
      details.stack,
      context: 'flutter_error',
      extras: {
        'error_type': 'flutter_framework',
        'context': details.context?.toString() ?? 'none',
        'library': details.library ?? 'unknown',
      },
    );
  }

  /// Handle async/platform errors
  void _handleAsyncError(Object error, StackTrace stack) {
    // Log to console
    print('[ASYNC ERROR] $error');
    print('[ASYNC ERROR] Stack trace:\n$stack');

    // Log to file
    _logError('ASYNC ERROR', error, stack, null);

    // Report to GlitchTip (global error reporting)
    AnalyticsService().captureError(
      error,
      stack,
      context: 'async_error',
      extras: {
        'error_type': 'async_platform',
      },
    );
  }

  /// Log an error with full details
  Future<void> _logError(
    String type,
    Object error,
    StackTrace? stack,
    String? context,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('[$type] ${DateTime.now()}');
    buffer.writeln('═══════════════════════════════════════');
    if (context != null) {
      buffer.writeln('Context: $context');
    }
    buffer.writeln('Error: $error');
    if (stack != null) {
      buffer.writeln('Stack trace:');
      buffer.writeln(stack.toString());
    }
    buffer.writeln('═══════════════════════════════════════');

    await _logMessage(buffer.toString());
  }

  /// Log a general message
  Future<void> _logMessage(String message) async {
    // Write to Application Support log
    if (_logFile != null) {
      try {
        await _logFile!.writeAsString(
          '$message\n',
          mode: FileMode.append,
        );
      } catch (e) {
        print('[ERROR HANDLER] Failed to write to log: $e');
      }
    }

    // Also write to /tmp/log/karmaplayer.log on Mac/Linux
    if (_tmpLogFile != null) {
      try {
        await _tmpLogFile!.writeAsString(
          '$message\n',
          mode: FileMode.append,
        );
      } catch (e) {
        print('[ERROR HANDLER] Failed to write to /tmp log: $e');
      }
    }
  }

  /// Log a startup message
  Future<void> logStartup(String message) async {
    final formatted = '[STARTUP] $message';
    print(formatted);
    await _logMessage(formatted);
  }

  /// Log a startup error (critical)
  Future<void> logStartupError(String message, Object? error, [StackTrace? stack]) async {
    final buffer = StringBuffer();
    buffer.writeln('[STARTUP ERROR] $message');
    if (error != null) {
      buffer.writeln('[STARTUP ERROR] Error: $error');
    }
    if (stack != null) {
      buffer.writeln('[STARTUP ERROR] Stack trace:\n$stack');
    }

    print(buffer.toString());
    await _logError('STARTUP ERROR', error ?? message, stack, message);
  }

  /// Get all log files for debugging
  Future<List<File>> getLogFiles() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final logsDir = Directory(path.join(appDir.path, 'logs'));

      if (await logsDir.exists()) {
        return logsDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.log'))
            .toList();
      }
    } catch (e) {
      print('[ERROR HANDLER] Failed to get log files: $e');
    }
    return [];
  }

  /// Get current log file path
  String? get currentLogPath => _logFile?.path;

  /// Show error dialog to user (for critical startup errors)
  static Future<void> showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    String? details,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontSize: 14,
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A2A2E)),
                ),
                child: SelectableText(
                  details,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFFA855F7)),
            ),
          ),
        ],
      ),
    );
  }
}
