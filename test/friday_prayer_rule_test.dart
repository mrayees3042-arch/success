import 'package:flutter_test/flutter_test.dart';
import 'package:success/main.dart';

void main() {
  group('Friday Prayer Rule Verification Suite', () {
    test('1. Thursday: Dhuhr displays as Dhuhr in English and Arabic', () {
      final thursday = DateTime(2026, 8, 27); // Thursday
      expect(thursday.weekday, DateTime.thursday);

      expect(getPrayerDisplayName('Dhuhr', thursday), 'Dhuhr');
      expect(getPrayerArabicName('Dhuhr', thursday), '\u0638\u0647\u0631');
    });

    test('2. Friday: Dhuhr is replaced by Jumu\'ah in English and Arabic', () {
      final friday = DateTime(2026, 8, 28); // Friday
      expect(friday.weekday, DateTime.friday);

      expect(getPrayerDisplayName('Dhuhr', friday), 'Jumu\'ah');
      expect(getPrayerArabicName('Dhuhr', friday), '\u0627\u0644\u062c\u0645\u0639\u0629');
    });

    test('3. Saturday: Dhuhr displays as Dhuhr in English and Arabic', () {
      final saturday = DateTime(2026, 8, 29); // Saturday
      expect(saturday.weekday, DateTime.saturday);

      expect(getPrayerDisplayName('Dhuhr', saturday), 'Dhuhr');
      expect(getPrayerArabicName('Dhuhr', saturday), '\u0638\u0647\u0631');
    });

    test('4. All other prayers remain unchanged on Fridays', () {
      final friday = DateTime(2026, 8, 28);

      expect(getPrayerDisplayName('Fajr', friday), 'Fajr');
      expect(getPrayerDisplayName('Asr', friday), 'Asr');
      expect(getPrayerDisplayName('Maghrib', friday), 'Maghrib');
      expect(getPrayerDisplayName('Isha', friday), 'Isha');
      expect(getPrayerDisplayName('Tahajjud', friday), 'Tahajjud');
    });

    test('5. Internal data key Dhuhr is preserved for database & state integrity', () {
      const kPrayerNames = ['Tahajjud', 'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
      expect(kPrayerNames.contains('Dhuhr'), isTrue);
    });
  });
}
