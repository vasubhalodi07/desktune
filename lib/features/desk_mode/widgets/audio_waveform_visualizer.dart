import 'dart:math' as math;
import 'package:flutter/material.dart';

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
  State<AudioWaveformVisualizer> createState() => _AudioWaveformVisualizerState();
}

class _AudioWaveformVisualizerState extends State<AudioWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AudioWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const minHeight = 3.5;
    final maxH = widget.maxHeight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * math.pi;

        // 4 distinct sinusoidal frequencies and phase offsets for rhythmic equalizer motion
        final h1 = widget.isPlaying
            ? (minHeight + (maxH - minHeight) * (0.5 + 0.5 * math.sin(t * 1.6)))
            : 4.5;
        final h2 = widget.isPlaying
            ? (minHeight + (maxH - minHeight) * (0.5 + 0.5 * math.sin(t * 2.2 + 1.2)))
            : 10.0;
        final h3 = widget.isPlaying
            ? (minHeight + (maxH - minHeight) * (0.5 + 0.5 * math.sin(t * 1.8 + 2.5)))
            : 6.5;
        final h4 = widget.isPlaying
            ? (minHeight + (maxH - minHeight) * (0.5 + 0.5 * math.sin(t * 1.3 + 3.9)))
            : 4.0;

        return SizedBox(
          height: maxH,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(h1),
              const SizedBox(width: 2.2),
              _buildBar(h2),
              const SizedBox(width: 2.2),
              _buildBar(h3),
              const SizedBox(width: 2.2),
              _buildBar(h4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: widget.barWidth,
      height: height,
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: widget.isPlaying ? 0.95 : 0.40),
        borderRadius: BorderRadius.circular(widget.barWidth / 2),
      ),
    );
  }
}
