# Architecture

## High-level overview

The Kiwi Resilient SDK is composed of two main components:

1. **API Service** (`kiwi-logic`): A FastAPI application that exposes REST endpoints for flight search and calendar operations
2. **Browser Service** (`browser`): A Playwright-based service that captures authentication headers from Kiwi.com

The services communicate via a WebSocket connection (`PLAYWRIGHT_WS_ENDPOINT`) and coordinate through Docker Compose.

## Components

### API Service (`kiwi-logic`)

The main FastAPI application ([`src/kiwi_sdk/api/`](src/kiwi_sdk/api/)) composed of:

| Component | File | Responsibility |
|-----------|------|----------------|
| **FastAPI App** | `api/app.py` | Application lifecycle, dependency injection, router mounting |
| **Endpoints Router** | `api/endpoints.py` | HTTP route handlers, TokenManager, request/response processing |
| **Request Models** | `api/models.py` | Pydantic models for request validation (`SearchPayload`, `DateConfig`, `ReturnConfig`) |
| **Response Schemas** | `api/schemas.py` | Calendar and scoring models (`CalendarRequest`, `CalendarResponse`, `ScoredFlight`) |
| **Token Store** | `api/token_store.py` | SQLite persistence for browser tokens |

### Core Services Layer

| Service | File | Responsibility |
|---------|------|----------------|
| **FlightService** | `core/services.py` | Orchestrates flight/calendar searches with caching |
| **Browser** | `core/browser.py` | Playwright automation for capturing auth headers |
| **KiwiSession** | `core/session.py` | HTTP client with retry logic via `tenacity` |
| **Cache** | `core/cache.py` | In-memory LRU cache decorator |

### Adapters Layer

| Adapter | File | Responsibility |
|---------|------|----------------|
| **QueryAdapter** | `adapters/queries.py` | Constructs GraphQL payloads and query defaults |
| **Parsers** | `adapters/parsers.py` | Converts raw GraphQL responses to domain models |

### Domain Layer

| Module | File | Responsibility |
|--------|------|----------------|
| **Models** | `domain/models.py` | Core domain entities (`SearchQuery`, `ExploreQuery`, `Itinerary`) |
| **Exceptions** | `domain/exceptions.py` | Custom error types (`KiwiError`) |

### CLI Layer

| Module | File | Responsibility |
|--------|------|----------------|
| **Main CLI** | `cli/main.py` | Typer-based CLI for `kiwi server`, `kiwi search`, `kiwi explore` commands |

## Data flow

```
┌─────────────────┐
│  Client Request │ (HTTP POST /v1/flights/*)
└────────┬────────┘
         ▼
┌─────────────────────────────────────────────────────────────┐
│                     FastAPI Router                          │
│  (endpoints.py: search_flights, calendar_prices, etc.)      │
└────────┬────────────────────────────────────────────────────┘
         ▼
┌─────────────────────────────────────────────────────────────┐
│                   FlightService                             │
│  - Checks cache (async_cache decorator)                     │
│  - Routes to search vs explore based on payload             │
│  - Applies budget/results filters                           │
└────────┬────────────────────────────────────────────────────┘
         ▼
┌─────────────────────────────────────────────────────────────┐
│                    KiwiClient                               │
│  - Creates SearchQuery or ExploreQuery from payload         │
│  - Delegates to QueryAdapter for GraphQL construction       │
└────────┬────────────────────────────────────────────────────┘
         ▼
┌─────────────────────────────────────────────────────────────┐
│                  KiwiSession                                │
│  - Adds auth headers from TokenManager                      │
│  - HTTP POST to Kiwi GraphQL API                            │
│  - Retry on failure (tenacity)                              │
└────────┬────────────────────────────────────────────────────┘
         ▼
┌─────────────────────────────────────────────────────────────┐
│            Kiwi.com GraphQL API                             │
│  (https://api.skypicker.com/umbrella/v2/graphql)           │
└────────┬────────────────────────────────────────────────────┘
         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Parser                                    │
│  - Converts raw GraphQL response to List[Itinerary]         │
└────────┬────────────────────────────────────────────────────┘
         ▼
┌─────────────────────────────────────────────────────────────┐
│              SearchResponse                                 │
│  - Wraps results with metadata (query_type, filters, etc.)  │
└────────┬────────────────────────────────────────────────────┘
         ▼
┌─────────────────┐
│  HTTP Response  │ (JSON)
└─────────────────┘
```

## Token management flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     Application Startup                        │
│  1. lifespan() function initializes TokenManager               │
│  2. Loads persisted tokens from SQLite (if available)          │
│  3. Performs immediate token refresh via Browser               │
│  4. Starts background worker (15-minute refresh interval)      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│               Background Refresh Loop                          │
│  - Runs every 15 minutes (REFRESH_INTERVAL_SECONDS)           │
│  - Uses circuit breaker (3 failures → open for 2 minutes)      │
│  - Persists tokens to SQLite after success                     │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   TokenManager.get_browser_headers()           │
│  1. Check memory cache (if age < 10 minutes, reuse)           │
│  2. Check SQLite database (if persisted token is fresh)        │
│  3. Otherwise, trigger on-demand refresh via Browser           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Browser.get_fresh_headers()               │
│  1. Connect to Playwright browser (local or remote)            │
│  2. Navigate to Kiwi.com search results page                   │
│  3. Intercept GraphQL request headers                          │
│  4. Extract: kw-umbrella-token, kw-validation-token, etc.      │
│  5. Return complete headers dict                               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Token Storage                               │
│  - In-memory cache for fast access                             │
│  - SQLite at `/data/tokens.db` for persistence across restarts │
└─────────────────────────────────────────────────────────────────┘
```

## Design decisions

### Why a browser service?

Kiwi.com's GraphQL API requires authentication headers that are generated by their frontend. The browser service:

1. Opens a real Chromium browser via Playwright
2. Navigates to a Kiwi.com search results page
3. Intercepts the GraphQL request to capture the auth headers
4. Returns these headers for use in API requests

This approach uses official API endpoints with legitimately obtained credentials.

### Background token refresh

Tokens have a limited lifespan. The TokenManager runs a background loop that:

- Refreshes tokens every 15 minutes
- Implements a circuit breaker to prevent cascading failures
- Persists tokens to survive container restarts
- Allows on-demand refresh when tokens are stale

### Search vs Explore routing

The `SearchPayload` model uses `requires_explore()` to determine routing:

| Condition | Endpoint |
|-----------|----------|
| Fixed date, one-way or fixed return | `/v1/flights/search` → `KiwiClient.search()` |
| Date range OR flexible return | `/v1/flights/search` → `KiwiClient.explore()` |

This simplifies the API by accepting both search types through a single endpoint.

### Caching strategy

Two-tier caching improves performance:

| Cache | TTL | Max Size | Purpose |
|-------|-----|----------|---------|
| Search results | 10 minutes | 256 entries | Flight search responses |
| Calendar context | 60 minutes | 512 entries | Price graph data |
| Calendar prices | 60 minutes | 512 entries | Processed calendar buckets |

## Diagrams

### Service architecture (Docker Compose)

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Host                              │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              kiwi-logic (API Service)                   │   │
│  │  Port 8000: FastAPI app + Python 3.12                  │   │
│  │  - FlightService, TokenManager, KiwiClient             │   │
│  │  - /health, /v1/flights/* endpoints                    │   │
│  │  - SQLite: /data/tokens.db                             │   │
│  └─────────────────────┬───────────────────────────────────┘   │
│                        │ PLAYWRIGHT_WS_ENDPOINT                │
│                        │ ws://browser:3000                     │
│                        ▼                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │               browser (Playwright Service)               │   │
│  │  Internal port 3000: Playwright server                  │   │
│  │  - mcr.microsoft.com/playwright:v1.57.0-noble           │   │
│  │  - shm_size: 2gb                                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Request processing flow

```
HTTP Request → FastAPI Router → FlightService
                                    │
                                    ├─→ [Cache Hit?] → Return Cached Response
                                    │
                                    └─→ [Cache Miss]
                                           │
                                           ├─→ KiwiClient
                                           │       │
                                           │       ├─→ QueryAdapter (build GraphQL payload)
                                           │       │
                                           │       └─→ KiwiSession
                                           │                │
                                           │                ├─→ TokenManager (get headers)
                                           │                │
                                           │                └─→ HTTP POST to Kiwi API
                                           │
                                           └─→ Parser (GraphQL → Domain Models)
                                                    │
                                                    └─→ FlightService (apply filters)
                                                             │
                                                             └─→ HTTP Response
```

## Operational notes

### Logging

Structured logging via `structlog` with component binding for traceability.

### Persistence

- **Token database**: SQLite at `/data/tokens.db` (survives restarts)
- **In-memory cache**: Lost on restart (acceptable for transient search data)

### Limitations

- Browser connection requires WebSocket to Playwright service
- Token refresh can take up to 30 seconds (BROWSER_TIMEOUT)
- Circuit breaker prevents refresh attempts for 2 minutes after 3 failures
- No built-in rate limiting beyond Kiwi.com's own limits
