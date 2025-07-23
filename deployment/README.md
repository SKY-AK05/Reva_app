# Reva Mobile App Deployment Guide

This guide covers the deployment process for the Reva mobile application to both Google Play Store and Apple App Store.

## Prerequisites

### Development Environment
- Flutter SDK (latest stable version)
- Android Studio with Android SDK
- Xcode (for iOS builds, macOS only)
- Valid developer accounts for Google Play and Apple App Store

### Certificates and Keys
- Android: Release keystore file
- iOS: Distribution certificate and provisioning profiles
- App Store Connect access

## Environment Configuration

### 1. Environment Files
Create environment-specific configuration files:

```bash
# Development
.env.dev

# Staging  
.env.staging

# Production
.env.production
```

### 2. Android Signing
Configure `android/key.properties` with your release keystore:

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=../path/to/your/keystore.jks
```

### 3. iOS Configuration
- Configure signing in Xcode
- Set up provisioning profiles
- Configure App Store Connect

## Build Process

### Android Builds

#### Development Build
```bash
# Debug APK
flutter build apk --debug --flavor dev

# Release APK  
flutter build apk --release --flavor dev
```

#### Staging Build
```bash
# App Bundle for internal testing
flutter build appbundle --release --flavor stage
```

#### Production Build
```bash
# App Bundle for Play Store
flutter build appbundle --release --flavor prod
```

### iOS Builds

#### Development Build
```bash
flutter build ios --debug --no-codesign
```

#### Production Build
```bash
flutter build ios --release
```

Then use Xcode to:
1. Archive the build
2. Upload to App Store Connect
3. Submit for review

## App Store Assets

### App Icons
- Android: Various sizes in `android/app/src/main/res/mipmap-*`
- iOS: App icon set in `ios/Runner/Assets.xcassets/AppIcon.appiconset`

### Screenshots
Required sizes for both platforms:
- Phone screenshots (various screen sizes)
- Tablet screenshots (if supporting tablets)
- Feature graphics (Android)

### App Store Descriptions
See `deployment/store_listings/` for platform-specific descriptions.

## CI/CD Pipeline

### GitHub Actions
The repository includes GitHub Actions workflows for:
- Automated testing
- Build generation
- Deployment to app stores

### Manual Deployment Steps
1. Update version numbers in `pubspec.yaml`
2. Run tests: `flutter test`
3. Build for target platform
4. Upload to respective app store
5. Submit for review

## Version Management

### Version Numbering
Follow semantic versioning: `MAJOR.MINOR.PATCH+BUILD`

Example: `1.2.3+45`
- `1.2.3`: Version name (user-facing)
- `45`: Build number (internal)

### Release Notes
Maintain release notes in `deployment/release_notes/` for each version.

## Testing Before Release

### Pre-deployment Checklist
- [ ] All tests pass
- [ ] App builds successfully for all flavors
- [ ] Manual testing on physical devices
- [ ] Performance testing
- [ ] Security review
- [ ] App store guidelines compliance

### Testing Environments
- Development: Local testing
- Staging: Internal testing with staging backend
- Production: Final testing with production backend

## Monitoring and Analytics

### Crash Reporting
- Configure crash reporting service
- Monitor app stability post-release

### Performance Monitoring
- Track app performance metrics
- Monitor user engagement

## Rollback Plan

### Emergency Rollback
If critical issues are discovered post-release:
1. Immediately remove app from stores (if necessary)
2. Prepare hotfix release
3. Communicate with users
4. Deploy fixed version

## Support and Maintenance

### Post-Release
- Monitor app store reviews
- Track crash reports
- Plan regular updates
- Maintain backward compatibility

## Security Considerations

### Code Obfuscation
- Enable ProGuard for Android release builds
- Use Flutter's built-in obfuscation

### API Security
- Secure API endpoints
- Implement proper authentication
- Use HTTPS for all communications

### Data Protection
- Encrypt sensitive local data
- Comply with privacy regulations (GDPR, CCPA)
- Implement proper data retention policies

## Troubleshooting

### Common Issues
- Build failures: Check dependencies and configurations
- Signing issues: Verify certificates and provisioning profiles
- App store rejections: Review guidelines and fix issues

### Support Contacts
- Development team: [team-email]
- DevOps: [devops-email]
- App store contacts: [store-contacts]

## Resources

### Documentation
- [Flutter Deployment Guide](https://flutter.dev/docs/deployment)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)

### Tools
- [Fastlane](https://fastlane.tools/) - Automation tool
- [Codemagic](https://codemagic.io/) - CI/CD for Flutter
- [App Store Connect API](https://developer.apple.com/app-store-connect/api/)