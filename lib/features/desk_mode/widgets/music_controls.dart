import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
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
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    final hasSession = media.hasActiveSession;
    final isPlaying = media.isPlaying;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Skip Previous (iOS Cupertino backward_fill)
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: hasSession ? onPrevious : null,
          child: Icon(
            CupertinoIcons.backward_fill,
            size: size * 0.52,
            color: hasSession
                ? DeskTheme.textPrimary
                : DeskTheme.textMuted.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: 28),

        // Apple Liquid Glass Play / Pause Pill
        GestureDetector(
          onTap: hasSession ? onTogglePlayPause : null,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasSession ? Colors.white : Colors.white.withValues(alpha: 0.08),
              boxShadow: [
                if (hasSession)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.25),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Center(
              child: Icon(
                isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                size: size * 0.48,
                color: hasSession ? Colors.black : DeskTheme.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 28),

        // Skip Next (iOS Cupertino forward_fill)
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: hasSession ? onNext : null,
          child: Icon(
            CupertinoIcons.forward_fill,
            size: size * 0.52,
            color: hasSession
                ? DeskTheme.textPrimary
                : DeskTheme.textMuted.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}
