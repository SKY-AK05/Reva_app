import 'package:flutter/material.dart';
import '../../screens/tasks/tasks_screen.dart';

class TaskSortDropdown extends StatelessWidget {
  final TaskSort currentSort;
  final ValueChanged<TaskSort> onSortChanged;

  const TaskSortDropdown({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TaskSort>(
          value: currentSort,
          onChanged: (TaskSort? newValue) {
            if (newValue != null) {
              onSortChanged(newValue);
            }
          },
          icon: Icon(
            Icons.arrow_drop_down,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
          ),
          items: TaskSort.values.map<DropdownMenuItem<TaskSort>>((TaskSort sort) {
            return DropdownMenuItem<TaskSort>(
              value: sort,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getSortIcon(sort),
                    size: 16,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(_getSortLabel(sort)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getSortLabel(TaskSort sort) {
    switch (sort) {
      case TaskSort.createdDate:
        return 'Created Date';
      case TaskSort.dueDate:
        return 'Due Date';
      case TaskSort.priority:
        return 'Priority';
      case TaskSort.alphabetical:
        return 'Alphabetical';
    }
  }

  IconData _getSortIcon(TaskSort sort) {
    switch (sort) {
      case TaskSort.createdDate:
        return Icons.access_time;
      case TaskSort.dueDate:
        return Icons.calendar_today;
      case TaskSort.priority:
        return Icons.flag;
      case TaskSort.alphabetical:
        return Icons.sort_by_alpha;
    }
  }
}