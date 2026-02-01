# Flutter Permissions Fix Script
# This script helps fix common Flutter permission issues on Windows

Write-Host "Flutter Permissions Fix Script" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""

# Get Flutter SDK path
$flutterPath = (flutter --version | Select-String "Flutter SDK at").ToString().Split("`"")[1]
if (-not $flutterPath) {
    $flutterPath = "$env:USERPROFILE\flutter"
}

Write-Host "Flutter SDK Path: $flutterPath" -ForegroundColor Yellow
Write-Host ""

# Check if Flutter SDK exists
if (-not (Test-Path $flutterPath)) {
    Write-Host "ERROR: Flutter SDK not found at $flutterPath" -ForegroundColor Red
    Write-Host "Please set the correct Flutter SDK path or install Flutter." -ForegroundColor Red
    exit 1
}

# Paths to check and fix
$pathsToFix = @(
    "$flutterPath\bin\cache\artifacts\engine\windows-x64",
    "$flutterPath\bin\cache\artifacts\engine\windows-x64\shader_lib",
    "$PWD\build",
    "$PWD\build\flutter_assets",
    "$PWD\build\flutter_assets\shaders"
)

Write-Host "Checking and fixing permissions for:" -ForegroundColor Cyan
foreach ($path in $pathsToFix) {
    if (Test-Path $path) {
        Write-Host "  [OK] $path" -ForegroundColor Green
        try {
            # Try to create a test file to check write permissions
            $testFile = Join-Path $path ".permission_test"
            "" | Out-File -FilePath $testFile -ErrorAction Stop
            Remove-Item $testFile -ErrorAction SilentlyContinue
            Write-Host "    Write permissions: OK" -ForegroundColor Green
        } catch {
            Write-Host "    Write permissions: FAILED - $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "    Try running PowerShell as Administrator" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [MISSING] $path" -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Host "    Created successfully" -ForegroundColor Green
        } catch {
            Write-Host "    Failed to create - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Cleaning Flutter build cache..." -ForegroundColor Cyan
flutter clean

Write-Host ""
Write-Host "Getting Flutter dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host ""
Write-Host "Building web assets..." -ForegroundColor Cyan
flutter build web --debug

Write-Host ""
Write-Host "Fixing AssetManifest.json for debug mode..." -ForegroundColor Cyan
$assetsDir = "build\web\assets"
$binJsonPath = "$assetsDir\AssetManifest.bin.json"
$jsonPath = "$assetsDir\AssetManifest.json"

if (Test-Path $binJsonPath) {
    $base64Content = Get-Content $binJsonPath -Raw
    $base64Content = $base64Content.Trim('"')
    try {
        $bytes = [System.Convert]::FromBase64String($base64Content)
        $jsonContent = [System.Text.Encoding]::UTF8.GetString($bytes)
        $jsonContent | Out-File -FilePath $jsonPath -Encoding utf8 -NoNewline
        Write-Host "  Created AssetManifest.json successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "  Warning: Could not decode AssetManifest.bin.json" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Done! Try running 'flutter run -d chrome' again." -ForegroundColor Green
Write-Host ""
Write-Host "If issues persist:" -ForegroundColor Yellow
Write-Host "  1. Run PowerShell as Administrator" -ForegroundColor Yellow
Write-Host "  2. Check if antivirus is blocking Flutter tools" -ForegroundColor Yellow
Write-Host "  3. Add Flutter SDK directory to antivirus exclusions" -ForegroundColor Yellow
Write-Host "  4. Run '.\fix_asset_manifest.ps1' after each 'flutter clean'" -ForegroundColor Yellow

