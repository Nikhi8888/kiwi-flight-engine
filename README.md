# Kiwi Flight Engine

> **DISCLAIMER: This is a LEARNING PROJECT only.**

This project is **NOT** a web scraping tool. We explicitly:
- Respect all `robots.txt` files
- Adhere to rate limits of the original API
- Do not circumvent any anti-scraping measures
- Use only publicly accessible endpoints without authentication bypass

The sole purpose of this project is educational: to learn about Docker, API integration, and distributed systems architecture.

---

## TL;DR

**Windows:** Double-click `scripts/start.bat`

**Mac/Linux:** Run `scripts/start.sh`

Then open [http://localhost:8000/docs](http://localhost:8000/docs)

---

## What is this?

A self-hosted flight search API consisting of two Docker containers:
1. **Kiwi Engine** - Python/FastAPI server
2. **Browser Service** - Headless Chrome for rendering

[![Docker Hub](https://img.shields.io/badge/Docker-Pull_Image-blue)](https://hub.docker.com/r/abdallahthegreatest/kiwi-engine)

---

## Prerequisites

- Docker and Docker Compose installed
- Docker Desktop running

---

## Getting Started

```bash
git clone https://github.com/yourusername/kiwi-flight-engine.git
cd kiwi-flight-engine
docker compose up -d
```

Access the API at [http://localhost:8000/docs](http://localhost:8000/docs)

---

## Usage

Visit [http://localhost:8000/docs](http://localhost:8000/docs) for interactive Swagger documentation.

### Example (Python)

```python
import requests

response = requests.get("http://localhost:8000/search", params={
    "fly_from": "JFK",
    "fly_to": "LAX",
    "date_from": "2025-02-01",
    "date_to": "2025-02-28"
})

flights = response.json()
```

---

## Management

```bash
# Stop
docker compose down

# Start
docker compose up -d

# Logs
docker compose logs -f
```

---

## Project Structure

```
kiwi-flight-engine/
├── docker-compose.yml
├── scripts/
│   ├── start.bat
│   └── start.sh
├── .env.example
└── README.md
```

---

## License

MIT License