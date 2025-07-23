import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../services/auth/auth_exports.dart';
import '../services/connectivity/connectivity_service.dart';

// Export data providers
export '../providers/tasks_provider.dart';
export '../providers/expenses_provider.dart';
export '../providers/reminders_provider.dart';
export '../providers/error_provider.dart';
export '../providers/feedback_provider.dart';
export '../providers/cache_provider.dart';

// Connectivity Service Provider
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

// Connectivity Provider
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged;
});

// Enhanced Connectivity Status Provider
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.connectivityStream;
});

// Connectivity Info Provider
final connectivityInfoProvider = FutureProvider<ConnectivityInfo>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.getConnectivityInfo();
});

// Network Quality Provider
final networkQualityProvider = FutureProvider<NetworkQuality>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.estimateNetworkQuality();
});

// Supabase Client Provider
final supabaseClientProvider = Provider((ref) {
  return SupabaseConfig.client;
});

// Theme Mode Provider
final themeModeProvider = StateProvider<bool>((ref) {
  // Default to dark theme (false = light, true = dark)
  return true;
});

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthRepository(authService);
});

// Session Manager Provider
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final authService = ref.watch(authServiceProvider);
  return SessionManager(authService);
});

// Auth State Provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Current User Provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) => state.session?.user,
    loading: () => null,
    error: (_, __) => null,
  );
});

// Authentication Status Provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

// Authentication Loading Provider
final authLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.isLoading;
});