import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktune/app/theme.dart';
import 'package:desktune/features/permission/permission_gate_screen.dart';
import 'package:desktune/services/media_controller_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Measure with the real app font, not the wide default test font.
  setUpAll(() async {
    final loader = FontLoader('Comfortaa')
      ..addFont(rootBundle.load('assets/fonts/Comfortaa.ttf'));
    await loader.load();
  });

  // Typical phone in landscape (logical pixels).
  const phoneLandscape = Size(852, 393);

  Future<void> pumpGate(WidgetTester tester, {required bool restricted}) async {
    tester.view.physicalSize = phoneLandscape;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.desktune.app/media'),
      (call) async =>
          call.method == 'isRestrictedSettingsLikely' ? restricted : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.desktune.app/media'),
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: DeskTheme.darkTheme,
        home: PermissionGateScreen(
          mediaService: MediaControllerService(),
          onContinue: () {},
        ),
      ),
    );
    await tester.pump();
  }

  void expectOnScreen(WidgetTester tester, String text) {
    final rect = tester.getRect(find.text(text));
    expect(rect.top, greaterThanOrEqualTo(0), reason: '"$text" above screen');
    expect(
      rect.bottom,
      lessThanOrEqualTo(phoneLandscape.height),
      reason: '"$text" below screen',
    );
  }

  testWidgets('Welcome screen fits landscape without scrolling', (
    tester,
  ) async {
    await pumpGate(tester, restricted: false);

    expect(find.text('Notification access may be locked'), findsNothing);
    expectOnScreen(tester, 'Welcome to DeskTune');
    expectOnScreen(tester, 'Enable Media Access');
    expectOnScreen(tester, 'Preview Clock Mode Without Media');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unlock card sits beside the intro and everything fits', (
    tester,
  ) async {
    await pumpGate(tester, restricted: true);

    expect(find.text('Notification access may be locked'), findsOneWidget);
    final intro = tester.getRect(find.text('Welcome to DeskTune'));
    final card = tester.getRect(find.text('Notification access may be locked'));
    expect(intro.center.dx, lessThan(card.center.dx));

    expectOnScreen(tester, 'Enable Media Access');
    expectOnScreen(tester, 'Preview Clock Mode Without Media');
    expectOnScreen(tester, 'Notification access may be locked');
    expectOnScreen(tester, 'Open App Info');
    expect(tester.takeException(), isNull);
  });
}
