# Run Flutter web locally with Google Maps API key from .env or environment.
# Copy .env.example to .env and add GOOGLE_MAPS_API_KEY=your_key ( .env is gitignored).
$envFile = Join-Path (Get-Location) ".env"
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*GOOGLE_MAPS_API_KEY\s*=\s*(.+)$') {
      $env:GOOGLE_MAPS_API_KEY = $matches[1].Trim()
    }
  }
}
$key = $env:GOOGLE_MAPS_API_KEY
if ($key) {
  Write-Host "Using GOOGLE_MAPS_API_KEY from .env or environment."
  flutter run -d chrome --dart-define=GOOGLE_MAPS_API_KEY=$key
} else {
  Write-Host "GOOGLE_MAPS_API_KEY not set. Copy .env.example to .env and add your key, or set the env var. Maps may show ApiTargetBlockedMapError otherwise."
  flutter run -d chrome
}
