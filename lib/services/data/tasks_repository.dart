import '../../models/task.dart';
import '../../utils/logger.dart';
import 'base_repository.dart';

class TasksRepository extends BaseRepository<Task> {
  @override
  String get tableName => 'tasks';

  @override
  Task fromJson(Map<String, dynamic> json) => Task.fromJson(json);

  @override
  Map<String, dynamic> toJson(Task item) => item.toJson();

  /// Get tasks by completion status
  Future<List<Task>> getByCompletionStatus(bool completed) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching ${completed ? 'completed' : 'incomplete'} tasks');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .eq('completed', completed)
          .order('created_at', ascending: false);
      
      final tasks = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${tasks.length} ${completed ? 'completed' : 'incomplete'} tasks');
      return tasks;
    } catch (e) {
      Logger.error('Failed to fetch tasks by completion status: $e');
      throw handleError(e);
    }
  }

  /// Get tasks by priority
  Future<List<Task>> getByPriority(TaskPriority priority) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching tasks with priority: ${priority.name}');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .eq('priority', priority.name)
          .order('created_at', ascending: false);
      
      final tasks = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${tasks.length} tasks with priority: ${priority.name}');
      return tasks;
    } catch (e) {
      Logger.error('Failed to fetch tasks by priority: $e');
      throw handleError(e);
    }
  }

  /// Get overdue tasks
  Future<List<Task>> getOverdue() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching overdue tasks');
      
      final now = DateTime.now().toIso8601String();
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .eq('completed', false)
          .not('due_date', 'is', null)
          .lt('due_date', now)
          .order('due_date', ascending: true);
      
      final tasks = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${tasks.length} overdue tasks');
      return tasks;
    } catch (e) {
      Logger.error('Failed to fetch overdue tasks: $e');
      throw handleError(e);
    }
  }

  /// Get tasks due today
  Future<List<Task>> getDueToday() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching tasks due today');
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .eq('completed', false)
          .gte('due_date', startOfDay)
          .lte('due_date', endOfDay)
          .order('due_date', ascending: true);
      
      final tasks = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${tasks.length} tasks due today');
      return tasks;
    } catch (e) {
      Logger.error('Failed to fetch tasks due today: $e');
      throw handleError(e);
    }
  }

  /// Get tasks due within specified days
  Future<List<Task>> getDueWithin(int days) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching tasks due within $days days');
      
      final now = DateTime.now();
      final futureDate = now.add(Duration(days: days)).toIso8601String();
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .eq('completed', false)
          .not('due_date', 'is', null)
          .gte('due_date', now.toIso8601String())
          .lte('due_date', futureDate)
          .order('due_date', ascending: true);
      
      final tasks = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${tasks.length} tasks due within $days days');
      return tasks;
    } catch (e) {
      Logger.error('Failed to fetch tasks due within $days days: $e');
      throw handleError(e);
    }
  }

  /// Mark task as completed
  Future<Task> markCompleted(String taskId) async {
    try {
      Logger.info('Marking task $taskId as completed');
      
      return await update(taskId, {
        'completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      Logger.error('Failed to mark task as completed: $e');
      throw handleError(e);
    }
  }

  /// Mark task as incomplete
  Future<Task> markIncomplete(String taskId) async {
    try {
      Logger.info('Marking task $taskId as incomplete');
      
      return await update(taskId, {
        'completed': false,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      Logger.error('Failed to mark task as incomplete: $e');
      throw handleError(e);
    }
  }

  /// Update task priority
  Future<Task> updatePriority(String taskId, TaskPriority priority) async {
    try {
      Logger.info('Updating task $taskId priority to ${priority.name}');
      
      return await update(taskId, {
        'priority': priority.name,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      Logger.error('Failed to update task priority: $e');
      throw handleError(e);
    }
  }

  /// Update task due date
  Future<Task> updateDueDate(String taskId, DateTime? dueDate) async {
    try {
      Logger.info('Updating task $taskId due date');
      
      return await update(taskId, {
        'due_date': dueDate?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      Logger.error('Failed to update task due date: $e');
      throw handleError(e);
    }
  }

  /// Search tasks by description
  Future<List<Task>> searchByDescription(String query) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Searching tasks with query: $query');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .ilike('description', '%$query%')
          .order('created_at', ascending: false);
      
      final tasks = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Found ${tasks.length} tasks matching query: $query');
      return tasks;
    } catch (e) {
      Logger.error('Failed to search tasks: $e');
      throw handleError(e);
    }
  }

  /// Get task statistics
  Future<Map<String, int>> getStatistics() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching task statistics');
      
      // Get all tasks for the user
      final allTasks = await getAll();
      
      final stats = {
        'total': allTasks.length,
        'completed': allTasks.where((task) => task.completed).length,
        'incomplete': allTasks.where((task) => !task.completed).length,
        'overdue': allTasks.where((task) => task.isOverdue).length,
        'due_today': allTasks.where((task) => task.isDueToday).length,
        'high_priority': allTasks.where((task) => task.priority == TaskPriority.high).length,
        'medium_priority': allTasks.where((task) => task.priority == TaskPriority.medium).length,
        'low_priority': allTasks.where((task) => task.priority == TaskPriority.low).length,
      };
      
      Logger.info('Task statistics: $stats');
      return stats;
    } catch (e) {
      Logger.error('Failed to fetch task statistics: $e');
      throw handleError(e);
    }
  }


}