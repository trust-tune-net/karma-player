import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:media_kit/media_kit.dart';
import '../main.dart';
import '../widgets/diagnostics_dialog.dart';
import '../services/analytics_service.dart';
import '../services/audio_device_service.dart';
import '../services/platform/audio_device_platform.dart';

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
  bool _analyticsEnabled = false;
  
  // Audio device service
  final AudioDeviceService _audioDeviceService = AudioDeviceService();
  bool _isLoadingDevices = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkDaemonStatus();
    _loadAnalyticsPreference();
    _initializeAudioDevices();
  }

  Future<void> _initializeAudioDevices() async {
    setState(() {
      _isLoadingDevices = true;
    });
    try {
      await _audioDeviceService.initialize();
    } catch (e) {
      print('[Settings] Error initializing audio devices: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDevices = false;
        });
      }
    }
  }

  Future<void> _loadAnalyticsPreference() async {
    setState(() {
      _analyticsEnabled = AnalyticsService().isEnabled;
    });
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
    try {
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
    } catch (e, stackTrace) {
      print('[Settings] Error toggling daemon: $e');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'settings_toggle_daemon',
        extras: {
          'action': enable ? 'start' : 'stop',
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restartDaemon() async {
    try {
      await daemonManager.stopDaemon();
      await Future.delayed(const Duration(seconds: 1));
      await daemonManager.startDaemon(customDownloadDir: appSettings.customDownloadDir);
      _checkDaemonStatus();
    } catch (e, stackTrace) {
      print('[Settings] Error restarting daemon: $e');
      AnalyticsService().captureError(
        e,
        stackTrace,
        context: 'settings_restart_daemon',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restarting daemon: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Future<void> _toggleAnalytics(bool enabled) async {
    await AnalyticsService().setEnabled(enabled);
    setState(() {
      _analyticsEnabled = enabled;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Crash reporting enabled. Restart app to activate. Thank you for helping improve TrustTune!'
                : 'Crash reporting disabled. Restart app to take effect.',
          ),
          backgroundColor: enabled ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 5), // Longer duration to ensure user reads the message
        ),
      );
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

          // Audio Output Section
          ListTile(
            title: Text(
              'Audio Output',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListenableBuilder(
            listenable: _audioDeviceService,
            builder: (context, _) {
              // Prefer platform devices if available (more accurate on macOS)
              final usesPlatformDevices = _audioDeviceService.supportsNativeEnumeration &&
                  _audioDeviceService.hasPlatformDevices;

              final devices = _audioDeviceService.availableDevices;
              final platformDevices = _audioDeviceService.platformDevices;
              final selectedDevice = _audioDeviceService.selectedDevice;

              if (_isLoadingDevices) {
                return ListTile(
                  leading: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: const Text('Loading audio devices...'),
                );
              }

              if (!usesPlatformDevices && devices.isEmpty) {
                return ListTile(
                  leading: const Icon(Icons.speaker_notes_outlined, color: Colors.grey),
                  title: const Text('No audio devices found'),
                  subtitle: const Text('Check your system audio settings'),
                );
              }

              if (usesPlatformDevices && platformDevices.isEmpty) {
                return ListTile(
                  leading: const Icon(Icons.speaker_notes_outlined, color: Colors.grey),
                  title: const Text('No audio devices found'),
                  subtitle: const Text('Check your system audio settings'),
                );
              }
              
              // Determine device name and type to display
              String deviceName = 'System Default';
              AudioDeviceType deviceType = AudioDeviceType.other;

              if (usesPlatformDevices && platformDevices.isNotEmpty) {
                // Try to find matching platform device by comparing names
                PlatformAudioDevice? matchingPlatformDevice;
                if (selectedDevice != null) {
                  matchingPlatformDevice = platformDevices.where((pd) {
                    // Match by name or by media_kit device name containing platform device name
                    return selectedDevice.name.contains(pd.id) ||
                           selectedDevice.name.contains(pd.name) ||
                           pd.name.contains(selectedDevice.name);
                  }).firstOrNull;
                }

                if (matchingPlatformDevice != null) {
                  deviceName = matchingPlatformDevice.friendlyName;
                  deviceType = matchingPlatformDevice.deviceType;
                } else if (platformDevices.isNotEmpty) {
                  // Default to first platform device if no match
                  deviceName = platformDevices.first.friendlyName;
                  deviceType = platformDevices.first.deviceType;
                }
              } else if (selectedDevice != null) {
                deviceName = _audioDeviceService.getFriendlyName(selectedDevice);
                deviceType = _audioDeviceService.getDeviceType(selectedDevice);
              }

              return ListTile(
                leading: Icon(
                  _getDeviceIcon(deviceType),
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Audio Output Device'),
                subtitle: Text(
                  deviceName,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onTap: () {
                  if (usesPlatformDevices) {
                    _showPlatformAudioDeviceDropdown(context, platformDevices, selectedDevice);
                  } else {
                    _showAudioDeviceDropdown(context, devices, selectedDevice);
                  }
                },
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh, size: 20),
            title: const Text('Refresh Devices'),
            subtitle: const Text('Reload available audio output devices'),
            onTap: () async {
              setState(() {
                _isLoadingDevices = true;
              });
              try {
                await _audioDeviceService.refreshDevices();
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoadingDevices = false;
                  });
                }
              }
            },
          ),
          const Divider(),

          // Privacy Section
          ListTile(
            title: Text(
              'Privacy',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: Icon(
              _analyticsEnabled ? Icons.shield : Icons.shield_outlined,
              color: _analyticsEnabled ? Colors.green : Colors.grey,
            ),
            title: const Text('Crash Reporting'),
            subtitle: const Text(
              'Help improve TrustTune by automatically sending anonymous crash reports to our self-hosted GlitchTip server. No personal data is collected.',
            ),
            trailing: Switch(
              value: _analyticsEnabled,
              onChanged: _toggleAnalytics,
              activeColor: Colors.green,
              inactiveThumbColor: Colors.grey[400],
              inactiveTrackColor: Colors.grey[800],
              trackOutlineColor: MaterialStateProperty.resolveWith<Color?>((states) {
                return null; // No outline
              }),
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
              subtitle: const Text('Running in development mode'            ),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(AudioDeviceType type) {
    switch (type) {
      case AudioDeviceType.bluetooth:
        return Icons.bluetooth_audio;
      case AudioDeviceType.usb:
        return Icons.usb;
      case AudioDeviceType.hdmi:
        return Icons.cable; // HDMI icon alternative
      case AudioDeviceType.airplay:
        return Icons.airplay;
      case AudioDeviceType.builtIn:
        return Icons.speaker;
      case AudioDeviceType.other:
      default:
        return Icons.audiotrack;
    }
  }

  String _getDeviceTypeDescription(AudioDeviceType type) {
    switch (type) {
      case AudioDeviceType.bluetooth:
        return 'Bluetooth device';
      case AudioDeviceType.usb:
        return 'USB / DAC';
      case AudioDeviceType.hdmi:
        return 'HDMI output';
      case AudioDeviceType.airplay:
        return 'AirPlay device';
      case AudioDeviceType.builtIn:
        return 'Built-in speakers';
      case AudioDeviceType.other:
      default:
        return 'Audio output';
    }
  }

  void _showAudioDeviceDropdown(
    BuildContext context,
    List<AudioDevice> devices,
    AudioDevice? selectedDevice,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.speaker,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Select Audio Output',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            // Device list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  final isSelected = selectedDevice?.name == device.name;
                  final friendlyName = _audioDeviceService.getFriendlyName(device);
                  final technicalName = _audioDeviceService.getTechnicalName(device);
                  final deviceType = _audioDeviceService.getDeviceType(device);
                  
                  return ListTile(
                    leading: Icon(
                      _getDeviceIcon(deviceType),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFF888888),
                      size: 24,
                    ),
                    title: Text(
                      friendlyName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          technicalName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getDeviceTypeDescription(deviceType),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          )
                        : null,
                    selected: isSelected,
                    onTap: () async {
                      await _audioDeviceService.selectDevice(device);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Show platform audio device dropdown (uses CoreAudio/WASAPI enumeration)
  void _showPlatformAudioDeviceDropdown(
    BuildContext context,
    List<PlatformAudioDevice> devices,
    AudioDevice? selectedMediaKitDevice,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.speaker,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Select Audio Output',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            // Device list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];

                  // Try to match platform device with media_kit selected device
                  bool isSelected = false;
                  if (selectedMediaKitDevice != null) {
                    isSelected = selectedMediaKitDevice.name.contains(device.id) ||
                        selectedMediaKitDevice.name.contains(device.name) ||
                        device.name.contains(selectedMediaKitDevice.name);
                  }

                  return ListTile(
                    leading: Icon(
                      _getDeviceIcon(device.deviceType),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFF888888),
                      size: 24,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.friendlyName,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        // Show Bluetooth indicator
                        if (device.isBluetooth)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A84FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          device.id,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getDeviceTypeDescription(device.deviceType),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                            size: 24,
                          )
                        : null,
                    selected: isSelected,
                    onTap: () async {
                      // Find corresponding media_kit device to select
                      final mediaKitDevices = _audioDeviceService.availableDevices;
                      AudioDevice? matchingMediaKitDevice;

                      for (var mkDevice in mediaKitDevices) {
                        if (mkDevice.name.contains(device.id) ||
                            mkDevice.name.contains(device.name) ||
                            device.name.contains(mkDevice.name)) {
                          matchingMediaKitDevice = mkDevice;
                          break;
                        }
                      }

                      if (matchingMediaKitDevice != null) {
                        await _audioDeviceService.selectDevice(matchingMediaKitDevice);
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } else {
                        // Platform device found but no media_kit equivalent
                        // This shouldn't happen but handle gracefully
                        print('[Settings] Warning: Platform device "${device.name}" has no media_kit equivalent');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Device "${device.name}" not available for playback'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
