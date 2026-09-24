import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktune/features/desk_mode/widgets/burn_in_shift.dart';

Offset _at(int minuteOfDay) => BurnInShift.offsetFor(
  DateTime(2026, 1, 1, minuteOfDay ~/ 60, minuteOfDay % 60),
);

void main() {
  group('BurnInShift.offsetFor', () {
    test('stays within the amplitude and lands on whole pixels', () {
      for (var minute = 0; minute < 24 * 60; minute++) {
        final offset = _at(minute);
        expect(offset.dx.abs(), lessThanOrEqualTo(BurnInShift.amplitude));
        expect(offset.dy.abs(), lessThanOrEqualTo(BurnInShift.amplitude));
        expect(offset.dx, offset.dx.roundToDouble());
        expect(offset.dy, offset.dy.roundToDouble());
      }
    });

    test('moves only a couple of pixels from one minute to the next', () {
      for (var minute = 0; minute < 24 * 60 - 1; minute++) {
        final a = _at(minute);
        final b = _at(minute + 1);
        expect((a.dx - b.dx).abs(), lessThanOrEqualTo(2));
        expect((a.dy - b.dy).abs(), lessThanOrEqualTo(2));
      }
    });

    test('wanders across many different positions in a day', () {
      final visited = {
        for (var minute = 0; minute < 24 * 60; minute++) _at(minute),
      };
      expect(visited.length, greaterThan(100));
    });
  });

  testWidgets('shifts its child and follows the clock', (tester) async {
    final time = ValueNotifier(DateTime(2026, 1, 1, 10, 0));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: BurnInShift(
            time: time,
            child: const SizedBox(key: Key('child'), width: 10, height: 10),
          ),
        ),
      ),
    );

    Offset childTopLeft() => tester.getTopLeft(find.byKey(const Key('child')));

    expect(childTopLeft(), BurnInShift.offsetFor(time.value));

    time.value = DateTime(2026, 1, 1, 10, 7);
    await tester.pump();
    expect(childTopLeft(), BurnInShift.offsetFor(time.value));
  });
}
