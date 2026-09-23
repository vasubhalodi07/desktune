import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DeskTheme {
  // True OLED Pitch Black for authentic Apple StandBy display
  static const Color background = Color(0xFF000000);

  // Liquid Frosted Glass Colors
  static const Color surfaceElevated = Color(
    0x24FFFFFF,
  ); // 14% white for elevated elements
  static const Color glassCard = Color(0x14FFFFFF); // 8% white

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xA6FFFFFF); // 65% white
  static const Color textMuted = Color(0x59FFFFFF); // 35% white

  static const Color accent = Color(0xFFFFFFFF);
  static const Color accentRed = Color(0xFFFF453A); // Apple system red
  static const Color warning = Color(0xFFFF9F0A); // Apple system orange
  static const Color sliderTrack = Color(0x33FFFFFF); // 20% white
  static const Color sliderActive = Color(0xFFFFFFFF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      fontFamily: 'Comfortaa',
      colorScheme: const ColorScheme.dark(
        surface: glassCard,
        primary: accent,
        secondary: textSecondary,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CupertinoColors.white,
        barBackgroundColor: Color(0xCC000000),
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(fontFamily: 'Comfortaa', color: Colors.white),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: sliderActive,
        inactiveTrackColor: sliderTrack,
        thumbColor: Colors.white,
        overlayColor: Color(0x22FFFFFF),
        trackHeight: 4.0,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5.0),
      ),
    );
  }
}
