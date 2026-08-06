#!/bin/zsh

set -e

cd "$(dirname "$0")/website"

URL="http://localhost:5173/"
LOG_FILE="/tmp/buurthulp-vite.log"

echo "BuurtHulp website starten..."
echo

if [ ! -d "node_modules" ]; then
  echo "Onderdelen installeren..."
  npm install
  echo
fi

if curl -fsS "$URL" 2>/dev/null | grep -q "BuurtHulp"; then
  echo "De website draait al."
  open "$URL"
  echo "Geopend: $URL"
  echo
  echo "Je mag dit venster sluiten."
  exit 0
fi

echo "Lokale website-server starten..."
echo "Laat dit venster open zolang je de website bekijkt."
echo

npm run dev -- --host localhost --strictPort > "$LOG_FILE" 2>&1 &
SERVER_PID=$!

for _ in {1..40}; do
  if curl -fsS "$URL" 2>/dev/null | grep -q "BuurtHulp"; then
    open "$URL"
    echo "Geopend: $URL"
    echo
    echo "Server actief. Sluit dit venster om later te stoppen."
    wait "$SERVER_PID"
    exit 0
  fi
  sleep 0.25
done

echo "De website kon niet worden gestart."
echo
cat "$LOG_FILE"
echo
read "?Druk op Enter om dit venster te sluiten."
