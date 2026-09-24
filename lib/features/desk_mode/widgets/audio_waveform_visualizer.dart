import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/animation_clock.dart';

/// Four-bar equalizer that bounces while [isPlaying].
///
/// Driven by the shared low-frame-rate [AnimationClock] and painted directly,
/// so it neither rebuilds widgets nor produces frames while paused.
class AudioWaveformVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double barWidth;
  final double maxHeight;

  const AudioWaveformVisualizer({
    super.key,
    required this.isPlaying,
    this.color = Colors.white,
    this.barWidth = 2.5,
    this.maxHeight = 14.0,
  });

  @override
  State<AudioWaveformVisualizer> createState() =>
      _AudioWaveformVisualizerState();
}

class _AudioWaveformVisualizerState extends State<AudioWaveformVisualizer> {
  static const double _barGap = 2.2;
  static const int _barCount = 4;

  bool _holdingClock = false;

  @override
  void initState() {
    super.initState();
    _syncClock();
  }

  @override
  void didUpdateWidget(covariant AudioWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncClock();
  }

  @override
  void dispose() {
    if (_holdingClock) AnimationClock.instance.release();
    super.dispose();
  }

  void _syncClock() {
    if (widget.isPlaying && !_holdingClock) {
      AnimationClock.instance.acquire();
      _holdingClock = true;
    } else if (!widget.isPlaying && _holdingClock) {
      AnimationClock.instance.release();
      _holdingClock = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(
          _barCount * widget.barWidth + (_barCount - 1) * _barGap,
          widget.maxHeight,
        ),
        painter: _WaveformPainter(
          isPlaying: widget.isPlaying,
          color: widget.color,
          barWidth: widget.barWidth,
          maxHeight: widget.maxHeight,
          gap: _barGap,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final bool isPlaying;
  final Color color;
  final double barWidth;
  final double maxHeight;
  final double gap;

  static const double _minHeight = 3.5;
  static const int _cycleMs = 900;

  // Resting heights while paused.
  static const List<double> _restingHeights = [4.5, 10.0, 6.5, 4.0];

  // Four distinct frequencies and phase offsets for rhythmic motion.
  static const List<double> _frequencies = [1.6, 2.2, 1.8, 1.3];
  static const List<double> _phases = [0.0, 1.2, 2.5, 3.9];

  _WaveformPainter({
    required this.isPlaying,
    required this.color,
    required this.barWidth,
    required this.maxHeight,
    required this.gap,
  }) : super(repaint: isPlaying ? AnimationClock.instance : null);

  @override
  void paint(Canvas canvas, Size size) {
    final t = isPlaying
        ? (AnimationClock.instance.elapsed.inMilliseconds % _cycleMs) /
              _cycleMs *
              2 *
              math.pi
        : 0.0;
    final paint = Paint()
      ..color = color.withValues(alpha: isPlaying ? 0.95 : 0.40);

    for (var i = 0; i < _restingHeights.length; i++) {
      final height = isPlaying
          ? _minHeight +
                (maxHeight - _minHeight) *
                    (0.5 + 0.5 * math.sin(t * _frequencies[i] + _phases[i]))
          : _restingHeights[i];
      final left = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) {
    return old.isPlaying != isPlaying ||
        old.color != color ||
        old.barWidth != barWidth ||
        old.maxHeight != maxHeight ||
        old.gap != gap;
  }
}
