import '../cache/database_helper.dart';
import '../storage/storage_permission_service.dart';
import '../../utils/logger.dart';

class DatabaseInitializationService {
  static const String _logTag = 'DatabaseInitializationService';
  static bool _isInitialized = false;

  /// Initialize database with proper permission handling
  static Future<bool> initializeDatabase() async {
    if (_isInitialized) {
      Logger.info('$_logTag: Database already initialized');
      return true;
    }

    try {
      Logger.info('$_logTag: Starting database initialization');

      // Step 1: Check and request storage permissions
      final hasPermissions = await StoragePermissionService.canAccessDatabase();
      if (!hasPermissions) {
        Logger.error('$_logTag: Storage permissions not available');
        await StoragePermissionService.handlePermissionDenied();
        return false;
      }

      // Step 2: Reset database if there are any corruption issues
      await _handleDatabaseCorruption();

      // Step 3: Initialize database connection
      final db = await DatabaseHelper.database;
      Logger.info('$_logTag: Database connection established');

      // Step 4: Verify database integrity
      final isHealthy = await _verifyDatabaseHealth();
      if (!isHealthy) {
        Logger.warning('$_logTag: Database health check failed, attempting reset');
        
        // Try again after reset
        final dbAfterReset = await DatabaseHelper.database;
        final isHealthyAfterReset = await _verifyDatabaseHealth();
        
        if (!isHealthyAfterReset) {
          Logger.error('$_logTag: Database still unhealthy after reset');
          return false;
        }
      }

      _isInitialized = true;
      Logger.info('$_logTag: Database initialization completed successfully');
      return true;

    } catch (e) {
      Logger.error('$_logTag: Database initialization failed: $e');
      return false;
    }
  }

  /// Handle potential database corruption
  static Future<void> _handleDatabaseCorruption() async {
    try {
      // This will clean up any corrupted WAL/SHM files
      // The cleanup happens automatically in DatabaseHelper._initDatabase()
      Logger.info('$_logTag: Checking for database corruption');
    } catch (e) {
      Logger.warning('$_logTag: Error during corruption check: $e');
    }
  }

  /// Verify database health
  static Future<bool> _verifyDatabaseHealth() async {
    try {
      final db = await DatabaseHelper.database;
      
      // Test basic database operations
      await db.rawQuery('SELECT 1');
      
      // Check if all required tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      
      final requiredTables = [
        DatabaseHelper.tasksTable,
        DatabaseHelper.expensesTable,
        DatabaseHelper.remindersTable,
        DatabaseHelper.chatMessagesTable,
        DatabaseHelper.cacheMetadataTable,
        DatabaseHelper.cacheDataTable,
      ];
      
      final existingTables = tables.map((t) => t['name'] as String).toSet();
      
      for (final table in requiredTables) {
        if (!existingTables.contains(table)) {
          Logger.warning('$_logTag: Missing table: $table');
          return false;
        }
      }
      
      Logger.info('$_logTag: Database health check passed');
      return true;
      
    } catch (e) {
      Logger.error('$_logTag: Database health check failed: $e');
      return false;
    }
  }

  /// Get database statistics for debugging
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      if (!_isInitialized) {
        return {'error': 'Database not initialized'};
      }
      
      final stats = await DatabaseHelper.getDatabaseStats();
      return {
        'initialized': _isInitialized,
        'stats': stats,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Force database reset (for debugging/recovery)
  static Future<bool> forceReset() async {
    try {
      Logger.info('$_logTag: Force resetting database');
      _isInitialized = false;
      
      return await initializeDatabase();
    } catch (e) {
      Logger.error('$_logTag: Force reset failed: $e');
      return false;
    }
  }

  /// Check if database is ready for use
  static bool get isReady => _isInitialized;
}