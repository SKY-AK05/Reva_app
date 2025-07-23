import 'package:flutter/material.dart';

class ExpenseFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;
  final bool isSelected;

  const ExpenseFilterChip({
    super.key,
    required this.label,
    this.onDeleted,
    this.onTap,
    this.isSelected = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Chip(
      label: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isSelected 
              ? theme.colorScheme.onPrimary 
              : theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: isSelected 
          ? theme.colorScheme.primary 
          : theme.colorScheme.surface,
      side: BorderSide(
        color: isSelected 
            ? theme.colorScheme.primary 
            : theme.colorScheme.outline.withOpacity(0.5),
        width: 1,
      ),
      deleteIcon: onDeleted != null 
          ? Icon(
              Icons.close,
              size: 16,
              color: isSelected 
                  ? theme.colorScheme.onPrimary 
                  : theme.colorScheme.onSurface,
            )
          : null,
      onDeleted: onDeleted,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}