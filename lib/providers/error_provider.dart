import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/error/error_handler.dart';
import '../utils/logger.dart';

/// Provider for managing global error state
final errorProvider = StateNotifierProvider<ErrorNotifier, ErrorState>((ref) {
  return ErrorNotifier();
});

/// Error state management
class ErrorNotifier extends StateNotifier<ErrorState> {
  ErrorNotifier() : super(const ErrorState());

  /// Show an error
  void showError(AppError error, {String? context}) {
    Logger.error('Showing error: ${error.userMessage}', null, null);
    state = state.copyWith(
      currentError: error,
      context: context,
      timestamp: DateTime.now(),
    );
  }

  /// Clear the current error
  void clearError() {
    Logger.debug('Clearing current error');
    state = state.copyWith(
      currentError: null,
      context: null,
    );
  }

  /// Handle an error and convert it to AppError
  void handleError(Object error, StackTrace stackTrace, {String? context}) {
    final appError = ErrorHandler.handleError(error, stackTrace, context: context);
    showError(appError, context: context);
  }

  /// Add error to history (for debugging/analytics)
  void addToHistory(AppError error, {String? context}) {
    final historyItem = ErrorHistoryItem(
      error: error,
      context: context,
      timestamp: DateTime.now(),
    );
    
    final newHistory = [...state.errorHistory, historyItem];
    
    // Keep only last 50 errors to prevent memory issues
    final trimmedHistory = newHistory.length > 50 
        ? newHistory.sublist(newHistory.length - 50)
        : newHistory;
    
    state = state.copyWith(errorHistory: trimmedHistory);
  }

  /// Get error statistics for debugging
  Map<ErrorType, int> getErrorStats() {
    final stats = <ErrorType, int>{};
    
    for (final item in state.errorHistory) {
      stats[item.error.type] = (stats[item.error.type] ?? 0) + 1;
    }
    
    return stats;
  }

  /// Clear error history
  void clearHistory() {
    Logger.debug('Clearing error history');
    state = state.copyWith(errorHistory: []);
  }
}

/// Error state data class
class ErrorState {
  final AppError? currentError;
  final String? context;
  final DateTime? timestamp;
  final List<ErrorHistoryItem> errorHistory;

  const ErrorState({
    this.currentError,
    this.context,
    this.timestamp,
    this.errorHistory = const [],
  });

  /// Check if there's a current error
  bool get hasError => currentError != null;

  /// Check if the current error is retryable
  bool get isRetryable => currentError?.isRetryable ?? false;

  /// Get the user-friendly error message
  String? get userMessage => currentError?.userMessage;

  /// Copy with new values
  ErrorState copyWith({
    AppError? currentError,
    String? context,
    DateTime? timestamp,
    List<ErrorHistoryItem>? errorHistory,
  }) {
    return ErrorState(
      currentError: currentError,
      context: context ?? this.context,
      timestamp: timestamp ?? this.timestamp,
      errorHistory: errorHistory ?? this.errorHistory,
    );
  }
}

/// Error history item for tracking past errors
class ErrorHistoryItem {
  final AppError error;
  final String? context;
  final DateTime timestamp;

  const ErrorHistoryItem({
    required this.error,
    this.context,
    required this.timestamp,
  });
}

/// Provider for network-specific errors
final networkErrorProvider = StateNotifierProvider<NetworkErrorNotifier, NetworkErrorState>((ref) {
  return NetworkErrorNotifier();
});

/// Network error state management
class NetworkErrorNotifier extends StateNotifier<NetworkErrorState> {
  NetworkErrorNotifier() : super(const NetworkErrorState());

  /// Set connection status
  void setConnectionStatus(bool isConnected) {
    if (state.isConnected != isConnected) {
      Logger.info('Connection status changed: ${isConnected ? 'connected' : 'disconnected'}');
      state = state.copyWith(
        isConnected: isConnected,
        lastConnectionChange: DateTime.now(),
      );
    }
  }

  /// Add failed request
  void addFailedRequest(String endpoint, AppError error) {
    Logger.warning('Request failed: $endpoint - ${error.userMessage}');
    
    final failedRequest = FailedRequest(
      endpoint: endpoint,
      error: error,
      timestamp: DateTime.now(),
    );
    
    final newFailedRequests = [...state.failedRequests, failedRequest];
    
    // Keep only last 20 failed requests
    final trimmedRequests = newFailedRequests.length > 20
        ? newFailedRequests.sublist(newFailedRequests.length - 20)
        : newFailedRequests;
    
    state = state.copyWith(failedRequests: trimmedRequests);
  }

  /// Clear failed requests
  void clearFailedRequests() {
    Logger.debug('Clearing failed requests');
    state = state.copyWith(failedRequests: []);
  }

  /// Get retry queue (requests that can be retried)
  List<FailedRequest> getRetryQueue() {
    return state.failedRequests
        .where((request) => request.error.isRetryable)
        .toList();
  }
}

/// Network error state
class NetworkErrorState {
  final bool isConnected;
  final DateTime? lastConnectionChange;
  final List<FailedRequest> failedRequests;

  const NetworkErrorState({
    this.isConnected = true,
    this.lastConnectionChange,
    this.failedRequests = const [],
  });

  /// Check if we're in offline mode
  bool get isOffline => !isConnected;

  /// Get count of retryable failed requests
  int get retryableRequestCount => 
      failedRequests.where((r) => r.error.isRetryable).length;

  /// Copy with new values
  NetworkErrorState copyWith({
    bool? isConnected,
    DateTime? lastConnectionChange,
    List<FailedRequest>? failedRequests,
  }) {
    return NetworkErrorState(
      isConnected: isConnected ?? this.isConnected,
      lastConnectionChange: lastConnectionChange ?? this.lastConnectionChange,
      failedRequests: failedRequests ?? this.failedRequests,
    );
  }
}

/// Failed request data class
class FailedRequest {
  final String endpoint;
  final AppError error;
  final DateTime timestamp;

  const FailedRequest({
    required this.endpoint,
    required this.error,
    required this.timestamp,
  });
}

/// Provider for form validation errors
final formErrorProvider = StateNotifierProvider.family<FormErrorNotifier, FormErrorState, String>((ref, formId) {
  return FormErrorNotifier(formId);
});

/// Form error state management
class FormErrorNotifier extends StateNotifier<FormErrorState> {
  final String formId;

  FormErrorNotifier(this.formId) : super(const FormErrorState());

  /// Set field error
  void setFieldError(String fieldName, String? error) {
    final newErrors = Map<String, String>.from(state.fieldErrors);
    
    if (error != null) {
      newErrors[fieldName] = error;
      Logger.debug('Form validation error for $formId.$fieldName: $error');
    } else {
      newErrors.remove(fieldName);
    }
    
    state = state.copyWith(fieldErrors: newErrors);
  }

  /// Set multiple field errors
  void setFieldErrors(Map<String, String> errors) {
    Logger.debug('Setting multiple form errors for $formId: ${errors.keys.join(', ')}');
    state = state.copyWith(fieldErrors: errors);
  }

  /// Clear all errors
  void clearErrors() {
    Logger.debug('Clearing all form errors for $formId');
    state = state.copyWith(fieldErrors: {});
  }

  /// Clear specific field error
  void clearFieldError(String fieldName) {
    final newErrors = Map<String, String>.from(state.fieldErrors);
    newErrors.remove(fieldName);
    state = state.copyWith(fieldErrors: newErrors);
  }

  /// Set form-level error
  void setFormError(String? error) {
    Logger.debug('Setting form-level error for $formId: $error');
    state = state.copyWith(formError: error);
  }

  /// Clear form-level error
  void clearFormError() {
    state = state.copyWith(formError: null);
  }
}

/// Form error state
class FormErrorState {
  final Map<String, String> fieldErrors;
  final String? formError;

  const FormErrorState({
    this.fieldErrors = const {},
    this.formError,
  });

  /// Check if form has any errors
  bool get hasErrors => fieldErrors.isNotEmpty || formError != null;

  /// Check if specific field has error
  bool hasFieldError(String fieldName) => fieldErrors.containsKey(fieldName);

  /// Get error for specific field
  String? getFieldError(String fieldName) => fieldErrors[fieldName];

  /// Get all error messages as a list
  List<String> get allErrors {
    final errors = <String>[];
    if (formError != null) errors.add(formError!);
    errors.addAll(fieldErrors.values);
    return errors;
  }

  /// Copy with new values
  FormErrorState copyWith({
    Map<String, String>? fieldErrors,
    String? formError,
  }) {
    return FormErrorState(
      fieldErrors: fieldErrors ?? this.fieldErrors,
      formError: formError,
    );
  }
}