class AppConstants {
  // App Information
  static const String appName = 'Reva';
  static const String appVersion = '1.0.0';
  
  // API Endpoints
  static const String chatEndpoint = '/api/v1/chat';
  
  // Database Tables
  static const String tasksTable = 'tasks';
  static const String expensesTable = 'expenses';
  static const String remindersTable = 'reminders';
  static const String chatMessagesTable = 'chat_messages';
  
  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String themeKey = 'theme_mode';
  
  // Cache Keys
  static const String tasksCacheKey = 'tasks_cache';
  static const String expensesCacheKey = 'expenses_cache';
  static const String remindersCacheKey = 'reminders_cache';
  static const String chatCacheKey = 'chat_cache';
  static const String apiBaseUrl = 'https://revaappbe-production.up.railway.app';
  
  // Timeouts and Limits
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration cacheExpiry = Duration(hours: 24);
  static const int maxChatHistory = 100;
  static const int maxRetryAttempts = 3;
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 8.0;
  static const double defaultElevation = 2.0;
}