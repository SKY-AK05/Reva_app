import 'package:flutter/material.dart';
import '../../screens/tasks/tasks_screen.dart';

class TaskFilterChip extends StatelessWidget {
  final TaskFilter filter;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const TaskFilterChip({
    super.key,
    required this.filter,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilterChip(
      label: Text(_getFilterLabel()),
      selected: isSelected,
      onSelected: onSelected,
      avatar: Icon(
        _getFilterIcon(),
        size: 16,
        color: isSelected 
            ? colorScheme.onPrimary 
            : colorScheme.onSurface.withOpacity(0.7),
      ),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primary,
      checkmarkColor: colorScheme.onPrimary,
      labelStyle: TextStyle(
        color: isSelected 
            ? colorScheme.onPrimary 
            : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected 
            ? colorScheme.primary 
            : colorScheme.outline.withOpacity(0.5),
      ),
      elevation: isSelected ? 2 : 0,
      pressElevation: 4,
    );
  }

  String _getFilterLabel() {
    switch (filter) {
      case TaskFilter.all:
        return 'All';
      case TaskFilter.incomplete:
        return 'Incomplete';
      case TaskFilter.completed:
        return 'Completed';
      case TaskFilter.overdue:
        return 'Overdue';
      case TaskFilter.dueToday:
        return 'Due Today';
      case TaskFilter.highPriority:
        return 'High Priority';
    }
  }

  IconData _getFilterIcon() {
    switch (filter) {
      case TaskFilter.all:
        return Icons.list;
      case TaskFilter.incomplete:
        return Icons.pending_actions;
      case TaskFilter.completed:
        return Icons.check_circle;
      case TaskFilter.overdue:
        return Icons.schedule;
      case TaskFilter.dueToday:
        return Icons.today;
      case TaskFilter.highPriority:
        return Icons.priority_high;
    }
  }
}