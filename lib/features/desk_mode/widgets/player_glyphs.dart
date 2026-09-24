import 'package:flutter/services.dart';
import 'svg_glyph.dart';

/// Logos for popular players, loaded from `assets/glyphs/*.svg`.
///
/// Players listed here get their logo drawn as a translucent glass glyph.
/// Every other player simply uses the icon Android provides, so this never
/// limits which apps work. To add a player, drop its SVG into `assets/glyphs/`
/// and add its package name below.
class PlayerGlyphs {
  const PlayerGlyphs._();

  /// Package name -> SVG asset.
  static const Map<String, String> _assets = {
    'com.amazon.mp3': 'assets/glyphs/amazon-music.svg',
    'com.spotify.music': 'assets/glyphs/spotify.svg',
    'com.spotify.lite': 'assets/glyphs/spotify.svg',
    'com.google.android.apps.youtube.music': 'assets/glyphs/youtube-music.svg',
  };

  // Each logo is read and parsed once, then reused.
  static final Map<String, Future<SvgGlyph?>> _cache = {};

  /// Whether DeskTune has its own logo for [packageName].
  static bool hasGlyph(String packageName) => _assets.containsKey(packageName);

  /// The logo for [packageName], or null if there isn't one (or it can't be
  /// read), in which case the caller should fall back to the app's own icon.
  static Future<SvgGlyph?> load(String packageName) {
    final asset = _assets[packageName];
    if (asset == null) return Future.value(null);
    return _cache.putIfAbsent(asset, () => _read(asset));
  }

  static Future<SvgGlyph?> _read(String asset) async {
    try {
      final glyph = SvgGlyph.parse(await rootBundle.loadString(asset));
      return glyph.shapes.isEmpty ? null : glyph;
    } catch (_) {
      return null;
    }
  }
}
