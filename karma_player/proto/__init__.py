"""
Protocol buffer definitions for TrustTune gRPC services.

Generated stubs for:
- SearchService: Music search with streaming results
- AuthService: User identity and authentication
- Common types: Errors, status codes, pagination
"""

from karma_player.proto import common_pb2, common_pb2_grpc
from karma_player.proto import search_pb2, search_pb2_grpc
from karma_player.proto import auth_pb2, auth_pb2_grpc

__all__ = [
    'common_pb2',
    'common_pb2_grpc',
    'search_pb2',
    'search_pb2_grpc',
    'auth_pb2',
    'auth_pb2_grpc',
]
