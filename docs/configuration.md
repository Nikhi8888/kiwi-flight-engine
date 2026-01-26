# Configuration

## Environment variables

### Application settings

| Name | Required | Default | Used by | Description | Source |
|------|----------|---------|---------|-------------|--------|
| `KIWI_BASE_URL` | No | `https://api.skypicker.com/umbrella/v2/graphql` | `KiwiSession` | Kiwi.com GraphQL API endpoint | `src/kiwi_sdk/config.py:96` |
| `KIWI_REAL_CALL` | No | `1` | `KiwiSession` | Enable real API calls (`1`) or mock mode (`0`) | `src/kiwi_sdk/config.py:98` |
| `TIMEOUT_SECONDS` | No | `30.0` | `KiwiSession` | HTTP request timeout in seconds | `src/kiwi_sdk/config.py:99` |
| `USER_AGENT` | No | `Mozilla/5.0...` | `KiwiSession` | User agent string for HTTP requests | `src/kiwi_sdk/config.py:101` |

### Browser settings

| Name | Required | Default | Used by | Description | Source |
|------|----------|---------|---------|-------------|--------|
| `PLAYWRIGHT_WS_ENDPOINT` | Yes* | - | `Browser` | WebSocket endpoint for Playwright browser service (e.g., `ws://browser:3000`) | `src/kiwi_sdk/core/browser.py:22` |
| `BROWSER_TIMEOUT` | No | `30` | `Browser` | Max seconds to wait for GraphQL request interception | `src/kiwi_sdk/config.py:100` |

*Required when running in Docker Compose. Optional for local development with local Playwright.

### Cache configuration (in-code defaults)

| Setting | Default | Description | Source |
|---------|---------|-------------|--------|
| `search_ttl_seconds` | `600` (10 min) | Search result cache TTL | `src/kiwi_sdk/config.py:11` |
| `search_max_size` | `256` | Search result cache max entries | `src/kiwi_sdk/config.py:12` |
| `calendar_context_ttl_seconds` | `3600` (60 min) | Calendar context cache TTL | `src/kiwi_sdk/config.py:13` |
| `calendar_context_max_size` | `512` | Calendar context cache max entries | `src/kiwi_sdk/config.py:14` |
| `calendar_prices_ttl_seconds` | `3600` (60 min) | Calendar prices cache TTL | `src/kiwi_sdk/config.py:15` |
| `calendar_prices_max_size` | `512` | Calendar prices cache max entries | `src/kiwi_sdk/config.py:16` |

### Query defaults (in-code defaults)

| Setting | Default | Description | Source |
|---------|---------|-------------|--------|
| `default_currency` | `EUR` | Default currency for searches | `src/kiwi_sdk/config.py:24` |
| `default_sort` | `PRICE` | Default sort order | `src/kiwi_sdk/config.py:25` |

## Docker Compose configuration

### Service ports

| Service | Internal Port | External Port | Description |
|---------|---------------|---------------|-------------|
| `kiwi-logic` | 8000 | 8000 | FastAPI application |
| `browser` | 3000 | - (exposed only internally) | Playwright browser service |

### Volumes

| Volume | Path | Purpose |
|--------|------|---------|
| (none specified) | `/data` | Working directory for token database |

### Service dependencies

- `kiwi-logic` depends on `browser` with health check
- `browser` health check: `curl -f http://localhost:3000/`

### Resource limits

| Service | Setting | Value |
|---------|---------|-------|
| `browser` | `shm_size` | `2gb` |

## Runtime options

### CLI commands

```bash
# Start server
kiwi server [--host HOST] [--port PORT] [--reload]

# Search flights (CLI mode)
kiwi search --origin PRG --destination LHR --date 2026-05-10

# Explore flights (CLI mode)
kiwi explore --origin PRG --destination AMS --date 2026-02-15
```

### Uvicorn options

When running via `kiwi server` or directly with uvicorn:

| Option | Default | Description |
|--------|---------|-------------|
| `--host` | `0.0.0.0` | Bind address |
| `--port` | `8000` | Port number |
| `--reload` | `false` | Enable auto-reload for development |

## Configuration files

### pyproject.toml

Main project configuration defining:

- Project metadata (name, version, dependencies)
- Python requirement: `>=3.12`
- CLI entry point: `kiwi = "kiwi_sdk.cli.main:main"`
- Build configuration (hatchling)

### docker-compose.yml

Defines two services:

```yaml
services:
  kiwi-logic:
    build: .
    ports:
      - "8000:8000"
    environment:
      - PLAYWRIGHT_WS_ENDPOINT=ws://browser:3000
    depends_on:
      browser:
        condition: service_healthy

  browser:
    image: abdallahthegreatest/kiwi-browser:v1.57.0
    expose:
      - "3000"
    shm_size: "2gb"
```

### Dockerfile

Multi-stage build:

1. **Builder stage**: Python 3.12-slim with uv, installs dependencies
2. **Runtime stage**: Copy venv, set `/data` working directory, entrypoint `kiwi`

## Safety limits

### Timeouts

| Setting | Value | Description |
|---------|-------|-------------|
| `TIMEOUT_SECONDS` | 30.0 | HTTP request timeout to Kiwi API |
| `BROWSER_TIMEOUT` | 30 | Max wait for Playwright token capture |

### Circuit breaker

| Setting | Value | Description | Source |
|---------|-------|-------------|--------|
| `CIRCUIT_MAX_FAILURES` | 3 | Failures before opening circuit | `src/kiwi_sdk/api/endpoints.py:31` |
| `CIRCUIT_RESET_SECONDS` | 120 (2 min) | Cooldown before retry | `src/kiwi_sdk/api/endpoints.py:32` |

### Token refresh

| Setting | Value | Description | Source |
|---------|-------|-------------|--------|
| `REFRESH_INTERVAL_SECONDS` | 900 (15 min) | Background refresh interval | `src/kiwi_sdk/api/endpoints.py:29` |
| `TOKEN_MAX_AGE_SECONDS` | 600 (10 min) | Reuse tokens if younger than this | `src/kiwi_sdk/api/endpoints.py:30` |
| `REFRESH_RETRY_ATTEMPTS` | 3 | Retry attempts for token refresh | `src/kiwi_sdk/api/endpoints.py:33` |

### Cache limits

| Cache | Max Size | TTL |
|-------|----------|-----|
| Search results | 256 entries | 10 minutes |
| Calendar context | 512 entries | 60 minutes |
| Calendar prices | 512 entries | 60 minutes |

## Not specified in repo

The following are **not** explicitly configured in the repository as of commit `c86400c`:

- CORS settings (uses FastAPI defaults)
- Request/response size limits
- Connection pool size limits
- Rate limiting configuration (relies on Kiwi.com's own rate limits)
- TLS/SSL verification options
- Proxy settings
- Logging level configuration
- Metrics/observability endpoints
