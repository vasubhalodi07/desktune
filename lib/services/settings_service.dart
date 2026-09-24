import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const MethodChannel _channel = MethodChannel('com.desktune.app/media');

  final ValueNotifier<AppSettings> settings = ValueNotifier(
    const AppSettings(),
  );

  /// The phone's own 12/24-hour setting. Read natively because Flutter doesn't
  /// reliably notice the setting changing while the app is running; call
  /// [refreshSystemTimeFormat] when the app comes back to the foreground.
  final ValueNotifier<bool> systemIs24Hour = ValueNotifier(false);

  Future<void> init() async {
    await refreshSystemTimeFormat();
    try {
      final res = await _channel.invokeMapMethod<dynamic, dynamic>(
        'getSettings',
      );
      if (res != null) {
        settings.value = AppSettings.fromMap(res);
      }
    } catch (_) {}
  }

  Future<void> refreshSystemTimeFormat() async {
    try {
      final is24 = await _channel.invokeMethod<bool>('getSystemTimeFormat24');
      if (is24 != null) systemIs24Hour.value = is24;
    } catch (_) {}
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    settings.value = newSettings;
    try {
      await _channel.invokeMethod('saveSettings', newSettings.toMap());
    } catch (_) {}
  }
}
