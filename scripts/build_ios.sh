#!/bin/bash
echo "Building Reva iOS App..."

# Development build
echo "Building development IPA..."
flutter build ios --debug --flavor dev --dart-define=ENVIRONMENT=development

# Staging build
echo "Building staging IPA..."
flutter build ios --release --flavor stage --dart-define=ENVIRONMENT=staging

# Production build
echo "Building production IPA..."
flutter build ios --release --flavor prod --dart-define=ENVIRONMENT=production

echo "Build complete!"