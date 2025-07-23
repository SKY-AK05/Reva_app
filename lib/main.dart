import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/navigation_exports.dart';
import 'providers/providers.dart';
import 'services/performance/performance_monitor.dart';
import 'services/performance/memory_optimizer.dart';
import 'services/performance/performance_analytics.dart';
import 'services/storage/database_initialization_service.dart';
import 'services/storage/storage_permission_service.dart';
// Add these imports for sqflite FFI
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite FFI for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded successfully');
  } catch (e) {
    print('⚠️  Could not load .env file: $e');
    print('📝 Using default environment values');
  }
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  // Initialize database with proper permission handling
  try {
    print('🗄️  Initializing database...');
    final dbInitialized = await DatabaseInitializationService.initializeDatabase();
    if (dbInitialized) {
      print('✅ Database initialized successfully');
    } else {
      print('⚠️  Database initialization failed - app will work with limited offline functionality');
    }
  } catch (e) {
    print('❌ Database initialization error: $e');
    print('📱 App will continue with online-only functionality');
  }
  
  // Initialize performance services
  PerformanceMonitor.startMonitoring();
  MemoryOptimizer.startOptimization();
  PerformanceAnalytics.startCollection();
  
  runApp(
    const ProviderScope(
      child: RevaApp(),
    ),
  );
}

class RevaApp extends ConsumerWidget {
  const RevaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Reva',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}