# Kiwi Resilient SDK

## What it is

The Kiwi Resilient SDK is a Python SDK and FastAPI sidecar service for searching flights via Kiwi.com's official GraphQL API. It provides both a programmatic Python client interface and a REST API wrapper, with built-in resilience features including:

- Automatic retry with exponential backoff via `tenacity`
- Response caching for development efficiency
- Structured logging with `structlog`
- Type-safe models using Pydantic
- Browser-based token refresh using Playwright
- Calendar price analysis with market stats and "greed scoring"

## What it is not

This project **does not** perform web scraping, HTML parsing, or bypass rate limits. It communicates exclusively with Kiwi.com's official GraphQL API endpoint (`https://api.skypicker.com/umbrella/v2/graphql`) using proper API contracts. The browser automation component is used solely to obtain valid authentication headers for API requests.

## Key features

- **Dual interface**: Use as a Python SDK (`KiwiClient`) or run as a FastAPI sidecar service
- **Flexible search modes**: Search (specific dates) and Explore (date ranges)
- **Return trip options**: One-way, fixed return, flexible return, duration-based stays
- **Calendar analytics**: Price graph data with market statistics and deal scoring
- **Token management**: Background refresh loop with circuit breaker and persistent storage
- **Docker Compose ready**: Includes browser service for headless Playwright execution

## Quickstart

1. **Clone and install**:
   ```bash
   git clone <repo-url>
   cd kiwi-resilient-sdk
   uv sync
   ```

2. **Run with Docker Compose**:
   ```bash
   docker compose up --build
   ```

3. **Make your first request**:
   ```bash
   curl -X POST http://localhost:8000/v1/flights/search \
     -H "Content-Type: application/json" \
     -d '{
       "origin": "PRG",
       "destination": "LHR",
       "date": {"start": "2026-05-10", "type": "fixed"},
       "return": {"type": "oneway"}
     }'
   ```

For detailed setup instructions, see the [Getting Started](getting-started.md) guide.

## Documentation links

- **API Reference**: See [API Documentation](api.md) for full endpoint reference
- **Interactive docs**: Swagger UI at `http://localhost:8000/docs` (when running)
- **ReDoc**: Available at `http://localhost:8000/redoc` (when running)
- **OpenAPI Schema**: `/openapi.json` endpoint (when running)
- **Architecture**: See [Architecture](architecture.md) for component overview
- **Configuration**: See [Configuration](configuration.md) for environment variables
- **Troubleshooting**: See [Troubleshooting](troubleshooting.md) for common issues
