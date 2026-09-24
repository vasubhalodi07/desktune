import 'dart:async';
import 'package:flutter/foundation.dart';

/// Publishes the current time, waking up only when the display can change.
///
/// Ticks are aligned to the wall clock. With [showSeconds] off the clock ticks
/// once a minute (60x fewer wake-ups than a per-second timer); with it on, once
/// a second. Nothing runs between [stop] and [start].
class ClockService {
  final ValueNotifier<DateTime> currentTime = ValueNotifier(DateTime.now());
  Timer? _timer;
  bool _running = false;
  bool _showSeconds = false;

  bool get isRunning => _running;

  /// Whether the UI displays seconds, which needs a tick every second.
  bool get showSeconds => _showSeconds;
  set showSeconds(bool value) {
    if (_showSeconds == value) return;
    _showSeconds = value;
    if (_running) _restart();
  }

  void start() {
    _running = true;
    _restart();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void _restart() {
    _timer?.cancel();
    currentTime.value = DateTime.now();
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer = Timer(delayUntilNextTick(DateTime.now(), _showSeconds), () {
      currentTime.value = DateTime.now();
      _scheduleNext();
    });
  }

  /// Time from [now] to the next second (or minute) boundary, plus a couple of
  /// milliseconds so the timer lands just after it.
  @visibleForTesting
  static Duration delayUntilNextTick(DateTime now, bool perSecond) {
    final periodMs = perSecond ? 1000 : 60000;
    final intoPeriodMs = perSecond
        ? now.millisecond
        : now.second * 1000 + now.millisecond;
    return Duration(milliseconds: periodMs - intoPeriodMs + 2);
  }

  void dispose() {
    stop();
    currentTime.dispose();
  }
}
