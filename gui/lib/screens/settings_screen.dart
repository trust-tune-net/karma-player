import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart';
import '../widgets/diagnostics_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _downloadDir = '';
  String _configDir = '';
  bool _daemonRunning = false;
  bool _isCheckingDaemon = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkDaemonStatus();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _downloadDir = daemonManager.getDownloadDir(appSettings.customDownloadDir);
      _configDir = daemonManager.configDir;
    });
  }

  Future<void> _checkDaemonStatus() async {
    setState(() {
      _isCheckingDaemon = true;
    });

    final isRunning = await daemonManager.isDaemonRunning();

    setState(() {
      _daemonRunning = isRunning;
      _isCheckingDaemon = false;
    });

    // If daemon is not running on first check, retry after a delay
    // This handles the race condition where the app is starting and daemon is still initializing
    if (!isRunning && mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        final isRunningRetry = await daemonManager.isDaemonRunning();
        setState(() {
          _daemonRunning = isRunningRetry;
        });
      }
    }
  }

  Future<void> _toggleDaemon(bool enable) async {
    if (enable) {
      // Start daemon
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starting daemon...')),
      );

      final started = await daemonManager.startDaemon(customDownloadDir: appSettings.customDownloadDir);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(started ? 'Daemon started successfully' : 'Failed to start daemon'),
            backgroundColor: started ? Colors.green : Colors.red,
          ),
        );
        _checkDaemonStatus();
      }
    } else {
      // Stop daemon
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stopping daemon...')),
      );

      await daemonManager.stopDaemon();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daemon stopped'),
            backgroundColor: Colors.orange,
          ),
        );
        _checkDaemonStatus();
      }
    }
  }

  Future<void> _restartDaemon() async {
    await daemonManager.stopDaemon();
    await Future.delayed(const Duration(seconds: 1));
    await daemonManager.startDaemon(customDownloadDir: appSettings.customDownloadDir);
    _checkDaemonStatus();
  }

  Future<void> _editSearchApiUrl() async {
    final controller = TextEditingController(text: appSettings.searchApiUrl);
    final newUrl = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Search API URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Search API URL',
            hintText: 'https://example.com',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newUrl != null && newUrl.isNotEmpty && newUrl != appSettings.searchApiUrl) {
      await appSettings.saveSearchApiUrl(newUrl);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Search API URL updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _openDiagnostics() async {
    await showDialog(
      context: context,
      builder: (context) => DiagnosticsDialog(
        daemonManager: daemonManager,
        appSettings: appSettings,
      ),
    );
  }

  Future<void> _editDownloadDir() async {
    final controller = TextEditingController(text: _downloadDir);
    final newDir = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Download Directory'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Download Directory',
            hintText: '/Users/username/Downloads',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newDir != null && newDir.isNotEmpty && newDir != _downloadDir) {
      await appSettings.saveDownloadDir(newDir);
      setState(() {
        _downloadDir = newDir;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Download directory updated. Restart daemon to apply changes.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Restart',
              onPressed: _restartDaemon,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: Row(
          children: [
            Text(
              'Settings',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const StatsBadges(), // No albums count for Settings screen
          ],
        ),
      ),
      body: ListView(
        children: [
          // Diagnostics Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton.icon(
              onPressed: _openDiagnostics,
              icon: const Icon(Icons.bug_report),
              label: const Text('Run System Diagnostics'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const Divider(),

          // Daemon Settings Section
          ListTile(
            title: Text(
              'Transmission Daemon',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: Icon(
              _daemonRunning ? Icons.check_circle : Icons.error,
              color: _daemonRunning ? Colors.green : Colors.red,
            ),
            title: const Text('Daemon Control'),
            subtitle: Text(
              _isCheckingDaemon
                  ? 'Checking...'
                  : _daemonRunning
                      ? 'Running on port 9091'
                      : 'Stopped',
            ),
            trailing: Switch(
              value: _daemonRunning,
              onChanged: _isCheckingDaemon ? null : _toggleDaemon,
              activeColor: Colors.green,
              inactiveThumbColor: Colors.grey[400],
              inactiveTrackColor: Colors.grey[800],
              trackOutlineColor: MaterialStateProperty.resolveWith<Color?>((states) {
                return null; // No outline
              }),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('Daemon Port'),
            subtitle: const Text('9091'),
          ),
          ListTile(
            leading: const Icon(Icons.settings_applications),
            title: const Text('Config Directory'),
            subtitle: Text(
              _configDir.isNotEmpty ? _configDir : 'Loading...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
          const Divider(),

          // Download Settings Section
          ListTile(
            title: Text(
              'Downloads',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Download Directory'),
            subtitle: Text(
              _downloadDir.isNotEmpty ? _downloadDir : 'Loading...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editDownloadDir,
              tooltip: 'Change download directory',
            ),
          ),
          const Divider(),

          // API Settings Section
          ListTile(
            title: Text(
              'API Configuration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.search,
              color: appSettings.isUsingDefaultApi
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary,
            ),
            title: Row(
              children: [
                const Text('Search API URL'),
                const SizedBox(width: 8),
                if (!appSettings.isUsingDefaultApi)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'CUSTOM',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              appSettings.displaySearchApiUrl,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editSearchApiUrl,
              tooltip: 'Change search API URL',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: const Text('Transmission RPC URL'),
            subtitle: Text(
              appSettings.transmissionRpcUrl,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
          const Divider(),

          // About Section
          ListTile(
            title: Text(
              'About',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.music_note, color: Color(0xFFA855F7)),
            title: const Text('Trust Tune Network'),
            subtitle: Text(
              'Phase 0 of the Trust Tune Network\n\nA fair music ecosystem where artists get 95% of revenue and listeners get high-quality, DRM-free music. Built on transparency, community validation, and decentralized infrastructure.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const ListTile(
            leading: Icon(Icons.search, color: Color(0xFFA855F7)),
            title: Text('What'),
            subtitle: Text('AI-powered music discovery that finds the highest quality audio (FLAC, hi-res) from multiple sources, ranked and explained by AI.'),
          ),
          const ListTile(
            leading: Icon(Icons.favorite, color: Color(0xFFA855F7)),
            title: Text('Why'),
            subtitle: Text('Spotify pays \$0.003/stream (30% to artists). We\'re building a protocol where artists get 95% + transparent analytics showing WHO listens and WHERE.'),
          ),
          const ListTile(
            leading: Icon(Icons.lightbulb_outline, color: Color(0xFFA855F7)),
            title: Text('How'),
            subtitle: Text('Search → MusicBrainz canonical metadata → Multi-source torrent search (Jackett/1337x) → AI quality ranking → Transmission downloads → Local library. Future: Community validation + creator payments.'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline, color: Color(0xFFA855F7)),
            title: Text('Status'),
            subtitle: Text('Phase 0 (Beta): Desktop player with AI search works today. Phase 1-2: Federation & web app. Phase 3-5: Creator compensation + community validation.'),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.hasData ? 'v${snapshot.data!.version}' : 'Loading...';
              return ListTile(
                leading: const Icon(Icons.code, color: Color(0xFFA855F7)),
                title: const Text('Version'),
                subtitle: Text(version),
              );
            },
          ),
          if (kDebugMode)
            ListTile(
              leading: Icon(
                Icons.bug_report,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('Debug Mode'),
              subtitle: const Text('Running in development mode'),
            ),
        ],
      ),
    );
  }
}
