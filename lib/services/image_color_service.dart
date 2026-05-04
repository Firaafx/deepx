import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageColorService {
  ImageColorService._();

  static final ImageColorService instance = ImageColorService._();

  Future<Color?> extractAccentFromUrl(String url) async {
    final String trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    try {
      final ByteData data =
          await NetworkAssetBundle(Uri.parse(trimmed)).load(trimmed);
      return extractAccentFromBytes(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Future<Color?> extractAccentFromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 48,
        targetHeight: 48,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (data == null) return null;
      return _extractAccentFromRgba(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Color _extractAccentFromRgba(Uint8List rgba) {
    double bestScore = -1;
    int bestR = 253;
    int bestG = 70;
    int bestB = 135;

    for (int i = 0; i <= rgba.length - 4; i += 4) {
      final int r = rgba[i];
      final int g = rgba[i + 1];
      final int b = rgba[i + 2];
      final int a = rgba[i + 3];
      if (a < 16) continue;
      final HSLColor hsl = HSLColor.fromColor(Color.fromARGB(a, r, g, b));
      final double score =
          (hsl.saturation * 1.45) + (hsl.lightness * 0.35) + (a / 255 * 0.25);
      if (score > bestScore) {
        bestScore = score;
        bestR = r;
        bestG = g;
        bestB = b;
      }
    }

    final HSLColor adjusted = HSLColor.fromColor(
      Color.fromARGB(255, bestR, bestG, bestB),
    )
        .withSaturation(
          HSLColor.fromColor(Color.fromARGB(255, bestR, bestG, bestB))
              .saturation
              .clamp(0.45, 0.92)
              .toDouble(),
        )
        .withLightness(
          HSLColor.fromColor(Color.fromARGB(255, bestR, bestG, bestB))
              .lightness
              .clamp(0.35, 0.72)
              .toDouble(),
        );

    return adjusted.toColor();
  }
}
