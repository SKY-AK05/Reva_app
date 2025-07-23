import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/supabase_service.dart';
import '../navigation/deep_link_service.dart';
import '../../utils/logger.dart';
import 'platform_notification_service.dart';

/// Service for handling push notifications via Supabase Edge Functions
class SupabaseNotificationService {
  static SupabaseNotificationService? _instance;
  static SupabaseNotificationService get instance => _instance ??= SupabaseNotificationService._();
  
  SupabaseNotificationService._();

  bool _isInitialized = false;
  bool _permissionsGranted = false;
  String? _deviceToken;
  final Map<String, StreamSubscription> _subscriptions = {};

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_isInitialized) return _permissionsGranted;

    try {
      Logger.info('Initializing SupabaseNotificationService');
      
      // Request notification permissions first
      _permissionsGranted = await requestPermissions();
      
      if (_permissionsGranted) {
        // Generate a device token (in a real implementation, this would come from FCM/APNs)
        _deviceToken = _generateDeviceToken();
        
        // Register device token with Supabase
        await _registerDeviceToken();
        
        // Set up notification listeners
        await _setupNotificationListeners();
      }
      
      _isInitialized = true;
      Logger.info('SupabaseNotificationService initialized successfully');
      return _permissionsGranted;
    } catch (e) {
      Logger.error('Failed to initialize SupabaseNotificationService: $e');
      return false;
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      Logger.info('Requesting notification permissions');
      
      // Initialize platform notification service
      await PlatformNotificationService().initialize();
      
      // Request permissions through platform service
      _permissionsGranted = await PlatformNotificationService().requestPermissions();
      
      Logger.info('Notification permissions: ${_permissionsGranted ? "granted" : "denied"}');
      return _permissionsGranted;
    } catch (e) {
      Logger.error('Failed to request notification permissions: $e');
      return false;
    }
  }

  /// Check if notifications are enabled
  bool get areNotificationsEnabled => _permissionsGranted;

  /// Get the current device token
  String? get deviceToken => _deviceToken;

  /// Schedule a push notification via Supabase Edge Function
  Future<bool> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    Map<String, dynamic>? data,
    String? reminderId,
  }) async {
    if (!_isInitialized || !_permissionsGranted) {
      Logger.warning('Cannot schedule notification: service not initialized or permissions not granted');
      return false;
    }

    if (!SupabaseService.isAuthenticated) {
      Logger.warning('Cannot schedule notification: user not authenticated');
      return false;
    }

    try {
      Logger.info('Scheduling push notification: $title');
      
      // Prepare notification data with deep link information
      final notificationData = <String, dynamic>{
        ...?data,
      };
      
      // Add deep link data for reminders
      if (reminderId != null) {
        notificationData.addAll(DeepLinkService.generateReminderNotificationData(reminderId));
      }
      
      final payload = {
        'user_id': SupabaseService.currentUserId,
        'device_token': _deviceToken,
        'title': title,
        'body': body,
        'scheduled_time': scheduledTime.toIso8601String(),
        'data': notificationData,
        'reminder_id': reminderId,
      };

      // Schedule local notification as backup
      final notificationId = reminderId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
      await PlatformNotificationService().scheduleNotification(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: scheduledTime,
        payload: jsonEncode(notificationData),
        channelId: 'reva_reminders',
      );

      // Call Supabase Edge Function to schedule notification
      final response = await SupabaseService.client.functions.invoke(
        'schedule-notification',
        body: payload,
      );

      if (response.status == 200) {
        Logger.info('Push notification scheduled successfully');
        return true;
      } else {
        Logger.error('Failed to schedule push notification: ${response.status}');
        // Local notification is still scheduled as fallback
        return true;
      }
    } catch (e) {
      Logger.error('Error scheduling push notification: $e');
      return false;
    }
  }

  /// Cancel a scheduled notification
  Future<bool> cancelNotification({required String reminderId}) async {
    if (!_isInitialized || !_permissionsGranted) {
      Logger.warning('Cannot cancel notification: service not initialized or permissions not granted');
      return false;
    }

    if (!SupabaseService.isAuthenticated) {
      Logger.warning('Cannot cancel notification: user not authenticated');
      return false;
    }

    try {
      Logger.info('Cancelling push notification for reminder: $reminderId');
      
      final payload = {
        'user_id': SupabaseService.currentUserId,
        'reminder_id': reminderId,
      };

      // Cancel local notification
      final notificationId = reminderId.hashCode;
      await PlatformNotificationService().cancelNotification(notificationId);

      // Call Supabase Edge Function to cancel notification
      final response = await SupabaseService.client.functions.invoke(
        'cancel-notification',
        body: payload,
      );

      if (response.status == 200) {
        Logger.info('Push notification cancelled successfully');
        return true;
      } else {
        Logger.error('Failed to cancel push notification: ${response.status}');
        // Local notification was still cancelled
        return true;
      }
    } catch (e) {
      Logger.error('Error cancelling push notification: $e');
      return false;
    }
  }

  /// Send an immediate push notification
  Future<bool> sendImmediateNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? targetUserId,
  }) async {
    if (!_isInitialized || !_permissionsGranted) {
      Logger.warning('Cannot send notification: service not initialized or permissions not granted');
      return false;
    }

    if (!SupabaseService.isAuthenticated) {
      Logger.warning('Cannot send notification: user not authenticated');
      return false;
    }

    try {
      Logger.info('Sending immediate push notification: $title');
      
      final payload = {
        'user_id': targetUserId ?? SupabaseService.currentUserId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'immediate': true,
      };

      // Call Supabase Edge Function to send immediate notification
      final response = await SupabaseService.client.functions.invoke(
        'send-notification',
        body: payload,
      );

      if (response.status == 200) {
        Logger.info('Immediate push notification sent successfully');
        return true;
      } else {
        Logger.error('Failed to send immediate push notification: ${response.status}');
        return false;
      }
    } catch (e) {
      Logger.error('Error sending immediate push notification: $e');
      return false;
    }
  }

  /// Handle incoming notification when app is in foreground
  void handleForegroundNotification(Map<String, dynamic> notification) {
    try {
      Logger.info('Handling foreground notification: ${notification['title']}');
      
      // Extract notification data
      final title = notification['title'] as String? ?? 'Notification';
      final body = notification['body'] as String? ?? '';
      final data = notification['data'] as Map<String, dynamic>? ?? {};
      
      // Show in-app notification or handle as needed
      _showInAppNotification(title, body, data);
      
    } catch (e) {
      Logger.error('Error handling foreground notification: $e');
    }
  }

  /// Handle notification tap when app is opened from notification
  void handleNotificationTap(Map<String, dynamic> notification, BuildContext context) {
    try {
      Logger.info('Handling notification tap: ${notification['title']}');
      
      final data = notification['data'] as Map<String, dynamic>? ?? {};
      
      // Use deep link service to handle navigation
      DeepLinkService.handleNotificationTap(context, data);
      
    } catch (e) {
      Logger.error('Error handling notification tap: $e');
    }
  }

  /// Register device token with Supabase
  Future<void> _registerDeviceToken() async {
    if (_deviceToken == null || !SupabaseService.isAuthenticated) {
      return;
    }

    try {
      Logger.info('Registering device token with Supabase');
      
      // Store device token in user profile or separate table
      await SupabaseService.client
          .from('user_devices')
          .upsert({
            'user_id': SupabaseService.currentUserId,
            'device_token': _deviceToken,
            'platform': _getPlatform(),
            'updated_at': DateTime.now().toIso8601String(),
          });
      
      Logger.info('Device token registered successfully');
    } catch (e) {
      Logger.error('Failed to register device token: $e');
    }
  }

  /// Set up notification listeners for real-time updates
  Future<void> _setupNotificationListeners() async {
    if (!SupabaseService.isAuthenticated) {
      return;
    }

    try {
      Logger.info('Setting up notification listeners');
      
      // Listen for notification events from Supabase
      final channel = SupabaseService.client
          .channel('notification-events')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notification_events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: SupabaseService.currentUserId,
            ),
            callback: (payload) {
              _handleNotificationEvent(payload);
            },
          );
      
      await channel.subscribe();
      _subscriptions['notification-events'] = channel as StreamSubscription;
      
      Logger.info('Notification listeners set up successfully');
    } catch (e) {
      Logger.error('Failed to set up notification listeners: $e');
    }
  }

  /// Handle notification events from Supabase
  void _handleNotificationEvent(PostgresChangePayload payload) {
    try {
      final eventData = payload.newRecord;
      final eventType = eventData['event_type'] as String?;
      
      switch (eventType) {
        case 'reminder_notification':
          _handleReminderNotification(eventData);
          break;
        case 'task_notification':
          _handleTaskNotification(eventData);
          break;
        default:
          Logger.info('Unknown notification event type: $eventType');
      }
    } catch (e) {
      Logger.error('Error handling notification event: $e');
    }
  }

  /// Handle reminder notification events
  void _handleReminderNotification(Map<String, dynamic> eventData) {
    final title = eventData['title'] as String? ?? 'Reminder';
    final body = eventData['body'] as String? ?? '';
    final data = eventData['data'] as Map<String, dynamic>? ?? {};
    
    handleForegroundNotification({
      'title': title,
      'body': body,
      'data': data,
    });
  }

  /// Handle task notification events
  void _handleTaskNotification(Map<String, dynamic> eventData) {
    final title = eventData['title'] as String? ?? 'Task Update';
    final body = eventData['body'] as String? ?? '';
    final data = eventData['data'] as Map<String, dynamic>? ?? {};
    
    handleForegroundNotification({
      'title': title,
      'body': body,
      'data': data,
    });
  }

  /// Show in-app notification
  void _showInAppNotification(String title, String body, Map<String, dynamic> data) {
    // TODO: Implement in-app notification UI
    Logger.info('In-app notification: $title - $body');
  }



  /// Generate a device token (placeholder implementation)
  String _generateDeviceToken() {
    // In a real implementation, this would come from FCM/APNs
    return 'device_token_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get current platform
  String _getPlatform() {
    // In a real implementation, this would detect the actual platform
    return 'flutter_simulation';
  }

  /// Get notification permission status message
  String getPermissionStatusMessage() {
    if (!_isInitialized) {
      return 'Notification service not initialized. Please restart the app.';
    }
    
    if (!_permissionsGranted) {
      return 'Notification permissions are required for reminders. Please enable notifications in your device settings.';
    }
    
    return 'Notifications are enabled and working properly.';
  }

  /// Dispose the service
  void dispose() {
    Logger.info('Disposing SupabaseNotificationService');
    
    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    _isInitialized = false;
    _permissionsGranted = false;
    _deviceToken = null;
  }
}