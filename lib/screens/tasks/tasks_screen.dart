import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../providers/tasks_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/tasks/task_list_item.dart';
import '../../widgets/tasks/task_filter_chip.dart';
import '../../widgets/tasks/task_sort_dropdown.dart';
import '../../widgets/tasks/task_realtime_indicator.dart';
import '../../widgets/common/offline_state_wrapper.dart';
import '../../widgets/common/offline_indicator.dart';
import '../../widgets/performance/optimized_list_view.dart';
import '../../core/theme/app_theme.dart';
import '../../services/performance/performance_monitor.dart';

enum TaskFilter { all, incomplete, completed, overdue, dueToday, highPriority }
enum TaskSort { createdDate, dueDate, priority, alphabetical }

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final ScrollController _scrollController = ScrollController();
  TaskFilter _currentFilter = TaskFilter.all;
  TaskSort _currentSort = TaskSort.createdDate;
  bool _sortAscending = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Start performance monitoring for this screen
    PerformanceMonitor.startScreenLoad('TasksScreen');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Infinite scrolling logic can be added here if needed
    // For now, we'll load all tasks at once
  }

  Future<void> _onRefresh() async {
    await ref.read(tasksProvider.notifier).loadTasks(forceRefresh: true);
  }

  List<Task> _getFilteredTasks(List<Task> tasks) {
    List<Task> filtered = List.of(tasks);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((task) => task.description
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply status filter
    switch (_currentFilter) {
      case TaskFilter.all:
        break;
      case TaskFilter.incomplete:
        filtered = filtered.where((task) => !task.completed).toList();
        break;
      case TaskFilter.completed:
        filtered = filtered.where((task) => task.completed).toList();
        break;
      case TaskFilter.overdue:
        filtered = filtered.where((task) => task.isOverdue).toList();
        break;
      case TaskFilter.dueToday:
        filtered = filtered.where((task) => task.isDueToday).toList();
        break;
      case TaskFilter.highPriority:
        filtered = filtered
            .where((task) => task.priority == TaskPriority.high)
            .toList();
        break;
    }

    // Apply sorting
    switch (_currentSort) {
      case TaskSort.createdDate:
        filtered.sort((a, b) => _sortAscending
            ? a.createdAt.compareTo(b.createdAt)
            : b.createdAt.compareTo(a.createdAt));
        break;
      case TaskSort.dueDate:
        filtered.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return _sortAscending
              ? a.dueDate!.compareTo(b.dueDate!)
              : b.dueDate!.compareTo(a.dueDate!);
        });
        break;
      case TaskSort.priority:
        filtered.sort((a, b) {
          final priorityOrder = {
            TaskPriority.high: 3,
            TaskPriority.medium: 2,
            TaskPriority.low: 1,
          };
          final aValue = priorityOrder[a.priority]!;
          final bValue = priorityOrder[b.priority]!;
          return _sortAscending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        });
        break;
      case TaskSort.alphabetical:
        filtered.sort((a, b) => _sortAscending
            ? a.description.compareTo(b.description)
            : b.description.compareTo(a.description));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksProvider);
    final filteredTasks = _getFilteredTasks(tasksState.tasks);
    
    // Complete screen load tracking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerformanceMonitor.completeScreenLoad('TasksScreen');
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        actions: [
          const ConnectivityStatusChip(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _onRefresh();
                  break;
                case 'clear_completed':
                  _showClearCompletedDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_completed',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Completed'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: OfflineStateWrapper(
        onRetry: _onRefresh,
        offlineMessage: 'Tasks are read-only while offline. Connect to create or edit tasks.',
        child: Stack(
          children: [
            Column(
              children: [
                // Offline Indicator
                const OfflineIndicator(),
                // Realtime Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const TaskRealtimeIndicator(),
                      const Spacer(),
                      if (tasksState.isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                // Filter and Sort Controls
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: TaskFilter.values.map((filter) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: TaskFilterChip(
                                filter: filter,
                                isSelected: _currentFilter == filter,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _currentFilter = filter;
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Sort Controls
                      Row(
                        children: [
                          Expanded(
                            child: TaskSortDropdown(
                              currentSort: _currentSort,
                              onSortChanged: (sort) {
                                setState(() {
                                  _currentSort = sort;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _sortAscending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                            ),
                            onPressed: () {
                              setState(() {
                                _sortAscending = !_sortAscending;
                              });
                            },
                            tooltip: _sortAscending ? 'Ascending' : 'Descending',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Task List
                Expanded(
                  child: _buildOfflineAwareTaskList(tasksState, filteredTasks),
                ),
              ],
            ),
            // Realtime Notification Overlay
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TaskRealtimeNotification(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildOfflineAwareFAB(),
    );
  }

  Widget _buildTaskList(TasksState tasksState, List<Task> filteredTasks) {
    if (tasksState.isLoading && filteredTasks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (tasksState.error != null && filteredTasks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading tasks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                tasksState.error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _onRefresh,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredTasks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getEmptyStateIcon(),
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _getEmptyStateMessage(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _getEmptyStateSubtitle(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filteredTasks.length,
        itemBuilder: (context, index) {
          final task = filteredTasks[index];
          return TaskListItem(
            task: task,
            onToggleComplete: () => _toggleTaskCompletion(task),
            onTap: () => _navigateToTaskDetail(task),
            onEdit: () => _navigateToEditTask(task),
            onDelete: () => _showDeleteConfirmation(task),
          );
        },
      ),
    );
  }

  IconData _getEmptyStateIcon() {
    switch (_currentFilter) {
      case TaskFilter.all:
        return Icons.task_alt;
      case TaskFilter.incomplete:
        return Icons.pending_actions;
      case TaskFilter.completed:
        return Icons.check_circle_outline;
      case TaskFilter.overdue:
        return Icons.schedule;
      case TaskFilter.dueToday:
        return Icons.today;
      case TaskFilter.highPriority:
        return Icons.priority_high;
    }
  }

  String _getEmptyStateMessage() {
    switch (_currentFilter) {
      case TaskFilter.all:
        return 'No tasks yet';
      case TaskFilter.incomplete:
        return 'No incomplete tasks';
      case TaskFilter.completed:
        return 'No completed tasks';
      case TaskFilter.overdue:
        return 'No overdue tasks';
      case TaskFilter.dueToday:
        return 'No tasks due today';
      case TaskFilter.highPriority:
        return 'No high priority tasks';
    }
  }

  String _getEmptyStateSubtitle() {
    switch (_currentFilter) {
      case TaskFilter.all:
        return 'Create your first task to get started';
      case TaskFilter.incomplete:
        return 'Great job! All tasks are completed';
      case TaskFilter.completed:
        return 'Complete some tasks to see them here';
      case TaskFilter.overdue:
        return 'You\'re all caught up!';
      case TaskFilter.dueToday:
        return 'No tasks scheduled for today';
      case TaskFilter.highPriority:
        return 'No urgent tasks at the moment';
    }
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    try {
      await ref.read(tasksProvider.notifier).toggleTaskCompletion(task.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _navigateToTaskDetail(Task task) {
    Navigator.of(context).pushNamed('/tasks/detail', arguments: task);
  }

  void _navigateToEditTask(Task task) {
    Navigator.of(context).pushNamed('/tasks/edit', arguments: task);
  }

  Future<void> _showDeleteConfirmation(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(tasksProvider.notifier).deleteTask(task.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete task: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Tasks'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Enter search query...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearCompletedDialog() async {
    final tasksState = ref.read(tasksProvider);
    final completedTasks = tasksState.tasks.where((task) => task.completed).toList();
    
    if (completedTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No completed tasks to clear')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Completed Tasks'),
        content: Text(
          'Are you sure you want to delete all ${completedTasks.length} completed tasks? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final task in completedTasks) {
          await ref.read(tasksProvider.notifier).deleteTask(task.id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cleared ${completedTasks.length} completed tasks'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear completed tasks: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildOfflineAwareTaskList(TasksState tasksState, List<Task> filteredTasks) {
    if (tasksState.isLoading && filteredTasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tasksState.error != null && filteredTasks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading tasks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                tasksState.error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _onRefresh,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredTasks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getEmptyStateIcon(),
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _getEmptyStateMessage(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _getEmptyStateSubtitle(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: OptimizedListView<Task>(
        items: filteredTasks,
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, task, index) {
          return TaskListItem(
            task: task,
            onToggleComplete: () => _toggleTaskCompletion(task),
            onTap: () => _navigateToTaskDetail(task),
            onEdit: () => _navigateToEditTask(task),
            onDelete: () => _showDeleteConfirmation(task),
          );
        },
      ),
    );
  }

  Widget _buildOfflineAwareFAB() {
    return Consumer(
      builder: (context, ref, child) {
        final connectivityStatus = ref.watch(connectivityStatusProvider);
        
        return connectivityStatus.when(
          data: (isConnected) {
            return FloatingActionButton(
              onPressed: isConnected 
                  ? () => Navigator.of(context).pushNamed('/tasks/add')
                  : () => _showOfflineMessage('Cannot create tasks while offline'),
              backgroundColor: isConnected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              child: Icon(
                Icons.add,
                color: isConnected 
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            );
          },
          loading: () => FloatingActionButton(
            onPressed: () => Navigator.of(context).pushNamed('/tasks/add'),
            child: const Icon(Icons.add),
          ),
          error: (_, __) => FloatingActionButton(
            onPressed: () => Navigator.of(context).pushNamed('/tasks/add'),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showOfflineMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Theme.of(context).colorScheme.onError,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}