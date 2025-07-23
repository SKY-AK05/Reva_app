#!/bin/bash

# Reva Mobile App Environment Setup Script
# This script sets up the development environment for the Reva mobile app

set -e

echo "🚀 Setting up Reva Mobile App environment..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    echo "Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ Flutter found: $(flutter --version | head -n 1)"

# Check Flutter doctor
echo "🔍 Running Flutter doctor..."
flutter doctor

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Generate code (if needed)
echo "🔧 Generating code..."
if [ -f "pubspec.yaml" ] && grep -q "build_runner" pubspec.yaml; then
    flutter packages pub run build_runner build --delete-conflicting-outputs
fi

# Setup Android signing (if key.properties doesn't exist)
if [ ! -f "android/key.properties" ]; then
    echo "🔐 Setting up Android signing configuration..."
    cp android/key.properties.template android/key.properties
    echo "⚠️  Please edit android/key.properties with your actual signing configuration"
fi

# Check for environment file
if [ ! -f ".env" ]; then
    echo "🌍 Creating environment file..."
    cat > .env << EOF
# Supabase Configuration
SUPABASE_URL=your_supabase_url_here
SUPABASE_ANON_KEY=your_supabase_anon_key_here

# API Configuration
API_BASE_URL=https://reva-backend-8bcr.onrender.com/api/v1/chat

# Environment
ENVIRONMENT=development
EOF
    echo "⚠️  Please edit .env with your actual configuration values"
fi

# Create build directories
echo "📁 Creating build directories..."
mkdir -p build/android
mkdir -p build/ios

# iOS setup (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 Setting up iOS dependencies..."
    cd ios
    if command -v pod &> /dev/null; then
        pod install
        echo "✅ iOS pods installed"
    else
        echo "⚠️  CocoaPods not found. Please install CocoaPods for iOS development"
        echo "Run: sudo gem install cocoapods"
    fi
    cd ..
fi

echo "✅ Environment setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit android/key.properties with your signing configuration"
echo "2. Edit .env with your Supabase and API configuration"
echo "3. Run 'flutter run' to start development"
echo ""
echo "For production builds:"
echo "- Android: flutter build apk --release"
echo "- iOS: flutter build ios --release"