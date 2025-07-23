import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../utils/logger.dart';

/// Base repository class with common CRUD operations
abstract class BaseRepository<T> {
  final SupabaseClient _supabase = SupabaseConfig.client;
  
  /// Table name for this repository
  String get tableName;
  
  /// Convert JSON to model instance
  T fromJson(Map<String, dynamic> json);
  
  /// Convert model instance to JSON
  Map<String, dynamic> toJson(T item);
  
  /// Get current user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;
  
  /// Get Supabase client (protected access for subclasses)
  SupabaseClient get supabase => _supabase;
  
  /// Ensure user is authenticated
  void ensureAuthenticated() {
    if (currentUserId == null) {
      throw Exception('User must be authenticated to perform this operation');
    }
  }

  /// Get all items for the current user
  Future<List<T>> getAll() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching all items from $tableName');
      
      final response = await _supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .order('created_at', ascending: false);
      
      final items = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${items.length} items from $tableName');
      return items;
    } catch (e) {
      Logger.error('Failed to fetch items from $tableName: $e');
      rethrow;
    }
  }

  /// Get item by ID
  Future<T?> getById(String id) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching item $id from $tableName');
      
      final response = await _supabase
          .from(tableName)
          .select()
          .eq('id', id)
          .eq('user_id', currentUserId!)
          .maybeSingle();
      
      if (response == null) {
        Logger.info('Item $id not found in $tableName');
        return null;
      }
      
      final item = fromJson(response as Map<String, dynamic>);
      Logger.info('Fetched item $id from $tableName');
      return item;
    } catch (e) {
      Logger.error('Failed to fetch item $id from $tableName: $e');
      rethrow;
    }
  }

  /// Create new item
  Future<T> create(T item) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Creating new item in $tableName');
      
      final json = toJson(item);
      json['user_id'] = currentUserId!;
      
      final response = await _supabase
          .from(tableName)
          .insert(json)
          .select()
          .single();
      
      final createdItem = fromJson(response as Map<String, dynamic>);
      Logger.info('Created new item in $tableName');
      return createdItem;
    } catch (e) {
      Logger.error('Failed to create item in $tableName: $e');
      rethrow;
    }
  }

  /// Update existing item
  Future<T> update(String id, Map<String, dynamic> updates) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Updating item $id in $tableName');
      
      // Add updated_at timestamp if the table supports it
      if (updates.containsKey('updated_at') || tableName == 'tasks') {
        updates['updated_at'] = DateTime.now().toIso8601String();
      }
      
      final response = await _supabase
          .from(tableName)
          .update(updates)
          .eq('id', id)
          .eq('user_id', currentUserId!)
          .select()
          .single();
      
      final updatedItem = fromJson(response as Map<String, dynamic>);
      Logger.info('Updated item $id in $tableName');
      return updatedItem;
    } catch (e) {
      Logger.error('Failed to update item $id in $tableName: $e');
      rethrow;
    }
  }

  /// Delete item
  Future<void> delete(String id) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Deleting item $id from $tableName');
      
      await _supabase
          .from(tableName)
          .delete()
          .eq('id', id)
          .eq('user_id', currentUserId!);
      
      Logger.info('Deleted item $id from $tableName');
    } catch (e) {
      Logger.error('Failed to delete item $id from $tableName: $e');
      rethrow;
    }
  }

  /// Get items with pagination
  Future<List<T>> getPaginated({
    int limit = 20,
    int offset = 0,
    String? orderBy,
    bool ascending = false,
  }) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching paginated items from $tableName (limit: $limit, offset: $offset)');
      
      var query = _supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .range(offset, offset + limit - 1);
      
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      } else {
        query = query.order('created_at', ascending: false);
      }
      
      final response = await query;
      
      final items = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${items.length} paginated items from $tableName');
      return items;
    } catch (e) {
      Logger.error('Failed to fetch paginated items from $tableName: $e');
      rethrow;
    }
  }

  /// Count total items for current user
  Future<int> count() async {
    try {
      ensureAuthenticated();
      
      final response = await _supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .count();
      
      return response.count;
    } catch (e) {
      Logger.error('Failed to count items in $tableName: $e');
      rethrow;
    }
  }

  /// Subscribe to real-time changes
  RealtimeChannel subscribeToChanges({
    required void Function(PostgresChangePayload) onInsert,
    required void Function(PostgresChangePayload) onUpdate,
    required void Function(PostgresChangePayload) onDelete,
  }) {
    Logger.info('Subscribing to real-time changes for $tableName');
    
    return _supabase
        .channel('$tableName-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: tableName,
          callback: onInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: tableName,
          callback: onUpdate,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: tableName,
          callback: onDelete,
        )
        .subscribe();
  }

  /// Handle common database errors
  Exception handleError(dynamic error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case '23505': // Unique violation
          return Exception('This item already exists');
        case '23503': // Foreign key violation
          return Exception('Cannot perform this operation due to related data');
        case '42501': // Insufficient privilege
          return Exception('You do not have permission to perform this operation');
        default:
          return Exception('Database error: ${error.message}');
      }
    }
    
    if (error is AuthException) {
      return Exception('Authentication error: ${error.message}');
    }
    
    return Exception('An unexpected error occurred: $error');
  }
}