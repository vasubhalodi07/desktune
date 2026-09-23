import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../models/media_info.dart';

class MusicControls extends StatelessWidget {
  final MediaInfo media;
  final VoidCallback? onPrevious;
  final VoidCallback? onTogglePlayPause;
  final VoidCallback? onNext;
  final double size;

  const MusicControls({
    super.key,
    required this.media,
    this.onPrevious,
    this.onTogglePlayPause,
    this.onNext,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final hasSession = media.hasActiveSession;
    final isPlaying = media.isPlaying;

    final playPauseSize = size;
    final secondarySize = size * 0.84;

    final Color secondaryIconColor = hasSession
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.30);
    final Color primaryIconColor = hasSession
        ? Colors.white
        : Colors.white.withValues(alpha: 0.35);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Skip Previous (Liquid Glass Disc)
        _LiquidGlassIconButton(
          size: secondarySize,
          isEnabled: hasSession,
          onTap: onPrevious,
          icon: Icon(
            CupertinoIcons.backward_fill,
            size: secondarySize * 0.44,
            color: secondaryIconColor,
          ),
        ),
        const SizedBox(width: 20),

        // Play / Pause (Same Liquid Glass Disc as Prev/Next)
        _LiquidGlassIconButton(
          size: playPauseSize,
          isEnabled: hasSession,
          onTap: onTogglePlayPause,
          icon: Icon(
            isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
            size: playPauseSize * 0.46,
            color: primaryIconColor,
          ),
        ),
        const SizedBox(width: 20),

        // Skip Next (Liquid Glass Disc)
        _LiquidGlassIconButton(
          size: secondarySize,
          isEnabled: hasSession,
          onTap: onNext,
          icon: Icon(
            CupertinoIcons.forward_fill,
            size: secondarySize * 0.44,
            color: secondaryIconColor,
          ),
        ),
      ],
    );
  }
}

class _LiquidGlassIconButton extends StatefulWidget {
  final Widget icon;
  final double size;
  final VoidCallback? onTap;
  final bool isEnabled;

  const _LiquidGlassIconButton({
    required this.icon,
    required this.size,
    this.onTap,
    this.isEnabled = true,
  });

  @override
  State<_LiquidGlassIconButton> createState() => _LiquidGlassIconButtonState();
}

class _LiquidGlassIconButtonState extends State<_LiquidGlassIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.isEnabled && widget.onTap != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      onTap: enabled ? widget.onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.91 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.size / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: _isPressed ? 0.22 : 0.13),
                    Colors.white.withValues(alpha: _isPressed ? 0.10 : 0.05),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: _isPressed ? 0.35 : 0.20,
                  ),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(child: widget.icon),
            ),
          ),
        ),
      ),
    );
  }
}
