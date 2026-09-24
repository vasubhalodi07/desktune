import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../../../services/animation_clock.dart';

/// Frosted "liquid glass" card whose colours follow the album artwork.
///
/// Built to be cheap enough to leave on all day:
/// * It draws no backdrop blur; everything behind the card is already soft.
/// * The glow and drop shadow are one static, cacheable layer.
/// * The drifting colour mesh only animates while [animate] is true, driven by
///   the shared low-frame-rate [AnimationClock] rather than a 120 Hz controller.
///   When it is false the card is a still image and produces no frames.
class LiquidGlassCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? accentColor;
  final List<Color>? paletteColors;

  /// Draws the coloured glow and drop shadow behind the card.
  final bool showShadow;

  /// Drifts the colour mesh (only has an effect when there are artwork colours).
  final bool animate;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 28.0,
    this.padding,
    this.margin,
    this.onTap,
    this.accentColor,
    this.paletteColors,
    this.showShadow = true,
    this.animate = false,
  });

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard> {
  /// Room around the card for the glow to paint into (blur reaches ~3 sigma).
  static const double _glowExtent = 56;

  bool _holdingClock = false;

  @override
  void initState() {
    super.initState();
    _syncClock();
  }

  @override
  void didUpdateWidget(covariant LiquidGlassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncClock();
  }

  @override
  void dispose() {
    if (_holdingClock) AnimationClock.instance.release();
    super.dispose();
  }

  bool get _shouldAnimate => widget.animate && _resolveColors().isNotEmpty;

  void _syncClock() {
    final want = _shouldAnimate;
    if (want && !_holdingClock) {
      AnimationClock.instance.acquire();
      _holdingClock = true;
    } else if (!want && _holdingClock) {
      AnimationClock.instance.release();
      _holdingClock = false;
    }
  }

  List<Color> _resolveColors() {
    if (widget.paletteColors != null && widget.paletteColors!.isNotEmpty) {
      final p = widget.paletteColors!;
      final c1 = _toneColor(p[0]);
      final c2 = p.length > 1 ? _toneColor(p[1]) : _shiftHue(c1, 38);
      final c3 = p.length > 2 ? _toneColor(p[2]) : _shiftHue(c1, -38);
      return [c1, c2, c3];
    } else if (widget.accentColor != null) {
      final c1 = _toneColor(widget.accentColor!);
      return [c1, _shiftHue(c1, 36), _shiftHue(c1, -36)];
    }
    return [];
  }

  /// Mutes a raw palette color so vivid artwork doesn't overpower the UI.
  /// Caps saturation at 55% and lightness at 35% for a consistent moody feel.
  Color _toneColor(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.0, 0.55))
        .withLightness(hsl.lightness.clamp(0.08, 0.35))
        .toColor();
  }

  Color _shiftHue(Color c, double degrees) {
    final hsl = HSLColor.fromColor(c);
    final newHue = (hsl.hue + degrees + 360.0) % 360.0;
    return hsl.withHue(newHue).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors();
    final hasColors = colors.isNotEmpty;

    Widget content = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Multi-colour ambient glow + deep drop shadow (behind the card).
        // Static, so the raster cache keeps it as a texture.
        if (hasColors && widget.showShadow)
          Positioned(
            left: -_glowExtent,
            top: -_glowExtent,
            right: -_glowExtent,
            bottom: -_glowExtent,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  isComplex: true,
                  painter: _GlowPainter(
                    primary: colors[0],
                    secondary: colors[1],
                    radius: widget.borderRadius,
                    inset: _glowExtent,
                  ),
                ),
              ),
            ),
          ),

        // Glass body
        RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Stack(
              children: [
                // Animated layer: colour mesh + sheen. Repaints on its own
                // without rebuilding or repainting the card contents.
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _GlassPainter(
                        colors: colors,
                        animate: _shouldAnimate,
                      ),
                    ),
                  ),
                ),
                RepaintBoundary(
                  child: Padding(
                    padding: widget.padding ?? const EdgeInsets.all(20),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.margin != null) {
      content = Padding(padding: widget.margin!, child: content);
    }

    if (widget.onTap != null) {
      return GestureDetector(onTap: widget.onTap, child: content);
    }

    return content;
  }
}

/// Coloured glow and black drop shadow behind the card, painted once.
class _GlowPainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final double radius;

  /// Distance from this painter's edge to the card's edge on every side.
  final double inset;

  const _GlowPainter({
    required this.primary,
    required this.secondary,
    required this.radius,
    required this.inset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - 2 * inset,
        size.height - 2 * inset,
      ),
      Radius.circular(radius),
    );

    final glowBox = card.deflate(4);
    // A low, subtle lift: the card should sit just above the background rather
    // than float far off it. Keep the blur small enough to fit in _glowExtent.
    final primaryGlow = BoxShadow(
      color: primary.withValues(alpha: 0.14),
      blurRadius: 26,
      offset: const Offset(0, 3),
    );
    final secondaryGlow = BoxShadow(
      color: secondary.withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(-2, 2),
    );
    final dropShadow = BoxShadow(
      color: Colors.black.withValues(alpha: 0.20),
      blurRadius: 10,
      offset: const Offset(0, 3),
    );

    for (final shadow in [primaryGlow, secondaryGlow]) {
      canvas.drawRRect(
        glowBox.inflate(shadow.spreadRadius).shift(shadow.offset),
        shadow.toPaint(),
      );
    }
    canvas.drawRRect(
      card.deflate(2).shift(dropShadow.offset),
      dropShadow.toPaint(),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) {
    return old.primary != primary ||
        old.secondary != secondary ||
        old.radius != radius ||
        old.inset != inset;
  }
}

/// The card's colour mesh and sheen. Repaints on each [AnimationClock] tick
/// while [animate] is true; otherwise it is painted once at a fixed phase.
class _GlassPainter extends CustomPainter {
  final List<Color> colors;
  final bool animate;

  static const int _cycleMs = 14000;
  static const double _stillPhase = 0.0;

  _GlassPainter({required this.colors, required this.animate})
    : super(repaint: animate ? AnimationClock.instance : null);

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animate
        ? (AnimationClock.instance.elapsed.inMilliseconds % _cycleMs) / _cycleMs
        : _stillPhase;
    final t = progress * 2 * math.pi;
    final rect = Offset.zero & size;
    final hasColors = colors.isNotEmpty;

    if (hasColors) {
      _paintMesh(canvas, size, t);
    }

    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment(0.75 * math.sin(t * 0.7), -0.85 * math.cos(t * 0.7)),
        end: Alignment(-0.75 * math.sin(t * 0.7), 0.85 * math.cos(t * 0.7)),
        colors: [
          hasColors
              ? colors[0].withValues(alpha: 0.13)
              : Colors.white.withValues(alpha: 0.10),
          hasColors
              ? colors[1].withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.03),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, sheen);
  }

  void _paintMesh(Canvas canvas, Size size, double t) {
    // Orb 1 (Primary): oval orbit from top-left toward center
    final c1 = Offset(
      size.width * (0.30 + 0.24 * math.sin(t)),
      size.height * (0.35 + 0.22 * math.cos(t)),
    );
    final r1 = size.width * 0.46;

    // Orb 2 (Secondary): counter-phase orbit across the right diagonal
    final c2 = Offset(
      size.width * (0.70 - 0.24 * math.cos(t * 0.85 + 0.5)),
      size.height * (0.65 - 0.20 * math.sin(t * 0.85 + 0.5)),
    );
    final r2 = size.width * 0.42;

    // Orb 3 (Tertiary): bottom center floating wave
    final c3 = Offset(
      size.width * (0.50 + 0.25 * math.sin(t * 1.2 + 1.2)),
      size.height * (0.74 + 0.16 * math.cos(t * 1.2 + 1.2)),
    );
    final r3 = size.width * 0.38;

    _orb(canvas, c1, r1, colors[0], 0.26);
    _orb(canvas, c2, r2, colors[1], 0.20);
    _orb(canvas, c3, r3, colors[2], 0.15);
  }

  void _orb(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GlassPainter old) {
    return old.animate != animate || !listEquals(old.colors, colors);
  }
}
