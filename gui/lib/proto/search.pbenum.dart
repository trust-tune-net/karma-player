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

import 'package:protobuf/protobuf.dart' as $pb;

class ResponseType extends $pb.ProtobufEnum {
  static const ResponseType RESPONSE_TYPE_UNSPECIFIED =
      ResponseType._(0, _omitEnumNames ? '' : 'RESPONSE_TYPE_UNSPECIFIED');
  static const ResponseType RESPONSE_TYPE_PROGRESS =
      ResponseType._(1, _omitEnumNames ? '' : 'RESPONSE_TYPE_PROGRESS');
  static const ResponseType RESPONSE_TYPE_PARTIAL_RESULT =
      ResponseType._(2, _omitEnumNames ? '' : 'RESPONSE_TYPE_PARTIAL_RESULT');
  static const ResponseType RESPONSE_TYPE_COMPLETE =
      ResponseType._(3, _omitEnumNames ? '' : 'RESPONSE_TYPE_COMPLETE');
  static const ResponseType RESPONSE_TYPE_ERROR =
      ResponseType._(4, _omitEnumNames ? '' : 'RESPONSE_TYPE_ERROR');

  static const $core.List<ResponseType> values = <ResponseType>[
    RESPONSE_TYPE_UNSPECIFIED,
    RESPONSE_TYPE_PROGRESS,
    RESPONSE_TYPE_PARTIAL_RESULT,
    RESPONSE_TYPE_COMPLETE,
    RESPONSE_TYPE_ERROR,
  ];

  static final $core.List<ResponseType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static ResponseType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ResponseType._(super.value, super.name);
}

class SourceType extends $pb.ProtobufEnum {
  static const SourceType SOURCE_TYPE_UNSPECIFIED =
      SourceType._(0, _omitEnumNames ? '' : 'SOURCE_TYPE_UNSPECIFIED');
  static const SourceType SOURCE_TYPE_TORRENT =
      SourceType._(1, _omitEnumNames ? '' : 'SOURCE_TYPE_TORRENT');
  static const SourceType SOURCE_TYPE_YOUTUBE =
      SourceType._(2, _omitEnumNames ? '' : 'SOURCE_TYPE_YOUTUBE');
  static const SourceType SOURCE_TYPE_PIPED =
      SourceType._(3, _omitEnumNames ? '' : 'SOURCE_TYPE_PIPED');
  static const SourceType SOURCE_TYPE_INVIDIOUS =
      SourceType._(4, _omitEnumNames ? '' : 'SOURCE_TYPE_INVIDIOUS');

  static const $core.List<SourceType> values = <SourceType>[
    SOURCE_TYPE_UNSPECIFIED,
    SOURCE_TYPE_TORRENT,
    SOURCE_TYPE_YOUTUBE,
    SOURCE_TYPE_PIPED,
    SOURCE_TYPE_INVIDIOUS,
  ];

  static final $core.List<SourceType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static SourceType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SourceType._(super.value, super.name);
}

class SourceTypeFilter extends $pb.ProtobufEnum {
  static const SourceTypeFilter SOURCE_TYPE_FILTER_ALL =
      SourceTypeFilter._(0, _omitEnumNames ? '' : 'SOURCE_TYPE_FILTER_ALL');
  static const SourceTypeFilter SOURCE_TYPE_FILTER_TORRENT =
      SourceTypeFilter._(1, _omitEnumNames ? '' : 'SOURCE_TYPE_FILTER_TORRENT');
  static const SourceTypeFilter SOURCE_TYPE_FILTER_STREAMING =
      SourceTypeFilter._(
          2, _omitEnumNames ? '' : 'SOURCE_TYPE_FILTER_STREAMING');

  static const $core.List<SourceTypeFilter> values = <SourceTypeFilter>[
    SOURCE_TYPE_FILTER_ALL,
    SOURCE_TYPE_FILTER_TORRENT,
    SOURCE_TYPE_FILTER_STREAMING,
  ];

  static final $core.List<SourceTypeFilter?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static SourceTypeFilter? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SourceTypeFilter._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
