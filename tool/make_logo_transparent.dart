// ignore_for_file: avoid_print
/// Makes white/near-white pixels in assets/images/logo-waypoint.png transparent.
/// Run from project root: dart run tool/make_logo_transparent.dart

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const path = 'assets/images/logo-waypoint.png';
  final file = File(path);
  if (!file.existsSync()) {
    print('Error: $path not found.');
    exitCode = 1;
    return;
  }

  final bytes = file.readAsBytesSync();
  img.Image? image = img.decodeImage(bytes);
  if (image == null) {
    print('Error: Could not decode $path');
    exitCode = 1;
    return;
  }

  // Ensure we have alpha channel
  if (!image.hasAlpha) {
    image = image.convert(numChannels: 4);
  }

  // Remove white and near-white background; 248 keeps light details inside the logo
  const whiteThreshold = 248;
  for (final p in image) {
    final r = p.r.toInt();
    final g = p.g.toInt();
    final b = p.b.toInt();
    if (r >= whiteThreshold && g >= whiteThreshold && b >= whiteThreshold) {
      p.a = 0;
    }
  }

  file.writeAsBytesSync(img.encodePng(image));
  print('Done: white background made transparent in $path');
}
