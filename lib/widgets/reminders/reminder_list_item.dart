import 'package:flutter/material.dart';
import '../../models/reminder.dart';

class ReminderListItem extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;
  final VoidCallback? onSnooze;

  const ReminderListItem({
    super.key,
    required this.reminder,
    this.onTap,
    this.onToggleComplete,
    this.onSnooze,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = reminder.isOverdue;
    final isDueToday = reminder.isDueToday;
    final isDueSoon = reminder.isDueSoon;

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with checkbox and priority indicator
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Completion checkbox
                  Checkbox(
                    value: reminder.completed,
                    onChanged: onToggleComplete != null
                        ? (_) => onToggleComplete!()
                        : null,
                  ),
                  const SizedBox(width: 8),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          reminder.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            decoration: reminder.completed
                                ? TextDecoration.lineThrough
                                : null,
                            color: reminder.completed
                                ? theme.colorScheme.onSurface.withOpacity(0.6)
                                : null,
                          ),
                        ),
                        
                        // Description (if available)
                        if (reminder.description != null && reminder.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              reminder.description!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: reminder.completed
                                    ? theme.colorScheme.onSurface.withOpacity(0.4)
                                    : theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        
                        const SizedBox(height: 8),
                        
                        // Time and status row
                        Row(
                          children: [
                            // Time indicator
                            Icon(
                              _getTimeIcon(),
                              size: 16,
                              color: _getTimeColor(theme),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              reminder.formattedScheduledTime,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _getTimeColor(theme),
                                fontWeight: isOverdue ? FontWeight.bold : null,
                              ),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // Status badge
                            _buildStatusBadge(theme),
                            
                            const Spacer(),
                            
                            // Action buttons
                            if (!reminder.completed) ...[
                              // Snooze button
                              IconButton(
                                icon: const Icon(Icons.snooze),
                                iconSize: 20,
                                onPressed: onSnooze,
                                tooltip: 'Snooze',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildStatusBadge(ThemeData theme) {
    String text;
    Color backgroundColor;
    Color textColor;

    if (reminder.completed) {
      text = 'Completed';
      backgroundColor = theme.colorScheme.primary.withOpacity(0.1);
      textColor = theme.colorScheme.primary;
    } else if (reminder.isOverdue) {
      text = 'Overdue';
      backgroundColor = theme.colorScheme.error.withOpacity(0.1);
      textColor = theme.colorScheme.error;
    } else if (reminder.isDueToday) {
      text = 'Due Today';
      backgroundColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange.shade700;
    } else if (reminder.isDueSoon) {
      text = 'Due Soon';
      backgroundColor = theme.colorScheme.primary.withOpacity(0.1);
      textColor = theme.colorScheme.primary;
    } else {
      text = reminder.timeUntilDue;
      backgroundColor = theme.colorScheme.surfaceVariant;
      textColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}