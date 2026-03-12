import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Safe URL launching with error handling and consistent mode for same-domain links.
/// Use for user-facing links so failures show "Could not open link" instead of system errors.
class UrlLauncherHelper {
  UrlLauncherHelper._();

  /// Whether [uri] is a waypoint.tours link (same-domain); use [LaunchMode.platformDefault] for these.
  static bool isWaypointTours(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'waypoint.tours' || host == 'www.waypoint.tours';
  }

  /// Launches [uri]. For waypoint.tours uses [LaunchMode.platformDefault];
  /// otherwise uses [mode] (default [LaunchMode.externalApplication]).
  /// On failure shows a SnackBar if [context] is provided and mounted.
  /// Returns true if the launch succeeded (or no exception), false otherwise.
  static Future<bool> launchUrlSafe(
    BuildContext? context,
    Uri uri, {
    LaunchMode? mode,
  }) async {
    final usePlatformDefault = isWaypointTours(uri);
    final effectiveMode = mode ??
        (usePlatformDefault
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication);

    try {
      final launched = await launchUrl(uri, mode: effectiveMode);
      if (!launched && context != null && context.mounted) {
        _showCouldNotOpenSnackBar(context, uri);
        return false;
      }
      return launched;
    } catch (_) {
      if (context != null && context.mounted) {
        _showCouldNotOpenSnackBar(context, uri);
      }
      return false;
    }
  }

  static void _showCouldNotOpenSnackBar(BuildContext context, Uri uri) {
    final urlString = uri.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Could not open link'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: urlString));
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link copied to clipboard')),
            );
          },
        ),
      ),
    );
  }
}
