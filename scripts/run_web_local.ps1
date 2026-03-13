# Run Flutter web locally with Google Maps API key from environment.
# Set GOOGLE_MAPS_API_KEY before running, e.g.:
#   $env:GOOGLE_MAPS_API_KEY = "your_key_here"
#   .\scripts\run_web_local.ps1
$key = $env:GOOGLE_MAPS_API_KEY
if ($key) {
  Write-Host "Using GOOGLE_MAPS_API_KEY from environment."
  flutter run -d chrome --dart-define=GOOGLE_MAPS_API_KEY=$key
} else {
  Write-Host "GOOGLE_MAPS_API_KEY not set. Maps may show ApiTargetBlockedMapError. Set it and re-run to fix."
  flutter run -d chrome
}
