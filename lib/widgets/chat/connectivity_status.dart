import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/chat_provider.dart';
import '../../providers/providers.dart';
import '../../services/connectivity/connectivity_service.dart';

class ConnectivityStatus extends ConsumerStatefulWidget {
  const ConnectivityStatus({super.key});

  @override
  ConsumerState<ConnectivityStatus> createState() => _ConnectivityStatusState();
}

class _ConnectivityStatusState extends ConsumerState<ConnectivityStatus> {
  ConnectivityInfo? _connectivityInfo;
  NetworkQuality? _networkQuality;

  @override
  void initState() {
    super.initState();
    _loadConnectivityInfo();
  }

  Future<void> _loadConnectivityInfo() async {
    // Invalidate providers to force refresh
    ref.invalidate(connectivityInfoProvider);
    ref.invalidate(networkQualityProvider);
    
    final connectivityService = ref.read(connectivityServiceProvider);
    final info = await connectivityService.getConnectivityInfo();
    final quality = await connectivityService.estimateNetworkQuality();
    
    if (mounted) {
      setState(() {
        _connectivityInfo = info;
        _networkQuality = quality;
      });
    }
  }

  Future<void> _forceReconnection() async {
    final connectivityService = ref.read(connectivityServiceProvider);
    await connectivityService.forceReconnectionCheck();
    await _loadConnectivityInfo();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getConnectivityIcon(),
                  color: _getConnectivityColor(context),
                ),
                const SizedBox(width: 8),
                Text(
                  'Connection Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadConnectivityInfo,
                  icon: const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
              context,
              'Status',
              chatState.isOffline ? 'Offline' : 'Online',
              chatState.isOffline ? Colors.red : Colors.green,
            ),
            if (_connectivityInfo != null) ...[
              _buildStatusRow(
                context,
                'Connection Type',
                _getConnectionTypeText(_connectivityInfo!.connectionType),
                null,
              ),
              _buildStatusRow(
                context,
                'Internet Access',
                _connectivityInfo!.hasInternet ? 'Available' : 'Limited',
                _connectivityInfo!.hasInternet ? Colors.green : Colors.orange,
              ),
            ],
            if (_networkQuality != null)
              _buildStatusRow(
                context,
                'Network Quality',
                _getNetworkQualityText(_networkQuality!),
                _getNetworkQualityColor(_networkQuality!),
              ),
            if (chatState.unsyncedMessages.isNotEmpty) ...[
              const Divider(),
              _buildStatusRow(
                context,
                'Pending Messages',
                '${chatState.unsyncedMessages.length}',
                Colors.orange,
              ),
            ],
            if (chatState.lastSyncTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last sync: ${_formatLastSync(chatState.lastSyncTime!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
            if (chatState.isOffline) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _forceReconnection,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try to Reconnect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getConnectivityIcon() {
    final chatState = ref.read(chatProvider);
    if (chatState.isOffline) return Icons.cloud_off;
    
    if (_connectivityInfo?.connectionType == ConnectivityType.wifi) {
      return Icons.wifi;
    } else if (_connectivityInfo?.connectionType == ConnectivityType.mobile) {
      return Icons.signal_cellular_4_bar;
    } else {
      return Icons.cloud_done;
    }
  }

  Color _getConnectivityColor(BuildContext context) {
    final chatState = ref.read(chatProvider);
    if (chatState.isOffline) {
      return Theme.of(context).colorScheme.error;
    }
    return Theme.of(context).colorScheme.primary;
  }

  String _getConnectionTypeText(ConnectivityType type) {
    switch (type) {
      case ConnectivityType.wifi:
        return 'Wi-Fi';
      case ConnectivityType.mobile:
        return 'Mobile Data';
      case ConnectivityType.ethernet:
        return 'Ethernet';
      case ConnectivityType.none:
        return 'No Connection';
      case ConnectivityType.unknown:
        return 'Unknown';
    }
  }

  String _getNetworkQualityText(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return 'Excellent';
      case NetworkQuality.good:
        return 'Good';
      case NetworkQuality.fair:
        return 'Fair';
      case NetworkQuality.poor:
        return 'Poor';
      case NetworkQuality.unknown:
        return 'Unknown';
    }
  }

  Color _getNetworkQualityColor(NetworkQuality quality) {
    switch (quality) {
      case NetworkQuality.excellent:
        return Colors.green;
      case NetworkQuality.good:
        return Colors.lightGreen;
      case NetworkQuality.fair:
        return Colors.orange;
      case NetworkQuality.poor:
        return Colors.red;
      case NetworkQuality.unknown:
        return Colors.grey;
    }
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}