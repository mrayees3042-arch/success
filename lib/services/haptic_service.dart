import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

class HapticService {
  static const _prefsKey = 'haptics_enabled';
  static bool _enabled = true;

  /// Initialize haptic service — load user preference
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      _enabled = true;
    }
  }

  /// Check if haptics are enabled
  static bool get isEnabled => _enabled;

  /// Toggle haptics on/off and persist
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}
  }

  // ── BASIC FEEDBACK ──

  /// Very light tap — for nav taps, list item taps, settings toggles
  static void tapFeedback() {
    if (!_enabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Light impact — general button presses
  static void light() {
    if (!_enabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium impact — start workout, important actions
  static void medium() {
    if (!_enabled) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy impact — strong confirmation
  static void heavy() {
    if (!_enabled) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Selection click — minimal tick
  static void selection() {
    if (!_enabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  // ── WORKOUT-SPECIFIC ──

  /// Counter tap — medium feel for each rep tap, like a mechanical counter click
  static void counterTap() {
    if (!_enabled) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Negative feedback — soft, for skip actions
  static void negative() {
    if (!_enabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Habit complete — different pattern if all done
  static Future<void> habitComplete(bool allCompleted) async {
    if (!_enabled) return;
    try {
      if (allCompleted) {
        HapticFeedback.heavyImpact();
        if (await Vibration.hasVibrator()) {
          Vibration.vibrate(pattern: [100, 50, 100, 50, 100]);
        }
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  /// When rep counter hits zero — strong confirmation
  static Future<void> workoutRepZero() async {
    if (!_enabled) return;
    try {
      HapticFeedback.heavyImpact();
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [200, 100, 200]);
      }
    } catch (_) {}
  }

  /// Exercise complete — triple-tap pattern: short-short-long
  static Future<void> exerciseComplete() async {
    if (!_enabled) return;
    try {
      HapticFeedback.heavyImpact();
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 30, 50, 30, 50, 80]);
      }
    } catch (_) {}
  }

  /// Workout complete — stronger celebration pattern
  static Future<void> workoutComplete() async {
    if (!_enabled) return;
    try {
      HapticFeedback.heavyImpact();
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 50, 80, 50, 80, 120]);
      }
    } catch (_) {}
  }

  /// Rest timer end
  static Future<void> restTimerEnd() async {
    if (!_enabled) return;
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [100, 50, 100, 50, 100, 50, 200]);
      }
    } catch (_) {}
  }

  /// Premium weird pink haptic feedback (rapid double-pulse)
  static Future<void> pinkFeedback() async {
    if (!_enabled) return;
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 15, 25, 15, 25, 30]);
      } else {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }
}
