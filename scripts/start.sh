#!/bin/bash
echo "🥝 Starting Kiwi Engine..."

# 1. Check if Docker is installed/running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Error: Docker is not running."
  echo "👉 Please launch Docker Desktop and try again."
  exit 1
fi

# 2. Update to latest version automatically (Beginners forget this)
echo "⬇️  Checking for updates..."
docker pull abdallahthegreatest/kiwi-engine:0.1.0

# 3. Start the engine
echo "🚀 Ignition..."
docker-compose up -d

echo ""
echo "✅ SUCCESS! The engine is running."
echo "   - Dashboard: http://localhost:8000/docs"
echo "   - Status:    http://localhost:8000/meta/status"
echo ""
read -p "Press [Enter] to close..."