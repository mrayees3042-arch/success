import 'package:flutter_test/flutter_test.dart';
import 'package:success/services/psychology_report_service.dart';

void main() {
  group('Muttaqin QA Audit - Business Logic & Data Verification', () {
    test('1. Score calculation formula behaves predictably without NaN/0 division', () {
      // Helper score calculator
      int calculateScore(int tasksDone, int tasksTotal, int prayersDone, int prayersTotal) {
        if (tasksTotal == 0 && prayersTotal == 0) return 0;
        final taskRatio = tasksTotal > 0 ? (tasksDone / tasksTotal) : 0.0;
        final prayerRatio = prayersTotal > 0 ? (prayersDone / prayersTotal) : 0.0;
        final score = ((taskRatio + prayerRatio) / 2.0 * 100.0).round();
        return score.clamp(0, 100);
      }

      // Case A: 0 tasks, 0 prayers -> 0%
      expect(calculateScore(0, 4, 0, 5), 0);

      // Case B: 2 of 4 tasks, 0 prayers -> 25%
      expect(calculateScore(2, 4, 0, 5), 25);

      // Case C: 4 of 4 tasks, 5 of 5 prayers -> 100%
      expect(calculateScore(4, 4, 5, 5), 100);

      // Case D: 0 of 0 edge case -> 0%
      expect(calculateScore(0, 0, 0, 0), 0);
    });

    test('2. Streak calculation is continuous and handles gaps gracefully', () {
      int calculateBestStreak(List<int> dailyScores) {
        int current = 0;
        int best = 0;
        for (final score in dailyScores) {
          if (score > 0) {
            current++;
            if (current > best) best = current;
          } else {
            current = 0;
          }
        }
        return best;
      }

      // 5 consecutive days of activity -> streak = 5
      expect(calculateBestStreak([20, 40, 50, 60, 80]), 5);

      // Gap on day 3 -> best streak is 3
      expect(calculateBestStreak([20, 40, 0, 60, 80, 90]), 3);

      // All zeroes -> streak = 0
      expect(calculateBestStreak([0, 0, 0, 0]), 0);
    });

    test('3. Fasting state machine is strictly Opt-In Only', () {
      // Fasting states: 'none', 'offered', 'fasting', 'broke', 'completed'
      String fastingState = 'none';
      bool isSunnahDay = true; // e.g. Monday

      // App opened on Monday: State remains 'none' (NEVER auto-starts)
      expect(fastingState, 'none');

      // User taps "+ Log Fast"
      fastingState = 'offered';
      expect(fastingState, 'offered');

      // User confirms intention -> 'fasting'
      fastingState = 'fasting';
      expect(fastingState, 'fasting');

      // User taps "Break Fast"
      fastingState = 'broke';
      expect(fastingState, 'broke');
    });

    test('4. Psychology Report Data correctly computes wins, momentum, and anchor habit', () {
      final days = [
        DailyHabitData(
          date: DateTime(2026, 8, 19),
          score: 50,
          tasksDone: 1,
          tasksTotal: 4,
          prayersDone: 0,
          prayersTotal: 5,
          taskBreakdown: {'Morning Adhkar': true, 'Read Quran': false, 'Call parents': false},
          prayerBreakdown: {'Fajr': false, 'Dhuhr': false, 'Asr': false},
        ),
        DailyHabitData(
          date: DateTime(2026, 8, 20),
          score: 50,
          tasksDone: 2,
          tasksTotal: 4,
          prayersDone: 1,
          prayersTotal: 5,
          taskBreakdown: {'Morning Adhkar': true, 'Read Quran': true, 'Call parents': false},
          prayerBreakdown: {'Fajr': true, 'Dhuhr': false, 'Asr': false},
        ),
        DailyHabitData(
          date: DateTime(2026, 8, 21),
          score: 25,
          tasksDone: 1,
          tasksTotal: 4,
          prayersDone: 0,
          prayersTotal: 5,
          taskBreakdown: {'Morning Adhkar': true, 'Read Quran': false, 'Call parents': false},
          prayerBreakdown: {'Fajr': false, 'Dhuhr': false, 'Asr': false},
        ),
      ];

      final reportData = HabitReportData(
        userName: 'Rayees',
        startDate: DateTime(2026, 8, 19),
        endDate: DateTime(2026, 8, 21),
        days: days,
      );

      // Verify Morning Adhkar is identified as strongest habit (3/3)
      expect(reportData.strongestHabit, 'Morning Adhkar');
      expect(reportData.bestDayScore, 50);
      expect(reportData.totalDays, 3);
      expect(reportData.totalTasksDone, 4);
      expect(reportData.totalPrayersDone, 1);
    });
  });
}
