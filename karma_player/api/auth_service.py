"""
Auth service implementation for gRPC.

Provides user identity (username generation) based on device_id.
"""

from karma_player.proto import auth_pb2, auth_pb2_grpc, common_pb2
from karma_player.services.username_generator import generate_username_with_parts


class AuthServicer(auth_pb2_grpc.AuthServiceServicer):
    """gRPC servicer for authentication and user identity."""

    async def GetUserIdentity(self, request, context):
        """
        Get user identity (username + device_id).

        Args:
            request: GetUserIdentityRequest (empty, auth in metadata)
            context: gRPC service context

        Returns:
            GetUserIdentityResponse with UserIdentity
        """
        try:
            # Extract device_id from gRPC metadata (set by AuthInterceptor)
            metadata = dict(context.invocation_metadata())
            device_id = metadata.get('device_id')

            if not device_id:
                # This shouldn't happen if AuthInterceptor is working
                error = common_pb2.Error(
                    code=common_pb2.STATUS_CODE_UNAUTHORIZED,
                    message="Missing device_id in metadata",
                    details="Authentication failed - no device_id found"
                )
                return auth_pb2.GetUserIdentityResponse(error=error)

            # Generate username deterministically from device_id
            username, adjective, noun, number = generate_username_with_parts(device_id)

            # Create username components
            components = auth_pb2.UsernameComponents(
                adjective=adjective,
                noun=noun,
                number=number
            )

            # Create user identity
            identity = auth_pb2.UserIdentity(
                device_id=device_id,
                username=username,
                components=components
            )

            # Return response
            return auth_pb2.GetUserIdentityResponse(identity=identity)

        except Exception as e:
            # Handle unexpected errors
            error = common_pb2.Error(
                code=common_pb2.STATUS_CODE_ERROR,
                message="Failed to generate user identity",
                details=str(e)
            )
            return auth_pb2.GetUserIdentityResponse(error=error)
