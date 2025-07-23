import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import '../../utils/logger.dart';

/// Manages user sessions with automatic refresh logic
class SessionManager {
  final AuthService _authService;
  Timer? _refreshTimer;
  
  static const Duration _refreshBuffer = Duration(minutes: 5);
  static const Duration _checkInterval = Duration(minutes: 1);
  
  SessionManager(this._authService) {
    _startSessionMonitoring();
  }
  
  /// Start monitoring session expiration
  void _startSessionMonitoring() {
    _refreshTimer = Timer.periodic(_checkInterval, (_) {
      _checkAndRefreshSession();
    });
    
    Logger.info('Session monitoring started');
  }
  
  /// Check if session needs refresh and refresh if necessary
  Future<void> _checkAndRefreshSession() async {
    final session = _authService.currentSession;
    
    if (session == null) {
      Logger.debug('No active session to check');
      return;
    }
    
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    final now = DateTime.now();
    final timeUntilExpiry = expiresAt.difference(now);
    
    Logger.debug('Session expires in: ${timeUntilExpiry.inMinutes} minutes');
    
    // Refresh if session expires within the buffer time
    if (timeUntilExpiry <= _refreshBuffer && timeUntilExpiry > Duration.zero) {
      Logger.info('Session expiring soon, attempting refresh');
      await _performSessionRefresh();
    } else if (timeUntilExpiry <= Duration.zero) {
      Logger.warning('Session has expired');
      await _handleExpiredSession();
    }
  }
  
  /// Perform session refresh
  Future<void> _performSessionRefresh() async {
    try {
      await _authService.refreshSession();
      Logger.info('Session refreshed successfully');
    } catch (e) {
      Logger.error('Failed to refresh session: $e');
      await _handleExpiredSession();
    }
  }
  
  /// Handle expired session
  Future<void> _handleExpiredSession() async {
    try {
      Logger.info('Handling expired session - signing out user');
      await _authService.signOut();
    } catch (e) {
      Logger.error('Failed to sign out expired user: $e');
    }
  }
  
  /// Manually trigger session refresh
  Future<bool> refreshSession() async {
    try {
      await _authService.refreshSession();
      Logger.info('Manual session refresh successful');
      return true;
    } catch (e) {
      Logger.error('Manual session refresh failed: $e');
      return false;
    }
  }
  
  /// Get session expiry information
  SessionInfo? getSessionInfo() {
    final session = _authService.currentSession;
    
    if (session == null) {
      return null;
    }
    
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
    final now = DateTime.now();
    final timeUntilExpiry = expiresAt.difference(now);
    
    return SessionInfo(
      expiresAt: expiresAt,
      timeUntilExpiry: timeUntilExpiry,
      isExpired: timeUntilExpiry <= Duration.zero,
      needsRefresh: timeUntilExpiry <= _refreshBuffer,
    );
  }
  
  /// Stop session monitoring
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    Logger.info('Session monitoring stopped');
  }
}

/// Information about the current session
class SessionInfo {
  final DateTime expiresAt;
  final Duration timeUntilExpiry;
  final bool isExpired;
  final bool needsRefresh;
  
  const SessionInfo({
    required this.expiresAt,
    required this.timeUntilExpiry,
    required this.isExpired,
    required this.needsRefresh,
  });
  
  @override
  String toString() {
    return 'SessionInfo(expiresAt: $expiresAt, timeUntilExpiry: $timeUntilExpiry, '
           'isExpired: $isExpired, needsRefresh: $needsRefresh)';
  }
}