// YouTube URL Resolver - Client-Side Resolution (Spotube-inspired)
//
// Resolves YouTube Music URLs to playable stream URLs directly in the Flutter app.
// NO server involved - uses user's residential IP to avoid bot detection.
//
// Architecture inspired by Spotube's approach:
// - 100% client-side resolution
// - Uses youtube_explode_dart library
// - Each user operates from their own IP (distributed by nature)
// - No central server to get banned

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeResolver {
  late final YoutubeExplode _yt;

  YouTubeResolver() {
    _yt = YoutubeExplode();
  }

  /// Resolve a YouTube Music video ID to a playable stream URL
  ///
  /// This method:
  /// 1. Uses youtube_explode_dart to extract stream manifest
  /// 2. Selects the best audio-only stream
  /// 3. Returns the direct URL for playback
  ///
  /// All resolution happens client-side using the user's residential IP.
  Future<String?> resolveStreamUrl(String videoId) async {
    try {
      print('[YouTube Resolver] Resolving video ID: $videoId');

      // Get stream manifest from YouTube
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // Get audio-only streams (sorted by bitrate, highest first)
      final audioStreams = manifest.audioOnly.sortByBitrate().reversed.toList();

      if (audioStreams.isEmpty) {
        print('[YouTube Resolver] ❌ No audio streams found for $videoId');
        return null;
      }

      // Get the best audio stream (highest bitrate)
      final bestAudio = audioStreams.first;
      final streamUrl = bestAudio.url.toString();

      print('[YouTube Resolver] ✅ Resolved successfully');
      print('[YouTube Resolver]    Codec: ${bestAudio.audioCodec}');
      print('[YouTube Resolver]    Bitrate: ${bestAudio.bitrate.kiloBitsPerSecond.toStringAsFixed(0)} kbps');
      print('[YouTube Resolver]    URL: ${streamUrl.substring(0, 80)}...');

      return streamUrl;
    } catch (e, stackTrace) {
      print('[YouTube Resolver] ❌ Failed to resolve $videoId');
      print('[YouTube Resolver]    Error: $e');
      print('[YouTube Resolver]    Stack: $stackTrace');
      return null;
    }
  }

  /// Extract video ID from various YouTube URL formats
  ///
  /// Supports:
  /// - https://music.youtube.com/watch?v=VIDEO_ID
  /// - https://www.youtube.com/watch?v=VIDEO_ID
  /// - https://youtu.be/VIDEO_ID
  /// - VIDEO_ID (direct)
  String? extractVideoId(String url) {
    try {
      // If it's already a video ID (no protocol), return it
      if (!url.contains('://') && !url.contains('/')) {
        return url;
      }

      // Try to parse as YouTube URL
      final videoId = VideoId(url);
      return videoId.value;
    } catch (e) {
      print('[YouTube Resolver] ❌ Failed to extract video ID from: $url');
      print('[YouTube Resolver]    Error: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _yt.close();
  }
}
