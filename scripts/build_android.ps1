# Android Build Script for Reva Mobile App
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "stage", "prod")]
    [string]$Environment,
    
    [ValidateSet("debug", "release")]
    [string]$BuildType = "release",
    
    [ValidateSet("apk", "appbundle")]
    [string]$OutputType = "apk"
)

Write-Host "🤖 Building Android app for $Environment environment..." -ForegroundColor Green

# Set environment variables based on flavor
switch ($Environment) {
    "dev" {
        $env:ENVIRONMENT = "development"
        $flavor = "dev"
    }
    "stage" {
        $env:ENVIRONMENT = "staging"
        $flavor = "stage"
    }
    "prod" {
        $env:ENVIRONMENT = "production"
        $flavor = "prod"
    }
}

# Clean previous builds
Write-Host "🧹 Cleaning previous builds..." -ForegroundColor Blue
flutter clean
flutter pub get

# Build the app
Write-Host "🔨 Building $OutputType for $flavor flavor..." -ForegroundColor Blue

try {
    if ($OutputType -eq "apk") {
        if ($BuildType -eq "debug") {
            flutter build apk --debug --flavor $flavor
        } else {
            flutter build apk --release --flavor $flavor
        }
    } else {
        if ($BuildType -eq "debug") {
            flutter build appbundle --debug --flavor $flavor
        } else {
            flutter build appbundle --release --flavor $flavor
        }
    }
    
    Write-Host "✅ Build completed successfully!" -ForegroundColor Green
    
    # Show output location
    $buildPath = "build/app/outputs/flutter-apk"
    if ($OutputType -eq "appbundle") {
        $buildPath = "build/app/outputs/bundle"
    }
    
    Write-Host "📦 Output location: $buildPath" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ Build failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Android build process completed!" -ForegroundColor Green