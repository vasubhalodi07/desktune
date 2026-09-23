import 'dart:ui';
import 'package:flutter/material.dart';

class LiquidGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? accentColor;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 28.0,
    this.padding,
    this.margin,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final Widget glassBody = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor != null
                    ? accentColor!.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.12),
                accentColor != null
                    ? accentColor!.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(
              color: accentColor != null
                  ? accentColor!.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.16),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );

    Widget content = Stack(
      alignment: Alignment.center,
      children: [
        // Artwork-Adaptive Ambient Diffused Glow (Radiates soft colored aura behind glass)
        Positioned.fill(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(
              begin: Colors.transparent,
              end: accentColor != null
                  ? accentColor!.withValues(alpha: 0.32)
                  : Colors.transparent,
            ),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, color, _) {
              if (color == null || color.a == 0) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: color,
                      blurRadius: 44,
                      spreadRadius: 4,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Deep black ambient drop shadow
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
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

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
