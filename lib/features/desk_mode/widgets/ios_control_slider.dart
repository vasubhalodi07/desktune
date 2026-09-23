import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum IosSliderType { brightness, volume }

class IosControlSlider extends StatefulWidget {
  final IosSliderType type;
  final ValueListenable<double> valueListenable;
  final ValueChanged<double> onChanged;
  final double width;
  final double height;

  const IosControlSlider({
    super.key,
    required this.type,
    required this.valueListenable,
    required this.onChanged,
    this.width = 44.0,
    this.height = 136.0,
  });

  @override
  State<IosControlSlider> createState() => _IosControlSliderState();
}

class _IosControlSliderState extends State<IosControlSlider> {
  double? _dragValue;
  Timer? _dragReleaseTimer;
  DateTime _lastSentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    widget.valueListenable.addListener(_onExternalValueChanged);
  }

  @override
  void didUpdateWidget(IosControlSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueListenable != widget.valueListenable) {
      oldWidget.valueListenable.removeListener(_onExternalValueChanged);
      widget.valueListenable.addListener(_onExternalValueChanged);
    }
  }

  @override
  void dispose() {
    widget.valueListenable.removeListener(_onExternalValueChanged);
    _dragReleaseTimer?.cancel();
    super.dispose();
  }

  void _onExternalValueChanged() {
    if (_dragValue == null && mounted) {
      setState(() {});
    }
  }

  void _onSliderChanged(double val) {
    setState(() {
      _dragValue = val;
    });

    final now = DateTime.now();
    if (now.difference(_lastSentTime).inMilliseconds >= 35) {
      _lastSentTime = now;
      widget.onChanged(val);
    }
  }

  void _onSliderChangeEnd(double val) {
    widget.onChanged(val);
    _dragReleaseTimer?.cancel();
    _dragReleaseTimer = Timer(const Duration(milliseconds: 380), () {
      if (mounted) {
        setState(() {
          _dragValue = null;
        });
      }
    });
  }

  void _handleTouch(Offset localPosition) {
    final ratio = (1.0 - (localPosition.dy / widget.height)).clamp(0.0, 1.0);
    _onSliderChanged(ratio);
  }

  IconData _getIcon(double val) {
    if (widget.type == IosSliderType.brightness) {
      return CupertinoIcons.sun_max_fill;
    } else {
      if (val <= 0.02) {
        return CupertinoIcons.speaker_slash_fill;
      } else if (val < 0.35) {
        return CupertinoIcons.speaker_1_fill;
      } else if (val < 0.70) {
        return CupertinoIcons.speaker_2_fill;
      } else {
        return CupertinoIcons.speaker_3_fill;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentVal = (_dragValue ?? widget.valueListenable.value).clamp(0.0, 1.0);
    // Dynamic contrast inversion matching iOS Control Center:
    // If fill level is higher than icon position (~0.22), icon becomes dark charcoal; otherwise white.
    final iconColor = currentVal > 0.22
        ? const Color(0xFF2C2C2E)
        : Colors.white.withValues(alpha: 0.88);

    return GestureDetector(
      onVerticalDragStart: (details) => _handleTouch(details.localPosition),
      onVerticalDragUpdate: (details) => _handleTouch(details.localPosition),
      onVerticalDragEnd: (_) => _onSliderChangeEnd(currentVal),
      onTapDown: (details) {
        _handleTouch(details.localPosition);
        _onSliderChangeEnd((1.0 - (details.localPosition.dy / widget.height)).clamp(0.0, 1.0));
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(widget.width / 2),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Filled portion rising from the bottom
            FractionallySizedBox(
              heightFactor: currentVal,
              widthFactor: 1.0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
              ),
            ),

            // Icon placed at bottom inside the pill
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    _getIcon(currentVal),
                    key: ValueKey('${widget.type}_${currentVal > 0.02}'),
                    size: 20,
                    color: iconColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
