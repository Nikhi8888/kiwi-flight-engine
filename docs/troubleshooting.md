# Troubleshooting

## Docker issues

### Port 8000 already in use

**Symptom**: Error message when starting Docker Compose:
```
bind: address already in use
```

**Cause**: Another process is using port 8000.

**Fix**:
```bash
# Find what's using the port
sudo lsof -i :8000  # Linux/macOS
netstat -ano | findstr :8000  # Windows

# Option 1: Kill the process
kill -9 <PID>

# Option 2: Change the port in docker-compose.yml
ports:
  - "8080:8000"  # Use 8080 externally instead
```

### Browser service fails to start

**Symptom**: Browser container exits immediately or health check fails.

**Diagnose**:
```bash
# Check container status
docker ps -a

# Check browser logs
docker logs kiwi-resilient-sdk-browser-1

# Check health check
docker exec kiwi-resilient-sdk-browser-1 curl -f http://localhost:3000/
```

**Likely causes**:
1. Insufficient shared memory (`shm_size`)
2. Playwright browser image pull failure
3. Network issues

**Fix**:
```bash
# Increase shm_size in docker-compose.yml
services:
  browser:
    shm_size: "2gb"  # or higher

# Rebuild and restart
docker compose up --build -d
```

### Container can't reach browser service

**Symptom**: API service logs show connection refused to `ws://browser:3000`.

**Diagnose**:
```bash
# Check both containers are running
docker ps

# Test connectivity from api container
docker exec kiwi-resilient-sdk-kiwi-logic-1 curl -f http://browser:3000/

# Check Docker network
docker network inspect kiwi-resilient-sdk_default
```

**Fix**:
- Ensure both services are on the same Docker network
- Verify `PLAYWRIGHT_WS_ENDPOINT` is set to `ws://browser:3000` in [docker-compose.yml](docker-compose.yml:8)
- Restart services: `docker compose restart`

## Browser automation issues

### Token refresh fails on startup

**Symptom**: API service logs show token refresh errors, `/meta/status` returns `"status": "missing"`.

**Diagnose**:
```bash
# Check service logs
docker logs kiwi-resilient-sdk-kiwi-logic-1 --tail 50

# Check token status endpoint
curl http://localhost:8000/meta/status

# Manual refresh attempt
curl -X POST http://localhost:8000/system/refresh-tokens
```

**Likely causes**:
1. Browser service not healthy
2. Circuit breaker open after repeated failures
3. Playwright timeout during navigation

**Fix**:
```bash
# 1. Verify browser is healthy
docker ps | grep browser

# 2. If circuit breaker is open, wait 2 minutes then retry
# (CIRCUIT_RESET_SECONDS = 120)

# 3. Increase browser timeout if needed
# Set BROWSER_TIMEOUT env var (default: 30 seconds)
```

### Playwright connection timeout

**Symptom**: Logs show `playwright timeout` or `asyncio.TimeoutError`.

**Diagnose**:
```bash
# Check browser service is running
docker logs kiwi-resilient-sdk-browser-1

# Check if Playwright server is responsive
docker exec kiwi-resilient-sdk-browser-1 curl http://localhost:3000/
```

**Fix**:
1. Ensure browser service health check passes
2. Increase `BROWSER_TIMEOUT` environment variable
3. Check network connectivity between containers

## Network / timeout issues

### HTTP timeout to Kiwi API

**Symptom**: Search requests fail with timeout errors.

**Diagnose**:
```bash
# Check service logs
docker logs kiwi-resilient-sdk-kiwi-logic-1 | grep timeout

# Test connectivity to Kiwi API
docker exec kiwi-resilient-sdk-kiwi-logic-1 curl -w "\n" https://api.skypicker.com/umbrella/v2/graphql
```

**Fix**:
- Increase `TIMEOUT_SECONDS` environment variable (default: 30.0)
- Check network connectivity
- Verify Kiwi.com API is operational

### Circuit breaker is open

**Symptom**: Token refresh fails with `circuit_open` error.

**Diagnose**:
```bash
# Check logs for circuit breaker messages
docker logs kiwi-resilient-sdk-kiwi-logic-1 | grep circuit

# Check token status
curl http://localhost:8000/meta/status
```

**Cause**: 3 consecutive token refresh failures triggered the circuit breaker ([endpoints.py:31](src/kiwi_sdk/api/endpoints.py:31)).

**Fix**:
1. Wait 2 minutes for automatic reset (`CIRCUIT_RESET_SECONDS`)
2. Manually trigger refresh after cooldown: `curl -X POST http://localhost:8000/system/refresh-tokens`
3. Address underlying browser issue before retrying

## API errors

### 400 Bad Request - Validation error

**Symptom**: API returns 400 with error details.

**Common causes**:
- Invalid IATA code (not 3 letters)
- Date range invalid (`end` before `start`)
- Missing required fields
- `max_budget` or `max_results` ≤ 0

**Example error**:
```json
{
  "detail": {
    "error": "destination is required for search requests"
  }
}
```

**Fix**: Validate request payload against schema in [models.py](src/kiwi_sdk/api/models.py).

### 500 Internal Server Error - Kiwi API error

**Symptom**: API returns 500 with upstream error message.

**Diagnose**:
```bash
# Check logs for KiwiError
docker logs kiwi-resilient-sdk-kiwi-logic-1 | grep KiwiError
```

**Likely causes**:
1. Invalid auth tokens (expired or missing)
2. Kiwi.com API rate limiting
3. Malformed GraphQL payload
4. Upstream API issues

**Fix**:
```bash
# 1. Refresh tokens
curl -X POST http://localhost:8000/system/refresh-tokens

# 2. Verify token status
curl http://localhost:8000/meta/status

# 3. Retry request after cache expires (10 minutes)
```

### Empty search results

**Symptom**: `{"items": [], "count": 0}` for valid query.

**Possible causes**:
1. No flights matching criteria
2. `max_budget` filter too restrictive
3. Date range outside valid search window
4. Invalid route (no service between airports)

**Fix**:
```bash
# 1. Remove max_budget filter
# 2. Expand date range
# 3. Verify route exists on Kiwi.com
# 4. Check meta.source to confirm API was called
```

## Development issues

### ImportError: No module named 'playwright'

**Symptom**: Module import error when running locally.

**Fix**:
```bash
# Ensure dependencies are installed
uv sync

# Playwright should be installed via pyproject.toml
# If still missing:
uv pip install playwright==1.57.0
```

### SQLite database errors

**Symptom**: Token storage errors in logs.

**Diagnose**:
```bash
# Check if database file exists
docker exec kiwi-resilient-sdk-kiwi-logic-1 ls -la /data/tokens.db

# Check file permissions
docker exec kiwi-resilient-sdk-kiwi-logic-1 ls -la /data/
```

**Fix**:
- Ensure `/data` directory exists and is writable
- Database is created automatically by [token_store.py](src/kiwi_sdk/api/token_store.py)

## Logging and debugging

### Enable debug logging

**Not specified in repo** - The project uses `structlog` but logging level configuration is not exposed via environment variables as of commit `c86400c`.

### View service logs

```bash
# All services, follow mode
docker compose logs -f

# Specific service
docker logs kiwi-resilient-sdk-kiwi-logic-1 -f
docker logs kiwi-resilient-sdk-browser-1 -f

# Last 100 lines
docker logs kiwi-resilient-sdk-kiwi-logic-1 --tail 100
```

### Check container health

```bash
# Container status
docker ps

# Health check status
docker inspect kiwi-resilient-sdk-kiwi-logic-1 | grep -A 5 Health

# Execute into container
docker exec -it kiwi-resilient-sdk-kiwi-logic-1 bash
```

### Common diagnostic commands

```bash
# Test API health
curl http://localhost:8000/health

# Check token status
curl http://localhost:8000/meta/status

# Force token refresh
curl -X POST http://localhost:8000/system/refresh-tokens

# Simple search test
curl -X POST http://localhost:8000/v1/flights/search \
  -H "Content-Type: application/json" \
  -d '{"origin": "PRG", "destination": "LHR", "date": {"start": "2026-05-10", "type": "fixed"}, "return": {"type": "oneway"}}'

# OpenAPI schema
curl http://localhost:8000/openapi.json | jq '.paths | keys'
```

## Getting help

If issues persist after trying the above:

1. Check the [GitHub repository issues](https://github.com/anthropics/kiwi-resilient-sdk/issues)
2. Verify you're using the latest version
3. Review logs for specific error messages
4. Ensure all prerequisites (Docker, Python 3.12+) are met
