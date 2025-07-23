import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/reminder.dart';
import '../../providers/reminders_provider.dart';
import '../../utils/validators.dart';

class EditReminderScreen extends ConsumerStatefulWidget {
  final Reminder reminder;

  const EditReminderScreen({
    super.key,
    required this.reminder,
  });

  @override
  ConsumerState<EditReminderScreen> createState() => _EditReminderScreenState();
}

class _EditReminderScreenState extends ConsumerState<EditReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _isLoading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.reminder.title);
    _descriptionController = TextEditingController(text: widget.reminder.description ?? '');
    _selectedDate = widget.reminder.scheduledTime;
    _selectedTime = TimeOfDay.fromDateTime(widget.reminder.scheduledTime);
    
    // Listen for changes
    _titleController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Reminder'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
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
            // Completion status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Checkbox(
                      value: widget.reminder.completed,
                      onChanged: (value) {
                        if (value != null) {
                          _toggleCompletion(value);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.reminder.completed ? 'Completed' : 'Pending',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            widget.reminder.completed 
                                ? 'This reminder has been completed'
                                : 'This reminder is still pending',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
            
            // Title field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'What do you want to be reminded about?',
                border: OutlineInputBorder(),
              ),
              validator: Validators.required,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 200,
            ),
            
            const SizedBox(height: 16),
            
            // Description field
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add more details about this reminder',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
            ),
            
            const SizedBox(height: 24),
            
            // Date and time section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'When to remind you',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    
                    // Date picker
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Date'),
                      subtitle: Text(_formatDate(_selectedDate)),
                      onTap: _selectDate,
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    const Divider(),
                    
                    // Time picker
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Time'),
                      subtitle: Text(_selectedTime.format(context)),
                      onTap: _selectTime,
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Combined date/time display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reminder scheduled for:',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatFullDateTime(),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getTimeUntilReminder(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Quick time options (only if not completed)
            if (!widget.reminder.completed) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick reschedule options',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildQuickTimeOptions(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Notification status
            _buildNotificationStatus(),
            
            const SizedBox(height: 24),
            
            // Delete button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showDeleteConfirmation,
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Delete Reminder', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildQuickTimeOptions() {
    final now = DateTime.now();
    final quickOptions = [
      {'label': 'In 5 min', 'dateTime': now.add(const Duration(minutes: 5))},
      {'label': 'In 15 min', 'dateTime': now.add(const Duration(minutes: 15))},
      {'label': 'In 30 min', 'dateTime': now.add(const Duration(minutes: 30))},
      {'label': 'In 1 hour', 'dateTime': now.add(const Duration(hours: 1))},
      {'label': 'In 2 hours', 'dateTime': now.add(const Duration(hours: 2))},
      {'label': 'Tomorrow 9 AM', 'dateTime': DateTime(now.year, now.month, now.day + 1, 9, 0)},
    ];

    return quickOptions.map((option) {
      final dateTime = option['dateTime'] as DateTime;
      return ActionChip(
        label: Text(option['label'] as String),
        onPressed: () => _setQuickTime(dateTime),
      );
    }).toList();
  }

  Widget _buildNotificationStatus() {
    final remindersState = ref.watch(remindersProvider);
    
    if (remindersState.notificationsEnabled) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.green.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications enabled',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.green.shade700,
                      ),
                    ),
                    Text(
                      'You\'ll receive a notification at the scheduled time',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.notifications_off, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications disabled',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                    ),
                    Text(
                      'Enable notifications to receive alerts for your reminders',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(remindersProvider.notifier).requestNotificationPermissions();
                },
                child: const Text('Enable'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
        _hasChanges = true;
      });
    }
  }

  void _setQuickTime(DateTime dateTime) {
    setState(() {
      _selectedDate = dateTime;
      _selectedTime = TimeOfDay.fromDateTime(dateTime);
      _hasChanges = true;
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final selectedDay = DateTime(date.year, date.month, date.day);

    if (selectedDay == today) {
      return 'Today';
    } else if (selectedDay == tomorrow) {
      return 'Tomorrow';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatFullDateTime() {
    final dateStr = _formatDate(_selectedDate);
    final timeStr = _selectedTime.format(context);
    return '$dateStr at $timeStr';
  }

  String _getTimeUntilReminder() {
    final now = DateTime.now();
    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    
    final difference = scheduledDateTime.difference(now);
    
    if (difference.isNegative) {
      return 'This time has already passed';
    }
    
    if (difference.inDays > 0) {
      return 'In ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return 'In ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return 'In ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'In less than a minute';
    }
  }

  void _toggleCompletion(bool completed) {
    ref.read(remindersProvider.notifier).updateReminder(
      widget.reminder.id,
      {'completed': completed},
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Check if the scheduled time is in the past (only for non-completed reminders)
    if (!widget.reminder.completed && scheduledDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a future date and time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updates = <String, dynamic>{};
      
      // Check what has changed
      if (_titleController.text.trim() != widget.reminder.title) {
        updates['title'] = _titleController.text.trim();
      }
      
      final newDescription = _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim();
      if (newDescription != widget.reminder.description) {
        updates['description'] = newDescription;
      }
      
      if (scheduledDateTime != widget.reminder.scheduledTime) {
        updates['scheduled_time'] = scheduledDateTime.toIso8601String();
      }

      if (updates.isNotEmpty) {
        await ref.read(remindersProvider.notifier).updateReminder(
          widget.reminder.id,
          updates,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update reminder: $e'),
            backgroundColor: Colors.red,
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

  void _showDeleteConfirmation() {
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
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to detail screen
              Navigator.of(context).pop(); // Go back to list screen
              ref.read(remindersProvider.notifier).deleteReminder(widget.reminder.id);
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