import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

/// Provider for managing loading states across the app
final loadingProvider = StateNotifierProvider<LoadingNotifier, LoadingState>((ref) {
  return LoadingNotifier();
});

/// Loading state management
class LoadingNotifier extends StateNotifier<LoadingState> {
  LoadingNotifier() : super(const LoadingState());

  /// Start loading for a specific operation
  void startLoading(String operation, {String? message}) {
    Logger.debug('Starting loading for operation: $operation');
    
    final newOperations = Map<String, LoadingOperation>.from(state.operations);
    newOperations[operation] = LoadingOperation(
      name: operation,
      message: message,
      startTime: DateTime.now(),
    );
    
    state = state.copyWith(operations: newOperations);
  }

  /// Stop loading for a specific operation
  void stopLoading(String operation) {
    Logger.debug('Stopping loading for operation: $operation');
    
    final newOperations = Map<String, LoadingOperation>.from(state.operations);
    final removedOperation = newOperations.remove(operation);
    
    if (removedOperation != null) {
      final duration = DateTime.now().difference(removedOperation.startTime);
      Logger.performance(operation, duration);
    }
    
    state = state.copyWith(operations: newOperations);
  }

  /// Check if a specific operation is loading
  bool isLoading(String operation) {
    return state.operations.containsKey(operation);
  }

  /// Get loading message for a specific operation
  String? getLoadingMessage(String operation) {
    return state.operations[operation]?.message;
  }

  /// Clear all loading states
  void clearAll() {
    Logger.debug('Clearing all loading states');
    state = state.copyWith(operations: {});
  }

  /// Get all currently loading operations
  List<String> getLoadingOperations() {
    return state.operations.keys.toList();
  }
}

/// Loading state data class
class LoadingState {
  final Map<String, LoadingOperation> operations;

  const LoadingState({
    this.operations = const {},
  });

  /// Check if any operation is loading
  bool get isLoading => operations.isNotEmpty;

  /// Get count of loading operations
  int get loadingCount => operations.length;

  /// Get the first loading message (for global loading indicator)
  String? get globalLoadingMessage {
    if (operations.isEmpty) return null;
    return operations.values.first.message;
  }

  /// Copy with new values
  LoadingState copyWith({
    Map<String, LoadingOperation>? operations,
  }) {
    return LoadingState(
      operations: operations ?? this.operations,
    );
  }
}

/// Loading operation data class
class LoadingOperation {
  final String name;
  final String? message;
  final DateTime startTime;

  const LoadingOperation({
    required this.name,
    this.message,
    required this.startTime,
  });

  /// Get duration since start
  Duration get duration => DateTime.now().difference(startTime);
}

/// Provider for managing success messages
final successProvider = StateNotifierProvider<SuccessNotifier, SuccessState>((ref) {
  return SuccessNotifier();
});

/// Success state management
class SuccessNotifier extends StateNotifier<SuccessState> {
  SuccessNotifier() : super(const SuccessState());

  /// Show success message
  void showSuccess(String message, {String? title, Duration? duration}) {
    Logger.info('Showing success message: $message');
    
    final successMessage = SuccessMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
      duration: duration ?? const Duration(seconds: 3),
    );
    
    final newMessages = [...state.messages, successMessage];
    
    // Keep only last 10 messages to prevent memory issues
    final trimmedMessages = newMessages.length > 10
        ? newMessages.sublist(newMessages.length - 10)
        : newMessages;
    
    state = state.copyWith(
      messages: trimmedMessages,
      currentMessage: successMessage,
    );

    // Auto-dismiss after duration
    Future.delayed(successMessage.duration, () {
      dismissSuccess(successMessage.id);
    });
  }

  /// Dismiss success message
  void dismissSuccess(String messageId) {
    Logger.debug('Dismissing success message: $messageId');
    
    final newMessages = state.messages
        .where((message) => message.id != messageId)
        .toList();
    
    final newCurrentMessage = state.currentMessage?.id == messageId
        ? null
        : state.currentMessage;
    
    state = state.copyWith(
      messages: newMessages,
      currentMessage: newCurrentMessage,
    );
  }

  /// Clear current success message
  void clearCurrent() {
    Logger.debug('Clearing current success message');
    state = state.copyWith(currentMessage: null);
  }

  /// Clear all success messages
  void clearAll() {
    Logger.debug('Clearing all success messages');
    state = state.copyWith(
      messages: [],
      currentMessage: null,
    );
  }
}

/// Success state data class
class SuccessState {
  final List<SuccessMessage> messages;
  final SuccessMessage? currentMessage;

  const SuccessState({
    this.messages = const [],
    this.currentMessage,
  });

  /// Check if there's a current success message
  bool get hasCurrentMessage => currentMessage != null;

  /// Get current success message text
  String? get currentMessageText => currentMessage?.message;

  /// Copy with new values
  SuccessState copyWith({
    List<SuccessMessage>? messages,
    SuccessMessage? currentMessage,
  }) {
    return SuccessState(
      messages: messages ?? this.messages,
      currentMessage: currentMessage,
    );
  }
}

/// Success message data class
class SuccessMessage {
  final String id;
  final String? title;
  final String message;
  final DateTime timestamp;
  final Duration duration;

  const SuccessMessage({
    required this.id,
    this.title,
    required this.message,
    required this.timestamp,
    required this.duration,
  });
}

/// Provider for managing form submission states
final formSubmissionProvider = StateNotifierProvider.family<FormSubmissionNotifier, FormSubmissionState, String>((ref, formId) {
  return FormSubmissionNotifier(formId);
});

/// Form submission state management
class FormSubmissionNotifier extends StateNotifier<FormSubmissionState> {
  final String formId;

  FormSubmissionNotifier(this.formId) : super(const FormSubmissionState());

  /// Start form submission
  void startSubmission({String? message}) {
    Logger.debug('Starting form submission for $formId');
    state = state.copyWith(
      isSubmitting: true,
      submissionMessage: message,
      submissionStartTime: DateTime.now(),
      lastError: null,
      lastSuccess: null,
    );
  }

  /// Complete form submission successfully
  void completeSubmission({String? successMessage}) {
    Logger.info('Form submission completed successfully for $formId');
    
    final duration = state.submissionStartTime != null
        ? DateTime.now().difference(state.submissionStartTime!)
        : null;
    
    if (duration != null) {
      Logger.performance('Form submission ($formId)', duration);
    }
    
    state = state.copyWith(
      isSubmitting: false,
      submissionMessage: null,
      submissionStartTime: null,
      lastSuccess: successMessage ?? 'Form submitted successfully',
      lastSuccessTime: DateTime.now(),
    );

    // Auto-clear success message after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        clearSuccess();
      }
    });
  }

  /// Fail form submission
  void failSubmission(String errorMessage) {
    Logger.warning('Form submission failed for $formId: $errorMessage');
    
    state = state.copyWith(
      isSubmitting: false,
      submissionMessage: null,
      submissionStartTime: null,
      lastError: errorMessage,
      lastErrorTime: DateTime.now(),
    );
  }

  /// Clear success message
  void clearSuccess() {
    state = state.copyWith(
      lastSuccess: null,
      lastSuccessTime: null,
    );
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(
      lastError: null,
      lastErrorTime: null,
    );
  }

  /// Reset form submission state
  void reset() {
    Logger.debug('Resetting form submission state for $formId');
    state = const FormSubmissionState();
  }
}

/// Form submission state
class FormSubmissionState {
  final bool isSubmitting;
  final String? submissionMessage;
  final DateTime? submissionStartTime;
  final String? lastError;
  final DateTime? lastErrorTime;
  final String? lastSuccess;
  final DateTime? lastSuccessTime;

  const FormSubmissionState({
    this.isSubmitting = false,
    this.submissionMessage,
    this.submissionStartTime,
    this.lastError,
    this.lastErrorTime,
    this.lastSuccess,
    this.lastSuccessTime,
  });

  /// Check if form has recent success
  bool get hasRecentSuccess {
    if (lastSuccessTime == null) return false;
    return DateTime.now().difference(lastSuccessTime!).inSeconds < 5;
  }

  /// Check if form has recent error
  bool get hasRecentError {
    if (lastErrorTime == null) return false;
    return DateTime.now().difference(lastErrorTime!).inSeconds < 10;
  }

  /// Get submission duration if currently submitting
  Duration? get submissionDuration {
    if (submissionStartTime == null) return null;
    return DateTime.now().difference(submissionStartTime!);
  }

  /// Copy with new values
  FormSubmissionState copyWith({
    bool? isSubmitting,
    String? submissionMessage,
    DateTime? submissionStartTime,
    String? lastError,
    DateTime? lastErrorTime,
    String? lastSuccess,
    DateTime? lastSuccessTime,
  }) {
    return FormSubmissionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionMessage: submissionMessage ?? this.submissionMessage,
      submissionStartTime: submissionStartTime ?? this.submissionStartTime,
      lastError: lastError,
      lastErrorTime: lastErrorTime,
      lastSuccess: lastSuccess,
      lastSuccessTime: lastSuccessTime,
    );
  }
}

/// Provider for managing operation feedback (combines loading, success, error)
final operationFeedbackProvider = StateNotifierProvider.family<OperationFeedbackNotifier, OperationFeedbackState, String>((ref, operationId) {
  return OperationFeedbackNotifier(operationId);
});

/// Operation feedback state management
class OperationFeedbackNotifier extends StateNotifier<OperationFeedbackState> {
  final String operationId;

  OperationFeedbackNotifier(this.operationId) : super(const OperationFeedbackState());

  /// Start operation
  void start({String? message}) {
    Logger.debug('Starting operation: $operationId');
    state = state.copyWith(
      status: OperationStatus.loading,
      message: message,
      startTime: DateTime.now(),
      error: null,
    );
  }

  /// Complete operation successfully
  void success({String? message}) {
    Logger.info('Operation completed successfully: $operationId');
    
    final duration = state.startTime != null
        ? DateTime.now().difference(state.startTime!)
        : null;
    
    if (duration != null) {
      Logger.performance(operationId, duration);
    }
    
    state = state.copyWith(
      status: OperationStatus.success,
      message: message ?? 'Operation completed successfully',
      endTime: DateTime.now(),
    );
  }

  /// Fail operation
  void failure(String errorMessage) {
    Logger.warning('Operation failed: $operationId - $errorMessage');
    
    state = state.copyWith(
      status: OperationStatus.error,
      message: errorMessage,
      error: errorMessage,
      endTime: DateTime.now(),
    );
  }

  /// Reset operation state
  void reset() {
    Logger.debug('Resetting operation state: $operationId');
    state = const OperationFeedbackState();
  }
}

/// Operation feedback state
class OperationFeedbackState {
  final OperationStatus status;
  final String? message;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? error;

  const OperationFeedbackState({
    this.status = OperationStatus.idle,
    this.message,
    this.startTime,
    this.endTime,
    this.error,
  });

  /// Check if operation is loading
  bool get isLoading => status == OperationStatus.loading;

  /// Check if operation succeeded
  bool get isSuccess => status == OperationStatus.success;

  /// Check if operation failed
  bool get isError => status == OperationStatus.error;

  /// Check if operation is idle
  bool get isIdle => status == OperationStatus.idle;

  /// Get operation duration
  Duration? get duration {
    if (startTime == null) return null;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!);
  }

  /// Copy with new values
  OperationFeedbackState copyWith({
    OperationStatus? status,
    String? message,
    DateTime? startTime,
    DateTime? endTime,
    String? error,
  }) {
    return OperationFeedbackState(
      status: status ?? this.status,
      message: message ?? this.message,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      error: error,
    );
  }
}

/// Operation status enum
enum OperationStatus {
  idle,
  loading,
  success,
  error,
}