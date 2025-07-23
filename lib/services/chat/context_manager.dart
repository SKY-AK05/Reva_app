import '../../models/chat_message.dart';
import '../../models/task.dart';
import '../../models/expense.dart';
import '../../models/reminder.dart';

/// Manages conversation context for AI interactions
class ContextManager {
  static const int _maxContextMessages = 10;
  static const int _maxContextItems = 5;
  static const Duration _contextExpiryDuration = Duration(hours: 24);

  /// Build comprehensive context for AI conversation
  Map<String, dynamic> buildContext({
    required List<ChatMessage> recentMessages,
    List<Task>? recentTasks,
    List<Expense>? recentExpenses,
    List<Reminder>? recentReminders,
    Map<String, dynamic>? currentContextItem,
  }) {
    final context = <String, dynamic>{};

    // Add conversation history
    context['conversation'] = _buildConversationContext(recentMessages);

    // Add recent data context
    if (recentTasks != null && recentTasks.isNotEmpty) {
      context['recent_tasks'] = _buildTasksContext(recentTasks);
    }

    if (recentExpenses != null && recentExpenses.isNotEmpty) {
      context['recent_expenses'] = _buildExpensesContext(recentExpenses);
    }

    if (recentReminders != null && recentReminders.isNotEmpty) {
      context['recent_reminders'] = _buildRemindersContext(recentReminders);
    }

    // Add current context item if provided
    if (currentContextItem != null) {
      context['current_context'] = currentContextItem;
    }

    // Add metadata
    context['context_metadata'] = {
      'generated_at': DateTime.now().toIso8601String(),
      'message_count': recentMessages.length,
      'has_recent_actions': _hasRecentActions(recentMessages),
      'last_activity': recentMessages.isNotEmpty 
          ? recentMessages.first.timestamp.toIso8601String()
          : null,
    };

    return context;
  }

  /// Build conversation context from recent messages
  Map<String, dynamic> _buildConversationContext(List<ChatMessage> messages) {
    final relevantMessages = messages
        .where((msg) => _isMessageRelevant(msg))
        .take(_maxContextMessages)
        .toList();

    final conversationSummary = _generateConversationSummary(relevantMessages);
    final actionHistory = _extractActionHistory(relevantMessages);

    return {
      'recent_messages': relevantMessages.map((msg) => {
        'type': msg.type.name,
        'content': _truncateContent(msg.content, 200),
        'timestamp': msg.timestamp.toIso8601String(),
        'has_action': msg.hasActionMetadata,
        'action_type': msg.actionType,
      }).toList(),
      'conversation_summary': conversationSummary,
      'action_history': actionHistory,
      'total_messages': messages.length,
    };
  }

  /// Build tasks context
  Map<String, dynamic> _buildTasksContext(List<Task> tasks) {
    final recentTasks = tasks.take(_maxContextItems).toList();
    
    return {
      'recent_tasks': recentTasks.map((task) => {
        'id': task.id,
        'description': _truncateContent(task.description, 100),
        'completed': task.completed,
        'priority': task.priority.name,
        'due_date': task.dueDate?.toIso8601String(),
        'created_at': task.createdAt.toIso8601String(),
      }).toList(),
      'task_stats': {
        'total_count': tasks.length,
        'completed_count': tasks.where((t) => t.completed).length,
        'pending_count': tasks.where((t) => !t.completed).length,
        'overdue_count': tasks.where((t) => 
          !t.completed && 
          t.dueDate != null && 
          t.dueDate!.isBefore(DateTime.now())
        ).length,
      },
    };
  }

  /// Build expenses context
  Map<String, dynamic> _buildExpensesContext(List<Expense> expenses) {
    final recentExpenses = expenses.take(_maxContextItems).toList();
    final totalAmount = expenses.fold<double>(0, (sum, expense) => sum + expense.amount);
    final categories = expenses.map((e) => e.category).toSet().toList();

    return {
      'recent_expenses': recentExpenses.map((expense) => {
        'id': expense.id,
        'item': _truncateContent(expense.item, 50),
        'amount': expense.amount,
        'category': expense.category,
        'date': expense.date.toIso8601String(),
      }).toList(),
      'expense_stats': {
        'total_count': expenses.length,
        'total_amount': totalAmount,
        'categories': categories,
        'average_amount': expenses.isNotEmpty ? totalAmount / expenses.length : 0,
      },
    };
  }

  /// Build reminders context
  Map<String, dynamic> _buildRemindersContext(List<Reminder> reminders) {
    final recentReminders = reminders.take(_maxContextItems).toList();
    final now = DateTime.now();
    
    return {
      'recent_reminders': recentReminders.map((reminder) => {
        'id': reminder.id,
        'title': _truncateContent(reminder.title, 50),
        'scheduled_time': reminder.scheduledTime.toIso8601String(),
        'completed': reminder.completed,
        'is_overdue': !reminder.completed && reminder.scheduledTime.isBefore(now),
        'is_upcoming': !reminder.completed && reminder.scheduledTime.isAfter(now),
      }).toList(),
      'reminder_stats': {
        'total_count': reminders.length,
        'completed_count': reminders.where((r) => r.completed).length,
        'pending_count': reminders.where((r) => !r.completed).length,
        'overdue_count': reminders.where((r) => 
          !r.completed && r.scheduledTime.isBefore(now)
        ).length,
        'upcoming_count': reminders.where((r) => 
          !r.completed && r.scheduledTime.isAfter(now)
        ).length,
      },
    };
  }

  /// Check if a message is relevant for context
  bool _isMessageRelevant(ChatMessage message) {
    // Filter out very old messages
    final age = DateTime.now().difference(message.timestamp);
    if (age > _contextExpiryDuration) return false;

    // Always include messages with actions
    if (message.hasActionMetadata) return true;

    // Include user messages and assistant responses
    if (message.type == MessageType.user || message.type == MessageType.assistant) {
      return true;
    }

    // Filter out system messages unless they're recent
    if (message.type == MessageType.system) {
      return age < const Duration(minutes: 30);
    }

    return false;
  }

  /// Generate a summary of the conversation
  String _generateConversationSummary(List<ChatMessage> messages) {
    if (messages.isEmpty) return 'No recent conversation';

    final userMessages = messages.where((m) => m.type == MessageType.user).length;
    final assistantMessages = messages.where((m) => m.type == MessageType.assistant).length;
    final actionsPerformed = messages.where((m) => m.hasActionMetadata).length;

    final topics = _extractTopics(messages);
    final topicsText = topics.isNotEmpty ? ' Topics: ${topics.join(', ')}.' : '';

    return 'Recent conversation: $userMessages user messages, $assistantMessages responses, '
           '$actionsPerformed actions performed.$topicsText';
  }

  /// Extract action history from messages
  List<Map<String, dynamic>> _extractActionHistory(List<ChatMessage> messages) {
    return messages
        .where((msg) => msg.hasActionMetadata)
        .map((msg) => {
          'timestamp': msg.timestamp.toIso8601String(),
          'action_type': msg.actionType,
          'action_data': msg.actionData,
          'message_content': _truncateContent(msg.content, 100),
        })
        .toList();
  }

  /// Extract topics from conversation
  List<String> _extractTopics(List<ChatMessage> messages) {
    final topics = <String>[];
    
    for (final message in messages) {
      if (message.hasActionMetadata) {
        final actionType = message.actionType;
        if (actionType != null) {
          switch (actionType) {
            case 'create_task':
            case 'update_task':
            case 'complete_task':
              if (!topics.contains('tasks')) topics.add('tasks');
              break;
            case 'create_expense':
            case 'update_expense':
              if (!topics.contains('expenses')) topics.add('expenses');
              break;
            case 'create_reminder':
            case 'update_reminder':
              if (!topics.contains('reminders')) topics.add('reminders');
              break;
          }
        }
      }
    }
    
    return topics;
  }

  /// Check if there are recent actions in the conversation
  bool _hasRecentActions(List<ChatMessage> messages) {
    final recentCutoff = DateTime.now().subtract(const Duration(minutes: 30));
    return messages.any((msg) => 
      msg.hasActionMetadata && msg.timestamp.isAfter(recentCutoff)
    );
  }

  /// Truncate content to specified length
  String _truncateContent(String content, int maxLength) {
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength - 3)}...';
  }

  /// Create context item for specific data
  Map<String, dynamic> createContextItem({
    required String type,
    required String id,
    required Map<String, dynamic> data,
  }) {
    return {
      'type': type,
      'id': id,
      'data': data,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Create task context item
  Map<String, dynamic> createTaskContext(Task task) {
    return createContextItem(
      type: 'task',
      id: task.id,
      data: {
        'description': task.description,
        'completed': task.completed,
        'priority': task.priority.name,
        'due_date': task.dueDate?.toIso8601String(),
        'created_at': task.createdAt.toIso8601String(),
        'updated_at': task.updatedAt.toIso8601String(),
      },
    );
  }

  /// Create expense context item
  Map<String, dynamic> createExpenseContext(Expense expense) {
    return createContextItem(
      type: 'expense',
      id: expense.id,
      data: {
        'item': expense.item,
        'amount': expense.amount,
        'category': expense.category,
        'date': expense.date.toIso8601String(),
        'created_at': expense.createdAt.toIso8601String(),
      },
    );
  }

  /// Create reminder context item
  Map<String, dynamic> createReminderContext(Reminder reminder) {
    return createContextItem(
      type: 'reminder',
      id: reminder.id,
      data: {
        'title': reminder.title,
        'description': reminder.description,
        'scheduled_time': reminder.scheduledTime.toIso8601String(),
        'completed': reminder.completed,
        'created_at': reminder.createdAt.toIso8601String(),
      },
    );
  }

  /// Validate context data
  bool isValidContext(Map<String, dynamic> context) {
    // Check required fields
    if (!context.containsKey('context_metadata')) return false;
    
    final metadata = context['context_metadata'] as Map<String, dynamic>?;
    if (metadata == null || !metadata.containsKey('generated_at')) return false;

    // Check if context is not too old
    try {
      final generatedAt = DateTime.parse(metadata['generated_at'] as String);
      final age = DateTime.now().difference(generatedAt);
      return age < _contextExpiryDuration;
    } catch (e) {
      return false;
    }
  }

  /// Clean up old context data
  Map<String, dynamic> cleanupContext(Map<String, dynamic> context) {
    final cleanedContext = Map<String, dynamic>.from(context);
    
    // Remove expired conversation messages
    if (cleanedContext.containsKey('conversation')) {
      final conversation = cleanedContext['conversation'] as Map<String, dynamic>;
      if (conversation.containsKey('recent_messages')) {
        final messages = conversation['recent_messages'] as List<dynamic>;
        final validMessages = messages.where((msg) {
          try {
            final timestamp = DateTime.parse(msg['timestamp'] as String);
            final age = DateTime.now().difference(timestamp);
            return age < _contextExpiryDuration;
          } catch (e) {
            return false;
          }
        }).toList();
        
        conversation['recent_messages'] = validMessages;
      }
    }
    
    return cleanedContext;
  }
}