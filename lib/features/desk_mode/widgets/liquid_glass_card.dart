import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidGlassCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? accentColor;
  final List<Color>? paletteColors;
  final bool isPlaying;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 28.0,
    this.padding,
    this.margin,
    this.onTap,
    this.accentColor,
    this.paletteColors,
    this.isPlaying = true,
  });

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _resolveColors() {
    if (widget.paletteColors != null && widget.paletteColors!.isNotEmpty) {
      final p = widget.paletteColors!;
      final c1 = p[0];
      final c2 = p.length > 1 ? p[1] : _shiftHue(c1, 38);
      final c3 = p.length > 2 ? p[2] : _shiftHue(c1, -38);
      return [c1, c2, c3];
    } else if (widget.accentColor != null) {
      final c1 = widget.accentColor!;
      return [c1, _shiftHue(c1, 36), _shiftHue(c1, -36)];
    }
    return [];
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final t = progress * 2 * math.pi;

        final Color primaryColor = hasColors ? colors[0] : Colors.transparent;
        final Color secondaryColor = hasColors ? colors[1] : Colors.transparent;
        final Color tertiaryColor = hasColors ? colors[2] : Colors.transparent;

        // Animated Traveling Liquid Glass Body
        final Widget glassBody = ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            children: [
              // Liquid Moving Chromatic Mesh Orbs (Underneath the Blur)
              if (hasColors)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LiquidMeshPainter(
                      progress: progress,
                      color1: primaryColor,
                      color2: secondaryColor,
                      color3: tertiaryColor,
                    ),
                  ),
                ),

              // Frosted Glass Layer
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(
                  padding: widget.padding ?? const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    gradient: LinearGradient(
                      begin: Alignment(
                        0.75 * math.sin(t * 0.7),
                        -0.85 * math.cos(t * 0.7),
                      ),
                      end: Alignment(
                        -0.75 * math.sin(t * 0.7),
                        0.85 * math.cos(t * 0.7),
                      ),
                      colors: [
                        hasColors
                            ? primaryColor.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.12),
                        hasColors
                            ? secondaryColor.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
                    border: Border.all(
                      color: hasColors
                          ? primaryColor.withValues(alpha: 0.28)
                          : Colors.white.withValues(alpha: 0.16),
                      width: 1.0,
                    ),
                  ),
                  child: widget.child,
                ),
              ),
            ],
          ),
        );

        Widget content = Stack(
          alignment: Alignment.center,
          children: [
            // Multi-Color Traveling Ambient Diffused Glow (Behind the Card)
            if (hasColors)
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(
                          alpha: 0.28 + 0.06 * math.sin(t),
                        ),
                        blurRadius: 46 + 8 * math.sin(t * 1.3),
                        spreadRadius: 3 + 2 * math.cos(t),
                        offset: Offset(6 * math.sin(t), 6 + 2 * math.cos(t)),
                      ),
                      BoxShadow(
                        color: secondaryColor.withValues(
                          alpha: 0.18 + 0.05 * math.cos(t),
                        ),
                        blurRadius: 38 + 6 * math.cos(t * 0.8),
                        spreadRadius: 1,
                        offset: Offset(-5 * math.cos(t * 0.7), 4),
                      ),
                    ],
                  ),
                ),
              ),

            // Deep black ambient drop shadow for elevation
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.42),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),

            // Glass Body
            glassBody,
          ],
        );

        if (widget.margin != null) {
          content = Padding(padding: widget.margin!, child: content);
        }

        if (widget.onTap != null) {
          return GestureDetector(
            onTap: widget.onTap,
            child: content,
          );
        }

        return content;
      },
    );
  }
}

class _LiquidMeshPainter extends CustomPainter {
  final double progress;
  final Color color1;
  final Color color2;
  final Color color3;

  _LiquidMeshPainter({
    required this.progress,
    required this.color1,
    required this.color2,
    required this.color3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;

    // Orb 1 (Primary): Travels smoothly along an oval orbit from top-left toward center
    final c1 = Offset(
      size.width * (0.30 + 0.24 * math.sin(t)),
      size.height * (0.35 + 0.22 * math.cos(t)),
    );
    final r1 = size.width * 0.46;

    // Orb 2 (Secondary): Counter-phase orbit across the right diagonal
    final c2 = Offset(
      size.width * (0.70 - 0.24 * math.cos(t * 0.85 + 0.5)),
      size.height * (0.65 - 0.20 * math.sin(t * 0.85 + 0.5)),
    );
    final r2 = size.width * 0.42;

    // Orb 3 (Tertiary): Bottom center floating wave
    final c3 = Offset(
      size.width * (0.50 + 0.25 * math.sin(t * 1.2 + 1.2)),
      size.height * (0.74 + 0.16 * math.cos(t * 1.2 + 1.2)),
    );
    final r3 = size.width * 0.38;

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          color1.withValues(alpha: 0.38),
          color1.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c1, radius: r1));

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          color2.withValues(alpha: 0.32),
          color2.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c2, radius: r2));

    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          color3.withValues(alpha: 0.26),
          color3.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c3, radius: r3));

    canvas.drawCircle(c1, r1, paint1);
    canvas.drawCircle(c2, r2, paint2);
    canvas.drawCircle(c3, r3, paint3);
  }

  @override
  bool shouldRepaint(covariant _LiquidMeshPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2 ||
        oldDelegate.color3 != color3;
  }
}
