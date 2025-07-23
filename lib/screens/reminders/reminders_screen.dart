import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reminders_provider.dart';
import '../../models/reminder.dart';
import '../../widgets/reminders/reminder_list_item.dart';
import 'add_reminder_screen.dart';
import 'reminder_detail_screen.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remindersState = ref.watch(remindersProvider);
    final upcomingReminders = ref.watch(upcomingRemindersProvider);
    final overdueReminders = ref.watch(overdueRemindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            icon: Icon(_showCompleted ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showCompleted = !_showCompleted;
              });
            },
            tooltip: _showCompleted ? 'Hide completed' : 'Show completed',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(remindersProvider.notifier).loadReminders(forceRefresh: true);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Overdue',
              icon: Badge(
                label: Text('${overdueReminders.length}'),
                isLabelVisible: overdueReminders.isNotEmpty,
                child: const Icon(Icons.warning),
              ),
            ),
            Tab(
              text: 'Upcoming',
              icon: Badge(
                label: Text('${upcomingReminders.length}'),
                isLabelVisible: upcomingReminders.isNotEmpty,
                child: const Icon(Icons.schedule),
              ),
            ),
            const Tab(
              text: 'All',
              icon: Icon(Icons.list),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Notification status banner
          if (!remindersState.notificationsEnabled)
            _buildNotificationBanner(),
          
          // Error banner
          if (remindersState.error != null)
            _buildErrorBanner(remindersState.error!),
          
          // Main content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRemindersList(
                  reminders: overdueReminders,
                  emptyMessage: 'No overdue reminders',
                  emptyIcon: Icons.check_circle_outline,
                ),
                _buildRemindersList(
                  reminders: upcomingReminders,
                  emptyMessage: 'No upcoming reminders',
                  emptyIcon: Icons.schedule,
                ),
                _buildRemindersList(
                  reminders: _getFilteredReminders(remindersState.reminders),
                  emptyMessage: 'No reminders yet',
                  emptyIcon: Icons.notifications_none,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddReminder(),
        child: const Icon(Icons.add),
        tooltip: 'Add Reminder',
      ),
    );
  }

  Widget _buildNotificationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.orange.shade100,
      child: Row(
        children: [
          Icon(Icons.notifications_off, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Notifications are disabled. Enable them to receive reminder alerts.',
              style: TextStyle(color: Colors.orange.shade700),
            ),
          ),
          TextButton(
            onPressed: () => _showNotificationSettings(),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.red.shade100,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              // Clear error by reloading
              ref.read(remindersProvider.notifier).loadReminders();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersList({
    required List<Reminder> reminders,
    required String emptyMessage,
    required IconData emptyIcon,
  }) {
    final remindersState = ref.watch(remindersProvider);

    if (remindersState.isLoading && reminders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first reminder',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(remindersProvider.notifier).loadReminders(forceRefresh: true);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reminders.length,
        itemBuilder: (context, index) {
          final reminder = reminders[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ReminderListItem(
              reminder: reminder,
              onTap: () => _navigateToReminderDetail(reminder),
              onToggleComplete: () => _toggleReminderComplete(reminder),
              onSnooze: () => _showSnoozeOptions(reminder),
            ),
          );
        },
      ),
    );
  }

  List<Reminder> _getFilteredReminders(List<Reminder> reminders) {
    if (_showCompleted) {
      return reminders;
    }
    return reminders.where((reminder) => !reminder.completed).toList();
  }

  void _navigateToAddReminder() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddReminderScreen(),
      ),
    );
  }

  void _navigateToReminderDetail(Reminder reminder) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReminderDetailScreen(reminder: reminder),
      ),
    );
  }

  void _toggleReminderComplete(Reminder reminder) {
    if (reminder.completed) {
      // Reopen reminder
      ref.read(remindersProvider.notifier).updateReminder(
        reminder.id,
        {'completed': false},
      );
    } else {
      // Mark as completed
      ref.read(remindersProvider.notifier).markReminderCompleted(reminder.id);
    }
  }

  void _showSnoozeOptions(Reminder reminder) {
    if (reminder.completed) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => _buildSnoozeBottomSheet(reminder),
    );
  }

  Widget _buildSnoozeBottomSheet(Reminder reminder) {
    final snoozeOptions = [
      {'label': '5 minutes', 'duration': const Duration(minutes: 5)},
      {'label': '15 minutes', 'duration': const Duration(minutes: 15)},
      {'label': '30 minutes', 'duration': const Duration(minutes: 30)},
      {'label': '1 hour', 'duration': const Duration(hours: 1)},
      {'label': '2 hours', 'duration': const Duration(hours: 2)},
      {'label': 'Tomorrow', 'duration': const Duration(days: 1)},
    ];

    return Container(
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
    );
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Notifications'),
        content: Text(
          ref.read(notificationServiceProvider).getPermissionStatusMessage(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(remindersProvider.notifier).requestNotificationPermissions();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}