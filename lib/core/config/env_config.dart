import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // Supabase Configuration
  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ?? 
           const String.fromEnvironment(
             'SUPABASE_URL',
             defaultValue: 'https://jjjrstmydcvimasfkdxw.supabase.co',
           );
  }
  
  static String get supabaseAnonKey {
    return dotenv.env['SUPABASE_ANON_KEY'] ?? 
           const String.fromEnvironment(
             'SUPABASE_ANON_KEY',
             defaultValue: 'your-anon-key',
           );
  }
  
  // API Configuration
  static String get apiBaseUrl {
    return dotenv.env['API_BASE_URL'] ?? 
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: 'https://reva-backend-8bcr.onrender.com/api/v1/chat',
           );
  }
  
  // Environment
  static String get environment {
    return dotenv.env['ENVIRONMENT'] ?? 
           const String.fromEnvironment(
             'ENVIRONMENT',
             defaultValue: 'development',
           );
  }
  
  // Debug settings
  static bool get debugMode {
    return dotenv.env['DEBUG_MODE'] == 'true' || 
           const bool.fromEnvironment('DEBUG_MODE', defaultValue: true);
  }
  
  static String get logLevel {
    return dotenv.env['LOG_LEVEL'] ?? 
           const String.fromEnvironment('LOG_LEVEL', defaultValue: 'info');
  }
  
  // Feature flags
  static bool get enablePushNotifications {
    return dotenv.env['ENABLE_PUSH_NOTIFICATIONS'] != 'false' && 
           const bool.fromEnvironment('ENABLE_PUSH_NOTIFICATIONS', defaultValue: true);
  }
  
  static bool get enableOfflineMode {
    return dotenv.env['ENABLE_OFFLINE_MODE'] != 'false' && 
           const bool.fromEnvironment('ENABLE_OFFLINE_MODE', defaultValue: true);
  }
  
  static bool get enablePerformanceMonitoring {
    return dotenv.env['ENABLE_PERFORMANCE_MONITORING'] != 'false' && 
           const bool.fromEnvironment('ENABLE_PERFORMANCE_MONITORING', defaultValue: true);
  }
  
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';
}