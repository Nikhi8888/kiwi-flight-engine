# 🥝 Kiwi Flight Engine
> **The Flight Search API that runs on your machine.**

[![Docker Hub](https://img.shields.io/badge/Docker-Pull_Image-blue)](https://hub.docker.com/r/abdallahthegreatest/kiwi-engine)

## 📖 What is this?

**Kiwi Flight Engine** is a self-contained flight search API that you can run on your own computer. Instead of relying on third-party APIs that might rate-limit or block you, this engine runs locally and searches for flights directly.

### Why would I use this?

| Reason | Explanation |
|--------|-------------|
| **No Ban** | Uses your residential IP address to avoid getting blocked by flight websites |
| **No Cloud** | All data stays on your computer - nothing is sent to external servers |
| **No Code** | Everything is pre-packaged - just run it and start searching |
| **Free** | No API costs or subscriptions |

### How does it work?

The engine uses two Docker containers:
1. **Kiwi Engine** - A Python/FastAPI server that handles flight searches
2. **Browser Container** - A headless Chrome browser that visits flight websites and scrapes data

They work together to search flights and return results to you via a clean API interface.

---

## 📋 Prerequisites

Before you start, you need **Docker Desktop** installed on your computer.

### What is Docker?

Docker is a tool that lets you run applications in isolated containers. Think of it like a lightweight virtual machine that contains everything the app needs to run.

### Installing Docker Desktop

Choose your operating system and follow the official guide:

- **Windows:** [Download Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
- **macOS:** [Download Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)
- **Linux:** Install Docker Engine following [these instructions](https://docs.docker.com/engine/install/)

> **After installing:** Make sure Docker Desktop is **running** before you continue. You should see the Docker icon in your taskbar/menu bar.

---

## 🚀 Getting Started

### Option A: The Easy Way (Recommended for Beginners)

This method uses pre-made scripts that do everything for you.

#### Windows Users:

1. **Download** this project as a ZIP file:
   - Click the green "Code" button at the top of this page
   - Click "Download ZIP"
   - Save it somewhere you can find it (like your Desktop or Downloads)

2. **Extract the ZIP file:**
   - Right-click the downloaded file
   - Select "Extract All..."
   - Choose a location and click "Extract"

3. **Open the extracted folder** and navigate to the `scripts` folder

4. **Double-click `start.bat`**
   - A black window will open and show progress
   - Wait until you see "SUCCESS!"

5. **Open your browser** and go to: **[http://localhost:8000/docs](http://localhost:8000/docs)**

You should now see the interactive API documentation where you can search for flights!

#### Mac/Linux Users:

1. **Download** this project as a ZIP file (same steps as Windows above)

2. **Extract the ZIP file**

3. **Open a terminal** and navigate to the scripts folder:
   ```bash
   cd /path/to/kiwi-flight-engine/scripts
   ```

4. **Run the start script:**
   ```bash
   chmod +x start.sh  # Only needed the first time
   ./start.sh
   ```

5. **Open your browser** and go to: **[http://localhost:8000/docs](http://localhost:8000/docs)**

---

### Option B: The Developer Way (Using Command Line)

If you're comfortable with the terminal and git:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/kiwi-flight-engine.git
   cd kiwi-flight-engine
   ```

2. **Start the engine with Docker Compose:**
   ```bash
   docker compose up -d
   ```

3. **Open your browser** and go to: **[http://localhost:8000/docs](http://localhost:8000/docs)**

> **Note:** The `-d` flag runs the containers in "detached" mode (in the background). Omit it if you want to see logs in real-time.

---

## 🎯 How to Use the API

Once the engine is running, open **[http://localhost:8000/docs](http://localhost:8000/docs)** in your browser.

This is an interactive Swagger UI that lets you:
- See all available API endpoints
- Test endpoints directly from your browser
- View request/response formats

### Quick Example: Searching for Flights

1. Find the `/search` endpoint in the documentation
2. Click "Try it out"
3. Enter your search parameters:
   ```json
   {
     "fly_from": "JFK",
     "fly_to": "LAX",
     "date_from": "2025-02-01",
     "date_to": "2025-02-28"
   }
   ```
4. Click "Execute"
5. View the results below

### Using the API from Code

Here's a Python example:

```python
import requests

# Search for flights from New York to Los Angeles
response = requests.get("http://localhost:8000/search", params={
    "fly_from": "JFK",
    "fly_to": "LAX",
    "date_from": "2025-02-01",
    "date_to": "2025-02-28"
})

flights = response.json()
for flight in flights:
    print(f"{flight['price']} - {flight['airlines']}")
```

---

## 🛠 Managing the Engine

### Check if it's running

Open your browser and go to: **[http://localhost:8000/meta/status](http://localhost:8000/meta/status)**

You should see a status message if everything is working.

### Stop the engine

```bash
docker compose down
```

### Start it again

```bash
docker compose up -d
```

### View logs (for debugging)

```bash
# See all logs
docker compose logs

# Follow logs in real-time
docker compose logs -f

# See logs for a specific service
docker compose logs kiwi
docker compose logs browser
```

---

## 🔧 Troubleshooting

### Problem: "Docker is not running"

**Solution:** Make sure Docker Desktop is open and running. Look for the Docker icon in your taskbar or menu bar.

### Problem: Port 8000 is already in use

**Solution:** You might have another service running on port 8000. You can either:
1. Stop the other service
2. Change the port in [docker-compose.yml:12](docker-compose.yml#L12) from `8000:8000` to something like `8001:8000`

### Problem: The engine is slow

**Solution:** Flight searches can take 10-30 seconds depending on the websites being scraped. This is normal behavior.

### Problem: I'm getting connection errors

**Solution:** Check that both containers are running:
```bash
docker ps
```

You should see two containers: `kiwi-logic` and `kiwi-browser`. If one is missing or restarting, check the logs.

### Problem: I'm on Linux and nothing happens

**Solution:** Make sure the start script is executable:
```bash
chmod +x scripts/start.sh
./scripts/start.sh
```

---

## 📁 Project Structure

```
kiwi-flight-engine/
├── docker-compose.yml      # Docker configuration
├── scripts/
│   ├── start.bat          # Windows startup script
│   └── start.sh           # Mac/Linux startup script
├── .env.example           # Example environment variables
└── README.md              # This file
```

---

## 🔐 Environment Variables

You can customize the engine by creating a `.env` file in the project root. See [`.env.example`](.env.example) for available options.

---

## 💡 Tips for Beginners

1. **Always check Docker is running first** - Most issues are because Docker Desktop isn't open
2. **Give it time** - Flight searches aren't instant, especially on first run
3. **Check the logs** - If something seems wrong, run `docker compose logs` to see what's happening
4. **Restart** - If all else fails, try `docker compose restart`

---

## 📝 Coming from the old version?

If you were using a previous version of this engine, you may want to pull the latest images:

```bash
docker pull abdallahthegreatest/kiwi-engine:latest
docker pull abdallahthegreatest/kiwi-browser:v1.57.0
```

---

## 🤝 Contributing

Found a bug? Have a suggestion? Feel free to open an issue or submit a pull request!

---

## 📄 License

This project is open source and available under the MIT License.