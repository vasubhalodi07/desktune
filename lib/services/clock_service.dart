import 'dart:async';
import 'package:flutter/foundation.dart';

class ClockService {
  final ValueNotifier<DateTime> currentTime = ValueNotifier(DateTime.now());
  Timer? _timer;

  void start() {
    _timer?.cancel();
    currentTime.value = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      currentTime.value = DateTime.now();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    currentTime.dispose();
  }
}
