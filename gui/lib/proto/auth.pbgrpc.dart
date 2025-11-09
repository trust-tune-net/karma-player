// This is a generated file - do not edit.
//
// Generated from auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'auth.pb.dart' as $0;

export 'auth.pb.dart';

/// Auth/User service
@$pb.GrpcServiceName('trusttune.auth.AuthService')
class AuthServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AuthServiceClient(super.channel, {super.options, super.interceptors});

  /// Get user identity (username + device_id)
  $grpc.ResponseFuture<$0.GetUserIdentityResponse> getUserIdentity(
    $0.GetUserIdentityRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getUserIdentity, request, options: options);
  }

  // method descriptors

  static final _$getUserIdentity =
      $grpc.ClientMethod<$0.GetUserIdentityRequest, $0.GetUserIdentityResponse>(
          '/trusttune.auth.AuthService/GetUserIdentity',
          ($0.GetUserIdentityRequest value) => value.writeToBuffer(),
          $0.GetUserIdentityResponse.fromBuffer);
}

@$pb.GrpcServiceName('trusttune.auth.AuthService')
abstract class AuthServiceBase extends $grpc.Service {
  $core.String get $name => 'trusttune.auth.AuthService';

  AuthServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetUserIdentityRequest,
            $0.GetUserIdentityResponse>(
        'GetUserIdentity',
        getUserIdentity_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetUserIdentityRequest.fromBuffer(value),
        ($0.GetUserIdentityResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.GetUserIdentityResponse> getUserIdentity_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetUserIdentityRequest> $request) async {
    return getUserIdentity($call, await $request);
  }

  $async.Future<$0.GetUserIdentityResponse> getUserIdentity(
      $grpc.ServiceCall call, $0.GetUserIdentityRequest request);
}
