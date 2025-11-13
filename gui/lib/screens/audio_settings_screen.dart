import 'package:flutter/material.dart';
import '../services/audio_device_service.dart';
import '../services/platform/audio_device_platform.dart';
import '../services/app_settings.dart';
import 'dart:io';
import '../main.dart';
import '../widgets/common/primary_screen_header.dart';

/// Dedicated audio settings screen for audiophile features
/// Phase 2: Exclusive mode, device selection, format info
/// Phase 3: Chipset detection, codec info, metadata
class AudioSettingsScreen extends StatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  State<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends State<AudioSettingsScreen> {
  final AudioDeviceService _audioService = AudioDeviceService();
  final AppSettings _appSettings = AppSettings();

  PlatformAudioDevice? _selectedPlatformDevice;
  bool _exclusiveModeEnabled = false;
  bool _exclusiveModeSupported = false;
  bool _loadingExclusiveMode = false;
  Map<String, dynamic>? _deviceFormat;
  Map<String, dynamic>? _deviceMetadata;
  bool _loadingMetadata = false;
  bool _refreshingDevices = false;
  bool _wirelessActive = false;
  String? _exclusiveModeReason;
  String? _metadataReason;
  bool _isManualRefresh = false; // Flag to suppress callbacks during manual refresh

  @override
  void initState() {
    super.initState();
    _initialize();

    // Listen to AudioDeviceService changes (e.g., when headphones plugged in)
    _audioService.addListener(_onAudioDeviceChanged);
    _wirelessActive = !_audioService.isExclusiveModeEligible;
    if (_wirelessActive && _exclusiveModeEnabled) {
      _exclusiveModeEnabled = false;
    }
  }

  /// Called when AudioDeviceService notifies of device changes
  /// This happens when:
  /// - User plugs/unplugs headphones
  /// - macOS changes system default device
  /// - User manually selects device
  void _onAudioDeviceChanged() {
    // Suppress callback during manual refresh to prevent flickering
    if (_isManualRefresh) {
      return;
    }
    
    print('[AudioSettings] Audio device changed, updating UI...');

    PlatformAudioDevice? deviceForCapability;

    // Sync UI with the newly selected device from AudioDeviceService
    final selectedDevice = _audioService.selectedDevice;

    if (selectedDevice != null && selectedDevice.name != 'auto') {
      // Map MediaKit AudioDevice to PlatformAudioDevice by description
      final matchingPlatformDevice = _audioService.platformDevices.firstWhere(
        (d) => d.name == selectedDevice.description,
        orElse: () => _audioService.platformDevices.isNotEmpty
            ? _audioService.platformDevices.first
            : _selectedPlatformDevice!,
      );

      if (mounted) {
        setState(() {
          _selectedPlatformDevice = matchingPlatformDevice;
          _exclusiveModeReason = null;
          _metadataReason = null;
          _deviceMetadata = null;
          _deviceFormat = null;
          final wirelessNow = !_audioService.isExclusiveModeEligible;
          if (wirelessNow && _exclusiveModeEnabled) {
            _exclusiveModeEnabled = false;
          }
          _wirelessActive = wirelessNow;
        });
      }

      print('[AudioSettings] ✓ UI updated to show: ${matchingPlatformDevice.name}');
      deviceForCapability = matchingPlatformDevice;
    }

    if (selectedDevice == null || selectedDevice.name == 'auto') {
      final wirelessNow = !_audioService.isExclusiveModeEligible;
      if (mounted) {
        setState(() {
          if (wirelessNow && _exclusiveModeEnabled) {
            _exclusiveModeEnabled = false;
          }
          _wirelessActive = wirelessNow;
        });
      }
      deviceForCapability ??= _selectedPlatformDevice;
    }

    if (deviceForCapability != null) {
      _loadExclusiveModeState(deviceForCapability);
    }
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    _audioService.removeListener(_onAudioDeviceChanged);
    super.dispose();
  }

  Future<void> _initialize() async {
    // Wait for platform devices to be available
    await Future.delayed(const Duration(milliseconds: 500));

    if (_audioService.platformDevices.isNotEmpty) {
      // Sync with the actual selected device from AudioService
      final selectedDevice = _audioService.selectedDevice;
      if (selectedDevice != null && selectedDevice.name != 'auto') {
        // Map MediaKit AudioDevice to PlatformAudioDevice by description
        _selectedPlatformDevice = _audioService.platformDevices.firstWhere(
          (d) => d.name == selectedDevice.description,
          orElse: () => _audioService.platformDevices.first,
        );
      } else {
        // If 'auto' or no device, query macOS for the actual default device
        try {
          final defaultPlatformDevice = await _audioService.platform.getDefaultDevice();
          if (defaultPlatformDevice != null) {
            _selectedPlatformDevice = _audioService.platformDevices.firstWhere(
              (d) => d.id == defaultPlatformDevice.id,
              orElse: () => _audioService.platformDevices.first,
            );
          } else {
            _selectedPlatformDevice = _audioService.platformDevices.first;
          }
        } catch (e) {
          print('[AudioSettings] Error getting default device: $e');
          _selectedPlatformDevice = _audioService.platformDevices.first;
        }
      }

      await _loadExclusiveModeState(_selectedPlatformDevice!);
      if (mounted) {
        setState(() {
          final wirelessNow = !_audioService.isExclusiveModeEligible;
          if (wirelessNow && _exclusiveModeEnabled) {
            _exclusiveModeEnabled = false;
          }
          _wirelessActive = wirelessNow;
        });
      }
    }
  }

  Future<void> _loadExclusiveModeState(PlatformAudioDevice device) async {
    if (mounted) {
      setState(() {
        _loadingMetadata = true;
      });
    }

    final deviceId = device.id;

    final exclusiveCapability = await _audioService.fetchExclusiveModeCapability(deviceId);
    final format = await _audioService.fetchDeviceFormat(deviceId);
    final metadataResult = await _audioService.fetchDeviceMetadata(deviceId);

    if (mounted) {
      setState(() {
        _exclusiveModeSupported = exclusiveCapability.supported;
        _exclusiveModeReason = exclusiveCapability.reason;
        if (!_exclusiveModeSupported && _exclusiveModeEnabled) {
          _exclusiveModeEnabled = false;
        }
        _deviceFormat = format;
        _deviceMetadata = metadataResult.metadata;
        _metadataReason = metadataResult.reason;
        _loadingMetadata = false;
      });
    }
  }

  Future<void> _toggleExclusiveMode(bool enable) async {
    if (_selectedPlatformDevice == null) return;
    if (enable && _wirelessActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exclusive mode is unavailable while a wireless output is active.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (enable && !_exclusiveModeSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_exclusiveModeReason ??
              'Exclusive mode is not supported for the selected device on ${Platform.operatingSystem}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _loadingExclusiveMode = true;
    });

    try {
      final success = await _audioService.platform.enableExclusiveMode(
        _selectedPlatformDevice!.id,
        enable,
      );

      if (mounted) {
        setState(() {
          _exclusiveModeEnabled = success && enable;
          _loadingExclusiveMode = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(enable
                  ? '✓ Exclusive mode enabled - other apps cannot use this device'
                  : '✓ Exclusive mode disabled'),
              backgroundColor: enable ? Colors.orange : Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(enable
                  ? '✗ Failed to enable exclusive mode - device may be in use'
                  : '✗ Failed to disable exclusive mode'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingExclusiveMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: PrimaryScreenHeader(
        title: 'Audio Settings',
        backgroundColor: const Color(0xFF0A0A0A),
        trailing: Align(
          alignment: Alignment.centerRight,
          child: StatsBadges(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          _buildSectionHeader('🎵 Audiophile Settings', 'High-quality audio output configuration'),
          const SizedBox(height: 32),

          // Wireless quick actions
          _buildWirelessOutputsSection(),
          const SizedBox(height: 32),

          // Device Selection Section
          _buildDeviceSelectionSection(),
          const SizedBox(height: 32),

          // Exclusive Mode Section (Phase 2)
          _buildExclusiveModeSection(),
          const SizedBox(height: 32),

          // Device Format Section
          _buildDeviceFormatSection(),
          const SizedBox(height: 32),

          // Phase 3 - Advanced Metadata
          _buildAdvancedMetadata(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildWirelessOutputsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2A2A2A),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.wifi_tethering, color: Color(0xFF9D4EDD), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wireless Outputs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect to AirPlay or Google Cast speakers without leaving Karma Player.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: _audioService,
            builder: (context, _) {
              final airPlayStatus = _audioService.airPlayStatus;
              final castStatus = _audioService.castStatus;

              final airPlayButtonLabel = _audioService.supportsAirPlayPicker
                  ? 'Open AirPlay Picker'
                  : 'Open Sound Settings';
              final castButtonLabel = _audioService.supportsCastPicker
                  ? 'Open Cast Picker'
                  : 'Open Sound Settings';

              return Column(
                children: [
                  _buildWirelessCard(
                    icon: Icons.airplay,
                    iconColor: const Color(0xFF9D4EDD),
                    title: 'AirPlay',
                    description: _airPlayDescription(),
                    status: airPlayStatus,
                    tooltip: _audioService.supportsAirPlayPicker
                        ? 'Launch the macOS AirPlay picker'
                        : 'Opens system sound settings to expose AirPlay devices',
                    buttonLabel: airPlayButtonLabel,
                    onPressed: _handleAirPlayAction,
                  ),
                  const SizedBox(height: 16),
                  _buildWirelessCard(
                    icon: Icons.cast,
                    iconColor: const Color(0xFF06D6A0),
                    title: 'Google Cast',
                    description: _castDescription(),
                    status: castStatus,
                    tooltip: _audioService.supportsCastPicker
                        ? 'Launch the Google Cast picker'
                        : 'Opens system sound settings for Cast-compatible sinks',
                    buttonLabel: castButtonLabel,
                    onPressed: _handleCastAction,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWirelessCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required WirelessOutputStatus status,
    required String tooltip,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF2A2A2A),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          const SizedBox(height: 16),
          Tooltip(
            message: tooltip,
            waitDuration: const Duration(milliseconds: 200),
            child: FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9D4EDD).withOpacity(0.15),
                foregroundColor: const Color(0xFF9D4EDD),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(WirelessOutputStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _statusLabel(WirelessOutputStatus status) {
    switch (status) {
      case WirelessOutputStatus.connected:
        return 'Connected';
      case WirelessOutputStatus.available:
        return 'Available';
      case WirelessOutputStatus.unavailable:
        return 'Unavailable';
    }
  }

  Color _statusColor(WirelessOutputStatus status) {
    switch (status) {
      case WirelessOutputStatus.connected:
        return const Color(0xFF10B981);
      case WirelessOutputStatus.available:
        return const Color(0xFFF59E0B);
      case WirelessOutputStatus.unavailable:
        return const Color(0xFF6B7280);
    }
  }

  Future<void> _handleAirPlayAction() async {
    final outcome = await _audioService.openAirPlayPicker();
    if (!mounted) return;
    _handleWirelessOutcome(
      label: 'AirPlay',
      outcome: outcome,
      guidance: _airPlayGuidance(),
    );
  }

  Future<void> _handleCastAction() async {
    final outcome = await _audioService.openCastPicker();
    if (!mounted) return;
    _handleWirelessOutcome(
      label: 'Google Cast',
      outcome: outcome,
      guidance: _castGuidance(),
    );
  }

  void _handleWirelessOutcome({
    required String label,
    required WirelessActionOutcome outcome,
    required List<String> guidance,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    switch (outcome) {
      case WirelessActionOutcome.pickerLaunched:
        messenger.showSnackBar(
          SnackBar(
            content: Text('Select your $label destination in the picker that just opened.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case WirelessActionOutcome.systemSettingsOpened:
        messenger.showSnackBar(
          SnackBar(
            content: Text('Opening system sound settings—choose your $label output there.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case WirelessActionOutcome.unsupported:
        _showWirelessGuidance(label: label, guidance: guidance);
        break;
      case WirelessActionOutcome.error:
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not open $label controls. Showing setup tips.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _showWirelessGuidance(label: label, guidance: guidance);
        break;
    }
  }

  void _showWirelessGuidance({
    required String label,
    required List<String> guidance,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            '$label setup tips',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: guidance
                .map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _airPlayDescription() {
    if (Platform.isMacOS) {
      return 'Use Control Center or the button below to pick an AirPlay target for Karma Player.';
    } else if (Platform.isWindows) {
      return 'Use an AirPlay bridge or Apple Music to expose AirPlay speakers, then open sound settings.';
    }
    return 'Expose AirPlay sinks (shairport-sync/RAOP) in your desktop environment and select them from system sound.';
  }

  String _castDescription() {
    if (Platform.isWindows) {
      return 'Chromecast and Nest speakers appear after you cast system audio through Chrome or Google Home.';
    } else if (Platform.isMacOS) {
      return 'Cast audio via Chrome or the Google Home app, then refresh devices to see the new route.';
    }
    return 'Use PipeWire/PulseAudio cast extensions or Chrome to start casting, then refresh devices.';
  }

  List<String> _airPlayGuidance() {
    if (Platform.isMacOS) {
      return [
        'Open Control Center → Screen Mirroring or Sound to choose your AirPlay device.',
        'Make sure the AirPlay speaker or Apple TV is on the same network and not muted.',
        'Return here and tap Refresh devices so the new route shows up in the list.',
      ];
    } else if (Platform.isWindows) {
      return [
        'Install an AirPlay bridge (AirParrot, TuneBlade) or use iTunes/Apple Music to enable AirPlay.',
        'Switch the Windows audio output to the AirPlay bridge from system sound settings.',
        'Use Refresh devices so Karma Player picks up the new AirPlay route.',
      ];
    }
    return [
      'Ensure a RAOP/AirPlay bridge such as shairport-sync is running on your network.',
      'Select the AirPlay sink via your desktop sound settings.',
      'Use Refresh devices to update the available outputs in Karma Player.',
    ];
  }

  List<String> _castGuidance() {
    if (Platform.isWindows || Platform.isMacOS) {
      return [
        'Make sure Google Chrome or the Google Home app can see your Chromecast/Nest speaker.',
        'Start casting system audio or set the Cast device as the default output in Google Home.',
        'Return to Karma Player and use Refresh devices to update the list.',
      ];
    }
    return [
      'Use Chrome, Chromium, or `pactl load-module module-null-sink` style Cast bridges to route audio.',
      'Confirm the Cast sink appears in your desktop sound settings.',
      'Refresh devices so Karma Player can target the Cast output.',
    ];
  }

  Future<void> _refreshAudioDevices() async {
    if (_refreshingDevices) return;

    // Set flag to suppress callbacks during refresh
    _isManualRefresh = true;

    setState(() {
      _refreshingDevices = true;
    });

    try {
      await _audioService.refreshDevices();
      if (!mounted) return;
      
      // Update selected device if it still exists, otherwise select first available
      if (_audioService.platformDevices.isNotEmpty) {
        final currentSelectedId = _selectedPlatformDevice?.id;
        final stillExists = _audioService.platformDevices.any((d) => d.id == currentSelectedId);
        
        if (!stillExists && _audioService.platformDevices.isNotEmpty) {
          // Previous device no longer exists, select first available
          _selectedPlatformDevice = _audioService.platformDevices.first;
        } else if (stillExists) {
          // Update reference to ensure it's current
          _selectedPlatformDevice = _audioService.platformDevices.firstWhere(
            (d) => d.id == currentSelectedId,
          );
        }
      }
      
      // Batch all state updates into one setState call
      if (mounted) {
        final wirelessNow = !_audioService.isExclusiveModeEligible;
        setState(() {
          _refreshingDevices = false;
          if (wirelessNow && _exclusiveModeEnabled) {
            _exclusiveModeEnabled = false;
          }
          _wirelessActive = wirelessNow;
        });
        
        // Load exclusive mode state after state update
        if (_selectedPlatformDevice != null) {
          await _loadExclusiveModeState(_selectedPlatformDevice!);
        }
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio devices refreshed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refreshingDevices = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not refresh devices: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      // Clear flag after refresh completes
      _isManualRefresh = false;
    }
  }

  Widget _buildDeviceSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2A2A2A),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speaker, color: Color(0xFF9D4EDD), size: 24),
              const SizedBox(width: 12),
              const Text(
                'Audio Output Device',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Refresh available output devices',
                waitDuration: const Duration(milliseconds: 200),
                child: TextButton.icon(
                  onPressed: _refreshingDevices ? null : _refreshAudioDevices,
                  icon: _refreshingDevices
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9D4EDD)),
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_refreshingDevices ? 'Refreshing...' : 'Refresh'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF9D4EDD),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Device dropdown
          ListenableBuilder(
            listenable: _audioService,
            builder: (context, _) {
              final devices = _audioService.platformDevices;

              if (devices.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No audio devices found',
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AirPlay device not listed? Connect via System Settings > Sound first, then refresh.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF3A3A3A),
                    width: 1,
                  ),
                ),
                child: Focus(
                  // Prevent space key from opening dropdown
                  onKeyEvent: (node, event) {
                    if (event.logicalKey.keyLabel == ' ') {
                      return KeyEventResult.skipRemainingHandlers;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedPlatformDevice?.id ?? devices.first.id,
                    dropdownColor: const Color(0xFF1A1A1A),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF9D4EDD)),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: devices.map((device) {
                    final deviceType = device.deviceType;
                    return DropdownMenuItem<String>(
                      value: device.id,
                      child: Row(
                        children: [
                          _getDeviceIcon(deviceType),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  device.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getFriendlyTypeName(device),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      // Find the platform device object by ID
                      final platformDevice = devices.firstWhere((d) => d.id == value);
                      setState(() {
                        _selectedPlatformDevice = platformDevice;
                      });

                      // Map to MediaKit AudioDevice and call selectDevice
                      // MediaKit's description matches PlatformDevice's name
                      try {
                        final mediaKitDevice = _audioService.availableDevices.firstWhere(
                          (d) => d.description == platformDevice.name || d.name == platformDevice.name,
                        );
                        print('[AudioSettings] ✓ Matched platform device "${platformDevice.name}" to MediaKit device "${mediaKitDevice.name}"');
                        await _audioService.selectDevice(mediaKitDevice);
                      } catch (e) {
                        print('[AudioSettings] ⚠️  Could not find MediaKit device for platform device "${platformDevice.name}"');
                        print('[AudioSettings] Available MediaKit devices:');
                        for (var d in _audioService.availableDevices) {
                          print('[AudioSettings]   - "${d.name}" (description: "${d.description}")');
                        }
                        // For AirPlay devices, use platform selection
                        if (platformDevice.isAirPlay) {
                          print('[AudioSettings] AirPlay device selected - attempting platform-level selection');
                          try {
                            final success = await _audioService.platform.setAudioDevice(platformDevice.id);
                            if (success) {
                              print('[AudioSettings] ✓ Set AirPlay device "${platformDevice.name}" via platform channel');
                              // Refresh devices to see if MediaKit picks it up
                              await _audioService.refreshDevices();
                              // Try to find it in MediaKit now
                              try {
                                final mediaKitDevice = _audioService.availableDevices.firstWhere(
                                  (d) => d.description == platformDevice.name || d.name == platformDevice.name,
                                );
                                await _audioService.selectDevice(mediaKitDevice);
                                print('[AudioSettings] ✓ Found MediaKit device after refresh');
                              } catch (_) {
                                // MediaKit still doesn't have it, but platform selection succeeded
                                print('[AudioSettings] ⚠️  Platform device set, but not available in MediaKit');
                              }
                            } else {
                              throw Exception('Platform returned false');
                            }
                          } catch (platformError) {
                            print('[AudioSettings] ❌ Failed to set device via platform: $platformError');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not switch to ${platformDevice.name}. Try selecting it in System Settings first.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        } else {
                          // For non-AirPlay devices, fall back to first available
                          if (_audioService.availableDevices.isNotEmpty) {
                            await _audioService.selectDevice(_audioService.availableDevices.first);
                          }
                        }
                      }

                      await _loadExclusiveModeState(platformDevice); // Reload for new device
                    }
                  },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          
          // AirPlay connection warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AirPlay device not in the list?',
                        style: TextStyle(
                          color: Colors.blue.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Connect it via System Settings first:',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstructionStep('1. Open System Settings > Sound'),
                      const SizedBox(height: 4),
                      _buildInstructionStep('2. Connect to your AirPlay device'),
                      const SizedBox(height: 4),
                      _buildInstructionStep('3. Return here and click Refresh'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await _audioService.platform.openSystemSoundSettings();
                      },
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('Open System Settings'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        foregroundColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _refreshingDevices ? null : _refreshAudioDevices,
                      icon: _refreshingDevices
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(_refreshingDevices ? 'Refreshing...' : 'Refresh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExclusiveModeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _exclusiveModeEnabled ? const Color(0xFFFF6B35) : const Color(0xFF2A2A2A),
          width: _exclusiveModeEnabled ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock, color: Color(0xFFFF6B35), size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Exclusive Mode (Hog Mode)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_loadingExclusiveMode)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: _exclusiveModeEnabled,
                  activeColor: const Color(0xFFFF6B35),
                  onChanged: _exclusiveModeSupported && !_wirelessActive ? _toggleExclusiveMode : null,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            'Exclusive mode provides bit-perfect audio by taking exclusive control of a local output device. '
            'Wireless routes (AirPlay, Google Cast, Bluetooth) continue using system mixing and cannot enter hog mode.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),

          if (_wirelessActive) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Switch to a wired or USB output to enable exclusive mode. macOS/Windows/Linux hand off wireless audio to the system mixer.',
                      style: TextStyle(
                        color: Colors.blue.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!_exclusiveModeSupported) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _exclusiveModeReason ??
                          'Exclusive mode not supported on this device for ${Platform.operatingSystem}.',
                      style: TextStyle(
                        color: Colors.orange.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_exclusiveModeEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFF6B35).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Color(0xFFFF6B35), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Device locked - other apps cannot play audio',
                      style: TextStyle(
                        color: const Color(0xFFFF6B35).withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceFormatSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2A2A2A),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq, color: Color(0xFF9D4EDD), size: 24),
              const SizedBox(width: 12),
              const Text(
                'Current Audio Format',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_deviceFormat != null) ...[
            _buildFormatRow('Sample Rate', '${_deviceFormat!['nominalSampleRate']?.toInt() ?? 0} Hz'),
            const SizedBox(height: 12),
            _buildFormatRow('Bit Depth', '${_deviceFormat!['bitDepth'] ?? 0} bit'),
            const SizedBox(height: 12),
            _buildFormatRow('Channels', '${_deviceFormat!['channels'] ?? 0}'),
            const SizedBox(height: 12),
            _buildFormatRow('Format', _deviceFormat!['isFloat'] == true ? 'Float' : 'Integer'),
          ] else ...[
            Text(
              'Select a device to view format information',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedMetadata() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2A2A2A),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory, color: Color(0xFF9D4EDD), size: 24),
              const SizedBox(width: 12),
              const Text(
                'Advanced Metadata',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_loadingMetadata) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          if (_deviceMetadata == null && !_loadingMetadata) ...[
            Text(
              _metadataReason == null
                  ? 'Select a device to view advanced metadata'
                  : 'Advanced metadata is unavailable for the selected device.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (_metadataReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _metadataReason!,
                        style: TextStyle(
                          color: Colors.blue.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (_deviceMetadata != null) ...[
            // USB DAC Chipset
            if (_deviceMetadata!['chipset'] != null) ...[
              _buildMetadataRow(
                Icons.developer_board,
                'DAC Chipset',
                '${_deviceMetadata!['chipset']}',
                const Color(0xFF9D4EDD),
              ),
              const SizedBox(height: 16),
            ],

            // Bluetooth Codec
            if (_deviceMetadata!['bluetoothCodec'] != null) ...[
              _buildMetadataRow(
                Icons.bluetooth_audio,
                'Bluetooth Codec',
                '${_deviceMetadata!['bluetoothCodec']}',
                const Color(0xFF0A84FF),
              ),
              const SizedBox(height: 16),
            ],

            // Transport Type
            if (_deviceMetadata!['transportType'] != null) ...[
              _buildMetadataRow(
                Icons.cable,
                'Connection',
                '${_deviceMetadata!['transportType']}',
                const Color(0xFF06D6A0),
              ),
              const SizedBox(height: 16),
            ],

            // Device Capabilities - Max Channels
            if (_deviceMetadata!['capabilities'] != null) ...[
              () {
                try {
                  final caps = _deviceMetadata!['capabilities'];
                  if (caps != null && caps is Map) {
                    final maxChannels = caps['maxChannels'];
                    if (maxChannels != null) {
                      return Column(
                        children: [
                          _buildMetadataRow(
                            Icons.speaker_group,
                            'Max Channels',
                            '$maxChannels',
                            const Color(0xFFFFB84D),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }
                  }
                } catch (e) {
                  print('[AudioSettings] Error accessing capabilities: $e');
                }
                return const SizedBox.shrink();
              }(),
            ],

            // Supported Sample Rates
            if (_deviceMetadata!['supportedSampleRates'] != null) ...[
              () {
                try {
                  final rates = _deviceMetadata!['supportedSampleRates'];
                  if (rates is List && rates.isNotEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Supported Sample Rates',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: rates
                              .map((rate) {
                                try {
                                  final rateValue = rate is double ? rate : (rate is int ? rate.toDouble() : double.tryParse('$rate'));
                                  if (rateValue != null) {
                                    return _buildSampleRateChip(rateValue);
                                  }
                                } catch (e) {
                                  print('[AudioSettings] Error parsing rate: $e');
                                }
                                return const SizedBox.shrink();
                              })
                              .where((widget) => widget is! SizedBox)
                              .toList(),
                        ),
                      ],
                    );
                  }
                } catch (e) {
                  print('[AudioSettings] Error accessing sample rates: $e');
                }
                return const SizedBox.shrink();
              }(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSampleRateChip(double sampleRate) {
    // Highlight high-res rates (>48kHz)
    final isHighRes = sampleRate > 48000;
    final rateKhz = (sampleRate / 1000).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isHighRes
            ? const Color(0xFF9D4EDD).withOpacity(0.2)
            : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighRes
              ? const Color(0xFF9D4EDD).withOpacity(0.5)
              : const Color(0xFF3A3A3A),
          width: 1,
        ),
      ),
      child: Text(
        '${rateKhz}kHz',
        style: TextStyle(
          color: isHighRes ? const Color(0xFF9D4EDD) : Colors.white,
          fontSize: 12,
          fontWeight: isHighRes ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _getDeviceIcon(AudioDeviceType type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case AudioDeviceType.bluetooth:
        iconData = Icons.bluetooth_audio;
        iconColor = const Color(0xFF0A84FF);
        break;
      case AudioDeviceType.usb:
        iconData = Icons.usb;
        iconColor = const Color(0xFF9D4EDD);
        break;
      case AudioDeviceType.hdmi:
        iconData = Icons.monitor;
        iconColor = const Color(0xFF06D6A0);
        break;
      case AudioDeviceType.airplay:
        iconData = Icons.cast;
        iconColor = const Color(0xFF06D6A0);
        break;
      case AudioDeviceType.builtIn:
        iconData = Icons.speaker;
        iconColor = const Color(0xFF8B8B8B);
        break;
      default:
        iconData = Icons.speaker;
        iconColor = const Color(0xFF8B8B8B);
    }

    return Icon(iconData, color: iconColor, size: 20);
  }

  /// Get friendly type name for display (matches System Settings format)
  String _getFriendlyTypeName(PlatformAudioDevice device) {
    if (device.isAirPlay) return 'AirPlay';
    if (device.isBluetooth) return 'Bluetooth';
    if (device.isUSB) return 'USB';
    if (device.isBuiltIn) return 'Built-in';
    if (device.transportType == 'hdmi') return 'HDMI';
    if (device.transportType == 'displayport') return 'DisplayPort';
    if (device.transportType == 'headphone') return 'Headphone port';
    // Capitalize first letter of transport type
    if (device.transportType.isNotEmpty) {
      return device.transportType[0].toUpperCase() + device.transportType.substring(1);
    }
    return 'Other';
  }
}
