# API Reference

## API overview

The Kiwi Resilient SDK exposes a REST API built with FastAPI. All endpoints accept and return JSON. The API automatically routes requests to either search or explore mode based on the payload structure.

### Base URL

When running locally:
```
http://localhost:8000
```

### Interactive documentation

When the server is running:
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`
- **OpenAPI Schema**: `http://localhost:8000/openapi.json`

## Authentication

No API key or bearer token is required. Authentication is handled internally by the service:

1. The browser service (`Browser.get_fresh_headers()`) captures Kiwi.com auth tokens
2. Tokens are stored in memory and persisted to SQLite
3. Each request includes these headers when calling Kiwi.com's GraphQL API

This is transparent to API consumers.

## Endpoints

### Health & Status

#### GET /health

Simple health check endpoint.

**Response** (200 OK):
```json
{
  "status": "ok"
}
```

**Source**: [endpoints.py:501](src/kiwi_sdk/api/endpoints.py:501)

#### GET /meta/status

Returns token metadata including age and source.

**Response** (200 OK):
```json
{
  "status": "active",
  "token_age_seconds": 123,
  "token_source": "db"
}
```

**Status values**: `active`, `missing`, `unknown`

**Source**: [endpoints.py:506](src/kiwi_sdk/api/endpoints.py:506)

### Token Management

#### POST /system/refresh-tokens

Manually trigger a token refresh from the browser service.

**Response** (200 OK):
```json
{
  "status": "refreshed",
  "token": {
    "token": "...",
    "refreshed_at": "2026-01-26T12:00:00Z",
    "age_seconds": 0,
    "status": "success",
    "cookies_count": 5,
    "user_agent": "Mozilla/5.0..."
  },
  "kw-skypicker-visitor-uniqid": "...",
  "kw-umbrella-token": "...",
  "kw-validation-token": "...",
  "kw-x-rand-id": "..."
}
```

**Source**: [endpoints.py:525](src/kiwi_sdk/api/endpoints.py:525)

### Flight Search

#### POST /v1/flights/search

Search for flights (one-way or round trip) with flexible options. The endpoint automatically routes to search or explore based on date windows and return configuration.

**Request body**:

```json
{
  "origin": "PRG",
  "destination": "LHR",
  "date": {
    "start": "2026-05-10",
    "end": null,
    "type": "fixed"
  },
  "return": {
    "type": "oneway"
  },
  "stay": null,
  "system": {
    "currency": "EUR",
    "locale": "us"
  },
  "sort": "PRICE",
  "max_budget": 150,
  "max_results": 5
}
```

**Request schema** (`SearchPayload`):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `origin` | string | Yes | 3-letter IATA airport code |
| `destination` | string \| null | No | IATA code or `europe`/`anywhere` (required for search, optional for explore) |
| `date` | `DateConfig` | Yes | Departure date configuration |
| `date.start` | date (ISO 8601) | Yes | Earliest departure date |
| `date.end` | date \| null | No | Latest departure date (for range searches) |
| `date.type` | `fixed` \| `range` | Yes | Whether departure is single date or range |
| `return` | `ReturnConfig` | No | Return trip configuration (defaults to `{"type": "oneway"}`) |
| `return.type` | `oneway` \| `fixed` \| `range` \| `anytime` \| `duration` \| `roundtrip` | No | Return behavior type |
| `return.start` | date \| null | No | Return date for fixed/roundtrip returns |
| `stay` | int \| `{min: int, max: int}` \| null | No | Stay duration for duration-based returns |
| `system` | `SystemConfig` | No | System defaults (currency, locale) |
| `system.currency` | string | No | Currency code (default: `EUR`) |
| `system.locale` | string | No | Locale setting (default: `us`) |
| `sort` | string | No | Sort order: `PRICE`, `DURATION`, `QUALITY` (default: `PRICE`) |
| `max_budget` | int \| null | No | Maximum budget filter (must be > 0) |
| `max_results` | int \| null | No | Maximum number of results to return |

**Return type behaviors**:

| Type | Description | Required fields |
|------|-------------|-----------------|
| `oneway` | One-way flight | None |
| `fixed` | Specific return date | `return.start` |
| `roundtrip` | Fixed return (start = end) | `return.start` or `return.end` |
| `anytime` | Flexible return within 30 days | None |
| `duration` | Stay-based return | `stay` (int or dict) |

**Response** (200 OK):

```json
{
  "items": [
    {
      "segments": [
        {
          "departure_airport": "PRG",
          "arrival_airport": "LHR",
          "departure_time": "2026-05-10T10:00:00Z",
          "arrival_time": "2026-05-10T11:30:00Z",
          "airline_code": "BA"
        }
      ],
      "total_price": 89.99,
      "deep_link": "https://kiwi.com/...",
      "duration_minutes": 90,
      "stops": 0,
      "airlines": ["BA"],
      "is_direct": true,
      "has_overnight": false,
      "origin": "PRG",
      "destination": "LHR"
    }
  ],
  "count": 1,
  "meta": {
    "origin": "PRG",
    "destination": "LHR",
    "query_type": "search",
    "max_budget_applied": 150,
    "max_results_applied": 5,
    "source": "kiwi"
  }
}
```

**Error responses**:

| Status | Description |
|--------|-------------|
| 400 | Invalid request payload (validation error) |
| 500 | Upstream Kiwi API error |

**Source**: [endpoints.py:540](src/kiwi_sdk/api/endpoints.py:540)

#### POST /v1/flights/search/scored

Same as `/v1/flights/search` but adds "greed scoring" to each itinerary based on calendar price data.

**Request body**: Same as `/v1/flights/search`

**Response** (200 OK):

```json
{
  "items": [
    {
      "segments": [...],
      "total_price": 89.99,
      "deep_link": "...",
      "duration_minutes": 90,
      "stops": 0,
      "airlines": ["BA"],
      "is_direct": true,
      "has_overnight": false,
      "origin": "PRG",
      "destination": "LHR",
      "greed_score": {
        "score": 7.5,
        "verdict": "GOOD",
        "metrics": {
          "z_score": -0.8,
          "percentile": 0.22,
          "weekend_tax": 5.0,
          "market_context": {
            "min": 75.0,
            "max": 150.0,
            "avg": 95.0,
            "median": 90.0
          }
        }
      }
    }
  ],
  "count": 1,
  "meta": {
    "origin": "PRG",
    "destination": "LHR",
    "query_type": "search",
    "max_budget_applied": null,
    "max_results_applied": null,
    "source": "kiwi"
  },
  "calendar_source": "kiwi"
}
```

**Greed verdict values**:

| Verdict | Z-score range | Description |
|---------|---------------|-------------|
| `ERROR_FARE` | Z < -3.0 | Exceptionally good deal |
| `STEAL` | -3.0 ≤ Z < -2.0 | Excellent deal |
| `RARE` | -2.0 ≤ Z < -1.5 | Rare deal |
| `GREAT` | -1.5 ≤ Z < -1.0 | Great price |
| `GOOD` | -1.0 ≤ Z < -0.5 | Good price |
| `FAIR` | -0.5 ≤ Z ≤ 0.5 | Average price |
| `MEH` | 0.5 < Z ≤ 1.0 | Slightly overpriced |
| `BAD` | 1.0 < Z ≤ 1.5 | Overpriced |
| `EXPENSIVE` | 1.5 < Z ≤ 2.0 | Expensive |
| `RIP_OFF` | Z > 2.0 | Very expensive |

**Source**: [endpoints.py:582](src/kiwi_sdk/api/endpoints.py:582)

### Calendar Prices

#### POST /v1/flights/calendar

Fetch calendar price data with market statistics for a date range.

**Request body**:

```json
{
  "origin": "PRG",
  "destination": "MAD",
  "start": "2026-02-01",
  "end": null,
  "currency": "EUR",
  "min_nights": 3,
  "max_nights": 5
}
```

**Request schema** (`CalendarRequest`):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `origin` | string | Yes | 3-letter IATA origin code |
| `destination` | string | Yes | 3-letter IATA destination code |
| `start` | date (ISO 8601) | Yes | Start of date range |
| `end` | date \| null | No | End of date range (defaults to full month) |
| `currency` | string | No | Currency code (default: `EUR`) |
| `min_nights` | int | No | Minimum stay duration (default: `1`) |
| `max_nights` | int | No | Maximum stay duration (default: `1`) |

**Response** (200 OK):

```json
{
  "data": [
    {
      "duration_nights": 3,
      "entries": [
        {
          "date": "2026-02-01",
          "price": 89.99
        },
        {
          "date": "2026-02-02",
          "price": 95.50
        }
      ]
    },
    {
      "duration_nights": 4,
      "entries": [...]
    },
    {
      "duration_nights": 5,
      "entries": [...]
    }
  ],
  "stats": {
    "min": 75.0,
    "max": 150.0,
    "avg": 95.0,
    "median": 90.0,
    "std_dev": 20.0
  },
  "meta": {
    "request_duration_ms": 2500,
    "source": "kiwi"
  }
}
```

**Source**: [endpoints.py:563](src/kiwi_sdk/api/endpoints.py:563)

## Example requests

### One-way simple search

```bash
curl -X POST http://localhost:8000/v1/flights/search \
  -H "Content-Type: application/json" \
  -d '{
    "origin": "PRG",
    "destination": "LHR",
    "date": {"start": "2026-05-10", "type": "fixed"},
    "return": {"type": "oneway"},
    "system": {"currency": "EUR"},
    "sort": "PRICE"
  }'
```

### Round trip with fixed dates

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
    "system": {"currency": "USD"}
  }'
```

### Explore with date range

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
    "return": {"type": "oneway"}
  }'
```

### Duration-based stay

```bash
curl -X POST http://localhost:8000/v1/flights/search \
  -H "Content-Type: application/json" \
  -d '{
    "origin": "VIE",
    "destination": "BCN",
    "date": {
      "start": "2026-02-01",
      "end": "2026-02-28",
      "type": "range"
    },
    "stay": {"min": 3, "max": 5}
  }'
```

### Calendar prices

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

### Scored search

```bash
curl -X POST http://localhost:8000/v1/flights/search/scored \
  -H "Content-Type: application/json" \
  -d '{
    "origin": "PRG",
    "destination": "BCN",
    "date": {"start": "2026-02-01", "type": "fixed"},
    "return": {"type": "oneway"}
  }'
```

## Request/response examples

### Example: One-way search with budget filter

**Request**:
```json
POST /v1/flights/search
{
  "origin": "PRG",
  "destination": "LHR",
  "date": {
    "start": "2026-05-10",
    "type": "fixed"
  },
  "return": {
    "type": "oneway"
  },
  "system": {
    "currency": "EUR",
    "locale": "us"
  },
  "sort": "PRICE",
  "max_budget": 150,
  "max_results": 5
}
```

**Response**:
```json
{
  "items": [
    {
      "segments": [
        {
          "departure_airport": "PRG",
          "arrival_airport": "LHR",
          "departure_time": "2026-05-10T06:30:00Z",
          "arrival_time": "2026-05-10T07:45:00Z",
          "airline_code": "U2"
        }
      ],
      "total_price": 45.00,
      "deep_link": "https://www.kiwi.com/en/booking/...",
      "duration_minutes": 75,
      "stops": 0,
      "airlines": ["U2"],
      "is_direct": true,
      "has_overnight": false,
      "origin": "PRG",
      "destination": "LHR"
    },
    {
      "segments": [
        {
          "departure_airport": "PRG",
          "arrival_airport": "LHR",
          "departure_time": "2026-05-10T10:00:00Z",
          "arrival_time": "2026-05-10T11:30:00Z",
          "airline_code": "BA"
        }
      ],
      "total_price": 89.99,
      "deep_link": "https://www.kiwi.com/en/booking/...",
      "duration_minutes": 90,
      "stops": 0,
      "airlines": ["BA"],
      "is_direct": true,
      "has_overnight": false,
      "origin": "PRG",
      "destination": "LHR"
    }
  ],
  "count": 2,
  "meta": {
    "origin": "PRG",
    "destination": "LHR",
    "query_type": "search",
    "max_budget_applied": 150,
    "max_results_applied": 5,
    "source": "kiwi"
  }
}
```

### Example: Calendar with stats

**Request**:
```json
POST /v1/flights/calendar
{
  "origin": "PRG",
  "destination": "MAD",
  "start": "2026-02-01",
  "currency": "EUR",
  "min_nights": 3,
  "max_nights": 5
}
```

**Response**:
```json
{
  "data": [
    {
      "duration_nights": 3,
      "entries": [
        {"date": "2026-02-01", "price": 89.99},
        {"date": "2026-02-02", "price": 95.50},
        {"date": "2026-02-03", "price": 110.00}
      ]
    },
    {
      "duration_nights": 4,
      "entries": [
        {"date": "2026-02-01", "price": 92.00},
        {"date": "2026-02-02", "price": 98.50}
      ]
    },
    {
      "duration_nights": 5,
      "entries": [
        {"date": "2026-02-01", "price": 95.00}
      ]
    }
  ],
  "stats": {
    "min": 75.0,
    "max": 150.0,
    "avg": 95.0,
    "median": 90.0,
    "std_dev": 20.0
  },
  "meta": {
    "request_duration_ms": 3500,
    "source": "kiwi"
  }
}
```
