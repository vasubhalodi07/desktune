import 'package:flutter/material.dart';
import '../features/desk_mode/desk_mode_screen.dart';
import '../features/permission/permission_gate_screen.dart';
import '../services/battery_service.dart';
import '../services/clock_service.dart';
import '../services/media_controller_service.dart';
import '../services/settings_service.dart';
import 'theme.dart';

class DeskTuneApp extends StatefulWidget {
  final SettingsService settingsService;
  final MediaControllerService mediaService;
  final ClockService clockService;
  final BatteryService? batteryService;

  const DeskTuneApp({
    super.key,
    required this.settingsService,
    required this.mediaService,
    required this.clockService,
    this.batteryService,
  });

  @override
  State<DeskTuneApp> createState() => _DeskTuneAppState();
}

class _DeskTuneAppState extends State<DeskTuneApp> {
  bool _skippedPermission = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Desk Mode',
      debugShowCheckedModeBanner: false,
      theme: DeskTheme.darkTheme,
      home: ValueListenableBuilder<bool>(
        valueListenable: widget.mediaService.isPermissionGranted,
        builder: (context, isGranted, _) {
          if (!isGranted && !_skippedPermission) {
            return PermissionGateScreen(
              mediaService: widget.mediaService,
              onContinue: () {
                setState(() {
                  _skippedPermission = true;
                });
              },
            );
          }

          return DeskModeScreen(
            clockService: widget.clockService,
            mediaService: widget.mediaService,
            settingsService: widget.settingsService,
            batteryService: widget.batteryService,
          );
        },
      ),
    );
  }
}
