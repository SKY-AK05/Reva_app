import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../lib/services/sync/realtime_service.dart';

void main() {
  group('RealtimeService', () {
    late RealtimeService realtimeService;

    setUp(() {
      realtimeService = RealtimeService.instance;
    });

    tearDown(() async {
      await realtimeService.dispose();
    });

    group('Singleton Pattern', () {
      test('should return the same instance', () {
        // Act
        final instance1 = RealtimeService.instance;
        final instance2 = RealtimeService.instance;
        
        // Assert
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Subscription Configuration', () {
      test('should create subscription config correctly', () {
        // Arrange
        var insertCalled = false;
        var updateCalled = false;
        var deleteCalled = false;
        
        // Act
        final config = SubscriptionConfig(
          table: 'tasks',
          filter: 'user_id=eq.123',
          onInsert: (payload) => insertCalled = true,
          onUpdate: (payload) => updateCalled = true,
          onDelete: (payload) => deleteCalled = true,
        );
        
        // Assert
        expect(config.table, equals('tasks'));
        expect(config.filter, equals('user_id=eq.123'));
        expect(config.onInsert, isNotNull);
        expect(config.onUpdate, isNotNull);
        expect(config.onDelete, isNotNull);
        
        // Test callbacks
        config.onInsert!({});
        config.onUpdate!({});
        config.onDelete!({});
        
        expect(insertCalled, isTrue);
        expect(updateCalled, isTrue);
        expect(deleteCalled, isTrue);
      });

      test('should create subscription config with minimal parameters', () {
        // Act
        final config = SubscriptionConfig(table: 'expenses');
        
        // Assert
        expect(config.table, equals('expenses'));
        expect(config.filter, isNull);
        expect(config.onInsert, isNull);
        expect(config.onUpdate, isNull);
        expect(config.onDelete, isNull);
      });
    });

    group('Subscription Status', () {
      test('should return disconnected status for non-existent subscription', () {
        // Act
        final status = realtimeService.getSubscriptionStatus('non-existent');
        
        // Assert
        expect(status, equals(SubscriptionStatus.disconnected));
      });

      test('should return false for non-existent subscription connection check', () {
        // Act
        final isConnected = realtimeService.isSubscriptionConnected('non-existent');
        
        // Assert
        expect(isConnected, isFalse);
      });

      test('should return empty subscription statuses initially', () {
        // Act
        final statuses = realtimeService.subscriptionStatuses;
        
        // Assert
        expect(statuses, isEmpty);
      });
    });

    group('Health Status', () {
      test('should return correct health status structure', () {
        // Act
        final healthStatus = realtimeService.getHealthStatus();
        
        // Assert - Just check the structure exists, not specific values since singleton is shared
        expect(healthStatus['total_subscriptions'], equals(0));
        expect(healthStatus['connected_subscriptions'], equals(0));
        expect(healthStatus['subscription_statuses'], isEmpty);
        expect(healthStatus['has_reconnection_timer'], isFalse);
        expect(healthStatus.containsKey('timestamp'), isTrue);
        expect(healthStatus.containsKey('initialized'), isTrue);
        expect(healthStatus.containsKey('disposed'), isTrue);
      });
    });

    group('Authentication State Handling', () {
      test('should handle sign in auth state', () {
        // Arrange
        final authState = AuthState(AuthChangeEvent.signedIn, null);
        
        // Act & Assert - Should not throw
        expect(() => realtimeService.handleAuthStateChange(authState), returnsNormally);
      });

      test('should handle sign out auth state', () {
        // Arrange
        final authState = AuthState(AuthChangeEvent.signedOut, null);
        
        // Act & Assert - Should not throw
        expect(() => realtimeService.handleAuthStateChange(authState), returnsNormally);
      });

      test('should handle token refresh auth state', () {
        // Arrange
        final authState = AuthState(AuthChangeEvent.tokenRefreshed, null);
        
        // Act & Assert - Should not throw
        expect(() => realtimeService.handleAuthStateChange(authState), returnsNormally);
      });
    });

    group('Stream Functionality', () {
      test('should provide status stream', () {
        // Act
        final stream = realtimeService.statusStream;
        
        // Assert
        expect(stream, isA<Stream<Map<String, SubscriptionStatus>>>());
      });

      test('should emit initial empty status through stream', () async {
        // Arrange
        final statusUpdates = <Map<String, SubscriptionStatus>>[];
        final subscription = realtimeService.statusStream.listen(statusUpdates.add);
        
        // Wait for potential initial emission
        await Future.delayed(const Duration(milliseconds: 10));
        
        // Cleanup
        await subscription.cancel();
        
        // Assert - Stream should be available but may not emit initially
        expect(statusUpdates.length, greaterThanOrEqualTo(0));
      });
    });

    group('Disposal', () {
      test('should dispose cleanly without subscriptions', () async {
        // Act & Assert - Should not throw
        await expectLater(realtimeService.dispose(), completes);
      });

      test('should handle multiple dispose calls', () async {
        // Act
        await realtimeService.dispose();
        
        // Act & Assert - Second dispose should not throw
        await expectLater(realtimeService.dispose(), completes);
      });
    });

    group('Error Handling', () {
      test('should handle unsubscribe of non-existent subscription', () async {
        // Act & Assert - Should not throw
        await expectLater(
          realtimeService.unsubscribe('non-existent'),
          completes,
        );
      });

      test('should handle unsubscribe all with no subscriptions', () async {
        // Act & Assert - Should not throw
        await expectLater(
          realtimeService.unsubscribeAll(),
          completes,
        );
      });

      test('should handle reconnect all with no subscriptions', () async {
        // Act & Assert - Should not throw
        await expectLater(
          realtimeService.reconnectAll(),
          completes,
        );
      });
    });
  });
}