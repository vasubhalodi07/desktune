import 'dart:typed_data';

class MediaInfo {
  final bool hasActiveSession;
  final String packageName;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int positionMs;
  final int lastUpdateTime;
  final int receivedAtMs;
  final double playbackSpeed;
  final bool isPlaying;
  final int playbackStateCode;
  final bool canPlay;
  final bool canPause;
  final bool canNext;
  final bool canPrevious;
  final bool canSeek;
  final Uint8List? artworkBytes;

  const MediaInfo({
    this.hasActiveSession = false,
    this.packageName = '',
    this.title = '',
    this.artist = '',
    this.album = '',
    this.durationMs = 0,
    this.positionMs = 0,
    this.lastUpdateTime = 0,
    this.receivedAtMs = 0,
    this.playbackSpeed = 1.0,
    this.isPlaying = false,
    this.playbackStateCode = 0,
    this.canPlay = false,
    this.canPause = false,
    this.canNext = false,
    this.canPrevious = false,
    this.canSeek = false,
    this.artworkBytes,
  });

  /// [artwork], when given, is used instead of the bytes in [map]. The media
  /// service passes the previously received instance when the artwork hasn't
  /// changed, so the image isn't re-decoded on every playback event.
  factory MediaInfo.fromMap(Map<dynamic, dynamic>? map, {Uint8List? artwork}) {
    if (map == null || map.isEmpty || map['hasActiveSession'] != true) {
      return const MediaInfo();
    }

    if (artwork == null) {
      final rawArt = map['artwork'];
      if (rawArt is Uint8List) {
        artwork = rawArt;
      } else if (rawArt is List<dynamic>) {
        artwork = Uint8List.fromList(rawArt.cast<int>());
      }
    }

    final localNow = DateTime.now().millisecondsSinceEpoch;

    return MediaInfo(
      hasActiveSession: map['hasActiveSession'] as bool? ?? false,
      packageName: map['packageName'] as String? ?? '',
      title: map['title'] as String? ?? '',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String? ?? '',
      durationMs: (map['duration'] as num?)?.toInt() ?? 0,
      positionMs: (map['position'] as num?)?.toInt() ?? 0,
      lastUpdateTime: (map['lastUpdateTime'] as num?)?.toInt() ?? 0,
      receivedAtMs: localNow,
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      isPlaying: map['isPlaying'] as bool? ?? false,
      playbackStateCode: (map['playbackStateCode'] as num?)?.toInt() ?? 0,
      canPlay: map['canPlay'] as bool? ?? false,
      canPause: map['canPause'] as bool? ?? false,
      canNext: map['canNext'] as bool? ?? false,
      canPrevious: map['canPrevious'] as bool? ?? false,
      canSeek: map['canSeek'] as bool? ?? false,
      artworkBytes: artwork,
    );
  }

  /// Calculates the current estimated position in ms based on playback state and time elapsed.
  int get currentPositionMs {
    if (!isPlaying) {
      return positionMs.clamp(0, durationMs > 0 ? durationMs : positionMs);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    // Android's PlaybackState.lastPositionUpdateTime is SystemClock.elapsedRealtime().
    // If lastUpdateTime is a wall-clock epoch timestamp (> 1e11), use it;
    // otherwise fallback to local receivedAtMs timestamp to prevent clamping to duration.
    final refTime = (lastUpdateTime > 100000000000)
        ? lastUpdateTime
        : receivedAtMs;
    if (refTime <= 0) {
      return positionMs.clamp(0, durationMs > 0 ? durationMs : positionMs);
    }
    final elapsed = ((now - refTime) * playbackSpeed).toInt();
    final safeElapsed = elapsed >= 0 ? elapsed : 0;
    final calculated = positionMs + safeElapsed;
    if (durationMs > 0) {
      return calculated.clamp(0, durationMs);
    }
    return calculated.clamp(0, 86400000); // 24 hours max fallback
  }

  bool get hasContent => title.isNotEmpty || artist.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaInfo &&
          runtimeType == other.runtimeType &&
          hasActiveSession == other.hasActiveSession &&
          packageName == other.packageName &&
          title == other.title &&
          artist == other.artist &&
          album == other.album &&
          durationMs == other.durationMs &&
          positionMs == other.positionMs &&
          isPlaying == other.isPlaying &&
          canPlay == other.canPlay &&
          canPause == other.canPause &&
          canNext == other.canNext &&
          canPrevious == other.canPrevious &&
          canSeek == other.canSeek &&
          artworkBytes?.length == other.artworkBytes?.length;

  @override
  int get hashCode => Object.hash(
    hasActiveSession,
    packageName,
    title,
    artist,
    album,
    durationMs,
    positionMs,
    isPlaying,
    artworkBytes?.length,
  );
}
