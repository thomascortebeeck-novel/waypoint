#!/usr/bin/env bash
# Run Flutter web locally with Google Maps API key from environment.
# Set GOOGLE_MAPS_API_KEY before running, e.g.:
#   export GOOGLE_MAPS_API_KEY=your_key_here
#   ./scripts/run_web_local.sh
if [ -n "$GOOGLE_MAPS_API_KEY" ]; then
  echo "Using GOOGLE_MAPS_API_KEY from environment."
  exec flutter run -d chrome --dart-define=GOOGLE_MAPS_API_KEY="$GOOGLE_MAPS_API_KEY"
else
  echo "GOOGLE_MAPS_API_KEY not set. Maps may show ApiTargetBlockedMapError. Set it and re-run to fix."
  exec flutter run -d chrome
fi
