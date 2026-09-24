import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BatteryInfo {
  final int level;
  final bool isCharging;

  const BatteryInfo({this.level = -1, this.isCharging = false});

  factory BatteryInfo.fromMap(Map<dynamic, dynamic> map) {
    return BatteryInfo(
      level: (map['level'] as num?)?.toInt() ?? -1,
      isCharging: map['isCharging'] as bool? ?? false,
    );
  }

  // Value equality lets the ValueNotifier drop repeat updates, so the screen
  // only rebuilds when the level or charging state actually changes.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BatteryInfo &&
          level == other.level &&
          isCharging == other.isCharging;

  @override
  int get hashCode => Object.hash(level, isCharging);
}

class BatteryService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.desktune.app/media',
  );
  static const EventChannel _batteryEvents = EventChannel(
    'com.desktune.app/battery_events',
  );

  final ValueNotifier<BatteryInfo> batteryInfo = ValueNotifier(
    const BatteryInfo(),
  );
  StreamSubscription? _sub;

  /// Reads the current level and starts listening for changes. Safe to call
  /// again; it replaces any existing subscription.
  Future<void> init() async {
    try {
      final res = await _methodChannel.invokeMapMethod<dynamic, dynamic>(
        'getBatteryStatus',
      );
      if (res != null) {
        batteryInfo.value = BatteryInfo.fromMap(res);
      }
    } catch (_) {}

    await _sub?.cancel();
    try {
      _sub = _batteryEvents.receiveBroadcastStream().listen((dynamic event) {
        if (event is Map) {
          batteryInfo.value = BatteryInfo.fromMap(event);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  /// Stops listening (and unregisters the native receiver) while the app is in
  /// the background. Call [init] to resume.
  Future<void> pause() async {
    await _sub?.cancel();
    _sub = null;
  }

  void dispose() {
    _sub?.cancel();
    batteryInfo.dispose();
  }
}
