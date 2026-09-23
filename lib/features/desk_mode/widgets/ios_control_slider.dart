import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum IosSliderType { brightness, volume }

class IosControlSlider extends StatefulWidget {
  final IosSliderType type;
  final ValueListenable<double> valueListenable;
  final ValueChanged<double> onChanged;
  final double? width;
  final double height;
  final Axis orientation;

  const IosControlSlider({
    super.key,
    required this.type,
    required this.valueListenable,
    required this.onChanged,
    this.width,
    this.height = 44.0,
    this.orientation = Axis.horizontal,
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

  void _handleTouch(Offset localPosition, double totalLength) {
    if (totalLength <= 0) return;
    final double ratio;
    if (widget.orientation == Axis.vertical) {
      ratio = (1.0 - (localPosition.dy / totalLength)).clamp(0.0, 1.0);
    } else {
      ratio = (localPosition.dx / totalLength).clamp(0.0, 1.0);
    }
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
    final isHorizontal = widget.orientation == Axis.horizontal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalLength = isHorizontal
            ? (widget.width ?? constraints.maxWidth)
            : widget.height;

        final bool isFilledOverIcon;
        if (isHorizontal) {
          isFilledOverIcon = (currentVal * totalLength) > 33.0;
        } else {
          isFilledOverIcon = currentVal > 0.22;
        }

        final iconColor = isFilledOverIcon
            ? const Color(0xFF2C2C2E)
            : Colors.white.withValues(alpha: 0.88);

        final radius = isHorizontal
            ? widget.height / 2
            : ((widget.width ?? 44.0) / 2);

        return GestureDetector(
          onVerticalDragStart: isHorizontal
              ? null
              : (details) => _handleTouch(details.localPosition, totalLength),
          onVerticalDragUpdate: isHorizontal
              ? null
              : (details) => _handleTouch(details.localPosition, totalLength),
          onVerticalDragEnd: isHorizontal
              ? null
              : (_) => _onSliderChangeEnd(currentVal),
          onHorizontalDragStart: isHorizontal
              ? (details) => _handleTouch(details.localPosition, totalLength)
              : null,
          onHorizontalDragUpdate: isHorizontal
              ? (details) => _handleTouch(details.localPosition, totalLength)
              : null,
          onHorizontalDragEnd: isHorizontal
              ? (_) => _onSliderChangeEnd(currentVal)
              : null,
          onTapDown: (details) {
            _handleTouch(details.localPosition, totalLength);
            final double tapRatio;
            if (isHorizontal) {
              tapRatio = (details.localPosition.dx / totalLength).clamp(0.0, 1.0);
            } else {
              tapRatio = (1.0 - (details.localPosition.dy / totalLength)).clamp(0.0, 1.0);
            }
            _onSliderChangeEnd(tapRatio);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: isHorizontal
                  ? Alignment.centerLeft
                  : Alignment.bottomCenter,
              children: [
                // Filled portion
                FractionallySizedBox(
                  widthFactor: isHorizontal ? currentVal : 1.0,
                  heightFactor: isHorizontal ? 1.0 : currentVal,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                  ),
                ),

                // Icon
                if (isHorizontal)
                  Positioned(
                    left: 13,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          _getIcon(currentVal),
                          key: ValueKey('${widget.type}_${currentVal > 0.02}'),
                          size: 18,
                          color: iconColor,
                        ),
                      ),
                    ),
                  )
                else
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
      },
    );
  }
}
