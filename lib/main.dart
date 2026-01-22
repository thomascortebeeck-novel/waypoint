import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'nav.dart';
import 'package:waypoint/integrations/offline_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:waypoint/utils/logger.dart';
import 'package:waypoint/integrations/mapbox_config.dart';
import 'package:waypoint/providers/theme_provider.dart';

/// Configure global image cache for better performance
void _configureImageCache() {
  // Set maximum number of images to keep in memory cache
  PaintingBinding.instance.imageCache.maximumSize = 100;
  
  // Set maximum size of memory cache (50 MB)
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;
  
  Log.i('bootstrap', 'Image cache configured: 100 images, 50MB max');
}

/// Main entry point for the application
///
/// This sets up:
/// - Firebase initialization
/// - Provider state management
/// - go_router navigation
/// - Material 3 theming with light/dark modes
/// - Global image caching configuration
Future<void> main() async {
  try {
    // IMPORTANT: Keep bindings and runApp in the SAME zone to avoid web zone mismatch.
    WidgetsFlutterBinding.ensureInitialized();
    Log.i('bootstrap', 'Widgets binding initialized');
    
    // Configure global image cache for better performance
    _configureImageCache();

    // Global Flutter error hook (safe to reassign on hot restart)
    FlutterError.onError = (FlutterErrorDetails details) {
      Log.e('flutter', 'FlutterError.onError', details.exception, details.stack);
    };

    // PlatformDispatcher hook for uncaught async errors (safe to reassign on hot restart)
    PlatformDispatcher.instance.onError = (error, stack) {
      Log.e('uncaught', 'PlatformDispatcher caught', error, stack);
      return true; // handled
    };

    // Print environment snapshot (safe, no secrets)
    Log.i('env', 'kIsWeb=$kIsWeb, platform=${defaultTargetPlatform.name}');
    Log.i('env', 'hasValidMapboxToken=$hasValidMapboxToken, styleUri=$mapboxStyleUri');

    // Initialize Firebase (idempotent - safe for hot restart)
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      Log.i('bootstrap', 'Firebase initialized (fresh)');
    } catch (e) {
      if (e.toString().contains('duplicate-app')) {
        Log.i('bootstrap', 'Firebase already initialized (hot restart)');
      } else {
        rethrow;
      }
    }

    // Initialize offline tiles cache (no-op on web)
    await OfflineTilesManager().initialize();
    Log.i('bootstrap', 'OfflineTilesManager initialized');

    Log.i('bootstrap', '✓ App startup complete, launching UI');
    runApp(const MyApp());
  } catch (e, stack) {
    Log.e('bootstrap', 'Fatal error during app initialization', e, stack);
    // Show a minimal error UI if initialization fails completely
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text('App initialization failed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('$e', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    ));
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'Waypoint',
            debugShowCheckedModeBanner: false,

            // Theme configuration with user preference
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.themeMode,

            // Use context.go() or context.push() to navigate to the routes.
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
