import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import 'player_glyphs.dart';
import 'svg_glyph.dart';

/// Fetches the launcher icon (PNG bytes) of an app, or null if unavailable.
typedef AppIconLoader = Future<Uint8List?> Function(String packageName);

/// The icon of the app that is playing, shown on the music card as a round
/// liquid-glass chip. Falls back to a music-note chip when Android can't supply
/// the icon.
class PlayerAppIcon extends StatefulWidget {
  final String packageName;

  /// Display name (e.g. "Amazon Music"), used as the accessibility label.
  final String appName;
  final double size;
  final AppIconLoader loadIcon;

  /// Called when the icon is tapped (used to open the player app).
  final VoidCallback? onTap;

  const PlayerAppIcon({
    super.key,
    required this.packageName,
    required this.loadIcon,
    this.appName = '',
    this.size = 30,
    this.onTap,
  });

  @override
  State<PlayerAppIcon> createState() => _PlayerAppIconState();
}

/// What to draw once resolved: DeskTune's own logo, or the bytes of Android's icon.
class _ResolvedIcon {
  const _ResolvedIcon({this.glyph, this.bytes});

  final SvgGlyph? glyph;
  final Uint8List? bytes;
}

class _PlayerAppIconState extends State<PlayerAppIcon> {
  late Future<_ResolvedIcon> _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = _resolve();
  }

  @override
  void didUpdateWidget(covariant PlayerAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) {
      _resolved = _resolve();
    }
  }

  /// Popular players use DeskTune's own glass logo; everything else (and any
  /// player whose logo can't be read) uses the icon Android supplies.
  Future<_ResolvedIcon> _resolve() async {
    if (PlayerGlyphs.hasGlyph(widget.packageName)) {
      final glyph = await PlayerGlyphs.load(widget.packageName);
      if (glyph != null) return _ResolvedIcon(glyph: glyph);
    }
    return _ResolvedIcon(bytes: await widget.loadIcon(widget.packageName));
  }

  // A circle, like the previous / play / next buttons beside it.
  BorderRadius get _radius => BorderRadius.circular(widget.size / 2);

  @override
  Widget build(BuildContext context) {
    // The logo sits inset inside the glass, so decode it at that size.
    final logoSize = widget.size * _logoFraction;
    // Headroom because the layout scales up on tablets.
    final decodeWidth =
        (logoSize * MediaQuery.devicePixelRatioOf(context) * 1.5).round();

    Widget icon = FutureBuilder<_ResolvedIcon>(
      future: _resolved,
      builder: (context, snapshot) {
        final Widget child;
        final resolved = snapshot.data;
        final bytes = resolved?.bytes;
        if (snapshot.hasError) {
          child = _defaultIcon();
        } else if (snapshot.connectionState != ConnectionState.done ||
            resolved == null) {
          // Reserve the space while the icon loads, so nothing jumps.
          child = SizedBox.square(
            key: const ValueKey('loading'),
            dimension: widget.size,
          );
        } else if (resolved.glyph != null) {
          child = _glassChip(
            key: ValueKey(widget.packageName),
            child: CustomPaint(
              size: Size.square(widget.size * _glyphFraction),
              painter: SvgGlyphPainter(
                glyph: resolved.glyph!,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          );
        } else if (bytes != null && bytes.isNotEmpty) {
          child = _glassChip(
            key: ValueKey(widget.packageName),
            // Slightly see-through, so the glass shows through the logo.
            child: ClipRRect(
              // Crop the app's icon to a circle too, to sit inside the round glass.
              borderRadius: BorderRadius.circular(logoSize / 2),
              child: Image.memory(
                bytes,
                width: logoSize,
                height: logoSize,
                fit: BoxFit.cover,
                cacheWidth: decodeWidth,
                opacity: const AlwaysStoppedAnimation(_logoOpacity),
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => _defaultIcon(),
              ),
            ),
          );
        } else {
          child = _defaultIcon();
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: child,
        );
      },
    );

    icon = Semantics(
      button: widget.onTap != null,
      label: widget.appName.isNotEmpty
          ? 'Open ${widget.appName}'
          : 'Open player app',
      child: icon,
    );

    if (widget.onTap == null) return icon;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: icon,
    );
  }

  /// Fraction of the chip the logo occupies; the rest is glass around it.
  static const double _logoFraction = 0.72;

  /// Line glyphs are drawn a little larger, since their fine strokes need room.
  static const double _glyphFraction = 0.84;

  /// Logo opacity: high enough to stay recognisable, low enough to feel glassy.
  static const double _logoOpacity = 0.86;

  /// A frosted, translucent tile in the style of the music card: a soft white
  /// gradient, a thin light edge and a glossy highlight along the top. Drawn
  /// statically (no blur), so it costs nothing while idle.
  Widget _glassChip({required Widget child, Key? key}) {
    return Container(
      key: key,
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: _radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.07),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.30),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: child),
            // Glossy highlight across the upper half.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.55],
                    colors: [
                      Colors.white.withValues(alpha: 0.26),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown when Android can't supply the app's icon: the same glass chip with a
  /// music note.
  Widget _defaultIcon() {
    return _glassChip(
      key: const ValueKey('default'),
      child: Icon(
        CupertinoIcons.music_note,
        size: widget.size * 0.5,
        color: DeskTheme.textSecondary,
      ),
    );
  }
}
