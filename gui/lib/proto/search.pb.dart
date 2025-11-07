// This is a generated file - do not edit.
//
// Generated from search.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pb.dart' as $1;
import 'search.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'search.pbenum.dart';

/// Search request
class SearchRequest extends $pb.GeneratedMessage {
  factory SearchRequest({
    $core.String? query,
    $core.String? formatFilter,
    $core.int? minSeeders,
    $core.int? limit,
    $core.int? offset,
    $core.String? artist,
    $core.String? album,
    $core.int? minBitrate,
    $core.int? maxSizeMb,
    SourceTypeFilter? sourceTypeFilter,
  }) {
    final result = create();
    if (query != null) result.query = query;
    if (formatFilter != null) result.formatFilter = formatFilter;
    if (minSeeders != null) result.minSeeders = minSeeders;
    if (limit != null) result.limit = limit;
    if (offset != null) result.offset = offset;
    if (artist != null) result.artist = artist;
    if (album != null) result.album = album;
    if (minBitrate != null) result.minBitrate = minBitrate;
    if (maxSizeMb != null) result.maxSizeMb = maxSizeMb;
    if (sourceTypeFilter != null) result.sourceTypeFilter = sourceTypeFilter;
    return result;
  }

  SearchRequest._();

  factory SearchRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.search'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'query')
    ..aOS(2, _omitFieldNames ? '' : 'formatFilter')
    ..aI(3, _omitFieldNames ? '' : 'minSeeders')
    ..aI(4, _omitFieldNames ? '' : 'limit')
    ..aI(5, _omitFieldNames ? '' : 'offset')
    ..aOS(6, _omitFieldNames ? '' : 'artist')
    ..aOS(7, _omitFieldNames ? '' : 'album')
    ..aI(8, _omitFieldNames ? '' : 'minBitrate')
    ..aI(9, _omitFieldNames ? '' : 'maxSizeMb')
    ..aE<SourceTypeFilter>(10, _omitFieldNames ? '' : 'sourceTypeFilter',
        enumValues: SourceTypeFilter.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchRequest copyWith(void Function(SearchRequest) updates) =>
      super.copyWith((message) => updates(message as SearchRequest))
          as SearchRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchRequest create() => SearchRequest._();
  @$core.override
  SearchRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchRequest>(create);
  static SearchRequest? _defaultInstance;

  /// Search parameters
  @$pb.TagNumber(1)
  $core.String get query => $_getSZ(0);
  @$pb.TagNumber(1)
  set query($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuery() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuery() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get formatFilter => $_getSZ(1);
  @$pb.TagNumber(2)
  set formatFilter($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFormatFilter() => $_has(1);
  @$pb.TagNumber(2)
  void clearFormatFilter() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get minSeeders => $_getIZ(2);
  @$pb.TagNumber(3)
  set minSeeders($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMinSeeders() => $_has(2);
  @$pb.TagNumber(3)
  void clearMinSeeders() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get limit => $_getIZ(3);
  @$pb.TagNumber(4)
  set limit($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLimit() => $_has(3);
  @$pb.TagNumber(4)
  void clearLimit() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get offset => $_getIZ(4);
  @$pb.TagNumber(5)
  set offset($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOffset() => $_has(4);
  @$pb.TagNumber(5)
  void clearOffset() => $_clearField(5);

  /// Filters
  @$pb.TagNumber(6)
  $core.String get artist => $_getSZ(5);
  @$pb.TagNumber(6)
  set artist($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasArtist() => $_has(5);
  @$pb.TagNumber(6)
  void clearArtist() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get album => $_getSZ(6);
  @$pb.TagNumber(7)
  set album($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAlbum() => $_has(6);
  @$pb.TagNumber(7)
  void clearAlbum() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get minBitrate => $_getIZ(7);
  @$pb.TagNumber(8)
  set minBitrate($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMinBitrate() => $_has(7);
  @$pb.TagNumber(8)
  void clearMinBitrate() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get maxSizeMb => $_getIZ(8);
  @$pb.TagNumber(9)
  set maxSizeMb($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMaxSizeMb() => $_has(8);
  @$pb.TagNumber(9)
  void clearMaxSizeMb() => $_clearField(9);

  @$pb.TagNumber(10)
  SourceTypeFilter get sourceTypeFilter => $_getN(9);
  @$pb.TagNumber(10)
  set sourceTypeFilter(SourceTypeFilter value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasSourceTypeFilter() => $_has(9);
  @$pb.TagNumber(10)
  void clearSourceTypeFilter() => $_clearField(10);
}

/// Search response (streamed)
class SearchResponse extends $pb.GeneratedMessage {
  factory SearchResponse({
    ResponseType? type,
    ProgressUpdate? progress,
    PartialResult? partialResult,
    CompleteResult? completeResult,
    $1.Error? error,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (progress != null) result.progress = progress;
    if (partialResult != null) result.partialResult = partialResult;
    if (completeResult != null) result.completeResult = completeResult;
    if (error != null) result.error = error;
    return result;
  }

  SearchResponse._();

  factory SearchResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.search'),
      createEmptyInstance: create)
    ..aE<ResponseType>(1, _omitFieldNames ? '' : 'type',
        enumValues: ResponseType.values)
    ..aOM<ProgressUpdate>(2, _omitFieldNames ? '' : 'progress',
        subBuilder: ProgressUpdate.create)
    ..aOM<PartialResult>(3, _omitFieldNames ? '' : 'partialResult',
        subBuilder: PartialResult.create)
    ..aOM<CompleteResult>(4, _omitFieldNames ? '' : 'completeResult',
        subBuilder: CompleteResult.create)
    ..aOM<$1.Error>(5, _omitFieldNames ? '' : 'error',
        subBuilder: $1.Error.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchResponse copyWith(void Function(SearchResponse) updates) =>
      super.copyWith((message) => updates(message as SearchResponse))
          as SearchResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchResponse create() => SearchResponse._();
  @$core.override
  SearchResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchResponse>(create);
  static SearchResponse? _defaultInstance;

  /// Response type
  @$pb.TagNumber(1)
  ResponseType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(ResponseType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  /// Progress update
  @$pb.TagNumber(2)
  ProgressUpdate get progress => $_getN(1);
  @$pb.TagNumber(2)
  set progress(ProgressUpdate value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProgress() => $_has(1);
  @$pb.TagNumber(2)
  void clearProgress() => $_clearField(2);
  @$pb.TagNumber(2)
  ProgressUpdate ensureProgress() => $_ensure(1);

  /// Partial results from a specific adapter
  @$pb.TagNumber(3)
  PartialResult get partialResult => $_getN(2);
  @$pb.TagNumber(3)
  set partialResult(PartialResult value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPartialResult() => $_has(2);
  @$pb.TagNumber(3)
  void clearPartialResult() => $_clearField(3);
  @$pb.TagNumber(3)
  PartialResult ensurePartialResult() => $_ensure(2);

  /// Final complete result
  @$pb.TagNumber(4)
  CompleteResult get completeResult => $_getN(3);
  @$pb.TagNumber(4)
  set completeResult(CompleteResult value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCompleteResult() => $_has(3);
  @$pb.TagNumber(4)
  void clearCompleteResult() => $_clearField(4);
  @$pb.TagNumber(4)
  CompleteResult ensureCompleteResult() => $_ensure(3);

  /// Error
  @$pb.TagNumber(5)
  $1.Error get error => $_getN(4);
  @$pb.TagNumber(5)
  set error($1.Error value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasError() => $_has(4);
  @$pb.TagNumber(5)
  void clearError() => $_clearField(5);
  @$pb.TagNumber(5)
  $1.Error ensureError() => $_ensure(4);
}

/// Progress update during search
class ProgressUpdate extends $pb.GeneratedMessage {
  factory ProgressUpdate({
    $core.int? percent,
    $core.String? message,
  }) {
    final result = create();
    if (percent != null) result.percent = percent;
    if (message != null) result.message = message;
    return result;
  }

  ProgressUpdate._();

  factory ProgressUpdate.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProgressUpdate.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProgressUpdate',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.search'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'percent')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressUpdate clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProgressUpdate copyWith(void Function(ProgressUpdate) updates) =>
      super.copyWith((message) => updates(message as ProgressUpdate))
          as ProgressUpdate;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProgressUpdate create() => ProgressUpdate._();
  @$core.override
  ProgressUpdate createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProgressUpdate getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProgressUpdate>(create);
  static ProgressUpdate? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get percent => $_getIZ(0);
  @$pb.TagNumber(1)
  set percent($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPercent() => $_has(0);
  @$pb.TagNumber(1)
  void clearPercent() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

/// Partial results from one adapter
class PartialResult extends $pb.GeneratedMessage {
  factory PartialResult({
    $core.String? adapterName,
    $core.int? count,
    $core.Iterable<MusicSource>? sources,
  }) {
    final result = create();
    if (adapterName != null) result.adapterName = adapterName;
    if (count != null) result.count = count;
    if (sources != null) result.sources.addAll(sources);
    return result;
  }

  PartialResult._();

  factory PartialResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PartialResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PartialResult',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.search'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'adapterName')
    ..aI(2, _omitFieldNames ? '' : 'count')
    ..pPM<MusicSource>(3, _omitFieldNames ? '' : 'sources',
        subBuilder: MusicSource.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PartialResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PartialResult copyWith(void Function(PartialResult) updates) =>
      super.copyWith((message) => updates(message as PartialResult))
          as PartialResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PartialResult create() => PartialResult._();
  @$core.override
  PartialResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PartialResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PartialResult>(create);
  static PartialResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get adapterName => $_getSZ(0);
  @$pb.TagNumber(1)
  set adapterName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAdapterName() => $_has(0);
  @$pb.TagNumber(1)
  void clearAdapterName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get count => $_getIZ(1);
  @$pb.TagNumber(2)
  set count($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<MusicSource> get sources => $_getList(2);
}

/// Final complete result
class CompleteResult extends $pb.GeneratedMessage {
  factory CompleteResult({
    $core.int? totalFound,
    $core.int? searchTimeMs,
    $core.Iterable<RankedSource>? rankedSources,
  }) {
    final result = create();
    if (totalFound != null) result.totalFound = totalFound;
    if (searchTimeMs != null) result.searchTimeMs = searchTimeMs;
    if (rankedSources != null) result.rankedSources.addAll(rankedSources);
    return result;
  }

  CompleteResult._();

  factory CompleteResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompleteResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompleteResult',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.search'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'totalFound')
    ..aI(2, _omitFieldNames ? '' : 'searchTimeMs')
    ..pPM<RankedSource>(3, _omitFieldNames ? '' : 'rankedSources',
        subBuilder: RankedSource.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteResult copyWith(void Function(CompleteResult) updates) =>
      super.copyWith((message) => updates(message as CompleteResult))
          as CompleteResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompleteResult create() => CompleteResult._();
  @$core.override
  CompleteResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompleteResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompleteResult>(create);
  static CompleteResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get totalFound => $_getIZ(0);
  @$pb.TagNumber(1)
  set totalFound($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTotalFound() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotalFound() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get searchTimeMs => $_getIZ(1);
  @$pb.TagNumber(2)
  set searchTimeMs($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSearchTimeMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearSearchTimeMs() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<RankedSource> get rankedSources => $_getList(2);
}

/// Music source (torrent or streaming)
class MusicSource extends $pb.GeneratedMessage {
  factory MusicSource({
    $core.String? id,
    $core.String? title,
    $core.String? url,
    SourceType? sourceType,
    $core.String? format,
    $core.double? qualityScore,
    $core.String? indexer,
    $core.String? magnetLink,
    $fixnum.Int64? sizeBytes,
    $core.String? sizeFormatted,
    $core.int? seeders,
    $core.int? leechers,
    $core.String? codec,
    $core.String? bitrate,
    $core.String? thumbnailUrl,
    $core.int? durationSeconds,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (url != null) result.url = url;
    if (sourceType != null) result.sourceType = sourceType;
    if (format != null) result.format = format;
    if (qualityScore != null) result.qualityScore = qualityScore;
    if (indexer != null) result.indexer = indexer;
    if (magnetLink != null) result.magnetLink = magnetLink;
    if (sizeBytes != null) result.sizeBytes = sizeBytes;
    if (sizeFormatted != null) result.sizeFormatted = sizeFormatted;
    if (seeders != null) result.seeders = seeders;
    if (leechers != null) result.leechers = leechers;
    if (codec != null) result.codec = codec;
    if (bitrate != null) result.bitrate = bitrate;
    if (thumbnailUrl != null) result.thumbnailUrl = thumbnailUrl;
    if (durationSeconds != null) result.durationSeconds = durationSeconds;
    return result;
  }

  MusicSource._();

  factory MusicSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MusicSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MusicSource',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.search'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'url')
    ..aE<SourceType>(4, _omitFieldNames ? '' : 'sourceType',
        enumValues: SourceType.values)
    ..aOS(5, _omitFieldNames ? '' : 'format')
    ..aD(6, _omitFieldNames ? '' : 'qualityScore',
        fieldType: $pb.PbFieldType.OF)
    ..aOS(7, _omitFieldNames ? '' : 'indexer')
    ..aOS(8, _omitFieldNames ? '' : 'magnetLink')
    ..aInt64(9, _omitFieldNames ? '' : 'sizeBytes')
    ..aOS(10, _omitFieldNames ? '' : 'sizeFormatted')
    ..aI(11, _omitFieldNames ? '' : 'seeders')
    ..aI(12, _omitFieldNames ? '' : 'leechers')
    ..aOS(13, _omitFieldNames ? '' : 'codec')
    ..aOS(14, _omitFieldNames ? '' : 'bitrate')
    ..aOS(15, _omitFieldNames ? '' : 'thumbnailUrl')
    ..aI(16, _omitFieldNames ? '' : 'durationSeconds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MusicSource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MusicSource copyWith(void Function(MusicSource) updates) =>
      super.copyWith((message) => updates(message as MusicSource))
          as MusicSource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MusicSource create() => MusicSource._();
  @$core.override
  MusicSource createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MusicSource getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MusicSource>(create);
  static MusicSource? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get url => $_getSZ(2);
  @$pb.TagNumber(3)
  set url($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUrl() => $_has(2);
  @$pb.TagNumber(3)
  void clearUrl() => $_clearField(3);

  @$pb.TagNumber(4)
  SourceType get sourceType => $_getN(3);
  @$pb.TagNumber(4)
  set sourceType(SourceType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasSourceType() => $_has(3);
  @$pb.TagNumber(4)
  void clearSourceType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get format => $_getSZ(4);
  @$pb.TagNumber(5)
  set format($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFormat() => $_has(4);
  @$pb.TagNumber(5)
  void clearFormat() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get qualityScore => $_getN(5);
  @$pb.TagNumber(6)
  set qualityScore($core.double value) => $_setFloat(5, value);
  @$pb.TagNumber(6)
  $core.bool hasQualityScore() => $_has(5);
  @$pb.TagNumber(6)
  void clearQualityScore() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get indexer => $_getSZ(6);
  @$pb.TagNumber(7)
  set indexer($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIndexer() => $_has(6);
  @$pb.TagNumber(7)
  void clearIndexer() => $_clearField(7);

  /// Torrent-specific fields
  @$pb.TagNumber(8)
  $core.String get magnetLink => $_getSZ(7);
  @$pb.TagNumber(8)
  set magnetLink($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMagnetLink() => $_has(7);
  @$pb.TagNumber(8)
  void clearMagnetLink() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get sizeBytes => $_getI64(8);
  @$pb.TagNumber(9)
  set sizeBytes($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSizeBytes() => $_has(8);
  @$pb.TagNumber(9)
  void clearSizeBytes() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get sizeFormatted => $_getSZ(9);
  @$pb.TagNumber(10)
  set sizeFormatted($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSizeFormatted() => $_has(9);
  @$pb.TagNumber(10)
  void clearSizeFormatted() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get seeders => $_getIZ(10);
  @$pb.TagNumber(11)
  set seeders($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasSeeders() => $_has(10);
  @$pb.TagNumber(11)
  void clearSeeders() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get leechers => $_getIZ(11);
  @$pb.TagNumber(12)
  set leechers($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasLeechers() => $_has(11);
  @$pb.TagNumber(12)
  void clearLeechers() => $_clearField(12);

  /// Streaming-specific fields
  @$pb.TagNumber(13)
  $core.String get codec => $_getSZ(12);
  @$pb.TagNumber(13)
  set codec($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCodec() => $_has(12);
  @$pb.TagNumber(13)
  void clearCodec() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get bitrate => $_getSZ(13);
  @$pb.TagNumber(14)
  set bitrate($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasBitrate() => $_has(13);
  @$pb.TagNumber(14)
  void clearBitrate() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get thumbnailUrl => $_getSZ(14);
  @$pb.TagNumber(15)
  set thumbnailUrl($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasThumbnailUrl() => $_has(14);
  @$pb.TagNumber(15)
  void clearThumbnailUrl() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.int get durationSeconds => $_getIZ(15);
  @$pb.TagNumber(16)
  set durationSeconds($core.int value) => $_setSignedInt32(15, value);
  @$pb.TagNumber(16)
  $core.bool hasDurationSeconds() => $_has(15);
  @$pb.TagNumber(16)
  void clearDurationSeconds() => $_clearField(16);
}

/// Ranked source with explanation
class RankedSource extends $pb.GeneratedMessage {
  factory RankedSource({
    $core.int? rank,
    MusicSource? source,
    $core.String? explanation,
    $core.Iterable<$core.String>? tags,
  }) {
    final result = create();
    if (rank != null) result.rank = rank;
    if (source != null) result.source = source;
    if (explanation != null) result.explanation = explanation;
    if (tags != null) result.tags.addAll(tags);
    return result;
  }

  RankedSource._();

  factory RankedSource.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RankedSource.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RankedSource',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.search'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'rank')
    ..aOM<MusicSource>(2, _omitFieldNames ? '' : 'source',
        subBuilder: MusicSource.create)
    ..aOS(3, _omitFieldNames ? '' : 'explanation')
    ..pPS(4, _omitFieldNames ? '' : 'tags')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RankedSource clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RankedSource copyWith(void Function(RankedSource) updates) =>
      super.copyWith((message) => updates(message as RankedSource))
          as RankedSource;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RankedSource create() => RankedSource._();
  @$core.override
  RankedSource createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RankedSource getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RankedSource>(create);
  static RankedSource? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get rank => $_getIZ(0);
  @$pb.TagNumber(1)
  set rank($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRank() => $_has(0);
  @$pb.TagNumber(1)
  void clearRank() => $_clearField(1);

  @$pb.TagNumber(2)
  MusicSource get source => $_getN(1);
  @$pb.TagNumber(2)
  set source(MusicSource value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSource() => $_has(1);
  @$pb.TagNumber(2)
  void clearSource() => $_clearField(2);
  @$pb.TagNumber(2)
  MusicSource ensureSource() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get explanation => $_getSZ(2);
  @$pb.TagNumber(3)
  set explanation($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExplanation() => $_has(2);
  @$pb.TagNumber(3)
  void clearExplanation() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get tags => $_getList(3);
}

/// Search stats request (admin only)
class SearchStatsRequest extends $pb.GeneratedMessage {
  factory SearchStatsRequest({
    $fixnum.Int64? startTime,
    $fixnum.Int64? endTime,
  }) {
    final result = create();
    if (startTime != null) result.startTime = startTime;
    if (endTime != null) result.endTime = endTime;
    return result;
  }

  SearchStatsRequest._();

  factory SearchStatsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchStatsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchStatsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.search'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'startTime')
    ..aInt64(2, _omitFieldNames ? '' : 'endTime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchStatsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchStatsRequest copyWith(void Function(SearchStatsRequest) updates) =>
      super.copyWith((message) => updates(message as SearchStatsRequest))
          as SearchStatsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchStatsRequest create() => SearchStatsRequest._();
  @$core.override
  SearchStatsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchStatsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchStatsRequest>(create);
  static SearchStatsRequest? _defaultInstance;

  /// Time range
  @$pb.TagNumber(1)
  $fixnum.Int64 get startTime => $_getI64(0);
  @$pb.TagNumber(1)
  set startTime($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStartTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearStartTime() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get endTime => $_getI64(1);
  @$pb.TagNumber(2)
  set endTime($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEndTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearEndTime() => $_clearField(2);
}

/// Search stats response
class SearchStatsResponse extends $pb.GeneratedMessage {
  factory SearchStatsResponse({
    $fixnum.Int64? totalSearches,
    $fixnum.Int64? totalResultsReturned,
    $core.double? averageSearchTimeMs,
    $core.Iterable<$core.MapEntry<$core.String, $fixnum.Int64>>?
        searchesByAdapter,
  }) {
    final result = create();
    if (totalSearches != null) result.totalSearches = totalSearches;
    if (totalResultsReturned != null)
      result.totalResultsReturned = totalResultsReturned;
    if (averageSearchTimeMs != null)
      result.averageSearchTimeMs = averageSearchTimeMs;
    if (searchesByAdapter != null)
      result.searchesByAdapter.addEntries(searchesByAdapter);
    return result;
  }

  SearchStatsResponse._();

  factory SearchStatsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchStatsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchStatsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.search'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'totalSearches')
    ..aInt64(2, _omitFieldNames ? '' : 'totalResultsReturned')
    ..aD(3, _omitFieldNames ? '' : 'averageSearchTimeMs',
        fieldType: $pb.PbFieldType.OF)
    ..m<$core.String, $fixnum.Int64>(
        4, _omitFieldNames ? '' : 'searchesByAdapter',
        entryClassName: 'SearchStatsResponse.SearchesByAdapterEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.O6,
        packageName: const $pb.PackageName('trusttune.search'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchStatsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchStatsResponse copyWith(void Function(SearchStatsResponse) updates) =>
      super.copyWith((message) => updates(message as SearchStatsResponse))
          as SearchStatsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchStatsResponse create() => SearchStatsResponse._();
  @$core.override
  SearchStatsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchStatsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchStatsResponse>(create);
  static SearchStatsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get totalSearches => $_getI64(0);
  @$pb.TagNumber(1)
  set totalSearches($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTotalSearches() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotalSearches() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalResultsReturned => $_getI64(1);
  @$pb.TagNumber(2)
  set totalResultsReturned($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalResultsReturned() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalResultsReturned() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get averageSearchTimeMs => $_getN(2);
  @$pb.TagNumber(3)
  set averageSearchTimeMs($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAverageSearchTimeMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearAverageSearchTimeMs() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $fixnum.Int64> get searchesByAdapter => $_getMap(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
