// ignore_for_file: avoid_print
/// Generates web/favicon.png and web/icons/*.png from assets/images/logo-waypoint.png.
///
/// Run from project root after placing the logo:
///   dart run tool/generate_web_icons.dart
///
/// Requires: package:image (project dependency).

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const sourcePath = 'assets/images/logo-waypoint.png';
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    print('Error: $sourcePath not found. Place the logo PNG there and run again.');
    exitCode = 1;
    return;
  }

  final bytes = sourceFile.readAsBytesSync();
  final src = img.decodeImage(bytes);
  if (src == null) {
    print('Error: Could not decode $sourcePath as image.');
    exitCode = 1;
    return;
  }

  // Ensure web/icons exists
  final iconsDir = Directory('web/icons');
  if (!iconsDir.existsSync()) {
    iconsDir.createSync(recursive: true);
  }

  // Favicon 48x48
  final favicon = img.copyResize(src, width: 48, height: 48);
  File('web/favicon.png').writeAsBytesSync(img.encodePng(favicon));
  print('Written web/favicon.png (48x48)');

  // PWA icons (no padding)
  for (final size in [192, 512]) {
    final out = img.copyResize(src, width: size, height: size);
    File('web/icons/Icon-$size.png').writeAsBytesSync(img.encodePng(out));
    print('Written web/icons/Icon-$size.png');
  }

  // Maskable: logo at 80% of canvas, centered (safe area)
  const safeFraction = 0.8;
  for (final size in [192, 512]) {
    final canvas = img.Image(width: size, height: size);
    img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
    final logoSize = (size * safeFraction).round();
    final resized = img.copyResize(src, width: logoSize, height: logoSize);
    final x = (size - logoSize) ~/ 2;
    final y = (size - logoSize) ~/ 2;
    img.compositeImage(canvas, resized, dstX: x, dstY: y, blend: img.BlendMode.alpha);
    File('web/icons/Icon-maskable-$size.png').writeAsBytesSync(img.encodePng(canvas));
    print('Written web/icons/Icon-maskable-$size.png');
  }

  print('Done. Regenerated favicon and PWA icons from $sourcePath');
}
