import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktune/services/battery_service.dart';
import 'package:desktune/services/clock_service.dart';
import 'package:desktune/services/media_controller_service.dart';
import 'package:desktune/services/time_format.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClockService ticking', () {
    test('per-minute mode waits for the next minute boundary', () {
      final now = DateTime(2026, 9, 23, 22, 15, 40, 250);
      final wait = ClockService.delayUntilNextTick(now, false);
      // 19.75 s left in the minute, plus the 2 ms cushion.
      expect(wait, const Duration(milliseconds: 19752));
    });

    test('per-second mode waits for the next second boundary', () {
      final now = DateTime(2026, 9, 23, 22, 15, 40, 250);
      final wait = ClockService.delayUntilNextTick(now, true);
      expect(wait, const Duration(milliseconds: 752));
    });

    test('a tick never lands before its boundary', () {
      for (var ms = 0; ms < 1000; ms += 37) {
        final now = DateTime(2026, 1, 1, 0, 0, 59, ms);
        final at = now.add(ClockService.delayUntilNextTick(now, false));
        expect(at.minute, 1, reason: 'ms=$ms');
      }
    });

    test('stop cancels the timer and start resumes it', () {
      final clock = ClockService();
      expect(clock.isRunning, false);
      clock.start();
      expect(clock.isRunning, true);
      clock.showSeconds = true; // restarts at the faster rate while running
      expect(clock.isRunning, true);
      clock.stop();
      expect(clock.isRunning, false);
      clock.dispose();
    });
  });

  group('TimeFormat', () {
    test('12-hour clock has no leading zero and maps midnight/noon', () {
      expect(TimeFormat.hour12(DateTime(2026, 1, 1, 0, 5)), '12');
      expect(TimeFormat.hour12(DateTime(2026, 1, 1, 9, 5)), '9');
      expect(TimeFormat.hour12(DateTime(2026, 1, 1, 12, 5)), '12');
      expect(TimeFormat.hour12(DateTime(2026, 1, 1, 23, 5)), '11');
    });

    test('24-hour, minutes and seconds are zero padded', () {
      final t = DateTime(2026, 1, 1, 7, 4, 9);
      expect(TimeFormat.hour24(t), '07');
      expect(TimeFormat.minute(t), '04');
      expect(TimeFormat.second(t), '09');
    });

    test('AM/PM switches at noon', () {
      expect(TimeFormat.meridiem(DateTime(2026, 1, 1, 11, 59)), 'AM');
      expect(TimeFormat.meridiem(DateTime(2026, 1, 1, 12, 0)), 'PM');
    });

    test('weekday and month names', () {
      // 23 September 2026 is a Wednesday.
      final t = DateTime(2026, 9, 23);
      expect(TimeFormat.weekdayShort(t), 'WED');
      expect(TimeFormat.monthName(t), 'September');
      expect(TimeFormat.dayOfMonth(DateTime(2026, 9, 5)), '5');
      expect(TimeFormat.weekdayShort(DateTime(2026, 9, 27)), 'SUN');
      expect(TimeFormat.monthName(DateTime(2026, 1, 1)), 'January');
      expect(TimeFormat.monthName(DateTime(2026, 12, 1)), 'December');
    });
  });

  group('BatteryInfo equality', () {
    test('equal values compare equal so repeat updates are dropped', () {
      expect(
        const BatteryInfo(level: 50, isCharging: true),
        const BatteryInfo(level: 50, isCharging: true),
      );
      expect(
        const BatteryInfo(level: 50, isCharging: true) ==
            const BatteryInfo(level: 51, isCharging: true),
        false,
      );
    });
  });

  group('MediaControllerService artwork reuse', () {
    const mediaChannel = EventChannel('com.desktune.app/media_events');
    const volumeChannel = EventChannel('com.desktune.app/volume_events');

    Map<String, Object?> event({required String key, Uint8List? artwork}) => {
      'hasActiveSession': true,
      'title': 'Song',
      'artist': 'Artist',
      'isPlaying': true,
      'artworkKey': key,
      'artwork': artwork,
    };

    testWidgets('keeps the same artwork instance until the key changes', (
      tester,
    ) async {
      MockStreamHandlerEventSink? sink;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockStreamHandler(
        mediaChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            sink = events;
          },
        ),
      );
      messenger.setMockStreamHandler(
        volumeChannel,
        MockStreamHandler.inline(onListen: (arguments, events) {}),
      );
      addTearDown(() {
        messenger.setMockStreamHandler(mediaChannel, null);
        messenger.setMockStreamHandler(volumeChannel, null);
      });

      final service = MediaControllerService();
      await tester.runAsync(service.resume);
      expect(sink, isNotNull);

      // Note: events are re-encoded by the channel codec, so compare the
      // instance the service holds across events, not the original bytes.
      sink!.success(event(key: 'a', artwork: Uint8List.fromList([1, 2, 3])));
      await tester.pump();
      final first = service.mediaInfo.value.artworkBytes;
      expect(first, [1, 2, 3]);

      // Same artwork, bytes omitted by the native side: instance is reused.
      sink!.success(event(key: 'a'));
      await tester.pump();
      expect(service.mediaInfo.value.artworkBytes, same(first));

      // New artwork arrives with new bytes.
      sink!.success(event(key: 'b', artwork: Uint8List.fromList([9, 9, 9, 9])));
      await tester.pump();
      final second = service.mediaInfo.value.artworkBytes;
      expect(second, [9, 9, 9, 9]);
      expect(second, isNot(same(first)));

      // Session ends: artwork is cleared.
      sink!.success(<String, Object?>{});
      await tester.pump();
      expect(service.mediaInfo.value.artworkBytes, isNull);

      await tester.runAsync(service.pause);
    });
  });
}
