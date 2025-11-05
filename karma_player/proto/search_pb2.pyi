import common_pb2 as _common_pb2
from google.protobuf.internal import containers as _containers
from google.protobuf.internal import enum_type_wrapper as _enum_type_wrapper
from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from typing import ClassVar as _ClassVar, Iterable as _Iterable, Mapping as _Mapping, Optional as _Optional, Union as _Union

DESCRIPTOR: _descriptor.FileDescriptor

class ResponseType(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    RESPONSE_TYPE_UNSPECIFIED: _ClassVar[ResponseType]
    RESPONSE_TYPE_PROGRESS: _ClassVar[ResponseType]
    RESPONSE_TYPE_PARTIAL_RESULT: _ClassVar[ResponseType]
    RESPONSE_TYPE_COMPLETE: _ClassVar[ResponseType]
    RESPONSE_TYPE_ERROR: _ClassVar[ResponseType]

class SourceType(int, metaclass=_enum_type_wrapper.EnumTypeWrapper):
    __slots__ = ()
    SOURCE_TYPE_UNSPECIFIED: _ClassVar[SourceType]
    SOURCE_TYPE_TORRENT: _ClassVar[SourceType]
    SOURCE_TYPE_YOUTUBE: _ClassVar[SourceType]
    SOURCE_TYPE_PIPED: _ClassVar[SourceType]
    SOURCE_TYPE_INVIDIOUS: _ClassVar[SourceType]
RESPONSE_TYPE_UNSPECIFIED: ResponseType
RESPONSE_TYPE_PROGRESS: ResponseType
RESPONSE_TYPE_PARTIAL_RESULT: ResponseType
RESPONSE_TYPE_COMPLETE: ResponseType
RESPONSE_TYPE_ERROR: ResponseType
SOURCE_TYPE_UNSPECIFIED: SourceType
SOURCE_TYPE_TORRENT: SourceType
SOURCE_TYPE_YOUTUBE: SourceType
SOURCE_TYPE_PIPED: SourceType
SOURCE_TYPE_INVIDIOUS: SourceType

class SearchRequest(_message.Message):
    __slots__ = ("query", "format_filter", "min_seeders", "limit", "offset", "artist", "album", "min_bitrate", "max_size_mb")
    QUERY_FIELD_NUMBER: _ClassVar[int]
    FORMAT_FILTER_FIELD_NUMBER: _ClassVar[int]
    MIN_SEEDERS_FIELD_NUMBER: _ClassVar[int]
    LIMIT_FIELD_NUMBER: _ClassVar[int]
    OFFSET_FIELD_NUMBER: _ClassVar[int]
    ARTIST_FIELD_NUMBER: _ClassVar[int]
    ALBUM_FIELD_NUMBER: _ClassVar[int]
    MIN_BITRATE_FIELD_NUMBER: _ClassVar[int]
    MAX_SIZE_MB_FIELD_NUMBER: _ClassVar[int]
    query: str
    format_filter: str
    min_seeders: int
    limit: int
    offset: int
    artist: str
    album: str
    min_bitrate: int
    max_size_mb: int
    def __init__(self, query: _Optional[str] = ..., format_filter: _Optional[str] = ..., min_seeders: _Optional[int] = ..., limit: _Optional[int] = ..., offset: _Optional[int] = ..., artist: _Optional[str] = ..., album: _Optional[str] = ..., min_bitrate: _Optional[int] = ..., max_size_mb: _Optional[int] = ...) -> None: ...

class SearchResponse(_message.Message):
    __slots__ = ("type", "progress", "partial_result", "complete_result", "error")
    TYPE_FIELD_NUMBER: _ClassVar[int]
    PROGRESS_FIELD_NUMBER: _ClassVar[int]
    PARTIAL_RESULT_FIELD_NUMBER: _ClassVar[int]
    COMPLETE_RESULT_FIELD_NUMBER: _ClassVar[int]
    ERROR_FIELD_NUMBER: _ClassVar[int]
    type: ResponseType
    progress: ProgressUpdate
    partial_result: PartialResult
    complete_result: CompleteResult
    error: _common_pb2.Error
    def __init__(self, type: _Optional[_Union[ResponseType, str]] = ..., progress: _Optional[_Union[ProgressUpdate, _Mapping]] = ..., partial_result: _Optional[_Union[PartialResult, _Mapping]] = ..., complete_result: _Optional[_Union[CompleteResult, _Mapping]] = ..., error: _Optional[_Union[_common_pb2.Error, _Mapping]] = ...) -> None: ...

class ProgressUpdate(_message.Message):
    __slots__ = ("percent", "message")
    PERCENT_FIELD_NUMBER: _ClassVar[int]
    MESSAGE_FIELD_NUMBER: _ClassVar[int]
    percent: int
    message: str
    def __init__(self, percent: _Optional[int] = ..., message: _Optional[str] = ...) -> None: ...

class PartialResult(_message.Message):
    __slots__ = ("adapter_name", "count", "sources")
    ADAPTER_NAME_FIELD_NUMBER: _ClassVar[int]
    COUNT_FIELD_NUMBER: _ClassVar[int]
    SOURCES_FIELD_NUMBER: _ClassVar[int]
    adapter_name: str
    count: int
    sources: _containers.RepeatedCompositeFieldContainer[MusicSource]
    def __init__(self, adapter_name: _Optional[str] = ..., count: _Optional[int] = ..., sources: _Optional[_Iterable[_Union[MusicSource, _Mapping]]] = ...) -> None: ...

class CompleteResult(_message.Message):
    __slots__ = ("total_found", "search_time_ms", "ranked_sources")
    TOTAL_FOUND_FIELD_NUMBER: _ClassVar[int]
    SEARCH_TIME_MS_FIELD_NUMBER: _ClassVar[int]
    RANKED_SOURCES_FIELD_NUMBER: _ClassVar[int]
    total_found: int
    search_time_ms: int
    ranked_sources: _containers.RepeatedCompositeFieldContainer[RankedSource]
    def __init__(self, total_found: _Optional[int] = ..., search_time_ms: _Optional[int] = ..., ranked_sources: _Optional[_Iterable[_Union[RankedSource, _Mapping]]] = ...) -> None: ...

class MusicSource(_message.Message):
    __slots__ = ("id", "title", "url", "source_type", "format", "quality_score", "indexer", "magnet_link", "size_bytes", "size_formatted", "seeders", "leechers", "codec", "bitrate", "thumbnail_url", "duration_seconds")
    ID_FIELD_NUMBER: _ClassVar[int]
    TITLE_FIELD_NUMBER: _ClassVar[int]
    URL_FIELD_NUMBER: _ClassVar[int]
    SOURCE_TYPE_FIELD_NUMBER: _ClassVar[int]
    FORMAT_FIELD_NUMBER: _ClassVar[int]
    QUALITY_SCORE_FIELD_NUMBER: _ClassVar[int]
    INDEXER_FIELD_NUMBER: _ClassVar[int]
    MAGNET_LINK_FIELD_NUMBER: _ClassVar[int]
    SIZE_BYTES_FIELD_NUMBER: _ClassVar[int]
    SIZE_FORMATTED_FIELD_NUMBER: _ClassVar[int]
    SEEDERS_FIELD_NUMBER: _ClassVar[int]
    LEECHERS_FIELD_NUMBER: _ClassVar[int]
    CODEC_FIELD_NUMBER: _ClassVar[int]
    BITRATE_FIELD_NUMBER: _ClassVar[int]
    THUMBNAIL_URL_FIELD_NUMBER: _ClassVar[int]
    DURATION_SECONDS_FIELD_NUMBER: _ClassVar[int]
    id: str
    title: str
    url: str
    source_type: SourceType
    format: str
    quality_score: float
    indexer: str
    magnet_link: str
    size_bytes: int
    size_formatted: str
    seeders: int
    leechers: int
    codec: str
    bitrate: str
    thumbnail_url: str
    duration_seconds: int
    def __init__(self, id: _Optional[str] = ..., title: _Optional[str] = ..., url: _Optional[str] = ..., source_type: _Optional[_Union[SourceType, str]] = ..., format: _Optional[str] = ..., quality_score: _Optional[float] = ..., indexer: _Optional[str] = ..., magnet_link: _Optional[str] = ..., size_bytes: _Optional[int] = ..., size_formatted: _Optional[str] = ..., seeders: _Optional[int] = ..., leechers: _Optional[int] = ..., codec: _Optional[str] = ..., bitrate: _Optional[str] = ..., thumbnail_url: _Optional[str] = ..., duration_seconds: _Optional[int] = ...) -> None: ...

class RankedSource(_message.Message):
    __slots__ = ("rank", "source", "explanation", "tags")
    RANK_FIELD_NUMBER: _ClassVar[int]
    SOURCE_FIELD_NUMBER: _ClassVar[int]
    EXPLANATION_FIELD_NUMBER: _ClassVar[int]
    TAGS_FIELD_NUMBER: _ClassVar[int]
    rank: int
    source: MusicSource
    explanation: str
    tags: _containers.RepeatedScalarFieldContainer[str]
    def __init__(self, rank: _Optional[int] = ..., source: _Optional[_Union[MusicSource, _Mapping]] = ..., explanation: _Optional[str] = ..., tags: _Optional[_Iterable[str]] = ...) -> None: ...

class SearchStatsRequest(_message.Message):
    __slots__ = ("start_time", "end_time")
    START_TIME_FIELD_NUMBER: _ClassVar[int]
    END_TIME_FIELD_NUMBER: _ClassVar[int]
    start_time: int
    end_time: int
    def __init__(self, start_time: _Optional[int] = ..., end_time: _Optional[int] = ...) -> None: ...

class SearchStatsResponse(_message.Message):
    __slots__ = ("total_searches", "total_results_returned", "average_search_time_ms", "searches_by_adapter")
    class SearchesByAdapterEntry(_message.Message):
        __slots__ = ("key", "value")
        KEY_FIELD_NUMBER: _ClassVar[int]
        VALUE_FIELD_NUMBER: _ClassVar[int]
        key: str
        value: int
        def __init__(self, key: _Optional[str] = ..., value: _Optional[int] = ...) -> None: ...
    TOTAL_SEARCHES_FIELD_NUMBER: _ClassVar[int]
    TOTAL_RESULTS_RETURNED_FIELD_NUMBER: _ClassVar[int]
    AVERAGE_SEARCH_TIME_MS_FIELD_NUMBER: _ClassVar[int]
    SEARCHES_BY_ADAPTER_FIELD_NUMBER: _ClassVar[int]
    total_searches: int
    total_results_returned: int
    average_search_time_ms: float
    searches_by_adapter: _containers.ScalarMap[str, int]
    def __init__(self, total_searches: _Optional[int] = ..., total_results_returned: _Optional[int] = ..., average_search_time_ms: _Optional[float] = ..., searches_by_adapter: _Optional[_Mapping[str, int]] = ...) -> None: ...
