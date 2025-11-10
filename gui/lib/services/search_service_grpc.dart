// gRPC search service for TrustTune
//
// Provides streaming search results via gRPC with HTTP fallback.
// Uses binary protocol (Protobuf) for efficient data transfer.

import 'dart:async';
import 'package:grpc/grpc.dart';
import '../proto/search.pbgrpc.dart';
import '../proto/search.pb.dart' as pb_search;
import 'api_auth_service.dart';
import 'device_service.dart';

class SearchServiceGrpc {
  final ApiAuthService _authService;
  final DeviceService _deviceService;
  ClientChannel? _channel;
  SearchServiceClient? _client;
  final String _host;
  final int _port;
  final bool _useSecure;

  SearchServiceGrpc({
    required ApiAuthService authService,
    required DeviceService deviceService,
    required String host,
    int port = 50051,
    bool useSecure = true,
  })  : _authService = authService,
        _deviceService = deviceService,
        _host = host,
        _port = port,
        _useSecure = useSecure;

  /// Initialize gRPC channel and client
  void _ensureClient() {
    if (_channel == null) {
      _channel = ClientChannel(
        _host,
        port: _port,
        options: ChannelOptions(
          credentials: _useSecure
              ? const ChannelCredentials.secure()
              : const ChannelCredentials.insecure(),
          // Connection settings
          idleTimeout: const Duration(minutes: 5),
          connectionTimeout: const Duration(seconds: 10),
        ),
      );

      _client = SearchServiceClient(_channel!);
    }
  }

  /// Perform search with streaming results
  ///
  /// Returns a stream that emits:
  /// - Progress updates
  /// - Partial results from each adapter
  /// - Final complete result
  /// - Errors
  Stream<SearchResult> search({
    required String query,
    String? formatFilter,
    int minSeeders = 1,
    int limit = 50,
    int offset = 0,
    pb_search.SourceTypeFilter? sourceTypeFilter,
    bool useDedup = true,
    int maxResults = 30,
  }) async* {
    _ensureClient();

    try {
      // Get auth credentials
      final deviceId = await _deviceService.getDeviceId();
      final apiKey = await _authService.generateApiKey();

      // Create call options with auth metadata
      final options = CallOptions(
        metadata: {
          'device_id': deviceId,
          'api_key': apiKey,
        },
        timeout: const Duration(seconds: 30),
      );

      // Create request
      final request = pb_search.SearchRequest(
        query: query,
        formatFilter: formatFilter,
        minSeeders: minSeeders,
        limit: limit,
        offset: offset,
        sourceTypeFilter: sourceTypeFilter,
        useDedup: useDedup,
        maxResults: maxResults,
      );

      // Execute streaming RPC
      final stream = _client!.search(request, options: options);

      // Process stream responses
      await for (final response in stream) {
        switch (response.type) {
          case pb_search.ResponseType.RESPONSE_TYPE_PROGRESS:
            if (response.hasProgress()) {
              yield SearchResult.progress(
                percent: response.progress.percent,
                message: response.progress.message,
              );
            }
            break;

          case pb_search.ResponseType.RESPONSE_TYPE_PARTIAL_RESULT:
            if (response.hasPartialResult()) {
              yield SearchResult.partialResult(
                adapterName: response.partialResult.adapterName,
                sources: response.partialResult.sources
                    .map((s) => _convertSource(s))
                    .toList(),
              );
            }
            break;

          case pb_search.ResponseType.RESPONSE_TYPE_COMPLETE:
            if (response.hasCompleteResult()) {
              yield SearchResult.complete(
                totalFound: response.completeResult.totalFound,
                searchTimeMs: response.completeResult.searchTimeMs,
                rankedSources: response.completeResult.rankedSources
                    .map((r) => RankedMusicSource(
                          rank: r.rank,
                          source: _convertSource(r.source),
                          explanation: r.explanation,
                          tags: r.tags,
                        ))
                    .toList(),
              );
            }
            break;

          case pb_search.ResponseType.RESPONSE_TYPE_ERROR:
            if (response.hasError()) {
              yield SearchResult.error(
                message: response.error.message,
                details: response.error.details,
              );
            }
            break;

          default:
            break;
        }
      }
    } on GrpcError catch (e) {
      yield SearchResult.error(
        message: 'gRPC error: ${e.message}',
        details: 'Code: ${e.code}, Details: ${e.details}',
      );
    } catch (e) {
      yield SearchResult.error(
        message: 'Search failed: $e',
        details: e.toString(),
      );
    }
  }

  /// Convert protobuf MusicSource to Dart model
  MusicSource _convertSource(pb_search.MusicSource pbSource) {
    return MusicSource(
      id: pbSource.id,
      title: pbSource.title,
      url: pbSource.url,
      sourceType: _convertSourceType(pbSource.sourceType),
      format: pbSource.format.isNotEmpty ? pbSource.format : null,
      qualityScore: pbSource.qualityScore,
      indexer: pbSource.indexer,
      // Torrent fields
      magnetLink: pbSource.magnetLink.isNotEmpty ? pbSource.magnetLink : null,
      sizeBytes: pbSource.sizeBytes > 0 ? pbSource.sizeBytes.toInt() : null,
      sizeFormatted: pbSource.sizeFormatted.isNotEmpty ? pbSource.sizeFormatted : null,
      seeders: pbSource.seeders > 0 ? pbSource.seeders : null,
      leechers: pbSource.leechers > 0 ? pbSource.leechers : null,
      // Streaming fields
      codec: pbSource.codec.isNotEmpty ? pbSource.codec : null,
      bitrate: pbSource.bitrate.isNotEmpty ? pbSource.bitrate : null,
      thumbnailUrl: pbSource.thumbnailUrl.isNotEmpty ? pbSource.thumbnailUrl : null,
      durationSeconds: pbSource.durationSeconds > 0 ? pbSource.durationSeconds : null,
    );
  }

  String _convertSourceType(pb_search.SourceType pbType) {
    switch (pbType) {
      case pb_search.SourceType.SOURCE_TYPE_TORRENT:
        return 'torrent';
      case pb_search.SourceType.SOURCE_TYPE_YOUTUBE:
        return 'youtube';
      case pb_search.SourceType.SOURCE_TYPE_PIPED:
        return 'piped';
      case pb_search.SourceType.SOURCE_TYPE_INVIDIOUS:
        return 'invidious';
      default:
        return 'unknown';
    }
  }

  /// Close the gRPC channel
  Future<void> close() async {
    await _channel?.shutdown();
    _channel = null;
    _client = null;
  }
}

// Data models

class SearchResult {
  final SearchResultType type;
  final ProgressData? progress;
  final PartialResultData? partialResult;
  final CompleteResultData? completeResult;
  final ErrorData? error;

  SearchResult.progress({
    required int percent,
    required String message,
  })  : type = SearchResultType.progress,
        progress = ProgressData(percent: percent, message: message),
        partialResult = null,
        completeResult = null,
        error = null;

  SearchResult.partialResult({
    required String adapterName,
    required List<MusicSource> sources,
  })  : type = SearchResultType.partialResult,
        progress = null,
        partialResult = PartialResultData(adapterName: adapterName, sources: sources),
        completeResult = null,
        error = null;

  SearchResult.complete({
    required int totalFound,
    required int searchTimeMs,
    required List<RankedMusicSource> rankedSources,
  })  : type = SearchResultType.complete,
        progress = null,
        partialResult = null,
        completeResult = CompleteResultData(
          totalFound: totalFound,
          searchTimeMs: searchTimeMs,
          rankedSources: rankedSources,
        ),
        error = null;

  SearchResult.error({
    required String message,
    String? details,
  })  : type = SearchResultType.error,
        progress = null,
        partialResult = null,
        completeResult = null,
        error = ErrorData(message: message, details: details);
}

enum SearchResultType { progress, partialResult, complete, error }

class ProgressData {
  final int percent;
  final String message;
  ProgressData({required this.percent, required this.message});
}

class PartialResultData {
  final String adapterName;
  final List<MusicSource> sources;
  PartialResultData({required this.adapterName, required this.sources});
}

class CompleteResultData {
  final int totalFound;
  final int searchTimeMs;
  final List<RankedMusicSource> rankedSources;
  CompleteResultData({
    required this.totalFound,
    required this.searchTimeMs,
    required this.rankedSources,
  });
}

class ErrorData {
  final String message;
  final String? details;
  ErrorData({required this.message, this.details});
}

class MusicSource {
  final String id;
  final String title;
  final String url;
  final String sourceType;
  final String? format;
  final double qualityScore;
  final String indexer;
  // Torrent fields
  final String? magnetLink;
  final int? sizeBytes;
  final String? sizeFormatted;
  final int? seeders;
  final int? leechers;
  // Streaming fields
  final String? codec;
  final String? bitrate;
  final String? thumbnailUrl;
  final int? durationSeconds;

  MusicSource({
    required this.id,
    required this.title,
    required this.url,
    required this.sourceType,
    this.format,
    required this.qualityScore,
    required this.indexer,
    this.magnetLink,
    this.sizeBytes,
    this.sizeFormatted,
    this.seeders,
    this.leechers,
    this.codec,
    this.bitrate,
    this.thumbnailUrl,
    this.durationSeconds,
  });
}

class RankedMusicSource {
  final int rank;
  final MusicSource source;
  final String explanation;
  final List<String> tags;

  RankedMusicSource({
    required this.rank,
    required this.source,
    required this.explanation,
    required this.tags,
  });
}
