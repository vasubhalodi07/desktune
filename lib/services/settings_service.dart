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
        settings.value = AppSettings.fromMap(res);
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
