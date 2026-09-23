import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/media_info.dart';

class ProgressSlider extends StatefulWidget {
  final MediaInfo media;
  final ValueChanged<int>? onSeek;

  const ProgressSlider({
    super.key,
    required this.media,
    this.onSeek,
  });

  @override
  State<ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends State<ProgressSlider> {
  Timer? _ticker;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant ProgressSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.media.isPlaying != oldWidget.media.isPlaying) {
      if (widget.media.isPlaying) {
        _startTicker();
      } else {
        _ticker?.cancel();
      }
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    if (widget.media.isPlaying) {
      _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted && _dragValue == null) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatDuration(int ms) {
    final totalSeconds = (ms / 1000).floor().clamp(0, 86400);
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    if (minutes >= 60) {
      final hours = (minutes / 60).floor();
      final remMinutes = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${remMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.media.durationMs;
    final currentPos = widget.media.currentPositionMs;
    final max = duration > 0 ? duration.toDouble() : 1.0;
    final current = (_dragValue ?? currentPos.toDouble()).clamp(0.0, max);
    final canSeek = widget.media.canSeek && duration > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 11.0),
            activeTrackColor: Colors.white,
            inactiveTrackColor: DeskTheme.sliderTrack,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: current,
            min: 0.0,
            max: max,
            onChanged: canSeek
                ? (val) {
                    setState(() {
                      _dragValue = val;
                    });
                  }
                : null,
            onChangeEnd: canSeek
                ? (val) {
                    final target = val.toInt();
                    widget.onSeek?.call(target);
                    setState(() {
                      _dragValue = null;
                    });
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(current.toInt()),
                style: const TextStyle(
                  fontFamily: 'Comfortaa',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DeskTheme.textMuted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                duration > 0 ? _formatDuration(duration) : '--:--',
                style: const TextStyle(
                  fontFamily: 'Comfortaa',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DeskTheme.textMuted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
