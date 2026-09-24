import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktune/features/desk_mode/widgets/desk_layout.dart';

const _leftKey = Key('left');
const _rightKey = Key('right');

/// Logical screen sizes, phones to tablets, in landscape and portrait.
const _landscapeSizes = <String, Size>{
  'compact phone': Size(640, 360),
  'phone': Size(852, 393),
  'large phone': Size(915, 412),
  'tablet 4:3': Size(1024, 768),
  'tablet 16:10': Size(1280, 800),
  'large tablet': Size(2560, 1600),
};

const _portraitSizes = <String, Size>{
  'phone portrait': Size(393, 852),
  'tablet portrait': Size(800, 1280),
  'split-screen strip': Size(500, 900),
};

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: DeskSplitLayout(
        // Stand-ins with the same design sizes as the real clock and player.
        left: SizedBox(
          key: _leftKey,
          width: DeskSplitLayout.leftWidth,
          height: 240,
        ),
        right: SizedBox(
          key: _rightKey,
          width: DeskSplitLayout.rightWidth,
          height: 236,
        ),
      ),
    ),
  );
}

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

void main() {
  group('DeskSplitLayout (landscape)', () {
    for (final entry in _landscapeSizes.entries) {
      final size = entry.value;

      testWidgets('${entry.key} $size: equal margins, side by side', (
        tester,
      ) async {
        await _pump(tester, size);
        expect(tester.takeException(), isNull);

        final left = _rect(tester, _leftKey);
        final right = _rect(tester, _rightKey);

        // The same space on the left and right of the composition.
        final leftGap = left.left;
        final rightGap = size.width - right.right;
        expect(
          (leftGap - rightGap).abs(),
          lessThan(1.0),
          reason: 'left $leftGap vs right $rightGap',
        );

        // Never closer to the edge than the margin.
        expect(
          leftGap,
          greaterThanOrEqualTo(DeskSplitLayout.marginFor(size.width) - 0.5),
        );

        // Clock on the left, player on the right, not overlapping.
        expect(left.right, lessThanOrEqualTo(right.left));

        // Everything is on screen.
        expect(left.top, greaterThanOrEqualTo(0));
        expect(right.bottom, lessThanOrEqualTo(size.height));
      });
    }

    testWidgets('grows on a tablet and shrinks on a compact phone', (
      tester,
    ) async {
      await _pump(tester, _landscapeSizes['tablet 16:10']!);
      final tabletWidth = _rect(tester, _rightKey).width;

      await _pump(tester, _landscapeSizes['compact phone']!);
      final compactWidth = _rect(tester, _rightKey).width;

      expect(tabletWidth, greaterThan(DeskSplitLayout.rightWidth));
      expect(compactWidth, lessThan(DeskSplitLayout.rightWidth));
    });
  });

  group('DeskSplitLayout (narrow, tall windows)', () {
    for (final entry in _portraitSizes.entries) {
      final size = entry.value;

      testWidgets('${entry.key} $size: stacked and centred', (tester) async {
        await _pump(tester, size);
        expect(tester.takeException(), isNull);

        final left = _rect(tester, _leftKey);
        final right = _rect(tester, _rightKey);

        // Stacked: clock above the player.
        expect(left.bottom, lessThanOrEqualTo(right.top));

        // Both centred horizontally on the screen.
        expect((left.center.dx - size.width / 2).abs(), lessThan(1.0));
        expect((right.center.dx - size.width / 2).abs(), lessThan(1.0));

        // Everything is on screen.
        expect(left.top, greaterThanOrEqualTo(0));
        expect(right.bottom, lessThanOrEqualTo(size.height));
      });
    }
  });

  group('SymmetricSafeArea', () {
    testWidgets('uses the larger side inset on both sides', (tester) async {
      tester.view.physicalSize = const Size(852, 393);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            // A camera cut-out on the left only.
            data: MediaQueryData(
              size: Size(852, 393),
              padding: EdgeInsets.only(left: 48, top: 24),
            ),
            child: SymmetricSafeArea(child: SizedBox.expand(key: _leftKey)),
          ),
        ),
      );

      final rect = _rect(tester, _leftKey);
      expect(rect.left, 48);
      expect(852 - rect.right, 48); // mirrored on the right
      expect(rect.top, 24);
    });
  });
}
