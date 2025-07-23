# Reva Mobile App Environment Setup Script (PowerShell)
# This script sets up the development environment for the Reva mobile app

param(
    [switch]$SkipDoctor = $false
)

Write-Host "🚀 Setting up Reva Mobile App environment..." -ForegroundColor Green

# Check if Flutter is installed
try {
    $flutterVersion = flutter --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Flutter found: $($flutterVersion.Split("`n")[0])" -ForegroundColor Green
    } else {
        throw "Flutter not found"
    }
} catch {
    Write-Host "❌ Flutter is not installed. Please install Flutter first." -ForegroundColor Red
    Write-Host "Visit: https://flutter.dev/docs/get-started/install" -ForegroundColor Yellow
    exit 1
}

# Check Flutter doctor (unless skipped)
if (-not $SkipDoctor) {
    Write-Host "🔍 Running Flutter doctor..." -ForegroundColor Blue
    flutter doctor
}

# Get dependencies
Write-Host "📦 Getting Flutter dependencies..." -ForegroundColor Blue
flutter pub get

# Generate code (if needed)
Write-Host "🔧 Generating code..." -ForegroundColor Blue
if (Test-Path "pubspec.yaml") {
    $pubspecContent = Get-Content "pubspec.yaml" -Raw
    if ($pubspecContent -match "build_runner") {
        flutter packages pub run build_runner build --delete-conflicting-outputs
    }
}

# Setup Android signing (if key.properties doesn't exist)
if (-not (Test-Path "android/key.properties")) {
    Write-Host "🔐 Setting up Android signing configuration..." -ForegroundColor Blue
    Copy-Item "android/key.properties.template" "android/key.properties"
    Write-Host "⚠️  Please edit android/key.properties with your actual signing configuration" -ForegroundColor Yellow
}

# Check for environment file
if (-not (Test-Path ".env")) {
    Write-Host "🌍 Creating environment file..." -ForegroundColor Blue
    @"
# Supabase Configuration
SUPABASE_URL=your_supabase_url_here
SUPABASE_ANON_KEY=your_supabase_anon_key_here

# API Configuration
API_BASE_URL=https://reva-backend-8bcr.onrender.com/api/v1/chat

# Environment
ENVIRONMENT=development
"@ | Out-File -FilePath ".env" -Encoding UTF8
    Write-Host "⚠️  Please edit .env with your actual configuration values" -ForegroundColor Yellow
}

# Create build directories
Write-Host "📁 Creating build directories..." -ForegroundColor Blue
New-Item -ItemType Directory -Force -Path "build/android" | Out-Null
New-Item -ItemType Directory -Force -Path "build/ios" | Out-Null

Write-Host "✅ Environment setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Edit android/key.properties with your signing configuration" -ForegroundColor White
Write-Host "2. Edit .env with your Supabase and API configuration" -ForegroundColor White
Write-Host "3. Run 'flutter run' to start development" -ForegroundColor White
Write-Host ""
Write-Host "For production builds:" -ForegroundColor Cyan
Write-Host "- Android: flutter build apk --release" -ForegroundColor White
Write-Host "- iOS: flutter build ios --release" -ForegroundColor White