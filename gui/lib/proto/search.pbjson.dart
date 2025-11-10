// This is a generated file - do not edit.
//
// Generated from search.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use responseTypeDescriptor instead')
const ResponseType$json = {
  '1': 'ResponseType',
  '2': [
    {'1': 'RESPONSE_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'RESPONSE_TYPE_PROGRESS', '2': 1},
    {'1': 'RESPONSE_TYPE_PARTIAL_RESULT', '2': 2},
    {'1': 'RESPONSE_TYPE_COMPLETE', '2': 3},
    {'1': 'RESPONSE_TYPE_ERROR', '2': 4},
  ],
};

/// Descriptor for `ResponseType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List responseTypeDescriptor = $convert.base64Decode(
    'CgxSZXNwb25zZVR5cGUSHQoZUkVTUE9OU0VfVFlQRV9VTlNQRUNJRklFRBAAEhoKFlJFU1BPTl'
    'NFX1RZUEVfUFJPR1JFU1MQARIgChxSRVNQT05TRV9UWVBFX1BBUlRJQUxfUkVTVUxUEAISGgoW'
    'UkVTUE9OU0VfVFlQRV9DT01QTEVURRADEhcKE1JFU1BPTlNFX1RZUEVfRVJST1IQBA==');

@$core.Deprecated('Use sourceTypeDescriptor instead')
const SourceType$json = {
  '1': 'SourceType',
  '2': [
    {'1': 'SOURCE_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'SOURCE_TYPE_TORRENT', '2': 1},
    {'1': 'SOURCE_TYPE_YOUTUBE', '2': 2},
    {'1': 'SOURCE_TYPE_PIPED', '2': 3},
    {'1': 'SOURCE_TYPE_INVIDIOUS', '2': 4},
  ],
};

/// Descriptor for `SourceType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sourceTypeDescriptor = $convert.base64Decode(
    'CgpTb3VyY2VUeXBlEhsKF1NPVVJDRV9UWVBFX1VOU1BFQ0lGSUVEEAASFwoTU09VUkNFX1RZUE'
    'VfVE9SUkVOVBABEhcKE1NPVVJDRV9UWVBFX1lPVVRVQkUQAhIVChFTT1VSQ0VfVFlQRV9QSVBF'
    'RBADEhkKFVNPVVJDRV9UWVBFX0lOVklESU9VUxAE');

@$core.Deprecated('Use sourceTypeFilterDescriptor instead')
const SourceTypeFilter$json = {
  '1': 'SourceTypeFilter',
  '2': [
    {'1': 'SOURCE_TYPE_FILTER_ALL', '2': 0},
    {'1': 'SOURCE_TYPE_FILTER_TORRENT', '2': 1},
    {'1': 'SOURCE_TYPE_FILTER_STREAMING', '2': 2},
  ],
};

/// Descriptor for `SourceTypeFilter`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sourceTypeFilterDescriptor = $convert.base64Decode(
    'ChBTb3VyY2VUeXBlRmlsdGVyEhoKFlNPVVJDRV9UWVBFX0ZJTFRFUl9BTEwQABIeChpTT1VSQ0'
    'VfVFlQRV9GSUxURVJfVE9SUkVOVBABEiAKHFNPVVJDRV9UWVBFX0ZJTFRFUl9TVFJFQU1JTkcQ'
    'Ag==');

@$core.Deprecated('Use searchRequestDescriptor instead')
const SearchRequest$json = {
  '1': 'SearchRequest',
  '2': [
    {'1': 'query', '3': 1, '4': 1, '5': 9, '10': 'query'},
    {
      '1': 'format_filter',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'formatFilter',
      '17': true
    },
    {'1': 'min_seeders', '3': 3, '4': 1, '5': 5, '10': 'minSeeders'},
    {'1': 'limit', '3': 4, '4': 1, '5': 5, '10': 'limit'},
    {'1': 'offset', '3': 5, '4': 1, '5': 5, '10': 'offset'},
    {'1': 'artist', '3': 6, '4': 1, '5': 9, '9': 1, '10': 'artist', '17': true},
    {'1': 'album', '3': 7, '4': 1, '5': 9, '9': 2, '10': 'album', '17': true},
    {
      '1': 'min_bitrate',
      '3': 8,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'minBitrate',
      '17': true
    },
    {
      '1': 'max_size_mb',
      '3': 9,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'maxSizeMb',
      '17': true
    },
    {
      '1': 'source_type_filter',
      '3': 10,
      '4': 1,
      '5': 14,
      '6': '.trusttune.search.SourceTypeFilter',
      '9': 5,
      '10': 'sourceTypeFilter',
      '17': true
    },
    {
      '1': 'use_dedup',
      '3': 11,
      '4': 1,
      '5': 8,
      '9': 6,
      '10': 'useDedup',
      '17': true
    },
    {
      '1': 'max_results',
      '3': 12,
      '4': 1,
      '5': 5,
      '9': 7,
      '10': 'maxResults',
      '17': true
    },
  ],
  '8': [
    {'1': '_format_filter'},
    {'1': '_artist'},
    {'1': '_album'},
    {'1': '_min_bitrate'},
    {'1': '_max_size_mb'},
    {'1': '_source_type_filter'},
    {'1': '_use_dedup'},
    {'1': '_max_results'},
  ],
};

/// Descriptor for `SearchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchRequestDescriptor = $convert.base64Decode(
    'Cg1TZWFyY2hSZXF1ZXN0EhQKBXF1ZXJ5GAEgASgJUgVxdWVyeRIoCg1mb3JtYXRfZmlsdGVyGA'
    'IgASgJSABSDGZvcm1hdEZpbHRlcogBARIfCgttaW5fc2VlZGVycxgDIAEoBVIKbWluU2VlZGVy'
    'cxIUCgVsaW1pdBgEIAEoBVIFbGltaXQSFgoGb2Zmc2V0GAUgASgFUgZvZmZzZXQSGwoGYXJ0aX'
    'N0GAYgASgJSAFSBmFydGlzdIgBARIZCgVhbGJ1bRgHIAEoCUgCUgVhbGJ1bYgBARIkCgttaW5f'
    'Yml0cmF0ZRgIIAEoBUgDUgptaW5CaXRyYXRliAEBEiMKC21heF9zaXplX21iGAkgASgFSARSCW'
    '1heFNpemVNYogBARJVChJzb3VyY2VfdHlwZV9maWx0ZXIYCiABKA4yIi50cnVzdHR1bmUuc2Vh'
    'cmNoLlNvdXJjZVR5cGVGaWx0ZXJIBVIQc291cmNlVHlwZUZpbHRlcogBARIgCgl1c2VfZGVkdX'
    'AYCyABKAhIBlIIdXNlRGVkdXCIAQESJAoLbWF4X3Jlc3VsdHMYDCABKAVIB1IKbWF4UmVzdWx0'
    'c4gBAUIQCg5fZm9ybWF0X2ZpbHRlckIJCgdfYXJ0aXN0QggKBl9hbGJ1bUIOCgxfbWluX2JpdH'
    'JhdGVCDgoMX21heF9zaXplX21iQhUKE19zb3VyY2VfdHlwZV9maWx0ZXJCDAoKX3VzZV9kZWR1'
    'cEIOCgxfbWF4X3Jlc3VsdHM=');

@$core.Deprecated('Use searchResponseDescriptor instead')
const SearchResponse$json = {
  '1': 'SearchResponse',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.trusttune.search.ResponseType',
      '10': 'type'
    },
    {
      '1': 'progress',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.trusttune.search.ProgressUpdate',
      '9': 0,
      '10': 'progress',
      '17': true
    },
    {
      '1': 'partial_result',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.trusttune.search.PartialResult',
      '9': 1,
      '10': 'partialResult',
      '17': true
    },
    {
      '1': 'complete_result',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.trusttune.search.CompleteResult',
      '9': 2,
      '10': 'completeResult',
      '17': true
    },
    {
      '1': 'error',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.trusttune.common.Error',
      '9': 3,
      '10': 'error',
      '17': true
    },
  ],
  '8': [
    {'1': '_progress'},
    {'1': '_partial_result'},
    {'1': '_complete_result'},
    {'1': '_error'},
  ],
};

/// Descriptor for `SearchResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchResponseDescriptor = $convert.base64Decode(
    'Cg5TZWFyY2hSZXNwb25zZRIyCgR0eXBlGAEgASgOMh4udHJ1c3R0dW5lLnNlYXJjaC5SZXNwb2'
    '5zZVR5cGVSBHR5cGUSQQoIcHJvZ3Jlc3MYAiABKAsyIC50cnVzdHR1bmUuc2VhcmNoLlByb2dy'
    'ZXNzVXBkYXRlSABSCHByb2dyZXNziAEBEksKDnBhcnRpYWxfcmVzdWx0GAMgASgLMh8udHJ1c3'
    'R0dW5lLnNlYXJjaC5QYXJ0aWFsUmVzdWx0SAFSDXBhcnRpYWxSZXN1bHSIAQESTgoPY29tcGxl'
    'dGVfcmVzdWx0GAQgASgLMiAudHJ1c3R0dW5lLnNlYXJjaC5Db21wbGV0ZVJlc3VsdEgCUg5jb2'
    '1wbGV0ZVJlc3VsdIgBARIyCgVlcnJvchgFIAEoCzIXLnRydXN0dHVuZS5jb21tb24uRXJyb3JI'
    'A1IFZXJyb3KIAQFCCwoJX3Byb2dyZXNzQhEKD19wYXJ0aWFsX3Jlc3VsdEISChBfY29tcGxldG'
    'VfcmVzdWx0QggKBl9lcnJvcg==');

@$core.Deprecated('Use progressUpdateDescriptor instead')
const ProgressUpdate$json = {
  '1': 'ProgressUpdate',
  '2': [
    {'1': 'percent', '3': 1, '4': 1, '5': 5, '10': 'percent'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `ProgressUpdate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List progressUpdateDescriptor = $convert.base64Decode(
    'Cg5Qcm9ncmVzc1VwZGF0ZRIYCgdwZXJjZW50GAEgASgFUgdwZXJjZW50EhgKB21lc3NhZ2UYAi'
    'ABKAlSB21lc3NhZ2U=');

@$core.Deprecated('Use partialResultDescriptor instead')
const PartialResult$json = {
  '1': 'PartialResult',
  '2': [
    {'1': 'adapter_name', '3': 1, '4': 1, '5': 9, '10': 'adapterName'},
    {'1': 'count', '3': 2, '4': 1, '5': 5, '10': 'count'},
    {
      '1': 'sources',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.trusttune.search.MusicSource',
      '10': 'sources'
    },
  ],
};

/// Descriptor for `PartialResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List partialResultDescriptor = $convert.base64Decode(
    'Cg1QYXJ0aWFsUmVzdWx0EiEKDGFkYXB0ZXJfbmFtZRgBIAEoCVILYWRhcHRlck5hbWUSFAoFY2'
    '91bnQYAiABKAVSBWNvdW50EjcKB3NvdXJjZXMYAyADKAsyHS50cnVzdHR1bmUuc2VhcmNoLk11'
    'c2ljU291cmNlUgdzb3VyY2Vz');

@$core.Deprecated('Use completeResultDescriptor instead')
const CompleteResult$json = {
  '1': 'CompleteResult',
  '2': [
    {'1': 'total_found', '3': 1, '4': 1, '5': 5, '10': 'totalFound'},
    {'1': 'search_time_ms', '3': 2, '4': 1, '5': 5, '10': 'searchTimeMs'},
    {
      '1': 'ranked_sources',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.trusttune.search.RankedSource',
      '10': 'rankedSources'
    },
  ],
};

/// Descriptor for `CompleteResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeResultDescriptor = $convert.base64Decode(
    'Cg5Db21wbGV0ZVJlc3VsdBIfCgt0b3RhbF9mb3VuZBgBIAEoBVIKdG90YWxGb3VuZBIkCg5zZW'
    'FyY2hfdGltZV9tcxgCIAEoBVIMc2VhcmNoVGltZU1zEkUKDnJhbmtlZF9zb3VyY2VzGAMgAygL'
    'Mh4udHJ1c3R0dW5lLnNlYXJjaC5SYW5rZWRTb3VyY2VSDXJhbmtlZFNvdXJjZXM=');

@$core.Deprecated('Use musicSourceDescriptor instead')
const MusicSource$json = {
  '1': 'MusicSource',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'url', '3': 3, '4': 1, '5': 9, '10': 'url'},
    {
      '1': 'source_type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.trusttune.search.SourceType',
      '10': 'sourceType'
    },
    {'1': 'format', '3': 5, '4': 1, '5': 9, '9': 0, '10': 'format', '17': true},
    {'1': 'quality_score', '3': 6, '4': 1, '5': 2, '10': 'qualityScore'},
    {'1': 'indexer', '3': 7, '4': 1, '5': 9, '10': 'indexer'},
    {
      '1': 'magnet_link',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'magnetLink',
      '17': true
    },
    {
      '1': 'size_bytes',
      '3': 9,
      '4': 1,
      '5': 3,
      '9': 2,
      '10': 'sizeBytes',
      '17': true
    },
    {
      '1': 'size_formatted',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'sizeFormatted',
      '17': true
    },
    {
      '1': 'seeders',
      '3': 11,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'seeders',
      '17': true
    },
    {
      '1': 'leechers',
      '3': 12,
      '4': 1,
      '5': 5,
      '9': 5,
      '10': 'leechers',
      '17': true
    },
    {'1': 'codec', '3': 13, '4': 1, '5': 9, '9': 6, '10': 'codec', '17': true},
    {
      '1': 'bitrate',
      '3': 14,
      '4': 1,
      '5': 9,
      '9': 7,
      '10': 'bitrate',
      '17': true
    },
    {
      '1': 'thumbnail_url',
      '3': 15,
      '4': 1,
      '5': 9,
      '9': 8,
      '10': 'thumbnailUrl',
      '17': true
    },
    {
      '1': 'duration_seconds',
      '3': 16,
      '4': 1,
      '5': 5,
      '9': 9,
      '10': 'durationSeconds',
      '17': true
    },
  ],
  '8': [
    {'1': '_format'},
    {'1': '_magnet_link'},
    {'1': '_size_bytes'},
    {'1': '_size_formatted'},
    {'1': '_seeders'},
    {'1': '_leechers'},
    {'1': '_codec'},
    {'1': '_bitrate'},
    {'1': '_thumbnail_url'},
    {'1': '_duration_seconds'},
  ],
};

/// Descriptor for `MusicSource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List musicSourceDescriptor = $convert.base64Decode(
    'CgtNdXNpY1NvdXJjZRIOCgJpZBgBIAEoCVICaWQSFAoFdGl0bGUYAiABKAlSBXRpdGxlEhAKA3'
    'VybBgDIAEoCVIDdXJsEj0KC3NvdXJjZV90eXBlGAQgASgOMhwudHJ1c3R0dW5lLnNlYXJjaC5T'
    'b3VyY2VUeXBlUgpzb3VyY2VUeXBlEhsKBmZvcm1hdBgFIAEoCUgAUgZmb3JtYXSIAQESIwoNcX'
    'VhbGl0eV9zY29yZRgGIAEoAlIMcXVhbGl0eVNjb3JlEhgKB2luZGV4ZXIYByABKAlSB2luZGV4'
    'ZXISJAoLbWFnbmV0X2xpbmsYCCABKAlIAVIKbWFnbmV0TGlua4gBARIiCgpzaXplX2J5dGVzGA'
    'kgASgDSAJSCXNpemVCeXRlc4gBARIqCg5zaXplX2Zvcm1hdHRlZBgKIAEoCUgDUg1zaXplRm9y'
    'bWF0dGVkiAEBEh0KB3NlZWRlcnMYCyABKAVIBFIHc2VlZGVyc4gBARIfCghsZWVjaGVycxgMIA'
    'EoBUgFUghsZWVjaGVyc4gBARIZCgVjb2RlYxgNIAEoCUgGUgVjb2RlY4gBARIdCgdiaXRyYXRl'
    'GA4gASgJSAdSB2JpdHJhdGWIAQESKAoNdGh1bWJuYWlsX3VybBgPIAEoCUgIUgx0aHVtYm5haW'
    'xVcmyIAQESLgoQZHVyYXRpb25fc2Vjb25kcxgQIAEoBUgJUg9kdXJhdGlvblNlY29uZHOIAQFC'
    'CQoHX2Zvcm1hdEIOCgxfbWFnbmV0X2xpbmtCDQoLX3NpemVfYnl0ZXNCEQoPX3NpemVfZm9ybW'
    'F0dGVkQgoKCF9zZWVkZXJzQgsKCV9sZWVjaGVyc0IICgZfY29kZWNCCgoIX2JpdHJhdGVCEAoO'
    'X3RodW1ibmFpbF91cmxCEwoRX2R1cmF0aW9uX3NlY29uZHM=');

@$core.Deprecated('Use rankedSourceDescriptor instead')
const RankedSource$json = {
  '1': 'RankedSource',
  '2': [
    {'1': 'rank', '3': 1, '4': 1, '5': 5, '10': 'rank'},
    {
      '1': 'source',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.trusttune.search.MusicSource',
      '10': 'source'
    },
    {'1': 'explanation', '3': 3, '4': 1, '5': 9, '10': 'explanation'},
    {'1': 'tags', '3': 4, '4': 3, '5': 9, '10': 'tags'},
  ],
};

/// Descriptor for `RankedSource`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rankedSourceDescriptor = $convert.base64Decode(
    'CgxSYW5rZWRTb3VyY2USEgoEcmFuaxgBIAEoBVIEcmFuaxI1CgZzb3VyY2UYAiABKAsyHS50cn'
    'VzdHR1bmUuc2VhcmNoLk11c2ljU291cmNlUgZzb3VyY2USIAoLZXhwbGFuYXRpb24YAyABKAlS'
    'C2V4cGxhbmF0aW9uEhIKBHRhZ3MYBCADKAlSBHRhZ3M=');

@$core.Deprecated('Use searchStatsRequestDescriptor instead')
const SearchStatsRequest$json = {
  '1': 'SearchStatsRequest',
  '2': [
    {
      '1': 'start_time',
      '3': 1,
      '4': 1,
      '5': 3,
      '9': 0,
      '10': 'startTime',
      '17': true
    },
    {
      '1': 'end_time',
      '3': 2,
      '4': 1,
      '5': 3,
      '9': 1,
      '10': 'endTime',
      '17': true
    },
  ],
  '8': [
    {'1': '_start_time'},
    {'1': '_end_time'},
  ],
};

/// Descriptor for `SearchStatsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchStatsRequestDescriptor = $convert.base64Decode(
    'ChJTZWFyY2hTdGF0c1JlcXVlc3QSIgoKc3RhcnRfdGltZRgBIAEoA0gAUglzdGFydFRpbWWIAQ'
    'ESHgoIZW5kX3RpbWUYAiABKANIAVIHZW5kVGltZYgBAUINCgtfc3RhcnRfdGltZUILCglfZW5k'
    'X3RpbWU=');

@$core.Deprecated('Use searchStatsResponseDescriptor instead')
const SearchStatsResponse$json = {
  '1': 'SearchStatsResponse',
  '2': [
    {'1': 'total_searches', '3': 1, '4': 1, '5': 3, '10': 'totalSearches'},
    {
      '1': 'total_results_returned',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'totalResultsReturned'
    },
    {
      '1': 'average_search_time_ms',
      '3': 3,
      '4': 1,
      '5': 2,
      '10': 'averageSearchTimeMs'
    },
    {
      '1': 'searches_by_adapter',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.trusttune.search.SearchStatsResponse.SearchesByAdapterEntry',
      '10': 'searchesByAdapter'
    },
  ],
  '3': [SearchStatsResponse_SearchesByAdapterEntry$json],
};

@$core.Deprecated('Use searchStatsResponseDescriptor instead')
const SearchStatsResponse_SearchesByAdapterEntry$json = {
  '1': 'SearchesByAdapterEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 3, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `SearchStatsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchStatsResponseDescriptor = $convert.base64Decode(
    'ChNTZWFyY2hTdGF0c1Jlc3BvbnNlEiUKDnRvdGFsX3NlYXJjaGVzGAEgASgDUg10b3RhbFNlYX'
    'JjaGVzEjQKFnRvdGFsX3Jlc3VsdHNfcmV0dXJuZWQYAiABKANSFHRvdGFsUmVzdWx0c1JldHVy'
    'bmVkEjMKFmF2ZXJhZ2Vfc2VhcmNoX3RpbWVfbXMYAyABKAJSE2F2ZXJhZ2VTZWFyY2hUaW1lTX'
    'MSbAoTc2VhcmNoZXNfYnlfYWRhcHRlchgEIAMoCzI8LnRydXN0dHVuZS5zZWFyY2guU2VhcmNo'
    'U3RhdHNSZXNwb25zZS5TZWFyY2hlc0J5QWRhcHRlckVudHJ5UhFzZWFyY2hlc0J5QWRhcHRlch'
    'pEChZTZWFyY2hlc0J5QWRhcHRlckVudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIg'
    'ASgDUgV2YWx1ZToCOAE=');
