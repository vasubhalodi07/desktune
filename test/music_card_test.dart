import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktune/features/desk_mode/widgets/music_artwork.dart';
import 'package:desktune/features/desk_mode/widgets/player_app_icon.dart';
import 'package:desktune/features/desk_mode/widgets/player_glyphs.dart';
import 'package:desktune/features/desk_mode/widgets/svg_glyph.dart';
import 'package:desktune/models/media_info.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

// A valid 1x1 PNG, standing in for an app icon.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  group('PlayerAppIcon', () {
    testWidgets('shows the default music-note tile when there is no icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PlayerAppIcon(
            packageName: 'com.example',
            loadIcon: (_) async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.music_note), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('shows the real app icon when Android supplies it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PlayerAppIcon(
            packageName: 'com.example',
            loadIcon: (_) async => _png,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.music_note), findsNothing);
    });

    testWidgets('loads once per app and again when the app changes', (
      tester,
    ) async {
      final requested = <String>[];
      Future<Uint8List?> load(String package) async {
        requested.add(package);
        return null;
      }

      Widget build(String package) =>
          _host(PlayerAppIcon(packageName: package, loadIcon: load));

      await tester.pumpWidget(build('com.a'));
      await tester.pumpWidget(build('com.a'));
      expect(requested, ['com.a']);

      await tester.pumpWidget(build('com.b'));
      expect(requested, ['com.a', 'com.b']);
    });

    testWidgets('calls onTap and is labelled for accessibility', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PlayerAppIcon(
            packageName: 'com.example.player',
            appName: 'Example Player',
            loadIcon: (_) async => null,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Open Example Player'), findsOneWidget);
      await tester.tap(find.byType(PlayerAppIcon));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('is not tappable without an onTap', (tester) async {
      await tester.pumpWidget(
        _host(
          PlayerAppIcon(
            packageName: 'com.example',
            loadIcon: (_) async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  group('parseSvgPathData', () {
    test('absolute and relative commands close a square', () {
      final bounds = parseSvgPathData('M10 10 h20 v20 h-20 z').getBounds();
      expect(bounds, const Rect.fromLTRB(10, 10, 30, 30));
    });

    test('extra coordinate pairs after a moveto are line segments', () {
      final bounds = parseSvgPathData('m10 10 20 0 0 20').getBounds();
      expect(bounds, const Rect.fromLTRB(10, 10, 30, 30));
    });

    test('reads compact numbers written without separators', () {
      // "10 0-5 5" is (10, 0) then (-5, 5).
      final bounds = parseSvgPathData('M0 0L10 0-5 5').getBounds();
      expect(bounds, const Rect.fromLTRB(-5, 0, 10, 5));
    });

    test('draws arcs, including flags written without separators', () {
      for (final data in ['M0 0a5 5 0 0 1 10 0', 'M0 0a5 5 0 0110 0']) {
        final bounds = parseSvgPathData(data).getBounds();
        expect(bounds.left, closeTo(0, 0.1), reason: data);
        expect(bounds.right, closeTo(10, 0.1), reason: data);
        expect(bounds.top, closeTo(-5, 0.1), reason: data); // bulges upward
      }
    });

    test('smooth curves continue from the previous control point', () {
      expect(
        () => parseSvgPathData('M0 0C1 1 2 1 3 0S5 -1 6 0'),
        returnsNormally,
      );
    });

    test('rejects unknown commands', () {
      expect(() => parseSvgPathData('M0 0 X1'), throwsFormatException);
    });
  });

  group('SvgGlyph.parse', () {
    test('reads the viewBox, class styles and shape kinds', () {
      final glyph = SvgGlyph.parse(
        '<svg viewBox="0 0 48 48"><defs><style>'
        '.a{fill:none;stroke:#000;stroke-linecap:round}.b{fill:#000}'
        '</style></defs>'
        '<circle class="a" cx="24" cy="24" r="20"/>'
        '<circle class="b" cx="30" cy="10" r="1"/>'
        '<rect fill="none" stroke="red" x="1" y="1" width="5" height="5"/>'
        '<path d="M0 0L5 5" fill="none"/>'
        '</svg>',
      );

      expect(glyph.viewBox, const Rect.fromLTWH(0, 0, 48, 48));
      // The last path paints nothing (no fill, no stroke), so it is skipped.
      expect(glyph.shapes, hasLength(3));

      final ring = glyph.shapes[0];
      expect(ring.stroke, isTrue);
      expect(ring.fill, isFalse);
      expect(ring.cap, StrokeCap.round);

      final dot = glyph.shapes[1];
      expect(dot.fill, isTrue);
      expect(dot.stroke, isFalse);
    });

    test('fills black by default and honours inline styles', () {
      final glyph = SvgGlyph.parse(
        '<svg viewBox="0 0 10 10">'
        '<path d="M0 0h10v10z"/>'
        '<path style="fill:none;stroke:blue;stroke-width:3" d="M0 0L9 9"/>'
        '</svg>',
      );

      expect(glyph.shapes[0].fill, isTrue);
      expect(glyph.shapes[1].fill, isFalse);
      expect(glyph.shapes[1].stroke, isTrue);
      expect(glyph.shapes[1].strokeWidth, 3);
    });
  });

  group('bundled player logos', () {
    SvgGlyph load(String name) =>
        SvgGlyph.parse(File('assets/glyphs/$name.svg').readAsStringSync());

    Rect bounds(SvgGlyph glyph) => glyph.shapes
        .map((shape) => shape.path.getBounds())
        .reduce((a, b) => a.expandToInclude(b));

    test('Amazon Music: 48x48 line art with a dot, inside its viewBox', () {
      final glyph = load('amazon-music');
      expect(glyph.viewBox, const Rect.fromLTWH(0, 0, 48, 48));
      expect(glyph.shapes.where((s) => s.stroke), isNotEmpty);
      expect(glyph.shapes.where((s) => s.fill), isNotEmpty); // the "i" dot
      final box = bounds(glyph);
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(48));
      expect(box.width, greaterThan(40)); // the outer ring
    });

    test('Spotify: one filled 24x24 shape', () {
      final glyph = load('spotify');
      expect(glyph.viewBox, const Rect.fromLTWH(0, 0, 24, 24));
      expect(glyph.shapes, hasLength(1));
      expect(glyph.shapes.single.fill, isTrue);
      expect(bounds(glyph).width, closeTo(24, 0.1));
    });

    test('YouTube Music: one filled 24x24 shape', () {
      final glyph = load('youtube-music');
      expect(glyph.viewBox, const Rect.fromLTWH(0, 0, 24, 24));
      expect(glyph.shapes, hasLength(1));
      expect(glyph.shapes.single.fill, isTrue);
      expect(bounds(glyph).width, closeTo(24, 0.1));
    });
  });

  group('PlayerGlyphs', () {
    test('knows the popular players and leaves the rest to Android', () {
      for (final package in [
        'com.amazon.mp3',
        'com.spotify.music',
        'com.google.android.apps.youtube.music',
      ]) {
        expect(PlayerGlyphs.hasGlyph(package), isTrue, reason: package);
      }
      expect(PlayerGlyphs.hasGlyph('com.example.unknown'), isFalse);
    });

    testWidgets('loads each bundled logo, and null for unknown players', (
      tester,
    ) async {
      for (final package in [
        'com.amazon.mp3',
        'com.spotify.music',
        'com.google.android.apps.youtube.music',
      ]) {
        final glyph = await tester.runAsync(() => PlayerGlyphs.load(package));
        expect(glyph, isNotNull, reason: package);
      }
      expect(
        await tester.runAsync(() => PlayerGlyphs.load('com.example.unknown')),
        isNull,
      );
    });

    testWidgets('a known player draws its logo and skips the icon lookup', (
      tester,
    ) async {
      var lookups = 0;
      // Read the asset outside the test clock, then let the widget use it.
      await tester.runAsync(() => PlayerGlyphs.load('com.spotify.music'));

      await tester.pumpWidget(
        _host(
          PlayerAppIcon(
            packageName: 'com.spotify.music',
            loadIcon: (_) async {
              lookups++;
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(lookups, 0);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is SvgGlyphPainter,
        ),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
    });
  });

  group('MusicArtwork tap', () {
    testWidgets('calls onTap when the artwork is tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(MusicArtwork(artworkBytes: null, size: 68, onTap: () => taps++)),
      );

      await tester.tap(find.byType(MusicArtwork));
      expect(taps, 1);
    });

    testWidgets('is not tappable without an onTap', (tester) async {
      await tester.pumpWidget(
        _host(const MusicArtwork(artworkBytes: null, size: 68)),
      );

      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  group('MediaInfo.appName', () {
    test('is read from the native map', () {
      final info = MediaInfo.fromMap({
        'hasActiveSession': true,
        'packageName': 'com.amazon.mp3',
        'appName': 'Amazon Music',
      });
      expect(info.appName, 'Amazon Music');
    });

    test('defaults to empty when the native side has no name', () {
      expect(MediaInfo.fromMap({'hasActiveSession': true}).appName, '');
      expect(const MediaInfo().appName, '');
    });
  });
}
