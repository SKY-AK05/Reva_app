import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/reminder.dart';
import '../../providers/reminders_provider.dart';
import 'edit_reminder_screen.dart';

class ReminderDetailScreen extends ConsumerWidget {
  final Reminder reminder;

  const ReminderDetailScreen({
    super.key,
    required this.reminder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEdit(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_complete',
                child: Row(
                  children: [
                    Icon(reminder.completed ? Icons.undo : Icons.check),
                    const SizedBox(width: 8),
                    Text(reminder.completed ? 'Mark as incomplete' : 'Mark as complete'),
                  ],
                ),
              ),
              if (!reminder.completed) ...[
                const PopupMenuItem(
                  value: 'snooze',
                  child: Row(
                    children: [
                      Icon(Icons.snooze),
                      SizedBox(width: 8),
                      Text('Snooze'),
                    ],
                  ),
                ),
              ],
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            _buildStatusCard(theme),
            
            const SizedBox(height: 16),
            
            // Title and description
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: reminder.completed,
                          onChanged: (_) => _toggleComplete(ref),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reminder.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  decoration: reminder.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (reminder.description != null && reminder.description!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  reminder.description!,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                                    decoration: reminder.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Time details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scheduled Time',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    
                    ListTile(
                      leading: Icon(
                        _getTimeIcon(),
                        color: _getTimeColor(theme),
                      ),
                      title: Text(reminder.formattedScheduledTime),
                      subtitle: Text(reminder.timeUntilDue),
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    if (!reminder.completed && reminder.isOverdue) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This reminder is overdue',
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Metadata
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Details',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    
                    _buildDetailRow(
                      'Created',
                      _formatDateTime(reminder.createdAt),
                      Icons.add_circle_outline,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    _buildDetailRow(
                      'Status',
                      reminder.completed ? 'Completed' : 'Pending',
                      reminder.completed ? Icons.check_circle : Icons.schedule,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            if (!reminder.completed) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showSnoozeOptions(context, ref),
                  icon: const Icon(Icons.snooze),
                  label: const Text('Snooze Reminder'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _toggleComplete(ref),
                icon: Icon(reminder.completed ? Icons.undo : Icons.check),
                label: Text(reminder.completed ? 'Mark as Incomplete' : 'Mark as Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: reminder.completed 
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String status;

    if (reminder.completed) {
      backgroundColor = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
      icon = Icons.check_circle;
      status = 'Completed';
    } else if (reminder.isOverdue) {
      backgroundColor = theme.colorScheme.errorContainer;
      textColor = theme.colorScheme.onErrorContainer;
      icon = Icons.warning;
      status = 'Overdue';
    } else if (reminder.isDueToday) {
      backgroundColor = Colors.orange.shade100;
      textColor = Colors.orange.shade800;
      icon = Icons.today;
      status = 'Due Today';
    } else if (reminder.isDueSoon) {
      backgroundColor = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
      icon = Icons.schedule;
      status = 'Due Soon';
    } else {
      backgroundColor = theme.colorScheme.surfaceVariant;
      textColor = theme.colorScheme.onSurfaceVariant;
      icon = Icons.schedule;
      status = 'Upcoming';
    }

    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    reminder.timeUntilDue,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  IconData _getTimeIcon() {
    if (reminder.completed) return Icons.check_circle;
    if (reminder.isOverdue) return Icons.warning;
    if (reminder.isDueToday) return Icons.today;
    if (reminder.isDueSoon) return Icons.schedule;
    return Icons.schedule;
  }

  Color _getTimeColor(ThemeData theme) {
    if (reminder.completed) return theme.colorScheme.primary;
    if (reminder.isOverdue) return theme.colorScheme.error;
    if (reminder.isDueToday) return Colors.orange;
    if (reminder.isDueSoon) return theme.colorScheme.primary;
    return theme.colorScheme.onSurface.withOpacity(0.6);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditReminderScreen(reminder: reminder),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'toggle_complete':
        _toggleComplete(ref);
        break;
      case 'snooze':
        _showSnoozeOptions(context, ref);
        break;
      case 'delete':
        _showDeleteConfirmation(context, ref);
        break;
    }
  }

  void _toggleComplete(WidgetRef ref) {
    if (reminder.completed) {
      ref.read(remindersProvider.notifier).updateReminder(
        reminder.id,
        {'completed': false},
      );
    } else {
      ref.read(remindersProvider.notifier).markReminderCompleted(reminder.id);
    }
  }

  void _showSnoozeOptions(BuildContext context, WidgetRef ref) {
    if (reminder.completed) return;

    final snoozeOptions = [
      {'label': '5 minutes', 'duration': const Duration(minutes: 5)},
      {'label': '15 minutes', 'duration': const Duration(minutes: 15)},
      {'label': '30 minutes', 'duration': const Duration(minutes: 30)},
      {'label': '1 hour', 'duration': const Duration(hours: 1)},
      {'label': '2 hours', 'duration': const Duration(hours: 2)},
      {'label': 'Tomorrow', 'duration': const Duration(days: 1)},
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Snooze reminder',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...snoozeOptions.map((option) {
              return ListTile(
                title: Text(option['label'] as String),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(remindersProvider.notifier).snoozeReminder(
                    reminder.id,
                    option['duration'] as Duration,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reminder snoozed for ${option['label']}'),
                    ),
                  );
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to list
              ref.read(remindersProvider.notifier).deleteReminder(reminder.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reminder deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}