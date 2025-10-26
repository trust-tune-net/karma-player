import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../services/daemon_manager.dart';

final appSettings = AppSettings();
final daemonManager = DaemonManager();

class StatusBar extends StatefulWidget {
  const StatusBar({super.key});

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  bool _daemonRunning = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    // Update status every 10 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final daemonStatus = await daemonManager.isDaemonRunning();
    await appSettings.checkApiHealth();

    if (mounted) {
      setState(() {
        _daemonRunning = daemonStatus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      child: Row(
        children: [
          // API Status Indicator
          Tooltip(
            message: appSettings.isUsingDefaultApi ? 'Using default API' : 'Using custom API',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  appSettings.isUsingDefaultApi ? Icons.cloud : Icons.cloud_done,
                  size: 16,
                  color: appSettings.isUsingDefaultApi
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: appSettings.apiHealthy ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),
          const Text('|', style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 16),

          // Daemon Status
          Tooltip(
            message: _daemonRunning ? 'Daemon running' : 'Daemon stopped',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.downloading,
                  size: 16,
                  color: _daemonRunning ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  _daemonRunning ? 'ON' : 'OFF',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _daemonRunning ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Statistics
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.play_circle_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${appSettings.totalPlays}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.download_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${appSettings.downloadedGigabytes} GB',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
