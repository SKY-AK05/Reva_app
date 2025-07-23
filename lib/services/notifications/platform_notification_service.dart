import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../utils/logger.dart';

class PlatformNotificationService {
  static final PlatformNotificationService _instance = PlatformNotificationService._internal();
  factory PlatformNotificationService() => _instance;
  PlatformNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize platform-specific notification settings
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android initialization
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@drawable/ic_notification');

      // iOS initialization
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: false,
        onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
      );

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      // Create notification channels for Android
      if (Platform.isAndroid) {
        await _createAndroidNotificationChannels();
      }

      _isInitialized = true;
      Logger.info('Platform notification service initialized successfully');
    } catch (e) {
      Logger.error('Failed to initialize notification service: $e');
      rethrow;
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        return await _requestAndroidPermissions();
      } else if (Platform.isIOS) {
        return await _requestIOSPermissions();
      }
      return false;
    } catch (e) {
      Logger.error('Failed to request notification permissions: $e');
      return false;
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        return status.isGranted;
      } else if (Platform.isIOS) {
        final bool? result = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return result ?? false;
      }
      return false;
    } catch (e) {
      Logger.error('Failed to check notification permissions: $e');
      return false;
    }
  }

  /// Schedule a local notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String channelId = 'reva_reminders',
  }) async {
    try {
      // Convert DateTime to TZDateTime
      final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(scheduledDate, tz.local);
      
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTZDate,
        _getNotificationDetails(channelId),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      Logger.info('Scheduled notification: $title at $scheduledDate');
    } catch (e) {
      Logger.error('Failed to schedule notification: $e');
      rethrow;
    }
  }

  /// Show immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'reva_default',
  }) async {
    try {
      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        _getNotificationDetails(channelId),
        payload: payload,
      );

      Logger.info('Showed notification: $title');
    } catch (e) {
      Logger.error('Failed to show notification: $e');
      rethrow;
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      Logger.info('Cancelled notification with id: $id');
    } catch (e) {
      Logger.error('Failed to cancel notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      Logger.info('Cancelled all notifications');
    } catch (e) {
      Logger.error('Failed to cancel all notifications: $e');
    }
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      Logger.error('Failed to get pending notifications: $e');
      return [];
    }
  }

  // Private methods

  Future<bool> _requestAndroidPermissions() async {
    // For Android 13+ (API level 33+), request POST_NOTIFICATIONS permission
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      
      // Also request exact alarm permission for precise scheduling
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
      
      return status.isGranted;
    }
    return false;
  }

  Future<bool> _requestIOSPermissions() async {
    final bool? result = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: false,
        );
    return result ?? false;
  }

  Future<void> _createAndroidNotificationChannels() async {
    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // Default channel
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'reva_default',
          'Default Notifications',
          description: 'General notifications from Reva',
          importance: Importance.defaultImportance,
          playSound: true,
          enableVibration: true,
        ),
      );

      // Reminders channel
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'reva_reminders',
          'Reminders',
          description: 'Reminder notifications from Reva',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        ),
      );

      // Tasks channel
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'reva_tasks',
          'Tasks',
          description: 'Task-related notifications from Reva',
          importance: Importance.defaultImportance,
          playSound: true,
          enableVibration: false,
        ),
      );

      // Chat channel
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'reva_chat',
          'Chat Updates',
          description: 'Chat and AI response notifications',
          importance: Importance.defaultImportance,
          playSound: false,
          enableVibration: true,
        ),
      );

      Logger.info('Created Android notification channels');
    }
  }

  NotificationDetails _getNotificationDetails(String channelId) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: _getChannelDescription(channelId),
        importance: _getChannelImportance(channelId),
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        color: const Color(0xFF6366F1), // Primary app color
        playSound: _shouldPlaySound(channelId),
        enableVibration: _shouldVibrate(channelId),
        enableLights: true,
        ledColor: const Color(0xFF6366F1),
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: 'Reva Notification',
        styleInformation: const BigTextStyleInformation(''),
        actions: _getNotificationActions(channelId),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: _shouldPlaySound(channelId),
        sound: _shouldPlaySound(channelId) ? 'default' : null,
        badgeNumber: null,
        threadIdentifier: channelId,
        categoryIdentifier: channelId,
      ),
    );
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'reva_reminders':
        return 'Reminders';
      case 'reva_tasks':
        return 'Tasks';
      case 'reva_chat':
        return 'Chat Updates';
      default:
        return 'Default Notifications';
    }
  }

  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'reva_reminders':
        return 'Reminder notifications from Reva';
      case 'reva_tasks':
        return 'Task-related notifications from Reva';
      case 'reva_chat':
        return 'Chat and AI response notifications';
      default:
        return 'General notifications from Reva';
    }
  }

  Importance _getChannelImportance(String channelId) {
    switch (channelId) {
      case 'reva_reminders':
        return Importance.high;
      case 'reva_tasks':
        return Importance.defaultImportance;
      case 'reva_chat':
        return Importance.low;
      default:
        return Importance.defaultImportance;
    }
  }

  bool _shouldPlaySound(String channelId) {
    switch (channelId) {
      case 'reva_reminders':
        return true;
      case 'reva_tasks':
        return true;
      case 'reva_chat':
        return false;
      default:
        return true;
    }
  }

  bool _shouldVibrate(String channelId) {
    switch (channelId) {
      case 'reva_reminders':
        return true;
      case 'reva_tasks':
        return false;
      case 'reva_chat':
        return true;
      default:
        return true;
    }
  }

  List<AndroidNotificationAction>? _getNotificationActions(String channelId) {
    switch (channelId) {
      case 'reva_reminders':
        return [
          const AndroidNotificationAction(
            'mark_done',
            'Mark Done',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_check'),
          ),
          const AndroidNotificationAction(
            'snooze',
            'Snooze',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_snooze'),
          ),
        ];
      case 'reva_tasks':
        return [
          const AndroidNotificationAction(
            'complete',
            'Complete',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_check'),
          ),
        ];
      default:
        return null;
    }
  }

  // Callback handlers
  void _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) async {
    Logger.info('Received local notification: $title');
    // Handle iOS foreground notifications
    if (payload != null) {
      await _handleNotificationPayload(payload);
    }
  }

  void _onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse,
  ) async {
    final String? payload = notificationResponse.payload;
    final String? actionId = notificationResponse.actionId;
    
    Logger.info('Notification response: action=$actionId, payload=$payload');
    
    if (actionId != null) {
      await _handleNotificationAction(actionId, payload);
    } else if (payload != null) {
      await _handleNotificationPayload(payload);
    }
  }

  Future<void> _handleNotificationAction(String actionId, String? payload) async {
    try {
      switch (actionId) {
        case 'mark_done':
        case 'complete':
          // Handle completion actions
          if (payload != null) {
            // Parse payload and mark item as complete
            Logger.info('Marking item complete: $payload');
          }
          break;
        case 'snooze':
          // Handle snooze action
          if (payload != null) {
            Logger.info('Snoozing item: $payload');
            // Reschedule notification for later
          }
          break;
      }
    } catch (e) {
      Logger.error('Failed to handle notification action: $e');
    }
  }

  Future<void> _handleNotificationPayload(String payload) async {
    try {
      // Parse payload and navigate to appropriate screen
      Logger.info('Handling notification payload: $payload');
      
      // This would typically involve parsing the payload and using
      // the app's navigation system to go to the relevant screen
    } catch (e) {
      Logger.error('Failed to handle notification payload: $e');
    }
  }
}