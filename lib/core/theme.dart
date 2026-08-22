import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: kBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kGold,
      brightness: Brightness.dark,
      surface: kCard,
    ),
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.syne(
        color: kT1,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: GoogleFonts.syne(color: kT1, fontSize: 18, fontWeight: FontWeight.w800),
      titleMedium: GoogleFonts.syne(color: kT1, fontSize: 15, fontWeight: FontWeight.w700),
      bodyMedium: GoogleFonts.dmSans(color: kT2, fontSize: 13, fontWeight: FontWeight.w600, height: 1.45),
      labelSmall: GoogleFonts.dmSans(
        color: kT4,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    ),
  );
}
