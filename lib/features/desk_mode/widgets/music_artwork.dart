import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class MusicArtwork extends StatelessWidget {
  final Uint8List? artworkBytes;
  final double size;

  const MusicArtwork({
    super.key,
    required this.artworkBytes,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    final hasArt = artworkBytes != null && artworkBytes!.isNotEmpty;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Ambient Diffused Glow
        if (hasArt)
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.18),
                  blurRadius: 36,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

        // Album Art Box with iOS Squircle
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF16171D),
            borderRadius: BorderRadius.circular(size * 0.16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.0,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: hasArt
                ? Image.memory(
                    artworkBytes!,
                    key: ValueKey(artworkBytes.hashCode),
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      key: const ValueKey('placeholder'),
      color: const Color(0xFF16171D),
      child: Center(
        child: Icon(
          CupertinoIcons.music_note,
          size: size * 0.38,
          color: DeskTheme.textMuted.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
