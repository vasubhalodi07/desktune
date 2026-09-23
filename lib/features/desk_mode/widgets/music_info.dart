import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import 'audio_waveform_visualizer.dart';

class MusicInfo extends StatelessWidget {
  final String title;
  final String artist;
  final String album;
  final bool isExpanded;
  final bool isPlaying;
  final bool hasActiveSession;
  final Color? accentColor;

  const MusicInfo({
    super.key,
    required this.title,
    required this.artist,
    this.album = '',
    this.isExpanded = false,
    this.isPlaying = false,
    this.hasActiveSession = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                title.isNotEmpty ? title : 'No Track',
                textAlign: TextAlign.start,
                maxLines: isExpanded ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Comfortaa',
                  fontSize: isExpanded ? 20 : 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
            ),
            if (hasActiveSession && title.isNotEmpty) ...[
              const SizedBox(width: 8),
              AudioWaveformVisualizer(
                isPlaying: isPlaying,
                color: accentColor ?? Colors.white,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          artist.isNotEmpty ? artist : 'Unknown Artist',
          textAlign: TextAlign.start,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Comfortaa',
            fontSize: isExpanded ? 14 : 13,
            fontWeight: FontWeight.w500,
            color: DeskTheme.textSecondary,
            letterSpacing: -0.2,
          ),
        ),
        if (album.isNotEmpty && album != title) ...[
          const SizedBox(height: 3),
          Text(
            album,
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Comfortaa',
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: DeskTheme.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
