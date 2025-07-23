import 'dart:developer' as developer;

/// Simple logging utility for the application
class Logger {
  static const String _appName = 'RevaApp';
  
  /// Log levels
  static const int _debugLevel = 0;
  static const int _infoLevel = 1;
  static const int _warningLevel = 2;
  static const int _errorLevel = 3;
  
  /// Current log level (can be configured)
  static int _currentLevel = _debugLevel;
  
  /// Set the minimum log level
  static void setLevel(int level) {
    _currentLevel = level;
  }
  
  /// Log debug message
  static void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (_currentLevel <= _debugLevel) {
      _log('DEBUG', message, error, stackTrace);
    }
  }
  
  /// Log info message
  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (_currentLevel <= _infoLevel) {
      _log('INFO', message, error, stackTrace);
    }
  }
  
  /// Log warning message
  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (_currentLevel <= _warningLevel) {
      _log('WARNING', message, error, stackTrace);
    }
  }
  
  /// Log error message
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (_currentLevel <= _errorLevel) {
      _log('ERROR', message, error, stackTrace);
    }
  }
  
  /// Internal logging method
  static void _log(String level, String message, [Object? error, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [$level] $_appName: $message';
    
    // Use developer.log for better debugging support
    developer.log(
      logMessage,
      name: _appName,
      error: error,
      stackTrace: stackTrace,
      level: _getLevelValue(level),
    );
  }
  
  /// Get numeric level value for developer.log
  static int _getLevelValue(String level) {
    switch (level) {
      case 'DEBUG':
        return 500;
      case 'INFO':
        return 800;
      case 'WARNING':
        return 900;
      case 'ERROR':
        return 1000;
      default:
        return 800;
    }
  }
  
  /// Log method entry (for debugging)
  static void methodEntry(String className, String methodName, [Map<String, dynamic>? params]) {
    if (_currentLevel <= _debugLevel) {
      final paramsStr = params != null ? ' with params: $params' : '';
      debug('[$className.$methodName] Entry$paramsStr');
    }
  }
  
  /// Log method exit (for debugging)
  static void methodExit(String className, String methodName, [dynamic result]) {
    if (_currentLevel <= _debugLevel) {
      final resultStr = result != null ? ' returning: $result' : '';
      debug('[$className.$methodName] Exit$resultStr');
    }
  }
  
  /// Log performance timing
  static void performance(String operation, Duration duration) {
    info('Performance: $operation took ${duration.inMilliseconds}ms');
  }
  
  /// Log network request
  static void networkRequest(String method, String url, [Map<String, dynamic>? headers]) {
    debug('Network: $method $url${headers != null ? ' headers: $headers' : ''}');
  }
  
  /// Log network response
  static void networkResponse(String url, int statusCode, [String? body]) {
    final bodyStr = body != null && body.length > 200 ? '${body.substring(0, 200)}...' : body;
    debug('Network Response: $url -> $statusCode${bodyStr != null ? ' body: $bodyStr' : ''}');
  }
  
  /// Log cache operation
  static void cache(String operation, String key, [bool? hit]) {
    final hitStr = hit != null ? (hit ? ' HIT' : ' MISS') : '';
    debug('Cache: $operation $key$hitStr');
  }
  
  /// Log database operation
  static void database(String operation, String table, [Map<String, dynamic>? data]) {
    final dataStr = data != null ? ' data: $data' : '';
    debug('Database: $operation $table$dataStr');
  }
  
  /// Log authentication event
  static void auth(String event, [String? userId]) {
    final userStr = userId != null ? ' user: $userId' : '';
    info('Auth: $event$userStr');
  }
  
  /// Log sync operation
  static void sync(String operation, [String? details]) {
    final detailsStr = details != null ? ' - $details' : '';
    info('Sync: $operation$detailsStr');
  }
  
  /// Log notification event
  static void notification(String event, [String? details]) {
    final detailsStr = details != null ? ' - $details' : '';
    info('Notification: $event$detailsStr');
  }
}