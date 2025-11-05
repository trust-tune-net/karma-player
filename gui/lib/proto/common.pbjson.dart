// This is a generated file - do not edit.
//
// Generated from common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use statusCodeDescriptor instead')
const StatusCode$json = {
  '1': 'StatusCode',
  '2': [
    {'1': 'STATUS_CODE_UNSPECIFIED', '2': 0},
    {'1': 'STATUS_CODE_OK', '2': 1},
    {'1': 'STATUS_CODE_ERROR', '2': 2},
    {'1': 'STATUS_CODE_NOT_FOUND', '2': 3},
    {'1': 'STATUS_CODE_UNAUTHORIZED', '2': 4},
    {'1': 'STATUS_CODE_RATE_LIMITED', '2': 5},
    {'1': 'STATUS_CODE_BANNED', '2': 6},
  ],
};

/// Descriptor for `StatusCode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List statusCodeDescriptor = $convert.base64Decode(
    'CgpTdGF0dXNDb2RlEhsKF1NUQVRVU19DT0RFX1VOU1BFQ0lGSUVEEAASEgoOU1RBVFVTX0NPRE'
    'VfT0sQARIVChFTVEFUVVNfQ09ERV9FUlJPUhACEhkKFVNUQVRVU19DT0RFX05PVF9GT1VORBAD'
    'EhwKGFNUQVRVU19DT0RFX1VOQVVUSE9SSVpFRBAEEhwKGFNUQVRVU19DT0RFX1JBVEVfTElNSV'
    'RFRBAFEhYKElNUQVRVU19DT0RFX0JBTk5FRBAG');

@$core.Deprecated('Use errorDescriptor instead')
const Error$json = {
  '1': 'Error',
  '2': [
    {
      '1': 'code',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.trusttune.common.StatusCode',
      '10': 'code'
    },
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'details', '3': 3, '4': 1, '5': 9, '10': 'details'},
  ],
};

/// Descriptor for `Error`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorDescriptor = $convert.base64Decode(
    'CgVFcnJvchIwCgRjb2RlGAEgASgOMhwudHJ1c3R0dW5lLmNvbW1vbi5TdGF0dXNDb2RlUgRjb2'
    'RlEhgKB21lc3NhZ2UYAiABKAlSB21lc3NhZ2USGAoHZGV0YWlscxgDIAEoCVIHZGV0YWlscw==');

@$core.Deprecated('Use timestampDescriptor instead')
const Timestamp$json = {
  '1': 'Timestamp',
  '2': [
    {'1': 'seconds', '3': 1, '4': 1, '5': 3, '10': 'seconds'},
    {'1': 'nanos', '3': 2, '4': 1, '5': 5, '10': 'nanos'},
  ],
};

/// Descriptor for `Timestamp`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List timestampDescriptor = $convert.base64Decode(
    'CglUaW1lc3RhbXASGAoHc2Vjb25kcxgBIAEoA1IHc2Vjb25kcxIUCgVuYW5vcxgCIAEoBVIFbm'
    'Fub3M=');

@$core.Deprecated('Use paginationRequestDescriptor instead')
const PaginationRequest$json = {
  '1': 'PaginationRequest',
  '2': [
    {'1': 'limit', '3': 1, '4': 1, '5': 5, '10': 'limit'},
    {'1': 'offset', '3': 2, '4': 1, '5': 5, '10': 'offset'},
  ],
};

/// Descriptor for `PaginationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paginationRequestDescriptor = $convert.base64Decode(
    'ChFQYWdpbmF0aW9uUmVxdWVzdBIUCgVsaW1pdBgBIAEoBVIFbGltaXQSFgoGb2Zmc2V0GAIgAS'
    'gFUgZvZmZzZXQ=');

@$core.Deprecated('Use paginationResponseDescriptor instead')
const PaginationResponse$json = {
  '1': 'PaginationResponse',
  '2': [
    {'1': 'total_count', '3': 1, '4': 1, '5': 5, '10': 'totalCount'},
    {'1': 'returned_count', '3': 2, '4': 1, '5': 5, '10': 'returnedCount'},
    {'1': 'offset', '3': 3, '4': 1, '5': 5, '10': 'offset'},
    {'1': 'has_more', '3': 4, '4': 1, '5': 8, '10': 'hasMore'},
  ],
};

/// Descriptor for `PaginationResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paginationResponseDescriptor = $convert.base64Decode(
    'ChJQYWdpbmF0aW9uUmVzcG9uc2USHwoLdG90YWxfY291bnQYASABKAVSCnRvdGFsQ291bnQSJQ'
    'oOcmV0dXJuZWRfY291bnQYAiABKAVSDXJldHVybmVkQ291bnQSFgoGb2Zmc2V0GAMgASgFUgZv'
    'ZmZzZXQSGQoIaGFzX21vcmUYBCABKAhSB2hhc01vcmU=');
