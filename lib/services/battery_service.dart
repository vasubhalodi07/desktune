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

  Future<void> init() async {
    try {
      final res = await _methodChannel.invokeMapMethod<dynamic, dynamic>(
        'getBatteryStatus',
      );
      if (res != null) {
        batteryInfo.value = BatteryInfo.fromMap(res);
      }
    } catch (_) {}

    try {
      _sub = _batteryEvents.receiveBroadcastStream().listen((dynamic event) {
        if (event is Map) {
          batteryInfo.value = BatteryInfo.fromMap(event);
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  void dispose() {
    _sub?.cancel();
    batteryInfo.dispose();
  }
}
