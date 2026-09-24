import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/media_info.dart';

class MediaControllerService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.desktune.app/media',
  );
  static const EventChannel _mediaEvents = EventChannel(
    'com.desktune.app/media_events',
  );
  static const EventChannel _volumeEvents = EventChannel(
    'com.desktune.app/volume_events',
  );

  final ValueNotifier<MediaInfo> mediaInfo = ValueNotifier(const MediaInfo());
  final ValueNotifier<double> volumeRatio = ValueNotifier(0.5);
  final ValueNotifier<double> brightness = ValueNotifier(0.7);
  final ValueNotifier<bool> isPermissionGranted = ValueNotifier(false);

  StreamSubscription? _mediaSub;
  StreamSubscription? _volumeSub;

  // The artwork most recently received. The native side only re-sends the
  // bytes when the artwork changes; this keeps the same instance in between so
  // the image isn't decoded again on every playback event.
  String? _artworkKey;
  Uint8List? _artworkBytes;

  Future<void> init() async {
    await checkPermission();
    await _subscribe();

    // Initial query
    await refreshSessions();
    await getVolume();
    await getBrightness();
  }

  /// Stops the native event streams while the app is in the background so the
  /// bridges stop building and sending updates nobody is looking at.
  Future<void> pause() async {
    await _mediaSub?.cancel();
    await _volumeSub?.cancel();
    _mediaSub = null;
    _volumeSub = null;
  }

  /// Restarts the streams after [pause] and catches up on anything missed.
  Future<void> resume() async {
    await _subscribe();
    await refreshSessions();
    await getVolume();
  }

  Future<void> _subscribe() async {
    await _mediaSub?.cancel();
    await _volumeSub?.cancel();
    _mediaSub = null;
    _volumeSub = null;
    // A fresh subscription starts from a clean slate on the native side, so
    // the first event carries the artwork bytes again.
    _artworkKey = null;
    _artworkBytes = null;

    try {
      _mediaSub = _mediaEvents.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            mediaInfo.value = _parseMedia(event);
          }
        },
        onError: (dynamic error) {
          debugPrint('Media events error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to subscribe to media events: $e');
    }

    try {
      _volumeSub = _volumeEvents.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is Map) {
            final ratio = (event['volumeRatio'] as num?)?.toDouble();
            if (ratio != null) {
              volumeRatio.value = ratio.clamp(0.0, 1.0);
            }
          }
        },
        onError: (dynamic error) {
          debugPrint('Volume events error: $error');
        },
      );
    } catch (e) {
      debugPrint('Failed to subscribe to volume events: $e');
    }
  }

  MediaInfo _parseMedia(Map<dynamic, dynamic> map) {
    if (map.isEmpty || map['hasActiveSession'] != true) {
      _artworkKey = null;
      _artworkBytes = null;
      return const MediaInfo();
    }

    Uint8List? artwork;
    final key = map['artworkKey'] as String?;
    if (key == null) {
      _artworkKey = null;
      _artworkBytes = null;
    } else if (key == _artworkKey && _artworkBytes != null) {
      artwork = _artworkBytes;
    } else if (map['artwork'] is Uint8List) {
      _artworkKey = key;
      _artworkBytes = map['artwork'] as Uint8List;
      artwork = _artworkBytes;
    }
    return MediaInfo.fromMap(map, artwork: artwork);
  }

  Future<bool> checkPermission() async {
    try {
      final granted =
          await _methodChannel.invokeMethod<bool>('checkPermission') ?? false;
      isPermissionGranted.value = granted;
      return granted;
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _methodChannel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('Error opening notification settings: $e');
    }
  }

  /// True when Android (13+) probably has notification access locked because
  /// the app was installed from a file; the user must turn on "Allow restricted
  /// settings" in App info first.
  Future<bool> isRestrictedSettingsLikely() async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            'isRestrictedSettingsLikely',
          ) ??
          false;
    } catch (e) {
      debugPrint('Error checking restricted settings: $e');
      return false;
    }
  }

  Future<void> openAppInfo() async {
    try {
      await _methodChannel.invokeMethod('openAppInfo');
    } catch (e) {
      debugPrint('Error opening app info: $e');
    }
  }

  Future<void> refreshSessions() async {
    try {
      final res = await _methodChannel.invokeMapMethod<dynamic, dynamic>(
        'getCurrentMedia',
        {'knownArtworkKey': _artworkKey},
      );
      if (res != null) {
        mediaInfo.value = _parseMedia(res);
      }
    } catch (e) {
      debugPrint('Error refreshing sessions: $e');
    }
  }

  Future<void> togglePlayPause() async {
    try {
      await _methodChannel.invokeMethod('togglePlayPause');
    } catch (e) {
      debugPrint('Error invoking togglePlayPause: $e');
    }
  }

  Future<void> next() async {
    try {
      await _methodChannel.invokeMethod('next');
    } catch (e) {
      debugPrint('Error invoking next: $e');
    }
  }

  Future<void> previous() async {
    try {
      await _methodChannel.invokeMethod('previous');
    } catch (e) {
      debugPrint('Error invoking previous: $e');
    }
  }

  Future<void> seekTo(int positionMs) async {
    try {
      await _methodChannel.invokeMethod('seekTo', {'position': positionMs});
    } catch (e) {
      debugPrint('Error invoking seekTo: $e');
    }
  }

  Future<double> getVolume() async {
    try {
      final vol = await _methodChannel.invokeMethod<num>('getVolume');
      if (vol != null) {
        final ratio = vol.toDouble().clamp(0.0, 1.0);
        volumeRatio.value = ratio;
        return ratio;
      }
    } catch (e) {
      debugPrint('Error getting volume: $e');
    }
    return volumeRatio.value;
  }

  Future<void> setVolume(double ratio) async {
    final clamped = ratio.clamp(0.0, 1.0);
    volumeRatio.value = clamped;
    try {
      await _methodChannel.invokeMethod('setVolume', {'volume': clamped});
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  Future<double> getBrightness() async {
    try {
      final b = await _methodChannel.invokeMethod<num>('getBrightness');
      if (b != null) {
        final ratio = b.toDouble().clamp(0.01, 1.0);
        brightness.value = ratio;
        return ratio;
      }
    } catch (e) {
      debugPrint('Error getting brightness: $e');
    }
    return brightness.value;
  }

  Future<void> setBrightness(double ratio) async {
    final clamped = ratio.clamp(0.01, 1.0);
    brightness.value = clamped;
    try {
      await _methodChannel.invokeMethod('setBrightness', {
        'brightness': clamped,
      });
    } catch (e) {
      debugPrint('Error setting brightness: $e');
    }
  }

  Future<void> setKeepScreenOn(bool keepOn) async {
    try {
      await _methodChannel.invokeMethod('setKeepScreenOn', {'keepOn': keepOn});
    } catch (e) {
      debugPrint('Error setting keep screen on: $e');
    }
  }

  void dispose() {
    _mediaSub?.cancel();
    _volumeSub?.cancel();
    mediaInfo.dispose();
    volumeRatio.dispose();
    brightness.dispose();
    isPermissionGranted.dispose();
  }
}
