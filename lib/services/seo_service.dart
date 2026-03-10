// Conditional export: when dart.library.html (web) → use web impl; otherwise use stub.
export 'seo_service_stub.dart'
    if (dart.library.html) 'seo_service_web.dart';
