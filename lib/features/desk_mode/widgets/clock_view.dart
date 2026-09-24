import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../models/app_settings.dart';
import '../../../services/battery_service.dart';
import '../../../services/time_format.dart';

class ClockView extends StatelessWidget {
  final ValueListenable<DateTime> time;
  final AppSettings settings;
  final BatteryInfo? batteryInfo;
  final bool isExpanded;
  final bool showControls;
  final VoidCallback? onTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onExpandTap;

  const ClockView({
    super.key,
    required this.time,
    required this.settings,
    this.batteryInfo,
    this.isExpanded = false,
    this.showControls = true,
    this.onTap,
    this.onSettingsTap,
    this.onExpandTap,
  });

  @override
  Widget build(BuildContext context) {
    // Only the clock rebuilds on a tick; the rest of the screen is untouched.
    return ValueListenableBuilder<DateTime>(
      valueListenable: time,
      builder: (context, dateTime, _) => _buildClock(dateTime),
    );
  }

  Widget _buildClock(DateTime dateTime) {
    // Seconds are never rendered on the split music screen
    final showSeconds = isExpanded && settings.showSeconds;
    final hoursStr = settings.is24HourFormat
        ? TimeFormat.hour24(dateTime)
        : TimeFormat.hour12(dateTime);
    final minutesStr = TimeFormat.minute(dateTime);
    final secondsStr = showSeconds ? TimeFormat.second(dateTime) : '';
    final amPmStr = settings.is24HourFormat
        ? ''
        : TimeFormat.meridiem(dateTime);

    final dayShort = TimeFormat.weekdayShort(dateTime);
    final dayNum = TimeFormat.dayOfMonth(dateTime);
    final monthFull = TimeFormat.monthName(dateTime);

    // Comfortaa rounded clock typography
    final clockFontSize = isExpanded ? 210.0 : 130.0;
    const clockFontFamily = 'Comfortaa';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Apple StandBy Date & Battery Pill
          if (settings.showDate || batteryInfo != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (settings.showDate) ...[
                        Text(
                          dayShort,
                          style: const TextStyle(
                            fontFamily: clockFontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: DeskTheme.accentRed,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$dayNum  •  $monthFull',
                          style: const TextStyle(
                            fontFamily: clockFontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: DeskTheme.textSecondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                      if (batteryInfo != null) ...[
                        if (settings.showDate)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Container(
                              width: 1,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        _buildBatteryStatus(batteryInfo!, clockFontFamily),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: isExpanded ? 24 : 18),
          ],

          // Clock Digits (Tall condensed iOS LockScreen Typography with circular colon dots)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hoursStr,
                    style: TextStyle(
                      fontFamily: clockFontFamily,
                      fontSize: clockFontSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -1.0,
                      height: 0.95,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  _buildColon(clockFontSize),
                  Text(
                    minutesStr,
                    style: TextStyle(
                      fontFamily: clockFontFamily,
                      fontSize: clockFontSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -1.0,
                      height: 0.95,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (secondsStr.isNotEmpty) ...[
                    _buildColon(clockFontSize),
                    Text(
                      secondsStr,
                      style: TextStyle(
                        fontFamily: clockFontFamily,
                        fontSize: clockFontSize,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -1.0,
                        height: 0.95,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  if (amPmStr.isNotEmpty) ...[
                    SizedBox(width: isExpanded ? 16 : 10),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: isExpanded ? 18.0 : 11.0,
                        ),
                        child: Text(
                          amPmStr,
                          style: TextStyle(
                            fontFamily: clockFontFamily,
                            fontSize: isExpanded ? 34 : 20,
                            fontWeight: FontWeight.w700,
                            color: DeskTheme.textMuted,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Frosted icon buttons directly rendered below timer in split view
          if (!isExpanded && onSettingsTap != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onSettingsTap,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.gear_alt,
                          size: 17,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                  if (onExpandTap != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onExpandTap,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16),
                            width: 0.8,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            CupertinoIcons.arrow_up_left_arrow_down_right,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColon(double fontSize) {
    final dotSize = (fontSize * 0.09).clamp(6.0, 22.0);
    final gap = (fontSize * 0.24).clamp(14.0, 52.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.04),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(height: gap),
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryStatus(BatteryInfo info, String fontFamily) {
    final isCharging = info.isCharging;
    final hasData = info.level >= 0;
    final isLow = hasData && info.level <= 20;
    final Color textColor = isCharging
        ? const Color(0xFF34C759)
        : (isLow ? const Color(0xFFFF453A) : DeskTheme.textSecondary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isCharging) ...[
          const Icon(
            CupertinoIcons.bolt_fill,
            size: 13,
            color: Color(0xFF34C759),
          ),
          const SizedBox(width: 3),
        ],
        Text(
          hasData ? '${info.level}%' : '--',
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
