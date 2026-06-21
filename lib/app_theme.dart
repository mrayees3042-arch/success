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
      gold: cGold,
      teal: cEmerald,
      blue: cAzure,
      red: cRose,
      green: cEmerald,
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