import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/chat_provider.dart';

class AITaskSummary extends ConsumerWidget {
  const AITaskSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(tasksProvider);
    final chatState = ref.watch(chatProvider);
    
    // Get recently created tasks (within last 24 hours)
    final recentTasks = tasksState.tasks
        .where((task) => 
            DateTime.now().difference(task.createdAt).inHours < 24)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Get recent chat messages with task actions
    final recentTaskMessages = chatState.messages
        .where((message) => 
            message.hasActionMetadata && 
            (message.actionType == 'create_task' || 
             message.actionType == 'update_task' ||
             message.actionType == 'complete_task'))
        .take(3)
        .toList();

    if (recentTasks.isEmpty && recentTaskMessages.isEmpty) {
      return const SizedBox.shrink();
    }

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
                  Icons.smart_toy,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Task Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showFullActivity(context, ref),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Recent Tasks
            if (recentTasks.isNotEmpty) ...[
              Text(
                'Recently Created Tasks',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              ...recentTasks.take(3).map((task) => _buildTaskItem(context, task)),
            ],
            
            // Recent Chat Actions
            if (recentTaskMessages.isNotEmpty) ...[
              if (recentTasks.isNotEmpty) const SizedBox(height: 16),
              Text(
                'Recent AI Actions',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              ...recentTaskMessages.map((message) => _buildChatActionItem(context, message)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, Task task) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getPriorityColor(task.priority),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Created ${_formatRelativeTime(task.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (task.completed)
            Icon(
              Icons.check_circle,
              size: 16,
              color: Colors.green,
            ),
        ],
      ),
    );
  }

  Widget _buildChatActionItem(BuildContext context, message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    String actionText;
    IconData actionIcon;
    Color actionColor;
    
    switch (message.actionType) {
      case 'create_task':
        actionText = 'Created task';
        actionIcon = Icons.add_task;
        actionColor = Colors.green;
        break;
      case 'update_task':
        actionText = 'Updated task';
        actionIcon = Icons.edit;
        actionColor = Colors.blue;
        break;
      case 'complete_task':
        actionText = 'Completed task';
        actionIcon = Icons.check_circle;
        actionColor = Colors.orange;
        break;
      default:
        actionText = 'Task action';
        actionIcon = Icons.task_alt;
        actionColor = colorScheme.primary;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: actionColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: actionColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            actionIcon,
            size: 16,
            color: actionColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actionText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: actionColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRelativeTime(message.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: actionColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  void _showFullActivity(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => AITaskActivitySheet(
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class AITaskActivitySheet extends ConsumerWidget {
  final ScrollController scrollController;

  const AITaskActivitySheet({
    super.key,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(tasksProvider);
    final chatState = ref.watch(chatProvider);
    
    // Get all tasks created in the last week
    final recentTasks = tasksState.tasks
        .where((task) => 
            DateTime.now().difference(task.createdAt).inDays < 7)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Get all chat messages with task actions
    final taskMessages = chatState.messages
        .where((message) => 
            message.hasActionMetadata && 
            (message.actionType == 'create_task' || 
             message.actionType == 'update_task' ||
             message.actionType == 'complete_task'))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Title
          Text(
            'AI Task Activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tasks and actions from the last 7 days',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          
          // Content
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                // Statistics
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Tasks Created',
                        recentTasks.length.toString(),
                        Icons.add_task,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'AI Actions',
                        taskMessages.length.toString(),
                        Icons.smart_toy,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Recent Tasks
                if (recentTasks.isNotEmpty) ...[
                  Text(
                    'Recent Tasks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...recentTasks.map((task) => _buildDetailedTaskItem(context, task)),
                ],
                
                // Recent Actions
                if (taskMessages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Recent AI Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...taskMessages.map((message) => _buildDetailedActionItem(context, message)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedTaskItem(BuildContext context, Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getPriorityColor(task.priority).withOpacity(0.2),
          child: Icon(
            task.completed ? Icons.check_circle : Icons.task_alt,
            color: _getPriorityColor(task.priority),
          ),
        ),
        title: Text(
          task.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Created ${DateFormat('MMM d, h:mm a').format(task.createdAt)}'),
            Row(
              children: [
                Text('Priority: ${task.priorityDisplayName}'),
                if (task.dueDate != null) ...[
                  const Text(' • '),
                  Text('Due: ${DateFormat('MMM d').format(task.dueDate!)}'),
                ],
              ],
            ),
          ],
        ),
        trailing: task.completed
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
      ),
    );
  }

  Widget _buildDetailedActionItem(BuildContext context, message) {
    String actionText;
    IconData actionIcon;
    Color actionColor;
    
    switch (message.actionType) {
      case 'create_task':
        actionText = 'Created new task';
        actionIcon = Icons.add_task;
        actionColor = Colors.green;
        break;
      case 'update_task':
        actionText = 'Updated task';
        actionIcon = Icons.edit;
        actionColor = Colors.blue;
        break;
      case 'complete_task':
        actionText = 'Completed task';
        actionIcon = Icons.check_circle;
        actionColor = Colors.orange;
        break;
      default:
        actionText = 'Task action';
        actionIcon = Icons.task_alt;
        actionColor = Theme.of(context).colorScheme.primary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: actionColor.withOpacity(0.2),
          child: Icon(actionIcon, color: actionColor),
        ),
        title: Text(actionText),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM d, h:mm a').format(message.timestamp)),
            if (message.content.isNotEmpty)
              Text(
                message.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
          ],
        ),
      ),
    );
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
}