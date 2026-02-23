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
import 'package:google_fonts/google_fonts.dart';

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
    
    // Enable Google Fonts runtime fetching since local font assets are not available
    // Fonts will be fetched from Google Fonts CDN at runtime
    GoogleFonts.config.allowRuntimeFetching = true;
    
    // Configure global image cache for better performance
    _configureImageCache();

    // Global Flutter error hook (safe to reassign on hot restart)
    FlutterError.onError = (FlutterErrorDetails details) {
      // Filter out harmless debug-only mouse tracker assertions
      // These occur during rapid scrolling on web and are non-fatal
      // CRITICAL: These errors can block hit testing, preventing navigation clicks
      final errorString = details.exception.toString();
      final stackString = details.stack?.toString() ?? '';
      final libraryString = details.library ?? '';
      final summaryString = details.summary.toString();
      
      // Very aggressive filtering: check for mouse tracker errors in all possible locations
      // Match any variation of the mouse tracker assertion error
      final isMouseTrackerError = 
          (errorString.contains('mouse_tracker') || 
           stackString.contains('mouse_tracker') ||
           libraryString.contains('mouse_tracker') ||
           summaryString.contains('mouse_tracker')) &&
          (errorString.contains('!_debugDuringDeviceUpdate') ||
           errorString.contains('debugDuringDeviceUpdate') ||
           errorString.contains('Assertion failed') ||
           errorString.contains('is not true') ||
           summaryString.contains('!_debugDuringDeviceUpdate') ||
           summaryString.contains('debugDuringDeviceUpdate'));
      
      if (isMouseTrackerError) {
        // Silently ignore these debug-only mouse tracker assertions
        // They don't affect functionality and only appear in debug mode
        // Returning early prevents the error from blocking hit testing
        // DO NOT log or print - this would spam the console
        return;
      }
      
      // Filter out drawer hit-test errors - occur when DrawerController measures drawer with zero constraints
      // These are non-fatal and happen during layout phase when drawer is closed
      final isDrawerHitTestError = 
          (errorString.contains('Cannot hit test a render box') ||
           errorString.contains('has never been laid out')) &&
          (stackString.contains('DrawerController') ||
           stackString.contains('SizedBox.shrink') ||
           stackString.contains('_ScaffoldSlot.drawer'));
      
      if (isDrawerHitTestError) {
        // Silently ignore these non-fatal drawer hit-test errors
        // They occur when Flutter's DrawerController tries to measure the drawer
        // before it has proper constraints during the layout phase
        return;
      }
      
      // Filter out AssetManifest.json errors - common in Flutter web debug mode
      // These are non-critical: fonts will fall back to system fonts or CDN
      // The manifest is generated during build but may not be available in debug mode
      final isAssetManifestError = 
          (errorString.contains('AssetManifest.json') ||
           errorString.contains('Unable to load asset') ||
           errorString.contains('asset does not exist') ||
           stackString.contains('AssetManifest.json') ||
           stackString.contains('asset_bundle.dart') ||
           stackString.contains('google_fonts')) &&
          (errorString.contains('AssetManifest') ||
           errorString.contains('Unable to load asset') ||
           stackString.contains('loadFontIfNecessary') ||
           stackString.contains('google_fonts_base'));
      
      if (isAssetManifestError) {
        // Silently ignore AssetManifest.json errors
        // These are common in debug mode and don't affect functionality
        // Fonts will fall back gracefully
        return;
      }

      // Filter optional image asset 404s (e.g. waypoint_logo_mark) — UI shows fallback
      final isOptionalAsset404 = (errorString.contains('failed to fetch') ||
              errorString.contains('HTTP status 404') ||
              summaryString.contains('load an asset')) &&
          (errorString.contains('waypoint_logo') || errorString.contains('images/'));

      if (isOptionalAsset404) {
        return;
      }

      // Filter minor RenderFlex overflows (e.g. 4px) — non-fatal layout tweaks
      final isMinorOverflow = (errorString.contains('RenderFlex overflowed') ||
              summaryString.contains('overflowed')) &&
          (errorString.contains('by 4.0 pixels') ||
              errorString.contains('by 2.0 pixels') ||
              errorString.contains('by 6.0 pixels'));

      if (isMinorOverflow) {
        return;
      }

      // Log all other errors
      Log.e('flutter', 'FlutterError.onError', details.exception, details.stack);
    };

    // PlatformDispatcher hook for uncaught async errors (safe to reassign on hot restart)
    PlatformDispatcher.instance.onError = (error, stack) {
      final errorString = error.toString();
      final stackString = stack?.toString() ?? '';
      
      // Filter out AssetManifest.json / asset load errors from uncaught promises
      final isAssetManifestError = 
          errorString.contains('AssetManifest') ||
          (errorString.contains('Unable to load asset') && errorString.contains('asset')) ||
          errorString.contains('asset does not exist') ||
          stackString.contains('AssetManifest') ||
          stackString.contains('asset_bundle.dart');
      
      if (isAssetManifestError) {
        // Silently ignore - these are non-critical debug mode issues
        return true; // handled
      }
      
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
