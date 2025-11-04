import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/mobile_discovery_service.dart';
import '../main.dart';

class MobileConnectivityScreen extends StatefulWidget {
  const MobileConnectivityScreen({super.key});

  @override
  State<MobileConnectivityScreen> createState() => _MobileConnectivityScreenState();
}

class _MobileConnectivityScreenState extends State<MobileConnectivityScreen> {
  final MobileDiscoveryService _discoveryService = MobileDiscoveryService();
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      await _discoveryService.initialize();
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _toggleDiscovery(bool enabled) async {
    try {
      if (enabled) {
        await _discoveryService.enable();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mobile discovery enabled'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _discoveryService.disable();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mobile discovery disabled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('[MobileConnectivity] Error toggling discovery: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        title: Row(
          children: [
            Text(
              'Mobile App',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const StatsBadges(),
          ],
        ),
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: _discoveryService,
              builder: (context, _) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header card with icon
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.phone_android,
                              size: 64,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Connect Your Mobile Device',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Control your music library from your phone',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[400],
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Enable/Disable Section
                    Card(
                      child: ListTile(
                        leading: Icon(
                          _discoveryService.isEnabled ? Icons.cloud : Icons.cloud_off,
                          color: _discoveryService.isEnabled ? Colors.green : Colors.grey,
                        ),
                        title: const Text('Mobile Discovery'),
                        subtitle: Text(
                          _discoveryService.isEnabled
                              ? 'Mobile app can discover this desktop'
                              : 'Mobile app cannot discover this desktop',
                        ),
                        trailing: Switch(
                          value: _discoveryService.isEnabled,
                          onChanged: _toggleDiscovery,
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.grey[400],
                          inactiveTrackColor: Colors.grey[800],
                          trackOutlineColor: MaterialStateProperty.resolveWith<Color?>((states) {
                            return null; // No outline
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // QR Code Section (only shown when enabled)
                    if (_discoveryService.isEnabled) ...[
                      Text(
                        'Scan to Connect',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // QR Code
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: QrImageView(
                                  data: _discoveryService.connectionInfoJson,
                                  version: QrVersions.auto,
                                  size: 240,
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Scan this QR code with the KarmaPlayer mobile app',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[400],
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Connection Info
                      Text(
                        'Connection Details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.computer),
                              title: const Text('Device Name'),
                              subtitle: Text(
                                _discoveryService.deviceName,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.wifi),
                              title: const Text('IP Address'),
                              subtitle: Text(
                                _discoveryService.ipAddress,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.settings_ethernet),
                              title: const Text('Port'),
                              subtitle: Text(
                                _discoveryService.port.toString(),
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Instructions
                    Text(
                      'How to Connect',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInstructionStep(
                              '1',
                              'Download the KarmaPlayer mobile app',
                              'Available on iOS App Store and Google Play Store',
                            ),
                            const SizedBox(height: 16),
                            _buildInstructionStep(
                              '2',
                              'Enable Mobile Discovery',
                              'Turn on the switch above to make this desktop discoverable',
                            ),
                            const SizedBox(height: 16),
                            _buildInstructionStep(
                              '3',
                              'Scan the QR code',
                              'Open the mobile app and scan the QR code shown above',
                            ),
                            const SizedBox(height: 16),
                            _buildInstructionStep(
                              '4',
                              'Enjoy your music',
                              'Control playback, browse your library, and search for music from your phone',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Connected Devices Section
                    if (_discoveryService.isEnabled) ...[
                      Text(
                        'Connected Devices',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _discoveryService.connectedDevices.isEmpty
                          ? Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.devices_other,
                                      size: 48,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No devices connected',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey[400],
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Scan the QR code to connect your mobile device',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Card(
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _discoveryService.connectedDevices.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final device = _discoveryService.connectedDevices[index];
                                  return ListTile(
                                    leading: const Icon(Icons.phone_android, color: Colors.green),
                                    title: Text(device.name),
                                    subtitle: Text(
                                      '${device.ipAddress} • Connected ${_formatTimeSince(device.connectedAt)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.close, size: 20),
                                      onPressed: () {
                                        _discoveryService.removeDevice(device.id);
                                      },
                                      tooltip: 'Disconnect',
                                    ),
                                  );
                                },
                              ),
                            ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _buildInstructionStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[400],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimeSince(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);

    if (duration.inSeconds < 60) {
      return 'just now';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ago';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h ago';
    } else {
      return '${duration.inDays}d ago';
    }
  }
}
