import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../utils/logger.dart';
import '../data/supabase_service.dart';
import '../cache/cache_service.dart';
import 'realtime_service.dart';

/// Enum for sync status
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  offline,
}

/// Enum for sync operation types
enum SyncOperation {
  create,
  update,
  delete,
}

/// Represents a pending sync operation
class PendingSyncOperation {
  final String id;
  final String table;
  final SyncOperation operation;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;
  final String? recordId;

  const PendingSyncOperation({
    required this.id,
    required this.table,
    required this.operation,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
    this.recordId,
  });

  PendingSyncOperation copyWith({
    String? id,
    String? table,
    SyncOperation? operation,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retryCount,
    String? recordId,
  }) {
    return PendingSyncOperation(
      id: id ?? this.id,
      table: table ?? this.table,
      operation: operation ?? this.operation,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      recordId: recordId ?? this.recordId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table': table,
      'operation': operation.name,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'retry_count': retryCount,
      'record_id': recordId,
    };
  }

  factory PendingSyncOperation.fromJson(Map<String, dynamic> json) {
    return PendingSyncOperation(
      id: json['id'] as String,
      table: json['table'] as String,
      operation: SyncOperation.values.firstWhere(
        (e) => e.name == json['operation'],
      ),
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      retryCount: json['retry_count'] as int? ?? 0,
      recordId: json['record_id'] as String?,
    );
  }
}

/// Configuration for sync behavior
class SyncConfig {
  final Duration syncInterval;
  final int maxRetries;
  final Duration initialRetryDelay;
  final Duration maxRetryDelay;
  final double retryBackoffMultiplier;
  final Duration conflictResolutionWindow;

  const SyncConfig({
    this.syncInterval = const Duration(minutes: 5),
    this.maxRetries = 3,
    this.initialRetryDelay = const Duration(seconds: 2),
    this.maxRetryDelay = const Duration(minutes: 5),
    this.retryBackoffMultiplier = 2.0,
    this.conflictResolutionWindow = const Duration(seconds: 30),
  });
}

/// Service for coordinating online/offline data synchronization
class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  
  SyncService._();

  /// Reset the singleton instance (for testing purposes)
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  final CacheService _cacheService = CacheServiceImpl();
  final RealtimeService _realtimeService = RealtimeService.instance;
  final Connectivity _connectivity = Connectivity();
  
  final StreamController<SyncStatus> _statusController = 
      StreamController<SyncStatus>.broadcast();
  final StreamController<Map<String, dynamic>> _syncEventController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  final List<PendingSyncOperation> _pendingOperations = [];
  final Map<String, DateTime> _lastSyncTimes = {};
  
  Timer? _syncTimer;
  Timer? _retryTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  SyncConfig _config = const SyncConfig();
  SyncStatus _currentStatus = SyncStatus.idle;
  bool _isOnline = true;
  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Stream of sync status changes
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Stream of sync events (detailed information)
  Stream<Map<String, dynamic>> get syncEventStream => _syncEventController.stream;

  /// Current sync status
  SyncStatus get currentStatus => _currentStatus;

  /// Whether the device is currently online
  bool get isOnline => _isOnline;

  /// Number of pending sync operations
  int get pendingOperationsCount => _pendingOperations.length;

  /// List of pending operations (read-only)
  List<PendingSyncOperation> get pendingOperations => List.unmodifiable(_pendingOperations);

  /// Initialize the sync service
  Future<void> initialize({SyncConfig? config}) async {
    if (_isInitialized || _isDisposed) return;

    try {
      Logger.info('Initializing SyncService');
      
      if (config != null) {
        _config = config;
      }

      // Initialize connectivity monitoring
      await _initializeConnectivity();
      
      // Load pending operations from cache
      await _loadPendingOperations();
      
      // Start periodic sync
      _startPeriodicSync();
      
      _isInitialized = true;
      _updateStatus(SyncStatus.idle);
      
      Logger.info('SyncService initialized successfully');
    } catch (e) {
      Logger.error('Failed to initialize SyncService: $e');
      _updateStatus(SyncStatus.error);
      rethrow;
    }
  }

  /// Queue a sync operation for later execution
  Future<void> queueOperation({
    required String table,
    required SyncOperation operation,
    required Map<String, dynamic> data,
    String? recordId,
  }) async {
    if (_isDisposed) {
      Logger.warning('SyncService is disposed, cannot queue operation');
      return;
    }

    try {
      final operationId = _generateOperationId();
      final pendingOp = PendingSyncOperation(
        id: operationId,
        table: table,
        operation: operation,
        data: Map<String, dynamic>.from(data),
        timestamp: DateTime.now(),
        recordId: recordId,
      );

      _pendingOperations.add(pendingOp);
      await _savePendingOperations();

      Logger.info('Queued ${operation.name} operation for $table: $operationId');
      
      _emitSyncEvent({
        'type': 'operation_queued',
        'operation': pendingOp.toJson(),
        'pending_count': _pendingOperations.length,
      });

      // Try to sync immediately if online
      if (_isOnline) {
        _scheduleSyncAttempt();
      }
    } catch (e) {
      Logger.error('Failed to queue sync operation: $e');
    }
  }

  /// Manually trigger a sync attempt
  Future<void> sync({bool force = false}) async {
    if (_isDisposed || (!_isOnline && !force)) return;

    if (_currentStatus == SyncStatus.syncing) {
      Logger.debug('Sync already in progress, skipping');
      return;
    }

    try {
      _updateStatus(SyncStatus.syncing);
      Logger.info('Starting sync process');

      final startTime = DateTime.now();
      var successCount = 0;
      var errorCount = 0;

      // Process pending operations
      final operationsToProcess = List<PendingSyncOperation>.from(_pendingOperations);
      
      for (final operation in operationsToProcess) {
        try {
          await _processSyncOperation(operation);
          _pendingOperations.remove(operation);
          successCount++;
          
          Logger.debug('Successfully synced operation: ${operation.id}');
        } catch (e) {
          Logger.warning('Failed to sync operation ${operation.id}: $e');
          
          // Update retry count
          final updatedOperation = operation.copyWith(
            retryCount: operation.retryCount + 1,
          );
          
          final index = _pendingOperations.indexOf(operation);
          if (index != -1) {
            _pendingOperations[index] = updatedOperation;
          }
          
          // Remove if max retries exceeded
          if (updatedOperation.retryCount >= _config.maxRetries) {
            _pendingOperations.remove(operation);
            Logger.error('Max retries exceeded for operation: ${operation.id}');
          }
          
          errorCount++;
        }
      }

      // Save updated pending operations
      await _savePendingOperations();

      final duration = DateTime.now().difference(startTime);
      
      _emitSyncEvent({
        'type': 'sync_completed',
        'success_count': successCount,
        'error_count': errorCount,
        'duration_ms': duration.inMilliseconds,
        'remaining_operations': _pendingOperations.length,
      });

      if (errorCount == 0) {
        _updateStatus(SyncStatus.success);
        Logger.info('Sync completed successfully: $successCount operations');
      } else {
        _updateStatus(SyncStatus.error);
        Logger.warning('Sync completed with errors: $errorCount failed, $successCount succeeded');
        
        // Schedule retry for failed operations
        _scheduleRetry();
      }
    } catch (e) {
      Logger.error('Sync process failed: $e');
      _updateStatus(SyncStatus.error);
      _scheduleRetry();
    }
  }

  /// Handle incoming realtime data changes
  Future<void> handleRealtimeChange({
    required String table,
    required String changeType,
    required Map<String, dynamic> record,
  }) async {
    if (_isDisposed) return;

    try {
      Logger.debug('Handling realtime change: $changeType on $table');

      // Check for conflicts with pending operations
      final conflicts = _findConflictingOperations(table, record);
      
      if (conflicts.isNotEmpty) {
        await _resolveConflicts(conflicts, record, changeType);
      }

      // Update local cache
      await _updateLocalCache(table, changeType, record);
      
      // Update last sync time
      _lastSyncTimes[table] = DateTime.now();

      _emitSyncEvent({
        'type': 'realtime_change_processed',
        'table': table,
        'change_type': changeType,
        'record_id': record['id'],
        'conflicts_resolved': conflicts.length,
      });
    } catch (e) {
      Logger.error('Failed to handle realtime change: $e');
    }
  }

  /// Get the last sync time for a table
  DateTime? getLastSyncTime(String table) {
    return _lastSyncTimes[table];
  }

  /// Check if a table needs syncing
  bool needsSync(String table, {Duration? maxAge}) {
    final lastSync = _lastSyncTimes[table];
    if (lastSync == null) return true;
    
    final age = maxAge ?? _config.syncInterval;
    return DateTime.now().difference(lastSync) > age;
  }

  /// Clear all pending operations
  Future<void> clearPendingOperations() async {
    try {
      _pendingOperations.clear();
      await _savePendingOperations();
      
      Logger.info('Cleared all pending sync operations');
      
      _emitSyncEvent({
        'type': 'pending_operations_cleared',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      Logger.error('Failed to clear pending operations: $e');
    }
  }

  /// Initialize connectivity monitoring
  Future<void> _initializeConnectivity() async {
    try {
      // Check initial connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      _isOnline = connectivityResult != ConnectivityResult.none;
      
      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (ConnectivityResult result) {
          final wasOnline = _isOnline;
          _isOnline = result != ConnectivityResult.none;
          
          Logger.info('Connectivity changed: ${_isOnline ? 'online' : 'offline'}');
          
          if (!wasOnline && _isOnline) {
            // Just came online, trigger sync
            Logger.info('Device came online, triggering sync');
            _scheduleSyncAttempt();
          } else if (wasOnline && !_isOnline) {
            // Just went offline
            Logger.info('Device went offline');
            _updateStatus(SyncStatus.offline);
          }
          
          _emitSyncEvent({
            'type': 'connectivity_changed',
            'is_online': _isOnline,
            'connectivity_result': result.name,
          });
        },
      );
      
      if (!_isOnline) {
        _updateStatus(SyncStatus.offline);
      }
    } catch (e) {
      Logger.error('Failed to initialize connectivity monitoring: $e');
    }
  }

  /// Load pending operations from cache
  Future<void> _loadPendingOperations() async {
    try {
      final cachedOps = await _cacheService.getCachedData<Map<String, dynamic>>('pending_sync_operations');
      
      if (cachedOps != null) {
        _pendingOperations.clear();
        for (final opData in cachedOps) {
          try {
            final operation = PendingSyncOperation.fromJson(opData);
            _pendingOperations.add(operation);
          } catch (e) {
            Logger.warning('Failed to parse cached sync operation: $e');
          }
        }
        
        Logger.info('Loaded ${_pendingOperations.length} pending sync operations from cache');
      }
    } catch (e) {
      Logger.error('Failed to load pending operations: $e');
    }
  }

  /// Save pending operations to cache
  Future<void> _savePendingOperations() async {
    try {
      final operationsData = _pendingOperations.map((op) => op.toJson()).toList();
      await _cacheService.cacheData('pending_sync_operations', operationsData);
    } catch (e) {
      Logger.error('Failed to save pending operations: $e');
    }
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_config.syncInterval, (_) {
      if (_isOnline && _pendingOperations.isNotEmpty) {
        sync();
      }
    });
  }

  /// Schedule a sync attempt with a short delay
  void _scheduleSyncAttempt() {
    Timer(const Duration(seconds: 1), () {
      if (_isOnline) {
        sync();
      }
    });
  }

  /// Schedule retry with exponential backoff
  void _scheduleRetry() {
    _retryTimer?.cancel();
    
    final delay = Duration(
      milliseconds: (_config.initialRetryDelay.inMilliseconds * 
          pow(_config.retryBackoffMultiplier, _getAverageRetryCount())).round().clamp(
        _config.initialRetryDelay.inMilliseconds,
        _config.maxRetryDelay.inMilliseconds,
      ),
    );
    
    Logger.info('Scheduling retry in ${delay.inSeconds} seconds');
    
    _retryTimer = Timer(delay, () {
      if (_isOnline && _pendingOperations.isNotEmpty) {
        sync();
      }
    });
  }

  /// Process a single sync operation
  Future<void> _processSyncOperation(PendingSyncOperation operation) async {
    final client = SupabaseService.client;
    
    switch (operation.operation) {
      case SyncOperation.create:
        await client.from(operation.table).insert(operation.data);
        break;
        
      case SyncOperation.update:
        if (operation.recordId == null) {
          throw Exception('Record ID required for update operation');
        }
        await client.from(operation.table)
            .update(operation.data)
            .eq('id', operation.recordId!);
        break;
        
      case SyncOperation.delete:
        if (operation.recordId == null) {
          throw Exception('Record ID required for delete operation');
        }
        await client.from(operation.table)
            .delete()
            .eq('id', operation.recordId!);
        break;
    }
  }

  /// Find operations that conflict with incoming realtime data
  List<PendingSyncOperation> _findConflictingOperations(
    String table, 
    Map<String, dynamic> record,
  ) {
    final recordId = record['id'] as String?;
    if (recordId == null) return [];
    
    return _pendingOperations.where((op) => 
      op.table == table && 
      op.recordId == recordId &&
      DateTime.now().difference(op.timestamp) < _config.conflictResolutionWindow
    ).toList();
  }

  /// Resolve conflicts using last-write-wins strategy
  Future<void> _resolveConflicts(
    List<PendingSyncOperation> conflicts,
    Map<String, dynamic> incomingRecord,
    String changeType,
  ) async {
    try {
      Logger.info('Resolving ${conflicts.length} conflicts using last-write-wins');
      
      final incomingTimestamp = DateTime.tryParse(incomingRecord['updated_at'] as String? ?? '') 
          ?? DateTime.now();
      
      for (final conflict in conflicts) {
        // Compare timestamps - incoming data wins if it's newer
        if (incomingTimestamp.isAfter(conflict.timestamp)) {
          Logger.debug('Incoming data is newer, removing conflicting operation: ${conflict.id}');
          _pendingOperations.remove(conflict);
        } else {
          Logger.debug('Local operation is newer, keeping: ${conflict.id}');
          // Keep the local operation, it will be synced later
        }
      }
      
      await _savePendingOperations();
    } catch (e) {
      Logger.error('Failed to resolve conflicts: $e');
    }
  }

  /// Update local cache with realtime changes
  Future<void> _updateLocalCache(
    String table,
    String changeType,
    Map<String, dynamic> record,
  ) async {
    try {
      // This would integrate with specific cache services for each data type
      // For now, we'll emit an event that can be handled by data providers
      _emitSyncEvent({
        'type': 'cache_update_required',
        'table': table,
        'change_type': changeType,
        'record': record,
      });
    } catch (e) {
      Logger.error('Failed to update local cache: $e');
    }
  }

  /// Generate a unique operation ID
  String _generateOperationId() {
    return 'sync_${DateTime.now().millisecondsSinceEpoch}_${_pendingOperations.length}';
  }

  /// Get average retry count for backoff calculation
  int _getAverageRetryCount() {
    if (_pendingOperations.isEmpty) return 0;
    
    final totalRetries = _pendingOperations.fold<int>(
      0, (sum, op) => sum + op.retryCount,
    );
    
    return (totalRetries / _pendingOperations.length).round();
  }

  /// Update sync status and notify listeners
  void _updateStatus(SyncStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      if (!_statusController.isClosed) {
        _statusController.add(status);
      }
    }
  }

  /// Emit a sync event
  void _emitSyncEvent(Map<String, dynamic> event) {
    if (!_syncEventController.isClosed) {
      event['timestamp'] = DateTime.now().toIso8601String();
      _syncEventController.add(event);
    }
  }

  /// Get health status of the sync service
  Map<String, dynamic> getHealthStatus() {
    return {
      'initialized': _isInitialized,
      'disposed': _isDisposed,
      'current_status': _currentStatus.name,
      'is_online': _isOnline,
      'pending_operations': _pendingOperations.length,
      'last_sync_times': _lastSyncTimes.map(
        (table, time) => MapEntry(table, time.toIso8601String()),
      ),
      'config': {
        'sync_interval_minutes': _config.syncInterval.inMinutes,
        'max_retries': _config.maxRetries,
        'initial_retry_delay_seconds': _config.initialRetryDelay.inSeconds,
        'max_retry_delay_minutes': _config.maxRetryDelay.inMinutes,
      },
      'has_sync_timer': _syncTimer != null,
      'has_retry_timer': _retryTimer != null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Dispose the service and clean up resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    Logger.info('Disposing SyncService');
    
    _isDisposed = true;
    
    _syncTimer?.cancel();
    _retryTimer?.cancel();
    await _connectivitySubscription?.cancel();
    
    await _statusController.close();
    await _syncEventController.close();
    
    _pendingOperations.clear();
    _lastSyncTimes.clear();
    
    Logger.info('SyncService disposed');
  }
}