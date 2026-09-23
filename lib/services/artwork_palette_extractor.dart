import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ArtworkPalette {
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final List<Color> allColors;

  const ArtworkPalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.allColors,
  });

  static const ArtworkPalette fallback = ArtworkPalette(
    primary: Color(0xFF6C5CE7),
    secondary: Color(0xFF0984E3),
    tertiary: Color(0xFF00CEC9),
    allColors: [Color(0xFF6C5CE7), Color(0xFF0984E3), Color(0xFF00CEC9)],
  );
}

class ArtworkPaletteExtractor {
  static final Map<int, ArtworkPalette> _cache = {};

  /// Dynamically extracts dominant, vibrant colors directly from the raw image pixels
  /// like Netflix and Apple Music do, avoiding generic/fixed Material 3 tonal shifts.
  static Future<ArtworkPalette> extract(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) return ArtworkPalette.fallback;

    final hash = Object.hash(
      imageBytes.length,
      imageBytes.first,
      imageBytes.last,
      imageBytes[imageBytes.length ~/ 2],
    );

    if (_cache.containsKey(hash)) {
      return _cache[hash]!;
    }

    try {
      // Decode image down to 28x28 pixels for lightning-fast analysis (~784 pixels)
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 28,
        targetHeight: 28,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      codec.dispose();

      if (byteData == null) {
        return ArtworkPalette.fallback;
      }

      final pixels = byteData.buffer.asUint8List();
      final totalPixels = pixels.length ~/ 4;

      // Collect candidate colors with their vibrancy score
      final List<_ColorCandidate> candidates = [];

      for (int i = 0; i < totalPixels; i++) {
        final offset = i * 4;
        final r = pixels[offset];
        final g = pixels[offset + 1];
        final b = pixels[offset + 2];
        final a = pixels[offset + 3];

        if (a < 128) continue; // Skip transparent pixels

        final color = Color.fromARGB(255, r, g, b);
        final hsl = HSLColor.fromColor(color);

        // Filter out pure black and pure white
        if (hsl.lightness < 0.08 || hsl.lightness > 0.94) continue;

        // Vibrancy weight: higher saturation and mid-lightness are favored
        final saturationWeight = math.pow(hsl.saturation, 1.4).toDouble();
        final lightnessWeight = 1.0 - (hsl.lightness - 0.5).abs() * 1.4;
        final vibrancy = saturationWeight * lightnessWeight.clamp(0.1, 1.0);

        if (vibrancy > 0.04) {
          candidates.add(_ColorCandidate(color, hsl, vibrancy));
        }
      }

      if (candidates.isEmpty) {
        // Fallback for dark or monochrome covers: pick sampled quadrant colors
        final c1 = _samplePixel(pixels, 6, 6);
        final c2 = _samplePixel(pixels, 22, 22);
        final c3 = _samplePixel(pixels, 14, 14);
        final palette = ArtworkPalette(
          primary: _boostSaturation(c1),
          secondary: _boostSaturation(c2),
          tertiary: _boostSaturation(c3),
          allColors: [c1, c2, c3],
        );
        _cache[hash] = palette;
        return palette;
      }

      // Sort candidates by vibrancy (most vibrant colors first)
      candidates.sort((a, b) => b.vibrancy.compareTo(a.vibrancy));

      // 1. Dominant primary color
      final primary = _boostSaturation(candidates.first.color);
      final primaryHue = HSLColor.fromColor(primary).hue;

      // 2. Secondary color: must have noticeable hue distance from primary (>= 32 degrees)
      Color secondary = _shiftHue(primary, 48);
      for (final c in candidates) {
        final hueDiff = (c.hsl.hue - primaryHue).abs();
        final normalizedDiff = hueDiff > 180 ? 360 - hueDiff : hueDiff;
        if (normalizedDiff >= 32 && normalizedDiff <= 170) {
          secondary = _boostSaturation(c.color);
          break;
        }
      }

      // 3. Tertiary color: distinct from both primary and secondary
      final secondaryHue = HSLColor.fromColor(secondary).hue;
      Color tertiary = _shiftHue(primary, -42);

      for (final c in candidates) {
        final d1 = (c.hsl.hue - primaryHue).abs();
        final n1 = d1 > 180 ? 360 - d1 : d1;
        final d2 = (c.hsl.hue - secondaryHue).abs();
        final n2 = d2 > 180 ? 360 - d2 : d2;

        if (n1 >= 24 && n2 >= 24) {
          tertiary = _boostSaturation(c.color);
          break;
        }
      }

      final palette = ArtworkPalette(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        allColors: [primary, secondary, tertiary],
      );

      _cache[hash] = palette;
      return palette;
    } catch (_) {
      return ArtworkPalette.fallback;
    }
  }

  static Color _boostSaturation(Color c) {
    final hsl = HSLColor.fromColor(c);
    // Ensure rich, vivid colors suitable for dark glass dock backgrounds
    final s = (hsl.saturation * 1.30).clamp(0.45, 1.0);
    final l = hsl.lightness.clamp(0.38, 0.62);
    return hsl.withSaturation(s).withLightness(l).toColor();
  }

  static Color _shiftHue(Color c, double degrees) {
    final hsl = HSLColor.fromColor(c);
    final newHue = (hsl.hue + degrees + 360.0) % 360.0;
    return hsl.withHue(newHue).withSaturation(0.75).withLightness(0.50).toColor();
  }

  static Color _samplePixel(Uint8List pixels, int x, int y) {
    final offset = (y * 28 + x) * 4;
    if (offset + 2 < pixels.length) {
      return Color.fromARGB(255, pixels[offset], pixels[offset + 1], pixels[offset + 2]);
    }
    return const Color(0xFF6C5CE7);
  }
}

class _ColorCandidate {
  final Color color;
  final HSLColor hsl;
  final double vibrancy;

  _ColorCandidate(this.color, this.hsl, this.vibrancy);
}
