import 'package:flutter_map/flutter_map.dart';
// On device, we can return a cached-first provider via FMTC when wired-in.
// For now, keep a stable network provider to avoid API drift during web preview.
TileProvider tileProviderOrNetwork() => NetworkTileProvider();
