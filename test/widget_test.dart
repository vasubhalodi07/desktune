import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktune/app/app.dart';
import 'package:desktune/services/clock_service.dart';
import 'package:desktune/services/media_controller_service.dart';
import 'package:desktune/services/settings_service.dart';

void main() {
  testWidgets('Renders DeskTuneApp and permission gate', (WidgetTester tester) async {
    final settingsService = SettingsService();
    final mediaService = MediaControllerService();
    final clockService = ClockService();

    await tester.pumpWidget(
      DeskTuneApp(
        settingsService: settingsService,
        mediaService: mediaService,
        clockService: clockService,
      ),
    );

    // Initial state before permission is granted should show permission gate
    expect(find.text('Welcome to DeskTune'), findsOneWidget);
    expect(find.text('Enable Media Access'), findsOneWidget);
    expect(find.text('Preview Clock Mode Without Media'), findsOneWidget);

    // Tap preview without media
    await tester.tap(find.text('Preview Clock Mode Without Media'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Now DeskModeScreen should be visible showing the clock
    expect(find.text('No Music Playing'), findsOneWidget);

    // Clean up timers
    clockService.stop();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
