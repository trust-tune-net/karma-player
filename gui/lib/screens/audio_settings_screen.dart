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

  bool _exclusiveModeEnabled = false;
  bool _exclusiveModeSupported = false;
  bool _loadingExclusiveMode = false;
  Map<String, dynamic>? _deviceFormat;

  @override
  void initState() {
    super.initState();
    _loadExclusiveModeState();
  }

  Future<void> _loadExclusiveModeState() async {
    // Only check exclusive mode on macOS for now
    if (!Platform.isMacOS) return;

    final selectedDevice = _audioService.selectedDevice;
    if (selectedDevice == null) return;

    // Check if current device supports exclusive mode
    final supported = await _audioService.platform.supportsExclusiveMode(selectedDevice.name);

    // Get current device format
    final format = await _audioService.platform.getDeviceFormat(selectedDevice.name);

    if (mounted) {
      setState(() {
        _exclusiveModeSupported = supported;
        _deviceFormat = format;
      });
    }
  }

  Future<void> _toggleExclusiveMode(bool enable) async {
    final selectedDevice = _audioService.selectedDevice;
    if (selectedDevice == null) return;

    setState(() {
      _loadingExclusiveMode = true;
    });

    try {
      final success = await _audioService.platform.enableExclusiveMode(
        selectedDevice.name,
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

          // Phase 3 Placeholders (will be implemented later)
          _buildMetadataPlaceholder(),
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
              final selectedDevice = _audioService.selectedDevice;
              final devices = _audioService.availableDevices;

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
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedDevice?.name ?? 'auto',
                  dropdownColor: const Color(0xFF1A1A1A),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF9D4EDD)),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: devices.map((device) {
                    final deviceType = _audioService.getDeviceType(device);
                    return DropdownMenuItem<String>(
                      value: device.name,
                      child: Row(
                        children: [
                          _getDeviceIcon(deviceType),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _audioService.getFriendlyName(device),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (deviceType == AudioDeviceType.bluetooth)
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
                      // Find the device object by name
                      final device = devices.firstWhere((d) => d.name == value);
                      await _audioService.selectDevice(device);
                      await _loadExclusiveModeState(); // Reload for new device
                    }
                  },
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

  Widget _buildMetadataPlaceholder() {
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
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Coming in Phase 3:\n'
            '• USB DAC chipset detection (ESS, AKM, etc.)\n'
            '• Bluetooth codec info (AAC, aptX, LDAC)\n'
            '• Supported sample rates\n'
            '• Device capabilities',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              height: 1.8,
            ),
          ),
        ],
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
