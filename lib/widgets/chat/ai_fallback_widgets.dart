import 'package:flutter/material.dart';
import '../../services/chat/ai_fallback_service.dart';
import '../../core/error/error_handler.dart';

/// Widget to display AI fallback suggestions when AI fails to process a command
class AIFallbackSuggestions extends StatelessWidget {
  final List<FallbackSuggestion> suggestions;
  final Function(FallbackSuggestion) onSuggestionTapped;
  final VoidCallback? onDismiss;

  const AIFallbackSuggestions({
    super.key,
    required this.suggestions,
    required this.onSuggestionTapped,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Here are some suggestions:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...suggestions.map((suggestion) => _buildSuggestionTile(context, suggestion)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(BuildContext context, FallbackSuggestion suggestion) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onSuggestionTapped(suggestion),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _getIconForSuggestionType(suggestion.type),
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (suggestion.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        suggestion.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForSuggestionType(FallbackType type) {
    switch (type) {
      case FallbackType.createTask:
        return Icons.add_task;
      case FallbackType.viewTasks:
        return Icons.list_alt;
      case FallbackType.completeTask:
        return Icons.check_circle_outline;
      case FallbackType.logExpense:
        return Icons.receipt_long;
      case FallbackType.viewExpenses:
        return Icons.account_balance_wallet;
      case FallbackType.createReminder:
        return Icons.alarm_add;
      case FallbackType.viewReminders:
        return Icons.notifications;
      case FallbackType.manualInput:
        return Icons.edit;
    }
  }
}

/// Widget to display help message when AI fails
class AIHelpMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const AIHelpMessage({
    super.key,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.all(16),
      color: theme.colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'How to use Reva',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for manual input alternatives when AI fails
class ManualInputAlternatives extends StatelessWidget {
  final String originalMessage;
  final VoidCallback? onCreateTask;
  final VoidCallback? onLogExpense;
  final VoidCallback? onCreateReminder;
  final VoidCallback? onDismiss;

  const ManualInputAlternatives({
    super.key,
    required this.originalMessage,
    this.onCreateTask,
    this.onLogExpense,
    this.onCreateReminder,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Try manual input instead',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'I couldn\'t understand your message. You can manually:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onCreateTask != null)
                  _buildActionChip(
                    context,
                    'Create Task',
                    Icons.add_task,
                    onCreateTask!,
                  ),
                if (onLogExpense != null)
                  _buildActionChip(
                    context,
                    'Log Expense',
                    Icons.receipt_long,
                    onLogExpense!,
                  ),
                if (onCreateReminder != null)
                  _buildActionChip(
                    context,
                    'Set Reminder',
                    Icons.alarm_add,
                    onCreateReminder!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

/// Widget to display AI error with recovery options
class AIErrorRecovery extends StatelessWidget {
  final AppError error;
  final String originalMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onManualInput;
  final VoidCallback? onGetHelp;
  final VoidCallback? onDismiss;

  const AIErrorRecovery({
    super.key,
    required this.error,
    required this.originalMessage,
    this.onRetry,
    this.onManualInput,
    this.onGetHelp,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.all(16),
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.onErrorContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Something went wrong',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              error.userMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (error.isRetryable && onRetry != null)
                  _buildRecoveryButton(
                    context,
                    'Try Again',
                    Icons.refresh,
                    onRetry!,
                    isPrimary: true,
                  ),
                if (onManualInput != null)
                  _buildRecoveryButton(
                    context,
                    'Manual Input',
                    Icons.edit,
                    onManualInput!,
                  ),
                if (onGetHelp != null)
                  _buildRecoveryButton(
                    context,
                    'Get Help',
                    Icons.help_outline,
                    onGetHelp!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    
    return isPrimary
        ? ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.onErrorContainer,
              foregroundColor: theme.colorScheme.errorContainer,
            ),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.onErrorContainer,
              side: BorderSide(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          );
  }
}

/// Widget for displaying loading state with fallback options
class AILoadingWithFallback extends StatelessWidget {
  final String message;
  final Duration timeout;
  final VoidCallback? onTimeout;
  final VoidCallback? onCancel;

  const AILoadingWithFallback({
    super.key,
    required this.message,
    this.timeout = const Duration(seconds: 30),
    this.onTimeout,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Processing your request...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact suggestion chips for quick actions
class QuickActionSuggestions extends StatelessWidget {
  final List<FallbackSuggestion> suggestions;
  final Function(FallbackSuggestion) onSuggestionTapped;

  const QuickActionSuggestions({
    super.key,
    required this.suggestions,
    required this.onSuggestionTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: suggestions.take(3).map((suggestion) {
          return ActionChip(
            avatar: Icon(
              _getIconForSuggestionType(suggestion.type),
              size: 16,
            ),
            label: Text(
              suggestion.title,
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => onSuggestionTapped(suggestion),
          );
        }).toList(),
      ),
    );
  }

  IconData _getIconForSuggestionType(FallbackType type) {
    switch (type) {
      case FallbackType.createTask:
        return Icons.add_task;
      case FallbackType.viewTasks:
        return Icons.list_alt;
      case FallbackType.completeTask:
        return Icons.check_circle_outline;
      case FallbackType.logExpense:
        return Icons.receipt_long;
      case FallbackType.viewExpenses:
        return Icons.account_balance_wallet;
      case FallbackType.createReminder:
        return Icons.alarm_add;
      case FallbackType.viewReminders:
        return Icons.notifications;
      case FallbackType.manualInput:
        return Icons.edit;
    }
  }
}