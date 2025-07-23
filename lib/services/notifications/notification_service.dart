import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/logger.dart';
import 'supabase_notification_service.dart';
import 'notification_permission_handler.dart';

/// Service for managing local and push notifications
/// Integrates with SupabaseNotificationService for push notifications
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  
  NotificationService._();

  bool _isInitialized = false;
  bool _permissionsGranted = false;
  final Map<int, Timer> _scheduledNotifications = {};
  late final SupabaseNotificationService _supabaseNotificationService;
  late final NotificationPermissionHandler _permissionHandler;

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_isInitialized) return _permissionsGranted;

    try {
      Logger.info('Initializing NotificationService with Supabase integration');
      
      // Initialize permission handler
      _permissionHandler = NotificationPermissionHandler.instance;
      
      // Initialize Supabase notification service
      _supabaseNotificationService = SupabaseNotificationService.instance;
      final supabaseInitialized = await _supabaseNotificationService.initialize();
      
      // Initialize local notification permissions
      _permissionsGranted = await requestPermissions();
      
      _isInitialized = true;
      
      Logger.info('NotificationService initialized successfully (Supabase: $supabaseInitialized, Local: $_permissionsGranted)');
      return _permissionsGranted;
    } catch (e) {
      Logger.error('Failed to initialize NotificationService: $e');
      return false;
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      Logger.info('Requesting notification permissions via permission handler');
      
      // Use the permission handler to request permissions
      _permissionsGranted = await _permissionHandler.requestPermissions();
      
      Logger.info('Notification permissions: ${_permissionsGranted ? 'granted' : 'denied'}');
      return _permissionsGranted;
    } catch (e) {
      Logger.error('Failed to request notification permissions: $e');
      return false;
    }
  }

  /// Check if notifications are enabled
  bool get areNotificationsEnabled => _permissionsGranted;

  /// Check if push notifications are enabled
  bool get arePushNotificationsEnabled => 
      _isInitialized && _supabaseNotificationService.areNotificationsEnabled;

  /// Get notification permission status message
  String getPermissionStatusMessage() {
    if (!_isInitialized) {
      return 'Notification service not initialized. Please restart the app.';
    }
    
    if (!_permissionsGranted) {
      return _permissionHandler.getPermissionStatusMessage();
    }
    
    if (!arePushNotificationsEnabled) {
      return _supabaseNotificationService.getPermissionStatusMessage();
    }
    
    return 'Notifications are enabled and working properly.';
  }

  /// Get instructions for enabling notifications
  String getEnableInstructions() {
    if (!_isInitialized) {
      return 'Please restart the app to initialize notifications.';
    }
    
    return _permissionHandler.getEnableInstructions();
  }

  /// Check if we should show permission rationale
  bool shouldShowPermissionRationale() {
    if (!_isInitialized) return false;
    return _permissionHandler.shouldShowPermissionRationale();
  }

  /// Get permission rationale message
  String getPermissionRationale() {
    if (!_isInitialized) return 'Notification permissions help you stay on top of your reminders.';
    return _permissionHandler.getPermissionRationale();
  }

  /// Show an immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized || !_permissionsGranted) {
      Logger.warning('Cannot show notification: service not initialized or permissions not granted');
      return;
    }

    try {
      // For now, just log the notification
      // This should be replaced with actual notification display when notification packages are added
      Logger.info('Showing notification: $title - $body');
    } catch (e) {
      Logger.error('Failed to show notification: $e');
    }
  }

  /// Schedule a notification for a future time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String? reminderId,
  }) async {
    if (!_isInitialized || !_permissionsGranted) {
      Logger.warning('Cannot schedule notification: service not initialized or permissions not granted');
      return;
    }

    // Don't schedule notifications for past dates
    if (scheduledDate.isBefore(DateTime.now())) {
      Logger.warning('Cannot schedule notification for past date: $scheduledDate');
      return;
    }

    try {
      // Cancel existing notification with same ID
      _scheduledNotifications[id]?.cancel();
      
      // Schedule push notification via Supabase if available
      if (arePushNotificationsEnabled && reminderId != null) {
        final pushScheduled = await _supabaseNotificationService.scheduleNotification(
          title: title,
          body: body,
          scheduledTime: scheduledDate,
          data: payload != null ? {'payload': payload} : null,
          reminderId: reminderId,
        );
        
        if (pushScheduled) {
          Logger.info('Push notification scheduled successfully for reminder: $reminderId');
        } else {
          Logger.warning('Failed to schedule push notification, falling back to local notification');
        }
      }
      
      // Always schedule local notification as fallback
      final delay = scheduledDate.difference(DateTime.now());
      _scheduledNotifications[id] = Timer(delay, () {
        showNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        );
        _scheduledNotifications.remove(id);
      });

      Logger.debug('Scheduled notification: $title for ${scheduledDate.toIso8601String()}');
    } catch (e) {
      Logger.error('Failed to schedule notification: $e');
    }
  }

  /// Schedule a push notification for reminders
  Future<bool> schedulePushNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String reminderId,
    Map<String, dynamic>? data,
  }) async {
    if (!_isInitialized || !arePushNotificationsEnabled) {
      Logger.warning('Cannot schedule push notification: service not initialized or push notifications not enabled');
      return false;
    }

    try {
      return await _supabaseNotificationService.scheduleNotification(
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        reminderId: reminderId,
        data: data,
      );
    } catch (e) {
      Logger.error('Failed to schedule push notification: $e');
      return false;
    }
  }

  /// Handle notification tap from system
  void handleNotificationTap(Map<String, dynamic> notificationData, [BuildContext? context]) {
    if (!_isInitialized) {
      Logger.warning('Cannot handle notification tap: service not initialized');
      return;
    }

    try {
      if (context != null) {
        _supabaseNotificationService.handleNotificationTap(notificationData, context);
      } else {
        // Fallback when context is not available
        Logger.warning('Context not available for notification tap handling');
      }
    } catch (e) {
      Logger.error('Failed to handle notification tap: $e');
    }
  }

  /// Handle foreground notification
  void handleForegroundNotification(Map<String, dynamic> notificationData) {
    if (!_isInitialized) {
      Logger.warning('Cannot handle foreground notification: service not initialized');
      return;
    }

    try {
      _supabaseNotificationService.handleForegroundNotification(notificationData);
    } catch (e) {
      Logger.error('Failed to handle foreground notification: $e');
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    if (!_isInitialized) {
      Logger.warning('Cannot cancel notification: service not initialized');
      return;
    }

    try {
      _scheduledNotifications[id]?.cancel();
      _scheduledNotifications.remove(id);
      Logger.debug('Cancelled notification with id: $id');
    } catch (e) {
      Logger.error('Failed to cancel notification: $e');
    }
  }

  /// Cancel a push notification for a specific reminder
  Future<bool> cancelPushNotification({required String reminderId}) async {
    if (!_isInitialized || !arePushNotificationsEnabled) {
      Logger.warning('Cannot cancel push notification: service not initialized or push notifications not enabled');
      return false;
    }

    try {
      return await _supabaseNotificationService.cancelNotification(reminderId: reminderId);
    } catch (e) {
      Logger.error('Failed to cancel push notification: $e');
      return false;
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (!_isInitialized) {
      Logger.warning('Cannot cancel notifications: service not initialized');
      return;
    }

    try {
      for (final timer in _scheduledNotifications.values) {
        timer.cancel();
      }
      _scheduledNotifications.clear();
      Logger.debug('Cancelled all notifications');
    } catch (e) {
      Logger.error('Failed to cancel all notifications: $e');
    }
  }

  /// Get pending notifications count
  Future<int> getPendingNotificationsCount() async {
    if (!_isInitialized) {
      Logger.warning('Cannot get pending notifications: service not initialized');
      return 0;
    }

    try {
      final count = _scheduledNotifications.length;
      Logger.debug('Found $count pending notifications');
      return count;
    } catch (e) {
      Logger.error('Failed to get pending notifications: $e');
      return 0;
    }
  }

  /// Dispose the service
  void dispose() {
    Logger.info('Disposing NotificationService');
    
    // Cancel all scheduled notifications
    for (final timer in _scheduledNotifications.values) {
      timer.cancel();
    }
    _scheduledNotifications.clear();
    
    // Dispose Supabase notification service
    if (_isInitialized) {
      _supabaseNotificationService.dispose();
    }
  }
}