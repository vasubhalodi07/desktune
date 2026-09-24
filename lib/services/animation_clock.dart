import 'dart:async';
import 'package:flutter/widgets.dart';

/// One shared low-frame-rate clock for ambient animations (glass mesh,
/// waveform).
///
/// An [AnimationController] produces a frame on every display refresh (120 Hz
/// on many phones), which is far more than a slow drifting gradient needs and
/// keeps the CPU and GPU busy all day. This clock ticks at [fps] instead, and
/// only while something is using it and the app is in the foreground, so an
/// idle screen produces no frames at all.
class AnimationClock extends ChangeNotifier with WidgetsBindingObserver {
  AnimationClock._();

  static final AnimationClock instance = AnimationClock._();

  static const int fps = 30;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _users = 0;
  bool _observing = false;
  bool _foreground = true;

  /// Time spent running; freezes while the clock is stopped so animations
  /// resume from where they left off.
  Duration get elapsed => _stopwatch.elapsed;

  bool get isRunning => _timer != null;

  /// Registers a consumer. The clock runs while at least one is registered.
  void acquire() {
    _users++;
    _sync();
  }

  void release() {
    if (_users > 0) _users--;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _sync();
  }

  void _sync() {
    if (_users > 0 && !_observing) {
      final binding = WidgetsBinding.instance;
      binding.addObserver(this);
      _observing = true;
      _foreground =
          binding.lifecycleState != AppLifecycleState.paused &&
          binding.lifecycleState != AppLifecycleState.hidden;
    }

    final shouldRun = _users > 0 && _foreground;
    if (shouldRun && _timer == null) {
      _stopwatch.start();
      _timer = Timer.periodic(
        Duration(milliseconds: 1000 ~/ fps),
        (_) => notifyListeners(),
      );
    } else if (!shouldRun && _timer != null) {
      _timer!.cancel();
      _timer = null;
      _stopwatch.stop();
    }

    if (_users == 0 && _observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }
}
