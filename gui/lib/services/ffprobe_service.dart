import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// Service for extracting EXACT audio quality metadata using FFprobe
/// Reads actual audio stream headers for audiophile-grade accuracy
class FFprobeService {
  // Cache FFprobe results to avoid repeated calls
  final Map<String, AudioStreamInfo> _cache = {};
  
  // Cache FFprobe version globally (shared across all instances)
  static String? _cachedFfprobeVersion;

  /// Get path to FFprobe binary (bundled or system)
  String get ffprobePath {
    if (Platform.isMacOS) {
      // Check for bundled binary first (in app Resources)
      final bundledPath = path.join(
        path.dirname(Platform.resolvedExecutable),
        '../Resources/bin/ffprobe',
      );
      if (File(bundledPath).existsSync()) {
        return bundledPath;
      }
      
      // Fallback to Homebrew
      if (File('/opt/homebrew/bin/ffprobe').existsSync()) {
        return '/opt/homebrew/bin/ffprobe';
      }
      if (File('/usr/local/bin/ffprobe').existsSync()) {
        return '/usr/local/bin/ffprobe';
      }
    } else if (Platform.isLinux) {
      // Check for bundled binary
      final bundledPath = path.join(
        path.dirname(Platform.resolvedExecutable),
        'data/flutter_assets/assets/bin/ffprobe',
      );
      if (File(bundledPath).existsSync()) {
        return bundledPath;
      }
      
      // Fallback to system path
      return 'ffprobe';
    } else if (Platform.isWindows) {
      // Check for bundled binary
      final bundledPath = path.join(
        path.dirname(Platform.resolvedExecutable),
        'data/flutter_assets/assets/bin/ffprobe.exe',
      );
      if (File(bundledPath).existsSync()) {
        return bundledPath;
      }
      
      // Fallback to system path
      return 'ffprobe.exe';
    }
    
    return 'ffprobe';
  }

  /// Extract EXACT audio quality information from file
  Future<AudioStreamInfo> extractAudioInfo(String filePath) async {
    // Check cache first
    if (_cache.containsKey(filePath)) {
      _log('[FFprobe] Cache hit for: ${path.basename(filePath)}');
      return _cache[filePath]!;
    }

    try {
      _log('[FFprobe] Extracting audio info from: ${path.basename(filePath)}');
      
      // Execute FFprobe with JSON output
      final result = await Process.run(
        ffprobePath,
        [
          '-v', 'quiet',           // Suppress non-essential output
          '-print_format', 'json',  // Output as JSON
          '-show_streams',          // Show stream information
          '-select_streams', 'a:0', // Select first audio stream only
          filePath,
        ],
        runInShell: false,
      );

      if (result.exitCode != 0) {
        _log('[FFprobe] ERROR: FFprobe failed with exit code ${result.exitCode}');
        _log('[FFprobe] stderr: ${result.stderr}');
        throw Exception('FFprobe failed: ${result.stderr}');
      }

      // Parse JSON output
      final jsonOutput = result.stdout as String;
      final audioInfo = _parseFFprobeOutput(jsonOutput, filePath);
      
      // Add raw JSON and version to the result
      final enrichedInfo = AudioStreamInfo(
        bitrate: audioInfo.bitrate,
        sampleRate: audioInfo.sampleRate,
        bitDepth: audioInfo.bitDepth,
        codec: audioInfo.codec,
        channels: audioInfo.channels,
        channelLayout: audioInfo.channelLayout,
        codecLongName: audioInfo.codecLongName,
        duration: audioInfo.duration,
        rawJson: jsonOutput,
        ffprobeVersion: _cachedFfprobeVersion,
        isEstimated: false,
      );
      
      // Cache result
      _cache[filePath] = enrichedInfo;
      
      _log('[FFprobe] ✓ Bitrate: ${enrichedInfo.bitrate ?? "N/A"} kbps');
      _log('[FFprobe] ✓ Sample Rate: ${enrichedInfo.sampleRate ?? "N/A"} Hz');
      _log('[FFprobe] ✓ Bit Depth: ${enrichedInfo.bitDepth ?? "N/A"} bit');
      _log('[FFprobe] ✓ Codec: ${enrichedInfo.codec ?? "N/A"}');
      
      return enrichedInfo;
    } catch (e) {
      _log('[FFprobe] ERROR: Failed to extract audio info: $e');
      rethrow;
    }
  }

  /// Parse FFprobe JSON output
  AudioStreamInfo _parseFFprobeOutput(String jsonOutput, String filePath) {
    try {
      final data = json.decode(jsonOutput) as Map<String, dynamic>;
      final streams = data['streams'] as List<dynamic>?;
      
      if (streams == null || streams.isEmpty) {
        throw Exception('No audio streams found');
      }

      final audioStream = streams[0] as Map<String, dynamic>;
      
      // Extract sample rate
      int? sampleRate;
      if (audioStream.containsKey('sample_rate')) {
        final sampleRateStr = audioStream['sample_rate'].toString();
        sampleRate = int.tryParse(sampleRateStr);
      }

      // Extract bit depth (FLAC files need special handling)
      int? bitDepth;
      
      // First try bits_per_sample
      if (audioStream.containsKey('bits_per_sample')) {
        final bitsPerSampleStr = audioStream['bits_per_sample'].toString();
        bitDepth = int.tryParse(bitsPerSampleStr);
      }
      
      // Fallback 1: For FLAC files, bits_per_sample is often 0, use bits_per_raw_sample
      if (bitDepth == null || bitDepth == 0) {
        if (audioStream.containsKey('bits_per_raw_sample')) {
          final bitsPerRawSampleStr = audioStream['bits_per_raw_sample'].toString();
          bitDepth = int.tryParse(bitsPerRawSampleStr);
        }
      }
      
      // Fallback 2: Parse from sample_fmt (s16, s24, s32, etc.)
      if (bitDepth == null || bitDepth == 0) {
        final sampleFmt = audioStream['sample_fmt']?.toString() ?? '';
        if (sampleFmt.startsWith('s') && sampleFmt.length > 1) {
          bitDepth = int.tryParse(sampleFmt.substring(1));
        }
      }

      // Extract bitrate (in bits per second, convert to kbps)
      int? bitrate;
      if (audioStream.containsKey('bit_rate')) {
        final bitrateStr = audioStream['bit_rate'].toString();
        final bitrateBps = int.tryParse(bitrateStr);
        if (bitrateBps != null) {
          bitrate = (bitrateBps / 1000).round();
        }
      }

      // Extract codec
      String? codec = audioStream['codec_name'] as String?;
      String? codecLongName = audioStream['codec_long_name'] as String?;
      
      // Extract channels
      int? channels = audioStream['channels'] as int?;
      String? channelLayout = audioStream['channel_layout'] as String?;
      
      // Extract duration
      double? duration;
      if (audioStream.containsKey('duration')) {
        final durationStr = audioStream['duration'].toString();
        duration = double.tryParse(durationStr);
      }

      return AudioStreamInfo(
        bitrate: bitrate,
        sampleRate: sampleRate,
        bitDepth: bitDepth,
        codec: codec?.toUpperCase(),
        channels: channels,
        channelLayout: channelLayout,
        codecLongName: codecLongName,
        duration: duration,
        isEstimated: false, // This is EXACT data from FFprobe!
      );
    } catch (e) {
      _log('[FFprobe] ERROR parsing JSON: $e');
      throw Exception('Failed to parse FFprobe output: $e');
    }
  }

  /// Verify FFprobe is available and working
  Future<bool> verifyFFprobe() async {
    try {
      _log('[FFprobe] Verifying FFprobe binary...');
      _log('[FFprobe] Path: $ffprobePath');
      
      final result = await Process.run(
        ffprobePath,
        ['-version'],
        runInShell: false,
      );

      if (result.exitCode == 0) {
        final versionOutput = (result.stdout as String).split('\n').first;
        _log('[FFprobe] ✓ FFprobe available: $versionOutput');
        
        // Extract version number (e.g., "ffprobe version 7.1" -> "7.1")
        final versionMatch = RegExp(r'ffprobe version (\S+)').firstMatch(versionOutput);
        if (versionMatch != null) {
          _cachedFfprobeVersion = versionMatch.group(1);
        }
        
        return true;
      } else {
        _log('[FFprobe] ⚠️  FFprobe verification failed');
        return false;
      }
    } catch (e) {
      _log('[FFprobe] ⚠️  FFprobe not found: $e');
      return false;
    }
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
    _log('[FFprobe] Cache cleared');
  }

  /// Log to both console and file
  static void _log(String message) {
    print(message);
    
    // Also write to /tmp/log/karmaplayer.log
    try {
      final logDir = Directory('/tmp/log');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      
      final logFile = File('/tmp/log/karmaplayer.log');
      final timestamp = DateTime.now().toIso8601String();
      logFile.writeAsStringSync(
        '[$timestamp] $message\n',
        mode: FileMode.append,
      );
    } catch (e) {
      // Silently fail if logging to file doesn't work
      print('[FFprobe] Failed to write to log file: $e');
    }
  }
}

/// Audio stream information extracted from FFprobe
class AudioStreamInfo {
  final int? bitrate;      // in kbps
  final int? sampleRate;   // in Hz (44100, 48000, 96000, 192000, etc.)
  final int? bitDepth;     // 16, 24, 32
  final String? codec;     // FLAC, MP3, AAC, ALAC, etc.
  final int? channels;     // 2 for stereo, 6 for 5.1, etc.
  final String? channelLayout;  // "stereo", "5.1", "7.1(side)"
  final String? codecLongName;  // "FLAC (Free Lossless Audio Codec)"
  final double? duration;       // in seconds
  final String? rawJson;        // Raw FFprobe JSON output (for power users)
  final String? ffprobeVersion; // FFprobe version (e.g., "7.1")
  final bool isEstimated;  // false = exact from FFprobe, true = estimated

  AudioStreamInfo({
    this.bitrate,
    this.sampleRate,
    this.bitDepth,
    this.codec,
    this.channels,
    this.channelLayout,
    this.codecLongName,
    this.duration,
    this.rawJson,
    this.ffprobeVersion,
    required this.isEstimated,
  });

  @override
  String toString() {
    return 'AudioStreamInfo(bitrate: $bitrate kbps, sampleRate: $sampleRate Hz, '
           'bitDepth: $bitDepth bit, codec: $codec, channels: $channels, '
           'isEstimated: $isEstimated)';
  }
}

