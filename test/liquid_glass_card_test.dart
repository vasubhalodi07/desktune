import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktune/features/desk_mode/widgets/liquid_glass_card.dart';

int _shadowLayers(WidgetTester tester) {
  return tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((
    box,
  ) {
    final decoration = box.decoration;
    return decoration is BoxDecoration &&
        (decoration.boxShadow?.isNotEmpty ?? false);
  }).length;
}

void main() {
  Future<void> pumpCard(WidgetTester tester, {required bool showShadow}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidGlassCard(
            showShadow: showShadow,
            paletteColors: const [Colors.red, Colors.green, Colors.blue],
            child: const SizedBox(width: 100, height: 60),
          ),
        ),
      ),
    );
  }

  testWidgets('LiquidGlassCard draws glow and drop shadow by default', (
    tester,
  ) async {
    await pumpCard(tester, showShadow: true);
    expect(_shadowLayers(tester), 2);
  });

  testWidgets('LiquidGlassCard has no shadow layers when showShadow is false', (
    tester,
  ) async {
    await pumpCard(tester, showShadow: false);
    expect(_shadowLayers(tester), 0);
  });
}
