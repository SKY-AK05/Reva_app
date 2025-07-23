import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/task.dart';
import '../../providers/tasks_provider.dart';
import '../../utils/validators.dart';

class EditTaskScreen extends ConsumerStatefulWidget {
  final Task task;

  const EditTaskScreen({
    super.key,
    required this.task,
  });

  @override
  ConsumerState<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends ConsumerState<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  final _descriptionFocusNode = FocusNode();
  
  DateTime? _selectedDueDate;
  TaskPriority _selectedPriority = TaskPriority.medium;
  bool _isCompleted = false;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    _descriptionController = TextEditingController(text: widget.task.description);
    _selectedDueDate = widget.task.dueDate;
    _selectedPriority = widget.task.priority;
    _isCompleted = widget.task.completed;

    // Listen for changes
    _descriptionController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)), // Allow past dates for editing
      lastDate: now.add(const Duration(days: 365 * 2)), // 2 years from now
      helpText: 'Select due date',
      cancelText: 'Clear',
      confirmText: 'Set Date',
    );

    if (selectedDate != null) {
      // Also allow time selection
      if (mounted) {
        final selectedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_selectedDueDate ?? now),
          helpText: 'Select due time (optional)',
        );

        if (selectedTime != null) {
          setState(() {
            _selectedDueDate = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );
            _hasChanges = true;
          });
        } else {
          setState(() {
            _selectedDueDate = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              23,
              59,
            );
            _hasChanges = true;
          });
        }
      }
    } else {
      // Clear date if user pressed "Clear"
      setState(() {
        _selectedDueDate = null;
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updates = <String, dynamic>{};
      
      if (_descriptionController.text.trim() != widget.task.description) {
        updates['description'] = _descriptionController.text.trim();
      }
      
      if (_selectedDueDate != widget.task.dueDate) {
        updates['due_date'] = _selectedDueDate?.toIso8601String();
      }
      
      if (_selectedPriority != widget.task.priority) {
        updates['priority'] = _selectedPriority.name;
      }
      
      if (_isCompleted != widget.task.completed) {
        updates['completed'] = _isCompleted;
      }

      if (updates.isNotEmpty) {
        await ref.read(tasksProvider.notifier).updateTask(widget.task.id, updates);
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Task'),
          elevation: 0,
          backgroundColor: theme.scaffoldBackgroundColor,
          foregroundColor: theme.textTheme.titleLarge?.color,
          actions: [
            TextButton(
              onPressed: _isLoading ? null : _saveTask,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Task Status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task Status',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: Text(_isCompleted ? 'Completed' : 'Incomplete'),
                        subtitle: Text(
                          _isCompleted 
                              ? 'This task has been completed'
                              : 'This task is still pending',
                        ),
                        value: _isCompleted,
                        onChanged: (value) {
                          setState(() {
                            _isCompleted = value;
                            _hasChanges = true;
                          });
                        },
                        secondary: Icon(
                          _isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: _isCompleted ? Colors.green : null,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Task Description
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task Description',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionController,
                        focusNode: _descriptionFocusNode,
                        decoration: const InputDecoration(
                          hintText: 'What needs to be done?',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.task_alt),
                        ),
                        maxLines: 3,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        validator: Validators.requiredValidator('Task description is required'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Due Date
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Due Date',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _selectDueDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedDueDate != null
                                      ? DateFormat('MMM d, y \'at\' h:mm a')
                                          .format(_selectedDueDate!)
                                      : 'No due date set (optional)',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: _selectedDueDate != null
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              if (_selectedDueDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _selectedDueDate = null;
                                      _hasChanges = true;
                                    });
                                  },
                                  tooltip: 'Clear due date',
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Priority Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Priority',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...TaskPriority.values.map((priority) {
                        return RadioListTile<TaskPriority>(
                          title: Row(
                            children: [
                              Icon(
                                _getPriorityIcon(priority),
                                color: _getPriorityColor(priority),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(_getPriorityDisplayName(priority)),
                            ],
                          ),
                          subtitle: Text(_getPriorityDescription(priority)),
                          value: priority,
                          groupValue: _selectedPriority,
                          onChanged: (TaskPriority? value) {
                            if (value != null) {
                              setState(() {
                                _selectedPriority = value;
                                _hasChanges = true;
                              });
                            }
                          },
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Task Metadata
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
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Created',
                        DateFormat('MMM d, y \'at\' h:mm a').format(widget.task.createdAt),
                        Icons.add_circle_outline,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Last Updated',
                        DateFormat('MMM d, y \'at\' h:mm a').format(widget.task.updatedAt),
                        Icons.update,
                      ),
                      if (widget.task.isOverdue && !_isCompleted) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Status',
                          'Overdue',
                          Icons.warning,
                          color: colorScheme.error,
                        ),
                      ],
                      if (widget.task.isDueToday && !_isCompleted) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Status',
                          'Due Today',
                          Icons.today,
                          color: Colors.orange,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button (Alternative to AppBar action)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTask,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
            ),
          ),
        ),
      ],
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

  String _getPriorityDisplayName(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 'High Priority';
      case TaskPriority.medium:
        return 'Medium Priority';
      case TaskPriority.low:
        return 'Low Priority';
    }
  }

  String _getPriorityDescription(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 'Urgent and important tasks';
      case TaskPriority.medium:
        return 'Standard priority tasks';
      case TaskPriority.low:
        return 'Nice to have tasks';
    }
  }
}