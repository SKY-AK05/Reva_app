import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';
import '../data/supabase_service.dart';

/// Enum for subscription status
enum SubscriptionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// Callback types for realtime events
typedef RealtimeInsertCallback = void Function(Map<String, dynamic> payload);
typedef RealtimeUpdateCallback = void Function(Map<String, dynamic> payload);
typedef RealtimeDeleteCallback = void Function(Map<String, dynamic> payload);
typedef ConnectionStatusCallback = void Function(SubscriptionStatus status);

/// Configuration for a realtime subscription
class SubscriptionConfig {
  final String table;
  final String? filter;
  final RealtimeInsertCallback? onInsert;
  final RealtimeUpdateCallback? onUpdate;
  final RealtimeDeleteCallback? onDelete;

  const SubscriptionConfig({
    required this.table,
    this.filter,
    this.onInsert,
    this.onUpdate,
    this.onDelete,
  });
}

/// Service for managing Supabase realtime subscriptions
class RealtimeService {
  static RealtimeService? _instance;
  static RealtimeService get instance => _instance ??= RealtimeService._();
  
  RealtimeService._();

  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, SubscriptionConfig> _subscriptionConfigs = {};
  final Map<String, SubscriptionStatus> _subscriptionStatuses = {};
  final StreamController<Map<String, SubscriptionStatus>> _statusController = 
      StreamController<Map<String, SubscriptionStatus>>.broadcast();
  
  Timer? _reconnectionTimer;
  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Stream of subscription statuses
  Stream<Map<String, SubscriptionStatus>> get statusStream => _statusController.stream;

  /// Get current subscription statuses
  Map<String, SubscriptionStatus> get subscriptionStatuses => Map.from(_subscriptionStatuses);

  /// Initialize the realtime service
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    try {
      Logger.info('Initializing RealtimeService');
      
      // Check if user is authenticated
      if (!SupabaseService.isAuthenticated) {
        Logger.warning('User not authenticated, skipping realtime initialization');
        return;
      }

      _isInitialized = true;
      Logger.info('RealtimeService initialized successfully');
    } catch (e) {
      Logger.error('Failed to initialize RealtimeService: $e');
      rethrow;
    }
  }

  /// Subscribe to realtime changes for a table
  Future<void> subscribe({
    required String subscriptionId,
    required SubscriptionConfig config,
  }) async {
    if (_isDisposed) {
      Logger.warning('RealtimeService is disposed, cannot subscribe');
      return;
    }

    try {
      Logger.info('Creating subscription for table: ${config.table}');
      
      // Store the configuration for reconnection
      _subscriptionConfigs[subscriptionId] = config;
      _updateSubscriptionStatus(subscriptionId, SubscriptionStatus.connecting);

      // Create the channel
      final channelName = 'realtime_${config.table}_$subscriptionId';
      final channel = SupabaseService.client.channel(channelName);

      // Configure postgres changes listeners
      var configuredChannel = channel;

      if (config.onInsert != null) {
        configuredChannel = configuredChannel.onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: config.table,
          filter: config.filter != null ? PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: config.filter!.split('=')[0],
            value: config.filter!.split('=')[1],
          ) : null,
          callback: (payload) {
            Logger.debug('Received INSERT for ${config.table}: ${payload.newRecord}');
            config.onInsert!(payload.newRecord);
          },
        );
      }

      if (config.onUpdate != null) {
        configuredChannel = configuredChannel.onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: config.table,
          filter: config.filter != null ? PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: config.filter!.split('=')[0],
            value: config.filter!.split('=')[1],
          ) : null,
          callback: (payload) {
            Logger.debug('Received UPDATE for ${config.table}: ${payload.newRecord}');
            config.onUpdate!(payload.newRecord);
          },
        );
      }

      if (config.onDelete != null) {
        configuredChannel = configuredChannel.onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: config.table,
          filter: config.filter != null ? PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: config.filter!.split('=')[0],
            value: config.filter!.split('=')[1],
          ) : null,
          callback: (payload) {
            Logger.debug('Received DELETE for ${config.table}: ${payload.oldRecord}');
            config.onDelete!(payload.oldRecord);
          },
        );
      }

      // Subscribe to the channel
      await configuredChannel.subscribe((status, error) {
        Logger.info('Subscription status for ${config.table}: $status');
        
        if (error != null) {
          Logger.error('Subscription error for ${config.table}: $error');
          _updateSubscriptionStatus(subscriptionId, SubscriptionStatus.error);
          _scheduleReconnection(subscriptionId);
        } else {
          switch (status) {
            case RealtimeSubscribeStatus.subscribed:
              _updateSubscriptionStatus(subscriptionId, SubscriptionStatus.connected);
              _cancelReconnectionTimer();
              break;
            case RealtimeSubscribeStatus.timedOut:
              _updateSubscriptionStatus(subscriptionId, SubscriptionStatus.error);
              _scheduleReconnection(subscriptionId);
              break;
            case RealtimeSubscribeStatus.channelError:
              _updateSubscriptionStatus(subscriptionId, SubscriptionStatus.error);
              _scheduleReconnection(subscriptionId);
              break;
            case RealtimeSubscribeStatus.closed:
              _updateSubscriptionStatus(subscriptionId, SubscriptionStatus.disconnected);
              _scheduleReconnection(subscriptionId);
              break;
          }
        }
      });

      // Store the channel
      _channels[subscriptionId] = configuredChannel;
      
      Logger.info('Successfully created subscription for ${config.table}');
    } catch (e) {
      Logger.error('Failed to subscribe to ${config.table}: $e');
      _updateSubscriptionStatus(subscriptionId, SubscriptionStatus.error);
      _scheduleReconnection(subscriptionId);
    }
  }

  /// Unsubscribe from a specific subscription
  Future<void> unsubscribe(String subscriptionId) async {
    try {
      Logger.info('Unsubscribing from: $subscriptionId');
      
      final channel = _channels[subscriptionId];
      if (channel != null) {
        await channel.unsubscribe();
        _channels.remove(subscriptionId);
      }
      
      _subscriptionConfigs.remove(subscriptionId);
      _subscriptionStatuses.remove(subscriptionId);
      
      _notifyStatusChange();
      
      Logger.info('Successfully unsubscribed from: $subscriptionId');
    } catch (e) {
      Logger.error('Failed to unsubscribe from $subscriptionId: $e');
    }
  }

  /// Unsubscribe from all subscriptions
  Future<void> unsubscribeAll() async {
    try {
      Logger.info('Unsubscribing from all subscriptions');
      
      final subscriptionIds = List<String>.from(_channels.keys);
      for (final subscriptionId in subscriptionIds) {
        await unsubscribe(subscriptionId);
      }
      
      Logger.info('Successfully unsubscribed from all subscriptions');
    } catch (e) {
      Logger.error('Failed to unsubscribe from all subscriptions: $e');
    }
  }

  /// Reconnect all subscriptions
  Future<void> reconnectAll() async {
    if (_isDisposed) return;

    try {
      Logger.info('Reconnecting all subscriptions');
      
      // First unsubscribe from existing channels
      await unsubscribeAll();
      
      // Wait a bit before reconnecting
      await Future.delayed(const Duration(seconds: 1));
      
      // Recreate all subscriptions
      final configs = Map<String, SubscriptionConfig>.from(_subscriptionConfigs);
      for (final entry in configs.entries) {
        await subscribe(
          subscriptionId: entry.key,
          config: entry.value,
        );
      }
      
      Logger.info('Successfully reconnected all subscriptions');
    } catch (e) {
      Logger.error('Failed to reconnect all subscriptions: $e');
    }
  }

  /// Check if a subscription is connected
  bool isSubscriptionConnected(String subscriptionId) {
    return _subscriptionStatuses[subscriptionId] == SubscriptionStatus.connected;
  }

  /// Get the status of a specific subscription
  SubscriptionStatus getSubscriptionStatus(String subscriptionId) {
    return _subscriptionStatuses[subscriptionId] ?? SubscriptionStatus.disconnected;
  }

  /// Update subscription status and notify listeners
  void _updateSubscriptionStatus(String subscriptionId, SubscriptionStatus status) {
    _subscriptionStatuses[subscriptionId] = status;
    _notifyStatusChange();
  }

  /// Notify listeners of status changes
  void _notifyStatusChange() {
    if (!_statusController.isClosed) {
      _statusController.add(Map.from(_subscriptionStatuses));
    }
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnection(String subscriptionId) {
    if (_isDisposed) return;

    _cancelReconnectionTimer();
    
    // Start with 2 seconds, max 30 seconds
    const initialDelay = Duration(seconds: 2);
    const maxDelay = Duration(seconds: 30);
    
    var delay = initialDelay;
    var attempts = 0;
    const maxAttempts = 5;

    void attemptReconnection() {
      if (_isDisposed || attempts >= maxAttempts) {
        Logger.warning('Max reconnection attempts reached for $subscriptionId');
        return;
      }

      attempts++;
      Logger.info('Attempting reconnection for $subscriptionId (attempt $attempts)');
      
      _reconnectionTimer = Timer(delay, () async {
        try {
          final config = _subscriptionConfigs[subscriptionId];
          if (config != null) {
            await subscribe(subscriptionId: subscriptionId, config: config);
          }
        } catch (e) {
          Logger.error('Reconnection attempt failed for $subscriptionId: $e');
          
          // Exponential backoff
          delay = Duration(
            milliseconds: (delay.inMilliseconds * 1.5).round().clamp(
              initialDelay.inMilliseconds,
              maxDelay.inMilliseconds,
            ),
          );
          
          // Schedule next attempt
          attemptReconnection();
        }
      });
    }

    attemptReconnection();
  }

  /// Cancel the reconnection timer
  void _cancelReconnectionTimer() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
  }

  /// Handle authentication state changes
  void handleAuthStateChange(AuthState authState) {
    if (_isDisposed) return;

    Logger.info('Handling auth state change: ${authState.event}');
    
    switch (authState.event) {
      case AuthChangeEvent.signedIn:
        // Reconnect all subscriptions when user signs in
        Future.delayed(const Duration(seconds: 1), () {
          reconnectAll();
        });
        break;
      case AuthChangeEvent.signedOut:
        // Unsubscribe from all when user signs out
        unsubscribeAll();
        break;
      case AuthChangeEvent.tokenRefreshed:
        // Optionally reconnect on token refresh
        Logger.debug('Token refreshed, subscriptions should continue working');
        break;
      default:
        break;
    }
  }

  /// Dispose the service and clean up resources
  Future<void> dispose() async {
    if (_isDisposed) return;

    Logger.info('Disposing RealtimeService');
    
    _isDisposed = true;
    _cancelReconnectionTimer();
    
    await unsubscribeAll();
    
    await _statusController.close();
    
    _channels.clear();
    _subscriptionConfigs.clear();
    _subscriptionStatuses.clear();
    
    Logger.info('RealtimeService disposed');
  }

  /// Get health status of the realtime service
  Map<String, dynamic> getHealthStatus() {
    final connectedCount = _subscriptionStatuses.values
        .where((status) => status == SubscriptionStatus.connected)
        .length;
    
    final totalCount = _subscriptionStatuses.length;
    
    return {
      'initialized': _isInitialized,
      'disposed': _isDisposed,
      'total_subscriptions': totalCount,
      'connected_subscriptions': connectedCount,
      'subscription_statuses': Map.fromEntries(
        _subscriptionStatuses.entries.map(
          (entry) => MapEntry(entry.key, entry.value.name),
        ),
      ),
      'has_reconnection_timer': _reconnectionTimer != null,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}