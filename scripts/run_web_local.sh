#!/usr/bin/env bash
# Run Flutter web locally with Google Maps API key from .env or environment.
# Copy .env.example to .env and add GOOGLE_MAPS_API_KEY=your_key ( .env is gitignored).
if [ -f .env ]; then
  set -a
  source .env 2>/dev/null || true
  set +a
fi
# Fallback: parse GOOGLE_MAPS_API_KEY only (if source failed or .env has no export)
if [ -z "$GOOGLE_MAPS_API_KEY" ] && [ -f .env ]; then
  export GOOGLE_MAPS_API_KEY=$(grep -E '^\s*GOOGLE_MAPS_API_KEY\s*=' .env | head -1 | sed 's/^[^=]*=\s*//' | tr -d '"' | tr -d "'")
fi
if [ -n "$GOOGLE_MAPS_API_KEY" ]; then
  echo "Using GOOGLE_MAPS_API_KEY from .env or environment."
  exec flutter run -d chrome --dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY"
else
  echo "GOOGLE_MAPS_API_KEY not set. Copy .env.example to .env and add your key. Maps may show ApiTargetBlockedMapError otherwise."
  exec flutter run -d chrome
fi
