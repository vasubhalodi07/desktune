import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktune/features/desk_mode/widgets/liquid_glass_card.dart';
import 'package:desktune/services/animation_clock.dart';

Finder _painterOfType(String name) => find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint && widget.painter.runtimeType.toString() == name,
);

void main() {
  const palette = [Colors.red, Colors.green, Colors.blue];

  Future<void> pumpCard(
    WidgetTester tester, {
    bool showShadow = true,
    bool animate = false,
    List<Color>? paletteColors = palette,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidGlassCard(
            showShadow: showShadow,
            animate: animate,
            paletteColors: paletteColors,
            child: const SizedBox(width: 100, height: 60),
          ),
        ),
      ),
    );
  }

  testWidgets('draws the glow and drop shadow by default', (tester) async {
    await pumpCard(tester);
    expect(_painterOfType('_GlowPainter'), findsOneWidget);
  });

  testWidgets('draws no glow or shadow when showShadow is false', (
    tester,
  ) async {
    await pumpCard(tester, showShadow: false);
    expect(_painterOfType('_GlowPainter'), findsNothing);
  });

  testWidgets('draws no glow without artwork colours (empty card)', (
    tester,
  ) async {
    await pumpCard(tester, paletteColors: null);
    expect(_painterOfType('_GlowPainter'), findsNothing);
  });

  testWidgets('never uses a backdrop blur', (tester) async {
    await pumpCard(tester, animate: true);
    expect(find.byType(BackdropFilter), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('shared animation clock', () {
    testWidgets('runs only while the card animates', (tester) async {
      await pumpCard(tester, animate: false);
      expect(AnimationClock.instance.isRunning, false);

      await pumpCard(tester, animate: true);
      expect(AnimationClock.instance.isRunning, true);

      await pumpCard(tester, animate: false);
      expect(AnimationClock.instance.isRunning, false);
    });

    testWidgets('does not run when there is nothing to animate', (
      tester,
    ) async {
      await pumpCard(tester, animate: true, paletteColors: null);
      expect(AnimationClock.instance.isRunning, false);
    });

    testWidgets('stops when the card is removed', (tester) async {
      await pumpCard(tester, animate: true);
      expect(AnimationClock.instance.isRunning, true);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(AnimationClock.instance.isRunning, false);
    });

    testWidgets('ticks at a low frame rate, not every vsync', (tester) async {
      await pumpCard(tester, animate: true);
      var ticks = 0;
      void onTick() => ticks++;
      AnimationClock.instance.addListener(onTick);

      await tester.pump(const Duration(seconds: 1));
      AnimationClock.instance.removeListener(onTick);

      expect(
        ticks,
        inInclusiveRange(AnimationClock.fps - 2, AnimationClock.fps + 2),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
