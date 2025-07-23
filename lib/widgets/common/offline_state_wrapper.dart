import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

/// Wrapper widget that provides offline state management for screens
class OfflineStateWrapper extends ConsumerWidget {
  final Widget child;
  final Widget? offlineChild;
  final bool showOfflineBanner;
  final VoidCallback? onRetry;
  final String? offlineMessage;

  const OfflineStateWrapper({
    super.key,
    required this.child,
    this.offlineChild,
    this.showOfflineBanner = true,
    this.onRetry,
    this.offlineMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityStatus = ref.watch(connectivityStatusProvider);
    
    return connectivityStatus.when(
      data: (isConnected) {
        if (isConnected) {
          return child;
        }
        
        // Show offline state
        return Column(
          children: [
            if (showOfflineBanner) _buildOfflineBanner(context),
            Expanded(
              child: offlineChild ?? _buildDefaultOfflineState(context),
            ),
          ],
        );
      },
      loading: () => child, // Show normal state while loading connectivity
      error: (_, __) => child, // Show normal state on connectivity error
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.error.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              offlineMessage ?? 'You\'re offline. Some features may be limited.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDefaultOfflineState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'You\'re Offline',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              offlineMessage ?? 'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Offline-aware list widget that shows cached data with offline indicators
class OfflineAwareList<T> extends ConsumerWidget {
  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final Widget? emptyWidget;
  final String? emptyMessage;
  final VoidCallback? onRefresh;
  final bool showOfflineIndicators;
  final DateTime? lastSyncTime;

  const OfflineAwareList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.emptyWidget,
    this.emptyMessage,
    this.onRefresh,
    this.showOfflineIndicators = true,
    this.lastSyncTime,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityStatus = ref.watch(connectivityStatusProvider);
    
    return connectivityStatus.when(
      data: (isConnected) {
        if (items.isEmpty) {
          return _buildEmptyState(context, isConnected);
        }

        return Column(
          children: [
            if (!isConnected && showOfflineIndicators)
              _buildOfflineDataBanner(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (isConnected && onRefresh != null) {
                    onRefresh!();
                  }
                },
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _buildListItem(context, items[index], index, isConnected);
                  },
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildErrorState(context),
    );
  }

  Widget _buildListItem(BuildContext context, T item, int index, bool isConnected) {
    Widget listItem = itemBuilder(context, item, index);
    
    if (!isConnected && showOfflineIndicators) {
      // Add subtle offline indicator to list items
      listItem = Stack(
        children: [
          listItem,
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Icon(
                Icons.cloud_off,
                size: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ],
      );
    }
    
    return listItem;
  }

  Widget _buildOfflineDataBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cached,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lastSyncTime != null
                  ? 'Showing cached data (last updated ${_formatLastSync(lastSyncTime!)})'
                  : 'Showing cached data',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isConnected) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isConnected ? Icons.inbox : Icons.cloud_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              isConnected 
                  ? (emptyMessage ?? 'No items found')
                  : 'No cached data available',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            if (!isConnected) ...[
              const SizedBox(height: 8),
              Text(
                'Connect to the internet to load your data',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to check connectivity status',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Offline-aware form wrapper that disables form submission when offline
class OfflineAwareForm extends ConsumerWidget {
  final Widget child;
  final VoidCallback? onSubmit;
  final String? offlineMessage;

  const OfflineAwareForm({
    super.key,
    required this.child,
    this.onSubmit,
    this.offlineMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityStatus = ref.watch(connectivityStatusProvider);
    
    return connectivityStatus.when(
      data: (isConnected) {
        return Column(
          children: [
            if (!isConnected) _buildOfflineFormBanner(context),
            Expanded(
              child: AbsorbPointer(
                absorbing: !isConnected,
                child: Opacity(
                  opacity: isConnected ? 1.0 : 0.6,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }

  Widget _buildOfflineFormBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.error.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_off,
            color: Theme.of(context).colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              offlineMessage ?? 'Form editing is disabled while offline',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}