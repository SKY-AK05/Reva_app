import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/task.dart';
import '../services/data/tasks_repository.dart';
import '../services/cache/tasks_cache_service.dart';
import '../services/sync/sync_service.dart';
import '../services/sync/realtime_service.dart';
import '../utils/logger.dart';
import 'providers.dart';

/// State class for tasks data
class TasksState {
  final List<Task> tasks;
  final bool isLoading;
  final String? error;
  final bool isOnline;
  final DateTime? lastSyncTime;

  const TasksState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.isOnline = true,
    this.lastSyncTime,
  });

  TasksState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    String? error,
    bool? isOnline,
    DateTime? lastSyncTime,
  }) {
    return TasksState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOnline: isOnline ?? this.isOnline,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

/// Tasks provider that manages task data with realtime updates
class TasksNotifier extends StateNotifier<TasksState> {
  final TasksRepository _repository;
  final TasksCacheService _cacheService;
  final SyncService _syncService;
  final RealtimeService _realtimeService;
  final Ref _ref;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<Map<String, dynamic>>? _syncEventSubscription;
  String? _currentUserId;
  bool _isDisposed = false;

  TasksNotifier(
    this._repository,
    this._cacheService,
    this._syncService,
    this._realtimeService,
    this._ref,
  ) : super(const TasksState()) {
    _initialize();
  }

  /// Initialize the provider
  Future<void> _initialize() async {
    try {
      Logger.info('Initializing TasksProvider');

      // Listen to auth state changes
      _ref.listen(currentUserProvider, (previous, next) {
        if (next?.id != _currentUserId) {
          _currentUserId = next?.id;
          if (_currentUserId != null) {
            _setupRealtimeSubscription();
            loadTasks();
          } else {
            _cleanup();
          }
        }
      });

      // Listen to connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        (connectivity) {
          final isOnline = connectivity != ConnectivityResult.none;
          state = state.copyWith(isOnline: isOnline);
          
          if (isOnline && _currentUserId != null) {
            // Sync when coming back online
            _syncTasks();
          }
        },
      );

      // Listen to sync events
      _syncEventSubscription = _syncService.syncEventStream.listen(
        (event) {
          if (event['table'] == 'tasks') {
            _handleSyncEvent(event);
          }
        },
      );

      // Load initial data if user is authenticated
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser != null) {
        _currentUserId = currentUser.id;
        await _setupRealtimeSubscription();
        await loadTasks();
      }

      Logger.info('TasksProvider initialized successfully');
    } catch (e) {
      Logger.error('Failed to initialize TasksProvider: $e');
      state = state.copyWith(error: 'Failed to initialize: $e');
    }
  }

  /// Load tasks from repository or cache
  Future<void> loadTasks({bool forceRefresh = false}) async {
    if (_isDisposed || _currentUserId == null) return;

    try {
      state = state.copyWith(isLoading: true, error: null);
      Logger.info('Loading tasks');

      List<Task> tasks;

      if (state.isOnline && (forceRefresh || await _shouldRefreshFromServer())) {
        // Load from server
        tasks = await _repository.getAll();
        
        // Cache the data
        await _cacheService.cacheTasks(
          tasks.map((task) => task.toJson()).toList(),
        );
        
        Logger.info('Loaded ${tasks.length} tasks from server');
      } else {
        // Load from cache
        final cachedData = await _cacheService.getCachedTasks(userId: _currentUserId);
        tasks = await Future.wait(cachedData.map((json) => Task.fromEncryptedJson(json)));
        
        Logger.info('Loaded  [${tasks.length} tasks from cache');
      }

      state = state.copyWith(
        tasks: tasks,
        isLoading: false,
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      Logger.error('Failed to load tasks: $e');
      
      // Try to load from cache as fallback
      try {
        final cachedData = await _cacheService.getCachedTasks(userId: _currentUserId);
        final tasks = await Future.wait(cachedData.map((json) => Task.fromEncryptedJson(json)));
        
        state = state.copyWith(
          tasks: tasks,
          isLoading: false,
          error: 'Using cached data: $e',
        );
      } catch (cacheError) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load tasks: $e',
        );
      }
    }
  }

  /// Create a new task
  Future<void> createTask({
    required String description,
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
  }) async {
    if (_isDisposed || _currentUserId == null) return;

    try {
      Logger.info('Creating new task: $description');

      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _currentUserId!,
        description: description,
        dueDate: dueDate,
        priority: priority,
        completed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (state.isOnline) {
        // Create on server
        final createdTask = await _repository.create(newTask);
        
        // Update local state
        state = state.copyWith(
          tasks: [...state.tasks, createdTask],
        );
        
        // Cache the new task
        await _cacheService.cacheTask(createdTask.toJson());
      } else {
        // Add to local state and queue for sync
        state = state.copyWith(
          tasks: [...state.tasks, newTask],
        );
        
        // Cache with unsynced flag
        await _cacheService.cacheTask({
          ...newTask.toJson(),
          'synced': 0,
        });
        
        // Queue for sync
        await _syncService.queueOperation(
          table: 'tasks',
          operation: SyncOperation.create,
          data: newTask.toJson(),
        );
      }

      Logger.info('Task created successfully');
    } catch (e) {
      Logger.error('Failed to create task: $e');
      state = state.copyWith(error: 'Failed to create task: $e');
    }
  }

  /// Update an existing task
  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    if (_isDisposed || _currentUserId == null) return;

    try {
      Logger.info('Updating task: $taskId');

      final taskIndex = state.tasks.indexWhere((task) => task.id == taskId);
      if (taskIndex == -1) {
        throw Exception('Task not found');
      }

      final currentTask = state.tasks[taskIndex];
      final updatedData = {
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (state.isOnline) {
        // Update on server
        final updatedTask = await _repository.update(taskId, updatedData);
        
        // Update local state
        final updatedTasks = [...state.tasks];
        updatedTasks[taskIndex] = updatedTask;
        state = state.copyWith(tasks: updatedTasks);
        
        // Update cache
        await _cacheService.updateCachedTask(taskId, updatedTask.toJson());
      } else {
        // Update local state
        final updatedTask = currentTask.copyWith(
          description: updates['description'] ?? currentTask.description,
          dueDate: updates['due_date'] != null 
              ? DateTime.parse(updates['due_date']) 
              : currentTask.dueDate,
          priority: updates['priority'] != null
              ? TaskPriority.values.firstWhere((p) => p.name == updates['priority'])
              : currentTask.priority,
          completed: updates['completed'] ?? currentTask.completed,
          updatedAt: DateTime.now(),
        );
        
        final updatedTasks = [...state.tasks];
        updatedTasks[taskIndex] = updatedTask;
        state = state.copyWith(tasks: updatedTasks);
        
        // Update cache with unsynced flag
        await _cacheService.updateCachedTask(taskId, {
          ...updatedTask.toJson(),
          'synced': 0,
        });
        
        // Queue for sync
        await _syncService.queueOperation(
          table: 'tasks',
          operation: SyncOperation.update,
          data: updatedData,
          recordId: taskId,
        );
      }

      Logger.info('Task updated successfully');
    } catch (e) {
      Logger.error('Failed to update task: $e');
      state = state.copyWith(error: 'Failed to update task: $e');
    }
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    if (_isDisposed || _currentUserId == null) return;

    try {
      Logger.info('Deleting task: $taskId');

      if (state.isOnline) {
        // Delete from server
        await _repository.delete(taskId);
        
        // Update local state
        state = state.copyWith(
          tasks: state.tasks.where((task) => task.id != taskId).toList(),
        );
        
        // Remove from cache
        await _cacheService.deleteCachedTask(taskId);
      } else {
        // Update local state
        state = state.copyWith(
          tasks: state.tasks.where((task) => task.id != taskId).toList(),
        );
        
        // Remove from cache
        await _cacheService.deleteCachedTask(taskId);
        
        // Queue for sync
        await _syncService.queueOperation(
          table: 'tasks',
          operation: SyncOperation.delete,
          data: {},
          recordId: taskId,
        );
      }

      Logger.info('Task deleted successfully');
    } catch (e) {
      Logger.error('Failed to delete task: $e');
      state = state.copyWith(error: 'Failed to delete task: $e');
    }
  }

  /// Toggle task completion status
  Future<void> toggleTaskCompletion(String taskId) async {
    final task = state.tasks.firstWhere((t) => t.id == taskId);
    await updateTask(taskId, {'completed': !task.completed});
  }

  /// Get tasks by completion status
  List<Task> getTasksByCompletion(bool completed) {
    return state.tasks.where((task) => task.completed == completed).toList();
  }

  /// Get tasks by priority
  List<Task> getTasksByPriority(TaskPriority priority) {
    return state.tasks.where((task) => task.priority == priority).toList();
  }

  /// Get overdue tasks
  List<Task> getOverdueTasks() {
    return state.tasks.where((task) => task.isOverdue).toList();
  }

  /// Get tasks due today
  List<Task> getTasksDueToday() {
    return state.tasks.where((task) => task.isDueToday).toList();
  }

  /// Create task from AI action
  Future<void> createTaskFromAI(Map<String, dynamic> actionData) async {
    try {
      final description = actionData['description'] as String? ?? '';
      final dueDateStr = actionData['due_date'] as String?;
      final priorityStr = actionData['priority'] as String?;

      DateTime? dueDate;
      if (dueDateStr != null) {
        try {
          dueDate = DateTime.parse(dueDateStr);
        } catch (e) {
          Logger.warning('Invalid due date from AI: $dueDateStr');
        }
      }

      TaskPriority priority = TaskPriority.medium;
      if (priorityStr != null) {
        try {
          priority = TaskPriority.values.firstWhere(
            (p) => p.name.toLowerCase() == priorityStr.toLowerCase(),
            orElse: () => TaskPriority.medium,
          );
        } catch (e) {
          Logger.warning('Invalid priority from AI: $priorityStr');
        }
      }

      await createTask(
        description: description,
        dueDate: dueDate,
        priority: priority,
      );

      Logger.info('Task created from AI: $description');
    } catch (e) {
      Logger.error('Failed to create task from AI: $e');
      throw Exception('Failed to create task from AI: $e');
    }
  }

  /// Update task from AI action
  Future<void> updateTaskFromAI(Map<String, dynamic> actionData) async {
    try {
      final taskId = actionData['task_id'] as String?;
      if (taskId == null) {
        throw Exception('Task ID is required for update');
      }

      final updates = <String, dynamic>{};
      
      if (actionData.containsKey('description')) {
        updates['description'] = actionData['description'];
      }
      
      if (actionData.containsKey('due_date')) {
        final dueDateStr = actionData['due_date'] as String?;
        if (dueDateStr != null) {
          try {
            updates['due_date'] = DateTime.parse(dueDateStr).toIso8601String();
          } catch (e) {
            Logger.warning('Invalid due date from AI: $dueDateStr');
          }
        }
      }
      
      if (actionData.containsKey('priority')) {
        final priorityStr = actionData['priority'] as String?;
        if (priorityStr != null) {
          try {
            final priority = TaskPriority.values.firstWhere(
              (p) => p.name.toLowerCase() == priorityStr.toLowerCase(),
              orElse: () => TaskPriority.medium,
            );
            updates['priority'] = priority.name;
          } catch (e) {
            Logger.warning('Invalid priority from AI: $priorityStr');
          }
        }
      }
      
      if (actionData.containsKey('completed')) {
        updates['completed'] = actionData['completed'] as bool;
      }

      if (updates.isNotEmpty) {
        await updateTask(taskId, updates);
        Logger.info('Task updated from AI: $taskId');
      }
    } catch (e) {
      Logger.error('Failed to update task from AI: $e');
      throw Exception('Failed to update task from AI: $e');
    }
  }

  /// Complete task from AI action
  Future<void> completeTaskFromAI(Map<String, dynamic> actionData) async {
    try {
      final taskId = actionData['task_id'] as String?;
      if (taskId == null) {
        throw Exception('Task ID is required for completion');
      }

      await updateTask(taskId, {'completed': true});
      Logger.info('Task completed from AI: $taskId');
    } catch (e) {
      Logger.error('Failed to complete task from AI: $e');
      throw Exception('Failed to complete task from AI: $e');
    }
  }

  /// Setup realtime subscription for tasks
  Future<void> _setupRealtimeSubscription() async {
    if (_currentUserId == null) return;

    try {
      await _realtimeService.subscribe(
        subscriptionId: 'tasks_$_currentUserId',
        config: SubscriptionConfig(
          table: 'tasks',
          filter: 'user_id=eq.$_currentUserId',
          onInsert: (payload) => _handleRealtimeInsert(payload),
          onUpdate: (payload) => _handleRealtimeUpdate(payload),
          onDelete: (payload) => _handleRealtimeDelete(payload),
        ),
      );
      
      Logger.info('Realtime subscription setup for tasks');
    } catch (e) {
      Logger.error('Failed to setup realtime subscription: $e');
    }
  }

  /// Handle realtime insert events
  void _handleRealtimeInsert(Map<String, dynamic> payload) {
    try {
      final newTask = Task.fromJson(payload);
      
      // Check if task already exists (avoid duplicates)
      if (!state.tasks.any((task) => task.id == newTask.id)) {
        state = state.copyWith(
          tasks: [...state.tasks, newTask],
        );
        
        // Cache the new task
        _cacheService.cacheTask(newTask.toJson());
        
        Logger.debug('Added new task from realtime: ${newTask.id}');
      }
    } catch (e) {
      Logger.error('Failed to handle realtime insert: $e');
    }
  }

  /// Handle realtime update events
  void _handleRealtimeUpdate(Map<String, dynamic> payload) {
    try {
      final updatedTask = Task.fromJson(payload);
      final taskIndex = state.tasks.indexWhere((task) => task.id == updatedTask.id);
      
      if (taskIndex != -1) {
        final updatedTasks = [...state.tasks];
        updatedTasks[taskIndex] = updatedTask;
        state = state.copyWith(tasks: updatedTasks);
        
        // Update cache
        _cacheService.updateCachedTask(updatedTask.id, updatedTask.toJson());
        
        Logger.debug('Updated task from realtime: ${updatedTask.id}');
      }
    } catch (e) {
      Logger.error('Failed to handle realtime update: $e');
    }
  }

  /// Handle realtime delete events
  void _handleRealtimeDelete(Map<String, dynamic> payload) {
    try {
      final taskId = payload['id'] as String;
      
      state = state.copyWith(
        tasks: state.tasks.where((task) => task.id != taskId).toList(),
      );
      
      // Remove from cache
      _cacheService.deleteCachedTask(taskId);
      
      Logger.debug('Deleted task from realtime: $taskId');
    } catch (e) {
      Logger.error('Failed to handle realtime delete: $e');
    }
  }

  /// Handle sync events
  void _handleSyncEvent(Map<String, dynamic> event) {
    final eventType = event['type'] as String;
    
    switch (eventType) {
      case 'sync_completed':
        state = state.copyWith(lastSyncTime: DateTime.now());
        break;
      case 'cache_update_required':
        if (event['table'] == 'tasks') {
          // Reload tasks when cache update is required
          loadTasks();
        }
        break;
    }
  }

  /// Sync tasks with server
  Future<void> _syncTasks() async {
    if (!state.isOnline || _currentUserId == null) return;

    try {
      Logger.info('Syncing tasks with server');
      await _syncService.sync();
    } catch (e) {
      Logger.error('Failed to sync tasks: $e');
    }
  }

  /// Check if we should refresh from server
  Future<bool> _shouldRefreshFromServer() async {
    const maxAge = Duration(minutes: 5);
    return await _cacheService.isDataStale(maxAge);
  }

  /// Cleanup resources
  void _cleanup() {
    state = const TasksState();
    
    if (_currentUserId != null) {
      _realtimeService.unsubscribe('tasks_$_currentUserId');
    }
  }

  @override
  void dispose() {
    Logger.info('Disposing TasksProvider');
    _isDisposed = true;
    
    _connectivitySubscription?.cancel();
    _syncEventSubscription?.cancel();
    
    if (_currentUserId != null) {
      _realtimeService.unsubscribe('tasks_$_currentUserId');
    }
    
    super.dispose();
  }
}

/// Provider for tasks repository
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository();
});

/// Provider for tasks cache service
final tasksCacheServiceProvider = Provider<TasksCacheService>((ref) {
  return TasksCacheService();
});

/// Main tasks provider
final tasksProvider = StateNotifierProvider<TasksNotifier, TasksState>((ref) {
  return TasksNotifier(
    ref.watch(tasksRepositoryProvider),
    ref.watch(tasksCacheServiceProvider),
    SyncService.instance,
    RealtimeService.instance,
    ref,
  );
});

/// Convenience providers for specific task queries
final incompleteTasksProvider = Provider<List<Task>>((ref) {
  final tasksState = ref.watch(tasksProvider);
  return tasksState.tasks.where((task) => !task.completed).toList();
});

final completedTasksProvider = Provider<List<Task>>((ref) {
  final tasksState = ref.watch(tasksProvider);
  return tasksState.tasks.where((task) => task.completed).toList();
});

final overdueTasksProvider = Provider<List<Task>>((ref) {
  final tasksState = ref.watch(tasksProvider);
  return tasksState.tasks.where((task) => task.isOverdue).toList();
});

final tasksDueTodayProvider = Provider<List<Task>>((ref) {
  final tasksState = ref.watch(tasksProvider);
  return tasksState.tasks.where((task) => task.isDueToday).toList();
});

final highPriorityTasksProvider = Provider<List<Task>>((ref) {
  final tasksState = ref.watch(tasksProvider);
  return tasksState.tasks.where((task) => task.priority == TaskPriority.high).toList();
});

final tasksLoadingProvider = Provider<bool>((ref) {
  final tasksState = ref.watch(tasksProvider);
  return tasksState.isLoading;
});

final tasksErrorProvider = Provider<String?>((ref) {
  final tasksState = ref.watch(tasksProvider);
  return tasksState.error;
});