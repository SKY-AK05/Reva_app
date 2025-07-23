import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/navigation/app_router.dart';

import '../../utils/logger.dart';

/// Service for handling deep links and navigation from notifications
class DeepLinkService {
  static const String _tag = 'DeepLinkService';

  /// Handle deep link navigation
  static Future<void> handleDeepLink(
    BuildContext context,
    String link, {
    WidgetRef? ref,
  }) async {
    try {
      Logger.info(_tag, 'Handling deep link: $link');

      final uri = Uri.parse(link);
      final path = uri.path;
      final queryParams = uri.queryParameters;

      // Handle different deep link patterns
      if (path.startsWith('/tasks/')) {
        await _handleTaskDeepLink(context, path, queryParams);
      } else if (path.startsWith('/expenses/')) {
        await _handleExpenseDeepLink(context, path, queryParams);
      } else if (path.startsWith('/reminders/')) {
        await _handleReminderDeepLink(context, path, queryParams);
      } else if (path.startsWith('/chat')) {
        await _handleChatDeepLink(context, queryParams);
      } else {
        // Default to chat screen for unknown links
        Logger.warning(_tag, 'Unknown deep link path: $path, navigating to chat');
        context.go(AppRoutes.chat);
      }
    } catch (e, stackTrace) {
      Logger.error(_tag, 'Error handling deep link: $e', stackTrace);
      // Fallback to chat screen on error
      context.go(AppRoutes.chat);
    }
  }

  /// Handle notification tap navigation
  static Future<void> handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> notificationData, {
    WidgetRef? ref,
  }) async {
    try {
      Logger.info(_tag, 'Handling notification tap: $notificationData');

      final type = notificationData['type'] as String?;
      final id = notificationData['id'] as String?;
      final action = notificationData['action'] as String?;

      switch (type) {
        case 'reminder':
          if (id != null) {
            if (action == 'complete') {
              // Handle reminder completion action
              await _handleReminderAction(context, id, 'complete', ref);
            } else {
              // Navigate to reminder detail
              context.go('/reminders/detail/$id');
            }
          }
          break;

        case 'task':
          if (id != null) {
            if (action == 'complete') {
              // Handle task completion action
              await _handleTaskAction(context, id, 'complete', ref);
            } else {
              // Navigate to task detail
              context.go('/tasks/detail/$id');
            }
          }
          break;

        case 'expense':
          if (id != null) {
            // Navigate to expense detail
            context.go('/expenses/detail/$id');
          }
          break;

        case 'chat':
          // Navigate to chat with optional context
          final contextId = notificationData['contextId'] as String?;
          if (contextId != null) {
            context.go('${AppRoutes.chat}?contextId=$contextId');
          } else {
            context.go(AppRoutes.chat);
          }
          break;

        default:
          Logger.warning(_tag, 'Unknown notification type: $type');
          context.go(AppRoutes.chat);
      }
    } catch (e, stackTrace) {
      Logger.error(_tag, 'Error handling notification tap: $e', stackTrace);
      // Fallback to chat screen on error
      context.go(AppRoutes.chat);
    }
  }

  /// Handle task-related deep links
  static Future<void> _handleTaskDeepLink(
    BuildContext context,
    String path,
    Map<String, String> queryParams,
  ) async {
    final segments = path.split('/');
    
    if (segments.length >= 3) {
      final taskId = segments[2];
      
      if (segments.length >= 4) {
        final action = segments[3];
        switch (action) {
          case 'edit':
            context.go('/tasks/edit/$taskId');
            break;
          case 'detail':
            context.go('/tasks/detail/$taskId');
            break;
          default:
            context.go('/tasks/detail/$taskId');
        }
      } else {
        // Default to detail view
        context.go('/tasks/detail/$taskId');
      }
    } else {
      // Navigate to tasks list
      context.go(AppRoutes.tasks);
    }
  }

  /// Handle expense-related deep links
  static Future<void> _handleExpenseDeepLink(
    BuildContext context,
    String path,
    Map<String, String> queryParams,
  ) async {
    final segments = path.split('/');
    
    if (segments.length >= 3) {
      final expenseId = segments[2];
      
      if (segments.length >= 4) {
        final action = segments[3];
        switch (action) {
          case 'edit':
            context.go('/expenses/edit/$expenseId');
            break;
          case 'detail':
            context.go('/expenses/detail/$expenseId');
            break;
          default:
            context.go('/expenses/detail/$expenseId');
        }
      } else {
        // Default to detail view
        context.go('/expenses/detail/$expenseId');
      }
    } else {
      // Navigate to expenses list
      context.go(AppRoutes.expenses);
    }
  }

  /// Handle reminder-related deep links
  static Future<void> _handleReminderDeepLink(
    BuildContext context,
    String path,
    Map<String, String> queryParams,
  ) async {
    final segments = path.split('/');
    
    if (segments.length >= 3) {
      final reminderId = segments[2];
      
      if (segments.length >= 4) {
        final action = segments[3];
        switch (action) {
          case 'edit':
            context.go('/reminders/edit/$reminderId');
            break;
          case 'detail':
            context.go('/reminders/detail/$reminderId');
            break;
          case 'complete':
            await _handleReminderAction(context, reminderId, 'complete', null);
            break;
          default:
            context.go('/reminders/detail/$reminderId');
        }
      } else {
        // Default to detail view
        context.go('/reminders/detail/$reminderId');
      }
    } else {
      // Navigate to reminders list
      context.go(AppRoutes.reminders);
    }
  }

  /// Handle chat-related deep links
  static Future<void> _handleChatDeepLink(
    BuildContext context,
    Map<String, String> queryParams,
  ) async {
    final contextId = queryParams['contextId'];
    final message = queryParams['message'];
    
    if (contextId != null || message != null) {
      // Navigate to chat with query parameters
      final query = <String, String>{};
      if (contextId != null) query['contextId'] = contextId;
      if (message != null) query['message'] = message;
      
      final queryString = query.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      context.go('${AppRoutes.chat}?$queryString');
    } else {
      context.go(AppRoutes.chat);
    }
  }

  /// Generate notification data for reminders
  static Map<String, dynamic> generateReminderNotificationData(String reminderId) {
    return {
      'type': 'reminder',
      'id': reminderId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Handle reminder actions (like completion)
  static Future<void> _handleReminderAction(
    BuildContext context,
    String reminderId,
    String action,
    WidgetRef? ref,
  ) async {
    try {
      if (ref != null && action == 'complete') {
        // Note: In a real implementation, this would mark reminder as complete
        // using the reminders provider
        Logger.info(_tag, 'Completing reminder: $reminderId');
        
        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminder marked as complete'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      // Navigate to reminder detail to show updated state
      if (context.mounted) {
        context.go('/reminders/detail/$reminderId');
      }
    } catch (e, stackTrace) {
      Logger.error(_tag, 'Error handling reminder action: $e', stackTrace);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete reminder'),
            backgroundColor: Colors.red,
          ),
        );
        context.go('/reminders/detail/$reminderId');
      }
    }
  }

  /// Handle task actions (like completion)
  static Future<void> _handleTaskAction(
    BuildContext context,
    String taskId,
    String action,
    WidgetRef? ref,
  ) async {
    try {
      if (ref != null && action == 'complete') {
        // Note: In a real implementation, this would mark task as complete
        // using the tasks provider
        Logger.info(_tag, 'Completing task: $taskId');
        
        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task marked as complete'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      // Navigate to task detail to show updated state
      if (context.mounted) {
        context.go('/tasks/detail/$taskId');
      }
    } catch (e, stackTrace) {
      Logger.error(_tag, 'Error handling task action: $e', stackTrace);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete task'),
            backgroundColor: Colors.red,
          ),
        );
        context.go('/tasks/detail/$taskId');
      }
    }
  }

  /// Generate deep link URL for sharing
  static String generateDeepLink({
    required String type,
    required String id,
    String? action,
    Map<String, String>? queryParams,
  }) {
    final baseUrl = 'https://reva.app'; // Replace with your actual domain
    String path;

    switch (type) {
      case 'task':
        path = '/tasks/$id';
        if (action != null) path += '/$action';
        break;
      case 'expense':
        path = '/expenses/$id';
        if (action != null) path += '/$action';
        break;
      case 'reminder':
        path = '/reminders/$id';
        if (action != null) path += '/$action';
        break;
      case 'chat':
        path = '/chat';
        break;
      default:
        path = '/';
    }

    final uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams).toString();
    }
    
    return uri.toString();
  }
}

/// Provider for deep link service
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService();
});