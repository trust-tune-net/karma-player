// This is a generated file - do not edit.
//
// Generated from common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Common status codes for API responses
class StatusCode extends $pb.ProtobufEnum {
  static const StatusCode STATUS_CODE_UNSPECIFIED =
      StatusCode._(0, _omitEnumNames ? '' : 'STATUS_CODE_UNSPECIFIED');
  static const StatusCode STATUS_CODE_OK =
      StatusCode._(1, _omitEnumNames ? '' : 'STATUS_CODE_OK');
  static const StatusCode STATUS_CODE_ERROR =
      StatusCode._(2, _omitEnumNames ? '' : 'STATUS_CODE_ERROR');
  static const StatusCode STATUS_CODE_NOT_FOUND =
      StatusCode._(3, _omitEnumNames ? '' : 'STATUS_CODE_NOT_FOUND');
  static const StatusCode STATUS_CODE_UNAUTHORIZED =
      StatusCode._(4, _omitEnumNames ? '' : 'STATUS_CODE_UNAUTHORIZED');
  static const StatusCode STATUS_CODE_RATE_LIMITED =
      StatusCode._(5, _omitEnumNames ? '' : 'STATUS_CODE_RATE_LIMITED');
  static const StatusCode STATUS_CODE_BANNED =
      StatusCode._(6, _omitEnumNames ? '' : 'STATUS_CODE_BANNED');

  static const $core.List<StatusCode> values = <StatusCode>[
    STATUS_CODE_UNSPECIFIED,
    STATUS_CODE_OK,
    STATUS_CODE_ERROR,
    STATUS_CODE_NOT_FOUND,
    STATUS_CODE_UNAUTHORIZED,
    STATUS_CODE_RATE_LIMITED,
    STATUS_CODE_BANNED,
  ];

  static final $core.List<StatusCode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static StatusCode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StatusCode._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
