import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class VolumeSlider extends StatefulWidget {
  final ValueListenable<double> volumeListenable;
  final ValueChanged<double> onVolumeChanged;

  const VolumeSlider({
    super.key,
    required this.volumeListenable,
    required this.onVolumeChanged,
  });

  @override
  State<VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  double? _dragVolume;
  Timer? _dragReleaseTimer;
  DateTime _lastSentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    widget.volumeListenable.addListener(_onExternalVolumeChanged);
  }

  @override
  void didUpdateWidget(VolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.volumeListenable != widget.volumeListenable) {
      oldWidget.volumeListenable.removeListener(_onExternalVolumeChanged);
      widget.volumeListenable.addListener(_onExternalVolumeChanged);
    }
  }

  @override
  void dispose() {
    widget.volumeListenable.removeListener(_onExternalVolumeChanged);
    _dragReleaseTimer?.cancel();
    super.dispose();
  }

  void _onExternalVolumeChanged() {
    // Only update from hardware buttons/native if user is NOT currently dragging
    if (_dragVolume == null && mounted) {
      setState(() {});
    }
  }

  void _onSliderChanged(double val) {
    setState(() {
      _dragVolume = val;
    });

    // Throttle IPC calls to native audio manager to keep stream perfectly smooth
    final now = DateTime.now();
    if (now.difference(_lastSentTime).inMilliseconds >= 45) {
      _lastSentTime = now;
      widget.onVolumeChanged(val);
    }
  }

  void _onSliderChangeEnd(double val) {
    widget.onVolumeChanged(val);
    // Hold local value for 400ms so delayed Android broadcast echoes do not jump the thumb
    _dragReleaseTimer?.cancel();
    _dragReleaseTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _dragVolume = null;
        });
      }
    });
  }

  void _applyStep(double target) {
    final clamped = target.clamp(0.0, 1.0);
    setState(() {
      _dragVolume = clamped;
    });
    widget.onVolumeChanged(clamped);
    _dragReleaseTimer?.cancel();
    _dragReleaseTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _dragVolume = null;
        });
      }
    });
  }

  void _stepDown() {
    final current = _dragVolume ?? widget.volumeListenable.value;
    // Android has 15 volume steps (1 / 15 ≈ 0.0667)
    final next = current - (1.0 / 15.0);
    _applyStep(next <= 0.02 ? 0.0 : next);
  }

  void _stepUp() {
    final current = _dragVolume ?? widget.volumeListenable.value;
    final next = current + (1.0 / 15.0);
    _applyStep(next);
  }

  @override
  Widget build(BuildContext context) {
    final currentVol = (_dragVolume ?? widget.volumeListenable.value).clamp(0.0, 1.0);

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // iOS Cupertino speaker down button
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(28, 28),
            onPressed: _stepDown,
            child: Icon(
              currentVol <= 0.02
                  ? CupertinoIcons.speaker_slash_fill
                  : (currentVol < 0.35
                      ? CupertinoIcons.speaker_1_fill
                      : CupertinoIcons.speaker_fill),
              size: 14,
              color: Colors.white.withValues(alpha: 0.70),
            ),
          ),

          // iOS Capsule Scrub Track
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4.5,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6.0,
                  elevation: 1.0,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              ),
              child: Slider(
                value: currentVol,
                min: 0.0,
                max: 1.0,
                onChanged: _onSliderChanged,
                onChangeEnd: _onSliderChangeEnd,
              ),
            ),
          ),

          // iOS Cupertino speaker up button
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(28, 28),
            onPressed: _stepUp,
            child: Icon(
              CupertinoIcons.speaker_3_fill,
              size: 15,
              color: Colors.white.withValues(alpha: 0.70),
            ),
          ),
        ],
      ),
    );
  }
}
