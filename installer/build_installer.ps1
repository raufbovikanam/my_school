param(
    [switch]$UseInnoSetup
)

Write-Host "Cleaning previous builds..." -ForegroundColor Cyan
flutter clean

Write-Host "Fetching dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host "Building Windows Release..." -ForegroundColor Cyan
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Flutter build failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$releaseDir = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$outputDir = Join-Path $projectRoot 'installer\Output\release'

if (Test-Path $outputDir) { Remove-Item $outputDir -Recurse -Force }
New-Item -ItemType Directory -Path $outputDir | Out-Null

Write-Host "Copying built files to output directory..." -ForegroundColor Cyan
Copy-Item -Path (Join-Path $releaseDir '*') -Destination $outputDir -Recurse -Force

# If Inno Setup is available and requested, compile the .iss script. Otherwise create a zip.
$isccPath = Get-Command iscc.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
if ($UseInnoSetup -or $isccPath) {
    $issFile = Join-Path $projectRoot 'installer\my_school_installer.iss'
    if (-not (Test-Path $issFile)) {
        Write-Host "Inno Setup script not found: $issFile" -ForegroundColor Yellow
        Write-Host "Falling back to zip packaging." -ForegroundColor Yellow
    } else {
        Write-Host "Building installer with Inno Setup..." -ForegroundColor Cyan
        & $isccPath $issFile
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Success! Installer created in installer\Output\" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "Inno Setup compilation failed, falling back to zip." -ForegroundColor Yellow
        }
    }
}

Write-Host "Creating ZIP of release output..." -ForegroundColor Cyan
$zipPath = Join-Path $projectRoot 'installer\my_school_windows_installer.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $outputDir '*') -DestinationPath $zipPath

if (Test-Path $zipPath) {
    Write-Host "Packaged installer zip created at: $zipPath" -ForegroundColor Green
} else {
    Write-Host "Failed to create installer zip." -ForegroundColor Red
}
