import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'daemon_manager.dart';
import 'app_settings.dart';
import 'transmission_client.dart';
import 'analytics_service.dart';
import 'api_auth_service.dart';
import 'device_service.dart';
import 'search_service_grpc.dart';

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
  final ApiAuthService _apiAuthService = ApiAuthService();
  final DeviceService _deviceService = DeviceService();

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
    results.add(await _checkAppVersion());

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
    } catch (e, stackTrace) {
      // Report unexpected system info failures
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'diagnostics_system_info_error',
      );
      
      return DiagnosticResult(
        name: 'System Information',
        status: DiagnosticStatus.error,
        message: 'Failed to get system info',
        details: e.toString(),
      );
    }
  }

  Future<DiagnosticResult> _checkAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return DiagnosticResult(
        name: 'App Version',
        status: DiagnosticStatus.info,
        message: 'v${packageInfo.version}',
        details: 'TrustTune GUI (Build ${packageInfo.buildNumber})',
      );
    } catch (e, stackTrace) {
      // Report unexpected app version read failures
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'diagnostics_app_version_error',
      );
      
      return DiagnosticResult(
        name: 'App Version',
        status: DiagnosticStatus.error,
        message: 'Failed to read version',
        details: e.toString(),
      );
    }
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
    } catch (e, stackTrace) {
      // Report unexpected daemon check failures
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'diagnostics_daemon_check_error',
      );
      
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
    } catch (e, stackTrace) {
      // Diagnostics are user-initiated tests - don't report to Glitchtip
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
    } catch (e, stackTrace) {
      // Diagnostics are user-initiated tests - don't report to Glitchtip
      return DiagnosticResult(
        name: 'Search API Health',
        status: DiagnosticStatus.error,
        message: 'Failed to connect to API',
        details: 'URL: ${appSettings.searchApiUrl}\nError: ${e.toString()}',
      );
    }
  }

  Future<DiagnosticResult> _checkTestSearch() async {
    final stopwatch = Stopwatch()..start();

    // Try gRPC first
    try {
      final uri = Uri.parse(appSettings.searchApiUrl);
      // gRPC on port 50051 is typically insecure (plaintext)
      final useSecure = false;

      final grpcService = SearchServiceGrpc(
        authService: _apiAuthService,
        deviceService: _deviceService,
        host: uri.host,
        port: 50051,
        useSecure: useSecure,
      );

      int totalResults = 0;
      int completeResults = 0;
      String? errorMessage;

      await for (final result in grpcService.search(
        query: 'pink floyd',
        minSeeders: 1,
        limit: 10,
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: (sink) => throw TimeoutException('gRPC timed out'),
      )) {
        if (result.type == SearchResultType.complete) {
          totalResults = result.completeResult!.totalFound;
          completeResults = result.completeResult!.rankedSources.length;
          break;
        } else if (result.type == SearchResultType.error) {
          errorMessage = result.error?.message ?? 'Unknown error';
          break;
        }
      }

      stopwatch.stop();

      // gRPC worked!
      if (completeResults > 0) {
        return DiagnosticResult(
          name: 'Test Search',
          status: DiagnosticStatus.success,
          message: 'Search working (gRPC)',
          details: 'Query: "pink floyd"\nProtocol: gRPC (binary)\nTotal found: $totalResults\nResults: $completeResults\nTime: ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      // gRPC returned 0 results or error - fallback to WebSocket
    } catch (e) {
      // gRPC failed - fallback to WebSocket
    }

    // Fallback to WebSocket
    stopwatch.reset();
    stopwatch.start();

    try {
      final wsUrl = appSettings.searchApiUrl.replaceFirst('http', 'ws');
      final channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/search'));

      final authData = await _apiAuthService.getWebSocketAuth();

      channel.sink.add(json.encode({
        'auth': authData,
        'query': 'pink floyd',
        'format_filter': null,
        'min_seeders': 1,
        'limit': 10,
        'offset': 0,
      }));

      int totalResults = 0;
      int completeResults = 0;
      String? errorMessage;

      await for (final message in channel.stream.timeout(
        const Duration(seconds: 15),
        onTimeout: (sink) => throw TimeoutException('WebSocket timed out'),
      )) {
        final data = json.decode(message);

        // Accept partial_result as proof search is working (much faster!)
        if (data['type'] == 'partial_result') {
          final count = data['count'] ?? 0;
          if (count > 0) {
            completeResults = count;
            break;  // Got results from first adapter - search works!
          }
        } else if (data['type'] == 'result') {
          final resultData = data['data'];
          final results = List<Map<String, dynamic>>.from(resultData['results'] ?? []);
          completeResults = results.length;
          if (completeResults > 0) {
            break;
          }
        } else if (data['type'] == 'complete') {
          totalResults = data['total_found'] ?? 0;
          break;
        } else if (data['type'] == 'error') {
          errorMessage = data['message'] ?? 'Unknown error';
          break;
        }
      }

      channel.sink.close();
      stopwatch.stop();

      if (errorMessage != null) {
        return DiagnosticResult(
          name: 'Test Search',
          status: DiagnosticStatus.error,
          message: 'Search failed (WebSocket)',
          details: 'Query: "pink floyd"\nProtocol: WebSocket\nError: $errorMessage\nTime: ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      if (completeResults > 0) {
        return DiagnosticResult(
          name: 'Test Search',
          status: DiagnosticStatus.success,
          message: 'Search working (WebSocket fallback)',
          details: 'Query: "pink floyd"\nProtocol: WebSocket (gRPC unavailable)\nTotal found: $totalResults\nResults: $completeResults\nTime: ${stopwatch.elapsedMilliseconds}ms',
        );
      } else {
        return DiagnosticResult(
          name: 'Test Search',
          status: DiagnosticStatus.warning,
          message: 'Search returned no results',
          details: 'Query: "pink floyd"\nProtocol: WebSocket\nTotal found: $totalResults\nTime: ${stopwatch.elapsedMilliseconds}ms',
        );
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      return DiagnosticResult(
        name: 'Test Search',
        status: DiagnosticStatus.error,
        message: 'Both gRPC and WebSocket failed',
        details: 'Query: "pink floyd"\nError: ${e.toString()}\nTime: ${stopwatch.elapsedMilliseconds}ms',
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
