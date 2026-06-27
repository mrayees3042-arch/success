import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticService {
  static void light() {
    HapticFeedback.lightImpact();
  }

  static void medium() {
    HapticFeedback.mediumImpact();
  }

  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  static void selection() {
    HapticFeedback.selectionClick();
  }

  static Future<void> habitComplete(bool allCompleted) async {
    if (allCompleted) {
      HapticFeedback.heavyImpact();
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [100, 50, 100, 50, 100]);
      }
    } else {
      HapticFeedback.lightImpact();
    }
  }

  static Future<void> workoutRepZero() async {
    HapticFeedback.heavyImpact();
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [200, 100, 200]);
    }
  }

  static Future<void> restTimerEnd() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [100, 50, 100, 50, 100, 50, 200]);
    }
  }
}
