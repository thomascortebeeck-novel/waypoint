/// Layout constants shared across the app.
/// Ensures consistent max-width constraints on desktop/tablet.
class LayoutTokens {
  LayoutTokens._();

  /// Maximum width for form/content columns on desktop.
  /// Matches best-practice web form UX (AllTrails, Notion, Linear style).
  static const double formMaxWidth = 600;

  /// Maximum width for full-page content (e.g. itinerary panels, review screens).
  static const double pageMaxWidth = 800;
}
