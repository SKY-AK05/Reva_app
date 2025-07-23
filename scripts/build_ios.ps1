# iOS Build Script for Reva Mobile App
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "stage", "prod")]
    [string]$Environment,
    
    [ValidateSet("debug", "release")]
    [string]$BuildType = "release"
)

# Check if running on macOS (required for iOS builds)
if ($env:OS -eq "Windows_NT") {
    Write-Host "❌ iOS builds are only supported on macOS" -ForegroundColor Red
    Write-Host "Please use a macOS machine or CI/CD service for iOS builds" -ForegroundColor Yellow
    exit 1
}

Write-Host "🍎 Building iOS app for $Environment environment..." -ForegroundColor Green

# Set environment variables based on flavor
switch ($Environment) {
    "dev" {
        $env:ENVIRONMENT = "development"
        $scheme = "dev"
    }
    "stage" {
        $env:ENVIRONMENT = "staging"
        $scheme = "stage"
    }
    "prod" {
        $env:ENVIRONMENT = "production"
        $scheme = "Runner"
    }
}

# Clean previous builds
Write-Host "🧹 Cleaning previous builds..." -ForegroundColor Blue
flutter clean
flutter pub get

# Install iOS dependencies
Write-Host "📦 Installing iOS dependencies..." -ForegroundColor Blue
Set-Location ios
pod install
Set-Location ..

# Build the app
Write-Host "🔨 Building iOS app..." -ForegroundColor Blue

try {
    if ($BuildType -eq "debug") {
        flutter build ios --debug --no-codesign
    } else {
        flutter build ios --release --no-codesign
    }
    
    Write-Host "✅ Build completed successfully!" -ForegroundColor Green
    Write-Host "📦 Output location: build/ios/iphoneos/Runner.app" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Build failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 iOS build process completed!" -ForegroundColor Green
Write-Host "Note: For App Store distribution, you'll need to:" -ForegroundColor Yellow
Write-Host "1. Open the project in Xcode" -ForegroundColor White
Write-Host "2. Configure signing & capabilities" -ForegroundColor White
Write-Host "3. Archive and upload to App Store Connect" -ForegroundColor White