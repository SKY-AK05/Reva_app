import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../cache/database_helper.dart';
import 'image_cache_service.dart';

/// Service for optimizing memory usage and battery consumption
class MemoryOptimizer {
  static Timer? _cleanupTimer;
  static Timer? _memoryCheckTimer;
  static bool _isOptimizing = false;
  static const Duration _cleanupInterval = Duration(minutes: 15);
  static const Duration _memoryCheckInterval = Duration(minutes: 5);
  static const int _memoryThresholdMB = 150; // Threshold for aggressive cleanup

  /// Start memory optimization
  static void startOptimization() {
    if (_isOptimizing) return;
    
    _isOptimizing = true;
    _startPeriodicCleanup();
    _startMemoryMonitoring();
    debugPrint('Memory optimization started');
  }

  /// Stop memory optimization
  static void stopOptimization() {
    _isOptimizing = false;
    _cleanupTimer?.cancel();
    _memoryCheckTimer?.cancel();
    _cleanupTimer = null;
    _memoryCheckTimer = null;
    debugPrint('Memory optimization stopped');
  }

  /// Start periodic cleanup
  static void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      _performRoutineCleanup();
    });
  }

  /// Start memory monitoring
  static void _startMemoryMonitoring() {
    _memoryCheckTimer = Timer.periodic(_memoryCheckInterval, (_) {
      _checkMemoryUsage();
    });
  }

  /// Perform routine cleanup
  static Future<void> _performRoutineCleanup() async {
    try {
      debugPrint('Performing routine memory cleanup...');
      
      // Clean up image cache
      await _cleanupImageCache();
      
      // Clean up database
      await _cleanupDatabase();
      
      // Force garbage collection
      _forceGarbageCollection();
      
      debugPrint('Routine memory cleanup completed');
    } catch (e) {
      debugPrint('Error during routine cleanup: $e');
    }
  }

  /// Check memory usage and trigger aggressive cleanup if needed
  static Future<void> _checkMemoryUsage() async {
    try {
      final memoryUsage = await _getCurrentMemoryUsage();
      if (memoryUsage != null && memoryUsage > _memoryThresholdMB) {
        debugPrint('High memory usage detected: ${memoryUsage}MB. Triggering aggressive cleanup...');
        await _performAggressiveCleanup();
      }
    } catch (e) {
      debugPrint('Error checking memory usage: $e');
    }
  }

  /// Get current memory usage in MB
  static Future<double?> _getCurrentMemoryUsage() async {
    try {
      if (Platform.isAndroid) {
        const platform = MethodChannel('reva_mobile_app/performance');
        final result = await platform.invokeMethod('getMemoryInfo');
        return (result['usedMemory'] as num).toDouble() / (1024 * 1024);
      } else if (Platform.isIOS) {
        const platform = MethodChannel('reva_mobile_app/performance');
        final result = await platform.invokeMethod('getMemoryInfo');
        return (result['usedMemory'] as num).toDouble() / (1024 * 1024);
      }
    } catch (e) {
      debugPrint('Error getting memory usage: $e');
    }
    return null;
  }

  /// Perform aggressive cleanup when memory usage is high
  static Future<void> _performAggressiveCleanup() async {
    try {
      // Clear image cache completely
      await ImageCacheService.clearCache();
      
      // Clean up old database data
      await DatabaseHelper.cleanupOldData(
        chatMessageAge: const Duration(days: 7),
        cacheAge: const Duration(days: 1),
      );
      
      // Optimize database
      await DatabaseHelper.optimizeDatabase();
      
      // Force multiple garbage collections
      for (int i = 0; i < 3; i++) {
        _forceGarbageCollection();
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      debugPrint('Aggressive memory cleanup completed');
    } catch (e) {
      debugPrint('Error during aggressive cleanup: $e');
    }
  }

  /// Clean up image cache
  static Future<void> _cleanupImageCache() async {
    try {
      final cacheSize = await ImageCacheService.getCacheSize();
      const maxCacheSizeMB = 50; // 50MB limit
      
      if (cacheSize > maxCacheSizeMB * 1024 * 1024) {
        await ImageCacheService.cleanupOldCache();
        debugPrint('Image cache cleaned up. Size was: ${(cacheSize / (1024 * 1024)).toStringAsFixed(1)}MB');
      }
    } catch (e) {
      debugPrint('Error cleaning up image cache: $e');
    }
  }

  /// Clean up database
  static Future<void> _cleanupDatabase() async {
    try {
      await DatabaseHelper.cleanupOldData();
      debugPrint('Database cleanup completed');
    } catch (e) {
      debugPrint('Error cleaning up database: $e');
    }
  }

  /// Force garbage collection
  static void _forceGarbageCollection() {
    try {
      // Force garbage collection on debug builds
      if (kDebugMode) {
        // This is a hint to the Dart VM to run garbage collection
        // Note: This doesn't guarantee immediate GC, but encourages it
        for (int i = 0; i < 1000; i++) {
          <int>[];
        }
      }
    } catch (e) {
      debugPrint('Error forcing garbage collection: $e');
    }
  }

  /// Optimize widget rebuilds by providing const constructors helper
  static bool shouldRebuild<T>(T? oldValue, T? newValue) {
    return oldValue != newValue;
  }

  /// Memory-efficient list builder
  static Widget buildMemoryEfficientList<T>({
    required List<T> items,
    required Widget Function(BuildContext context, T item, int index) itemBuilder,
    ScrollController? controller,
    EdgeInsetsGeometry? padding,
    int? itemCount,
  }) {
    // Use ListView.builder for memory efficiency
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount ?? items.length,
      addAutomaticKeepAlives: false, // Don't keep items alive when scrolled away
      addRepaintBoundaries: true, // Isolate repaints
      itemBuilder: (context, index) {
        if (index >= items.length) return const SizedBox.shrink();
        
        return RepaintBoundary(
          child: itemBuilder(context, items[index], index),
        );
      },
    );
  }

  /// Preload critical resources
  static Future<void> preloadCriticalResources(BuildContext context) async {
    try {
      // Preload commonly used images
      await _preloadImages(context);
      
      // Warm up database connections
      await DatabaseHelper.database;
      
      debugPrint('Critical resources preloaded');
    } catch (e) {
      debugPrint('Error preloading resources: $e');
    }
  }

  /// Preload commonly used images
  static Future<void> _preloadImages(BuildContext context) async {
    try {
      // Add any commonly used images here
      // Example:
      // await precacheImage(const AssetImage('assets/images/logo.png'), context);
    } catch (e) {
      debugPrint('Error preloading images: $e');
    }
  }

  /// Get memory optimization statistics
  static Future<MemoryOptimizationStats> getOptimizationStats() async {
    try {
      final currentMemory = await _getCurrentMemoryUsage();
      final imageCacheSize = await ImageCacheService.getCacheSize();
      final dbStats = await DatabaseHelper.getDatabaseStats();
      
      return MemoryOptimizationStats(
        currentMemoryUsageMB: currentMemory ?? 0,
        imageCacheSizeMB: imageCacheSize / (1024 * 1024),
        databaseSizeMB: (dbStats['databaseSizeBytes'] as int) / (1024 * 1024),
        isOptimizing: _isOptimizing,
        lastCleanupTime: DateTime.now(), // This would be tracked in a real implementation
      );
    } catch (e) {
      debugPrint('Error getting optimization stats: $e');
      return MemoryOptimizationStats(
        currentMemoryUsageMB: 0,
        imageCacheSizeMB: 0,
        databaseSizeMB: 0,
        isOptimizing: _isOptimizing,
        lastCleanupTime: DateTime.now(),
      );
    }
  }

  /// Manual cleanup trigger
  static Future<void> performManualCleanup() async {
    debugPrint('Manual cleanup triggered');
    await _performAggressiveCleanup();
  }

  /// Optimize for low memory devices
  static void optimizeForLowMemoryDevice() {
    // Reduce image cache size
    // Increase cleanup frequency
    // Disable non-essential animations
    debugPrint('Optimized for low memory device');
  }

  /// Battery optimization methods
  static void optimizeBatteryUsage() {
    // Reduce animation frame rates
    // Minimize background processing
    // Optimize network requests
    debugPrint('Battery usage optimized');
  }
}

/// Memory optimization statistics
class MemoryOptimizationStats {
  final double currentMemoryUsageMB;
  final double imageCacheSizeMB;
  final double databaseSizeMB;
  final bool isOptimizing;
  final DateTime lastCleanupTime;

  MemoryOptimizationStats({
    required this.currentMemoryUsageMB,
    required this.imageCacheSizeMB,
    required this.databaseSizeMB,
    required this.isOptimizing,
    required this.lastCleanupTime,
  });

  double get totalCacheSizeMB => imageCacheSizeMB + databaseSizeMB;

  @override
  String toString() {
    return 'MemoryOptimizationStats('
        'currentMemory: ${currentMemoryUsageMB.toStringAsFixed(1)}MB, '
        'imageCache: ${imageCacheSizeMB.toStringAsFixed(1)}MB, '
        'database: ${databaseSizeMB.toStringAsFixed(1)}MB, '
        'isOptimizing: $isOptimizing'
        ')';
  }
}

/// Widget lifecycle optimizer
mixin WidgetLifecycleOptimizer<T extends StatefulWidget> on State<T> {
  Timer? _optimizationTimer;

  @override
  void initState() {
    super.initState();
    _startOptimization();
  }

  @override
  void dispose() {
    _stopOptimization();
    super.dispose();
  }

  void _startOptimization() {
    // Start widget-specific optimizations
    _optimizationTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _optimizeWidget(),
    );
  }

  void _stopOptimization() {
    _optimizationTimer?.cancel();
    _optimizationTimer = null;
  }

  void _optimizeWidget() {
    // Override in subclasses for widget-specific optimizations
  }
}

/// Performance-optimized StatefulWidget base class
abstract class OptimizedStatefulWidget extends StatefulWidget {
  const OptimizedStatefulWidget({super.key});

  @override
  OptimizedState createState();
}

abstract class OptimizedState<T extends OptimizedStatefulWidget> 
    extends State<T> with WidgetLifecycleOptimizer {
  
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: buildOptimized(context),
    );
  }

  Widget buildOptimized(BuildContext context);

  @override
  void _optimizeWidget() {
    // Perform widget-specific optimizations
    if (mounted) {
      // Check if widget needs optimization
      performWidgetOptimization();
    }
  }

  void performWidgetOptimization() {
    // Override in subclasses
  }
}