import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/logger.dart';

/// Comprehensive error handler with retry mechanisms and user-friendly messages
class ErrorHandler {
  static const int _defaultMaxRetries = 3;
  static const Duration _defaultDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 30);

  /// Execute an operation with retry logic
  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = _defaultMaxRetries,
    Duration delay = _defaultDelay,
    bool Function(Object error)? shouldRetry,
    String? operationName,
  }) async {
    int attempt = 0;
    Duration currentDelay = delay;

    while (attempt < maxRetries) {
      try {
        Logger.debug('Executing operation${operationName != null ? ' ($operationName)' : ''}, attempt ${attempt + 1}');
        final result = await operation();
        
        if (attempt > 0) {
          Logger.info('Operation${operationName != null ? ' ($operationName)' : ''} succeeded after ${attempt + 1} attempts');
        }
        
        return result;
      } catch (error, stackTrace) {
        attempt++;
        
        Logger.warning(
          'Operation${operationName != null ? ' ($operationName)' : ''} failed on attempt $attempt: ${error.toString()}',
          error,
          stackTrace,
        );

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          Logger.error('Operation${operationName != null ? ' ($operationName)' : ''} failed with non-retryable error');
          rethrow;
        }

        // If this was the last attempt, rethrow the error
        if (attempt >= maxRetries) {
          Logger.error('Operation${operationName != null ? ' ($operationName)' : ''} failed after $maxRetries attempts');
          rethrow;
        }

        // Wait before retrying with exponential backoff
        Logger.debug('Retrying in ${currentDelay.inMilliseconds}ms...');
        await Future.delayed(currentDelay);
        
        // Exponential backoff with jitter
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * 1.5).round() + 
                       (DateTime.now().millisecondsSinceEpoch % 1000),
        );
        
        // Cap the delay
        if (currentDelay > _maxDelay) {
          currentDelay = _maxDelay;
        }
      }
    }

    throw Exception('This should never be reached');
  }

  /// Handle and log errors with appropriate user messages
  static AppError handleError(Object error, StackTrace stackTrace, {String? context}) {
    final contextStr = context != null ? ' in $context' : '';
    Logger.error('Error occurred$contextStr: ${error.toString()}', error, stackTrace);

    // Convert to AppError with user-friendly message
    final appError = _convertToAppError(error);
    
    // Log the user-friendly message
    Logger.info('User-friendly error message: ${appError.userMessage}');
    
    return appError;
  }

  /// Convert various error types to AppError
  static AppError _convertToAppError(Object error) {
    if (error is AppError) {
      return error;
    }

    if (error is SocketException) {
      return AppError(
        type: ErrorType.network,
        message: error.toString(),
        userMessage: 'Unable to connect to the internet. Please check your connection and try again.',
        isRetryable: true,
      );
    }

    if (error is TimeoutException) {
      return AppError(
        type: ErrorType.timeout,
        message: error.toString(),
        userMessage: 'The request took too long to complete. Please try again.',
        isRetryable: true,
      );
    }

    if (error is AuthException) {
      return _handleAuthError(error);
    }

    if (error is PostgrestException) {
      return _handleSupabaseError(error);
    }

    if (error is FormatException) {
      return AppError(
        type: ErrorType.parsing,
        message: error.toString(),
        userMessage: 'There was a problem processing the data. Please try again.',
        isRetryable: true,
      );
    }

    if (error is ArgumentError) {
      return AppError(
        type: ErrorType.validation,
        message: error.toString(),
        userMessage: 'Invalid input provided. Please check your data and try again.',
        isRetryable: false,
      );
    }

    // Generic error
    return AppError(
      type: ErrorType.unknown,
      message: error.toString(),
      userMessage: 'An unexpected error occurred. Please try again.',
      isRetryable: true,
    );
  }

  /// Handle authentication-specific errors
  static AppError _handleAuthError(AuthException error) {
    switch (error.statusCode) {
      case '400':
        return AppError(
          type: ErrorType.authentication,
          message: error.message,
          userMessage: 'Invalid email or password. Please check your credentials.',
          isRetryable: false,
        );
      case '401':
        return AppError(
          type: ErrorType.authentication,
          message: error.message,
          userMessage: 'Your session has expired. Please log in again.',
          isRetryable: false,
        );
      case '403':
        return AppError(
          type: ErrorType.authorization,
          message: error.message,
          userMessage: 'You don\'t have permission to perform this action.',
          isRetryable: false,
        );
      case '422':
        return AppError(
          type: ErrorType.validation,
          message: error.message,
          userMessage: 'Please check your input and try again.',
          isRetryable: false,
        );
      case '429':
        return AppError(
          type: ErrorType.rateLimited,
          message: error.message,
          userMessage: 'Too many attempts. Please wait a moment and try again.',
          isRetryable: true,
        );
      default:
        return AppError(
          type: ErrorType.authentication,
          message: error.message,
          userMessage: 'Authentication failed. Please try logging in again.',
          isRetryable: false,
        );
    }
  }

  /// Handle Supabase-specific errors
  static AppError _handleSupabaseError(PostgrestException error) {
    switch (error.code) {
      case '23505': // Unique constraint violation
        return AppError(
          type: ErrorType.conflict,
          message: error.message,
          userMessage: 'This item already exists. Please try with different information.',
          isRetryable: false,
        );
      case '23503': // Foreign key constraint violation
        return AppError(
          type: ErrorType.validation,
          message: error.message,
          userMessage: 'Invalid reference. Please check your data.',
          isRetryable: false,
        );
      case '42501': // Insufficient privilege
        return AppError(
          type: ErrorType.authorization,
          message: error.message,
          userMessage: 'You don\'t have permission to perform this action.',
          isRetryable: false,
        );
      default:
        return AppError(
          type: ErrorType.server,
          message: error.message,
          userMessage: 'A server error occurred. Please try again later.',
          isRetryable: true,
        );
    }
  }

  /// Check if an error should be retried
  static bool shouldRetryError(Object error) {
    if (error is AppError) {
      return error.isRetryable;
    }

    // Network errors are generally retryable
    if (error is SocketException || error is TimeoutException) {
      return true;
    }

    // Auth errors are generally not retryable
    if (error is AuthException) {
      return error.statusCode == '429'; // Rate limiting is retryable
    }

    // Server errors (5xx) are retryable, client errors (4xx) are not
    if (error is PostgrestException) {
      final code = int.tryParse(error.code ?? '');
      if (code != null) {
        return code >= 500 && code < 600;
      }
    }

    // Default to retryable for unknown errors
    return true;
  }

  /// Log performance metrics
  static void logPerformance(String operation, Duration duration, {bool isError = false}) {
    if (isError) {
      Logger.warning('Performance: $operation failed after ${duration.inMilliseconds}ms');
    } else {
      Logger.performance(operation, duration);
    }
  }

  /// Log user action for debugging
  static void logUserAction(String action, {Map<String, dynamic>? context}) {
    Logger.info('User Action: $action${context != null ? ' - $context' : ''}');
  }

  /// Log system event
  static void logSystemEvent(String event, {String? details}) {
    Logger.info('System Event: $event${details != null ? ' - $details' : ''}');
  }

  /// Handle critical errors that should crash the app in debug mode
  static void handleCriticalError(Object error, StackTrace stackTrace, {String? context}) {
    final contextStr = context != null ? ' in $context' : '';
    Logger.error('CRITICAL ERROR$contextStr: ${error.toString()}', error, stackTrace);

    if (kDebugMode) {
      // In debug mode, we want to see the full error
      throw error;
    } else {
      // In production, log the error but don't crash
      // You might want to send this to a crash reporting service
      Logger.error('Critical error handled gracefully in production');
    }
  }
}

/// Custom error class for application-specific errors
class AppError implements Exception {
  final ErrorType type;
  final String message;
  final String userMessage;
  final bool isRetryable;
  final Map<String, dynamic>? context;

  const AppError({
    required this.type,
    required this.message,
    required this.userMessage,
    this.isRetryable = false,
    this.context,
  });

  @override
  String toString() {
    return 'AppError(type: $type, message: $message, userMessage: $userMessage, isRetryable: $isRetryable)';
  }

  /// Create a copy with updated properties
  AppError copyWith({
    ErrorType? type,
    String? message,
    String? userMessage,
    bool? isRetryable,
    Map<String, dynamic>? context,
  }) {
    return AppError(
      type: type ?? this.type,
      message: message ?? this.message,
      userMessage: userMessage ?? this.userMessage,
      isRetryable: isRetryable ?? this.isRetryable,
      context: context ?? this.context,
    );
  }
}

/// Error types for categorizing different kinds of errors
enum ErrorType {
  network,
  timeout,
  authentication,
  authorization,
  validation,
  parsing,
  server,
  conflict,
  rateLimited,
  cache,
  sync,
  unknown,
}

/// Extension to get user-friendly error type names
extension ErrorTypeExtension on ErrorType {
  String get displayName {
    switch (this) {
      case ErrorType.network:
        return 'Connection Error';
      case ErrorType.timeout:
        return 'Timeout Error';
      case ErrorType.authentication:
        return 'Authentication Error';
      case ErrorType.authorization:
        return 'Permission Error';
      case ErrorType.validation:
        return 'Validation Error';
      case ErrorType.parsing:
        return 'Data Error';
      case ErrorType.server:
        return 'Server Error';
      case ErrorType.conflict:
        return 'Conflict Error';
      case ErrorType.rateLimited:
        return 'Rate Limited';
      case ErrorType.cache:
        return 'Cache Error';
      case ErrorType.sync:
        return 'Sync Error';
      case ErrorType.unknown:
        return 'Unknown Error';
    }
  }
}