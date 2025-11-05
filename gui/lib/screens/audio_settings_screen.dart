import 'package:flutter/material.dart';
import '../services/audio_device_service.dart';
import '../services/platform/audio_device_platform.dart';
import '../services/app_settings.dart';
import 'dart:io';

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

  @override
  void initState() {
    super.initState();
    _initialize();

    // Listen to AudioDeviceService changes (e.g., when headphones plugged in)
    _audioService.addListener(_onAudioDeviceChanged);
  }

  /// Called when AudioDeviceService notifies of device changes
  /// This happens when:
  /// - User plugs/unplugs headphones
  /// - macOS changes system default device
  /// - User manually selects device
  void _onAudioDeviceChanged() {
    print('[AudioSettings] Audio device changed, updating UI...');

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
        });

        // Reload exclusive mode state and metadata for new device
        _loadExclusiveModeState(matchingPlatformDevice);
      }

      print('[AudioSettings] ✓ UI updated to show: ${matchingPlatformDevice.name}');
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
    }
  }

  Future<void> _loadExclusiveModeState(PlatformAudioDevice device) async {
    // Only check exclusive mode on macOS for now
    if (!Platform.isMacOS) return;

    setState(() {
      _loadingMetadata = true;
    });

    // Use the platform device ID for CoreAudio methods
    final deviceId = device.id;

    // Check if current device supports exclusive mode
    final supported = await _audioService.platform.supportsExclusiveMode(deviceId);

    // Get current device format
    final format = await _audioService.platform.getDeviceFormat(deviceId);

    // Get device metadata (Phase 3)
    final metadata = await _audioService.platform.getDeviceMetadata(deviceId);

    if (mounted) {
      setState(() {
        _exclusiveModeSupported = supported;
        _deviceFormat = format;
        _deviceMetadata = metadata;
        _loadingMetadata = false;
      });
    }
  }

  Future<void> _toggleExclusiveMode(bool enable) async {
    if (_selectedPlatformDevice == null) return;

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
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Audio Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          _buildSectionHeader('🎵 Audiophile Settings', 'High-quality audio output configuration'),
          const SizedBox(height: 32),

          // Device Selection Section
          _buildDeviceSelectionSection(),
          const SizedBox(height: 32),

          // Exclusive Mode Section (Phase 2)
          if (Platform.isMacOS) ...[
            _buildExclusiveModeSection(),
            const SizedBox(height: 32),
          ],

          // Device Format Section
          _buildDeviceFormatSection(),
          const SizedBox(height: 32),

          // Phase 3 - Advanced Metadata
          if (Platform.isMacOS) ...[
            _buildAdvancedMetadata(),
          ],
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
                  child: Text(
                    'No audio devices found',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
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
                            child: Text(
                              device.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (device.isBluetooth)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A84FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'BT',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
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
                      final mediaKitDevice = _audioService.availableDevices.firstWhere(
                        (d) => d.description == platformDevice.name,
                        orElse: () => _audioService.availableDevices.first,
                      );
                      await _audioService.selectDevice(mediaKitDevice);

                      await _loadExclusiveModeState(platformDevice); // Reload for new device
                    }
                  },
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
                  onChanged: _exclusiveModeSupported ? _toggleExclusiveMode : null,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            'Exclusive mode provides bit-perfect audio by taking exclusive control of the device. '
            'Other applications cannot use this device while exclusive mode is active.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.5,
            ),
          ),

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
                      'Exclusive mode not supported on this device',
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
              'Select a device to view advanced metadata',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
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
}
