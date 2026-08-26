import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'colors.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'SF Pro Text',
    scaffoldBackgroundColor: kBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kGold,
      brightness: Brightness.dark,
      surface: kCard,
    ),
    textTheme: TextTheme(
      headlineLarge: AppFonts.display(
        color: kT1,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: AppFonts.display(color: kT1, fontSize: 18, fontWeight: FontWeight.w800),
      titleMedium: AppFonts.text(color: kT1, fontSize: 15, fontWeight: FontWeight.w700),
      bodyMedium: AppFonts.text(color: kT2, fontSize: 13, fontWeight: FontWeight.w600, height: 1.45),
      labelSmall: AppFonts.compact(
        color: kT4,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    ),
  );
}
