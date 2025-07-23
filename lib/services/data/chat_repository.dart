import '../../models/chat_message.dart';
import '../../utils/logger.dart';
import 'base_repository.dart';

class ChatRepository extends BaseRepository<ChatMessage> {
  @override
  String get tableName => 'chat_messages';

  @override
  ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage.fromJson(json);

  @override
  Map<String, dynamic> toJson(ChatMessage item) => item.toJson();

  /// Get chat messages with pagination (most recent first)
  Future<List<ChatMessage>> getMessages({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching chat messages (limit: $limit, offset: $offset)');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .order('timestamp', ascending: false)
          .range(offset, offset + limit - 1);
      
      final messages = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${messages.length} chat messages');
      return messages;
    } catch (e) {
      Logger.error('Failed to fetch chat messages: $e');
      throw handleError(e);
    }
  }

  /// Get messages by type
  Future<List<ChatMessage>> getByType(MessageType type) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching messages of type: ${type.name}');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .eq('type', type.name)
          .order('timestamp', ascending: false);
      
      final messages = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${messages.length} messages of type: ${type.name}');
      return messages;
    } catch (e) {
      Logger.error('Failed to fetch messages by type: $e');
      throw handleError(e);
    }
  }

  /// Get messages after a specific timestamp
  Future<List<ChatMessage>> getMessagesAfter(DateTime timestamp) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching messages after: ${timestamp.toIso8601String()}');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .gt('timestamp', timestamp.toIso8601String())
          .order('timestamp', ascending: true);
      
      final messages = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${messages.length} messages after timestamp');
      return messages;
    } catch (e) {
      Logger.error('Failed to fetch messages after timestamp: $e');
      throw handleError(e);
    }
  }

  /// Get messages before a specific timestamp (for pagination)
  Future<List<ChatMessage>> getMessagesBefore(DateTime timestamp, {int limit = 50}) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching messages before: ${timestamp.toIso8601String()}');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .lt('timestamp', timestamp.toIso8601String())
          .order('timestamp', ascending: false)
          .limit(limit);
      
      final messages = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Fetched ${messages.length} messages before timestamp');
      return messages;
    } catch (e) {
      Logger.error('Failed to fetch messages before timestamp: $e');
      throw handleError(e);
    }
  }

  /// Search messages by content
  Future<List<ChatMessage>> searchMessages(String query) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Searching messages with query: $query');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .ilike('content', '%$query%')
          .order('timestamp', ascending: false);
      
      final messages = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      Logger.info('Found ${messages.length} messages matching query: $query');
      return messages;
    } catch (e) {
      Logger.error('Failed to search messages: $e');
      throw handleError(e);
    }
  }

  /// Get messages with action metadata
  Future<List<ChatMessage>> getMessagesWithActions() async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching messages with action metadata');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .not('metadata', 'is', null)
          .order('timestamp', ascending: false);
      
      final messages = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .where((message) => message.hasActionMetadata)
          .toList();
      
      Logger.info('Fetched ${messages.length} messages with actions');
      return messages;
    } catch (e) {
      Logger.error('Failed to fetch messages with actions: $e');
      throw handleError(e);
    }
  }

  /// Get conversation context (recent messages for AI)
  Future<List<ChatMessage>> getConversationContext({int limit = 20}) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Fetching conversation context (limit: $limit)');
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .order('timestamp', ascending: false)
          .limit(limit);
      
      final messages = (response as List<dynamic>)
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
      
      // Return in chronological order for context
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      Logger.info('Fetched ${messages.length} messages for conversation context');
      return messages;
    } catch (e) {
      Logger.error('Failed to fetch conversation context: $e');
      throw handleError(e);
    }
  }

  /// Clear old messages (keep only recent ones)
  Future<void> clearOldMessages({int keepCount = 1000}) async {
    try {
      ensureAuthenticated();
      
      Logger.info('Clearing old messages, keeping $keepCount most recent');
      
      // Get the timestamp of the message at the keepCount position
      final recentMessages = await supabase
          .from(tableName)
          .select('timestamp')
          .eq('user_id', currentUserId!)
          .order('timestamp', ascending: false)
          .limit(keepCount);
      
      if (recentMessages.length == keepCount) {
        final cutoffTimestamp = recentMessages.last['timestamp'] as String;
        
        await supabase
            .from(tableName)
            .delete()
            .eq('user_id', currentUserId!)
            .lt('timestamp', cutoffTimestamp);
        
        Logger.info('Cleared old messages before: $cutoffTimestamp');
      }
    } catch (e) {
      Logger.error('Failed to clear old messages: $e');
      throw handleError(e);
    }
  }

  /// Get message count
  Future<int> getMessageCount() async {
    try {
      ensureAuthenticated();
      
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', currentUserId!)
          .count();
      
      return response.count;
    } catch (e) {
      Logger.error('Failed to get message count: $e');
      throw handleError(e);
    }
  }

  /// Note: Chat messages typically don't need user_id since they're session-based
  /// Override the create method to handle this appropriately
  @override
  Future<ChatMessage> create(ChatMessage item) async {
    try {
      Logger.info('Creating new chat message');
      
      final json = toJson(item);
      // Chat messages might not need user_id if they're session-based
      // or they might use a different identifier
      
      final response = await supabase
          .from(tableName)
          .insert(json)
          .select()
          .single();
      
      final createdMessage = fromJson(response as Map<String, dynamic>);
      Logger.info('Created new chat message');
      return createdMessage;
    } catch (e) {
      Logger.error('Failed to create chat message: $e');
      rethrow;
    }
  }
}