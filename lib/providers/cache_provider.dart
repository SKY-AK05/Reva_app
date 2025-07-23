import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cache/cache_service.dart';

/// Provider for cache service instance
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheServiceImpl();
});

/// Provider for cache statistics
final cacheStatsProvider = FutureProvider<Map<String, CacheStats>>((ref) {
  final cacheService = ref.watch(cacheServiceProvider);
  return cacheService.getCacheStats();
});

/// Provider for cache size
final cacheSizeProvider = FutureProvider<int>((ref) {
  final cacheService = ref.watch(cacheServiceProvider);
  return cacheService.getCacheSize();
});

/// Provider for stale data detection
final staleDataProvider = FutureProvider.family<List<String>, Duration>((ref, maxAge) {
  final cacheService = ref.watch(cacheServiceProvider) as CacheServiceImpl;
  return cacheService.getStaleDataKeys(maxAge);
});

/// Cache management state
class CacheManagementState {
  final bool isPerformingMaintenance;
  final DateTime? lastMaintenanceTime;
  final int cacheSize;
  final Map<String, CacheStats> stats;
  final List<String> staleKeys;

  const CacheManagementState({
    this.isPerformingMaintenance = false,
    this.lastMaintenanceTime,
    this.cacheSize = 0,
    this.stats = const {},
    this.staleKeys = const [],
  });

  CacheManagementState copyWith({
    bool? isPerformingMaintenance,
    DateTime? lastMaintenanceTime,
    int? cacheSize,
    Map<String, CacheStats>? stats,
    List<String>? staleKeys,
  }) {
    return CacheManagementState(
      isPerformingMaintenance: isPerformingMaintenance ?? this.isPerformingMaintenance,
      lastMaintenanceTime: lastMaintenanceTime ?? this.lastMaintenanceTime,
      cacheSize: cacheSize ?? this.cacheSize,
      stats: stats ?? this.stats,
      staleKeys: staleKeys ?? this.staleKeys,
    );
  }
}

/// Cache management provider
class CacheManagementNotifier extends StateNotifier<CacheManagementState> {
  final CacheService _cacheService;
  
  CacheManagementNotifier(this._cacheService) : super(const CacheManagementState()) {
    _initializeCacheManagement();
  }

  Future<void> _initializeCacheManagement() async {
    await _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    try {
      final stats = await _cacheService.getCacheStats();
      final size = await _cacheService.getCacheSize();
      
      state = state.copyWith(
        stats: stats,
        cacheSize: size,
      );
    } catch (e) {
      // Handle error silently for now
    }
  }

  /// Perform cache maintenance tasks
  Future<void> performMaintenance() async {
    if (state.isPerformingMaintenance) return;

    state = state.copyWith(isPerformingMaintenance: true);

    try {
      final cacheServiceImpl = _cacheService as CacheServiceImpl;
      await cacheServiceImpl.performMaintenanceTasks();
      
      state = state.copyWith(
        lastMaintenanceTime: DateTime.now(),
      );
      
      // Reload stats after maintenance
      await _loadCacheStats();
    } catch (e) {
      // Handle error
    } finally {
      state = state.copyWith(isPerformingMaintenance: false);
    }
  }

  /// Clear all cache data
  Future<void> clearAllCache() async {
    try {
      await _cacheService.clearCache();
      await _loadCacheStats();
    } catch (e) {
      // Handle error
    }
  }

  /// Evict least recently used entries
  Future<void> evictLRU(int maxEntries) async {
    try {
      await _cacheService.evictLeastRecentlyUsed(maxEntries);
      await _loadCacheStats();
    } catch (e) {
      // Handle error
    }
  }

  /// Evict oldest entries
  Future<void> evictOldest(int maxEntries) async {
    try {
      await _cacheService.evictOldestEntries(maxEntries);
      await _loadCacheStats();
    } catch (e) {
      // Handle error
    }
  }

  /// Enforce storage limit
  Future<void> enforceStorageLimit(int maxSizeBytes) async {
    try {
      await _cacheService.enforceStorageLimit(maxSizeBytes);
      await _loadCacheStats();
    } catch (e) {
      // Handle error
    }
  }

  /// Refresh stale data
  Future<void> refreshStaleData(Duration maxAge) async {
    try {
      final cacheServiceImpl = _cacheService as CacheServiceImpl;
      final staleKeys = await cacheServiceImpl.getStaleDataKeys(maxAge);
      
      state = state.copyWith(staleKeys: staleKeys);
      
      // Mark stale data for refresh
      await cacheServiceImpl.markDataForRefresh(staleKeys);
      
      await _loadCacheStats();
    } catch (e) {
      // Handle error
    }
  }

  /// Get cache health score (0-100)
  int getCacheHealthScore() {
    if (state.stats.isEmpty) return 100;

    int score = 100;
    final now = DateTime.now();
    
    // Deduct points for expired entries
    final expiredCount = state.stats.values.where((stat) => stat.isExpired).length;
    score -= (expiredCount * 10).clamp(0, 30);
    
    // Deduct points for stale entries (older than 1 hour)
    final staleCount = state.stats.values.where((stat) => stat.isStale(const Duration(hours: 1))).length;
    score -= (staleCount * 5).clamp(0, 20);
    
    // Deduct points for large cache size (over 50 entries)
    if (state.cacheSize > 50) {
      score -= ((state.cacheSize - 50) * 2).clamp(0, 30);
    }
    
    return score.clamp(0, 100);
  }

  /// Check if maintenance is needed
  bool isMaintenanceNeeded() {
    final healthScore = getCacheHealthScore();
    final lastMaintenance = state.lastMaintenanceTime;
    
    // Maintenance needed if health score is low or it's been more than 24 hours
    return healthScore < 70 || 
           (lastMaintenance == null || 
            DateTime.now().difference(lastMaintenance) > const Duration(hours: 24));
  }
}

/// Provider for cache management
final cacheManagementProvider = StateNotifierProvider<CacheManagementNotifier, CacheManagementState>((ref) {
  final cacheService = ref.watch(cacheServiceProvider);
  return CacheManagementNotifier(cacheService);
});

/// Provider for cache health score
final cacheHealthProvider = Provider<int>((ref) {
  final cacheManagement = ref.watch(cacheManagementProvider.notifier);
  return cacheManagement.getCacheHealthScore();
});

/// Provider for maintenance needed status
final maintenanceNeededProvider = Provider<bool>((ref) {
  final cacheManagement = ref.watch(cacheManagementProvider.notifier);
  return cacheManagement.isMaintenanceNeeded();
});

/// Auto-maintenance provider that runs maintenance tasks periodically
final autoMaintenanceProvider = Provider<void>((ref) {
  final cacheManagement = ref.watch(cacheManagementProvider.notifier);
  final isMaintenanceNeeded = ref.watch(maintenanceNeededProvider);
  
  if (isMaintenanceNeeded) {
    // Schedule maintenance to run asynchronously
    Future.microtask(() => cacheManagement.performMaintenance());
  }
});