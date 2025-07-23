import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/connectivity/connectivity_service.dart';

/// Global offline indicator that shows when the device is offline
class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityStatus = ref.watch(connectivityStatusProvider);
    
    return connectivityStatus.when(
      data: (isConnected) {
        if (isConnected) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                color: Theme.of(context).colorScheme.onError,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'You\'re offline',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onError,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Offline banner that can be shown at the top of screens
class OfflineBanner extends ConsumerWidget {
  final Widget child;
  
  const OfflineBanner({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const OfflineIndicator(),
        Expanded(child: child),
      ],
    );
  }
}

/// Connectivity status chip for detailed information
class ConnectivityStatusChip extends ConsumerWidget {
  const ConnectivityStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityStatus = ref.watch(connectivityStatusProvider);
    final connectivityInfo = ref.watch(connectivityInfoProvider);
    
    return connectivityStatus.when(
      data: (isConnected) {
        return connectivityInfo.when(
          data: (info) {
            return Chip(
              avatar: Icon(
                _getConnectionIcon(info.connectionType, isConnected),
                size: 16,
                color: _getConnectionColor(context, isConnected),
              ),
              label: Text(
                _getConnectionText(info, isConnected),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getConnectionColor(context, isConnected),
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: _getConnectionColor(context, isConnected).withOpacity(0.1),
              side: BorderSide(
                color: _getConnectionColor(context, isConnected).withOpacity(0.3),
              ),
            );
          },
          loading: () => Chip(
            avatar: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            label: Text(
              'Checking...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          error: (_, __) => Chip(
            avatar: Icon(
              Icons.error_outline,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
            label: Text(
              'Unknown',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        );
      },
      loading: () => const Chip(
        avatar: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text('Loading...'),
      ),
      error: (_, __) => Chip(
        avatar: Icon(
          Icons.error_outline,
          size: 16,
          color: Theme.of(context).colorScheme.error,
        ),
        label: const Text('Error'),
      ),
    );
  }

  IconData _getConnectionIcon(ConnectivityType type, bool isConnected) {
    if (!isConnected) return Icons.cloud_off;
    
    switch (type) {
      case ConnectivityType.wifi:
        return Icons.wifi;
      case ConnectivityType.mobile:
        return Icons.signal_cellular_4_bar;
      case ConnectivityType.ethernet:
        return Icons.wifi; // Use wifi icon as fallback for ethernet
      case ConnectivityType.none:
        return Icons.cloud_off;
      case ConnectivityType.unknown:
        return Icons.help_outline;
    }
  }

  Color _getConnectionColor(BuildContext context, bool isConnected) {
    if (!isConnected) {
      return Theme.of(context).colorScheme.error;
    }
    return Theme.of(context).colorScheme.primary;
  }

  String _getConnectionText(ConnectivityInfo info, bool isConnected) {
    if (!isConnected) return 'Offline';
    
    if (!info.hasInternet) {
      return 'Limited Connection';
    }
    
    switch (info.connectionType) {
      case ConnectivityType.wifi:
        return 'Wi-Fi';
      case ConnectivityType.mobile:
        return 'Mobile Data';
      case ConnectivityType.ethernet:
        return 'Ethernet';
      case ConnectivityType.none:
        return 'No Connection';
      case ConnectivityType.unknown:
        return 'Connected';
    }
  }
}

/// Reconnection button for manual retry
class ReconnectionButton extends ConsumerWidget {
  final VoidCallback? onPressed;
  
  const ReconnectionButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityStatus = ref.watch(connectivityStatusProvider);
    
    return connectivityStatus.when(
      data: (isConnected) {
        if (isConnected) {
          return const SizedBox.shrink();
        }
        
        return ElevatedButton.icon(
          onPressed: () {
            // Refresh connectivity providers
            ref.invalidate(connectivityInfoProvider);
            ref.invalidate(networkQualityProvider);
            onPressed?.call();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}