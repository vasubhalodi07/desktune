import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktune/models/app_settings.dart';
import 'package:desktune/models/media_info.dart';
import 'package:desktune/services/battery_service.dart';

void main() {
  group('MediaInfo model tests', () {
    test('Default MediaInfo is empty and not playing', () {
      const info = MediaInfo();
      expect(info.hasActiveSession, false);
      expect(info.isPlaying, false);
      expect(info.hasContent, false);
      expect(info.title, '');
    });

    test('Parses from map correctly', () {
      final map = {
        'hasActiveSession': true,
        'packageName': 'com.amazon.mp3',
        'title': 'Song 1',
        'artist': 'Artist A',
        'album': 'Album X',
        'duration': 200000,
        'position': 50000,
        'lastUpdateTime': DateTime.now().millisecondsSinceEpoch - 5000,
        'playbackSpeed': 1.0,
        'isPlaying': true,
        'canPlay': true,
        'canPause': true,
        'canNext': true,
        'canPrevious': true,
        'canSeek': true,
        'artwork': Uint8List.fromList([1, 2, 3, 4]),
      };

      final info = MediaInfo.fromMap(map);
      expect(info.hasActiveSession, true);
      expect(info.packageName, 'com.amazon.mp3');
      expect(info.title, 'Song 1');
      expect(info.artist, 'Artist A');
      expect(info.album, 'Album X');
      expect(info.isPlaying, true);
      expect(info.durationMs, 200000);
      expect(info.hasContent, true);
      expect(info.artworkBytes?.length, 4);

      // Estimated position should be around 55000 ms
      expect(info.currentPositionMs, greaterThanOrEqualTo(54000));
      expect(info.currentPositionMs, lessThanOrEqualTo(57000));
    });

    test('Handles paused estimated position without drift', () {
      final map = {
        'hasActiveSession': true,
        'title': 'Paused Song',
        'duration': 180000,
        'position': 42000,
        'lastUpdateTime': DateTime.now().millisecondsSinceEpoch - 10000,
        'isPlaying': false,
      };

      final info = MediaInfo.fromMap(map);
      expect(info.isPlaying, false);
      expect(info.currentPositionMs, 42000);
    });
  });

  group('AppSettings tests', () {
    test('Defaults and copyWith', () {
      const settings = AppSettings();
      expect(settings.is24HourFormat, false);
      expect(settings.showSeconds, false);
      expect(settings.showDate, true);
      expect(settings.autoHideControls, true);
      expect(settings.autoHideDelaySeconds, 5);

      final updated = settings.copyWith(
        is24HourFormat: true,
        showSeconds: true,
        autoHideDelaySeconds: 10,
        keepScreenAwake: false,
      );

      expect(updated.is24HourFormat, true);
      expect(updated.showSeconds, true);
      expect(updated.autoHideDelaySeconds, 10);
      expect(updated.showDate, true); // preserved
      expect(updated.keepScreenAwake, false);

      final map = updated.toMap();
      final fromMap = AppSettings.fromMap(map);
      expect(fromMap.is24HourFormat, true);
      expect(fromMap.autoHideDelaySeconds, 10);
      expect(fromMap.keepScreenAwake, false);
    });

    group('12/24-hour time format', () {
      test('follows the phone by default, and old saved data does too', () {
        expect(const AppSettings().followSystemTimeFormat, true);
        // Settings saved before this option existed have no such key.
        expect(
          AppSettings.fromMap({'is24HourFormat': false}).followSystemTimeFormat,
          true,
        );
      });

      test('the choice is saved and restored', () {
        final saved = const AppSettings().copyWith(
          followSystemTimeFormat: false,
          is24HourFormat: true,
        );
        final restored = AppSettings.fromMap(saved.toMap());
        expect(restored.followSystemTimeFormat, false);
        expect(restored.is24HourFormat, true);
      });

      test(
        'following the phone uses the phone setting, whatever was chosen',
        () {
          const settings = AppSettings(is24HourFormat: false);
          expect(
            settings.withSystemTimeFormat(systemIs24Hour: true).is24HourFormat,
            true,
          );
          expect(
            settings.withSystemTimeFormat(systemIs24Hour: false).is24HourFormat,
            false,
          );

          const chosen24 = AppSettings(is24HourFormat: true);
          expect(
            chosen24.withSystemTimeFormat(systemIs24Hour: false).is24HourFormat,
            false,
          );
        },
      );

      test('not following uses the manual choice, whatever the phone says', () {
        const manual12 = AppSettings(
          followSystemTimeFormat: false,
          is24HourFormat: false,
        );
        expect(
          manual12.withSystemTimeFormat(systemIs24Hour: true).is24HourFormat,
          false,
        );

        const manual24 = AppSettings(
          followSystemTimeFormat: false,
          is24HourFormat: true,
        );
        expect(
          manual24.withSystemTimeFormat(systemIs24Hour: false).is24HourFormat,
          true,
        );
      });
    });
  });

  group('BatteryInfo tests', () {
    test('Defaults to unknown level and not charging', () {
      const info = BatteryInfo();
      expect(info.level, -1);
      expect(info.isCharging, false);
    });

    test('Parses from native battery data map', () {
      final map = {'level': 94, 'isCharging': false};
      final info = BatteryInfo.fromMap(map);
      expect(info.level, 94);
      expect(info.isCharging, false);
    });
  });
}
