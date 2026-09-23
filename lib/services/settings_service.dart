import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const MethodChannel _channel = MethodChannel('com.desktune.app/media');

  final ValueNotifier<AppSettings> settings =
      ValueNotifier(const AppSettings());

  Future<void> init() async {
    try {
      final res =
          await _channel.invokeMapMethod<dynamic, dynamic>('getSettings');
      if (res != null) {
        settings.value = AppSettings(
          is24HourFormat: res['is24HourFormat'] as bool? ?? false,
          showSeconds: res['showSeconds'] as bool? ?? false,
          showDate: res['showDate'] as bool? ?? true,
          autoHideControls: res['autoHideControls'] as bool? ?? true,
          autoHideDelaySeconds: res['autoHideDelaySeconds'] as int? ?? 5,
          keepScreenAwake: res['keepScreenAwake'] as bool? ?? true,
        );
      }
    } catch (_) {}
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    settings.value = newSettings;
    try {
      await _channel.invokeMethod('saveSettings', newSettings.toMap());
    } catch (_) {}
  }
}
