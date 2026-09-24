import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// A tiny SVG renderer for simple, single-colour logos and icons.
///
/// It exists so DeskTune can draw logo files without an SVG package. It reads
/// `path`, `circle`, `ellipse`, `rect`, `line`, `polyline` and `polygon`
/// elements, their `fill` / `stroke` settings (as attributes, inline `style`, or
/// simple `.class` rules in a `<style>` block) and the `viewBox`.
///
/// It deliberately ignores what a logo like this doesn't need: gradients,
/// transforms, groups and masks.
class SvgGlyph {
  const SvgGlyph({required this.viewBox, required this.shapes});

  /// The drawing space the shapes' coordinates are in.
  final Rect viewBox;
  final List<SvgShape> shapes;

  /// Parses SVG text. Unsupported elements are skipped rather than failing.
  factory SvgGlyph.parse(String svg) {
    final rules = _cssRulesOf(svg);
    // <defs> holds styles, clip paths and the like; it is never drawn itself.
    final drawable = svg.replaceAll(RegExp(r'<defs\b[\s\S]*?</defs>'), '');

    final shapes = <SvgShape>[];
    for (final match in _elementPattern.allMatches(drawable)) {
      final tag = match.group(1)!;
      final attrs = _attributesOf(match.group(2)!);
      final path = _pathFor(tag, attrs);
      if (path == null) continue;

      final props = _resolveProperties(attrs, rules);
      final fill = _paints(props['fill'] ?? 'black');
      final stroke = _paints(props['stroke'] ?? 'none');
      if (!fill && !stroke) continue;
      if (props['fill-rule'] == 'evenodd') path.fillType = PathFillType.evenOdd;

      shapes.add(
        SvgShape(
          path: path,
          fill: fill,
          stroke: stroke,
          strokeWidth: double.tryParse(props['stroke-width'] ?? '') ?? 1,
          cap: switch (props['stroke-linecap']) {
            'round' => StrokeCap.round,
            'square' => StrokeCap.square,
            _ => StrokeCap.butt,
          },
          join: switch (props['stroke-linejoin']) {
            'round' => StrokeJoin.round,
            'bevel' => StrokeJoin.bevel,
            _ => StrokeJoin.miter,
          },
        ),
      );
    }
    return SvgGlyph(viewBox: _viewBoxOf(svg), shapes: shapes);
  }

  static final RegExp _elementPattern = RegExp(
    r'<(path|circle|ellipse|rect|line|polyline|polygon)\b([^>]*?)/?>',
  );

  static bool _paints(String value) =>
      value != 'none' && value != 'transparent';
}

/// One drawable piece of an [SvgGlyph]: a path and how to paint it.
class SvgShape {
  const SvgShape({
    required this.path,
    required this.fill,
    required this.stroke,
    this.strokeWidth = 1,
    this.cap = StrokeCap.butt,
    this.join = StrokeJoin.miter,
  });

  final Path path;
  final bool fill;
  final bool stroke;

  /// Line thickness in the SVG's own units.
  final double strokeWidth;
  final StrokeCap cap;
  final StrokeJoin join;
}

/// Paints an [SvgGlyph] in a single [color], scaled to fit and centred.
class SvgGlyphPainter extends CustomPainter {
  const SvgGlyphPainter({
    required this.glyph,
    required this.color,
    this.minStrokePx = 1.2,
  });

  final SvgGlyph glyph;
  final Color color;

  /// The thinnest a line or dot may be drawn, in screen pixels. Fine line art
  /// designed at large sizes would otherwise vanish in a small icon.
  final double minStrokePx;

  @override
  void paint(Canvas canvas, Size size) {
    final box = glyph.viewBox;
    if (box.width <= 0 || box.height <= 0) return;

    final scale = math.min(size.width / box.width, size.height / box.height);
    final minStroke = minStrokePx / scale;

    canvas.save();
    canvas.translate(
      (size.width - box.width * scale) / 2,
      (size.height - box.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.translate(-box.left, -box.top);

    for (final shape in glyph.shapes) {
      if (shape.fill) {
        canvas.drawPath(
          shape.path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = color,
        );
        // A tiny filled dot (like the dot of an "i") would disappear when small.
        if (shape.path.getBounds().shortestSide < minStroke * 2) {
          canvas.drawPath(
            shape.path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = minStroke
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = color,
          );
        }
      }
      if (shape.stroke) {
        canvas.drawPath(
          shape.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(shape.strokeWidth, minStroke)
            ..strokeCap = shape.cap
            ..strokeJoin = shape.join
            ..color = color,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SvgGlyphPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.minStrokePx != minStrokePx;
}

// ---------------------------------------------------------------------------
// Parsing helpers
// ---------------------------------------------------------------------------

final RegExp _attributePattern = RegExp(
  r'''([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')''',
);

Map<String, String> _attributesOf(String text) => {
  for (final m in _attributePattern.allMatches(text))
    m.group(1)!: (m.group(2) ?? m.group(3))!,
};

/// `.name { prop: value; ... }` rules from any `<style>` block, by class name.
Map<String, Map<String, String>> _cssRulesOf(String svg) {
  final rules = <String, Map<String, String>>{};
  for (final block in RegExp(
    r'<style[^>]*>([\s\S]*?)</style>',
  ).allMatches(svg)) {
    for (final rule in RegExp(
      r'\.([\w-]+)\s*\{([^}]*)\}',
    ).allMatches(block.group(1)!)) {
      rules
          .putIfAbsent(rule.group(1)!, () => {})
          .addAll(_declarationsOf(rule.group(2)!));
    }
  }
  return rules;
}

Map<String, String> _declarationsOf(String text) {
  final result = <String, String>{};
  for (final part in text.split(';')) {
    final colon = part.indexOf(':');
    if (colon <= 0) continue;
    result[part.substring(0, colon).trim().toLowerCase()] = part
        .substring(colon + 1)
        .trim()
        .toLowerCase();
  }
  return result;
}

const _paintAttributes = [
  'fill',
  'stroke',
  'stroke-width',
  'stroke-linecap',
  'stroke-linejoin',
  'fill-rule',
];

/// Paint settings for an element: attributes, then class rules, then inline
/// `style`, each overriding the last (as in CSS).
Map<String, String> _resolveProperties(
  Map<String, String> attrs,
  Map<String, Map<String, String>> rules,
) {
  final props = <String, String>{
    for (final name in _paintAttributes)
      if (attrs[name] != null) name: attrs[name]!.trim().toLowerCase(),
  };
  for (final className in (attrs['class'] ?? '').split(RegExp(r'\s+'))) {
    props.addAll(rules[className] ?? const {});
  }
  props.addAll(_declarationsOf(attrs['style'] ?? ''));
  return props;
}

Rect _viewBoxOf(String svg) {
  final box = RegExp(r'viewBox\s*=\s*"([^"]+)"').firstMatch(svg)?.group(1);
  if (box != null) {
    final n = box
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .map(double.tryParse)
        .toList();
    if (n.length == 4 && !n.contains(null)) {
      return Rect.fromLTWH(n[0]!, n[1]!, n[2]!, n[3]!);
    }
  }
  double dimension(String name) =>
      double.tryParse(
        RegExp('$name\\s*=\\s*"([\\d.]+)').firstMatch(svg)?.group(1) ?? '',
      ) ??
      24;
  return Rect.fromLTWH(0, 0, dimension('width'), dimension('height'));
}

Path? _pathFor(String tag, Map<String, String> attrs) {
  double number(String key, [double fallback = 0]) =>
      double.tryParse(
        (attrs[key] ?? '').replaceAll(RegExp(r'[a-zA-Z%]+$'), ''),
      ) ??
      fallback;

  switch (tag) {
    case 'path':
      final data = attrs['d'];
      return data == null ? null : parseSvgPathData(data);
    case 'circle':
      return Path()..addOval(
        Rect.fromCircle(
          center: Offset(number('cx'), number('cy')),
          radius: number('r'),
        ),
      );
    case 'ellipse':
      return Path()..addOval(
        Rect.fromCenter(
          center: Offset(number('cx'), number('cy')),
          width: number('rx') * 2,
          height: number('ry') * 2,
        ),
      );
    case 'rect':
      final rect = Rect.fromLTWH(
        number('x'),
        number('y'),
        number('width'),
        number('height'),
      );
      final rx = number('rx', number('ry'));
      final ry = number('ry', rx);
      return Path()..addRRect(
        rx > 0 || ry > 0
            ? RRect.fromRectXY(rect, rx, ry)
            : RRect.fromRectAndRadius(rect, Radius.zero),
      );
    case 'line':
      return Path()
        ..moveTo(number('x1'), number('y1'))
        ..lineTo(number('x2'), number('y2'));
    case 'polyline':
    case 'polygon':
      final points = RegExp(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?')
          .allMatches(attrs['points'] ?? '')
          .map((m) => double.parse(m.group(0)!))
          .toList();
      if (points.length < 4) return null;
      final path = Path()..moveTo(points[0], points[1]);
      for (var i = 2; i + 1 < points.length; i += 2) {
        path.lineTo(points[i], points[i + 1]);
      }
      if (tag == 'polygon') path.close();
      return path;
  }
  return null;
}

/// Converts SVG path data (`d="M0 0 L10 10 ..."`) into a [Path].
///
/// Supports every SVG path command, absolute and relative. Elliptical arcs map
/// straight onto [Path.arcToPoint], which uses the same flags as SVG.
Path parseSvgPathData(String data) {
  final path = Path();
  final scanner = _PathScanner(data);

  var x = 0.0, y = 0.0; // current point
  var startX = 0.0, startY = 0.0; // start of the current sub-path
  double? lastCubicX, lastCubicY; // previous cubic control point (for S)
  double? lastQuadX, lastQuadY; // previous quadratic control point (for T)
  var command = '';

  while (!scanner.isDone) {
    if (scanner.nextIsCommand) {
      command = scanner.readCommand();
    } else if (command.isEmpty || command == 'Z' || command == 'z') {
      throw FormatException('Unexpected number in path data', data);
    }
    final relative = command == command.toLowerCase();
    final dx = relative ? x : 0.0;
    final dy = relative ? y : 0.0;

    var cubic = false, quad = false;
    switch (command.toUpperCase()) {
      case 'M':
        x = dx + scanner.number();
        y = dy + scanner.number();
        path.moveTo(x, y);
        startX = x;
        startY = y;
        // Extra coordinate pairs after a moveto are implicit lineto commands.
        command = relative ? 'l' : 'L';
      case 'L':
        x = dx + scanner.number();
        y = dy + scanner.number();
        path.lineTo(x, y);
      case 'H':
        x = dx + scanner.number();
        path.lineTo(x, y);
      case 'V':
        y = dy + scanner.number();
        path.lineTo(x, y);
      case 'C':
        final x1 = dx + scanner.number(), y1 = dy + scanner.number();
        final x2 = dx + scanner.number(), y2 = dy + scanner.number();
        x = dx + scanner.number();
        y = dy + scanner.number();
        path.cubicTo(x1, y1, x2, y2, x, y);
        lastCubicX = x2;
        lastCubicY = y2;
        cubic = true;
      case 'S':
        // The first control point mirrors the previous curve's second one.
        final prevX = lastCubicX, prevY = lastCubicY;
        final x1 = prevX == null || prevY == null ? x : 2 * x - prevX;
        final y1 = prevX == null || prevY == null ? y : 2 * y - prevY;
        final x2 = dx + scanner.number(), y2 = dy + scanner.number();
        x = dx + scanner.number();
        y = dy + scanner.number();
        path.cubicTo(x1, y1, x2, y2, x, y);
        lastCubicX = x2;
        lastCubicY = y2;
        cubic = true;
      case 'Q':
        final x1 = dx + scanner.number(), y1 = dy + scanner.number();
        x = dx + scanner.number();
        y = dy + scanner.number();
        path.quadraticBezierTo(x1, y1, x, y);
        lastQuadX = x1;
        lastQuadY = y1;
        quad = true;
      case 'T':
        final prevX = lastQuadX, prevY = lastQuadY;
        final x1 = prevX == null || prevY == null ? x : 2 * x - prevX;
        final y1 = prevX == null || prevY == null ? y : 2 * y - prevY;
        x = dx + scanner.number();
        y = dy + scanner.number();
        path.quadraticBezierTo(x1, y1, x, y);
        lastQuadX = x1;
        lastQuadY = y1;
        quad = true;
      case 'A':
        final rx = scanner.number().abs(), ry = scanner.number().abs();
        final rotation = scanner.number();
        final largeArc = scanner.flag();
        final sweep = scanner.flag();
        x = dx + scanner.number();
        y = dy + scanner.number();
        if (rx == 0 || ry == 0) {
          path.lineTo(x, y);
        } else {
          path.arcToPoint(
            Offset(x, y),
            radius: Radius.elliptical(rx, ry),
            rotation: rotation,
            largeArc: largeArc,
            clockwise: sweep,
          );
        }
      case 'Z':
        path.close();
        x = startX;
        y = startY;
      default:
        throw FormatException('Unknown path command "$command"', data);
    }
    if (!cubic) {
      lastCubicX = null;
      lastCubicY = null;
    }
    if (!quad) {
      lastQuadX = null;
      lastQuadY = null;
    }
  }
  return path;
}

/// Reads path data one token at a time. Handles the compact forms minified SVGs
/// use: no separator before a minus sign, `.5.5` as two numbers, and arc flags
/// written without separators (`a1 1 0 011 1`).
class _PathScanner {
  _PathScanner(this._text);

  final String _text;
  int _index = 0;

  static const String _commands = 'MmLlHhVvCcSsQqTtAaZz';
  static final RegExp _number = RegExp(
    r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?',
  );

  void _skipSeparators() {
    while (_index < _text.length && ' ,\n\r\t'.contains(_text[_index])) {
      _index++;
    }
  }

  bool get isDone {
    _skipSeparators();
    return _index >= _text.length;
  }

  bool get nextIsCommand {
    _skipSeparators();
    return _index < _text.length && _commands.contains(_text[_index]);
  }

  String readCommand() => _text[_index++];

  double number() {
    _skipSeparators();
    final match = _number.matchAsPrefix(_text, _index);
    if (match == null) {
      throw FormatException('Expected a number', _text, _index);
    }
    _index = match.end;
    return double.parse(match.group(0)!);
  }

  /// An arc flag: a single `0` or `1` character.
  bool flag() {
    _skipSeparators();
    if (_index >= _text.length) {
      throw FormatException('Expected an arc flag', _text, _index);
    }
    final char = _text[_index++];
    if (char != '0' && char != '1') {
      throw FormatException('Invalid arc flag "$char"', _text, _index - 1);
    }
    return char == '1';
  }
}
