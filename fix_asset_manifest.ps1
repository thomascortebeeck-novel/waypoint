# Fix AssetManifest.json for Flutter Web Debug Mode
# This script creates AssetManifest.json from AssetManifest.bin.json

$assetsDir = "build\web\assets"
$binJsonPath = "$assetsDir\AssetManifest.bin.json"
$jsonPath = "$assetsDir\AssetManifest.json"

if (Test-Path $binJsonPath) {
    Write-Host "Found AssetManifest.bin.json, creating AssetManifest.json..." -ForegroundColor Green
    
    # Read the base64 content
    $base64Content = Get-Content $binJsonPath -Raw
    
    # Remove quotes if present
    $base64Content = $base64Content.Trim('"')
    
    # Decode base64 to get the actual JSON
    try {
        $bytes = [System.Convert]::FromBase64String($base64Content)
        $jsonContent = [System.Text.Encoding]::UTF8.GetString($bytes)
        
        # Write the decoded JSON to AssetManifest.json
        $jsonContent | Out-File -FilePath $jsonPath -Encoding utf8 -NoNewline
        Write-Host "Created AssetManifest.json successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to decode AssetManifest.bin.json: $_" -ForegroundColor Red
        Write-Host "Creating a simple fallback AssetManifest.json..." -ForegroundColor Yellow
        
        # Fallback: create a minimal JSON that references the bin file
        $fallbackJson = '{"assets":[]}'
        $fallbackJson | Out-File -FilePath $jsonPath -Encoding utf8
        Write-Host "Created fallback AssetManifest.json" -ForegroundColor Yellow
    }
}
else {
    Write-Host "AssetManifest.bin.json not found. Run 'flutter build web' first." -ForegroundColor Yellow
}

