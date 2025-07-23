import 'dart:async';
import 'dart:math';
import '../../models/chat_message.dart';
import '../../utils/logger.dart';

/// Manages retry logic for failed chat messages
class RetryManager {
  static const int _maxRetryAttempts = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(minutes: 5);

  final Map<String, RetryInfo> _retryInfo = {};
  final Map<String, Timer> _retryTimers = {};

  /// Schedule a retry for a failed message
  Future<void> scheduleRetry(
    String messageId,
    Future<void> Function() retryFunction, {
    Duration? customDelay,
  }) async {
    final info = _retryInfo[messageId] ?? RetryInfo(messageId: messageId);
    
    if (info.attemptCount >= _maxRetryAttempts) {
      Logger.warning('Max retry attempts reached for message: $messageId');
      _retryInfo.remove(messageId);
      return;
    }

    info.attemptCount++;
    info.lastAttempt = DateTime.now();
    _retryInfo[messageId] = info;

    final delay = customDelay ?? _calculateRetryDelay(info.attemptCount);
    
    Logger.info('Scheduling retry ${info.attemptCount}/$_maxRetryAttempts for message $messageId in ${delay.inSeconds}s');

    _retryTimers[messageId]?.cancel();
    _retryTimers[messageId] = Timer(delay, () async {
      try {
        await retryFunction();
        _clearRetryInfo(messageId);
        Logger.info('Retry successful for message: $messageId');
      } catch (e) {
        Logger.error('Retry failed for message $messageId: $e');
        // Schedule next retry if not at max attempts
        if (info.attemptCount < _maxRetryAttempts) {
          await scheduleRetry(messageId, retryFunction);
        } else {
          _clearRetryInfo(messageId);
        }
      }
    });
  }

  /// Cancel retry for a message
  void cancelRetry(String messageId) {
    _retryTimers[messageId]?.cancel();
    _retryTimers.remove(messageId);
    _retryInfo.remove(messageId);
    Logger.debug('Cancelled retry for message: $messageId');
  }

  /// Get retry information for a message
  RetryInfo? getRetryInfo(String messageId) {
    return _retryInfo[messageId];
  }

  /// Check if a message is currently being retried
  bool isRetrying(String messageId) {
    return _retryTimers.containsKey(messageId);
  }

  /// Get all messages currently being retried
  List<String> getRetryingMessages() {
    return _retryTimers.keys.toList();
  }

  /// Clear retry information for a message
  void _clearRetryInfo(String messageId) {
    _retryTimers[messageId]?.cancel();
    _retryTimers.remove(messageId);
    _retryInfo.remove(messageId);
  }

  /// Calculate retry delay with exponential backoff
  Duration _calculateRetryDelay(int attemptCount) {
    final exponentialDelay = _baseRetryDelay * pow(2, attemptCount - 1);
    final jitteredDelay = exponentialDelay * (0.5 + Random().nextDouble() * 0.5);
    
    return Duration(
      milliseconds: min(jitteredDelay.inMilliseconds, _maxRetryDelay.inMilliseconds),
    );
  }

  /// Get retry statistics
  RetryStatistics getStatistics() {
    final activeRetries = _retryTimers.length;
    final totalRetries = _retryInfo.values.fold<int>(
      0, 
      (sum, info) => sum + info.attemptCount,
    );
    
    return RetryStatistics(
      activeRetries: activeRetries,
      totalRetries: totalRetries,
      messagesWithRetries: _retryInfo.length,
    );
  }

  /// Clear all retry information
  void clearAll() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _retryInfo.clear();
    Logger.info('Cleared all retry information');
  }

  /// Dispose resources
  void dispose() {
    clearAll();
  }
}

/// Information about retry attempts for a message
class RetryInfo {
  final String messageId;
  int attemptCount;
  DateTime? lastAttempt;
  DateTime? nextRetry;

  RetryInfo({
    required this.messageId,
    this.attemptCount = 0,
    this.lastAttempt,
    this.nextRetry,
  });

  /// Check if this message has exceeded retry limits
  bool get hasExceededLimit => attemptCount >= 3;

  /// Get time until next retry
  Duration? get timeUntilNextRetry {
    if (nextRetry == null) return null;
    final now = DateTime.now();
    if (nextRetry!.isBefore(now)) return null;
    return nextRetry!.difference(now);
  }

  /// Get user-friendly status description
  String get statusDescription {
    if (attemptCount == 0) {
      return 'Pending';
    } else if (hasExceededLimit) {
      return 'Failed after $attemptCount attempts';
    } else {
      return 'Retry attempt $attemptCount/3';
    }
  }
}

/// Statistics about retry operations
class RetryStatistics {
  final int activeRetries;
  final int totalRetries;
  final int messagesWithRetries;

  const RetryStatistics({
    required this.activeRetries,
    required this.totalRetries,
    required this.messagesWithRetries,
  });

  @override
  String toString() {
    return 'RetryStatistics(active: $activeRetries, total: $totalRetries, messages: $messagesWithRetries)';
  }
}