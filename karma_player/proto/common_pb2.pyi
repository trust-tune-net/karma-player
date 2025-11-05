from google.protobuf.internal import enum_type_wrapper as _enum_type_wrapper
from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from typing import ClassVar as _ClassVar, Optional as _Optional, Union as _Union

DESCRIPTOR: _descriptor.FileDescriptor

class StatusCode(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    STATUS_CODE_UNSPECIFIED: _ClassVar[StatusCode]
    STATUS_CODE_OK: _ClassVar[StatusCode]
    STATUS_CODE_ERROR: _ClassVar[StatusCode]
    STATUS_CODE_NOT_FOUND: _ClassVar[StatusCode]
    STATUS_CODE_UNAUTHORIZED: _ClassVar[StatusCode]
    STATUS_CODE_RATE_LIMITED: _ClassVar[StatusCode]
    STATUS_CODE_BANNED: _ClassVar[StatusCode]
STATUS_CODE_UNSPECIFIED: StatusCode
STATUS_CODE_OK: StatusCode
STATUS_CODE_ERROR: StatusCode
STATUS_CODE_NOT_FOUND: StatusCode
STATUS_CODE_UNAUTHORIZED: StatusCode
STATUS_CODE_RATE_LIMITED: StatusCode
STATUS_CODE_BANNED: StatusCode

class Error(_message.Message):
    __slots__ = ("code", "message", "details")
    CODE_FIELD_NUMBER: _ClassVar[int]
    MESSAGE_FIELD_NUMBER: _ClassVar[int]
    DETAILS_FIELD_NUMBER: _ClassVar[int]
    code: StatusCode
    message: str
    details: str
    def __init__(self, code: _Optional[_Union[StatusCode, str]] = ..., message: _Optional[str] = ..., details: _Optional[str] = ...) -> None: ...

class Timestamp(_message.Message):
    __slots__ = ("seconds", "nanos")
    SECONDS_FIELD_NUMBER: _ClassVar[int]
    NANOS_FIELD_NUMBER: _ClassVar[int]
    seconds: int
    nanos: int
    def __init__(self, seconds: _Optional[int] = ..., nanos: _Optional[int] = ...) -> None: ...

class PaginationRequest(_message.Message):
    __slots__ = ("limit", "offset")
    LIMIT_FIELD_NUMBER: _ClassVar[int]
    OFFSET_FIELD_NUMBER: _ClassVar[int]
    limit: int
    offset: int
    def __init__(self, limit: _Optional[int] = ..., offset: _Optional[int] = ...) -> None: ...

class PaginationResponse(_message.Message):
    __slots__ = ("total_count", "returned_count", "offset", "has_more")
    TOTAL_COUNT_FIELD_NUMBER: _ClassVar[int]
    RETURNED_COUNT_FIELD_NUMBER: _ClassVar[int]
    OFFSET_FIELD_NUMBER: _ClassVar[int]
    HAS_MORE_FIELD_NUMBER: _ClassVar[int]
    total_count: int
    returned_count: int
    offset: int
    has_more: bool
    def __init__(self, total_count: _Optional[int] = ..., returned_count: _Optional[int] = ..., offset: _Optional[int] = ..., has_more: bool = ...) -> None: ...
