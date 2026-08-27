import 'package:flutter/material.dart';

/// San Francisco (SF) Typography System for Muttaqin
///
/// Variants:
/// - SF Pro Display: Headlines & Large sizes (>= 20pt)
/// - SF Pro Text: Small sizes (< 20pt), body text, labels
/// - SF Pro: General System UI
/// - SF Mono: Code editors, terminal, tabular numbers
/// - SF Compact: WatchOS, tight spaces, badges & pills
/// - SF Arabic: Arabic Quranic & Dhikr text
class AppFonts {
  static const List<String> _displayFallbacks = [
    'SF Pro Display',
    'SF Pro',
    '-apple-system',
    'BlinkMacSystemFont',
    'Inter',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static const List<String> _textFallbacks = [
    'SF Pro Text',
    'SF Pro',
    '-apple-system',
    'BlinkMacSystemFont',
    'Inter',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static const List<String> _monoFallbacks = [
    'SF Mono',
    'Menlo',
    'Monaco',
    'Consolas',
    'Courier New',
    'monospace',
  ];

  static const List<String> _compactFallbacks = [
    'SF Compact',
    'SF Compact Text',
    'SF Compact Display',
    'SF Pro Text',
    'SF Pro',
    '-apple-system',
    'sans-serif',
  ];

  static const List<String> _arabicFallbacks = [
    'NotoNaskhArabic',
    'Amiri',
    'Traditional Arabic',
    'serif',
  ];

  /// Global font scaling factor (+12% sizing boost for optimal readability)
  static const double kGlobalFontScale = 1.12;

  /// SF Pro Display: For large sizes (>= 20pt), headlines, hero numbers
  static TextStyle display({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<FontFeature>? fontFeatures,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
  }) {
    return TextStyle(
      fontFamily: 'SF Pro Display',
      fontFamilyFallback: _displayFallbacks,
      fontSize: fontSize * kGlobalFontScale,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      fontFeatures: fontFeatures,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
    );
  }

  /// SF Pro Text: For small sizes (< 20pt), body text, subtitles, descriptions
  static TextStyle text({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<FontFeature>? fontFeatures,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
  }) {
    return TextStyle(
      fontFamily: 'SF Pro Text',
      fontFamilyFallback: _textFallbacks,
      fontSize: fontSize * kGlobalFontScale,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      fontFeatures: fontFeatures,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
    );
  }

  /// SF Pro: General System UI
  static TextStyle sfPro({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<FontFeature>? fontFeatures,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
  }) {
    return TextStyle(
      fontFamily: 'SF Pro',
      fontFamilyFallback: _textFallbacks,
      fontSize: fontSize * kGlobalFontScale,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      fontFeatures: fontFeatures,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
    );
  }

  /// SF Mono: For tabular numbers, currency counters, code, terminals
  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<FontFeature>? fontFeatures,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
  }) {
    return TextStyle(
      fontFamily: 'SF Mono',
      fontFamilyFallback: _monoFallbacks,
      fontSize: fontSize * kGlobalFontScale,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      fontFeatures: fontFeatures,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
    );
  }

  /// SF Compact: For tight spaces, badges, pills, compact metrics
  static TextStyle compact({
    double fontSize = 10.5,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? letterSpacing = 0.5,
    double? height,
    FontStyle? fontStyle,
    List<FontFeature>? fontFeatures,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
  }) {
    return TextStyle(
      fontFamily: 'SF Compact',
      fontFamilyFallback: _compactFallbacks,
      fontSize: fontSize * kGlobalFontScale,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      fontFeatures: fontFeatures,
      shadows: shadows,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
    );
  }

  /// Arabic typography with NotoNaskhArabic / Amiri fallbacks
  static TextStyle arabic({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height = 1.6,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: 'NotoNaskhArabic',
      fontFamilyFallback: _arabicFallbacks,
      fontSize: fontSize * kGlobalFontScale,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontStyle: fontStyle,
      shadows: shadows,
      decoration: decoration,
    );
  }

  /// Adaptive helper: auto-selects SF Pro Display if fontSize >= 20, else SF Pro Text
  static TextStyle auto({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
    List<FontFeature>? fontFeatures,
    List<Shadow>? shadows,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
  }) {
    if (fontSize >= 20) {
      return display(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
        fontFeatures: fontFeatures,
        shadows: shadows,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
      );
    } else {
      return text(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: fontStyle,
        fontFeatures: fontFeatures,
        shadows: shadows,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
      );
    }
  }
}
