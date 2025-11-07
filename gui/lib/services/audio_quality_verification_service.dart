import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'ffprobe_service.dart';

/// Service for verifying audio quality using FFprobe
/// Compares claimed quality from torrent titles vs actual file quality
class AudioQualityVerificationService {
  final FFprobeService _ffprobe = FFprobeService();

  /// Verify audio quality by analyzing a file
  /// If filePath is provided, uses it directly. Otherwise shows file picker.
  Future<void> verifyAudioQuality(
    BuildContext context,
    Map<String, dynamic> source, {
    String? filePath,
  }) async {
    try {
      String actualFilePath;
      String fileName;

      if (filePath != null) {
        // Use provided file path (e.g., from currently playing song)
        actualFilePath = filePath;
        fileName = path.basename(filePath);
      } else {
        // Show file picker to select downloaded audio file
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['flac', 'mp3', 'aac', 'm4a', 'wav', 'ogg', 'opus', 'wma'],
          dialogTitle: 'Select downloaded audio file to verify',
        );

        if (result == null || result.files.single.path == null) {
          return; // User canceled
        }

        actualFilePath = result.files.single.path!;
        fileName = path.basename(actualFilePath);
      }

      // Show loading dialog
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Analyzing audio quality...'),
            ],
          ),
        ),
      );

      // Analyze file using FFprobe
      final audioInfo = await _ffprobe.extractAudioInfo(actualFilePath);

      // Close loading dialog
      if (!context.mounted) return;
      Navigator.of(context).pop();

      // Build verification result
      final verificationResult = _buildVerificationResult(source, audioInfo, fileName);

      // Show verification dialog
      if (!context.mounted) return;
      _showVerificationDialog(context, verificationResult);
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying audio quality: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      print('Verification error: $e');
    }
  }

  /// Build verification result by comparing claimed vs actual quality
  VerificationResult _buildVerificationResult(
    Map<String, dynamic> source,
    AudioStreamInfo audioInfo,
    String fileName,
  ) {
    // Extract claimed quality from torrent title
    final claimedFormat = source['format']?.toString().toUpperCase() ?? 'UNKNOWN';
    final claimedBitrate = source['bitrate']?.toString();

    // Determine quality level from verified data
    String qualityLevel = 'Unknown';
    if (audioInfo.codec != null) {
      final codec = audioInfo.codec!.toUpperCase();
      if (['FLAC', 'ALAC', 'APE', 'WAV', 'AIFF'].contains(codec)) {
        if ((audioInfo.sampleRate ?? 0) >= 88200 || (audioInfo.bitDepth ?? 0) >= 24) {
          qualityLevel = 'Hi-Res';
        } else if ((audioInfo.sampleRate ?? 0) >= 44100 && (audioInfo.bitDepth ?? 0) >= 16) {
          qualityLevel = 'CD Quality';
        } else {
          qualityLevel = 'Lossless';
        }
      } else {
        final bitrate = audioInfo.bitrate ?? 0;
        if (bitrate >= 320) qualityLevel = 'Lossy (320kbps)';
        else if (bitrate >= 256) qualityLevel = 'Lossy (256kbps)';
        else if (bitrate >= 192) qualityLevel = 'Lossy (192kbps)';
        else if (bitrate >= 128) qualityLevel = 'Lossy (128kbps)';
        else qualityLevel = 'Lossy (Low)';
      }
    }

    // Check if misleading (claimed FLAC but not lossless, or claimed bitrate mismatch)
    bool isMisleading = false;
    if (claimedFormat == 'FLAC' && audioInfo.codec != null) {
      final actualCodec = audioInfo.codec!.toUpperCase();
      if (!['FLAC', 'ALAC', 'APE', 'WAV', 'AIFF'].contains(actualCodec)) {
        isMisleading = true; // Claimed FLAC but actually lossy
      }
    }

    // Check bitrate mismatch for lossy files
    if (claimedBitrate != null && audioInfo.bitrate != null) {
      final claimedKbps = int.tryParse(claimedBitrate);
      final actualKbps = audioInfo.bitrate!;
      if (claimedKbps != null && (claimedKbps - actualKbps).abs() > 10) {
        isMisleading = true; // Significant bitrate mismatch
      }
    }

    return VerificationResult(
      fileName: fileName,
      audioInfo: audioInfo,
      qualityLevel: qualityLevel,
      isMisleading: isMisleading,
      claimedFormat: claimedFormat,
      claimedBitrate: claimedBitrate,
    );
  }

  /// Show verification dialog with results
  void _showVerificationDialog(BuildContext context, VerificationResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified, color: Color(0xFFA855F7), size: 28),
            const SizedBox(width: 12),
            const Text('Audio Quality Verified'),
            if (result.isMisleading) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Text(
                  'MISLEADING',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // File info
                Text(
                  result.fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 20),

                // Quality Level Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA855F7), width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Color(0xFFA855F7)),
                      const SizedBox(width: 12),
                      Text(
                        result.qualityLevel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFA855F7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Verified Details
                const Text(
                  'Verified Quality:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Format', result.audioInfo.codec?.toUpperCase() ?? 'Unknown'),
                if (result.audioInfo.bitDepth != null)
                  _buildDetailRow('Bit Depth', '${result.audioInfo.bitDepth}-bit'),
                if (result.audioInfo.sampleRate != null)
                  _buildDetailRow('Sample Rate', '${(result.audioInfo.sampleRate! / 1000).toStringAsFixed(1)} kHz'),
                if (result.audioInfo.bitrate != null)
                  _buildDetailRow('Bitrate', '${result.audioInfo.bitrate} kbps'),
                if (result.audioInfo.channels != null)
                  _buildDetailRow('Channels', '${result.audioInfo.channels} (${result.audioInfo.channelLayout ?? 'unknown'})'),
                if (result.audioInfo.duration != null)
                  _buildDetailRow('Duration', _formatDuration(result.audioInfo.duration!)),

                if (result.isMisleading) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Quality Mismatch Detected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Claimed: ${result.claimedFormat}${result.claimedBitrate != null ? ' ${result.claimedBitrate} kbps' : ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          'Actual: ${result.audioInfo.codec?.toUpperCase() ?? 'Unknown'}${result.audioInfo.bitrate != null ? ' ${result.audioInfo.bitrate} kbps' : ''}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds.remainder(60);
    return '${minutes}:${secs.toString().padLeft(2, '0')}';
  }
}

/// Verification result data class
class VerificationResult {
  final String fileName;
  final AudioStreamInfo audioInfo;
  final String qualityLevel;
  final bool isMisleading;
  final String claimedFormat;
  final String? claimedBitrate;

  VerificationResult({
    required this.fileName,
    required this.audioInfo,
    required this.qualityLevel,
    required this.isMisleading,
    required this.claimedFormat,
    this.claimedBitrate,
  });
}
