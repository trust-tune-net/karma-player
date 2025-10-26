import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../services/diagnostics_service.dart';
import '../services/daemon_manager.dart';
import '../services/app_settings.dart';

class DiagnosticsDialog extends StatefulWidget {
  final DaemonManager daemonManager;
  final AppSettings appSettings;

  const DiagnosticsDialog({
    super.key,
    required this.daemonManager,
    required this.appSettings,
  });

  @override
  State<DiagnosticsDialog> createState() => _DiagnosticsDialogState();
}

class _DiagnosticsDialogState extends State<DiagnosticsDialog> {
  late DiagnosticsService _diagnosticsService;
  List<DiagnosticResult> _results = [];
  bool _isRunning = false;
  String _currentProgress = '';
  String? _markdownReport;

  @override
  void initState() {
    super.initState();
    _diagnosticsService = DiagnosticsService(
      daemonManager: widget.daemonManager,
      appSettings: widget.appSettings,
    );
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _results = [];
      _currentProgress = 'Starting diagnostics...';
    });

    try {
      final results = await _diagnosticsService.runAllDiagnostics(
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _currentProgress = message;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _results = results;
          _markdownReport = _diagnosticsService.generateMarkdownReport(results);
          _isRunning = false;
          _currentProgress = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _currentProgress = 'Error: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_markdownReport != null) {
      await Clipboard.setData(ClipboardData(text: _markdownReport!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diagnostics report copied to clipboard'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _openGitHubIssue() async {
    if (_results.isEmpty) return;

    final url = _diagnosticsService.generateGitHubIssueUrl(_results);

    try {
      // Use platform-specific command to open URL
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('start', [url]);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening GitHub in browser...'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open browser: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(DiagnosticStatus status) {
    switch (status) {
      case DiagnosticStatus.success:
        return Colors.green;
      case DiagnosticStatus.warning:
        return Colors.orange;
      case DiagnosticStatus.error:
        return Colors.red;
      case DiagnosticStatus.info:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(DiagnosticStatus status) {
    switch (status) {
      case DiagnosticStatus.success:
        return Icons.check_circle;
      case DiagnosticStatus.warning:
        return Icons.warning;
      case DiagnosticStatus.error:
        return Icons.error;
      case DiagnosticStatus.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final successCount = _results.where((r) => r.status == DiagnosticStatus.success).length;
    final warningCount = _results.where((r) => r.status == DiagnosticStatus.warning).length;
    final errorCount = _results.where((r) => r.status == DiagnosticStatus.error).length;

    return Dialog(
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.bug_report,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Diagnostics',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_isRunning)
                        Text(
                          _currentProgress,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        )
                      else if (_results.isNotEmpty)
                        Text(
                          'Completed ${_results.length} checks',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Summary (if completed)
            if (!_isRunning && _results.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(Icons.check_circle, 'Success', successCount, Colors.green),
                    _buildSummaryItem(Icons.warning, 'Warnings', warningCount, Colors.orange),
                    _buildSummaryItem(Icons.error, 'Errors', errorCount, Colors.red),
                  ],
                ),
              ),

            if (!_isRunning && _results.isNotEmpty) const SizedBox(height: 16),

            // Results List
            Expanded(
              child: _isRunning
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(_currentProgress),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            leading: Icon(
                              _getStatusIcon(result.status),
                              color: _getStatusColor(result.status),
                            ),
                            title: Text(
                              result.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(result.message),
                            children: [
                              if (result.details != null && result.details!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      result.details!,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontFamily: 'monospace',
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Actions
            if (!_isRunning && _results.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Report'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openGitHubIssue,
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Create GitHub Issue'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
