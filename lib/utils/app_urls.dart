import 'package:flutter/foundation.dart' show kIsWeb;

/// Shared helpers for web app URLs. On web uses current origin; on mobile uses production URL.
/// Used when opening the web app from iOS/Android (e.g. "Buy on web" to avoid store commission).
class AppUrls {
  AppUrls._();

  static const String _productionBaseUrl = 'https://www.waypoint.tours';

  /// Base URL of the web app. On web = current origin; on mobile = production.
  static String getWebAppBaseUrl() {
    if (kIsWeb) {
      final uri = Uri.base;
      return '${uri.scheme}://${uri.host}${uri.port != 80 && uri.port != 443 ? ':${uri.port}' : ''}';
    }
    return _productionBaseUrl;
  }

  /// Plan details page on web (user can tap Buy there for in-web checkout).
  static String getPlanDetailsWebUrl(String planId) {
    return '${getWebAppBaseUrl()}/details/$planId';
  }

  /// Join trip invite URL (share link for inviting others to a trip).
  static String getJoinTripUrl(String inviteCode) {
    return '${getWebAppBaseUrl()}/join/$inviteCode';
  }

  /// Checkout page on web (direct checkout URL).
  static String getCheckoutWebUrl(String planId) {
    return '${getWebAppBaseUrl()}/checkout/$planId';
  }

  /// Plan details URL with optional invite params for join flow (preserve context after purchase on web).
  static String getPlanDetailsWebUrlWithParams(
    String planId, {
    String? inviteCode,
    bool returnToJoin = false,
  }) {
    final base = getPlanDetailsWebUrl(planId);
    if (inviteCode == null || inviteCode.isEmpty) return base;
    final params = <String>['inviteCode=${Uri.encodeQueryComponent(inviteCode)}'];
    if (returnToJoin) params.add('returnToJoin=1');
    return '$base?${params.join('&')}';
  }

  /// Checkout URL with optional invite params (for redirect after success).
  static String getCheckoutWebUrlWithParams(
    String planId, {
    String? inviteCode,
    bool returnToJoin = false,
  }) {
    final base = getCheckoutWebUrl(planId);
    if (inviteCode == null || inviteCode.isEmpty) return base;
    final params = <String>['inviteCode=${Uri.encodeQueryComponent(inviteCode)}'];
    if (returnToJoin) params.add('returnToJoin=1');
    return '$base?${params.join('&')}';
  }
}
