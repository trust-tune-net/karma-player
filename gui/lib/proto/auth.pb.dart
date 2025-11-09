// This is a generated file - do not edit.
//
// Generated from auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Request to get user identity
class GetUserIdentityRequest extends $pb.GeneratedMessage {
  factory GetUserIdentityRequest() => create();

  GetUserIdentityRequest._();

  factory GetUserIdentityRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetUserIdentityRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetUserIdentityRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.auth'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUserIdentityRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUserIdentityRequest copyWith(
          void Function(GetUserIdentityRequest) updates) =>
      super.copyWith((message) => updates(message as GetUserIdentityRequest))
          as GetUserIdentityRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetUserIdentityRequest create() => GetUserIdentityRequest._();
  @$core.override
  GetUserIdentityRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetUserIdentityRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetUserIdentityRequest>(create);
  static GetUserIdentityRequest? _defaultInstance;
}

/// Response with user identity
class GetUserIdentityResponse extends $pb.GeneratedMessage {
  factory GetUserIdentityResponse({
    UserIdentity? identity,
    $1.Error? error,
  }) {
    final result = create();
    if (identity != null) result.identity = identity;
    if (error != null) result.error = error;
    return result;
  }

  GetUserIdentityResponse._();

  factory GetUserIdentityResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetUserIdentityResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetUserIdentityResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.auth'),
      createEmptyInstance: create)
    ..aOM<UserIdentity>(1, _omitFieldNames ? '' : 'identity',
        subBuilder: UserIdentity.create)
    ..aOM<$1.Error>(2, _omitFieldNames ? '' : 'error',
        subBuilder: $1.Error.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUserIdentityResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUserIdentityResponse copyWith(
          void Function(GetUserIdentityResponse) updates) =>
      super.copyWith((message) => updates(message as GetUserIdentityResponse))
          as GetUserIdentityResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetUserIdentityResponse create() => GetUserIdentityResponse._();
  @$core.override
  GetUserIdentityResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetUserIdentityResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetUserIdentityResponse>(create);
  static GetUserIdentityResponse? _defaultInstance;

  /// User identity
  @$pb.TagNumber(1)
  UserIdentity get identity => $_getN(0);
  @$pb.TagNumber(1)
  set identity(UserIdentity value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasIdentity() => $_has(0);
  @$pb.TagNumber(1)
  void clearIdentity() => $_clearField(1);
  @$pb.TagNumber(1)
  UserIdentity ensureIdentity() => $_ensure(0);

  /// Error if any
  @$pb.TagNumber(2)
  $1.Error get error => $_getN(1);
  @$pb.TagNumber(2)
  set error($1.Error value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.Error ensureError() => $_ensure(1);
}

/// User identity (device + generated username)
class UserIdentity extends $pb.GeneratedMessage {
  factory UserIdentity({
    $core.String? deviceId,
    $core.String? username,
    UsernameComponents? components,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (username != null) result.username = username;
    if (components != null) result.components = components;
    return result;
  }

  UserIdentity._();

  factory UserIdentity.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserIdentity.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserIdentity',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.auth'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..aOS(2, _omitFieldNames ? '' : 'username')
    ..aOM<UsernameComponents>(3, _omitFieldNames ? '' : 'components',
        subBuilder: UsernameComponents.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserIdentity clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserIdentity copyWith(void Function(UserIdentity) updates) =>
      super.copyWith((message) => updates(message as UserIdentity))
          as UserIdentity;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserIdentity create() => UserIdentity._();
  @$core.override
  UserIdentity createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserIdentity getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UserIdentity>(create);
  static UserIdentity? _defaultInstance;

  /// Raw device ID (UUID v4)
  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  /// Generated Reddit-style username (e.g., "Feisty-Sky-6018")
  @$pb.TagNumber(2)
  $core.String get username => $_getSZ(1);
  @$pb.TagNumber(2)
  set username($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUsername() => $_has(1);
  @$pb.TagNumber(2)
  void clearUsername() => $_clearField(2);

  /// Individual username components (for UI flexibility)
  @$pb.TagNumber(3)
  UsernameComponents get components => $_getN(2);
  @$pb.TagNumber(3)
  set components(UsernameComponents value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasComponents() => $_has(2);
  @$pb.TagNumber(3)
  void clearComponents() => $_clearField(3);
  @$pb.TagNumber(3)
  UsernameComponents ensureComponents() => $_ensure(2);
}

/// Username components
class UsernameComponents extends $pb.GeneratedMessage {
  factory UsernameComponents({
    $core.String? adjective,
    $core.String? noun,
    $core.int? number,
  }) {
    final result = create();
    if (adjective != null) result.adjective = adjective;
    if (noun != null) result.noun = noun;
    if (number != null) result.number = number;
    return result;
  }

  UsernameComponents._();

  factory UsernameComponents.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UsernameComponents.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UsernameComponents',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'trusttune.auth'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'adjective')
    ..aOS(2, _omitFieldNames ? '' : 'noun')
    ..aI(3, _omitFieldNames ? '' : 'number')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsernameComponents clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsernameComponents copyWith(void Function(UsernameComponents) updates) =>
      super.copyWith((message) => updates(message as UsernameComponents))
          as UsernameComponents;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UsernameComponents create() => UsernameComponents._();
  @$core.override
  UsernameComponents createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UsernameComponents getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UsernameComponents>(create);
  static UsernameComponents? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get adjective => $_getSZ(0);
  @$pb.TagNumber(1)
  set adjective($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAdjective() => $_has(0);
  @$pb.TagNumber(1)
  void clearAdjective() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get noun => $_getSZ(1);
  @$pb.TagNumber(2)
  set noun($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNoun() => $_has(1);
  @$pb.TagNumber(2)
  void clearNoun() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get number => $_getIZ(2);
  @$pb.TagNumber(3)
  set number($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNumber() => $_has(2);
  @$pb.TagNumber(3)
  void clearNumber() => $_clearField(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
