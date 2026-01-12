// Facade that chooses the proper implementation at compile-time.
import 'package:flutter_map/flutter_map.dart';
import 'package:waypoint/integrations/offline_tile_provider_stub.dart'
    if (dart.library.io) 'package:waypoint/integrations/offline_tile_provider_io.dart' as impl;

TileProvider tileProviderOrNetwork() => impl.tileProviderOrNetwork();
