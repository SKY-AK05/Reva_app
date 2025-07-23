import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/providers.dart';
import '../../services/connectivity/connectivity_service.dart';

class TaskRealtimeIndicator extends ConsumerWidget {
  const TaskRealtimeIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(tasksProvider);
    final connectivityResult = ref.watch(connectivityProvider).value;
    final isOffline = connectivityResult == ConnectivityResult.none;

    if (isOffline) {
      return _buildOfflineIndicator(context);
    }

    if (tasksState.lastSyncTime != null) {
      return _buildSyncIndicator(context, tasksState.lastSyncTime!);
    }

    return const SizedBox.shrink();
  }

  Widget _buildOfflineIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 16,
            color: Colors.orange,
          ),
          const SizedBox(width: 6),
          Text(
            'Offline',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncIndicator(BuildContext context, DateTime lastSyncTime) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final difference = now.difference(lastSyncTime);
    
    String timeText;
    Color indicatorColor;
    IconData icon;

    if (difference.inMinutes < 1) {
      timeText = 'Just now';
      indicatorColor = Colors.green;
      icon = Icons.sync;
    } else if (difference.inMinutes < 5) {
      timeText = '${difference.inMinutes}m ago';
      indicatorColor = Colors.green;
      icon = Icons.sync;
    } else if (difference.inMinutes < 30) {
      timeText = '${difference.inMinutes}m ago';
      indicatorColor = Colors.blue;
      icon = Icons.sync;
    } else {
      timeText = '${difference.inHours}h ago';
      indicatorColor = Colors.orange;
      icon = Icons.sync_problem;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: indicatorColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: indicatorColor,
          ),
          const SizedBox(width: 6),
          Text(
            'Synced $timeText',
            style: theme.textTheme.bodySmall?.copyWith(
              color: indicatorColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class TaskRealtimeNotification extends ConsumerStatefulWidget {
  const TaskRealtimeNotification({super.key});

  @override
  ConsumerState<TaskRealtimeNotification> createState() => _TaskRealtimeNotificationState();
}

class _TaskRealtimeNotificationState extends ConsumerState<TaskRealtimeNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  String? _lastNotificationMessage;
  DateTime? _lastNotificationTime;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TasksState>(tasksProvider, (previous, current) {
      if (previous != null && current.tasks.length != previous.tasks.length) {
        _showRealtimeNotification(current, previous);
      }
    });

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        if (_lastNotificationMessage == null) {
          return const SizedBox.shrink();
        }

        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sync,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lastNotificationMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: _hideNotification,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRealtimeNotification(TasksState current, TasksState previous) {
    String message;
    
    if (current.tasks.length > previous.tasks.length) {
      final newTasksCount = current.tasks.length - previous.tasks.length;
      message = newTasksCount == 1 
          ? 'New task added from web app'
          : '$newTasksCount new tasks added from web app';
    } else if (current.tasks.length < previous.tasks.length) {
      final deletedTasksCount = previous.tasks.length - current.tasks.length;
      message = deletedTasksCount == 1
          ? 'Task deleted from web app'
          : '$deletedTasksCount tasks deleted from web app';
    } else {
      // Same count, likely an update
      message = 'Task updated from web app';
    }

    setState(() {
      _lastNotificationMessage = message;
      _lastNotificationTime = DateTime.now();
    });

    _animationController.forward();

    // Auto-hide after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _lastNotificationTime != null) {
        final timeSinceNotification = DateTime.now().difference(_lastNotificationTime!);
        if (timeSinceNotification.inSeconds >= 3) {
          _hideNotification();
        }
      }
    });
  }

  void _hideNotification() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _lastNotificationMessage = null;
          _lastNotificationTime = null;
        });
      }
    });
  }
}