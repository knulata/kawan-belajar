#!/bin/bash
# Kawabel — Start everything for local development
# Usage: ./start.sh

set -e

# Check for API key
if [ -z "$OPENAI_API_KEY" ]; then
  echo "❌ Set your OpenAI API key first:"
  echo "   export OPENAI_API_KEY=sk-..."
  exit 1
fi

echo "🦉 Starting Kawabel..."
echo ""

# Start API server in background
echo "📡 Starting API server on port 3001..."
cd server
node index.js &
SERVER_PID=$!
cd ..

# Wait for server
sleep 2

# Start Flutter web
echo "🌐 Starting Flutter web app..."
echo ""
flutter run -d chrome --dart-define=API_URL=http://localhost:3001

# Cleanup on exit
kill $SERVER_PID 2>/dev/null
