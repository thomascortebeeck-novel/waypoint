// Conditional export: web uses dart:html implementation; mobile/desktop use no-op stub.
export 'seo_service_web.dart'
    if (dart.library.html) 'seo_service_stub.dart';
