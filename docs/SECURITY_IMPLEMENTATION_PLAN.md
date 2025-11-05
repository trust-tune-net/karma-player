# TrustTune API Security Implementation Plan

**Version:** 1.0
**Date:** 2025-11-05
**Status:** In Progress

---

## Overview

This document outlines the phased approach to securing the TrustTune API and implementing comprehensive authentication, abuse protection, and analytics infrastructure.

### Goals
- ✅ **Privacy-First:** No user accounts, automatic device authentication
- ✅ **Self-Hostable:** Users can run their own instances with their own secrets
- ✅ **Open Source Compatible:** Security through proper secrets management, not code obscurity
- ✅ **Abuse Protection:** Rate limiting, IP bans, graceful degradation
- ✅ **Observable:** Usage analytics, device tracking, admin controls

### Architecture Decision
- **Phase 0:** HMAC API Key authentication (device_id + server salt)
- **Phase 1:** gRPC/Protobuf protocol migration + Redis infrastructure
- **Phase 2:** Web admin panel for device/IP management
- **Phase 3:** Federation security (future P2P features)

---

## Phase 0: Emergency Security (Week 1 - Days 1-7)

**Goal:** Close critical security holes immediately with HMAC authentication

### Backend (Python/FastAPI)

#### Security Fixes
- [ ] **CRITICAL:** Rotate Jackett API key immediately
  - Generate new key in Jackett instance
  - Update `JACKETT_REMOTE_API_KEY` in Easypanel environment
  - Test connectivity before proceeding

- [ ] **CRITICAL:** Add `API_SECRET_SALT` to Easypanel
  - Generate: `python -c "import secrets; print(secrets.token_urlsafe(32))"`
  - Add to environment variables
  - Document in `.env.example` (without actual value)

- [ ] Remove hardcoded credentials from all files
  - Files to clean:
    - `karma_player/api/server.py` (lines 50-51)
    - `karma_player/api/search_api.py`
    - `karma_player/config.py`
    - `.env.example` (replace with placeholders)
    - `.env.production` (replace with placeholders)
    - `docker-compose.yml` (use ${} syntax only)
    - All test files
    - README.md and docs
  - Use `os.getenv()` exclusively, no defaults with real credentials

#### Authentication Implementation

- [ ] Create `karma_player/api/auth.py`
  - `generate_hmac_key(device_id: str, salt: str) -> str`
  - `validate_api_key(device_id: str, api_key: str, salt: str) -> bool`
  - Use HMAC-SHA256 algorithm
  - Return 32-character hex string

- [ ] Create `karma_player/api/middleware.py`
  - Authentication middleware/dependency
  - Extract `X-API-Key` and `X-Device-ID` headers
  - Validate using HMAC function
  - Raise `HTTPException(401)` if invalid
  - Allow `/health` endpoint to bypass auth

- [ ] Modify `karma_player/api/server.py`
  - Import auth dependency
  - Add to all protected endpoints: `Depends(verify_api_key)`
  - Protect:
    - `/api/search` (POST)
    - `/ws/search` (WebSocket)
    - `/api/download` (POST)
    - `/api/downloads` (GET)
    - `/api/download/{id}` (GET, DELETE)
  - Keep public: `/health`, `/` (root)

#### Rate Limiting

- [ ] Install `slowapi`
  - `poetry add slowapi`
  - Import and initialize in `server.py`

- [ ] Configure limits
  - Search endpoint: 100 requests/hour per device
  - Download endpoint: 50 requests/hour per device
  - Use `X-Device-ID` header as key
  - Return 429 with `Retry-After` header

#### CORS Restriction

- [ ] Update CORS middleware in `server.py`
  - Option A: Keep `allow_origins=["*"]` but require auth header
  - Option B: Restrict to specific origins for official API
  - Decision: **Option A** (authentication provides security)

#### Logging

- [ ] Add request logging middleware
  - Log: timestamp, device_id, endpoint, status_code, IP address
  - Use Python `logging` module
  - Format: JSON for easy parsing
  - Log to stdout (captured by Docker/Easypanel)

### Frontend (Flutter/Dart)

#### Device Identity

- [ ] Create `gui/lib/services/device_service.dart`
  - `generateDeviceId() -> String` (UUID v4)
  - `getDeviceId() -> Future<String>` (from SharedPreferences)
  - `ensureDeviceId() -> Future<String>` (generate if not exists)
  - Store key: `device_id`

#### Authentication

- [ ] Create `gui/lib/services/api_auth_service.dart`
  - Import `crypto` package for HMAC
  - `generateApiKey(String deviceId) -> String`
  - Hardcode salt temporarily (will be replaced in Phase 1)
  - Use same algorithm as backend (HMAC-SHA256)

- [ ] Modify `gui/lib/services/app_settings.dart`
  - Add `getApiKey() -> Future<String>` method
  - Call `DeviceService.ensureDeviceId()` on init
  - Cache device_id and api_key

#### HTTP Client Updates

- [ ] Find all HTTP request locations:
  - `gui/lib/screens/search_screen.dart`
  - Any other files with `http.post()` or `http.get()`

- [ ] Add headers to all requests:
  ```dart
  headers: {
    'Content-Type': 'application/json',
    'X-API-Key': await apiAuthService.getApiKey(),
    'X-Device-ID': await deviceService.getDeviceId(),
  }
  ```

#### WebSocket Updates

- [ ] Update WebSocket connection in `search_screen.dart`
  - Send auth in initial connection message:
  ```dart
  _channel = WebSocketChannel.connect(
    Uri.parse('$wsUrl/ws/search'),
  );
  _channel!.sink.add(json.encode({
    'auth': {
      'device_id': deviceId,
      'api_key': apiKey,
    },
    'query': searchQuery,
  }));
  ```

- [ ] Update backend WebSocket handler to validate auth from first message

#### Environment Configuration

- [ ] Create `gui/lib/config/environment.dart`
  ```dart
  class Environment {
    static const String apiUrl = String.fromEnvironment(
      'API_URL',
      defaultValue: 'https://trust-tune-trust-tune-community-api.62ickh.easypanel.host',
    );

    static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  }
  ```

- [ ] Update build scripts for environment-based compilation:
  - Production: `flutter build macos --dart-define=API_URL=https://official-api.trusttune.io`
  - Development: Default to localhost or staging

- [ ] Modify `app_settings.dart` to use environment default
  - Keep setting editable for self-hosting users
  - Add "Reset to default" button in UI

#### Error Handling

- [ ] Handle 401/403 responses
  - Show user-friendly error: "Unable to authenticate with API. Please check your connection."
  - For self-hosters: "API authentication failed. Verify your API configuration."
  - Log error details for debugging

- [ ] Handle 429 (rate limit) responses
  - Show: "Too many requests. Please try again in X minutes."
  - Parse `Retry-After` header if available

### Testing Checklist

- [ ] **Backend Unit Tests**
  - HMAC key generation produces consistent output
  - HMAC validation works with correct key
  - HMAC validation rejects incorrect key
  - Auth middleware blocks requests without headers
  - Auth middleware allows requests with valid headers

- [ ] **Integration Tests**
  - Unauthenticated request to `/api/search` returns 401
  - Authenticated request to `/api/search` returns 200
  - WebSocket connection without auth is rejected
  - WebSocket connection with auth succeeds
  - Rate limiting triggers after N requests

- [ ] **Frontend Tests**
  - Device ID is generated on first launch
  - Device ID persists across app restarts
  - API key is generated correctly
  - HTTP requests include auth headers
  - 401 responses show error message

- [ ] **End-to-End Tests**
  - Fresh install → device_id generated → search works
  - Existing install → device_id persisted → search still works
  - Invalid API key → search fails with clear error
  - Rate limit exceeded → error message shown

### Deployment

- [ ] Update Easypanel environment variables
  - Add `API_SECRET_SALT`
  - Update `JACKETT_REMOTE_API_KEY`
  - Restart service

- [ ] Update documentation
  - `docs/DEPLOYMENT.md` - Add security setup section
  - `README.md` - Mention authentication requirement
  - `.env.example` - Document new variables

- [ ] Create migration guide for existing users
  - Official hosted API: Automatic (just update app)
  - Self-hosters: Need to set `API_SECRET_SALT` env var

---

## Phase 1: Protocol Migration + Infrastructure (Weeks 2-4)

### 1A: gRPC/Protobuf Foundation (Week 2)

#### Protocol Definition

- [ ] Install protobuf tools
  - Backend: `poetry add grpcio grpcio-tools`
  - Frontend: Add to `pubspec.yaml`: `grpc`, `protobuf`

- [ ] Create `karma_player/proto/` directory

- [ ] Define `karma_player/proto/search.proto`
  ```protobuf
  syntax = "proto3";

  package trusttune.search;

  service SearchService {
    rpc Search(SearchRequest) returns (stream SearchResult);
    rpc GetSearchStatus(SearchStatusRequest) returns (SearchStatus);
  }

  message SearchRequest {
    string device_id = 1;
    string query = 2;
    optional string format_filter = 3;
    int32 min_seeders = 4;
    int32 limit = 5;
  }

  message SearchResult {
    string id = 1;
    string title = 2;
    string artist = 3;
    string album = 4;
    int32 seeders = 5;
    string magnet_link = 6;
    // ... other fields
  }
  ```

- [ ] Define `karma_player/proto/download.proto`
  ```protobuf
  service DownloadService {
    rpc StartDownload(DownloadRequest) returns (DownloadResponse);
    rpc GetDownloads(GetDownloadsRequest) returns (DownloadsList);
    rpc GetDownloadStatus(DownloadStatusRequest) returns (Download);
    rpc DeleteDownload(DeleteDownloadRequest) returns (DeleteResponse);
  }
  ```

- [ ] Define `karma_player/proto/common.proto`
  - Common message types (Status, Error, etc.)

- [ ] Generate Python stubs
  ```bash
  python -m grpc_tools.protoc \
    -I karma_player/proto \
    --python_out=karma_player/proto \
    --grpc_python_out=karma_player/proto \
    karma_player/proto/*.proto
  ```

- [ ] Generate Dart stubs
  ```bash
  protoc --dart_out=grpc:gui/lib/proto \
    -I karma_player/proto \
    karma_player/proto/*.proto
  ```

#### Backend gRPC Server

- [ ] Create `karma_player/api/grpc_server.py`
  - Import generated stubs
  - Implement `SearchServiceServicer`
  - Implement `DownloadServiceServicer`
  - Port logic from existing FastAPI endpoints

- [ ] Create gRPC authentication interceptor
  - Extract metadata: `device_id`, `api_key`
  - Validate using existing HMAC function
  - Reject unauthenticated requests

- [ ] Run gRPC server alongside FastAPI
  - Different port (e.g., 50051 for gRPC, 3000 for HTTP)
  - Share same FastAPI app context (search_service, etc.)
  - Use `asyncio` to run both servers

- [ ] Update `docker-compose.yml`
  - Expose both ports: 3000 (HTTP) and 50051 (gRPC)

#### Frontend gRPC Client

- [ ] Create `gui/lib/services/grpc_client.dart`
  - Initialize gRPC channel
  - Create service stubs (SearchServiceClient, DownloadServiceClient)
  - Add metadata interceptor for auth:
  ```dart
  final channel = ClientChannel(
    'api.trusttune.io',
    port: 50051,
    options: ChannelOptions(
      credentials: ChannelCredentials.secure(),
    ),
  );

  final options = CallOptions(metadata: {
    'device_id': deviceId,
    'api_key': apiKey,
  });
  ```

- [ ] Create `gui/lib/services/search_service_grpc.dart`
  - Wrapper around gRPC SearchService
  - Method: `Stream<SearchResult> search(String query)`
  - Handle streaming results

- [ ] Update `search_screen.dart`
  - Replace WebSocket with gRPC streaming
  - Listen to stream: `await for (var result in searchStream) { ... }`
  - Handle errors and connection issues

- [ ] Implement fallback mechanism
  - Try gRPC first
  - If gRPC fails (timeout, connection error), fall back to HTTP
  - Log fallback events for monitoring

#### Testing

- [ ] Test gRPC search endpoint
  - Streaming results work
  - Authentication required
  - Results match HTTP API

- [ ] Test gRPC download endpoints
  - All CRUD operations work
  - Matches HTTP behavior

- [ ] Test fallback logic
  - Simulate gRPC failure
  - Verify HTTP fallback works

### 1B: Redis Infrastructure (Week 3)

#### Redis Setup

- [ ] Add Redis to `docker-compose.yml`
  ```yaml
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
  ```

- [ ] Configure Redis in Easypanel
  - Option A: Add Redis service in same project
  - Option B: Use managed Redis (Upstash, Redis Cloud)
  - Document connection string format

- [ ] Install Redis client
  - `poetry add redis aioredis`

- [ ] Create `karma_player/api/redis_client.py`
  ```python
  from redis.asyncio import Redis

  redis_client: Optional[Redis] = None

  async def init_redis():
      global redis_client
      redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")
      redis_client = await Redis.from_url(redis_url)

  async def close_redis():
      if redis_client:
          await redis_client.close()
  ```

- [ ] Update `server.py` lifespan
  - Call `init_redis()` on startup
  - Call `close_redis()` on shutdown

#### Device Registry

- [ ] Create `karma_player/api/device_registry.py`

- [ ] Implement device registration
  ```python
  async def register_device(device_id: str, metadata: dict):
      key = f"device:{device_id}"
      data = {
          "first_seen": datetime.now().isoformat(),
          "last_seen": datetime.now().isoformat(),
          "total_requests": 0,
          **metadata
      }
      await redis_client.hset(key, mapping=data)
  ```

- [ ] Implement device stats tracking
  ```python
  async def increment_request_count(device_id: str):
      await redis_client.hincrby(f"device:{device_id}", "total_requests", 1)
      await redis_client.hset(f"device:{device_id}", "last_seen", datetime.now().isoformat())
  ```

- [ ] Add to authentication middleware
  - After successful auth, call `increment_request_count(device_id)`
  - Auto-register new devices on first request

- [ ] Create device info retrieval
  ```python
  async def get_device_info(device_id: str) -> dict:
      return await redis_client.hgetall(f"device:{device_id}")

  async def list_all_devices() -> list:
      keys = await redis_client.keys("device:*")
      # Return list of device IDs
  ```

#### Rate Limiting with Redis

- [ ] Create `karma_player/api/rate_limiter.py`

- [ ] Implement sliding window rate limiter
  ```python
  async def check_rate_limit(device_id: str, limit: int, window: int) -> bool:
      key = f"ratelimit:{device_id}:{int(time.time() // window)}"
      current = await redis_client.incr(key)
      if current == 1:
          await redis_client.expire(key, window)
      return current <= limit
  ```

- [ ] Create rate limit middleware
  - Check before processing request
  - Return 429 if exceeded
  - Different limits per endpoint type:
    - Search: 100/hour
    - Download: 50/hour
    - General: 1000/hour

- [ ] Remove `slowapi` dependency
  - Replace with Redis-backed limiter

#### Abuse Protection

- [ ] Create `karma_player/api/abuse_protection.py`

- [ ] Implement ban system
  ```python
  async def ban_device(device_id: str, reason: str, duration: Optional[int] = None):
      await redis_client.sadd("banned:devices", device_id)
      await redis_client.hset(f"ban:{device_id}", mapping={
          "reason": reason,
          "banned_at": datetime.now().isoformat(),
          "duration": duration
      })

  async def is_device_banned(device_id: str) -> bool:
      return await redis_client.sismember("banned:devices", device_id)
  ```

- [ ] Implement IP ban system
  ```python
  async def ban_ip(ip: str, duration: int = 3600):
      await redis_client.setex(f"banned:ip:{ip}", duration, "1")

  async def is_ip_banned(ip: str) -> bool:
      return await redis_client.exists(f"banned:ip:{ip}")
  ```

- [ ] Track failed authentication attempts
  ```python
  async def record_auth_failure(ip: str):
      key = f"auth_failures:{ip}"
      count = await redis_client.incr(key)
      await redis_client.expire(key, 3600)  # 1 hour window

      if count >= 10:
          await ban_ip(ip, duration=3600)  # 1 hour ban
  ```

- [ ] Add ban checks to auth middleware
  - Check IP ban first (fastest)
  - Check device ban second
  - Return 403 with reason if banned

- [ ] Implement graceful degradation (tarpit)
  ```python
  async def should_tarpit(ip: str) -> int:
      key = f"suspicious:{ip}"
      score = await redis_client.get(key)
      if score and int(score) > 5:
          return min(int(score) * 2, 30)  # Max 30 second delay
      return 0

  async def add_suspicious_activity(ip: str):
      key = f"suspicious:{ip}"
      await redis_client.incr(key)
      await redis_client.expire(key, 86400)  # 24 hour window
  ```

- [ ] Apply tarpit in middleware
  - Calculate delay for suspicious IPs
  - `await asyncio.sleep(delay)` before processing
  - Log tarpit events

#### Analytics & Logging

- [ ] Create `karma_player/api/analytics.py`

- [ ] Log all requests to Redis streams
  ```python
  async def log_request(event: dict):
      await redis_client.xadd("analytics:requests", event, maxlen=100000)
  ```

- [ ] Event schema:
  ```python
  {
      "timestamp": datetime.now().isoformat(),
      "device_id": "...",
      "endpoint": "/api/search",
      "method": "POST",
      "status_code": 200,
      "ip": "...",
      "user_agent": "...",
      "response_time_ms": 123
  }
  ```

- [ ] Create aggregation functions
  ```python
  async def get_daily_stats(date: str) -> dict:
      # Aggregate from stream
      return {
          "total_requests": 0,
          "unique_devices": 0,
          "searches": 0,
          "downloads": 0,
          "errors": 0
      }
  ```

- [ ] Add analytics middleware
  - Record request start time
  - Log event after response
  - Non-blocking (fire and forget)

#### Testing

- [ ] Test device registration
  - New device is registered automatically
  - Stats increment correctly
  - Last seen updates

- [ ] Test rate limiting
  - Exceeding limit returns 429
  - Different endpoints have different limits
  - Sliding window works correctly

- [ ] Test ban system
  - Banned device cannot access API
  - Banned IP cannot access API
  - Auto-ban after failed auth attempts

- [ ] Test graceful degradation
  - Suspicious activity triggers delays
  - Delays increase with score

- [ ] Test analytics logging
  - Events are recorded
  - Aggregation functions work

### 1C: Environment & Configuration (Week 4)

- [ ] Update `.env.example`
  ```bash
  # Redis
  REDIS_URL=redis://localhost:6379

  # Security
  API_SECRET_SALT=<generate_with_secrets.token_urlsafe(32)>

  # Rate Limits
  RATE_LIMIT_SEARCH_PER_HOUR=100
  RATE_LIMIT_DOWNLOAD_PER_HOUR=50

  # Jackett (use your own instance)
  JACKETT_URL=https://your-jackett.example.com
  JACKETT_API_KEY=your_api_key_here
  ```

- [ ] Create `karma_player/config.py` refactor
  - Centralize all config loading
  - Validate required env vars on startup
  - Provide clear error messages for missing config

- [ ] Update documentation
  - `docs/DEPLOYMENT.md` - Redis setup instructions
  - `docs/SECURITY.md` - New file for security documentation
  - `README.md` - Update with new requirements

---

## Phase 2: Web Admin Panel (Weeks 5-6)

### Admin Authentication

- [ ] Create admin API key system
  - Generate: `python -c "import secrets; print(secrets.token_urlsafe(32))"`
  - Store in `ADMIN_API_KEY` env var
  - Different from device API keys

- [ ] Create admin auth dependency
  ```python
  async def verify_admin(authorization: str = Header(...)):
      if not authorization.startswith("Bearer "):
          raise HTTPException(401)
      token = authorization[7:]
      if token != os.getenv("ADMIN_API_KEY"):
          raise HTTPException(403)
  ```

### Admin API Endpoints

- [ ] Create `karma_player/api/admin.py`

- [ ] Device management endpoints
  ```python
  @router.get("/admin/devices")
  async def list_devices(admin=Depends(verify_admin)):
      # Return all registered devices

  @router.get("/admin/device/{device_id}")
  async def get_device(device_id: str, admin=Depends(verify_admin)):
      # Return device details + stats

  @router.post("/admin/device/{device_id}/ban")
  async def ban_device_endpoint(device_id: str, request: BanRequest, admin=Depends(verify_admin)):
      # Ban device with reason

  @router.delete("/admin/device/{device_id}/ban")
  async def unban_device(device_id: str, admin=Depends(verify_admin)):
      # Remove device from ban list
  ```

- [ ] IP management endpoints
  ```python
  @router.get("/admin/ips/banned")
  async def list_banned_ips(admin=Depends(verify_admin)):
      # Return all banned IPs

  @router.post("/admin/ip/{ip}/ban")
  async def ban_ip_endpoint(ip: str, duration: int, admin=Depends(verify_admin)):
      # Ban IP with TTL

  @router.delete("/admin/ip/{ip}/ban")
  async def unban_ip(ip: str, admin=Depends(verify_admin)):
      # Remove IP from ban list
  ```

- [ ] Analytics endpoints
  ```python
  @router.get("/admin/stats/overview")
  async def get_overview(admin=Depends(verify_admin)):
      return {
          "total_devices": await count_devices(),
          "active_devices_24h": await count_active_devices(hours=24),
          "total_requests_today": await count_requests_today(),
          "searches_today": await count_searches_today(),
          "downloads_today": await count_downloads_today()
      }

  @router.get("/admin/stats/timeline")
  async def get_timeline(days: int = 7, admin=Depends(verify_admin)):
      # Return daily stats for last N days

  @router.get("/admin/activity/recent")
  async def get_recent_activity(limit: int = 100, admin=Depends(verify_admin)):
      # Return recent requests from Redis stream
  ```

### Web Interface (Simple HTML/JS)

- [ ] Create `admin/` directory in project root

- [ ] Create `admin/index.html`
  - Simple single-page app
  - Vanilla JS or lightweight framework (Alpine.js?)
  - Tailwind CSS for styling

- [ ] Create sections:
  - **Dashboard:** Overview stats, charts
  - **Devices:** List, search, view details, ban/unban
  - **IPs:** List banned IPs, add/remove
  - **Activity:** Recent request log
  - **Settings:** Configure rate limits (future)

- [ ] Implement device list view
  - Table with: device_id, first_seen, last_seen, total_requests
  - Search/filter by device_id
  - Click device → see details
  - Ban/unban buttons

- [ ] Implement stats dashboard
  - Chart.js for visualizations
  - Line chart: requests over time
  - Pie chart: searches vs downloads
  - Live update (poll API every 30s)

- [ ] Implement activity log
  - Real-time feed of recent requests
  - Filter by device, endpoint, status
  - Pagination

- [ ] Authentication
  - Login page (ask for admin API key)
  - Store in sessionStorage
  - Send as `Authorization: Bearer <key>` header

- [ ] Serve admin interface
  - Option A: FastAPI static files (`app.mount("/admin", StaticFiles(...))`)
  - Option B: Separate subdomain (admin.trusttune.io)
  - Option C: Don't build web UI, use CLI tool instead

### CLI Admin Tool (Alternative to Web UI)

- [ ] Create `karma_player/cli/admin.py`
  - Click-based CLI
  - Commands:
    - `karma-admin devices list`
    - `karma-admin device <id> show`
    - `karma-admin device <id> ban --reason "abuse"`
    - `karma-admin device <id> unban`
    - `karma-admin stats overview`
    - `karma-admin stats timeline --days 7`

### Testing

- [ ] Test admin authentication
  - Invalid key returns 403
  - Valid key grants access

- [ ] Test device management
  - List devices works
  - Ban/unban works
  - Stats are accurate

- [ ] Test analytics endpoints
  - Overview stats are correct
  - Timeline data matches reality

### Documentation

- [ ] Create `docs/ADMIN.md`
  - How to set up admin access
  - How to use admin endpoints/UI
  - Common tasks (banning devices, viewing stats)

- [ ] Update deployment docs
  - Set `ADMIN_API_KEY` in production
  - How to access admin panel

---

## Phase 3: Future Enhancements (Backlog)

### Federation Security (P2P Network)

- [ ] Research decentralized identity (DID) standards
- [ ] Implement node-to-node authentication
- [ ] Design trust network cryptography
- [ ] Implement reputation system
- [ ] Create node discovery protocol

### Advanced Features

- [ ] API key rotation mechanism
  - Generate new keys periodically
  - Support multiple active keys (transition period)
  - Revoke old keys

- [ ] Multi-device support per user
  - Optional user accounts
  - Link multiple devices to one account
  - Shared quotas

- [ ] Usage quotas
  - Free tier: 100 searches/day
  - Premium tier: unlimited (self-hosted)
  - Soft limits with warnings

- [ ] OAuth2 integration
  - Third-party app support
  - Scope-based permissions
  - Token management

- [ ] End-to-end encryption
  - Optional "paranoia mode"
  - Encrypt search queries client-side
  - Server processes encrypted data (homomorphic?)

### Monitoring & Observability

- [ ] Prometheus metrics endpoint
- [ ] Grafana dashboards
- [ ] Alert rules (high error rate, abuse patterns)
- [ ] Distributed tracing (OpenTelemetry)

---

## Security Best Practices Checklist

### Code Security
- [ ] No hardcoded secrets in code
- [ ] All secrets via environment variables
- [ ] Secrets documented in `.env.example` (no actual values)
- [ ] `.gitignore` includes `.env*` (except `.env.example`)
- [ ] Input validation on all endpoints
- [ ] SQL injection prevention (not applicable - no SQL)
- [ ] XSS prevention (not applicable - no HTML rendering)

### Infrastructure Security
- [ ] HTTPS only (TLS 1.2+)
- [ ] Environment variables encrypted at rest (Easypanel feature)
- [ ] Redis password protected (if exposed)
- [ ] Non-root user in Docker
- [ ] Minimal Docker image (alpine)
- [ ] Regular dependency updates

### Operational Security
- [ ] Admin API key rotated regularly
- [ ] Logs monitored for abuse
- [ ] Banned devices reviewed periodically
- [ ] Backup and disaster recovery plan
- [ ] Incident response plan

### Privacy
- [ ] No PII collected (only device_id)
- [ ] Search queries not stored permanently
- [ ] Analytics data anonymized
- [ ] GDPR-compliant data retention
- [ ] User can request data deletion (device_id wipe)

---

## Testing Strategy

### Unit Tests
- Authentication functions
- Rate limiter logic
- Ban system
- HMAC generation/validation

### Integration Tests
- API endpoints with auth
- WebSocket with auth
- gRPC services
- Redis operations

### End-to-End Tests
- Full user flows
- Device registration → search → download
- Rate limit exceeded → ban → unban
- Admin operations

### Load Tests
- 1000 concurrent users
- Rate limiter under load
- Redis performance
- gRPC streaming performance

### Security Tests
- Penetration testing
- Auth bypass attempts
- Rate limit bypass attempts
- SQL injection (N/A)
- XSS (N/A)

---

## Deployment Checklist

### Pre-Deployment
- [ ] All tests passing
- [ ] Flutter analyze clean
- [ ] No hardcoded secrets
- [ ] Documentation updated
- [ ] Changelog updated

### Environment Setup
- [ ] `API_SECRET_SALT` set
- [ ] `ADMIN_API_KEY` set
- [ ] `JACKETT_URL` and `JACKETT_API_KEY` set
- [ ] `REDIS_URL` set
- [ ] All required env vars validated

### Deployment Steps
1. [ ] Deploy backend (Easypanel/Railway)
2. [ ] Verify health check
3. [ ] Test auth endpoint manually
4. [ ] Deploy admin panel (if applicable)
5. [ ] Build and release Flutter apps
6. [ ] Update documentation
7. [ ] Announce to users

### Post-Deployment
- [ ] Monitor logs for errors
- [ ] Check analytics dashboard
- [ ] Verify user devices registering
- [ ] Monitor Redis memory usage
- [ ] Check rate limiting working

---

## Migration Guide for Existing Users

### Official Hosted API Users
- Simply update to latest TrustTune app version
- Device ID generated automatically
- No action required

### Self-Hosters
1. Pull latest code
2. Add `API_SECRET_SALT` to environment
   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   ```
3. Add Redis to `docker-compose.yml` or use managed service
4. Restart services
5. Update TrustTune app on client devices

---

## Reference

### Key Files Created/Modified

**Phase 0:**
- `docs/SECURITY_IMPLEMENTATION_PLAN.md` (this file)
- `karma_player/api/auth.py` (new)
- `karma_player/api/middleware.py` (new)
- `karma_player/api/server.py` (modified)
- `gui/lib/services/device_service.dart` (new)
- `gui/lib/services/api_auth_service.dart` (new)
- `gui/lib/config/environment.dart` (new)

**Phase 1:**
- `karma_player/proto/*.proto` (new)
- `karma_player/api/grpc_server.py` (new)
- `karma_player/api/redis_client.py` (new)
- `karma_player/api/device_registry.py` (new)
- `karma_player/api/rate_limiter.py` (new)
- `karma_player/api/abuse_protection.py` (new)
- `karma_player/api/analytics.py` (new)
- `gui/lib/services/grpc_client.dart` (new)

**Phase 2:**
- `karma_player/api/admin.py` (new)
- `admin/index.html` (new - if web UI chosen)
- `karma_player/cli/admin.py` (new - if CLI chosen)

### Dependencies Added

**Python:**
- `slowapi` (Phase 0 - temporary, replaced in Phase 1)
- `grpcio`, `grpcio-tools` (Phase 1)
- `redis`, `aioredis` (Phase 1)

**Dart/Flutter:**
- `crypto` (Phase 0)
- `grpc`, `protobuf` (Phase 1)

### Environment Variables

```bash
# Security
API_SECRET_SALT=<secrets.token_urlsafe(32)>
ADMIN_API_KEY=<secrets.token_urlsafe(32)>

# Redis
REDIS_URL=redis://localhost:6379

# Jackett (self-hosters)
JACKETT_URL=https://your-jackett-instance.com
JACKETT_API_KEY=your_key_here

# Rate Limits (optional)
RATE_LIMIT_SEARCH_PER_HOUR=100
RATE_LIMIT_DOWNLOAD_PER_HOUR=50

# AI (optional)
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
```

---

## Questions & Decisions Log

**Q:** Should we use HMAC or JWT for Phase 0?
**A:** HMAC - simpler, no token expiration needed for desktop app

**Q:** Should API URL be editable?
**A:** Yes, environment-based (locked in prod builds, editable for dev)

**Q:** When to migrate to Protobuf?
**A:** Phase 1 alongside Redis infrastructure

**Q:** How to handle abuse?
**A:** Multi-layered: rate limiting + IP bans + graceful degradation + logging + manual review via admin panel

**Q:** Web UI or CLI for admin?
**A:** TBD - both options documented, decide during Phase 2

---

## Success Criteria

### Phase 0 Complete When:
- ✅ All API endpoints require authentication
- ✅ Desktop app automatically generates device_id and API key
- ✅ Unauthenticated requests return 401
- ✅ Rate limiting works (100 req/hour)
- ✅ No secrets in code/git
- ✅ Self-hosters can set their own salt

### Phase 1 Complete When:
- ✅ gRPC endpoints functional alongside HTTP
- ✅ Redis stores device registry
- ✅ Rate limiting uses Redis (sliding window)
- ✅ Ban system works (device + IP)
- ✅ Analytics events logged
- ✅ Auto-ban after 10 failed auth attempts

### Phase 2 Complete When:
- ✅ Admin can view all devices
- ✅ Admin can ban/unban devices
- ✅ Admin can view usage statistics
- ✅ Admin can view recent activity
- ✅ Admin panel secured with separate API key

### Phase 3 Complete When:
- ✅ Federation security implemented (if/when P2P launches)
- ✅ Advanced features as needed

---

## Contact & Support

For questions about this implementation plan:
- Refer to this document first
- Check `docs/DEPLOYMENT.md` for environment setup
- Check `docs/SECURITY.md` for security details (created in Phase 1)
- Check `docs/ADMIN.md` for admin operations (created in Phase 2)

---

**Last Updated:** 2025-11-05
**Status:** Phase 0 in progress
