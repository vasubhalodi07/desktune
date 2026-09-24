import 'dart:math' as math;
import 'package:flutter/foundation.dart'
    show ValueListenable, visibleForTesting;
import 'package:flutter/widgets.dart';

/// Nudges [child] by a few pixels, a little further along a slow path each
/// minute, so the same OLED pixels aren't lit at full brightness for hours
/// (burn-in protection for an always-on display).
///
/// The step happens on the clock's own tick, in the same frame that already
/// redraws the digits, so it adds no extra frames and no battery cost. It is an
/// instant, whole-pixel step rather than an animation, which keeps text crisp
/// and is unnoticeable next to the changing minute.
class BurnInShift extends StatelessWidget {
  /// Clock that drives the shift; it only needs to tick at least once a minute.
  final ValueListenable<DateTime> time;
  final Widget child;

  const BurnInShift({super.key, required this.time, required this.child});

  /// Largest shift, in logical pixels, along each axis.
  static const double amplitude = 6;

  // Different periods per axis, so the path wanders instead of retracing a
  // line: it only repeats after 23 * 29 = 667 minutes (about 11 hours).
  static const int _periodX = 23;
  static const int _periodY = 29;

  /// The shift for [time]: whole pixels within +/- [amplitude] on each axis.
  @visibleForTesting
  static Offset offsetFor(DateTime time) {
    final minute = time.hour * 60 + time.minute;
    final x = math.sin(minute * 2 * math.pi / _periodX);
    final y = math.sin(minute * 2 * math.pi / _periodY);
    return Offset(
      (x * amplitude).roundToDouble(),
      (y * amplitude).roundToDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // `child` is passed through the builder, so a tick only rebuilds the
    // translate, never the screen underneath it.
    return ValueListenableBuilder<DateTime>(
      valueListenable: time,
      child: child,
      builder: (context, now, child) =>
          Transform.translate(offset: offsetFor(now), child: child),
    );
  }
}
