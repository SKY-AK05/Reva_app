@echo off
echo Building Reva Android App...

REM Development build
echo Building development APK...
flutter build apk --debug --flavor dev --dart-define=ENVIRONMENT=development

REM Staging build
echo Building staging APK...
flutter build apk --release --flavor stage --dart-define=ENVIRONMENT=staging

REM Production build
echo Building production APK...
flutter build apk --release --flavor prod --dart-define=ENVIRONMENT=production

echo Build complete!
pause