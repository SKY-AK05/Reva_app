import '../../models/reminder.dart';
import '../../utils/logger.dart';
import 'base_repository.dart';

class RemindersRepository extends BaseRepository<Reminder> {
  @override
  String get tableName => 'reminders';

  @override
  Reminder fromJson(Map<String, dynamic> json) => Reminder.fromJson(json);

  @override
  Map<String, dynamic> toJson(Reminder item) => item.toJson();

  /// Get reminders by completion status
  Future<List<Reminder>> getByCompletionStatus(bool completed) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching ${completed ? 'completed' : 'incomplete'} reminders');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .eq('completed', completed)
          .order('scheduled_time', ascending: !completed);
      
      final reminders = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${reminders.length} ${completed ? 'completed' : 'incomplete'} reminders');
      return reminders;
    } catch (e) {
      Logger.error('Failed to fetch reminders by completion status: $e');
      throw handleError(e);
    }
  }

  /// Get upcoming reminders (not completed and scheduled for future)
  Future<List<Reminder>> getUpcoming() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching upcoming reminders');
      
      final now = DateTime.now().toIso8601String();
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .eq('completed', false)
          .gt('scheduled_time', now)
          .order('scheduled_time', ascending: true);
      
      final reminders = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${reminders.length} upcoming reminders');
      return reminders;
    } catch (e) {
      Logger.error('Failed to fetch upcoming reminders: $e');
      throw handleError(e);
    }
  }

  /// Get overdue reminders (not completed and scheduled for past)
  Future<List<Reminder>> getOverdue() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching overdue reminders');
      
      final now = DateTime.now().toIso8601String();
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .eq('completed', false)
          .lt('scheduled_time', now)
          .order('scheduled_time', ascending: false);
      
      final reminders = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${reminders.length} overdue reminders');
      return reminders;
    } catch (e) {
      Logger.error('Failed to fetch overdue reminders: $e');
      throw handleError(e);
    }
  }

  /// Get reminders due today
  Future<List<Reminder>> getDueToday() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching reminders due today');
      
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .gte('scheduled_time', startOfDay)
          .lte('scheduled_time', endOfDay)
          .order('scheduled_time', ascending: true);
      
      final reminders = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${reminders.length} reminders due today');
      return reminders;
    } catch (e) {
      Logger.error('Failed to fetch reminders due today: $e');
      throw handleError(e);
    }
  }

  /// Get reminders due within specified duration
  Future<List<Reminder>> getDueWithin(Duration duration) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching reminders due within ${duration.inHours} hours');
      
      final now = DateTime.now();
      final futureTime = now.add(duration);
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .eq('completed', false)
          .gte('scheduled_time', now.toIso8601String())
          .lte('scheduled_time', futureTime.toIso8601String())
          .order('scheduled_time', ascending: true);
      
      final reminders = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${reminders.length} reminders due within ${duration.inHours} hours');
      return reminders;
    } catch (e) {
      Logger.error('Failed to fetch reminders due within duration: $e');
      throw handleError(e);
    }
  }

  /// Get reminders within date range
  Future<List<Reminder>> getByDateRange(DateTime startDate, DateTime endDate) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching reminders from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .gte('scheduled_time', startDate.toIso8601String())
          .lte('scheduled_time', endDate.toIso8601String())
          .order('scheduled_time', ascending: true);
      
      final reminders = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${reminders.length} reminders in date range');
      return reminders;
    } catch (e) {
      Logger.error('Failed to fetch reminders by date range: $e');
      throw handleError(e);
    }
  }

  /// Mark reminder as completed
  Future<Reminder> markCompleted(String reminderId) async {
    try {
      Logger.info('Marking reminder $reminderId as completed');
      
      return await update(reminderId, {
        'completed': true,
      });
    } catch (e) {
      Logger.error('Failed to mark reminder as completed: $e');
      throw handleError(e);
    }
  }

  /// Mark reminder as incomplete
  Future<Reminder> markIncomplete(String reminderId) async {
    try {
      Logger.info('Marking reminder $reminderId as incomplete');
      
      return await update(reminderId, {
        'completed': false,
      });
    } catch (e) {
      Logger.error('Failed to mark reminder as incomplete: $e');
      throw handleError(e);
    }
  }

  /// Update reminder scheduled time
  Future<Reminder> updateScheduledTime(String reminderId, DateTime scheduledTime) async {
    try {
      Logger.info('Updating reminder $reminderId scheduled time');
      
      return await update(reminderId, {
        'scheduled_time': scheduledTime.toIso8601String(),
      });
    } catch (e) {
      Logger.error('Failed to update reminder scheduled time: $e');
      throw handleError(e);
    }
  }

  /// Snooze reminder (reschedule for later)
  Future<Reminder> snooze(String reminderId, Duration snoozeDuration) async {
    try {
      Logger.info('Snoozing reminder $reminderId for ${snoozeDuration.inMinutes} minutes');
      
      final reminder = await getById(reminderId);
      if (reminder == null) {
        throw Exception('Reminder not found');
      }
      
      final newScheduledTime = DateTime.now().add(snoozeDuration);
      
      return await updateScheduledTime(reminderId, newScheduledTime);
    } catch (e) {
      Logger.error('Failed to snooze reminder: $e');
      throw handleError(e);
    }
  }

  /// Search reminders by title or description
  Future<List<Reminder>> search(String query) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Searching reminders with query: $query');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('scheduled_time', ascending: true);
      
      final reminders = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Found ${reminders.length} reminders matching query: $query');
      return reminders;
    } catch (e) {
      Logger.error('Failed to search reminders: $e');
      throw handleError(e);
    }
  }

  /// Get reminders that need notification (due within next few minutes)
  Future<List<Reminder>> getForNotification({Duration lookAhead = const Duration(minutes: 5)}) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching reminders for notification');
      
      final now = DateTime.now();
      final futureTime = now.add(lookAhead);
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .eq('completed', false)
          .gte('scheduled_time', now.toIso8601String())
          .lte('scheduled_time', futureTime.toIso8601String())
          .order('scheduled_time', ascending: true);
      
      final reminders = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Found ${reminders.length} reminders for notification');
      return reminders;
    } catch (e) {
      Logger.error('Failed to fetch reminders for notification: $e');
      throw handleError(e);
    }
  }

  /// Get reminder statistics
  Future<Map<String, int>> getStatistics() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching reminder statistics');
      
      // Get all reminders for the user
      final allReminders = await getAll();
      
      final stats = {
        'total': allReminders.length,
        'completed': allReminders.where((reminder) => reminder.completed).length,
        'incomplete': allReminders.where((reminder) => !reminder.completed).length,
        'overdue': allReminders.where((reminder) => reminder.isOverdue).length,
        'due_today': allReminders.where((reminder) => reminder.isDueToday).length,
        'upcoming': allReminders.where((reminder) => reminder.isUpcoming).length,
        'due_soon': allReminders.where((reminder) => reminder.isDueSoon).length,
      };
      
      Logger.info('Reminder statistics: $stats');
      return stats;
    } catch (e) {
      Logger.error('Failed to fetch reminder statistics: $e');
      throw handleError(e);
    }
  }
}