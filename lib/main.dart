import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'services/battery_service.dart';
import 'services/clock_service.dart';
import 'services/media_controller_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // DeskTune is landscape-only, including the welcome screen.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final settingsService = SettingsService();
  final mediaService = MediaControllerService();
  final clockService = ClockService();
  final batteryService = BatteryService();

  await Future.wait([
    settingsService.init(),
    mediaService.init(),
    batteryService.init(),
  ]);

  runApp(
    DeskTuneApp(
      settingsService: settingsService,
      mediaService: mediaService,
      clockService: clockService,
      batteryService: batteryService,
    ),
  );
}
