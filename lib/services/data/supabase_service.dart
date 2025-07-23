import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../utils/logger.dart';

/// Service for managing Supabase client configuration and RLS
class SupabaseService {
  static SupabaseClient get client => SupabaseConfig.client;
  
  /// Initialize Supabase with proper configuration
  static Future<void> initialize() async {
    try {
      Logger.info('Initializing Supabase service');
      await SupabaseConfig.initialize();
      Logger.info('Supabase service initialized successfully');
    } catch (e) {
      Logger.error('Failed to initialize Supabase service: $e');
      rethrow;
    }
  }

  /// Check if user is authenticated
  static bool get isAuthenticated => client.auth.currentUser != null;

  /// Get current user ID
  static String? get currentUserId => client.auth.currentUser?.id;

  /// Get current session
  static Session? get currentSession => client.auth.currentSession;

  /// Set up Row Level Security policies (this would typically be done in SQL)
  /// This method documents the expected RLS policies
  static void documentRLSPolicies() {
    Logger.info('''
    Expected Row Level Security Policies:
    
    1. Tasks Table:
       - SELECT: Users can only see their own tasks (user_id = auth.uid())
       - INSERT: Users can only create tasks for themselves
       - UPDATE: Users can only update their own tasks
       - DELETE: Users can only delete their own tasks
    
    2. Expenses Table:
       - SELECT: Users can only see their own expenses (user_id = auth.uid())
       - INSERT: Users can only create expenses for themselves
       - UPDATE: Users can only update their own expenses
       - DELETE: Users can only delete their own expenses
    
    3. Reminders Table:
       - SELECT: Users can only see their own reminders (user_id = auth.uid())
       - INSERT: Users can only create reminders for themselves
       - UPDATE: Users can only update their own reminders
       - DELETE: Users can only delete their own reminders
    
    4. Chat Messages Table:
       - SELECT: Users can only see their own messages (user_id = auth.uid())
       - INSERT: Users can only create messages for themselves
       - UPDATE: Users can only update their own messages
       - DELETE: Users can only delete their own messages
    
    SQL Examples:
    
    -- Tasks RLS Policies
    ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
    
    CREATE POLICY "Users can view own tasks" ON tasks
      FOR SELECT USING (auth.uid() = user_id);
    
    CREATE POLICY "Users can insert own tasks" ON tasks
      FOR INSERT WITH CHECK (auth.uid() = user_id);
    
    CREATE POLICY "Users can update own tasks" ON tasks
      FOR UPDATE USING (auth.uid() = user_id);
    
    CREATE POLICY "Users can delete own tasks" ON tasks
      FOR DELETE USING (auth.uid() = user_id);
    
    -- Similar policies should be created for expenses, reminders, and chat_messages tables
    ''');
  }

  /// Test database connection
  static Future<bool> testConnection() async {
    try {
      Logger.info('Testing Supabase connection');
      
      // Try to execute a simple query
      await client.from('tasks').select('count').limit(0);
      
      Logger.info('Supabase connection test successful');
      return true;
    } catch (e) {
      Logger.error('Supabase connection test failed: $e');
      return false;
    }
  }

  /// Get database health status
  static Future<Map<String, dynamic>> getHealthStatus() async {
    try {
      Logger.info('Checking Supabase health status');
      
      final startTime = DateTime.now();
      
      // Test basic connectivity
      final connectionTest = await testConnection();
      
      // Test authentication status
      final authStatus = isAuthenticated;
      
      // Calculate response time
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      final status = {
        'connected': connectionTest,
        'authenticated': authStatus,
        'response_time_ms': responseTime,
        'user_id': currentUserId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      Logger.info('Supabase health status: $status');
      return status;
    } catch (e) {
      Logger.error('Failed to get Supabase health status: $e');
      return {
        'connected': false,
        'authenticated': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Handle common Supabase errors
  static String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case '23505':
          return 'This item already exists';
        case '23503':
          return 'Cannot perform this operation due to related data';
        case '42501':
          return 'You do not have permission to perform this operation';
        case 'PGRST116':
          return 'No data found';
        case 'PGRST301':
          return 'Row Level Security policy violation';
        default:
          return 'Database error: ${error.message}';
      }
    }
    
    if (error is AuthException) {
      return 'Authentication error: ${error.message}';
    }
    
    if (error is StorageException) {
      return 'Storage error: ${error.message}';
    }
    
    return 'An unexpected error occurred: $error';
  }

  /// Create a real-time subscription
  static RealtimeChannel createSubscription({
    required String channelName,
    required String table,
    required void Function(PostgresChangePayload) onInsert,
    required void Function(PostgresChangePayload) onUpdate,
    required void Function(PostgresChangePayload) onDelete,
    PostgresChangeFilter? filter,
  }) {
    Logger.info('Creating real-time subscription for table: $table');
    
    var channel = client.channel(channelName);
    
    // Add postgres changes listeners
    channel = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: table,
          filter: filter,
          callback: onInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: table,
          filter: filter,
          callback: onUpdate,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: table,
          filter: filter,
          callback: onDelete,
        );
    
    return channel;
  }

  /// Subscribe to authentication state changes
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// Clean up resources
  static Future<void> dispose() async {
    try {
      Logger.info('Disposing Supabase service');
      // Close any open connections or subscriptions
      // The Supabase client handles most cleanup automatically
      Logger.info('Supabase service disposed');
    } catch (e) {
      Logger.error('Error disposing Supabase service: $e');
    }
  }
}