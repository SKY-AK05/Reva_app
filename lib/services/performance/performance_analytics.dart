import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'performance_monitor.dart';
import 'memory_optimizer.dart';

/// Service for collecting and analyzing app performance metrics
class PerformanceAnalytics {
  static const String _storageKey = 'performance_analytics';
  static const Duration _reportingInterval = Duration(hours: 1);
  static Timer? _reportingTimer;
  static bool _isCollecting = false;
  static final List<PerformanceEvent> _events = [];

  /// Start collecting performance analytics
  static void startCollection() {
    if (_isCollecting) return;
    
    _isCollecting = true;
    _startPeriodicReporting();
    debugPrint('Performance analytics collection started');
  }

  /// Stop collecting performance analytics
  static void stopCollection() {
    _isCollecting = false;
    _reportingTimer?.cancel();
    _reportingTimer = null;
    debugPrint('Performance analytics collection stopped');
  }

  /// Record a performance event
  static void recordEvent(PerformanceEventType type, {
    String? name,
    Duration? duration,
    Map<String, dynamic>? metadata,
  }) {
    if (!_isCollecting) return;

    final event = PerformanceEvent(
      type: type,
      name: name ?? type.toString(),
      timestamp: DateTime.now(),
      duration: duration,
      metadata: metadata,
    );

    _events.add(event);
    
    // Keep only last 1000 events to prevent memory issues
    if (_events.length > 1000) {
      _events.removeAt(0);
    }

    debugPrint('Performance event recorded: ${event.name} (${event.duration?.inMilliseconds}ms)');
  }

  /// Record screen load time
  static void recordScreenLoad(String screenName, Duration loadTime) {
    recordEvent(
      PerformanceEventType.screenLoad,
      name: screenName,
      duration: loadTime,
      metadata: {
        'screenName': screenName,
        'loadTimeMs': loadTime.inMilliseconds,
      },
    );
  }

  /// Record API call performance
  static void recordAPICall(String endpoint, Duration responseTime, {
    bool success = true,
    String? errorMessage,
  }) {
    recordEvent(
      PerformanceEventType.apiCall,
      name: endpoint,
      duration: responseTime,
      metadata: {
        'endpoint': endpoint,
        'responseTimeMs': responseTime.inMilliseconds,
        'success': success,
        'errorMessage': errorMessage,
      },
    );
  }

  /// Record memory usage
  static void recordMemoryUsage(double memoryUsageMB) {
    recordEvent(
      PerformanceEventType.memoryUsage,
      name: 'memory_usage',
      metadata: {
        'memoryUsageMB': memoryUsageMB,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Record app crash or error
  static void recordError(String error, StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    recordEvent(
      PerformanceEventType.error,
      name: 'app_error',
      metadata: {
        'error': error,
        'stackTrace': stackTrace?.toString(),
        'context': context,
        'additionalData': additionalData,
      },
    );
  }

  /// Record user interaction
  static void recordUserInteraction(String interaction, {
    Duration? responseTime,
    Map<String, dynamic>? metadata,
  }) {
    recordEvent(
      PerformanceEventType.userInteraction,
      name: interaction,
      duration: responseTime,
      metadata: metadata,
    );
  }

  /// Start periodic reporting
  static void _startPeriodicReporting() {
    _reportingTimer = Timer.periodic(_reportingInterval, (_) {
      _generateAndStoreReport();
    });
  }

  /// Generate and store performance report
  static Future<void> _generateAndStoreReport() async {
    try {
      final report = await generatePerformanceReport();
      await _storeReport(report);
      
      // Clear old events after reporting
      _events.clear();
      
      debugPrint('Performance report generated and stored');
    } catch (e) {
      debugPrint('Error generating performance report: $e');
    }
  }

  /// Generate comprehensive performance report
  static Future<PerformanceReport> generatePerformanceReport() async {
    final monitorReport = PerformanceMonitor.getPerformanceReport();
    final memoryStats = await MemoryOptimizer.getOptimizationStats();
    
    // Analyze events
    final screenLoadTimes = _getScreenLoadAnalysis();
    final apiCallStats = _getAPICallAnalysis();
    final errorStats = _getErrorAnalysis();
    final memoryUsageStats = _getMemoryUsageAnalysis();
    
    return PerformanceReport(
      timestamp: DateTime.now(),
      screenLoadTimes: screenLoadTimes,
      apiCallStats: apiCallStats,
      errorStats: errorStats,
      memoryUsageStats: memoryUsageStats,
      memoryOptimizationStats: memoryStats,
      totalEvents: _events.length,
      reportingPeriod: _reportingInterval,
    );
  }

  /// Analyze screen load times
  static Map<String, ScreenLoadStats> _getScreenLoadAnalysis() {
    final screenLoads = _events
        .where((e) => e.type == PerformanceEventType.screenLoad)
        .toList();
    
    final Map<String, List<Duration>> screenTimes = {};
    
    for (final event in screenLoads) {
      if (event.duration != null) {
        final screenName = event.metadata?['screenName'] ?? event.name;
        screenTimes.putIfAbsent(screenName, () => []).add(event.duration!);
      }
    }
    
    final Map<String, ScreenLoadStats> stats = {};
    
    for (final entry in screenTimes.entries) {
      final times = entry.value;
      if (times.isNotEmpty) {
        final totalMs = times.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
        final avgMs = totalMs / times.length;
        final maxMs = times.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
        final minMs = times.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
        
        stats[entry.key] = ScreenLoadStats(
          screenName: entry.key,
          loadCount: times.length,
          averageLoadTimeMs: avgMs.round(),
          maxLoadTimeMs: maxMs,
          minLoadTimeMs: minMs,
        );
      }
    }
    
    return stats;
  }

  /// Analyze API call performance
  static Map<String, APICallStats> _getAPICallAnalysis() {
    final apiCalls = _events
        .where((e) => e.type == PerformanceEventType.apiCall)
        .toList();
    
    final Map<String, List<PerformanceEvent>> endpointCalls = {};
    
    for (final event in apiCalls) {
      final endpoint = event.metadata?['endpoint'] ?? event.name;
      endpointCalls.putIfAbsent(endpoint, () => []).add(event);
    }
    
    final Map<String, APICallStats> stats = {};
    
    for (final entry in endpointCalls.entries) {
      final calls = entry.value;
      if (calls.isNotEmpty) {
        final durations = calls
            .where((c) => c.duration != null)
            .map((c) => c.duration!)
            .toList();
        
        if (durations.isNotEmpty) {
          final totalMs = durations.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
          final avgMs = totalMs / durations.length;
          final maxMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
          final minMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
          
          final successCount = calls.where((c) => c.metadata?['success'] == true).length;
          final errorCount = calls.length - successCount;
          
          stats[entry.key] = APICallStats(
            endpoint: entry.key,
            callCount: calls.length,
            averageMs: avgMs.round(),
            maxMs: maxMs,
            minMs: minMs,
            successCount: successCount,
            errorCount: errorCount,
          );
        }
      }
    }
    
    return stats;
  }

  /// Analyze error statistics
  static ErrorStats _getErrorAnalysis() {
    final errors = _events
        .where((e) => e.type == PerformanceEventType.error)
        .toList();
    
    final Map<String, int> errorTypes = {};
    
    for (final event in errors) {
      final error = event.metadata?['error'] ?? 'Unknown Error';
      errorTypes[error] = (errorTypes[error] ?? 0) + 1;
    }
    
    return ErrorStats(
      totalErrors: errors.length,
      errorTypes: errorTypes,
      lastErrorTime: errors.isNotEmpty ? errors.last.timestamp : null,
    );
  }

  /// Analyze memory usage patterns
  static MemoryUsageStats _getMemoryUsageAnalysis() {
    final memoryEvents = _events
        .where((e) => e.type == PerformanceEventType.memoryUsage)
        .toList();
    
    if (memoryEvents.isEmpty) {
      return MemoryUsageStats(
        averageUsageMB: 0,
        maxUsageMB: 0,
        minUsageMB: 0,
        sampleCount: 0,
      );
    }
    
    final usages = memoryEvents
        .map((e) => e.metadata?['memoryUsageMB'] as double? ?? 0.0)
        .toList();
    
    final totalUsage = usages.fold<double>(0, (sum, usage) => sum + usage);
    final avgUsage = totalUsage / usages.length;
    final maxUsage = usages.reduce((a, b) => a > b ? a : b);
    final minUsage = usages.reduce((a, b) => a < b ? a : b);
    
    return MemoryUsageStats(
      averageUsageMB: avgUsage,
      maxUsageMB: maxUsage,
      minUsageMB: minUsage,
      sampleCount: usages.length,
    );
  }

  /// Store performance report
  static Future<void> _storeReport(PerformanceReport report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reports = await getStoredReports();
      
      reports.add(report);
      
      // Keep only last 10 reports
      if (reports.length > 10) {
        reports.removeAt(0);
      }
      
      final jsonList = reports.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error storing performance report: $e');
    }
  }

  /// Get stored performance reports
  static Future<List<PerformanceReport>> getStoredReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        return jsonList
            .map((json) => PerformanceReport.fromJson(json))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading stored reports: $e');
    }
    
    return [];
  }

  /// Clear stored reports
  static Future<void> clearStoredReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      debugPrint('Stored performance reports cleared');
    } catch (e) {
      debugPrint('Error clearing stored reports: $e');
    }
  }

  /// Get performance insights
  static Future<List<PerformanceInsight>> getPerformanceInsights() async {
    final reports = await getStoredReports();
    if (reports.isEmpty) return [];
    
    final insights = <PerformanceInsight>[];
    final latestReport = reports.last;
    
    // Check for slow screen loads
    for (final screenStats in latestReport.screenLoadTimes.values) {
      if (screenStats.averageLoadTimeMs > 1000) {
        insights.add(PerformanceInsight(
          type: InsightType.slowScreenLoad,
          title: 'Slow Screen Load Detected',
          description: '${screenStats.screenName} takes ${screenStats.averageLoadTimeMs}ms to load on average',
          severity: screenStats.averageLoadTimeMs > 2000 ? InsightSeverity.high : InsightSeverity.medium,
          recommendation: 'Consider optimizing ${screenStats.screenName} by reducing initial data loading or using lazy loading',
        ));
      }
    }
    
    // Check for slow API calls
    for (final apiStats in latestReport.apiCallStats.values) {
      if (apiStats.averageMs > 3000) {
        insights.add(PerformanceInsight(
          type: InsightType.slowApiCall,
          title: 'Slow API Call Detected',
          description: '${apiStats.endpoint} takes ${apiStats.averageMs}ms on average',
          severity: apiStats.averageMs > 5000 ? InsightSeverity.high : InsightSeverity.medium,
          recommendation: 'Consider optimizing the ${apiStats.endpoint} endpoint or implementing caching',
        ));
      }
    }
    
    // Check for high error rates
    for (final apiStats in latestReport.apiCallStats.values) {
      final errorRate = apiStats.errorCount / apiStats.callCount;
      if (errorRate > 0.1) { // More than 10% error rate
        insights.add(PerformanceInsight(
          type: InsightType.highErrorRate,
          title: 'High Error Rate Detected',
          description: '${apiStats.endpoint} has ${(errorRate * 100).toStringAsFixed(1)}% error rate',
          severity: errorRate > 0.2 ? InsightSeverity.high : InsightSeverity.medium,
          recommendation: 'Investigate and fix errors in ${apiStats.endpoint} to improve user experience',
        ));
      }
    }
    
    // Check for high memory usage
    if (latestReport.memoryUsageStats.averageUsageMB > 200) {
      insights.add(PerformanceInsight(
        type: InsightType.highMemoryUsage,
        title: 'High Memory Usage Detected',
        description: 'Average memory usage is ${latestReport.memoryUsageStats.averageUsageMB.toStringAsFixed(1)}MB',
        severity: latestReport.memoryUsageStats.averageUsageMB > 300 ? InsightSeverity.high : InsightSeverity.medium,
        recommendation: 'Consider implementing more aggressive memory optimization or reducing cache sizes',
      ));
    }
    
    return insights;
  }
}

/// Performance event types
enum PerformanceEventType {
  screenLoad,
  apiCall,
  memoryUsage,
  error,
  userInteraction,
}

/// Performance event data class
class PerformanceEvent {
  final PerformanceEventType type;
  final String name;
  final DateTime timestamp;
  final Duration? duration;
  final Map<String, dynamic>? metadata;

  PerformanceEvent({
    required this.type,
    required this.name,
    required this.timestamp,
    this.duration,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'name': name,
      'timestamp': timestamp.toIso8601String(),
      'duration': duration?.inMilliseconds,
      'metadata': metadata,
    };
  }

  factory PerformanceEvent.fromJson(Map<String, dynamic> json) {
    return PerformanceEvent(
      type: PerformanceEventType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => PerformanceEventType.userInteraction,
      ),
      name: json['name'],
      timestamp: DateTime.parse(json['timestamp']),
      duration: json['duration'] != null ? Duration(milliseconds: json['duration']) : null,
      metadata: json['metadata'],
    );
  }
}

/// Screen load statistics
class ScreenLoadStats {
  final String screenName;
  final int loadCount;
  final int averageLoadTimeMs;
  final int maxLoadTimeMs;
  final int minLoadTimeMs;

  ScreenLoadStats({
    required this.screenName,
    required this.loadCount,
    required this.averageLoadTimeMs,
    required this.maxLoadTimeMs,
    required this.minLoadTimeMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'screenName': screenName,
      'loadCount': loadCount,
      'averageLoadTimeMs': averageLoadTimeMs,
      'maxLoadTimeMs': maxLoadTimeMs,
      'minLoadTimeMs': minLoadTimeMs,
    };
  }

  factory ScreenLoadStats.fromJson(Map<String, dynamic> json) {
    return ScreenLoadStats(
      screenName: json['screenName'],
      loadCount: json['loadCount'],
      averageLoadTimeMs: json['averageLoadTimeMs'],
      maxLoadTimeMs: json['maxLoadTimeMs'],
      minLoadTimeMs: json['minLoadTimeMs'],
    );
  }
}

/// API call statistics
class APICallStats {
  final String endpoint;
  final int callCount;
  final int averageMs;
  final int maxMs;
  final int minMs;
  final int successCount;
  final int errorCount;

  APICallStats({
    required this.endpoint,
    required this.callCount,
    required this.averageMs,
    required this.maxMs,
    required this.minMs,
    required this.successCount,
    required this.errorCount,
  });

  double get successRate => callCount > 0 ? successCount / callCount : 0.0;
  double get errorRate => callCount > 0 ? errorCount / callCount : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'callCount': callCount,
      'averageMs': averageMs,
      'maxMs': maxMs,
      'minMs': minMs,
      'successCount': successCount,
      'errorCount': errorCount,
    };
  }

  factory APICallStats.fromJson(Map<String, dynamic> json) {
    return APICallStats(
      endpoint: json['endpoint'],
      callCount: json['callCount'],
      averageMs: json['averageMs'],
      maxMs: json['maxMs'],
      minMs: json['minMs'],
      successCount: json['successCount'],
      errorCount: json['errorCount'],
    );
  }
}

/// Error statistics
class ErrorStats {
  final int totalErrors;
  final Map<String, int> errorTypes;
  final DateTime? lastErrorTime;

  ErrorStats({
    required this.totalErrors,
    required this.errorTypes,
    this.lastErrorTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalErrors': totalErrors,
      'errorTypes': errorTypes,
      'lastErrorTime': lastErrorTime?.toIso8601String(),
    };
  }

  factory ErrorStats.fromJson(Map<String, dynamic> json) {
    return ErrorStats(
      totalErrors: json['totalErrors'],
      errorTypes: Map<String, int>.from(json['errorTypes']),
      lastErrorTime: json['lastErrorTime'] != null 
          ? DateTime.parse(json['lastErrorTime']) 
          : null,
    );
  }
}

/// Memory usage statistics
class MemoryUsageStats {
  final double averageUsageMB;
  final double maxUsageMB;
  final double minUsageMB;
  final int sampleCount;

  MemoryUsageStats({
    required this.averageUsageMB,
    required this.maxUsageMB,
    required this.minUsageMB,
    required this.sampleCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'averageUsageMB': averageUsageMB,
      'maxUsageMB': maxUsageMB,
      'minUsageMB': minUsageMB,
      'sampleCount': sampleCount,
    };
  }

  factory MemoryUsageStats.fromJson(Map<String, dynamic> json) {
    return MemoryUsageStats(
      averageUsageMB: json['averageUsageMB'],
      maxUsageMB: json['maxUsageMB'],
      minUsageMB: json['minUsageMB'],
      sampleCount: json['sampleCount'],
    );
  }
}

/// Comprehensive performance report
class PerformanceReport {
  final DateTime timestamp;
  final Map<String, ScreenLoadStats> screenLoadTimes;
  final Map<String, APICallStats> apiCallStats;
  final ErrorStats errorStats;
  final MemoryUsageStats memoryUsageStats;
  final MemoryOptimizationStats memoryOptimizationStats;
  final int totalEvents;
  final Duration reportingPeriod;

  PerformanceReport({
    required this.timestamp,
    required this.screenLoadTimes,
    required this.apiCallStats,
    required this.errorStats,
    required this.memoryUsageStats,
    required this.memoryOptimizationStats,
    required this.totalEvents,
    required this.reportingPeriod,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'screenLoadTimes': screenLoadTimes.map((k, v) => MapEntry(k, v.toJson())),
      'apiCallStats': apiCallStats.map((k, v) => MapEntry(k, v.toJson())),
      'errorStats': errorStats.toJson(),
      'memoryUsageStats': memoryUsageStats.toJson(),
      'totalEvents': totalEvents,
      'reportingPeriodMs': reportingPeriod.inMilliseconds,
    };
  }

  factory PerformanceReport.fromJson(Map<String, dynamic> json) {
    return PerformanceReport(
      timestamp: DateTime.parse(json['timestamp']),
      screenLoadTimes: (json['screenLoadTimes'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, ScreenLoadStats.fromJson(v))),
      apiCallStats: (json['apiCallStats'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, APICallStats.fromJson(v))),
      errorStats: ErrorStats.fromJson(json['errorStats']),
      memoryUsageStats: MemoryUsageStats.fromJson(json['memoryUsageStats']),
      memoryOptimizationStats: MemoryOptimizationStats(
        currentMemoryUsageMB: 0,
        imageCacheSizeMB: 0,
        databaseSizeMB: 0,
        isOptimizing: false,
        lastCleanupTime: DateTime.now(),
      ), // Simplified for JSON compatibility
      totalEvents: json['totalEvents'],
      reportingPeriod: Duration(milliseconds: json['reportingPeriodMs']),
    );
  }
}

/// Performance insight types
enum InsightType {
  slowScreenLoad,
  slowApiCall,
  highErrorRate,
  highMemoryUsage,
}

/// Performance insight severity
enum InsightSeverity {
  low,
  medium,
  high,
}

/// Performance insight
class PerformanceInsight {
  final InsightType type;
  final String title;
  final String description;
  final InsightSeverity severity;
  final String recommendation;

  PerformanceInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.recommendation,
  });
}