import 'package:shared_preferences/shared_preferences.dart';

class AppOpenService {
  static const String _prefKey = 'app_open_dates_v1';

  static String dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Records an app-open event for the given date (defaults to DateTime.now()).
  /// Calling this multiple times on the same date will only store 1 unique date entry.
  static Future<void> recordAppOpen([DateTime? date]) async {
    final prefs = await SharedPreferences.getInstance();
    final key = dateKey(date ?? DateTime.now());
    final existingList = prefs.getStringList(_prefKey) ?? <String>[];
    final dateSet = existingList.toSet();
    if (!dateSet.contains(key)) {
      dateSet.add(key);
      await prefs.setStringList(_prefKey, dateSet.toList());
    }
  }

  /// Returns the set of all unique calendar dates (YYYY-MM-DD) on which the app was opened.
  static Future<Set<String>> getAppOpenDates() async {
    final prefs = await SharedPreferences.getInstance();
    final existingList = prefs.getStringList(_prefKey) ?? <String>[];
    return existingList.toSet();
  }

  /// Counts the number of unique calendar dates the app was opened within [startDate] and [endDate] (inclusive).
  static Future<int> countOpensInRange(
    DateTime startDate,
    DateTime endDate, {
    Set<String>? openDates,
  }) async {
    final dates = openDates ?? await getAppOpenDates();
    return calculateOpensInRange(startDate, endDate, dates);
  }

  /// Pure synchronous helper to calculate open days in range given a preloaded set of dates.
  static int calculateOpensInRange(
    DateTime startDate,
    DateTime endDate,
    Set<String> openDates,
  ) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    if (start.isAfter(end)) return 0;

    final totalDays = end.difference(start).inDays + 1;
    int count = 0;

    for (int i = 0; i < totalDays; i++) {
      final date = start.add(Duration(days: i));
      final key = dateKey(date);
      if (openDates.contains(key)) {
        count++;
      }
    }

    return count;
  }

  /// Clears recorded open dates (primarily used for unit testing).
  static Future<void> clearOpenDates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
