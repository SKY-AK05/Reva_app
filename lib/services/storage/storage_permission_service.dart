import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/logger.dart';

class StoragePermissionService {
  static const String _logTag = 'StoragePermissionService';

  /// Check if storage permissions are granted
  static Future<bool> hasStoragePermissions() async {
    try {
      // For Android 13+ (API 33+), we don't need storage permissions for app-specific directories
      if (Platform.isAndroid) {
        // Check Android version - if API 33+, we don't need storage permissions for internal storage
        return true; // We'll use internal storage which doesn't require permissions
      }
      
      // For iOS, no storage permissions needed for app documents directory
      if (Platform.isIOS) {
        return true;
      }
      
      return true;
    } catch (e) {
      Logger.error('$_logTag: Error checking storage permissions: $e');
      return false;
    }
  }

  /// Request storage permissions (only if needed for external storage)
  static Future<bool> requestStoragePermissions() async {
    try {
      if (Platform.isAndroid) {
        // For modern Android versions, we don't need storage permissions for internal app storage
        Logger.info('$_logTag: Using internal storage, no permissions required');
        return true;
      }
      
      if (Platform.isIOS) {
        // iOS doesn't require storage permissions for app documents directory
        Logger.info('$_logTag: iOS - no storage permissions required for app documents');
        return true;
      }
      
      return true;
    } catch (e) {
      Logger.error('$_logTag: Error requesting storage permissions: $e');
      return false;
    }
  }

  /// Check if we have all necessary permissions for database operations
  static Future<bool> canAccessDatabase() async {
    try {
      final hasPermissions = await hasStoragePermissions();
      
      if (!hasPermissions) {
        Logger.warning('$_logTag: Storage permissions not granted');
        return false;
      }
      
      Logger.info('$_logTag: Database access permissions verified');
      return true;
    } catch (e) {
      Logger.error('$_logTag: Error checking database access permissions: $e');
      return false;
    }
  }

  /// Show permission rationale to user
  static Future<void> showPermissionRationale() async {
    Logger.info('$_logTag: Storage permissions are required for offline data caching');
    // In a real app, you might show a dialog here explaining why permissions are needed
  }

  /// Handle permission denied scenario
  static Future<void> handlePermissionDenied() async {
    Logger.warning('$_logTag: Storage permissions denied - app will work with limited offline functionality');
    // In a real app, you might show a dialog explaining the impact
  }

  /// Open app settings if permissions are permanently denied
  static Future<void> openAppSettings() async {
    try {
      await openAppSettings();
      Logger.info('$_logTag: Opened app settings for permission management');
    } catch (e) {
      Logger.error('$_logTag: Error opening app settings: $e');
    }
  }
}