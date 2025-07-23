import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../providers/tasks_provider.dart';
import 'edit_task_screen.dart';

class TaskDetailScreen extends ConsumerWidget {
  final Task task;

  const TaskDetailScreen({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.textTheme.titleLarge?.color,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEdit(context),
            tooltip: 'Edit Task',
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      task.completed
                          ? Icons.radio_button_unchecked
                          : Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 8),
                    Text(task.completed ? 'Mark Incomplete' : 'Mark Complete'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      'Delete',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Task Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.completed
                          ? Colors.green.withOpacity(0.1)
                          : colorScheme.primary.withOpacity(0.1),
                      border: Border.all(
                        color: task.completed ? Colors.green : colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      task.completed ? Icons.check : Icons.pending_actions,
                      color: task.completed ? Colors.green : colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.completed ? 'Completed' : 'Incomplete',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: task.completed ? Colors.green : colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          task.completed
                              ? 'This task has been completed'
                              : 'This task is still pending',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Task Description Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      task.description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Priority and Due Date Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Priority
                  _buildDetailRow(
                    context,
                    'Priority',
                    task.priorityDisplayName,
                    _getPriorityIcon(task.priority),
                    _getPriorityColor(task.priority),
                  ),
                  const SizedBox(height: 12),
                  
                  // Due Date
                  _buildDetailRow(
                    context,
                    'Due Date',
                    task.dueDate != null
                        ? DateFormat('MMM d, y \'at\' h:mm a').format(task.dueDate!)
                        : 'No due date set',
                    Icons.calendar_today,
                    task.dueDate != null
                        ? (task.isOverdue && !task.completed
                            ? colorScheme.error
                            : task.isDueToday && !task.completed
                                ? Colors.orange
                                : colorScheme.onSurface.withOpacity(0.7))
                        : colorScheme.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status Indicators Card
          if (task.isOverdue || task.isDueToday || task.isDueSoon)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Indicators',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (task.isOverdue && !task.completed)
                      _buildStatusIndicator(
                        context,
                        'Overdue',
                        'This task is past its due date',
                        Icons.warning,
                        colorScheme.error,
                      ),
                    
                    if (task.isDueToday && !task.completed)
                      _buildStatusIndicator(
                        context,
                        'Due Today',
                        'This task is due today',
                        Icons.today,
                        Colors.orange,
                      ),
                    
                    if (task.isDueSoon && !task.completed && !task.isDueToday)
                      _buildStatusIndicator(
                        context,
                        'Due Soon',
                        'This task is due within the next 3 days',
                        Icons.schedule,
                        Colors.blue,
                      ),
                  ],
                ),
              ),
            ),
          
          if (task.isOverdue || task.isDueToday || task.isDueSoon)
            const SizedBox(height: 16),

          // Task Metadata Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Information',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildDetailRow(
                    context,
                    'Created',
                    DateFormat('MMM d, y \'at\' h:mm a').format(task.createdAt),
                    Icons.add_circle_outline,
                    colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildDetailRow(
                    context,
                    'Last Updated',
                    DateFormat('MMM d, y \'at\' h:mm a').format(task.updatedAt),
                    Icons.update,
                    colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildDetailRow(
                    context,
                    'Task ID',
                    task.id,
                    Icons.tag,
                    colorScheme.onSurface.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _toggleCompletion(context, ref),
                  icon: Icon(
                    task.completed
                        ? Icons.radio_button_unchecked
                        : Icons.check_circle,
                  ),
                  label: Text(
                    task.completed ? 'Mark Incomplete' : 'Mark Complete',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: task.completed
                        ? colorScheme.surface
                        : Colors.green,
                    foregroundColor: task.completed
                        ? colorScheme.onSurface
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToEdit(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Task'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Icons.priority_high;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.low:
        return Icons.keyboard_arrow_down;
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green;
    }
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditTaskScreen(task: task),
      ),
    );
  }

  Future<void> _toggleCompletion(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(tasksProvider.notifier).toggleTaskCompletion(task.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              task.completed
                  ? 'Task marked as incomplete'
                  : 'Task marked as complete',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'toggle':
        await _toggleCompletion(context, ref);
        break;
      case 'delete':
        await _showDeleteConfirmation(context, ref);
        break;
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(tasksProvider.notifier).deleteTask(task.id);
        if (context.mounted) {
          Navigator.of(context).pop(); // Go back to task list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete task: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}