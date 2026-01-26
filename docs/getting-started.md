# Getting Started

## Prerequisites

- **Docker** and **Docker Compose** (for containerized deployment)
- **Python 3.12+** (for local development)
- **uv** package manager (for dependency management)

### Installing uv

uv is a fast Python package manager written in Rust. Install it via:

```bash
# Linux / macOS
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows (PowerShell)
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"

# Or via pip
pip install uv
```

## Installation

### Option 1: Docker Compose (recommended)

The project includes a `docker-compose.yml` that sets up both the API service and a browser service for token refresh.

```bash
# Build and start all services
docker compose up --build

# Or run in detached mode
docker compose up --build -d
```

The API will be available at `http://localhost:8000`.

### Option 2: Local development setup

```bash
# Clone the repository
git clone <repo-url>
cd kiwi-resilient-sdk

# Install dependencies with uv
uv sync

# Activate the virtual environment (optional - uv run handles this)
source .venv/bin/activate  # Linux/macOS
# or
.venv\Scripts\activate  # Windows
```

## Running the server

### Docker Compose

```bash
docker compose up
```

Services:
- `kiwi-logic`: Main API on port 8000
- `browser`: Playwright browser service on port 3000 (internal)

### Local server (CLI)

```bash
# Run the server
uv run kiwi server

# With custom host/port
uv run kiwi server --host 0.0.0.0 --port 8080

# With auto-reload for development
uv run kiwi server --reload
```

## Verifying the service is running

### Health check

```bash
curl http://localhost:8000/health
```

Expected response:
```json
{"status":"ok"}
```

### Token status check

```bash
curl http://localhost:8000/meta/status
```

## First API requests

### 1. One-way flight search

```bash
curl -X POST http://localhost:8000/v1/flights/search \
  -H "Content-Type: application/json" \
  -d '{
    "origin": "PRG",
    "destination": "LHR",
    "date": {"start": "2026-05-10", "type": "fixed"},
    "return": {"type": "oneway"},
    "system": {"currency": "EUR"},
    "sort": "PRICE",
    "max_budget": 150,
    "max_results": 5
  }'
```

### 2. Flexible departure window (explore)

```bash
curl -X POST http://localhost:8000/v1/flights/search \
  -H "Content-Type: application/json" \
  -d '{
    "origin": "PRG",
    "destination": "MAD",
    "date": {
      "start": "2026-02-01",
      "end": "2026-02-28",
      "type": "range"
    },
    "return": {"type": "oneway"},
    "system": {"currency": "EUR"},
    "sort": "PRICE"
  }'
```

### 3. Round trip with fixed dates

```bash
curl -X POST http://localhost:8000/v1/flights/search \
  -H "Content-Type: application/json" \
  -d '{
    "origin": "PRG",
    "destination": "JFK",
    "date": {"start": "2026-06-10", "type": "fixed"},
    "return": {
      "type": "roundtrip",
      "start": "2026-06-20",
      "end": "2026-06-20"
    },
    "system": {"currency": "USD"},
    "sort": "PRICE"
  }'
```

### 4. Calendar prices with market analysis

```bash
curl -X POST http://localhost:8000/v1/flights/calendar \
  -H "Content-Type: application/json" \
  -d '{
    "origin": "PRG",
    "destination": "MAD",
    "start": "2026-02-01",
    "currency": "EUR",
    "min_nights": 3,
    "max_nights": 5
  }'
```

### 5. Scored search (with greed scoring)

```bash
curl -X POST http://localhost:8000/v1/flights/search/scored \
  -H "Content-Type: application/json" \
  -d '{
    "origin": "PRG",
    "destination": "BCN",
    "date": {"start": "2026-02-01", "type": "fixed"},
    "return": {"type": "oneway"},
    "system": {"currency": "EUR"},
    "sort": "PRICE"
  }'
```

## Interactive documentation

When the server is running, visit:

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

These provide interactive API documentation where you can test endpoints directly.

## Common startup issues

### Port already in use

If port 8000 is already occupied:

```bash
# Using a different port
uv run kiwi server --port 8080

# Or modify docker-compose.yml
ports:
  - "8080:8000"
```

### Browser service fails to start

Ensure Docker has sufficient memory allocated (at least 2GB for shm_size). Check the browser logs:

```bash
docker logs kiwi-resilient-sdk-browser-1
```

### Token refresh fails on startup

The service performs an initial token refresh during startup. If this fails, check:
1. The browser service is healthy: `docker ps`
2. Network connectivity between containers
3. Browser service logs for any errors

Token refresh has a circuit breaker that will retry after 2 minutes if consecutive failures occur.
