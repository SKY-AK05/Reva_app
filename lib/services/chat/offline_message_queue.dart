import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/chat_message.dart';
import '../../utils/logger.dart';

/// Manages offline message queue for chat functionality
class OfflineMessageQueue {
  static const String _queueKey = 'offline_message_queue';
  static const String _retryCountKey = 'message_retry_counts';
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  final List<QueuedMessage> _queue = [];
  final Map<String, int> _retryCounts = {};
  Timer? _retryTimer;
  bool _isProcessing = false;

  /// Add a message to the offline queue
  Future<void> queueMessage(ChatMessage message, {Map<String, dynamic>? context}) async {
    try {
      final queuedMessage = QueuedMessage(
        message: message,
        context: context,
        queuedAt: DateTime.now(),
        retryCount: 0,
      );

      _queue.add(queuedMessage);
      await _saveQueue();
      
      Logger.info('Message queued for offline sending: ${message.id}');
    } catch (e) {
      Logger.error('Failed to queue message: $e');
    }
  }

  /// Remove a message from the queue
  Future<void> removeMessage(String messageId) async {
    try {
      _queue.removeWhere((queuedMessage) => queuedMessage.message.id == messageId);
      _retryCounts.remove(messageId);
      await _saveQueue();
      await _saveRetryCounts();
      
      Logger.info('Message removed from queue: $messageId');
    } catch (e) {
      Logger.error('Failed to remove message from queue: $e');
    }
  }

  /// Get all queued messages
  List<QueuedMessage> getQueuedMessages() {
    return List.unmodifiable(_queue);
  }

  /// Get the count of queued messages
  int get queuedMessageCount => _queue.length;

  /// Check if a message is in the queue
  bool isMessageQueued(String messageId) {
    return _queue.any((queuedMessage) => queuedMessage.message.id == messageId);
  }

  /// Process the queue when connectivity is restored
  Future<void> processQueue(Future<void> Function(ChatMessage, Map<String, dynamic>?) sendFunction) async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;
    Logger.info('Processing offline message queue: ${_queue.length} messages');

    final messagesToProcess = List<QueuedMessage>.from(_queue);
    
    for (final queuedMessage in messagesToProcess) {
      try {
        await sendFunction(queuedMessage.message, queuedMessage.context);
        await removeMessage(queuedMessage.message.id);
        
        Logger.info('Successfully sent queued message: ${queuedMessage.message.id}');
      } catch (e) {
        await _handleRetry(queuedMessage, e);
      }
    }

    _isProcessing = false;
  }

  /// Handle retry logic for failed messages
  Future<void> _handleRetry(QueuedMessage queuedMessage, dynamic error) async {
    final messageId = queuedMessage.message.id;
    final currentRetryCount = _retryCounts[messageId] ?? 0;

    if (currentRetryCount >= _maxRetryAttempts) {
      Logger.error('Max retry attempts reached for message $messageId, removing from queue');
      await removeMessage(messageId);
      return;
    }

    _retryCounts[messageId] = currentRetryCount + 1;
    await _saveRetryCounts();

    Logger.warning('Failed to send message $messageId (attempt ${currentRetryCount + 1}/$_maxRetryAttempts): $error');

    // Schedule retry with exponential backoff
    final retryDelay = _retryDelay * (currentRetryCount + 1);
    _scheduleRetry(retryDelay);
  }

  /// Schedule a retry attempt
  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      Logger.info('Retry timer triggered, will process queue on next connectivity check');
    });
  }

  /// Load queue from persistent storage
  Future<void> loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load queue
      final queueJson = prefs.getString(_queueKey);
      if (queueJson != null) {
        final queueData = jsonDecode(queueJson) as List<dynamic>;
        _queue.clear();
        _queue.addAll(
          queueData.map((data) => QueuedMessage.fromJson(data as Map<String, dynamic>)),
        );
      }

      // Load retry counts
      final retryCountsJson = prefs.getString(_retryCountKey);
      if (retryCountsJson != null) {
        final retryCountsData = jsonDecode(retryCountsJson) as Map<String, dynamic>;
        _retryCounts.clear();
        _retryCounts.addAll(
          retryCountsData.map((key, value) => MapEntry(key, value as int)),
        );
      }

      Logger.info('Loaded offline message queue: ${_queue.length} messages');
    } catch (e) {
      Logger.error('Failed to load offline message queue: $e');
    }
  }

  /// Save queue to persistent storage
  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueData = _queue.map((queuedMessage) => queuedMessage.toJson()).toList();
      await prefs.setString(_queueKey, jsonEncode(queueData));
    } catch (e) {
      Logger.error('Failed to save offline message queue: $e');
    }
  }

  /// Save retry counts to persistent storage
  Future<void> _saveRetryCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_retryCountKey, jsonEncode(_retryCounts));
    } catch (e) {
      Logger.error('Failed to save retry counts: $e');
    }
  }

  /// Clear all queued messages
  Future<void> clearQueue() async {
    try {
      _queue.clear();
      _retryCounts.clear();
      await _saveQueue();
      await _saveRetryCounts();
      
      Logger.info('Offline message queue cleared');
    } catch (e) {
      Logger.error('Failed to clear offline message queue: $e');
    }
  }

  /// Get retry count for a specific message
  int getRetryCount(String messageId) {
    return _retryCounts[messageId] ?? 0;
  }

  /// Check if a message has exceeded retry limits
  bool hasExceededRetryLimit(String messageId) {
    return getRetryCount(messageId) >= _maxRetryAttempts;
  }

  /// Get messages that are ready for retry
  List<QueuedMessage> getMessagesReadyForRetry() {
    return _queue.where((queuedMessage) {
      final messageId = queuedMessage.message.id;
      return !hasExceededRetryLimit(messageId);
    }).toList();
  }

  /// Get failed messages that exceeded retry limits
  List<QueuedMessage> getFailedMessages() {
    return _queue.where((queuedMessage) {
      final messageId = queuedMessage.message.id;
      return hasExceededRetryLimit(messageId);
    }).toList();
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

/// Represents a message in the offline queue
class QueuedMessage {
  final ChatMessage message;
  final Map<String, dynamic>? context;
  final DateTime queuedAt;
  final int retryCount;

  const QueuedMessage({
    required this.message,
    this.context,
    required this.queuedAt,
    required this.retryCount,
  });

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      message: ChatMessage.fromJson(json['message'] as Map<String, dynamic>),
      context: json['context'] as Map<String, dynamic>?,
      queuedAt: DateTime.parse(json['queued_at'] as String),
      retryCount: json['retry_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message.toJson(),
      'context': context,
      'queued_at': queuedAt.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  QueuedMessage copyWith({
    ChatMessage? message,
    Map<String, dynamic>? context,
    DateTime? queuedAt,
    int? retryCount,
  }) {
    return QueuedMessage(
      message: message ?? this.message,
      context: context ?? this.context,
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  /// Check if this message is old and should be considered stale
  bool get isStale {
    const staleThreshold = Duration(hours: 24);
    return DateTime.now().difference(queuedAt) > staleThreshold;
  }

  /// Get a user-friendly description of the queue status
  String get statusDescription {
    if (retryCount == 0) {
      return 'Queued for sending';
    } else {
      return 'Retry attempt $retryCount';
    }
  }
}