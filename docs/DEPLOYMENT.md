# TrustTune Backend API - Deployment Guide

## Architecture Overview

TrustTune uses a **split-service architecture** optimized for security, scalability, and legal safety:

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENT SIDE                           │
│  ┌────────────────────┐     ┌──────────────────────────┐   │
│  │  Flutter Desktop   │────▶│  Download Daemon (Local)  │   │
│  │  App (GUI)         │     │  - Runs on user's machine │   │
│  └────────────────────┘     │  - Handles torrent downloads│ │
│            │                │  - File access allowed     │   │
│            │                └──────────────────────────┘   │
└────────────┼────────────────────────────────────────────────┘
             │
             │ HTTP/WebSocket
             │
┌────────────▼────────────────────────────────────────────────┐
│                      CLOUD (DEPLOYMENT)                      │
│  ┌────────────────────────────────────────────────────┐     │
│  │  Search API (Stateless)                            │     │
│  │  - Music search ONLY                               │     │
│  │  - NO file downloads                               │     │
│  │  - NO local file access                            │     │
│  │  - Returns magnet links + metadata                 │     │
│  │  - Scalable & legally safe                         │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### Service Roles

| Service | Location | Purpose | Deploys To |
|---------|----------|---------|------------|
| **search_api.py** | Cloud | Search ONLY (stateless) | Easypanel, Railway, Render |
| **download_daemon.py** | Client | Downloads (bundled with Flutter) | User's machine |
| **server.py** | Development | Both search + downloads | Local dev only |

---

## Quick Start - Deploy to Cloud

### Prerequisites

1. **Jackett instance** (torrent indexer aggregator)
   - Self-hosted: https://github.com/Jackett/Jackett
   - Or use shared demo instance (see `.env.production`)

2. **AI API keys** (optional but recommended)
   - OpenAI: https://platform.openai.com/api-keys
   - Anthropic: https://console.anthropic.com/

3. **MusicBrainz API key** (optional - for metadata)
   - Get one at: https://musicbrainz.org/

---

## Deployment Options

### Option 1: Easypanel (Recommended)

**Why Easypanel?**
- Simple Docker deployment
- Built-in SSL
- Environment variable management
- Resource limits
- Health checks

**Steps:**

1. **Create new service** in Easypanel
2. **Connect GitHub** repository
3. **Set environment variables** (copy from `.env.production`):
   ```bash
   JACKETT_URL=https://your-jackett-instance.com
   JACKETT_API_KEY=your_api_key
   OPENAI_API_KEY=sk-...
   # ... other vars from .env.production
   ```
4. **Deploy configuration**:
   - Build Path: `/`
   - Dockerfile: `Dockerfile`
   - Port: `3000`
   - Health Check: `/health`

5. **Deploy!** Easypanel will build and start the service.

**Test deployment:**
```bash
curl https://your-app.easypanel.host/health
```

---

### Option 2: Railway

1. **Create new project** from GitHub repo
2. **Add environment variables** (see `.env.production`)
3. **Railway auto-detects** Dockerfile and deploys
4. **Set custom domain** (optional)

Railway automatically assigns a public URL.

**Test deployment:**
```bash
curl https://your-app.railway.app/health
```

---

### Option 3: Render

1. **New Web Service** → Connect GitHub
2. **Docker runtime** (auto-detected)
3. **Environment variables**:
   - Copy from `.env.production`
   - Set in Render dashboard
4. **Health check path**: `/health`
5. **Deploy!**

---

### Option 4: Fly.io

```bash
# Install flyctl
brew install flyctl  # macOS
# or: curl -L https://fly.io/install.sh | sh

# Login
flyctl auth login

# Launch app (from project root)
flyctl launch --dockerfile Dockerfile

# Set secrets (environment variables)
flyctl secrets set JACKETT_URL=https://...
flyctl secrets set JACKETT_API_KEY=your_key
flyctl secrets set OPENAI_API_KEY=sk-...

# Deploy
flyctl deploy

# Check status
flyctl status
flyctl logs
```

---

### Option 5: Self-Hosted (VPS/Dedicated Server)

**Requirements:**
- Docker & Docker Compose installed
- Domain with SSL (Let's Encrypt recommended)

**Steps:**

1. **Clone repository** on server:
   ```bash
   git clone https://github.com/trust-tune-net/karma-player.git
   cd karma-player
   ```

2. **Create `.env` file** from template:
   ```bash
   cp .env.production .env
   nano .env  # Edit with your values
   ```

3. **Build and run**:
   ```bash
   docker-compose up -d
   ```

4. **Setup reverse proxy** (Nginx example):
   ```nginx
   server {
       listen 80;
       server_name search.trusttune.com;

       location / {
           proxy_pass http://localhost:3000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
   }
   ```

5. **Setup SSL** with Certbot:
   ```bash
   sudo certbot --nginx -d search.trusttune.com
   ```

---

## Environment Variables Reference

See `.env.production` for complete list. **Required variables:**

| Variable | Required | Description |
|----------|----------|-------------|
| `JACKETT_URL` | ✅ | Your Jackett instance URL |
| `JACKETT_API_KEY` | ✅ | Jackett API key |
| `OPENAI_API_KEY` | Recommended | For AI-powered ranking |
| `ANTHROPIC_API_KEY` | Alternative | Alternative to OpenAI |

**Optional but recommended:**
- `MUSICBRAINZ_API_KEY` - Metadata enrichment
- `USE_PARTIAL_AI=true` - Balanced speed/quality

---

## Testing Deployment

### 1. Health Check
```bash
curl https://your-deployment-url/health
```

Expected response:
```json
{
  "status": "ok",
  "version": "0.1.1",
  "service": "search_api",
  "search_ready": true
}
```

### 2. Search Test (HTTP)
```bash
curl -X POST https://your-deployment-url/api/search \
  -H "Content-Type: application/json" \
  -d '{"query": "radiohead ok computer flac", "min_seeders": 5, "limit": 10}'
```

### 3. WebSocket Test
```javascript
const ws = new WebSocket('wss://your-deployment-url/ws/search');

ws.onopen = () => {
  ws.send(JSON.stringify({
    query: "radiohead ok computer flac",
    min_seeders: 5,
    limit: 10
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log(data.type, data);
};
```

---

## API Documentation

Once deployed, visit:
```
https://your-deployment-url/docs
```

This provides **interactive Swagger/OpenAPI documentation** for all endpoints.

### Available Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Service info |
| GET | `/health` | Health check |
| POST | `/api/search` | Search for music (HTTP) |
| WS | `/ws/search` | Search with real-time progress (WebSocket) |

---

## Monitoring & Logs

### Check Logs

**Easypanel/Railway/Render:**
- Use web dashboard to view logs

**Docker (self-hosted):**
```bash
docker-compose logs -f
```

**Fly.io:**
```bash
flyctl logs
```

### Health Monitoring

Set up uptime monitoring with:
- **UptimeRobot** (free): https://uptimerobot.com
- **Pingdom**
- **Better Uptime**

Monitor endpoint: `https://your-deployment-url/health`

---

## Scaling

### Horizontal Scaling

The search API is **stateless** and can be scaled horizontally:

**Easypanel/Railway:** Increase instance count in dashboard

**Docker:** Use `docker-compose scale`:
```bash
docker-compose up -d --scale search-api=3
```

**Load balancer** (Nginx):
```nginx
upstream search_api {
    server localhost:3001;
    server localhost:3002;
    server localhost:3003;
}
```

### Resource Limits

**Recommended minimum:**
- CPU: 0.25 cores
- RAM: 256MB

**Recommended for production:**
- CPU: 1 core
- RAM: 512MB

Adjust based on traffic. The API is lightweight but AI ranking uses more CPU.

---

## Security

### Best Practices

1. **Never commit `.env` files** with real API keys
2. **Use environment variables** for all secrets
3. **Enable HTTPS** (automatic with most platforms)
4. **Rate limiting** (if high traffic):
   ```python
   # Add to search_api.py
   from slowapi import Limiter
   limiter = Limiter(key_func=get_remote_address)
   ```
5. **CORS restrictions** (if needed):
   ```python
   # In search_api.py, replace:
   allow_origins=["*"]
   # With:
   allow_origins=["https://your-flutter-app.com"]
   ```

### API Key Management

**For AI keys:**
- Rotate regularly
- Use separate keys for dev/staging/prod
- Monitor usage limits

**For Jackett:**
- Run your own instance (recommended)
- Don't share API keys publicly

---

## Troubleshooting

### Common Issues

**1. "Search service not initialized"**
- Check Jackett URL is accessible
- Verify API key is correct
- Check logs for connection errors

**2. "AI ranking not working"**
- Verify `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` is set
- Check API key has credits
- Try `USE_PARTIAL_AI=true` instead of `USE_FULL_AI=true`

**3. "No results found"**
- Jackett might be down or misconfigured
- Check Jackett web UI directly
- Try lowering `MIN_SEEDERS`

**4. High memory usage**
- Reduce `MAX_TORRENTS` (default: 50)
- Disable AI ranking: `USE_PARTIAL_AI=false`
- Increase container memory limit

### Debug Mode

Enable debug logging:
```bash
DEBUG=true
LOG_LEVEL=DEBUG
```

Then check logs for detailed error messages.

---

## Cost Estimates

### Cloud Hosting (Monthly)

| Platform | Cost | Notes |
|----------|------|-------|
| **Railway** | $5-10 | 512MB RAM, 0.5 CPU |
| **Render** | $7 | Starter plan |
| **Fly.io** | $5-10 | Pay-as-you-go |
| **Easypanel** | Free tier | If self-hosting Easypanel |
| **VPS (Hetzner)** | €4.50 | Self-managed |

### API Costs

**OpenAI** (optional):
- GPT-3.5-turbo: $0.50-2/month (low-medium usage)
- Partial AI mode uses ~50% less

**Anthropic** (alternative):
- Claude-instant: Similar pricing to GPT-3.5

**MusicBrainz**: Free (rate limited without key)

**Total estimated monthly cost**: **$5-15** (including AI)

---

## Production Checklist

Before going live:

- [ ] Environment variables configured
- [ ] Health check endpoint responding
- [ ] HTTPS/SSL enabled
- [ ] Domain configured (if using custom domain)
- [ ] Uptime monitoring setup
- [ ] Logs accessible
- [ ] Tested search queries work
- [ ] WebSocket connections tested
- [ ] Resource limits set appropriately
- [ ] Backup deployment strategy (if critical)

---

## Support & Issues

**Documentation:** https://github.com/trust-tune-net/karma-player

**Issues:** https://github.com/trust-tune-net/karma-player/issues

**Discussions:** https://github.com/trust-tune-net/karma-player/discussions

---

## Next Steps

After deploying:

1. **Update Flutter app** to use your API URL
2. **Monitor performance** and adjust resources
3. **Set up analytics** (optional)
4. **Contribute back** - Share your deployment tips!

**Happy deploying! 🚀**
