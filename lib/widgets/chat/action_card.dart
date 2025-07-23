import 'package:flutter/material.dart';

class ActionCard extends StatelessWidget {
  final String actionType;
  final Map<String, dynamic> actionData;

  const ActionCard({
    super.key,
    required this.actionType,
    required this.actionData,
  });

  @override
  Widget build(BuildContext context) {
    switch (actionType) {
      case 'create_task':
        return _buildTaskCreatedCard(context);
      case 'update_task':
        return _buildTaskUpdatedCard(context);
      case 'complete_task':
        return _buildTaskCompletedCard(context);
      case 'create_expense':
        return _buildExpenseCreatedCard(context);
      case 'update_expense':
        return _buildExpenseUpdatedCard(context);
      case 'create_reminder':
        return _buildReminderCreatedCard(context);
      case 'update_reminder':
        return _buildReminderUpdatedCard(context);
      default:
        return _buildGenericActionCard(context);
    }
  }

  Widget _buildTaskCreatedCard(BuildContext context) {
    final description = actionData['description'] as String? ?? 'New task';
    final priority = actionData['priority'] as String? ?? 'medium';
    final dueDate = actionData['due_date'] as String?;

    return _buildActionCardContainer(
      context,
      icon: Icons.task_alt,
      iconColor: Colors.green,
      title: 'Task Created',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildChip(context, 'Priority: ${priority.toUpperCase()}', _getPriorityColor(priority)),
              if (dueDate != null) ...[
                const SizedBox(width: 8),
                _buildChip(context, 'Due: ${_formatDate(dueDate)}', Colors.blue),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskUpdatedCard(BuildContext context) {
    final taskId = actionData['task_id'] as String? ?? '';
    final updates = actionData.entries.where((e) => e.key != 'task_id').toList();

    return _buildActionCardContainer(
      context,
      icon: Icons.edit,
      iconColor: Colors.orange,
      title: 'Task Updated',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task ID: ${taskId.substring(0, 8)}...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          ...updates.map((update) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${update.key}: ${update.value}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTaskCompletedCard(BuildContext context) {
    final taskId = actionData['task_id'] as String? ?? '';

    return _buildActionCardContainer(
      context,
      icon: Icons.check_circle,
      iconColor: Colors.green,
      title: 'Task Completed',
      content: Text(
        'Task ID: ${taskId.substring(0, 8)}...',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildExpenseCreatedCard(BuildContext context) {
    final item = actionData['item'] as String? ?? 'New expense';
    final amount = actionData['amount'] as num? ?? 0;
    final category = actionData['category'] as String? ?? 'Other';

    return _buildActionCardContainer(
      context,
      icon: Icons.receipt,
      iconColor: Colors.red,
      title: 'Expense Logged',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildChip(context, '\$${amount.toStringAsFixed(2)}', Colors.red),
              const SizedBox(width: 8),
              _buildChip(context, category, Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseUpdatedCard(BuildContext context) {
    final expenseId = actionData['expense_id'] as String? ?? '';
    final updates = actionData.entries.where((e) => e.key != 'expense_id').toList();

    return _buildActionCardContainer(
      context,
      icon: Icons.edit,
      iconColor: Colors.orange,
      title: 'Expense Updated',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expense ID: ${expenseId.substring(0, 8)}...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          ...updates.map((update) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${update.key}: ${update.value}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildReminderCreatedCard(BuildContext context) {
    final title = actionData['title'] as String? ?? 'New reminder';
    final scheduledTime = actionData['scheduled_time'] as String?;

    return _buildActionCardContainer(
      context,
      icon: Icons.notifications,
      iconColor: Colors.purple,
      title: 'Reminder Set',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (scheduledTime != null) ...[
            const SizedBox(height: 4),
            _buildChip(context, _formatDateTime(scheduledTime), Colors.purple),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderUpdatedCard(BuildContext context) {
    final reminderId = actionData['reminder_id'] as String? ?? '';
    final updates = actionData.entries.where((e) => e.key != 'reminder_id').toList();

    return _buildActionCardContainer(
      context,
      icon: Icons.edit,
      iconColor: Colors.orange,
      title: 'Reminder Updated',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reminder ID: ${reminderId.substring(0, 8)}...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          ...updates.map((update) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${update.key}: ${update.value}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildGenericActionCard(BuildContext context) {
    return _buildActionCardContainer(
      context,
      icon: Icons.info,
      iconColor: Colors.blue,
      title: 'Action: $actionType',
      content: Text(
        actionData.toString(),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildActionCardContainer(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(date.year, date.month, date.day);
      
      if (messageDate == today) {
        return 'Today';
      } else if (messageDate == today.add(const Duration(days: 1))) {
        return 'Tomorrow';
      } else {
        return '${date.month}/${date.day}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
      
      String dateStr;
      if (messageDate == today) {
        dateStr = 'Today';
      } else if (messageDate == today.add(const Duration(days: 1))) {
        dateStr = 'Tomorrow';
      } else {
        dateStr = '${dateTime.month}/${dateTime.day}';
      }
      
      final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      return '$dateStr at $timeStr';
    } catch (e) {
      return dateTimeStr;
    }
  }
}