import 'package:flutter/material.dart';

const kBg = Color(0xFF1a1a2e);
const kCard = Color(0xFF22223b);
const kCard2 = Color(0xFF2a2a45);
const kBorder = Color(0x17FFFFFF);
const kBorderStrong = Color(0x26FFFFFF);

const kGold = Color(0xFFf4c96e);
const kTeal = Color(0xFF5ce0b8);
const kRed = Color(0xFFff8a80);
const kPurple = Color(0xFFc3a6ff);
const kBlue = Color(0xFF82b4ff);
const kGreen = Color(0xFF69f0ae);
const kAmber = Color(0xFFffcc80);
const kPink = Color(0xFFff8fb1);

const kT1 = Color(0xFFEEE8D5);
const kT2 = Color(0xB8EEE8D5);
const kT3 = Color(0x6BEEE8D5);
const kT4 = Color(0x38EEE8D5);

Color tint(Color color, [double opacity = 0.13]) {
  return color.withValues(alpha: opacity);
}
