import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for monitoring app performance metrics
class PerformanceMonitor {
  static final Map<String, Stopwatch> _screenLoadTimers = {};
  static final Map<String, List<Duration>> _apiCallTimes = {};
  static final List<MemorySnapshot> _memorySnapshots = [];
  static Timer? _memoryMonitorTimer;
  static bool _isMonitoring = false;

  /// Start monitoring performance metrics
  static void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _startMemoryMonitoring();
    debugPrint('Performance monitoring started');
  }

  /// Stop monitoring performance metrics
  static void stopMonitoring() {
    _isMonitoring = false;
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
    debugPrint('Performance monitoring stopped');
  }

  /// Track screen load time
  static void startScreenLoad(String screenName) {
    final stopwatch = Stopwatch()..start();
    _screenLoadTimers[screenName] = stopwatch;
  }

  /// Complete screen load tracking
  static void completeScreenLoad(String screenName) {
    final stopwatch = _screenLoadTimers.remove(screenName);
    if (stopwatch != null) {
      stopwatch.stop();
      final loadTime = stopwatch.elapsed;
      debugPrint('Screen "$screenName" loaded in ${loadTime.inMilliseconds}ms');
      
      // Log slow screen loads
      if (loadTime.inMilliseconds > 1000) {
        debugPrint('WARNING: Slow screen load detected for "$screenName"');
      }
    }
  }

  /// Track API call performance
  static void trackAPICall(String endpoint, Duration duration) {
    _apiCallTimes.putIfAbsent(endpoint, () => []).add(duration);
    
    debugPrint('API call to "$endpoint" took ${duration.inMilliseconds}ms');
    
    // Log slow API calls
    if (duration.inMilliseconds > 3000) {
      debugPrint('WARNING: Slow API call detected for "$endpoint"');
    }
  }

  /// Get API call statistics
  static Map<String, APICallStats> getAPICallStats() {
    final stats = <String, APICallStats>{};
    
    for (final entry in _apiCallTimes.entries) {
      final times = entry.value;
      if (times.isNotEmpty) {
        final totalMs = times.fold<int>(0, (sum, duration) => sum + duration.inMilliseconds);
        final avgMs = totalMs / times.length;
        final maxMs = times.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
        final minMs = times.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
        
        stats[entry.key] = APICallStats(
          endpoint: entry.key,
          callCount: times.length,
          averageMs: avgMs.round(),
          maxMs: maxMs,
          minMs: minMs,
        );
      }
    }
    
    return stats;
  }

  /// Start memory monitoring
  static void _startMemoryMonitoring() {
    _memoryMonitorTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _captureMemorySnapshot(),
    );
  }

  /// Capture memory usage snapshot
  static Future<void> _captureMemorySnapshot() async {
    try {
      final memoryInfo = await _getMemoryInfo();
      if (memoryInfo != null) {
        _memorySnapshots.add(MemorySnapshot(
          timestamp: DateTime.now(),
          usedMemoryMB: memoryInfo.usedMemoryMB,
          totalMemoryMB: memoryInfo.totalMemoryMB,
        ));
        
        // Keep only last 100 snapshots
        if (_memorySnapshots.length > 100) {
          _memorySnapshots.removeAt(0);
        }
        
        // Check for memory leaks
        _checkMemoryLeaks();
      }
    } catch (e) {
      debugPrint('Error capturing memory snapshot: $e');
    }
  }

  /// Get current memory information
  static Future<MemoryInfo?> _getMemoryInfo() async {
    try {
      if (Platform.isAndroid) {
        // Use platform channel to get Android memory info
        const platform = MethodChannel('reva_mobile_app/performance');
        final result = await platform.invokeMethod('getMemoryInfo');
        return MemoryInfo(
          usedMemoryMB: (result['usedMemory'] as num).toDouble() / (1024 * 1024),
          totalMemoryMB: (result['totalMemory'] as num).toDouble() / (1024 * 1024),
        );
      } else if (Platform.isIOS) {
        // Use platform channel to get iOS memory info
        const platform = MethodChannel('reva_mobile_app/performance');
        final result = await platform.invokeMethod('getMemoryInfo');
        return MemoryInfo(
          usedMemoryMB: (result['usedMemory'] as num).toDouble() / (1024 * 1024),
          totalMemoryMB: (result['totalMemory'] as num).toDouble() / (1024 * 1024),
        );
      }
    } catch (e) {
      debugPrint('Error getting memory info: $e');
    }
    return null;
  }

  /// Check for potential memory leaks
  static void _checkMemoryLeaks() {
    if (_memorySnapshots.length < 10) return;
    
    final recent = _memorySnapshots.takeLast(10).toList();
    final oldestUsage = recent.first.usedMemoryMB;
    final newestUsage = recent.last.usedMemoryMB;
    
    // Check if memory usage has increased significantly
    final memoryIncrease = newestUsage - oldestUsage;
    if (memoryIncrease > 50) { // 50MB increase
      debugPrint('WARNING: Potential memory leak detected. Memory increased by ${memoryIncrease.toStringAsFixed(1)}MB');
    }
  }

  /// Get memory usage statistics
  static MemoryStats? getMemoryStats() {
    if (_memorySnapshots.isEmpty) return null;
    
    final usages = _memorySnapshots.map((s) => s.usedMemoryMB).toList();
    final avgUsage = usages.fold<double>(0, (sum, usage) => sum + usage) / usages.length;
    final maxUsage = usages.reduce((a, b) => a > b ? a : b);
    final minUsage = usages.reduce((a, b) => a < b ? a : b);
    
    return MemoryStats(
      averageUsageMB: avgUsage,
      maxUsageMB: maxUsage,
      minUsageMB: minUsage,
      snapshotCount: _memorySnapshots.length,
    );
  }

  /// Clear all performance data
  static void clearData() {
    _screenLoadTimers.clear();
    _apiCallTimes.clear();
    _memorySnapshots.clear();
    debugPrint('Performance monitoring data cleared');
  }

  /// Get performance report
  static PerformanceReport getPerformanceReport() {
    return PerformanceReport(
      apiCallStats: getAPICallStats(),
      memoryStats: getMemoryStats(),
      isMonitoring: _isMonitoring,
    );
  }
}

/// Memory information data class
class MemoryInfo {
  final double usedMemoryMB;
  final double totalMemoryMB;

  MemoryInfo({
    required this.usedMemoryMB,
    required this.totalMemoryMB,
  });

  double get usagePercentage => (usedMemoryMB / totalMemoryMB) * 100;
}

/// Memory snapshot data class
class MemorySnapshot {
  final DateTime timestamp;
  final double usedMemoryMB;
  final double totalMemoryMB;

  MemorySnapshot({
    required this.timestamp,
    required this.usedMemoryMB,
    required this.totalMemoryMB,
  });
}

/// Memory statistics data class
class MemoryStats {
  final double averageUsageMB;
  final double maxUsageMB;
  final double minUsageMB;
  final int snapshotCount;

  MemoryStats({
    required this.averageUsageMB,
    required this.maxUsageMB,
    required this.minUsageMB,
    required this.snapshotCount,
  });
}

/// API call statistics data class
class APICallStats {
  final String endpoint;
  final int callCount;
  final int averageMs;
  final int maxMs;
  final int minMs;

  APICallStats({
    required this.endpoint,
    required this.callCount,
    required this.averageMs,
    required this.maxMs,
    required this.minMs,
  });
}

/// Performance report data class
class PerformanceReport {
  final Map<String, APICallStats> apiCallStats;
  final MemoryStats? memoryStats;
  final bool isMonitoring;

  PerformanceReport({
    required this.apiCallStats,
    required this.memoryStats,
    required this.isMonitoring,
  });
}

/// Extension for taking last N elements from iterable
extension IterableExtension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    if (count >= length) return this;
    return skip(length - count);
  }
}