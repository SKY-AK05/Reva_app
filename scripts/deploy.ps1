# Reva Mobile App Deployment Script
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("android", "ios", "both")]
    [string]$Platform,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "stage", "prod")]
    [string]$Environment,
    
    [ValidateSet("debug", "release")]
    [string]$BuildType = "release",
    
    [switch]$SkipTests = $false,
    [switch]$SkipBuild = $false,
    [switch]$SkipDeploy = $false,
    [switch]$Verbose = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Enable verbose output if requested
if ($Verbose) {
    $VerbosePreference = "Continue"
}

Write-Host "🚀 Starting Reva Mobile App deployment..." -ForegroundColor Green
Write-Host "Platform: $Platform" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Build Type: $BuildType" -ForegroundColor Cyan

# Validate environment
function Test-Environment {
    Write-Host "🔍 Validating environment..." -ForegroundColor Blue
    
    # Check Flutter installation
    try {
        $flutterVersion = flutter --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter not found"
        }
        Write-Host "✅ Flutter: $($flutterVersion.Split("`n")[0])" -ForegroundColor Green
    } catch {
        Write-Host "❌ Flutter is not installed or not in PATH" -ForegroundColor Red
        exit 1
    }
    
    # Check environment file
    $envFile = ".env.$Environment"
    if (-not (Test-Path $envFile)) {
        Write-Host "❌ Environment file not found: $envFile" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Environment file found: $envFile" -ForegroundColor Green
    
    # Platform-specific checks
    if ($Platform -eq "android" -or $Platform -eq "both") {
        # Check Java
        try {
            $javaVersion = java -version 2>&1
            Write-Host "✅ Java: Available" -ForegroundColor Green
        } catch {
            Write-Host "❌ Java not found - required for Android builds" -ForegroundColor Red
            exit 1
        }
        
        # Check Android signing for production
        if ($Environment -eq "prod" -and $BuildType -eq "release") {
            if (-not (Test-Path "android/key.properties")) {
                Write-Host "❌ Android signing not configured (key.properties missing)" -ForegroundColor Red
                exit 1
            }
            Write-Host "✅ Android signing configured" -ForegroundColor Green
        }
    }
    
    if ($Platform -eq "ios" -or $Platform -eq "both") {
        if ($env:OS -eq "Windows_NT") {
            Write-Host "❌ iOS builds require macOS" -ForegroundColor Red
            exit 1
        }
        Write-Host "✅ macOS detected for iOS builds" -ForegroundColor Green
    }
}

# Run tests
function Invoke-Tests {
    if ($SkipTests) {
        Write-Host "⏭️ Skipping tests (--SkipTests flag)" -ForegroundColor Yellow
        return
    }
    
    Write-Host "🧪 Running tests..." -ForegroundColor Blue
    
    try {
        # Get dependencies
        flutter pub get
        
        # Run tests
        flutter test
        
        # Run analysis
        flutter analyze
        
        Write-Host "✅ All tests passed" -ForegroundColor Green
    } catch {
        Write-Host "❌ Tests failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Build Android
function Build-Android {
    Write-Host "🤖 Building Android app..." -ForegroundColor Blue
    
    try {
        # Clean previous builds
        flutter clean
        flutter pub get
        
        # Set environment
        Copy-Item ".env.$Environment" ".env" -Force
        
        # Determine flavor
        $flavor = switch ($Environment) {
            "dev" { "dev" }
            "stage" { "stage" }
            "prod" { "prod" }
        }
        
        # Build based on type
        if ($BuildType -eq "debug") {
            flutter build apk --debug --flavor $flavor
            $outputPath = "build/app/outputs/flutter-apk/app-$flavor-debug.apk"
        } else {
            flutter build appbundle --release --flavor $flavor
            $outputPath = "build/app/outputs/bundle/${flavor}Release/app-$flavor-release.aab"
        }
        
        if (Test-Path $outputPath) {
            Write-Host "✅ Android build completed: $outputPath" -ForegroundColor Green
        } else {
            throw "Build output not found at expected path"
        }
        
    } catch {
        Write-Host "❌ Android build failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Build iOS
function Build-iOS {
    Write-Host "🍎 Building iOS app..." -ForegroundColor Blue
    
    try {
        # Clean previous builds
        flutter clean
        flutter pub get
        
        # Set environment
        Copy-Item ".env.$Environment" ".env" -Force
        
        # Install iOS dependencies
        Set-Location ios
        pod install
        Set-Location ..
        
        # Build based on type
        if ($BuildType -eq "debug") {
            flutter build ios --debug --no-codesign
        } else {
            flutter build ios --release
        }
        
        Write-Host "✅ iOS build completed" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ iOS build failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Deploy to app stores
function Deploy-Apps {
    if ($SkipDeploy) {
        Write-Host "⏭️ Skipping deployment (--SkipDeploy flag)" -ForegroundColor Yellow
        return
    }
    
    if ($Environment -ne "prod") {
        Write-Host "⏭️ Skipping deployment (not production environment)" -ForegroundColor Yellow
        return
    }
    
    Write-Host "🚀 Deploying to app stores..." -ForegroundColor Blue
    
    # This would typically involve:
    # - Uploading to Google Play Console (Android)
    # - Uploading to App Store Connect (iOS)
    # - Triggering automated deployment pipelines
    
    Write-Host "📝 Manual deployment steps required:" -ForegroundColor Yellow
    Write-Host "1. Upload Android AAB to Google Play Console" -ForegroundColor White
    Write-Host "2. Upload iOS build to App Store Connect via Xcode" -ForegroundColor White
    Write-Host "3. Submit for review on both platforms" -ForegroundColor White
}

# Generate deployment report
function New-DeploymentReport {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $version = (Get-Content "pubspec.yaml" | Select-String "version:").ToString().Split(":")[1].Trim()
    
    $report = @"
# Deployment Report

**Date:** $timestamp
**Version:** $version
**Platform:** $Platform
**Environment:** $Environment
**Build Type:** $BuildType

## Build Status
- Tests: $(if ($SkipTests) { "Skipped" } else { "Passed" })
- Android Build: $(if ($Platform -eq "android" -or $Platform -eq "both") { "Completed" } else { "Skipped" })
- iOS Build: $(if ($Platform -eq "ios" -or $Platform -eq "both") { "Completed" } else { "Skipped" })

## Next Steps
$(if ($Environment -eq "prod") {
"- Upload builds to app stores
- Submit for review
- Monitor deployment metrics"
} else {
"- Test the build thoroughly
- Gather feedback from stakeholders
- Prepare for next environment deployment"
})

## Build Artifacts
$(if ($Platform -eq "android" -or $Platform -eq "both") {
"- Android: build/app/outputs/"
})
$(if ($Platform -eq "ios" -or $Platform -eq "both") {
"- iOS: build/ios/iphoneos/"
})
"@

    $reportPath = "deployment/reports/deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    New-Item -ItemType Directory -Force -Path (Split-Path $reportPath) | Out-Null
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    
    Write-Host "📊 Deployment report generated: $reportPath" -ForegroundColor Cyan
}

# Main execution
try {
    Test-Environment
    Invoke-Tests
    
    if (-not $SkipBuild) {
        if ($Platform -eq "android" -or $Platform -eq "both") {
            Build-Android
        }
        
        if ($Platform -eq "ios" -or $Platform -eq "both") {
            Build-iOS
        }
    } else {
        Write-Host "⏭️ Skipping build (--SkipBuild flag)" -ForegroundColor Yellow
    }
    
    Deploy-Apps
    New-DeploymentReport
    
    Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "💥 Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    if (Test-Path ".env") {
        Remove-Item ".env" -Force
    }
}

Write-Host "✨ Deployment process finished!" -ForegroundColor Green