// Conditional export for web vs non-web platforms
// Web uses Mapbox GL JS for full custom style support
// Mobile uses native Mapbox SDK (handled elsewhere)
export 'mapbox_web_widget_stub.dart'
    if (dart.library.html) 'mapbox_web_widget.dart';
