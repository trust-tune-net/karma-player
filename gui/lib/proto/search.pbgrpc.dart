// This is a generated file - do not edit.
//
// Generated from search.proto.

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

import 'search.pb.dart' as $0;

export 'search.pb.dart';

/// Search service for music discovery
@$pb.GrpcServiceName('trusttune.search.SearchService')
class SearchServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  SearchServiceClient(super.channel, {super.options, super.interceptors});

  /// Stream search results as they arrive from different sources
  $grpc.ResponseStream<$0.SearchResponse> search(
    $0.SearchRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$search, $async.Stream.fromIterable([request]),
        options: options);
  }

  /// Get search statistics (for admin)
  $grpc.ResponseFuture<$0.SearchStatsResponse> getSearchStats(
    $0.SearchStatsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSearchStats, request, options: options);
  }

  // method descriptors

  static final _$search =
      $grpc.ClientMethod<$0.SearchRequest, $0.SearchResponse>(
          '/trusttune.search.SearchService/Search',
          ($0.SearchRequest value) => value.writeToBuffer(),
          $0.SearchResponse.fromBuffer);
  static final _$getSearchStats =
      $grpc.ClientMethod<$0.SearchStatsRequest, $0.SearchStatsResponse>(
          '/trusttune.search.SearchService/GetSearchStats',
          ($0.SearchStatsRequest value) => value.writeToBuffer(),
          $0.SearchStatsResponse.fromBuffer);
}

@$pb.GrpcServiceName('trusttune.search.SearchService')
abstract class SearchServiceBase extends $grpc.Service {
  $core.String get $name => 'trusttune.search.SearchService';

  SearchServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.SearchRequest, $0.SearchResponse>(
        'Search',
        search_Pre,
        false,
        true,
        ($core.List<$core.int> value) => $0.SearchRequest.fromBuffer(value),
        ($0.SearchResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SearchStatsRequest, $0.SearchStatsResponse>(
            'GetSearchStats',
            getSearchStats_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SearchStatsRequest.fromBuffer(value),
            ($0.SearchStatsResponse value) => value.writeToBuffer()));
  }

  $async.Stream<$0.SearchResponse> search_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SearchRequest> $request) async* {
    yield* search($call, await $request);
  }

  $async.Stream<$0.SearchResponse> search(
      $grpc.ServiceCall call, $0.SearchRequest request);

  $async.Future<$0.SearchStatsResponse> getSearchStats_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SearchStatsRequest> $request) async {
    return getSearchStats($call, await $request);
  }

  $async.Future<$0.SearchStatsResponse> getSearchStats(
      $grpc.ServiceCall call, $0.SearchStatsRequest request);
}
