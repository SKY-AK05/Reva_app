import 'dart:math';
import '../../models/chat_message.dart';
import '../../utils/logger.dart';
import '../data/tasks_repository.dart';
import '../data/expenses_repository.dart';
import '../data/reminders_repository.dart';
import '../../models/task.dart';
import '../../models/expense.dart';
import '../../models/reminder.dart';

/// Service for handling AI interaction fallbacks when the AI fails to process commands
class AIFallbackService {
  final TasksRepository _tasksRepository;
  final ExpensesRepository _expensesRepository;
  final RemindersRepository _remindersRepository;

  AIFallbackService({
    required TasksRepository tasksRepository,
    required ExpensesRepository expensesRepository,
    required RemindersRepository remindersRepository,
  }) : _tasksRepository = tasksRepository,
       _expensesRepository = expensesRepository,
       _remindersRepository = remindersRepository;

  /// Analyze user message and suggest possible actions when AI fails
  Future<List<FallbackSuggestion>> analyzeFallbackSuggestions(String userMessage) async {
    Logger.debug('Analyzing fallback suggestions for message: $userMessage');
    
    final suggestions = <FallbackSuggestion>[];
    final lowerMessage = userMessage.toLowerCase();

    // Task-related suggestions
    if (_containsTaskKeywords(lowerMessage)) {
      suggestions.addAll(await _generateTaskSuggestions(userMessage, lowerMessage));
    }

    // Expense-related suggestions
    if (_containsExpenseKeywords(lowerMessage)) {
      suggestions.addAll(await _generateExpenseSuggestions(userMessage, lowerMessage));
    }

    // Reminder-related suggestions
    if (_containsReminderKeywords(lowerMessage)) {
      suggestions.addAll(await _generateReminderSuggestions(userMessage, lowerMessage));
    }

    // General suggestions if no specific category detected
    if (suggestions.isEmpty) {
      suggestions.addAll(_generateGeneralSuggestions(userMessage));
    }

    // Sort suggestions by confidence score
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));

    Logger.info('Generated ${suggestions.length} fallback suggestions');
    return suggestions.take(5).toList(); // Return top 5 suggestions
  }

  /// Check if message contains task-related keywords
  bool _containsTaskKeywords(String message) {
    const taskKeywords = [
      'task', 'todo', 'do', 'complete', 'finish', 'work', 'project',
      'assignment', 'deadline', 'due', 'priority', 'urgent', 'important'
    ];
    return taskKeywords.any((keyword) => message.contains(keyword));
  }

  /// Check if message contains expense-related keywords
  bool _containsExpenseKeywords(String message) {
    const expenseKeywords = [
      'expense', 'cost', 'spend', 'spent', 'buy', 'bought', 'purchase',
      'paid', 'pay', 'money', 'price', 'bill', 'receipt', 'shopping',
      '\$', 'dollar', 'budget'
    ];
    return expenseKeywords.any((keyword) => message.contains(keyword));
  }

  /// Check if message contains reminder-related keywords
  bool _containsReminderKeywords(String message) {
    const reminderKeywords = [
      'remind', 'reminder', 'remember', 'alert', 'notify', 'notification',
      'schedule', 'appointment', 'meeting', 'call', 'later', 'tomorrow',
      'today', 'time', 'clock', 'alarm'
    ];
    return reminderKeywords.any((keyword) => message.contains(keyword));
  }

  /// Generate task-related suggestions
  Future<List<FallbackSuggestion>> _generateTaskSuggestions(String originalMessage, String lowerMessage) async {
    final suggestions = <FallbackSuggestion>[];

    // Suggest creating a new task
    if (lowerMessage.contains('add') || lowerMessage.contains('create') || lowerMessage.contains('new')) {
      suggestions.add(FallbackSuggestion(
        type: FallbackType.createTask,
        title: 'Create New Task',
        description: 'Add a new task to your list',
        confidence: 0.8,
        actionData: {'description': _extractTaskDescription(originalMessage)},
      ));
    }

    // Suggest viewing tasks
    if (lowerMessage.contains('show') || lowerMessage.contains('list') || lowerMessage.contains('view')) {
      suggestions.add(FallbackSuggestion(
        type: FallbackType.viewTasks,
        title: 'View Tasks',
        description: 'See your current task list',
        confidence: 0.7,
      ));
    }

    // Suggest completing a task if there are existing tasks
    try {
      final tasks = await _tasksRepository.getAll();
      final incompleteTasks = tasks.where((task) => !task.completed).toList();
      
      if (incompleteTasks.isNotEmpty && (lowerMessage.contains('complete') || lowerMessage.contains('done'))) {
        suggestions.add(FallbackSuggestion(
          type: FallbackType.completeTask,
          title: 'Complete Task',
          description: 'Mark a task as completed',
          confidence: 0.6,
          actionData: {'availableTasks': incompleteTasks.length},
        ));
      }
    } catch (e) {
      Logger.warning('Failed to fetch tasks for suggestions: $e');
    }

    return suggestions;
  }

  /// Generate expense-related suggestions
  Future<List<FallbackSuggestion>> _generateExpenseSuggestions(String originalMessage, String lowerMessage) async {
    final suggestions = <FallbackSuggestion>[];

    // Extract potential amount from message
    final amount = _extractAmount(originalMessage);

    // Suggest logging an expense
    if (lowerMessage.contains('spent') || lowerMessage.contains('bought') || lowerMessage.contains('paid') || amount != null) {
      suggestions.add(FallbackSuggestion(
        type: FallbackType.logExpense,
        title: 'Log Expense',
        description: 'Record a new expense',
        confidence: amount != null ? 0.9 : 0.7,
        actionData: {
          if (amount != null) 'amount': amount,
          'item': _extractExpenseItem(originalMessage),
        },
      ));
    }

    // Suggest viewing expenses
    if (lowerMessage.contains('show') || lowerMessage.contains('list') || lowerMessage.contains('view') || lowerMessage.contains('budget')) {
      suggestions.add(FallbackSuggestion(
        type: FallbackType.viewExpenses,
        title: 'View Expenses',
        description: 'See your expense history',
        confidence: 0.6,
      ));
    }

    return suggestions;
  }

  /// Generate reminder-related suggestions
  Future<List<FallbackSuggestion>> _generateReminderSuggestions(String originalMessage, String lowerMessage) async {
    final suggestions = <FallbackSuggestion>[];

    // Suggest creating a reminder
    if (lowerMessage.contains('remind') || lowerMessage.contains('remember') || lowerMessage.contains('alert')) {
      suggestions.add(FallbackSuggestion(
        type: FallbackType.createReminder,
        title: 'Create Reminder',
        description: 'Set up a new reminder',
        confidence: 0.8,
        actionData: {'title': _extractReminderTitle(originalMessage)},
      ));
    }

    // Suggest viewing reminders
    if (lowerMessage.contains('show') || lowerMessage.contains('list') || lowerMessage.contains('view')) {
      suggestions.add(FallbackSuggestion(
        type: FallbackType.viewReminders,
        title: 'View Reminders',
        description: 'See your upcoming reminders',
        confidence: 0.6,
      ));
    }

    return suggestions;
  }

  /// Generate general suggestions when no specific category is detected
  List<FallbackSuggestion> _generateGeneralSuggestions(String originalMessage) {
    return [
      FallbackSuggestion(
        type: FallbackType.createTask,
        title: 'Create Task',
        description: 'Add this as a new task',
        confidence: 0.4,
        actionData: {'description': originalMessage},
      ),
      FallbackSuggestion(
        type: FallbackType.viewTasks,
        title: 'View Tasks',
        description: 'See your current tasks',
        confidence: 0.3,
      ),
      FallbackSuggestion(
        type: FallbackType.logExpense,
        title: 'Log Expense',
        description: 'Record this as an expense',
        confidence: 0.3,
      ),
      FallbackSuggestion(
        type: FallbackType.createReminder,
        title: 'Create Reminder',
        description: 'Set this as a reminder',
        confidence: 0.3,
      ),
    ];
  }

  /// Extract task description from message
  String _extractTaskDescription(String message) {
    // Remove common prefixes
    final prefixes = ['add task', 'create task', 'new task', 'add', 'create', 'new'];
    String cleaned = message.toLowerCase();
    
    for (final prefix in prefixes) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length).trim();
        break;
      }
    }
    
    return cleaned.isEmpty ? message : cleaned;
  }

  /// Extract expense item from message
  String _extractExpenseItem(String message) {
    // Remove amount and common expense words
    String cleaned = message.replaceAll(RegExp(r'\$[\d,]+\.?\d*'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\b(spent|bought|paid|for|on)\b', caseSensitive: false), '').trim();
    
    return cleaned.isEmpty ? 'Expense' : cleaned;
  }

  /// Extract reminder title from message
  String _extractReminderTitle(String message) {
    // Remove reminder keywords
    final keywords = ['remind me to', 'remind me', 'remember to', 'remember', 'alert me to', 'alert me'];
    String cleaned = message.toLowerCase();
    
    for (final keyword in keywords) {
      if (cleaned.contains(keyword)) {
        cleaned = cleaned.replaceAll(keyword, '').trim();
        break;
      }
    }
    
    return cleaned.isEmpty ? message : cleaned;
  }

  /// Extract monetary amount from message
  double? _extractAmount(String message) {
    // Look for patterns like $123.45, $123, 123.45, etc.
    final amountRegex = RegExp(r'\$?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)', caseSensitive: false);
    final match = amountRegex.firstMatch(message);
    
    if (match != null) {
      final amountStr = match.group(1)?.replaceAll(',', '');
      return double.tryParse(amountStr ?? '');
    }
    
    return null;
  }

  /// Execute a fallback suggestion
  Future<FallbackExecutionResult> executeFallbackSuggestion(FallbackSuggestion suggestion) async {
    Logger.info('Executing fallback suggestion: ${suggestion.title}');
    
    try {
      switch (suggestion.type) {
        case FallbackType.createTask:
          return await _executeCreateTask(suggestion);
        case FallbackType.viewTasks:
          return await _executeViewTasks(suggestion);
        case FallbackType.completeTask:
          return await _executeCompleteTask(suggestion);
        case FallbackType.logExpense:
          return await _executeLogExpense(suggestion);
        case FallbackType.viewExpenses:
          return await _executeViewExpenses(suggestion);
        case FallbackType.createReminder:
          return await _executeCreateReminder(suggestion);
        case FallbackType.viewReminders:
          return await _executeViewReminders(suggestion);
        case FallbackType.manualInput:
          return FallbackExecutionResult.success(
            message: 'Please use the manual input form',
            requiresNavigation: true,
            navigationRoute: suggestion.actionData?['route'] as String?,
          );
      }
    } catch (e) {
      Logger.error('Failed to execute fallback suggestion: $e');
      return FallbackExecutionResult.failure('Failed to execute action: ${e.toString()}');
    }
  }

  /// Execute create task fallback
  Future<FallbackExecutionResult> _executeCreateTask(FallbackSuggestion suggestion) async {
    final description = suggestion.actionData?['description'] as String?;
    
    if (description == null || description.trim().isEmpty) {
      return FallbackExecutionResult.success(
        message: 'Please provide a task description',
        requiresNavigation: true,
        navigationRoute: '/tasks/add',
      );
    }

    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'current_user', // This should come from auth
      description: description,
      priority: TaskPriority.medium,
      completed: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _tasksRepository.create(task);
    
    return FallbackExecutionResult.success(
      message: 'Task created: $description',
      data: {'taskId': task.id},
    );
  }

  /// Execute view tasks fallback
  Future<FallbackExecutionResult> _executeViewTasks(FallbackSuggestion suggestion) async {
    return FallbackExecutionResult.success(
      message: 'Opening your task list',
      requiresNavigation: true,
      navigationRoute: '/tasks',
    );
  }

  /// Execute complete task fallback
  Future<FallbackExecutionResult> _executeCompleteTask(FallbackSuggestion suggestion) async {
    return FallbackExecutionResult.success(
      message: 'Please select a task to complete',
      requiresNavigation: true,
      navigationRoute: '/tasks',
    );
  }

  /// Execute log expense fallback
  Future<FallbackExecutionResult> _executeLogExpense(FallbackSuggestion suggestion) async {
    final amount = suggestion.actionData?['amount'] as double?;
    final item = suggestion.actionData?['item'] as String?;
    
    if (amount == null || item == null || item.trim().isEmpty) {
      return FallbackExecutionResult.success(
        message: 'Please provide expense details',
        requiresNavigation: true,
        navigationRoute: '/expenses/add',
        data: {
          if (amount != null) 'amount': amount,
          if (item != null) 'item': item,
        },
      );
    }

    final expense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'current_user', // This should come from auth
      item: item,
      amount: amount,
      category: 'General',
      date: DateTime.now(),
      createdAt: DateTime.now(),
    );

    await _expensesRepository.create(expense);
    
    return FallbackExecutionResult.success(
      message: 'Expense logged: $item - \$${amount.toStringAsFixed(2)}',
      data: {'expenseId': expense.id},
    );
  }

  /// Execute view expenses fallback
  Future<FallbackExecutionResult> _executeViewExpenses(FallbackSuggestion suggestion) async {
    return FallbackExecutionResult.success(
      message: 'Opening your expense list',
      requiresNavigation: true,
      navigationRoute: '/expenses',
    );
  }

  /// Execute create reminder fallback
  Future<FallbackExecutionResult> _executeCreateReminder(FallbackSuggestion suggestion) async {
    final title = suggestion.actionData?['title'] as String?;
    
    if (title == null || title.trim().isEmpty) {
      return FallbackExecutionResult.success(
        message: 'Please provide reminder details',
        requiresNavigation: true,
        navigationRoute: '/reminders/add',
      );
    }

    // For now, just navigate to the add reminder screen with pre-filled data
    return FallbackExecutionResult.success(
      message: 'Setting up your reminder',
      requiresNavigation: true,
      navigationRoute: '/reminders/add',
      data: {'title': title},
    );
  }

  /// Execute view reminders fallback
  Future<FallbackExecutionResult> _executeViewReminders(FallbackSuggestion suggestion) async {
    return FallbackExecutionResult.success(
      message: 'Opening your reminders',
      requiresNavigation: true,
      navigationRoute: '/reminders',
    );
  }

  /// Generate contextual help message when AI fails
  String generateHelpMessage(String originalMessage) {
    final lowerMessage = originalMessage.toLowerCase();
    
    if (_containsTaskKeywords(lowerMessage)) {
      return "I couldn't process your task request. Try phrases like:\n"
             "• \"Add task: [description]\"\n"
             "• \"Create a new task\"\n"
             "• \"Show my tasks\"";
    }
    
    if (_containsExpenseKeywords(lowerMessage)) {
      return "I couldn't process your expense request. Try phrases like:\n"
             "• \"I spent \$20 on groceries\"\n"
             "• \"Log expense: \$15 for lunch\"\n"
             "• \"Show my expenses\"";
    }
    
    if (_containsReminderKeywords(lowerMessage)) {
      return "I couldn't process your reminder request. Try phrases like:\n"
             "• \"Remind me to call mom at 3pm\"\n"
             "• \"Set reminder for meeting tomorrow\"\n"
             "• \"Show my reminders\"";
    }
    
    return "I couldn't understand your request. You can:\n"
           "• Create tasks, log expenses, or set reminders\n"
           "• Use the navigation tabs to access different features\n"
           "• Try being more specific with your request";
  }
}

/// Fallback suggestion data class
class FallbackSuggestion {
  final FallbackType type;
  final String title;
  final String description;
  final double confidence;
  final Map<String, dynamic>? actionData;

  const FallbackSuggestion({
    required this.type,
    required this.title,
    required this.description,
    required this.confidence,
    this.actionData,
  });
}

/// Types of fallback suggestions
enum FallbackType {
  createTask,
  viewTasks,
  completeTask,
  logExpense,
  viewExpenses,
  createReminder,
  viewReminders,
  manualInput,
}

/// Result of executing a fallback suggestion
class FallbackExecutionResult {
  final bool success;
  final String message;
  final bool requiresNavigation;
  final String? navigationRoute;
  final Map<String, dynamic>? data;

  const FallbackExecutionResult({
    required this.success,
    required this.message,
    this.requiresNavigation = false,
    this.navigationRoute,
    this.data,
  });

  factory FallbackExecutionResult.success({
    required String message,
    bool requiresNavigation = false,
    String? navigationRoute,
    Map<String, dynamic>? data,
  }) {
    return FallbackExecutionResult(
      success: true,
      message: message,
      requiresNavigation: requiresNavigation,
      navigationRoute: navigationRoute,
      data: data,
    );
  }

  factory FallbackExecutionResult.failure(String message) {
    return FallbackExecutionResult(
      success: false,
      message: message,
    );
  }
}