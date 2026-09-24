import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Album art as a plain rounded square: no frame, border, shadow or glow, so
/// the image fills the whole tile edge to edge.
class MusicArtwork extends StatelessWidget {
  final Uint8List? artworkBytes;
  final double size;

  /// Called when the artwork is tapped (used to open the player app).
  final VoidCallback? onTap;

  const MusicArtwork({
    super.key,
    required this.artworkBytes,
    this.size = 140,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasArt = artworkBytes != null && artworkBytes!.isNotEmpty;
    // The native side sends up to 800px; decode only what the screen shows, with
    // some headroom because the layout scales up on tablets.
    final decodeWidth = (size * MediaQuery.devicePixelRatioOf(context) * 1.5)
        .round();

    final tile = SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: hasArt
              ? Image.memory(
                  artworkBytes!,
                  key: ValueKey(artworkBytes.hashCode),
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  cacheWidth: decodeWidth,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
      ),
    );

    if (onTap == null) return tile;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: tile,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      key: const ValueKey('placeholder'),
      width: size,
      height: size,
      color: Colors.white.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          CupertinoIcons.music_note,
          size: size * 0.38,
          color: DeskTheme.textMuted,
        ),
      ),
    );
  }
}
