import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'daemon_manager.dart';
import 'app_settings.dart';
import 'transmission_client.dart';

enum DiagnosticStatus { success, warning, error, info }

class DiagnosticResult {
  final String name;
  final DiagnosticStatus status;
  final String message;
  final String? details;

  DiagnosticResult({
    required this.name,
    required this.status,
    required this.message,
    this.details,
  });

  String get icon {
    switch (status) {
      case DiagnosticStatus.success:
        return '✅';
      case DiagnosticStatus.warning:
        return '⚠️';
      case DiagnosticStatus.error:
        return '❌';
      case DiagnosticStatus.info:
        return 'ℹ️';
    }
  }

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('$icon **$name**');
    buffer.writeln('  - Status: ${status.name.toUpperCase()}');
    buffer.writeln('  - Message: $message');
    if (details != null && details!.isNotEmpty) {
      buffer.writeln('  - Details: $details');
    }
    return buffer.toString();
  }
}

class DiagnosticsService {
  final DaemonManager daemonManager;
  final AppSettings appSettings;

  DiagnosticsService({
    required this.daemonManager,
    required this.appSettings,
  });

  Future<List<DiagnosticResult>> runAllDiagnostics({
    Function(String)? onProgress,
  }) async {
    final results = <DiagnosticResult>[];

    // 1. System Info
    onProgress?.call('Checking system information...');
    results.add(await _checkSystemInfo());

    // 2. App Version
    onProgress?.call('Checking app version...');
    results.add(_checkAppVersion());

    // 3. Transmission Daemon
    onProgress?.call('Checking Transmission daemon...');
    results.add(await _checkTransmissionDaemon());

    // 4. Transmission RPC
    onProgress?.call('Testing Transmission RPC...');
    results.add(await _checkTransmissionRPC());

    // 5. Search API
    onProgress?.call('Testing Search API...');
    results.add(await _checkSearchAPI());

    // 6. Test Search
    onProgress?.call('Running test search...');
    results.add(await _checkTestSearch());

    // 7. Configuration
    onProgress?.call('Checking configuration...');
    results.add(_checkConfiguration());

    onProgress?.call('Diagnostics complete!');
    return results;
  }

  Future<DiagnosticResult> _checkSystemInfo() async {
    try {
      final os = Platform.operatingSystem;
      final version = Platform.operatingSystemVersion;
      final locale = Platform.localeName;

      return DiagnosticResult(
        name: 'System Information',
        status: DiagnosticStatus.success,
        message: 'OS: $os',
        details: 'Version: $version\nLocale: $locale',
      );
    } catch (e) {
      return DiagnosticResult(
        name: 'System Information',
        status: DiagnosticStatus.error,
        message: 'Failed to get system info',
        details: e.toString(),
      );
    }
  }

  DiagnosticResult _checkAppVersion() {
    return DiagnosticResult(
      name: 'App Version',
      status: DiagnosticStatus.info,
      message: '1.0.0-alpha',
      details: 'TrustTune GUI',
    );
  }

  Future<DiagnosticResult> _checkTransmissionDaemon() async {
    try {
      final isRunning = await daemonManager.isDaemonRunning();

      if (isRunning) {
        return DiagnosticResult(
          name: 'Transmission Daemon',
          status: DiagnosticStatus.success,
          message: 'Daemon is running',
          details: 'Port: 9091\nConfig: ${daemonManager.configDir}',
        );
      } else {
        return DiagnosticResult(
          name: 'Transmission Daemon',
          status: DiagnosticStatus.error,
          message: 'Daemon is not running',
          details: 'Please start Transmission daemon to use download features',
        );
      }
    } catch (e) {
      return DiagnosticResult(
        name: 'Transmission Daemon',
        status: DiagnosticStatus.error,
        message: 'Error checking daemon status',
        details: e.toString(),
      );
    }
  }

  Future<DiagnosticResult> _checkTransmissionRPC() async {
    try {
      final client = TransmissionClient(baseUrl: appSettings.transmissionRpcUrl);
      final torrents = await client.getTorrents().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('RPC request timed out'),
      );

      return DiagnosticResult(
        name: 'Transmission RPC',
        status: DiagnosticStatus.success,
        message: 'RPC connection successful',
        details: 'URL: ${appSettings.transmissionRpcUrl}\nActive torrents: ${torrents.length}',
      );
    } catch (e) {
      return DiagnosticResult(
        name: 'Transmission RPC',
        status: DiagnosticStatus.error,
        message: 'RPC connection failed',
        details: 'URL: ${appSettings.transmissionRpcUrl}\nError: ${e.toString()}',
      );
    }
  }

  Future<DiagnosticResult> _checkSearchAPI() async {
    try {
      final url = '${appSettings.searchApiUrl}/health';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('API request timed out'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final version = data['version'] ?? 'unknown';
        final searchReady = data['search_ready'] ?? false;

        return DiagnosticResult(
          name: 'Search API Health',
          status: searchReady ? DiagnosticStatus.success : DiagnosticStatus.warning,
          message: searchReady ? 'API is healthy' : 'API is running but search not ready',
          details: 'URL: ${appSettings.searchApiUrl}\nVersion: $version\nSearch Ready: $searchReady',
        );
      } else {
        return DiagnosticResult(
          name: 'Search API Health',
          status: DiagnosticStatus.error,
          message: 'API returned error status',
          details: 'URL: ${appSettings.searchApiUrl}\nStatus: ${response.statusCode}\nBody: ${response.body}',
        );
      }
    } catch (e) {
      return DiagnosticResult(
        name: 'Search API Health',
        status: DiagnosticStatus.error,
        message: 'Failed to connect to API',
        details: 'URL: ${appSettings.searchApiUrl}\nError: ${e.toString()}',
      );
    }
  }

  Future<DiagnosticResult> _checkTestSearch() async {
    try {
      final url = '${appSettings.searchApiUrl}/api/search';
      final body = jsonEncode({
        'query': 'test',
        'format_filter': null,
        'min_seeders': 1,
        'limit': 10,
      });

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Search request timed out'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List? ?? [];
        final totalFound = data['total_found'] ?? 0;
        final searchTime = data['search_time_ms'] ?? 0;

        // Check if results have magnet links
        var validMagnets = 0;
        if (results.isNotEmpty) {
          for (var result in results) {
            if (result['torrent'] != null &&
                result['torrent']['magnet_link'] != null &&
                result['torrent']['magnet_link'].toString().isNotEmpty) {
              validMagnets++;
            }
          }
        }

        final hasValidResults = results.isNotEmpty && validMagnets > 0;

        return DiagnosticResult(
          name: 'Test Search',
          status: hasValidResults ? DiagnosticStatus.success : DiagnosticStatus.warning,
          message: hasValidResults
              ? 'Search working correctly'
              : 'Search returned results but no valid magnet links',
          details: 'Query: "test"\nTotal found: $totalFound\nResults returned: ${results.length}\nWith valid magnets: $validMagnets\nSearch time: ${searchTime}ms',
        );
      } else {
        return DiagnosticResult(
          name: 'Test Search',
          status: DiagnosticStatus.error,
          message: 'Search request failed',
          details: 'Status: ${response.statusCode}\nBody: ${response.body}',
        );
      }
    } catch (e) {
      return DiagnosticResult(
        name: 'Test Search',
        status: DiagnosticStatus.error,
        message: 'Search request failed',
        details: e.toString(),
      );
    }
  }

  DiagnosticResult _checkConfiguration() {
    final buffer = StringBuffer();
    buffer.writeln('Search API: ${appSettings.displaySearchApiUrl}');
    buffer.writeln('Transmission RPC: ${appSettings.transmissionRpcUrl}');
    final downloadDir = appSettings.customDownloadDir ?? '';
    buffer.writeln('Download Dir: ${downloadDir.isEmpty ? "default" : downloadDir}');
    buffer.writeln('Using Default API: ${appSettings.isUsingDefaultApi}');

    return DiagnosticResult(
      name: 'Configuration',
      status: DiagnosticStatus.info,
      message: 'Configuration loaded',
      details: buffer.toString().trim(),
    );
  }

  String generateMarkdownReport(List<DiagnosticResult> results) {
    final buffer = StringBuffer();

    buffer.writeln('# TrustTune Diagnostics Report');
    buffer.writeln();
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('## System Information');
    buffer.writeln();

    for (var result in results) {
      buffer.writeln(result.toMarkdown());
      buffer.writeln();
    }

    buffer.writeln('## Summary');
    final successCount = results.where((r) => r.status == DiagnosticStatus.success).length;
    final warningCount = results.where((r) => r.status == DiagnosticStatus.warning).length;
    final errorCount = results.where((r) => r.status == DiagnosticStatus.error).length;

    buffer.writeln('- ✅ Success: $successCount');
    buffer.writeln('- ⚠️ Warnings: $warningCount');
    buffer.writeln('- ❌ Errors: $errorCount');
    buffer.writeln('- Total Checks: ${results.length}');

    return buffer.toString();
  }

  String generateGitHubIssueUrl(List<DiagnosticResult> results) {
    final title = Uri.encodeComponent('Bug Report: [Brief description]');
    final report = generateMarkdownReport(results);
    final body = Uri.encodeComponent('''
**Describe the bug:**
[Please describe what went wrong]

**Expected behavior:**
[What should have happened instead]

**Steps to reproduce:**
1. [First step]
2. [Second step]
3. [Third step]

---

## Diagnostic Report

$report
''');

    return 'https://github.com/trust-tune-net/karma-player/issues/new?title=$title&body=$body';
  }
}
