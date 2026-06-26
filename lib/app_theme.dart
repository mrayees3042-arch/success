import 'package:flutter/material.dart';

const Color kGold = Color(0xFFE8B84B);
const Color kTeal = Color(0xFF00C896);
const Color kGreen = Color(0xFF00C896);
const Color kBlue = Color(0xFF38BDF8);
const Color kAzure = Color(0xFF38BDF8);
const Color kRed = Color(0xFFF87171);
const Color kAmber = Color(0xFFFFD580);
const Color kPurple = Color(0xFFA78BFA);
const Color pGold = Color(0xFFE8B84B);
const Color pEmerald = Color(0xFF00C896);
const Color pAzure = Color(0xFF38BDF8);
const Color pBg = Color(0xFF06060F);

const cBg = Color(0xFF06060F);
const cGold = Color(0xFFE8B84B);
const cGold2 = Color(0xFFFFD580);
const cGold3 = Color(0xFFB8861E);
const cEmerald = Color(0xFF00C896);
const cAzure = Color(0xFF38BDF8);
const cRose = Color(0xFFF87171);
const cCard = Color(0x09FFFFFF);
const cCardBorder = Color(0x12FFFFFF);
const cText = Color(0xFFF2F2FF);
const cSub = Color(0xFF7070A0);
const cSub2 = Color(0xFF9090BB);

const kMuted = cSub;

class ThemeColors {
  const ThemeColors({
    required this.bg,
    required this.card,
    required this.border,
    required this.divider,
    required this.navBg,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.text4,
    required this.gold,
    required this.teal,
    required this.blue,
    required this.red,
    required this.green,
    required this.isDark,
  });

  final Color bg;
  final Color card;
  final Color border;
  final Color divider;
  final Color navBg;
  final Color text1;
  final Color text2;
  final Color text3;
  final Color text4;
  final Color gold;
  final Color teal;
  final Color blue;
  final Color red;
  final Color green;
  final bool isDark;
}

ThemeColors getTheme() {
  final hour = DateTime.now().hour;
  final isDay = hour >= 6 && hour < 20;

  if (isDay) {
    return const ThemeColors(
      isDark: false,
      bg: Color(0xFFF5F0E8),
      card: Color(0xFFFFFFFF),
      border: Color(0xFFDDD8CC),
      divider: Color(0xFFDDD8CC),
      navBg: Color(0xFFF9F7F2),
      text1: Color(0xFF1A1A2E),
      text2: Color(0xFF2A2A3E),
      text3: Color(0xFF8A8580),
      text4: Color(0xFF9A9585),
      gold: Color(0xFFB8860B),
      teal: Color(0xFF0A7A5A),
      blue: Color(0xFF1A6FA0),
      red: Color(0xFFC0392B),
      green: Color(0xFF0A7A5A),
    );
  }

  return const ThemeColors(
    isDark: true,
    bg: cBg,
    card: cCard,
    border: cCardBorder,
    divider: cCardBorder,
    navBg: cBg,
    text1: cText,
    text2: cText,
    text3: cSub,
    text4: cSub2,
    gold: cGold,
    teal: cEmerald,
    blue: cAzure,
    red: cRose,
    green: cEmerald,
  );
}

class AppColors {
  final ThemeColors theme;

  AppColors(this.theme);

  Color get bg => theme.isDark ? const Color(0xFF06060F) : const Color(0xFFF5F0E8);
  Color get card => theme.isDark ? const Color(0x0AFFFFFF) : const Color(0xFFFFFFFF);
  Color get cardBorder => theme.isDark ? const Color(0x14FFFFFF) : const Color(0x0F000000);
  Color get gold => theme.isDark ? const Color(0xFFE8B84B) : const Color(0xFFB8860B);
  Color get gold2 => theme.isDark ? const Color(0xFFF5D78E) : const Color(0xFFD4A843);
  Color get gold3 => theme.isDark ? const Color(0x1AE8B84B) : const Color(0x1FB8860B);
  Color get emerald => theme.isDark ? const Color(0xFF00C896) : const Color(0xFF0A7A5A);
  Color get emerald2 => theme.isDark ? const Color(0x1400C896) : const Color(0x140A7A5A);
  Color get red => theme.isDark ? const Color(0xFFFF6B6B) : const Color(0xFFC0392B);
  Color get red2 => theme.isDark ? const Color(0x14FF6B6B) : const Color(0x14C0392B);
  Color get text1 => theme.isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A2E);
  Color get text2 => theme.isDark ? const Color(0x8CFFFFFF) : const Color(0x80000000);
  Color get text3 => theme.isDark ? const Color(0x4DFFFFFF) : const Color(0x4D000000);
  Color get text4 => theme.isDark ? const Color(0x19FFFFFF) : const Color(0x1F000000);
  Color get track => theme.isDark ? const Color(0x14FFFFFF) : const Color(0x0F000000);

  List<BoxShadow>? get shadow {
    if (theme.isDark) return null;
    return [
      const BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 12,
        offset: Offset(0, 2),
      ),
    ];
  }
}