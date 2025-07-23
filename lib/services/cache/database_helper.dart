import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io'; // Add this import

class DatabaseHelper {
  static const String _databaseName = 'reva_cache.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String tasksTable = 'tasks';
  static const String expensesTable = 'expenses';
  static const String remindersTable = 'reminders';
  static const String chatMessagesTable = 'chat_messages';
  static const String cacheMetadataTable = 'cache_metadata';
  static const String cacheDataTable = 'cache_data';

  static Database? _database;

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    final db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Configure database settings after opening (outside of transaction)
    await _configureDatabaseSettings(db);
    
    return db;
  }

  static Future<void> _configureDatabaseSettings(Database db) async {
    try {
      print('Attempting to set WAL mode...');
      // Only attempt WAL mode on Android
      if (Platform.isAndroid) {
        await db.execute('PRAGMA journal_mode=WAL');
        print('WAL mode set successfully.');
        await db.execute('PRAGMA synchronous=NORMAL');
        await db.execute('PRAGMA cache_size=10000');
        await db.execute('PRAGMA temp_store=MEMORY');
      } else {
        print('Not Android, skipping WAL mode.');
      }
    } catch (e) {
      // If WAL mode fails, fall back to DELETE mode
      print('Warning: Could not enable WAL mode, falling back to DELETE mode: $e');
      try {
        await db.execute('PRAGMA journal_mode=DELETE');
        await db.execute('PRAGMA synchronous=FULL');
      } catch (e2) {
        print('Warning: Could not set DELETE mode either: $e2');
      }
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Only create tables and indexes here, do not run PRAGMA statements
    // Tasks table
    await db.execute('''
      CREATE TABLE $tasksTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        description TEXT NOT NULL,
        due_date TEXT,
        priority TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Expenses table
    await db.execute('''
      CREATE TABLE $expensesTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        item TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Reminders table
    await db.execute('''
      CREATE TABLE $remindersTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        scheduled_time TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Chat messages table
    await db.execute('''
      CREATE TABLE $chatMessagesTable (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        metadata TEXT,
        synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Cache metadata table
    await db.execute('''
      CREATE TABLE $cacheMetadataTable (
        key TEXT PRIMARY KEY,
        last_updated TEXT NOT NULL,
        expires_at TEXT
      )
    ''');

    // Cache data table
    await db.execute('''
      CREATE TABLE $cacheDataTable (
        key TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create optimized indexes for better query performance
    await _createIndexes(db);
  }

  static Future<void> _createIndexes(Database db) async {
    // Tasks indexes
    await db.execute('CREATE INDEX idx_tasks_user_id ON $tasksTable(user_id)');
    await db.execute('CREATE INDEX idx_tasks_completed ON $tasksTable(completed)');
    await db.execute('CREATE INDEX idx_tasks_due_date ON $tasksTable(due_date)');
    await db.execute('CREATE INDEX idx_tasks_priority ON $tasksTable(priority)');
    await db.execute('CREATE INDEX idx_tasks_updated_at ON $tasksTable(updated_at)');
    await db.execute('CREATE INDEX idx_tasks_user_completed ON $tasksTable(user_id, completed)');
    
    // Expenses indexes
    await db.execute('CREATE INDEX idx_expenses_user_id ON $expensesTable(user_id)');
    await db.execute('CREATE INDEX idx_expenses_date ON $expensesTable(date)');
    await db.execute('CREATE INDEX idx_expenses_category ON $expensesTable(category)');
    await db.execute('CREATE INDEX idx_expenses_user_date ON $expensesTable(user_id, date)');
    await db.execute('CREATE INDEX idx_expenses_user_category ON $expensesTable(user_id, category)');
    
    // Reminders indexes
    await db.execute('CREATE INDEX idx_reminders_user_id ON $remindersTable(user_id)');
    await db.execute('CREATE INDEX idx_reminders_scheduled_time ON $remindersTable(scheduled_time)');
    await db.execute('CREATE INDEX idx_reminders_completed ON $remindersTable(completed)');
    await db.execute('CREATE INDEX idx_reminders_user_scheduled ON $remindersTable(user_id, scheduled_time)');
    await db.execute('CREATE INDEX idx_reminders_user_completed ON $remindersTable(user_id, completed)');
    
    // Chat messages indexes
    await db.execute('CREATE INDEX idx_chat_messages_timestamp ON $chatMessagesTable(timestamp)');
    await db.execute('CREATE INDEX idx_chat_messages_type ON $chatMessagesTable(type)');
    await db.execute('CREATE INDEX idx_chat_messages_type_timestamp ON $chatMessagesTable(type, timestamp)');
    
    // Cache indexes
    await db.execute('CREATE INDEX idx_cache_metadata_expires_at ON $cacheMetadataTable(expires_at)');
    await db.execute('CREATE INDEX idx_cache_data_created_at ON $cacheDataTable(created_at)');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database schema upgrades here
    // For now, we'll just recreate the tables
    if (oldVersion < newVersion) {
      await db.execute('DROP TABLE IF EXISTS $tasksTable');
      await db.execute('DROP TABLE IF EXISTS $expensesTable');
      await db.execute('DROP TABLE IF EXISTS $remindersTable');
      await db.execute('DROP TABLE IF EXISTS $chatMessagesTable');
      await db.execute('DROP TABLE IF EXISTS $cacheMetadataTable');
      await db.execute('DROP TABLE IF EXISTS $cacheDataTable');
      await _onCreate(db, newVersion);
    }
  }

  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete(tasksTable);
    await db.delete(expensesTable);
    await db.delete(remindersTable);
    await db.delete(chatMessagesTable);
    await db.delete(cacheMetadataTable);
    await db.delete(cacheDataTable);
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Optimize database performance
  static Future<void> optimizeDatabase() async {
    final db = await database;
    
    // Analyze tables to update query planner statistics
    await db.execute('ANALYZE');
    
    // Vacuum database to reclaim space and optimize
    await db.execute('VACUUM');
    
    // Update SQLite statistics
    await db.execute('PRAGMA optimize');
  }

  /// Get database performance statistics
  static Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;
    
    final pageCount = await db.rawQuery('PRAGMA page_count');
    final pageSize = await db.rawQuery('PRAGMA page_size');
    final cacheSize = await db.rawQuery('PRAGMA cache_size');
    final journalMode = await db.rawQuery('PRAGMA journal_mode');
    
    // Get table row counts
    final taskCount = await db.rawQuery('SELECT COUNT(*) as count FROM $tasksTable');
    final expenseCount = await db.rawQuery('SELECT COUNT(*) as count FROM $expensesTable');
    final reminderCount = await db.rawQuery('SELECT COUNT(*) as count FROM $remindersTable');
    final chatCount = await db.rawQuery('SELECT COUNT(*) as count FROM $chatMessagesTable');
    
    return {
      'pageCount': pageCount.first['page_count'],
      'pageSize': pageSize.first['page_size'],
      'cacheSize': cacheSize.first['cache_size'],
      'journalMode': journalMode.first['journal_mode'],
      'databaseSizeBytes': (pageCount.first['page_count'] as int) * (pageSize.first['page_size'] as int),
      'tableCounts': {
        'tasks': taskCount.first['count'],
        'expenses': expenseCount.first['count'],
        'reminders': reminderCount.first['count'],
        'chatMessages': chatCount.first['count'],
      },
    };
  }

  /// Execute batch operations for better performance
  static Future<void> executeBatch(List<String> statements) async {
    final db = await database;
    final batch = db.batch();
    
    for (final statement in statements) {
      batch.execute(statement);
    }
    
    await batch.commit(noResult: true);
  }

  /// Clean up old data to maintain performance
  static Future<void> cleanupOldData({
    Duration? chatMessageAge,
    Duration? cacheAge,
  }) async {
    final db = await database;
    final batch = db.batch();
    
    // Clean up old chat messages (default: 30 days)
    final chatCutoff = DateTime.now().subtract(chatMessageAge ?? const Duration(days: 30));
    batch.delete(
      chatMessagesTable,
      where: 'timestamp < ?',
      whereArgs: [chatCutoff.toIso8601String()],
    );
    
    // Clean up expired cache data
    final cacheCutoff = DateTime.now().subtract(cacheAge ?? const Duration(days: 7));
    batch.delete(
      cacheDataTable,
      where: 'created_at < ?',
      whereArgs: [cacheCutoff.toIso8601String()],
    );
    
    // Clean up expired cache metadata
    batch.delete(
      cacheMetadataTable,
      where: 'expires_at IS NOT NULL AND expires_at < ?',
      whereArgs: [DateTime.now().toIso8601String()],
    );
    
    await batch.commit(noResult: true);
  }
}