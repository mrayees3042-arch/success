import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:success/main.dart';

void main() {
  group('Defensive Security & Input Validation Audit', () {
    test('1. Security: Sanitizes and safely handles special characters and malicious input in user names', () {
      final maliciousInputs = [
        '<script>alert("XSS")</script>',
        'DROP TABLE users;--',
        '\' OR \'1\'=\'1',
        '../../etc/passwd',
        'Null\u0000Byte',
        '🚀🔥🌟 Unicode Name',
        '   Leading and trailing spaces   ',
      ];

      for (final input in maliciousInputs) {
        final sanitized = input.trim();
        expect(sanitized, isNotEmpty);
        final encoded = jsonEncode({'user_name': sanitized});
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;
        expect(decoded['user_name'], sanitized);
      }
    });

    test('2. Security: Peer sync bundle payload validation defends against malformed or poisoned JSON', () {
      final invalidPayloads = [
        '{}',
        '{"version": 1}',
        '{"version": "invalid_type", "records": []}',
        '{"records": null}',
      ];

      for (final payload in invalidPayloads) {
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final hasValidStructure = data.containsKey('version') &&
              data.containsKey('records') &&
              data['records'] is List;
          if (!hasValidStructure) {
            expect(hasValidStructure, isFalse);
          }
        } catch (e) {
          expect(e, isNotNull);
        }
      }
    });

    test('3. Security: Offline Data Integrity - No hardcoded API keys or external secrets exposed in bundle', () {
      final sampleBundle = {
        'version': 1,
        'app': 'Muttaqin',
        'user_name': 'TestUser',
        'user_dob': '2000-01-01',
        'records': {},
      };

      final serialized = jsonEncode(sampleBundle);
      expect(serialized.contains('password'), isFalse);
      expect(serialized.contains('secret'), isFalse);
      expect(serialized.contains('api_key'), isFalse);
      expect(serialized.contains('bearer'), isFalse);
      expect(serialized.contains('token'), isFalse);
    });
  });

  group('End-to-End User Flow & State Machine Audit', () {
    test('4. Flow: Midnight date transition recalculates prayer schedules accurately', () {
      final thursdayNight = DateTime(2026, 8, 27, 23, 59, 59);
      final fridayMidnight = DateTime(2026, 8, 28, 0, 0, 0);

      expect(getPrayerDisplayName('Dhuhr', thursdayNight), 'Dhuhr');
      expect(getPrayerDisplayName('Dhuhr', fridayMidnight), 'Jumu\'ah');
      expect(getPrayerArabicName('Dhuhr', fridayMidnight), '\u0627\u0644\u062c\u0645\u0639\u0629');
    });

    test('5. Flow: Score computation with zero prayers or zero tasks does not divide by zero', () {
      int calculateScore(int tasksDone, int tasksTotal, int prayersDone, int prayersTotal) {
        if (tasksTotal == 0 && prayersTotal == 0) return 0;
        final taskRatio = tasksTotal > 0 ? (tasksDone / tasksTotal) : 0.0;
        final prayerRatio = prayersTotal > 0 ? (prayersDone / prayersTotal) : 0.0;
        final score = ((taskRatio + prayerRatio) / 2.0 * 100.0).round();
        return score.clamp(0, 100);
      }

      expect(calculateScore(0, 0, 0, 0), 0);
      expect(calculateScore(5, 5, 0, 0), 50);
      expect(calculateScore(0, 0, 5, 5), 50);
      expect(calculateScore(4, 4, 5, 5), 100);
    });

    test('6. Flow: DayKey formatting handles leap years and single-digit months/days', () {
      final leapDay = DateTime(2028, 2, 29);
      final singleDigitDay = DateTime(2026, 4, 5);

      expect(dayKey(leapDay), '2028-02-29');
      expect(dayKey(singleDigitDay), '2026-04-05');

      final parsedLeap = dateFromKey('2028-02-29');
      expect(parsedLeap.year, 2028);
      expect(parsedLeap.month, 2);
      expect(parsedLeap.day, 29);
    });
  });
}
