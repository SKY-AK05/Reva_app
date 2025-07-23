import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring network connectivity
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectivityController;
  StreamController<ConnectivityEvent>? _eventController;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isConnected = true;
  bool _wasOffline = false;
  Timer? _connectivityCheckTimer;
  Timer? _reconnectionTimer;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 5;

  /// Stream of connectivity status
  Stream<bool> get connectivityStream {
    _connectivityController ??= StreamController<bool>.broadcast();
    _startListening();
    return _connectivityController!.stream;
  }

  /// Stream of connectivity events (connection/disconnection events)
  Stream<ConnectivityEvent> get connectivityEventStream {
    _eventController ??= StreamController<ConnectivityEvent>.broadcast();
    return _eventController!.stream;
  }

  /// Current connectivity status
  bool get isConnected => _isConnected;

  /// Number of reconnection attempts made
  int get reconnectionAttempts => _reconnectionAttempts;

  /// Start listening to connectivity changes
  void _startListening() {
    if (_connectivitySubscription != null) return;

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        print('Connectivity stream error: $error');
      },
    );

    // Initial connectivity check
    _checkInitialConnectivity();

    // Periodic connectivity verification
    _startPeriodicCheck();
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    final hasConnection = result != ConnectivityResult.none;

    if (hasConnection) {
      // Verify actual internet connectivity
      _verifyInternetConnection();
    } else {
      _updateConnectivityStatus(false);
    }
  }

  /// Check initial connectivity status
  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _onConnectivityChanged(result);
    } catch (e) {
      print('Error checking initial connectivity: $e');
      _updateConnectivityStatus(false);
    }
  }

  /// Verify actual internet connection by attempting to reach a reliable host
  Future<void> _verifyInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      final hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _updateConnectivityStatus(hasInternet);
    } catch (e) {
      _updateConnectivityStatus(false);
    }
  }

  /// Start periodic connectivity checks
  void _startPeriodicCheck() {
    _connectivityCheckTimer?.cancel();
    _connectivityCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _verifyInternetConnection(),
    );
  }

  /// Update connectivity status and notify listeners
  void _updateConnectivityStatus(bool isConnected) {
    if (_isConnected != isConnected) {
      final previousState = _isConnected;
      _isConnected = isConnected;
      _connectivityController?.add(isConnected);
      
      // Handle reconnection logic
      if (isConnected && !previousState) {
        _onReconnected();
      } else if (!isConnected && previousState) {
        _onDisconnected();
      }
      
      // Emit connectivity event
      _eventController?.add(ConnectivityEvent(
        isConnected: isConnected,
        timestamp: DateTime.now(),
        connectionType: isConnected ? null : ConnectivityType.none,
      ));
      
      print('Connectivity status changed: ${isConnected ? 'Connected' : 'Disconnected'}');
    }
  }

  /// Handle disconnection event
  void _onDisconnected() {
    _wasOffline = true;
    _startReconnectionAttempts();
  }

  /// Handle reconnection event
  void _onReconnected() {
    if (_wasOffline) {
      _wasOffline = false;
      _reconnectionAttempts = 0;
      _reconnectionTimer?.cancel();
      
      _eventController?.add(ConnectivityEvent(
        isConnected: true,
        timestamp: DateTime.now(),
        connectionType: null,
        isReconnection: true,
      ));
      
      print('Successfully reconnected after $_reconnectionAttempts attempts');
    }
  }

  /// Start automatic reconnection attempts
  void _startReconnectionAttempts() {
    _reconnectionTimer?.cancel();
    _reconnectionAttempts = 0;
    
    _reconnectionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _attemptReconnection(),
    );
  }

  /// Attempt to reconnect
  Future<void> _attemptReconnection() async {
    if (_reconnectionAttempts >= _maxReconnectionAttempts) {
      _reconnectionTimer?.cancel();
      print('Max reconnection attempts reached');
      return;
    }

    _reconnectionAttempts++;
    print('Reconnection attempt $_reconnectionAttempts/$_maxReconnectionAttempts');

    try {
      final result = await _connectivity.checkConnectivity();
      if (result != ConnectivityResult.none) {
        await _verifyInternetConnection();
      }
    } catch (e) {
      print('Reconnection attempt failed: $e');
    }
  }

  /// Manually trigger reconnection check
  Future<void> forceReconnectionCheck() async {
    print('Manual reconnection check triggered');
    await _checkInitialConnectivity();
  }

  /// Check if a specific host is reachable
  Future<bool> canReachHost(String host, {int port = 80, Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if the API server is reachable
  Future<bool> canReachAPI(String apiUrl) async {
    try {
      final uri = Uri.parse(apiUrl);
      final host = uri.host;
      final port = uri.port != 0 ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      
      return await canReachHost(host, port: port);
    } catch (e) {
      return false;
    }
  }

  /// Get detailed connectivity information
  Future<ConnectivityInfo> getConnectivityInfo() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final hasConnection = result != ConnectivityResult.none;
      
      if (!hasConnection) {
        return ConnectivityInfo(
          isConnected: false,
          connectionType: ConnectivityType.none,
          hasInternet: false,
        );
      }

      // Determine primary connection type
      ConnectivityType connectionType = ConnectivityType.unknown;
      if (result == ConnectivityResult.wifi) {
        connectionType = ConnectivityType.wifi;
      } else if (result == ConnectivityResult.mobile) {
        connectionType = ConnectivityType.mobile;
      } else if (result == ConnectivityResult.ethernet) {
        connectionType = ConnectivityType.ethernet;
      }

      // Verify internet connectivity
      final hasInternet = await _hasInternetConnection();

      return ConnectivityInfo(
        isConnected: hasConnection,
        connectionType: connectionType,
        hasInternet: hasInternet,
      );
    } catch (e) {
      return ConnectivityInfo(
        isConnected: false,
        connectionType: ConnectivityType.unknown,
        hasInternet: false,
      );
    }
  }

  /// Check if there's actual internet connectivity
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get network quality estimation
  Future<NetworkQuality> estimateNetworkQuality() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Test connection to a reliable host
      final socket = await Socket.connect('google.com', 80, timeout: const Duration(seconds: 10));
      socket.destroy();
      
      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      if (latency < 100) {
        return NetworkQuality.excellent;
      } else if (latency < 300) {
        return NetworkQuality.good;
      } else if (latency < 1000) {
        return NetworkQuality.fair;
      } else {
        return NetworkQuality.poor;
      }
    } catch (e) {
      return NetworkQuality.unknown;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController?.close();
    _eventController?.close();
    _connectivityCheckTimer?.cancel();
    _reconnectionTimer?.cancel();
  }
}

/// Connectivity information
class ConnectivityInfo {
  final bool isConnected;
  final ConnectivityType connectionType;
  final bool hasInternet;

  const ConnectivityInfo({
    required this.isConnected,
    required this.connectionType,
    required this.hasInternet,
  });

  @override
  String toString() {
    return 'ConnectivityInfo(isConnected: $isConnected, type: $connectionType, hasInternet: $hasInternet)';
  }
}

/// Types of network connections
enum ConnectivityType {
  wifi,
  mobile,
  ethernet,
  none,
  unknown,
}

/// Network quality levels
enum NetworkQuality {
  excellent,
  good,
  fair,
  poor,
  unknown,
}

/// Connectivity event information
class ConnectivityEvent {
  final bool isConnected;
  final DateTime timestamp;
  final ConnectivityType? connectionType;
  final bool isReconnection;

  const ConnectivityEvent({
    required this.isConnected,
    required this.timestamp,
    this.connectionType,
    this.isReconnection = false,
  });

  @override
  String toString() {
    return 'ConnectivityEvent(isConnected: $isConnected, timestamp: $timestamp, type: $connectionType, isReconnection: $isReconnection)';
  }
}