// This is a generated file - do not edit.
//
// Generated from auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use getUserIdentityRequestDescriptor instead')
const GetUserIdentityRequest$json = {
  '1': 'GetUserIdentityRequest',
};

/// Descriptor for `GetUserIdentityRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUserIdentityRequestDescriptor =
    $convert.base64Decode('ChZHZXRVc2VySWRlbnRpdHlSZXF1ZXN0');

@$core.Deprecated('Use getUserIdentityResponseDescriptor instead')
const GetUserIdentityResponse$json = {
  '1': 'GetUserIdentityResponse',
  '2': [
    {
      '1': 'identity',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.trusttune.auth.UserIdentity',
      '10': 'identity'
    },
    {
      '1': 'error',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.trusttune.common.Error',
      '9': 0,
      '10': 'error',
      '17': true
    },
  ],
  '8': [
    {'1': '_error'},
  ],
};

/// Descriptor for `GetUserIdentityResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUserIdentityResponseDescriptor = $convert.base64Decode(
    'ChdHZXRVc2VySWRlbnRpdHlSZXNwb25zZRI4CghpZGVudGl0eRgBIAEoCzIcLnRydXN0dHVuZS'
    '5hdXRoLlVzZXJJZGVudGl0eVIIaWRlbnRpdHkSMgoFZXJyb3IYAiABKAsyFy50cnVzdHR1bmUu'
    'Y29tbW9uLkVycm9ySABSBWVycm9yiAEBQggKBl9lcnJvcg==');

@$core.Deprecated('Use userIdentityDescriptor instead')
const UserIdentity$json = {
  '1': 'UserIdentity',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'username', '3': 2, '4': 1, '5': 9, '10': 'username'},
    {
      '1': 'components',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.trusttune.auth.UsernameComponents',
      '10': 'components'
    },
  ],
};

/// Descriptor for `UserIdentity`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userIdentityDescriptor = $convert.base64Decode(
    'CgxVc2VySWRlbnRpdHkSGwoJZGV2aWNlX2lkGAEgASgJUghkZXZpY2VJZBIaCgh1c2VybmFtZR'
    'gCIAEoCVIIdXNlcm5hbWUSQgoKY29tcG9uZW50cxgDIAEoCzIiLnRydXN0dHVuZS5hdXRoLlVz'
    'ZXJuYW1lQ29tcG9uZW50c1IKY29tcG9uZW50cw==');

@$core.Deprecated('Use usernameComponentsDescriptor instead')
const UsernameComponents$json = {
  '1': 'UsernameComponents',
  '2': [
    {'1': 'adjective', '3': 1, '4': 1, '5': 9, '10': 'adjective'},
    {'1': 'noun', '3': 2, '4': 1, '5': 9, '10': 'noun'},
    {'1': 'number', '3': 3, '4': 1, '5': 5, '10': 'number'},
  ],
};

/// Descriptor for `UsernameComponents`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List usernameComponentsDescriptor = $convert.base64Decode(
    'ChJVc2VybmFtZUNvbXBvbmVudHMSHAoJYWRqZWN0aXZlGAEgASgJUglhZGplY3RpdmUSEgoEbm'
    '91bhgCIAEoCVIEbm91bhIWCgZudW1iZXIYAyABKAVSBm51bWJlcg==');
