// Conditional export for Google Maps widget
// Web uses google_maps_flutter_web
// Mobile uses google_maps_flutter
export 'google_map_widget_stub.dart'
    if (dart.library.html) 'google_map_widget_web.dart'
    if (dart.library.io) 'google_map_widget_mobile.dart';

