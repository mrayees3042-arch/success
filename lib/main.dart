import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math' show max; // Fix 1: Add dart:math show max, min
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:success/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:success/providers/theme_provider.dart';
import 'package:success/screens/life_plan_screen.dart';
import 'package:success/screens/boot_screen.dart';
import 'package:success/screens/onboarding_screen.dart';
import 'package:success/services/haptic_service.dart';
import 'package:success/services/audio_service.dart';
import 'package:success/services/sound_manager.dart';
import 'package:success/widgets/stick_figure_painter.dart';
import 'package:success/core/islamic_data.dart';
import 'package:printing/printing.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:success/services/psychology_report_service.dart';
import 'package:success/services/app_open_service.dart';
import 'package:success/core/app_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AudioService.init();
  SoundManager.init();
  HapticService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const SuccessApp(),
    ),
  );
}

class TodayTask {
  const TodayTask(this.icon, this.title, this.tag);

  factory TodayTask.fromJson(Map<String, dynamic> json) {
    return TodayTask(
      IconData(
        (json['iconCodePoint'] as num?)?.toInt() ??
            Icons.check_circle.codePoint,
        fontFamily:
            json['iconFontFamily'] as String? ??
            'MaterialIcons', // Default to MaterialIcons
        fontPackage: json['iconFontPackage'] as String?,
      ),
      (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Daily Task',
      (json['tag'] as String?)?.trim().isNotEmpty == true
          ? (json['tag'] as String).trim()
          : 'Tap to edit subtitle',
    );
  }

  final IconData icon;
  final String title;
  final String tag;

  TodayTask copyWith({String? title, String? tag, IconData? icon}) {
    return TodayTask(icon ?? this.icon, title ?? this.title, tag ?? this.tag);
  }

  Map<String, dynamic> toJson() => {
    'iconCodePoint': icon.codePoint,
    'iconFontFamily': icon.fontFamily,
    'iconFontPackage': icon.fontPackage,
    'title': title,
    'tag': tag,
  };
}

final kDefaultTodayTasks = <TodayTask>[
  TodayTask(Icons.menu_book, 'Morning Adhkar', 'Daily'),
  TodayTask(Icons.auto_stories, 'Read 1 page of Quran', 'Daily'),
  TodayTask(Icons.phone_in_talk, 'Call parents', 'Personal'),
  TodayTask(Icons.nights_stay, 'Evening Reflection', 'Daily'),
];

List<TodayTask> kTodayTasks = List<TodayTask>.from(kDefaultTodayTasks);

const kPrayerNames = ['Tahajjud', 'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

String dayKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

DateTime dateFromKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class WorkoutSummary {
  WorkoutSummary({
    required this.workoutName,
    required this.exercisesCompleted,
    required this.totalExercises,
    required this.setsCompleted,
    required this.totalSets,
    required this.setsPerExercise,
  });

  factory WorkoutSummary.fromJson(Map<String, dynamic> json) {
    final rawSets = json['setsPerExercise'] as Map<String, dynamic>? ?? {};
    return WorkoutSummary(
      workoutName: json['workoutName'] as String,
      exercisesCompleted: (json['exercisesCompleted'] as num).toInt(),
      totalExercises: (json['totalExercises'] as num).toInt(),
      setsCompleted: (json['setsCompleted'] as num).toInt(),
      totalSets: (json['totalSets'] as num).toInt(),
      setsPerExercise: rawSets.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
    );
  }

  final String workoutName;
  final int exercisesCompleted;
  final int totalExercises;
  final int setsCompleted;
  final int totalSets;
  final Map<String, int> setsPerExercise;

  Map<String, dynamic> toJson() => {
    'workoutName': workoutName,
    'exercisesCompleted': exercisesCompleted,
    'totalExercises': totalExercises,
    'setsCompleted': setsCompleted,
    'totalSets': totalSets,
    'setsPerExercise': setsPerExercise,
  };
}

class WorkoutProgressSnapshot {
  const WorkoutProgressSnapshot({
    required this.workoutName,
    required this.exercisesCompleted,
    required this.totalExercises,
    this.setsCompleted = 0,
    this.totalSets = 0,
    required this.completed,
    required this.inProgress,
    required this.dateKey,
  });

  factory WorkoutProgressSnapshot.fromJson(Map<String, dynamic> json) {
    return WorkoutProgressSnapshot(
      workoutName: json['workoutName'] as String? ?? 'Workout',
      exercisesCompleted: (json['exercisesCompleted'] as num?)?.toInt() ?? 0,
      totalExercises: (json['totalExercises'] as num?)?.toInt() ?? 0,
      setsCompleted: (json['setsCompleted'] as num?)?.toInt() ?? 0,
      totalSets: (json['totalSets'] as num?)?.toInt() ?? 0,
      completed: json['completed'] == true,
      inProgress: json['inProgress'] == true,
      dateKey: json['dateKey'] as String? ?? '',
    );
  }

  final String workoutName;
  final int exercisesCompleted;
  final int totalExercises;
  final int setsCompleted;
  final int totalSets;
  final bool completed;
  final bool inProgress;
  final String dateKey;

  String get todaySubtitle {
    if (completed) {
      return '$workoutName - $exercisesCompleted/$totalExercises exercises done';
    }
    if (inProgress) {
      return '$workoutName - In progress - $exercisesCompleted/$totalExercises exercises';
    }
    return 'Push / Legs / Back / HIIT';
  }

  Map<String, dynamic> toJson() => {
    'workoutName': workoutName,
    'exercisesCompleted': exercisesCompleted,
    'totalExercises': totalExercises,
    'setsCompleted': setsCompleted,
    'totalSets': totalSets,
    'completed': completed,
    'inProgress': inProgress,
    'dateKey': dateKey,
  };
}

class DayRecord {
  DayRecord({required List<bool> tasks, required this.prayers, this.workoutSummary})
      : tasks = List<bool>.from(tasks, growable: true);

  factory DayRecord.empty() {
    return DayRecord(
      tasks: List<bool>.filled(
        kTodayTasks.length,
        false,
        growable: true,
      ),
      prayers: {for (final name in kPrayerNames) name: false},
      workoutSummary: null,
    );
  }

  factory DayRecord.fromJson(Map<String, dynamic> json) {
    final rawTasks = (json['tasks'] as List?) ?? const [];
    final rawPrayers = (json['prayers'] as Map?) ?? const {};
    final rawWorkout = json['workoutSummary'] as Map<String, dynamic>?;
    return DayRecord(
      tasks: List<bool>.generate(
        kTodayTasks.length,
        (index) => index < rawTasks.length && rawTasks[index] == true,
        growable: true,
      ),
      prayers: {
        for (final name in kPrayerNames) name: rawPrayers[name] == true,
      },
      workoutSummary: rawWorkout != null
          ? WorkoutSummary.fromJson(rawWorkout)
          : null,
    );
  }

  final List<bool> tasks;
  final Map<String, bool> prayers;
  WorkoutSummary? workoutSummary;

  void syncTaskCount() {
    if (tasks.length < kTodayTasks.length) {
      final needed = kTodayTasks.length - tasks.length;
      tasks.addAll(List<bool>.filled(needed, false, growable: true));
    } else if (tasks.length > kTodayTasks.length) {
      tasks.removeRange(kTodayTasks.length, tasks.length);
    }
  }

  int get taskDone => tasks.where((done) => done).length;
  int get prayerDone => prayers.values.where((done) => done).length;
  int get doneTotal => taskDone + prayerDone;
  int get total => tasks.length + prayers.length;
  int get percent => total == 0 ? 0 : (doneTotal / total * 100).round();

  Map<String, dynamic> toJson() {
    final data = {'tasks': tasks, 'prayers': prayers};
    if (workoutSummary != null) {
      data['workoutSummary'] = workoutSummary!.toJson();
    }
    return data;
  }
}

class SuccessApp extends StatelessWidget {
  const SuccessApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'MUTTAQIN',
          debugShowCheckedModeBanner: false,
          themeMode: themeNotifier.mode,
          theme: lightTheme,
          darkTheme: darkTheme,
          home: const BootScreen(),
        );
      },
    );
  }
}

final lightTheme = _appTheme(Brightness.light);
final darkTheme = _appTheme(Brightness.dark);

ThemeData _appTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final textColor = isDark ? const Color(0xFFF2F2FF) : const Color(0xFF1A1A2E);
  final textMuted = isDark ? const Color(0xFF9090BB) : const Color(0xFF8A8580);

  final baseTextTheme = TextTheme(
    displayLarge: AppFonts.display(fontSize: 32, fontWeight: FontWeight.w800, color: textColor),
    displayMedium: AppFonts.display(fontSize: 28, fontWeight: FontWeight.w700, color: textColor),
    displaySmall: AppFonts.display(fontSize: 24, fontWeight: FontWeight.w700, color: textColor),
    headlineLarge: AppFonts.display(fontSize: 22, fontWeight: FontWeight.w700, color: textColor),
    headlineMedium: AppFonts.display(fontSize: 20, fontWeight: FontWeight.w600, color: textColor),
    headlineSmall: AppFonts.text(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
    titleLarge: AppFonts.text(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
    titleMedium: AppFonts.text(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
    titleSmall: AppFonts.text(fontSize: 13, fontWeight: FontWeight.w500, color: textMuted),
    bodyLarge: AppFonts.text(fontSize: 15, fontWeight: FontWeight.w400, color: textColor),
    bodyMedium: AppFonts.text(fontSize: 13, fontWeight: FontWeight.w400, color: textColor),
    bodySmall: AppFonts.text(fontSize: 11, fontWeight: FontWeight.w400, color: textMuted),
    labelLarge: AppFonts.compact(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
    labelMedium: AppFonts.compact(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted),
    labelSmall: AppFonts.compact(fontSize: 10, fontWeight: FontWeight.w600, color: textMuted),
  );

  return ThemeData(
    brightness: brightness,
    fontFamily: 'SF Pro Text',
    fontFamilyFallback: const [
      'SF Pro Text',
      'SF Pro Display',
      'SF Pro',
      '-apple-system',
      'BlinkMacSystemFont',
      'Inter',
      'Roboto',
      'sans-serif',
    ],
    textTheme: _withArabicFallback(baseTextTheme),
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF1C1C2E)
        : const Color(0xFFF5F0E8),
    cardColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFFFFFFF),
    primaryColor: const Color(0xFF1D9E75),
    colorScheme: isDark
        ? const ColorScheme.dark(
            primary: Color(0xFF1D9E75),
            secondary: Color(0xFFD4AF37),
          )
        : const ColorScheme.light(
            primary: Color(0xFF1D9E75),
            secondary: Color(0xFFD4AF37),
          ),
  );
}

TextTheme _withArabicFallback(TextTheme textTheme) {
  TextStyle? withFallback(TextStyle? style) {
    return style?.copyWith(
      fontFamilyFallback: const ['Roboto', 'NotoNaskhArabic'],
    );
  }

  return textTheme.copyWith(
    displayLarge: withFallback(textTheme.displayLarge),
    displayMedium: withFallback(textTheme.displayMedium),
    displaySmall: withFallback(textTheme.displaySmall),
    headlineLarge: withFallback(textTheme.headlineLarge),
    headlineMedium: withFallback(textTheme.headlineMedium),
    headlineSmall: withFallback(textTheme.headlineSmall),
    titleLarge: withFallback(textTheme.titleLarge),
    titleMedium: withFallback(textTheme.titleMedium),
    titleSmall: withFallback(textTheme.titleSmall),
    bodyLarge: withFallback(textTheme.bodyLarge),
    bodyMedium: withFallback(textTheme.bodyMedium),
    bodySmall: withFallback(textTheme.bodySmall),
    labelLarge: withFallback(textTheme.labelLarge),
    labelMedium: withFallback(textTheme.labelMedium),
    labelSmall: withFallback(textTheme.labelSmall),
  );
}

class MainScreen extends StatefulWidget {
  // Fix 1: Mixins
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  static final ValueNotifier<bool> hideBottomNavNotifier = ValueNotifier(false);
  static const _channel = MethodChannel('rayees.history/storage');
  static const _prefsTaskDefinitionsKey = 'today_tasks_v1';
  static const _prefsWorkoutProgressKey = 'workout_today_progress_v1';

  late AnimationController _orbController;
  int _tab = 0;
  bool _loaded = false;
  String? _lastPdfPath;
  bool? _darkOverride; // null = auto, true = force dark, false = force light
  ThemeColors _theme = getTheme();
  late Timer _themeTimer;
  final Map<String, DayRecord> _history = {};
  final Map<String, int> _incomeLog = {};
  final Map<String, int> _expenseLog = {};
  WorkoutProgressSnapshot? _workoutProgress;
  int _waterGlasses = 1;

  String _userName = '';
  int _userGoalYear = 2027;
  int _userGoalMonth = 1;
  int _userGoalDay = 1;

  String _userDob = '2000-01-01';

  DayRecord get _today => _recordFor(DateTime.now());

  DateTime _lastDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    AppOpenService.recordAppOpen();
    _loadUserProfile();
    _loadAppData();
    _loadIncome();
    _loadExpenses();
    _loadWater();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _themeTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (mounted) {
        final now = DateTime.now();
        if (now.day != _lastDate.day) {
          _lastDate = now;
          await updatePrayerTimesForLocation();
          setState(() {});
        }
        if (_darkOverride == null) {
          final nextTheme = getTheme();
          if (nextTheme.isDark != _theme.isDark) {
            setState(() => _theme = nextTheme);
          }
        }
      }
    });
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    final year = prefs.getInt('user_goal_year');
    final month = prefs.getInt('user_goal_month');
    final day = prefs.getInt('user_goal_day');
    final dob = prefs.getString('user_dob');
    if (mounted) {
      setState(() {
        if (name != null) _userName = name;
        if (year != null) _userGoalYear = year;
        if (month != null) _userGoalMonth = month;
        if (day != null) _userGoalDay = day;
        if (dob != null) _userDob = dob;
      });
    }
  }

  Future<void> _updateProfile(
    String name,
    int year,
    int month,
    int day,
    String dob,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setInt('user_goal_year', year);
    await prefs.setInt('user_goal_month', month);
    await prefs.setInt('user_goal_day', day);
    await prefs.setString('user_dob', dob);
    if (mounted) {
      setState(() {
        _userName = name;
        _userGoalYear = year;
        _userGoalMonth = month;
        _userGoalDay = day;
        _userDob = dob;
      });
    }
  }

  Future<void> _updateProfileFromNameChanged(
    String name,
    int year,
    int month,
    int day,
  ) async {
    await _updateProfile(name, year, month, day, _userDob);
  }

  @override
  void dispose() {
    _themeTimer.cancel();
    _orbController.dispose();
    super.dispose();
  }

  Future<void> _loadAppData() async {
    await _loadTaskDefinitions();
    if (!mounted) return;
    await _loadHistory();
    await _loadWorkoutProgress();
    await updatePrayerTimesForLocation();
    detectLocationByIp();
  }

  Future<void> _loadTaskDefinitions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsTaskDefinitionsKey);
    if (raw == null || raw.isEmpty) {
      kTodayTasks = List<TodayTask>.from(kDefaultTodayTasks);
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final loadedTasks = decoded
          .whereType<Map<String, dynamic>>()
          .map(TodayTask.fromJson)
          .toList();
      kTodayTasks = loadedTasks.isEmpty
          ? List<TodayTask>.from(kDefaultTodayTasks)
          : loadedTasks;
    } catch (_) {
      kTodayTasks = List<TodayTask>.from(kDefaultTodayTasks);
    }
  }

  Future<void> _saveTaskDefinitions() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    await prefs.setString(
      _prefsTaskDefinitionsKey,
      jsonEncode(kTodayTasks.map((task) => task.toJson()).toList()),
    );
  }

  Future<void> _loadWorkoutProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsWorkoutProgressKey);
    WorkoutProgressSnapshot? progress;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final loaded = WorkoutProgressSnapshot.fromJson(decoded);
        if (loaded.dateKey == dayKey(DateTime.now())) {
          progress = loaded;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _workoutProgress = progress;
      final workoutIndex = _workoutTaskIndex;
      if (workoutIndex != -1 && _today.tasks.length > workoutIndex) {
        _today.tasks[workoutIndex] = progress?.completed == true;
      }
    });
  }

  int get _workoutTaskIndex {
    return kTodayTasks.indexWhere(
      (task) =>
          task.title.trim().toLowerCase() == 'workout' ||
          task.icon.codePoint == Icons.fitness_center.codePoint,
    );
  }

  Future<void> _loadHistory() async {
    try {
      final raw = await _channel.invokeMethod<String>(
        'getString',
        'history_v2',
      );
      if (!mounted) return;
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final todayK = dayKey(DateTime.now());
        for (final entry in decoded.entries) {
          final rec = DayRecord.fromJson(
            entry.value as Map<String, dynamic>,
          );
          // Sanitize contaminated ghost records from previous fallback where first 2 tasks were defaulted true
          if (entry.key != todayK) {
            final taskTrueCount = rec.tasks.where((t) => t).length;
            final prayerTrueCount = rec.prayers.values.where((p) => p).length;
            if (taskTrueCount == 2 &&
                rec.tasks.length >= 2 &&
                rec.tasks[0] &&
                rec.tasks[1] &&
                prayerTrueCount == 0 &&
                rec.workoutSummary == null) {
              rec.tasks[0] = false;
              rec.tasks[1] = false;
            }
          }
          _history[entry.key] = rec;
        }
      }
    } catch (_) {}
    _history.putIfAbsent(dayKey(DateTime.now()), DayRecord.empty);
    for (final record in _history.values) {
      record.syncTaskCount();
    }
    _saveHistory();
    if (mounted) {
      setState(() => _loaded = true);
    }
  }

  DayRecord _recordFor(DateTime date) {
    final record = _history.putIfAbsent(dayKey(date), DayRecord.empty);
    record.syncTaskCount();
    return record;
  }

  Future<void> _saveHistory() async {
    _trimHistory();
    final payload = _history.map((key, value) => MapEntry(key, value.toJson()));
    try {
      await _channel.invokeMethod('setString', {
        'key': 'history_v2',
        'value': jsonEncode(payload),
      });
    } catch (_) {}
  }

  void _trimHistory() {
    final keep = {
      for (var i = 0; i < 30; i++)
        dayKey(DateTime.now().subtract(Duration(days: i))),
    };
    _history.removeWhere((key, value) => !keep.contains(key));
  }

  Future<void> _loadIncome() async {
    try {
      final raw = await _channel.invokeMethod<String>(
        'getString',
        'income_log_v1',
      );
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((k, v) => _incomeLog[k] = (v as num).toInt());
      }
    } catch (_) {}
  }

  Future<void> _saveIncome() async {
    try {
      await _channel.invokeMethod('setString', {
        'key': 'income_log_v1',
        'value': jsonEncode(_incomeLog),
      });
    } catch (_) {}
  }

  Future<void> _loadExpenses() async {
    try {
      final raw = await _channel.invokeMethod<String>(
        'getString',
        'expense_log_v1',
      );
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((k, v) => _expenseLog[k] = (v as num).toInt());
      }
    } catch (_) {}
  }

  Future<void> _saveExpenses() async {
    try {
      await _channel.invokeMethod('setString', {
        'key': 'expense_log_v1',
        'value': jsonEncode(_expenseLog),
      });
    } catch (_) {}
  }

  void _addIncomeEntry(int amount) {
    HapticService.light();
    AudioService.playIncomeLogged();
    if (!mounted) return;
    setState(() {
      final key = dayKey(DateTime.now());
      _incomeLog[key] = (_incomeLog[key] ?? 0) + amount;
    });
    _saveIncome();
  }

  void _addExpenseEntry(int amount) {
    HapticService.light();
    AudioService.playIncomeLogged();
    if (!mounted) return;
    setState(() {
      final key = dayKey(DateTime.now());
      _expenseLog[key] = (_expenseLog[key] ?? 0) + amount;
    });
    _saveExpenses();
  }

  void _setIncomeForDate(DateTime date, int amount) {
    HapticService.light();
    AudioService.playIncomeLogged();
    if (!mounted) return;
    setState(() => _incomeLog[dayKey(date)] = amount);
    _saveIncome();
  }

  void _setExpenseForDate(DateTime date, int amount) {
    HapticService.light();
    AudioService.playIncomeLogged();
    if (!mounted) return;
    setState(() => _expenseLog[dayKey(date)] = amount);
    _saveExpenses();
  }

  Future<void> _resetDayData(DateTime date) async {
    final key = dayKey(date);
    setState(() {
      _history[key] = DayRecord.empty();
      _incomeLog[key] = 0;
      _expenseLog[key] = 0;
    });
    await _saveHistory();
    await _saveIncome();
    await _saveExpenses();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fast_status_$key');
    await prefs.remove('water_$key');
    for (var name in [
      "Quran 1 page",
      "Evening adhkar",
      "No phone 1hr after Fajr",
      "Sleep before midnight",
    ]) {
      await prefs.remove('islamic_habit_${name}_$key');
    }
  }

  Future<void> _loadWater() async {
    try {
      final key = 'water_${dayKey(DateTime.now())}';
      final raw = await _channel.invokeMethod<String>('getString', key);
      if (!mounted) return;
      final value = (raw != null && raw.isNotEmpty) ? (int.tryParse(raw) ?? 1) : 1;
      if (mounted) {
        setState(() => _waterGlasses = value.clamp(0, 10));
      } else {
        _waterGlasses = value.clamp(0, 10);
      }
    } catch (_) {}
  }

  Future<void> _saveWater() async {
    try {
      await _channel.invokeMethod('setString', {
        'key': 'water_${dayKey(DateTime.now())}',
        'value': '$_waterGlasses',
      });
    } catch (_) {}
  }

  void _setWaterGlasses(int count) {
    if (!mounted) return;
    setState(() => _waterGlasses = count.clamp(0, 10));
    _saveWater();
  }

  void _toggleTask(int index) {
    if (!mounted) return;
    _today.syncTaskCount();
    if (index < 0 || index >= _today.tasks.length) return;
    final isChecked = !_today.tasks[index];
    setState(() {
      _today.syncTaskCount();
      _today.tasks[index] = isChecked;
    });
    _saveHistory();

    if (isChecked) {
      final allCompleted = _today.tasks.every((t) => t == true);
      HapticService.habitComplete(allCompleted);
      if (allCompleted) {
        AudioService.playAllHabitsDone();
      } else {
        AudioService.playHabitComplete();
      }
    } else {
      HapticService.light();
    }
  }

  void _editTask(int index, TodayTask task) {
    if (index < 0 || index >= kTodayTasks.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          kTodayTasks[index] = task;
        });
        _saveTaskDefinitions();
      }
    });
  }

  void _addDailyTask(TodayTask task) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          kTodayTasks.add(task);
          for (final record in _history.values) {
            record.tasks.add(false);
          }
        });
        _saveTaskDefinitions();
        _saveHistory();
      }
    });
  }

  void _deleteTask(int index) {
    if (index < 0 || index >= kTodayTasks.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          kTodayTasks.removeAt(index);
          for (final record in _history.values) {
            if (record.tasks.length > index) {
              record.tasks.removeAt(index);
            }
          }
        });
        _saveTaskDefinitions();
        _saveHistory();
      }
    });
  }

  void _reorderTask(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= kTodayTasks.length) return;
    if (newIndex < 0 || newIndex > kTodayTasks.length) return;
    if (!mounted) return;
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final task = kTodayTasks.removeAt(oldIndex);
      kTodayTasks.insert(newIndex, task);
      for (final record in _history.values) {
        if (record.tasks.length <= oldIndex ||
            record.tasks.length <= newIndex) {
          continue;
        }
        final done = record.tasks.removeAt(oldIndex);
        record.tasks.insert(newIndex, done);
      }
    });
    _saveTaskDefinitions();
    _saveHistory();
  }

  void _markWorkoutCompleted(WorkoutSummary summary) {
    final workoutTaskIndex = _workoutTaskIndex;
    if (!mounted) return;
    setState(() {
      final todayRecord = _recordFor(DateTime.now());
      if (workoutTaskIndex != -1 &&
          todayRecord.tasks.length > workoutTaskIndex) {
        todayRecord.tasks[workoutTaskIndex] = true;
      }
      todayRecord.workoutSummary = summary;
      _workoutProgress = WorkoutProgressSnapshot(
        workoutName: summary.workoutName,
        exercisesCompleted: summary.exercisesCompleted,
        totalExercises: summary.totalExercises,
        setsCompleted: summary.setsCompleted,
        totalSets: summary.totalSets,
        completed: true,
        inProgress: false,
        dateKey: dayKey(DateTime.now()),
      );
    });
    _saveHistory();
  }

  void _updateWorkoutProgress(WorkoutProgressSnapshot progress) {
    if (!mounted) return;
    setState(() {
      final isToday = progress.dateKey == dayKey(DateTime.now());
      _workoutProgress = isToday ? progress : null;
      final workoutIndex = _workoutTaskIndex;
      if (workoutIndex != -1 && _today.tasks.length > workoutIndex) {
        _today.tasks[workoutIndex] = isToday && progress.completed;
      }
      // Sync workout progress to DayRecord so Habits screen can read it
      if (isToday) {
        final todayRecord = _recordFor(DateTime.now());
        if (progress.inProgress || progress.completed) {
          todayRecord.workoutSummary = WorkoutSummary(
            workoutName: progress.workoutName,
            exercisesCompleted: progress.exercisesCompleted,
            totalExercises: progress.totalExercises,
            setsCompleted: progress.setsCompleted,
            totalSets: progress.totalSets,
            setsPerExercise: {},
          );
        } else {
          todayRecord.workoutSummary = null;
        }
      }
    });
    _saveHistory();
  }

  void _togglePrayer(String name) {
    HapticService.medium();
    if (!mounted) return;
    setState(() => _today.prayers[name] = !(_today.prayers[name] ?? false));
    _saveHistory();
  }

  ThemeColors _dayTheme() {
    return const ThemeColors(
      isDark: false,
      bg: Color(0xFFF5F0E8), // Light theme background
      card: Color(0xFFFFFFFF), // Light theme card
      border: Color(0xFFDDD8CC), // Light theme border
      divider: Color(0xFFDDD8CC), // Light theme divider
      navBg: Color(0xFFF9F7F2), // Light theme nav background
      text1: Color(0xFF1A1A2E), // Light theme text
      text2: Color(0xFF2A2A3E), // Light theme text
      text3: Color(0xFF8A8580), // Light theme muted text
      text4: Color(0xFF9A9585), // Light theme very muted text
      gold: Color(0xFFB8860B),
      teal: Color(0xFF0A7A5A),
      blue: Color(0xFF1A6FA0),
      red: Color(0xFFC0392B),
      green: Color(0xFF0A7A5A),
    );
  }

  ThemeColors _nightTheme() {
    return const ThemeColors(
      isDark: true,
      bg: cBg, // Use new dark background constant
      card: cCard, // Use new dark card constant
      border: cCardBorder, // Use new dark border constant
      divider: cCardBorder, // Use new dark border constant
      navBg: cBg, // Use new dark background constant for nav
      text1: cText, // Use new dark text constant
      text2: cText, // Use new dark text constant
      text3: cSub, // Use new dark muted text constant
      text4: cSub2, // Use new dark very muted text constant
      gold: cGold, // Use new gold constant
      teal: cEmerald, // Use new emerald constant
      blue: cAzure, // Use new azure constant
      red: cRose, // Use new rose constant
      green: cEmerald, // Use new emerald constant for general green
    );
  }

  void _toggleTheme() {
    if (!mounted) return;
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    themeNotifier.toggle();
    setState(() {
      _darkOverride = themeNotifier.isDark;
      _theme = themeNotifier.isDark ? _nightTheme() : _dayTheme();
    });
    SystemChrome.setSystemUIOverlayStyle(
      _theme.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }

  final GlobalKey _screenshotKey = GlobalKey();

  Future<void> _takeScreenshot() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary =
          _screenshotKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Screenshot boundary not found')),
        );
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to convert image to bytes')),
        );
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'rayees_screenshot_$timeStamp.png';

      final path = await _channel.invokeMethod<String>(
        'saveScreenshotToGallery',
        {'fileName': fileName, 'bytes': pngBytes},
      );

      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Screenshot saved to: ${path ?? "Gallery"}'),
          backgroundColor: _theme.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Screenshot save failed: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool get widgetIsDark => _theme.isDark;

  Future<void> _printPdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      HapticService.selection();
      final days = <DailyHabitData>[];
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 29));

      for (var i = 29; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final record = _recordFor(date);

        final taskBreakdown = <String, bool>{};
        for (var t = 0; t < kTodayTasks.length; t++) {
          final done = t < record.tasks.length && record.tasks[t];
          taskBreakdown[kTodayTasks[t].title] = done;
        }

        final prayerBreakdown = <String, bool>{};
        for (final p in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha', 'Tahajjud']) {
          prayerBreakdown[p] = record.prayers[p] ?? false;
        }

        days.add(
          DailyHabitData(
            date: date,
            score: record.percent,
            tasksDone: record.taskDone,
            tasksTotal: kTodayTasks.length,
            prayersDone: record.prayerDone,
            prayersTotal: 5,
            taskBreakdown: taskBreakdown,
            prayerBreakdown: prayerBreakdown,
            workoutName: record.workoutSummary?.workoutName,
          ),
        );
      }

      final openDates = await AppOpenService.getAppOpenDates();

      final reportData = HabitReportData(
        userName: _userName.isNotEmpty ? _userName : 'Rayees',
        startDate: startDate,
        endDate: now,
        days: days,
        openDates: openDates,
      );

      final pdfBytes = await PsychologyReportService.generatePdfBytes(reportData);
      final fileName = 'muttaqin_30_day_report_${dayKey(now)}.pdf';

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('30-Day Report generated successfully!'),
            backgroundColor: Color(0xFF2DD4A8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Report generation failed: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<String> _reportLines() {
    final lines = <String>[
      'Rayees 30 Day Task Report',
      'Generated: ${shortDate(DateTime.now())}',
      '',
    ];
    for (var i = 0; i < 30; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final record = _recordFor(date);
      lines.add(
        '${shortDate(date)} - ${record.doneTotal}/${record.total} (${record.percent}%)',
      );
      lines.add('Tasks: ${record.taskDone}/${kTodayTasks.length}');
      for (var t = 0; t < kTodayTasks.length; t++) {
        final done = t < record.tasks.length && record.tasks[t];
        lines.add('  ${done ? '[x]' : '[ ]'} ${kTodayTasks[t].title}');
      }
      if (record.workoutSummary != null) {
        final workout = record.workoutSummary!;
        lines.add('Workout: ${workout.workoutName}');
        lines.add(
          '  Exercises: ${workout.exercisesCompleted}/${workout.totalExercises}',
        );
        lines.add('  Sets: ${workout.setsCompleted}/${workout.totalSets}');
      }
      lines.add('Prayers: ${record.prayerDone}/${kPrayerNames.length}');
      for (final prayer in kPrayerNames) {
        lines.add(
          '  ${(record.prayers[prayer] ?? false) ? '[x]' : '[ ]'} $prayer',
        );
      }
      lines.add('');
    }
    return lines.expand(_wrapLine).toList();
  }

  Iterable<String> _wrapLine(String line) sync* {
    const max = 88;
    var rest = line;
    while (rest.length > max) {
      var cut = rest.lastIndexOf(' ', max);
      if (cut < 20) {
        cut = max;
      }
      yield rest.substring(0, cut);
      rest = '  ${rest.substring(cut).trimLeft()}';
    }
    yield rest;
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    _theme = themeNotifier.isDark ? _nightTheme() : _dayTheme();

    if (!_loaded) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: _theme.gold)),
      );
    }

    final screens = [
      SizedBox.expand(
        child: TodayScreen(
          theme: _theme,
          orbController: _orbController,
          record: _today,
          workoutProgress: _workoutProgress,
          onTaskToggle: _toggleTask,
          onTaskEdit: _editTask,
          onTaskAdd: _addDailyTask,
          onTaskDelete: _deleteTask,
          onTaskReorder: _reorderTask,
          onPrayerToggle: _togglePrayer,
          onThemeToggle: _toggleTheme,
          isDark: _theme.isDark,
          waterGlasses: _waterGlasses,
          onWaterChange: _setWaterGlasses,
          onScreenshot: _takeScreenshot,
          userName: _userName,
          userGoalYear: _userGoalYear,
          userGoalMonth: _userGoalMonth,
          userGoalDay: _userGoalDay,
          userDob: _userDob,
          onProfileChanged: _updateProfile,
          onResetToday: () => _resetDayData(DateTime.now()),
        ),
      ),
      SizedBox.expand(
        child: HabitsScreen(
          theme: _theme,
          history: _history,
          onPrintPdf: () => _printPdf(context),
          lastPdfPath: _lastPdfPath,
          incomeLog: _incomeLog,
          expenseLog: _expenseLog,
          onSetIncome: _setIncomeForDate,
          onSetExpense: _setExpenseForDate,
          onResetDay: _resetDayData,
          onScreenshot: _takeScreenshot,
        ),
      ),
      SizedBox.expand(
        child: WorkoutScreen(
          theme: _theme,
          onWorkoutCompleted: _markWorkoutCompleted,
          onWorkoutProgressChanged: _updateWorkoutProgress,
          onScreenshot: _takeScreenshot,
          userName: _userName,
          onNameChanged: _updateProfileFromNameChanged,
          userGoalYear: _userGoalYear,
          userGoalMonth: _userGoalMonth,
          userGoalDay: _userGoalDay,
        ),
      ),
      SizedBox.expand(
        child: IncomeScreen(
          theme: _theme,
          incomeLog: _incomeLog,
          expenseLog: _expenseLog,
          onAddEntry: _addIncomeEntry,
          onAddExpense: _addExpenseEntry,
          onScreenshot: _takeScreenshot,
        ),
      ),
      SizedBox.expand(
        child: LifePlanScreen(
          theme: _theme,
          onScreenshot: _takeScreenshot,
          userGoalYear: _userGoalYear,
        ),
      ),
    ];

    final currentTab = _tab.clamp(0, screens.length - 1);

    return RepaintBoundary(
      key: _screenshotKey,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: List.generate(screens.length, (index) {
              final isCurrent = index == currentTab;
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isCurrent ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !isCurrent,
                  child: screens[index],
                ),
              );
            }),
          ),
          bottomNavigationBar: ValueListenableBuilder<bool>(
            valueListenable: _MainScreenState.hideBottomNavNotifier,
            builder: (context, hideNav, child) {
              if (hideNav) return const SizedBox.shrink();
              return _BottomNavBar(
                selectedIndex: currentTab,
                onTap: (i) {
                  if (_tab != i) {
                    HapticService.selection();
                    setState(() => _tab = i);
                  }
                },
                theme: _theme,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MoreHubScreen extends StatelessWidget {
  final ThemeColors theme;
  final String userName;
  final VoidCallback onOpenWorkout;
  final VoidCallback onOpenIncome;
  final VoidCallback onPrintPdf;
  final VoidCallback onPrayerSettings;

  const _MoreHubScreen({
    required this.theme,
    required this.userName,
    required this.onOpenWorkout,
    required this.onOpenIncome,
    required this.onPrintPdf,
    required this.onPrayerSettings,
  });

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = theme.isDark;

    Widget hubCard({
      required String title,
      required String subtitle,
      required IconData icon,
      required Color accentColor,
      required VoidCallback onTap,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticService.tapFeedback();
              onTap();
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppFonts.display(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: theme.text1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: AppFonts.text(
                            fontSize: 12.5,
                            color: theme.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.text3,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 90),
          physics: const BouncingScrollPhysics(),
          children: [
            Text(
              'More Hub',
              style: AppFonts.display(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: theme.text1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Health, Financial Tracking & Profile',
              style: AppFonts.text(
                fontSize: 13,
                color: theme.text3,
              ),
            ),
            const SizedBox(height: 24),
            hubCard(
              title: 'Workout & Training',
              subtitle: 'Daily splits, routines & exercise progress',
              icon: Icons.fitness_center_rounded,
              accentColor: const Color(0xFF2DD4A8),
              onTap: onOpenWorkout,
            ),
            hubCard(
              title: 'Income & Cash Flow',
              subtitle: 'Daily earnings, monthly goals & expenses',
              icon: Icons.account_balance_wallet_rounded,
              accentColor: const Color(0xFFD4A843),
              onTap: onOpenIncome,
            ),
            hubCard(
              title: 'Monthly Psychology Report',
              subtitle: 'Generate & export PDF performance report',
              icon: Icons.picture_as_pdf_rounded,
              accentColor: const Color(0xFF818CF8),
              onTap: onPrintPdf,
            ),
            hubCard(
              title: 'Prayer & Notification Settings',
              subtitle: 'Calculation methods, adhan & reminders',
              icon: Icons.notifications_active_rounded,
              accentColor: const Color(0xFF38BDF8),
              onTap: onPrayerSettings,
            ),
            hubCard(
              title: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              subtitle: isDark ? 'Cream surface #F5F0E8' : 'Deep obsidian #080810',
              icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              accentColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFF94A3B8),
              onTap: () {
                themeNotifier.toggle();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatefulWidget {
  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.theme,
  });
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final ThemeColors theme;

  @override
  State<_BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<_BottomNavBar>
    with SingleTickerProviderStateMixin {
  static const _activeIcons = [
    Icons.home_rounded,
    Icons.check_circle_rounded,
    Icons.fitness_center_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.flag_rounded,
  ];

  static const _inactiveIcons = [
    Icons.home_outlined,
    Icons.check_circle_outline_rounded,
    Icons.fitness_center_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.flag_outlined,
  ];

  static const _labels = ['Today', 'Habits', 'Workout', 'Income', 'Goals'];

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final navBg = theme.isDark ? cBg : theme.navBg;
    final bubbleColor = theme.teal;
    final inactiveColor = theme.isDark ? const Color(0xFF9898AC) : const Color(0xFF64748B);

    return SafeArea(
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: theme.isDark ? const Color(0xCC080810) : navBg,
              border: Border(
                top: BorderSide(
                  color: theme.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black12,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: List.generate(_labels.length, (i) {
                final isSelected = widget.selectedIndex == i;
                return Expanded(
                  child: InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () {
                      HapticService.tapFeedback();
                      widget.onTap(i);
                    },
                    child: SizedBox(
                      height: 64,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? _activeIcons[i] : _inactiveIcons[i],
                            size: 22,
                            color: isSelected ? bubbleColor : inactiveColor,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _labels[i],
                            maxLines: 1,
                            style: AppFonts.compact(
                              fontSize: 10.5,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              letterSpacing: isSelected ? 0.3 : 0.1,
                              color: isSelected ? bubbleColor : inactiveColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isSelected ? 12 : 0,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: isSelected ? bubbleColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class ScoreRing extends StatelessWidget {
  const ScoreRing({required this.percent, required this.theme, super.key});

  final int percent;
  final ThemeColors theme;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percent / 100),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final score = (value * 100).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 10,
                      valueColor: AlwaysStoppedAnimation(theme.border),
                    ),
                  ),
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 10,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(theme.gold),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$score',
                        style: AppFonts.display(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: theme.gold,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DAILY SCORE',
                        style: AppFonts.text(
                          fontSize: 10,
                          color: theme.text4,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TaskEditSheet extends StatefulWidget {
  final ThemeColors theme;
  final MapEntry<int, TodayTask>? entry;
  final void Function(TodayTask) onSave;
  final VoidCallback? onDelete;

  const _TaskEditSheet({
    required this.theme,
    this.entry,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<_TaskEditSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _tagCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.entry?.value.title ?? '');
    _tagCtrl = TextEditingController(text: widget.entry?.value.tag ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entry != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing ? 'Edit daily task' : 'Add daily task',
            style: AppFonts.display(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: widget.theme.text1,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            style: AppFonts.text(color: widget.theme.text1, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: 'Task name',
              labelStyle: AppFonts.text(color: widget.theme.text3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagCtrl,
            style: AppFonts.text(color: widget.theme.text1, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: 'Time / condition subtitle',
              labelStyle: AppFonts.text(color: widget.theme.text3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (isEditing && widget.onDelete != null)
                TextButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: widget.theme.gold,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  final title = _titleCtrl.text.trim();
                  final tag = _tagCtrl.text.trim();
                  if (title.isEmpty || tag.isEmpty) return;

                  final task = isEditing
                      ? widget.entry!.value.copyWith(title: title, tag: tag)
                      : TodayTask(Icons.check_circle_outline, title, tag);
                  widget.onSave(task);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.theme,
    required this.record,
    required this.workoutProgress,
    required this.onTaskToggle,
    required this.onTaskEdit,
    required this.onTaskAdd,
    required this.onTaskDelete,
    required this.onTaskReorder,
    required this.onPrayerToggle,
    required this.onThemeToggle,
    required this.isDark,
    required this.orbController,
    required this.waterGlasses,
    required this.onWaterChange,
    this.onScreenshot,
    required this.userName,
    required this.userGoalYear,
    required this.userGoalMonth,
    required this.userGoalDay,
    required this.userDob,
    this.onProfileChanged,
    this.onResetToday,
  });

  final Function(String, int, int, int, String)? onProfileChanged;
  final VoidCallback? onResetToday;

  final ThemeColors theme;
  final DayRecord record;
  final WorkoutProgressSnapshot? workoutProgress;
  final ValueChanged<int> onTaskToggle;
  final void Function(int, TodayTask) onTaskEdit;
  final ValueChanged<TodayTask> onTaskAdd;
  final ValueChanged<int> onTaskDelete;
  final void Function(int, int) onTaskReorder;
  final ValueChanged<String> onPrayerToggle;
  final VoidCallback onThemeToggle;
  final bool isDark;
  final AnimationController orbController;
  final int waterGlasses;
  final ValueChanged<int> onWaterChange;
  final VoidCallback? onScreenshot;
  final String userName;
  final int userGoalYear;
  final int userGoalMonth;
  final int userGoalDay;
  final String userDob;

  @override // Fix 1: Mixins
  State<TodayScreen> createState() => _TodayScreenState(); // Fix 1: Mixins
}

class _TodayScreenState extends State<TodayScreen>
    with TickerProviderStateMixin {
  // Fix 1: Mixins
  late AnimationController _animCtrl;
  late AnimationController _pulseCtrl;
  Timer? _timer;
  String _date = '';
  String _day = '';
  int _daysLeft = 0;
  int _countdownTick = 0;
  String _fastStatus = 'none';
  String _fastType = 'Sunnah Fast';
  String _fastStartTime = '';
  String _fastBrokenTime = '';

  int get _dayOfYearIndex {
    final now = DateTime.now();
    final day = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(now.year, 1, 1)).inDays;
    return day % quranAyahs365.length;
  }

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _prayersKey = GlobalKey();
  final GlobalKey _tasksKey = GlobalKey();
  final GlobalKey _waterKey = GlobalKey();

  final List<Animation<double>> _staggeredAnims = [];

  // Filter tasks to exclude water which has its own tracker
  List<MapEntry<int, TodayTask>> get _visibleTasks {
    for (var i = 0; i < kTodayTasks.length; i++) {
      if (kTodayTasks[i].title == 'Drink 2.5L Water') {
        continue;
      }
    }
    return kTodayTasks
        .asMap()
        .entries
        .where((e) => e.value.title != 'Drink 2.5L Water')
        .toList();
  }

  bool _isTaskDone(int index) =>
      index >= 0 &&
      index < widget.record.tasks.length &&
      widget.record.tasks[index];

  int get _visibleTaskDone =>
      _visibleTasks.where((entry) => _isTaskDone(entry.key)).length;

  int get _workoutIndex {
    return kTodayTasks.indexWhere(
      (task) =>
          task.title.trim().toLowerCase() == 'workout' ||
          task.icon.codePoint == Icons.fitness_center.codePoint,
    );
  }

  void _showPrayerSettingsSheet() {
    HapticService.tapFeedback();
    SoundManager.playTapClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SettingsSheet(
        theme: widget.theme,
        userName: widget.userName,
        userGoalYear: widget.userGoalYear,
        userGoalMonth: widget.userGoalMonth,
        userGoalDay: widget.userGoalDay,
        userDob: widget.userDob,
        onProfileChanged: widget.onProfileChanged,
        onResetToday: widget.onResetToday,
        onSaved: () {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _updateTime(); // Initial update
    _loadFastStatus();
    _loadCleanStreaks();
    _loadNoBadHabitsState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Create 8 staggered animation intervals
    for (int i = 0; i < 12; i++) {
      double start = (i * 0.12).clamp(
        0.0,
        1.0,
      ); // Staggered delays: d1=50ms, d2=120ms, d3=180ms, d4=240ms, d5=300ms, d6=360ms, d7=420ms
      double end = (start + 0.4).clamp(
        0.0,
        1.0,
      ); // Each section fades up (opacity 0?1, translateY 16?0)
      _staggeredAnims.add(
        CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    }
    // Timer for updating time and daysLeft
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTime(),
    ); // Use _timer from state

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animCtrl.dispose();
    _pulseCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    if (!mounted) return;
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final nextDate = '${now.day} ${months[now.month - 1]}';
    final nextDay = days[now.weekday % 7];
    final goalDate = DateTime(
      widget.userGoalYear,
      widget.userGoalMonth,
      widget.userGoalDay,
    );
    final nextDaysLeft = goalDate.difference(now).inDays;
    final nextCountdownTick = now.second;
    if (nextDate != _date ||
        nextDay != _day ||
        nextDaysLeft != _daysLeft ||
        nextCountdownTick != _countdownTick) {
      setState(() {
        _date = nextDate;
        _day = nextDay;
        _daysLeft = nextDaysLeft;
        _countdownTick = nextCountdownTick;
      });
    }
  }

  bool isPrayerPassed(String prayer) {
    if (prayer == 'Tahajjud') return false;

    const nextPrayerMap = {
      'Fajr': 'Dhuhr',
      'Dhuhr': 'Asr',
      'Asr': 'Maghrib',
      'Maghrib': 'Isha',
      'Isha': null,
    };

    final nextPrayer = nextPrayerMap[prayer];
    final now = DateTime.now();

    if (nextPrayer != null) {
      final nextTime = _prayerTimes[nextPrayer];
      if (nextTime == null) return false;
      final nextPrayerDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        nextTime.hour,
        nextTime.minute,
      );
      return now.isAfter(nextPrayerDateTime);
    } else {
      // Isha window remains active until midnight/end of day
      return false;
    }
  }

  void _scrollTo(GlobalKey targetKey) {
    final context = targetKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  String _taskSubtitle(MapEntry<int, TodayTask> entry) {
    if (entry.key == _workoutIndex && widget.workoutProgress != null) {
      return widget.workoutProgress!.todaySubtitle;
    }
    return entry.value.tag;
  }

  void _showTaskSheet({MapEntry<int, TodayTask>? entry}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.theme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return _TaskEditSheet(
          theme: widget.theme,
          entry: entry,
          onSave: (updatedTask) {
            Navigator.pop(sheetContext);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                if (entry != null) {
                  widget.onTaskEdit(entry.key, updatedTask);
                } else {
                  widget.onTaskAdd(updatedTask);
                }
              }
            });
          },
          onDelete: () {
            Navigator.pop(sheetContext);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && entry != null) {
                widget.onTaskDelete(entry.key);
              }
            });
          },
        );
      },
    );
  }

  int get _fardPrayerDone {
    const fardPrayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    return fardPrayers.where((p) => widget.record.prayers[p] == true).length;
  }

  Widget _taskRow(MapEntry<int, TodayTask> entry) {
    final task = entry.value;
    final done = _isTaskDone(entry.key);
    final isDark = widget.theme.isDark;

    Widget card = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0AFFFFFF) : const Color(0x06000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: done
              ? const Color(0xFF2DD4A8).withValues(alpha: 0.3)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06)),
          width: 0.5,
        ),
      ),
      child: Row(
          children: [
            GestureDetector(
              onTap: () {
                HapticService.tapFeedback();
                widget.onTaskToggle(entry.key);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: done ? const Color(0xFF00C896) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: done
                      ? null
                      : Border.all(
                          color: widget.theme.isDark
                              ? Colors.white38
                              : Colors.black38,
                          width: 1.8,
                        ),
                  boxShadow: done
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF00C896,
                            ).withValues(alpha: 0.35),
                            blurRadius: 6,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: AppFonts.display(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: done ? widget.theme.text3 : widget.theme.text1,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _taskSubtitle(entry),
                    style: AppFonts.text(
                      fontSize: 11,
                      color: done ? widget.theme.text4 : widget.theme.text2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showTaskSheet(entry: entry),
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: widget.theme.text3,
              ),
            ),
          ],
        ),
      );

    return done ? Opacity(opacity: 0.65, child: card) : card;
  }

  Widget _waterTracker() {
    final int glasses = widget.waterGlasses;
    final double consumed = (glasses * 0.25).clamp(0.0, 2.5);

    final bool morningDone = glasses >= 3;
    final bool afternoonDone = glasses >= 6;
    final bool eveningDone = glasses >= 10;

    Widget chunkPill({
      required String label,
      required String subtitle,
      required int targetGlasses,
      required bool isDone,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticService.selection();
            SoundManager.playTapClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.18)
                  : (widget.theme.isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDone
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.7)
                    : (widget.theme.isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
                width: isDone ? 1.0 : 0.5,
              ),
              boxShadow: isDone
                  ? [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.water_drop_outlined,
                      size: 15,
                      color: isDone
                          ? const Color(0xFF38BDF8)
                          : widget.theme.text3,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: AppFonts.compact(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDone
                            ? const Color(0xFF38BDF8)
                            : widget.theme.text1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppFonts.compact(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDone
                        ? const Color(0xFF38BDF8)
                        : widget.theme.text3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _GlassCard(
      theme: widget.theme,
      glowColor: const Color(0xFF38BDF8),
      radius: 16,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💧', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'Water Intake',
                    style: AppFonts.display(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.theme.text1,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Micro stepper -
                  GestureDetector(
                    onTap: () {
                      if (glasses > 0) {
                        HapticService.selection();
                        widget.onWaterChange(glasses - 1);
                      }
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.theme.isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '−',
                        style: AppFonts.compact(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: widget.theme.text2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      '$glasses/10 · ${consumed.toStringAsFixed(1)}L',
                      style: AppFonts.compact(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Micro stepper +
                  GestureDetector(
                    onTap: () {
                      if (glasses < 10) {
                        HapticService.selection();
                        widget.onWaterChange(glasses + 1);
                      }
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+',
                        style: AppFonts.compact(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (glasses / 10.0).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: widget.theme.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : widget.theme.border,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF38BDF8)),
            ),
          ),
          const SizedBox(height: 14),

          // ── 3 Chunk Pills (48dp+ Touch Targets) ──
          Row(
            children: [
              chunkPill(
                label: 'Morning',
                subtitle: '3 gl (0.75L)',
                targetGlasses: 3,
                isDone: morningDone,
                onTap: () {
                  widget.onWaterChange(morningDone ? 0 : 3);
                },
              ),
              const SizedBox(width: 8),
              chunkPill(
                label: 'Afternoon',
                subtitle: '3 gl (1.5L)',
                targetGlasses: 6,
                isDone: afternoonDone,
                onTap: () {
                  widget.onWaterChange(afternoonDone ? 3 : 6);
                },
              ),
              const SizedBox(width: 8),
              chunkPill(
                label: 'Evening',
                subtitle: '4 gl (2.5L)',
                targetGlasses: 10,
                isDone: eveningDone,
                onTap: () {
                  widget.onWaterChange(eveningDone ? 6 : 10);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Approximate Hijri day of month for the current date.
  int _hijriDayOfMonth() {
    final now = DateTime.now();
    final jd = (now.millisecondsSinceEpoch / 86400000.0 + 2440587.5).floor();
    final l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    final rem = l - 10631 * n + 354;
    final j =
        ((10985 - rem) ~/ 5316) * ((50 * rem) ~/ 17719) +
        (rem ~/ 5670) * ((43 * rem) ~/ 15238);
    final lp =
        rem -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final m = (24 * lp) ~/ 709;
    final day = lp - ((709 * m) ~/ 24);
    return day.clamp(1, 30);
  }

  String _hijriApprox() {
    final day = _hijriDayOfMonth();
    return 'Day $day Hijri';
  }

  /// Returns true if today is a Sunnah fasting day:
  /// Monday, Thursday, or Ayyam al-Bid (13th, 14th, 15th of Hijri month).
  bool _isSunnahDay() {
    final d = DateTime.now().weekday;
    if (d == DateTime.monday || d == DateTime.thursday) return true;
    // Ayyam al-Bid — the three white days of the lunar month
    final hijriDay = _hijriDayOfMonth();
    return hijriDay >= 13 && hijriDay <= 15;
  }

  String _fastingDayName() {
    final d = DateTime.now().weekday;
    if (d == DateTime.monday) return 'Monday Fast';
    if (d == DateTime.thursday) return 'Thursday Fast';
    final hijriDay = _hijriDayOfMonth();
    if (hijriDay >= 13 && hijriDay <= 15) return 'Ayyām al-Bīḍ (Day $hijriDay)';
    return 'No Sunnah Fast Today';
  }

  DateTime _getIftarTime() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 18, 51);
  }

  String _getCountdown() {
    final diff = _getIftarTime().difference(DateTime.now());
    if (diff.isNegative) return '00:00:00';
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  double _fastElapsedProgress() {
    final iftar = _getIftarTime();
    final start = iftar.subtract(const Duration(hours: 14));
    final elapsed = DateTime.now().difference(start).inSeconds;
    return (elapsed / const Duration(hours: 14).inSeconds).clamp(0.0, 1.0);
  }

  String _getNextSunnahDayName() {
    final d = DateTime.now().weekday;
    if (d < DateTime.thursday) return 'Thursday';
    return 'Monday';
  }

  Future<void> _loadFastStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final key = dayKey(DateTime.now());
    setState(() {
      _fastStatus = prefs.getString('fast_status_$key') ?? 'none';
      _fastType = prefs.getString('fast_type_$key') ?? (_isSunnahDay() ? 'Sunnah Fast' : 'Voluntary Fast');
      _fastStartTime = prefs.getString('fast_start_time_$key') ?? 'Fajr';
      _fastBrokenTime = prefs.getString('fast_broken_time_$key') ?? '';
    });
  }

  Future<void> _setFastStatus(String status) async {
    HapticFeedback.selectionClick();
    setState(() => _fastStatus = status);
    final prefs = await SharedPreferences.getInstance();
    final key = dayKey(DateTime.now());
    await prefs.setString('fast_status_$key', status);
  }

  Future<void> _startFast(String fastType) async {
    HapticService.selection();
    final now = DateTime.now();
    final hour12 = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final ampm = now.hour < 12 ? 'AM' : 'PM';
    final timeStr = '$hour12:${now.minute.toString().padLeft(2, '0')} $ampm';

    setState(() {
      _fastStatus = 'fasting';
      _fastType = fastType;
      _fastStartTime = timeStr;
    });

    final prefs = await SharedPreferences.getInstance();
    final key = dayKey(DateTime.now());
    await prefs.setString('fast_status_$key', 'fasting');
    await prefs.setString('fast_type_$key', fastType);
    await prefs.setString('fast_start_time_$key', timeStr);
  }

  Future<void> _breakFast() async {
    HapticService.selection();
    final now = DateTime.now();
    final hour12 = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final ampm = now.hour < 12 ? 'AM' : 'PM';
    final timeStr = '$hour12:${now.minute.toString().padLeft(2, '0')} $ampm';

    setState(() {
      _fastStatus = 'broke';
      _fastBrokenTime = timeStr;
    });

    final prefs = await SharedPreferences.getInstance();
    final key = dayKey(DateTime.now());
    await prefs.setString('fast_status_$key', 'broke');
    await prefs.setString('fast_broken_time_$key', timeStr);
  }

  void _showStartFastSheet() {
    HapticService.tapFeedback();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = widget.theme.isDark;
        final isSunnah = _isSunnahDay();
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text('🌙', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text(
                    'Start Fast',
                    style: AppFonts.display(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: widget.theme.text1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Fasting is voluntary and deliberate worship. Choose your intention:',
                style: AppFonts.text(
                  fontSize: 13,
                  color: widget.theme.text3,
                ),
              ),
              const SizedBox(height: 16),
              if (isSunnah)
                _fastChoiceItem(
                  title: 'Start Sunnah Fast',
                  subtitle: '${_fastingDayName()} • Recommended Sunnah',
                  color: const Color(0xFFD4A843),
                  onTap: () {
                    Navigator.pop(context);
                    _startFast('Sunnah Fast');
                  },
                ),
              _fastChoiceItem(
                title: 'Start Voluntary Fast',
                subtitle: 'Nafl devotion on any day',
                color: widget.theme.teal,
                onTap: () {
                  Navigator.pop(context);
                  _startFast('Voluntary Fast');
                },
              ),
              _fastChoiceItem(
                title: 'Start Ramadan / Qada Fast',
                subtitle: 'Obligatory or make-up fast',
                color: const Color(0xFF38BDF8),
                onTap: () {
                  Navigator.pop(context);
                  _startFast('Ramadan / Qada Fast');
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _setFastStatus('none');
                  },
                  child: Text(
                    'Skip Today',
                    style: AppFonts.text(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: widget.theme.text3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fastChoiceItem({
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = widget.theme.isDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.text(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.theme.text1,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppFonts.text(
                      fontSize: 11,
                      color: widget.theme.text3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: widget.theme.text3,
            ),
          ],
        ),
      ),
    );
  }

  int? _pureMindLastReset;
  int? _noBadHabitsLastReset;
  int? _noFastFoodLastReset;

  // 3 Clean Habits
  bool _habNoBadHabits = true;
  bool _habFastFood = true;
  bool _habNoFap = true;

  Future<void> _loadNoBadHabitsState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _habNoBadHabits = prefs.getBool('hab_no_bad_habits') ?? prefs.getBool('hab_no_smoking') ?? true;
      _habFastFood = prefs.getBool('hab_no_fastfood') ?? true;
      _habNoFap = prefs.getBool('hab_no_fap') ?? true;
    });
  }

  Future<void> _saveHabit(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _toggleHabit(String key, bool current) {
    HapticService.tapFeedback();
    final next = !current;
    _saveHabit(key, next);
    setState(() {
      if (key == 'hab_no_bad_habits' || key == 'hab_no_smoking') _habNoBadHabits = next;
      if (key == 'hab_no_fastfood') _habFastFood = next;
      if (key == 'hab_no_fap') _habNoFap = next;
    });
  }

  void _checkAllHabits() {
    HapticService.tapFeedback();
    _saveHabit('hab_no_bad_habits', true);
    _saveHabit('hab_no_smoking', true);
    _saveHabit('hab_no_fastfood', true);
    _saveHabit('hab_no_fap', true);
    setState(() {
      _habNoBadHabits = true;
      _habFastFood = true;
      _habNoFap = true;
    });
  }

  Future<void> _loadCleanStreaks() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _pureMindLastReset = prefs.getInt('pure_mind_last_reset') ?? prefs.getInt('nofap_last_reset') ?? nowMs;
      _noBadHabitsLastReset = prefs.getInt('no_bad_habits_last_reset') ?? prefs.getInt('smoking_last_reset') ?? nowMs;
      _noFastFoodLastReset = prefs.getInt('no_fastfood_last_reset') ?? nowMs;

      // Ensure keys are persisted
      prefs.setInt('pure_mind_last_reset', _pureMindLastReset!);
      prefs.setInt('no_bad_habits_last_reset', _noBadHabitsLastReset!);
      prefs.setInt('no_fastfood_last_reset', _noFastFoodLastReset!);
    });
  }

  int _calculateDaysClean(int? lastResetMs) {
    if (lastResetMs == null) return 0;
    final lastReset = DateTime.fromMillisecondsSinceEpoch(lastResetMs);
    final now = DateTime.now();
    final lastResetDate = DateTime(lastReset.year, lastReset.month, lastReset.day);
    final nowDate = DateTime(now.year, now.month, now.day);
    return nowDate.difference(lastResetDate).inDays;
  }

  int get _pureMindDaysClean => _calculateDaysClean(_pureMindLastReset);
  int get _noBadHabitsDaysClean => _calculateDaysClean(_noBadHabitsLastReset);
  int get _noFastFoodDaysClean => _calculateDaysClean(_noFastFoodLastReset);

  Future<void> _resetHabitStreak(String habitKey, String habitName) async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(habitKey, nowMs);
    if (habitKey == 'pure_mind_last_reset') await prefs.setInt('nofap_last_reset', nowMs);
    if (habitKey == 'no_bad_habits_last_reset') await prefs.setInt('smoking_last_reset', nowMs);

    HapticService.tapFeedback();
    SoundManager.playTapClick();
    if (mounted) {
      setState(() {
        if (habitKey == 'pure_mind_last_reset') _pureMindLastReset = nowMs;
        if (habitKey == 'no_bad_habits_last_reset') _noBadHabitsLastReset = nowMs;
        if (habitKey == 'no_fastfood_last_reset') _noFastFoodLastReset = nowMs;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$habitName streak reset to 0 days. Keep strong! 💪'),
          backgroundColor: widget.theme.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showHabitResetDialog(String habitName, String habitKey) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: widget.theme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: widget.theme.isDark ? Colors.white12 : Colors.black12,
              width: 0.5,
            ),
          ),
          title: Text(
            'Reset $habitName?',
            style: AppFonts.display(
              fontWeight: FontWeight.w800,
              color: widget.theme.text1,
            ),
          ),
          content: Text(
            'Are you sure you want to reset your $habitName streak to 0 days?',
            style: AppFonts.text(color: widget.theme.text2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: AppFonts.text(
                  fontWeight: FontWeight.w600,
                  color: widget.theme.text3,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _resetHabitStreak(habitKey, habitName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.theme.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Yes, Reset',
                style: AppFonts.text(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, int> calculateExactAge(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    int months = now.month - dob.month;
    int days = now.day - dob.day;

    if (days < 0) {
      final prevMonth = DateTime(now.year, now.month, 0);
      days += prevMonth.day;
      months--;
    }
    if (months < 0) {
      months += 12;
      years--;
    }

    return {
      'years': years.clamp(0, 150),
      'months': months.clamp(0, 11),
      'days': days.clamp(0, 31),
    };
  }

  Widget _buildDigitalDigit(String digit) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.theme.isDark
              ? const Color(0x33E8B84B)
              : widget.theme.border,
          width: 1,
        ),
        boxShadow: widget.theme.isDark
            ? [
                const BoxShadow(
                  color: Color(0x10E8B84B),
                  blurRadius: 3,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Text(
        digit,
        style: AppFonts.display(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: const Color(0xFFE8B84B),
        ),
      ),
    );
  }

  Widget _buildDigitalMeterGroup(String label, int value) {
    final valStr = value.toString().padLeft(2, '0');
    final digits = valStr.split('');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: digits.map((d) => _buildDigitalDigit(d)).toList(),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: AppFonts.text(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: widget.theme.text3,
          ),
        ),
      ],
    );
  }

  Map<String, String> _getMementoMoriQuote() {
    final now = DateTime.now();
    final fajr = _prayerTimes['Fajr'] ?? const TimeOfDay(hour: 5, minute: 0);
    final dhuhr = _prayerTimes['Dhuhr'] ?? const TimeOfDay(hour: 12, minute: 30);
    final asr = _prayerTimes['Asr'] ?? const TimeOfDay(hour: 15, minute: 45);
    final maghrib = _prayerTimes['Maghrib'] ?? const TimeOfDay(hour: 18, minute: 30);
    final isha = _prayerTimes['Isha'] ?? const TimeOfDay(hour: 19, minute: 45);

    final fajrDt = DateTime(now.year, now.month, now.day, fajr.hour, fajr.minute);
    final dhuhrDt = DateTime(now.year, now.month, now.day, dhuhr.hour, dhuhr.minute);
    final asrDt = DateTime(now.year, now.month, now.day, asr.hour, asr.minute);
    final maghribDt = DateTime(now.year, now.month, now.day, maghrib.hour, maghrib.minute);
    final ishaDt = DateTime(now.year, now.month, now.day, isha.hour, isha.minute);

    if (now.isAfter(ishaDt) || now.isBefore(fajrDt)) {
      return {
        'quote': 'O son of Adam, you are but days. Whenever a day passes, a part of you has gone.',
        'source': '— Hasan al-Basri',
        'action': 'Night reflection ›',
        'period': 'After Isha',
      };
    } else if (now.isAfter(maghribDt)) {
      return {
        'quote': 'Whoever wakes up secure in his dwelling, with the provision of his day, it is as if the entire world has been gathered for him.',
        'source': '— Tirmidhi',
        'action': 'Give thanks & reflect ›',
        'period': 'After Maghrib',
      };
    } else if (now.isAfter(asrDt)) {
      return {
        'quote': 'By time, indeed mankind is in loss, except those who believe and do righteous deeds.',
        'source': '— Surah Al-Asr',
        'action': 'Read one verse ›',
        'period': 'After Asr',
      };
    } else if (now.isAfter(dhuhrDt)) {
      return {
        'quote': 'The feet of a servant will not move on the Day of Judgment until he is asked about his life and how he spent it.',
        'source': '— Tirmidhi',
        'action': "Review today's prayers ›",
        'period': 'After Dhuhr',
      };
    } else {
      return {
        'quote': 'Take advantage of five before five: your youth before your old age, your health before your sickness, your wealth before your poverty, your free time before your busyness, and your life before your death.',
        'source': '— Al-Hakim',
        'action': 'Log one good deed ›',
        'period': 'After Fajr',
      };
    }
  }

  double _getDayProgress() {
    final now = DateTime.now();
    final fajr = _prayerTimes['Fajr'] ?? const TimeOfDay(hour: 5, minute: 0);
    final isha = _prayerTimes['Isha'] ?? const TimeOfDay(hour: 20, minute: 0);
    final fajrDt = DateTime(now.year, now.month, now.day, fajr.hour, fajr.minute);
    final ishaDt = DateTime(now.year, now.month, now.day, isha.hour, isha.minute);

    if (now.isBefore(fajrDt)) return 0.05;
    if (now.isAfter(ishaDt)) return 1.0;
    final total = ishaDt.difference(fajrDt).inSeconds;
    final elapsed = now.difference(fajrDt).inSeconds;
    return (elapsed / total).clamp(0.05, 1.0);
  }

  Widget _buildAgeDigitalMeter() {
    final dob = DateTime.tryParse(widget.userDob) ?? DateTime(2000, 1, 1);
    final ageData = calculateExactAge(dob);
    final quoteInfo = _getMementoMoriQuote();
    final dayProgress = _getDayProgress();
    final dayPct = (dayProgress * 100).round();

    final isDark = widget.theme.isDark;
    final cardBg = isDark ? const Color(0xFF14141E) : Colors.white;
    const goldColor = Color(0xFFD4A843);
    const tealColor = Color(0xFF2DD4A8);

    Color progressColor;
    if (dayProgress < 0.35) {
      progressColor = goldColor;
    } else if (dayProgress < 0.75) {
      progressColor = tealColor;
    } else {
      progressColor = const Color(0xFF94A3B8);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 14, color: goldColor),
                  const SizedBox(width: 8),
                  Text(
                    'DAILY REFLECTION',
                    style: AppFonts.compact(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: widget.theme.text3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${ageData['years']}y ${ageData['months']}m',
                  style: AppFonts.compact(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: goldColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Wisdom Quote
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: goldColor.withValues(alpha: 0.18),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '"${quoteInfo['quote']}"',
                  textAlign: TextAlign.center,
                  style: AppFonts.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: widget.theme.text1,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  quoteInfo['source']!,
                  style: AppFonts.compact(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: goldColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Daylight Progress Bar (Unambiguous referent)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daylight elapsed today (Fajr → Isha):',
                style: AppFonts.text(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: widget.theme.text3,
                ),
              ),
              Text(
                '$dayPct%',
                style: AppFonts.compact(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: dayProgress,
              minHeight: 5,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBadHabitsCard() {
    final maxStreak = math.max(_pureMindDaysClean, math.max(_noBadHabitsDaysClean, _noFastFoodDaysClean));
    const goldColor = Color(0xFFD4A843);
    const tealColor = Color(0xFF2DD4A8);
    const badHabitColor = Color(0xFF94A3B8);
    const fastFoodColor = Color(0xFFFBBF24);
    const fapColor = Color(0xFF818CF8);

    final allClean = _habNoBadHabits && _habFastFood && _habNoFap;
    final milestones = [7, 14, 30, 60, 90, 180];

    String motivationalText() {
      if (maxStreak >= 180) return 'Half a year! You are legendary 👑';
      if (maxStreak >= 90) return 'Three months strong! 🏆';
      if (maxStreak >= 30) return 'Incredible self-control! 🌟';
      if (maxStreak >= 14) return 'Two weeks! Keep pushing 🚀';
      if (maxStreak >= 7) return 'One week down, stay strong! 💪';
      if (maxStreak >= 1) return 'Streak active. Keep going strong! 🔥';
      return 'Today is a clean slate. Stay focused! 🌱';
    }

    Widget subHabitRow({
      required String label,
      required IconData icon,
      required Color iconColor,
      required bool checked,
      required String habitKey,
      required int streakDays,
      required String resetKey,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: checked
              ? tealColor.withValues(alpha: 0.08)
              : (widget.theme.isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: checked
                ? tealColor.withValues(alpha: 0.3)
                : widget.theme.border,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            // Unified Vector Icon in Badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggleHabit(habitKey, checked),
                onLongPress: () => _showHabitResetDialog(label, resetKey),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppFonts.text(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: widget.theme.text1,
                      ),
                    ),
                    Text(
                      checked
                          ? '${streakDays > 0 ? "$streakDays day streak · " : ""}Clean today ✓'
                          : '${streakDays > 0 ? "$streakDays day streak · " : ""}Tap to mark clean',
                      style: AppFonts.text(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: checked ? tealColor : widget.theme.text3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Checkmark Toggle Circle (Safely isolated on trailing edge)
            GestureDetector(
              onTap: () => _toggleHabit(habitKey, checked),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: checked ? tealColor : Colors.transparent,
                  border: Border.all(
                    color: checked ? tealColor : widget.theme.border,
                    width: 1.5,
                  ),
                  boxShadow: checked
                      ? [
                          BoxShadow(
                            color: tealColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: checked
                    ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                    : null,
              ),
            ),
          ],
        ),
      );
    }

    String streakDisplay;
    if (maxStreak == 0) {
      streakDisplay = allClean ? 'Day 1 (Clean)' : 'Today Started';
    } else if (maxStreak == 1) {
      streakDisplay = '1 Day';
    } else {
      streakDisplay = '$maxStreak Days';
    }

    return _GlassCard(
      theme: widget.theme,
      glowColor: goldColor,
      radius: 16,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_fire_department_rounded, color: goldColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLEAN STREAKS',
                      style: AppFonts.compact(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: widget.theme.text3,
                      ),
                    ),
                    Text(
                      streakDisplay,
                      style: AppFonts.display(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: goldColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Streak status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (allClean ? tealColor : goldColor).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (allClean ? tealColor : goldColor).withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  allClean ? 'All clean today ✓' : 'In Progress',
                  style: AppFonts.compact(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: allClean ? tealColor : goldColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            motivationalText(),
            style: AppFonts.text(fontSize: 11.5, color: widget.theme.text3),
          ),
          const SizedBox(height: 14),

          // ── Sub-habit rows with unified vector icons ──
          subHabitRow(
            label: 'Pure Mind',
            icon: Icons.spa_rounded,
            iconColor: tealColor,
            checked: _habNoFap,
            habitKey: 'hab_no_fap',
            streakDays: _pureMindDaysClean,
            resetKey: 'pure_mind_last_reset',
          ),
          subHabitRow(
            label: 'No Bad Habits',
            icon: Icons.block_rounded,
            iconColor: const Color(0xFFF87171),
            checked: _habNoBadHabits,
            habitKey: 'hab_no_bad_habits',
            streakDays: _noBadHabitsDaysClean,
            resetKey: 'no_bad_habits_last_reset',
          ),
          subHabitRow(
            label: 'Clean Eating (No Fast Food)',
            icon: Icons.restaurant_rounded,
            iconColor: fastFoodColor,
            checked: _habFastFood,
            habitKey: 'hab_no_fastfood',
            streakDays: _noFastFoodDaysClean,
            resetKey: 'no_fastfood_last_reset',
          ),

          const SizedBox(height: 10),

          // ── Next Milestone Teaser ──
          Builder(
            builder: (context) {
              final nextM = milestones.firstWhere(
                (m) => m > maxStreak,
                orElse: () => 180,
              );
              final remaining = nextM - maxStreak;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.theme.isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_rounded, size: 14, color: goldColor),
                    const SizedBox(width: 8),
                    Text(
                      remaining > 0
                          ? 'Reach a $nextM-day streak in $remaining more days'
                          : 'Milestone reached! Legend! 🏆',
                      style: AppFonts.text(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: widget.theme.text2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _fastingStatusCard() {
    final isSunnah = _isSunnahDay();
    final isFastingActive = _fastStatus == 'fasting';
    final countdown = _getCountdown();
    final progress = _fastElapsedProgress();
    const gold = Color(0xFFD4A843);
    final isDark = widget.theme.isDark;

    // 1. Not Fasting (default state): Completely hidden on non-Sunnah days
    if (_fastStatus == 'none') {
      if (!isSunnah) {
        return const SizedBox.shrink();
      }
      // On Sunnah days: subtle one-line teaser
      return GestureDetector(
        onTap: _showStartFastSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141418) : const Color(0xFFFAF8F3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: gold.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🌙', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 10),
                  Text(
                    '${_fastingDayName().replaceFirst(' Fast', '')} — Sunnah fast day',
                    style: AppFonts.text(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.theme.text1,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Start Fast ›',
                    style: AppFonts.text(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: gold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // 2. Fast Broken State: Collapses to clean single line
    if (_fastStatus == 'broke') {
      final brokenTime = _fastBrokenTime.isNotEmpty ? _fastBrokenTime : 'earlier';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16161A) : const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.theme.border,
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fast broken at $brokenTime. Next fast: ${_getNextSunnahDayName()}.',
              style: AppFonts.text(
                fontSize: 12,
                color: widget.theme.text3,
              ),
            ),
            GestureDetector(
              onTap: _showStartFastSheet,
              child: Text(
                'Restart ›',
                style: AppFonts.text(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: gold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 3. Fast Completed State: Collapses to clean single line
    if (_fastStatus == 'completed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2DD4A8).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF2DD4A8).withValues(alpha: 0.3),
            width: 0.6,
          ),
        ),
        child: Row(
          children: [
            const Text('✓', style: TextStyle(color: Color(0xFF2DD4A8), fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text(
              '$_fastType completed. BarakAllahu feek.',
              style: AppFonts.text(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.theme.text1,
              ),
            ),
          ],
        ),
      );
    }

    // 4. Active Fasting State: Full cockpit card
    return _GlassCard(
      theme: widget.theme,
      glowColor: gold,
      radius: 16,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('🌙', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _fastType,
                  style: AppFonts.text(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.theme.text1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ACTIVE FAST',
                  style: AppFonts.text(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Fasting since $_fastStartTime • Iftar at 6:51 PM',
            style: AppFonts.text(
              fontSize: 11,
              color: widget.theme.text3,
            ),
          ),
          const SizedBox(height: 12),
          // Timer & Progress Ring Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IFTAR IN',
                    style: AppFonts.text(
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: widget.theme.text3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    countdown,
                    style: AppFonts.display(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: gold,
                    ),
                  ),
                ],
              ),
              // Progress ring
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: widget.theme.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : widget.theme.border,
                      valueColor: const AlwaysStoppedAnimation(gold),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: gold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Break fast button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _breakFast,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'Break Fast',
                    style: AppFonts.text(
                      fontSize: 12,
                      color: const Color(0xFFFF6B6B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _setFastStatus('completed'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD4A8).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF2DD4A8).withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'Complete Fast ✓',
                    style: AppFonts.text(
                      fontSize: 12,
                      color: const Color(0xFF2DD4A8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _prayerTile(String prayer, String arabic) {
    final done = widget.record.prayers[prayer] ?? false;
    final missed = !done && isPrayerPassed(prayer);
    final isNext = !done && !missed && _getNextPrayer()['name'] == prayer;

    final tod = _prayerTimes[prayer] ?? const TimeOfDay(hour: 0, minute: 0);
    final hour12 = tod.hour == 0
        ? 12
        : (tod.hour > 12 ? tod.hour - 12 : tod.hour);
    final timeStr = '$hour12:${tod.minute.toString().padLeft(2, '0')}';

    Color borderColor;
    Color timeColor;

    if (done) {
      borderColor = const Color(0xFF2DD4A8).withValues(alpha: 0.6); // completed border
      timeColor = const Color(0xFF2DD4A8);
    } else if (isNext) {
      borderColor = const Color(0xFF2DD4A8); // current active glow border
      timeColor = const Color(0xFF2DD4A8);
    } else if (missed) {
      borderColor = widget.theme.isDark
          ? Colors.white.withValues(alpha: 0.08)
          : widget.theme.border;
      timeColor = widget.theme.text3;
    } else {
      borderColor = widget.theme.isDark
          ? Colors.white.withValues(alpha: 0.05)
          : widget.theme.border;
      timeColor = widget.theme.text2;
    }

    return GestureDetector(
      onTap: () => widget.onPrayerToggle(prayer),
      child: Container(
        decoration: BoxDecoration(
          color: done
              ? const Color(0xFF2DD4A8).withValues(alpha: 0.08)
              : widget.theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isNext ? 1.2 : 0.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              prayer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.compact(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: done ? const Color(0xFF2DD4A8) : widget.theme.text1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              timeStr,
              maxLines: 1,
              style: AppFonts.compact(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: timeColor,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? const Color(0xFF2DD4A8) : Colors.transparent,
                border: Border.all(
                  color: done ? const Color(0xFF2DD4A8) : widget.theme.border,
                  width: 1.0,
                ),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, color: Colors.black, size: 10)
                  : (isNext
                      ? Container(
                          margin: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF2DD4A8),
                          ),
                        )
                      : null),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _getNextPrayer() {
    final now = DateTime.now();

    for (final prayer in [
      'Tahajjud',
      'Fajr',
      'Dhuhr',
      'Asr',
      'Maghrib',
      'Isha',
    ]) {
      final time = _prayerTimes[prayer]!;
      final prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (now.isBefore(prayerTime) &&
          !(widget.record.prayers[prayer] ?? false)) {
        final diff = prayerTime.difference(now);
        final hours = diff.inHours;
        final minutes = diff.inMinutes % 60;
        final hour12 = time.hour == 0
            ? 12
            : (time.hour > 12 ? time.hour - 12 : time.hour);
        final ampm = time.hour < 12 ? 'AM' : 'PM';
        final timeStr =
            '$hour12:${time.minute.toString().padLeft(2, '0')} $ampm';
        final inStr = 'in ${hours > 0 ? '${hours}h ' : ''}${minutes}m';
        return {'name': prayer, 'time': timeStr, 'in': inStr};
      }
    }
    final completedCount = widget.record.prayers.entries
        .where((e) => e.key != 'Tahajjud' && e.value == true)
        .length;
    if (completedCount >= 5) {
      return {'name': 'All Done', 'time': '5/5 prayed', 'in': '✓'};
    }

    // After Isha: Next upcoming prayer is Tomorrow's Fajr
    final fajrTime = _prayerTimes['Fajr'] ?? const TimeOfDay(hour: 5, minute: 4);
    final tomorrowFajr = DateTime(
      now.year,
      now.month,
      now.day + 1,
      fajrTime.hour,
      fajrTime.minute,
    );
    final diff = tomorrowFajr.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final hour12 = fajrTime.hour == 0
        ? 12
        : (fajrTime.hour > 12 ? fajrTime.hour - 12 : fajrTime.hour);
    final ampm = fajrTime.hour < 12 ? 'AM' : 'PM';
    final timeStr =
        '$hour12:${fajrTime.minute.toString().padLeft(2, '0')} $ampm';
    final inStr = 'in ${hours > 0 ? '${hours}h ' : ''}${minutes}m';
    return {'name': 'Fajr', 'time': timeStr, 'in': inStr, 'isTomorrow': 'true'};
  }

  Widget _nextPrayerBanner() {
    final nextPrayer = _getNextPrayer();
    if (nextPrayer['name'] == 'All Done') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2DD4A8).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF2DD4A8).withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF2DD4A8), size: 18),
            const SizedBox(width: 10),
            Text(
              'All 5 Daily Prayers Completed',
              style: AppFonts.text(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: widget.theme.text1,
              ),
            ),
          ],
        ),
      );
    }

    final isTomorrow = nextPrayer['isTomorrow'] == 'true';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: widget.theme.isDark ? const Color(0xFF18181C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.theme.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PulsingDot(color: const Color(0xFF2DD4A8), size: 10),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isTomorrow ? 'TOMORROW\'S FIRST PRAYER' : 'UPCOMING PRAYER',
                  style: AppFonts.compact(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: widget.theme.text3,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      nextPrayer['name']!,
                      style: AppFonts.display(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: widget.theme.text1,
                      ),
                    ),
                    Text(
                      nextPrayer['time']!,
                      style: AppFonts.text(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2DD4A8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2DD4A8).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF2DD4A8).withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              nextPrayer['in']!,
              style: AppFonts.compact(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF2DD4A8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final displayUserName = widget.userName.trim().isNotEmpty
        ? widget.userName.trim()
        : 'Rayees';
    final now = DateTime.now();

    return Container(
      width: double.infinity,
      color: widget.theme.bg,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'As-salamu alaykum',
                    style: AppFonts.text(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: widget.theme.text3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFD4A843), Color(0xFFF5D78E)],
                    ).createShader(bounds),
                    child: Text(
                      displayUserName,
                      style: AppFonts.display(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_hijriApprox()} • ${shortDate(now)}',
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: widget.theme.text3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _showPrayerSettingsSheet,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x40E8B84B),
                        width: 1.0,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFE8B84B).withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFFE8B84B),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => themeNotifier.toggle(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0x40E8B84B),
                        width: 1.0,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFE8B84B).withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                    child: Icon(
                      themeNotifier.isDark ? Icons.nights_stay : Icons.wb_sunny,
                      color: const Color(0xFFE8B84B),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCountdown() {
    return Column(
      children: [
        SizedBox(
          width: 200,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(200, 110),
                painter: _HeroArcPainter(
                  progress: _daysLeft / 365.0,
                  color: const Color(0xFFE8B84B),
                ),
              ),
              Positioned(
                top: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_daysLeft',
                      style: AppFonts.display(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE8B84B),
                      ),
                    ),
                    Text(
                      'Target Days Remaining',
                      style: AppFonts.text(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: widget.theme.text3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$_date \u2022 $_day',
          style: AppFonts.text(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: widget.theme.text4,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleTaskCount = _visibleTasks.length;
    final totalPrayers = kPrayerNames.length;
    final prayersDoneCount = widget.record.prayerDone;
    final totalTasks = _visibleTasks.length;
    final tasksDone = _visibleTaskDone;
    const waterGoal = 10;
    final waterDone = widget.waterGlasses.clamp(0, waterGoal);

    final prayerProgress = totalPrayers == 0
        ? 0.0
        : (prayersDoneCount / totalPrayers).clamp(0.0, 1.0);
    final taskProgress = totalTasks == 0
        ? 0.0
        : (tasksDone / totalTasks).clamp(0.0, 1.0);
    final waterProgress = waterGoal == 0
        ? 0.0
        : (waterDone / waterGoal).clamp(0.0, 1.0);
    final todayScore =
        ((prayerProgress * 50) + (taskProgress * 30) + (waterProgress * 20))
            .round();

    return Scaffold(
      backgroundColor: widget.theme.bg,
      body: Stack(
        children: [
          // 1. Ambient fixed auroras (only in dark mode)
          if (widget.theme.isDark) ...[
            Positioned(
              top: -60,
              right: -80,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0x3000C896), const Color(0x0000C896)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 280,
              left: -120,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0x20E8B84B), const Color(0x00E8B84B)],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0x200D4F3C), const Color(0x000D4F3C)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 500,
              right: 40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0x15A78BFA), const Color(0x00A78BFA)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: const SizedBox.shrink(),
              ),
            ),
          ],
          // 3. Scrollable Content
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    90,
                  ), // Padded bottom
                  child: Column(
                    children: [
                      // 1. Current Prayer Hero Card
                      _wrapWithStaggered(0, _nextPrayerBanner()),
                      const SizedBox(height: 16),

                      // 2. Five Daily Prayers (Single 5-step row)
                      _wrapWithStaggered(
                        1,
                        KeyedSubtree(
                          key: _prayersKey,
                          child: _buildPrayerGrid(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Daily Tasks Section
                      _wrapWithStaggered(
                        2,
                        KeyedSubtree(key: _tasksKey, child: _buildTasksList()),
                      ),
                      const SizedBox(height: 16),

                      // 4. Today's Score & Momentum
                      _wrapWithStaggered(
                        3,
                        _buildScoreCard(
                          todayScore,
                          prayerProgress,
                          taskProgress,
                          waterProgress,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Water Intake (3 Chunk Pills)
                      _wrapWithStaggered(
                        4,
                        KeyedSubtree(key: _waterKey, child: _waterTracker()),
                      ),
                      const SizedBox(height: 16),

                      // 6. Clean Streaks
                      _wrapWithStaggered(5, _buildNoBadHabitsCard()),
                      const SizedBox(height: 16),

                      // 7. Daily Mindful Reflection
                      _wrapWithStaggered(6, _buildAgeDigitalMeter()),
                      const SizedBox(height: 16),

                      // 8. Fasting Card (Conditional — hidden unless active or Sunnah day)
                      _wrapWithStaggered(7, _fastingStatusCard()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wrapWithStaggered(int index, Widget child) {
    return FadeTransition(
      opacity: _staggeredAnims[index],
      child: SlideTransition(
        position: _staggeredAnims[index].drive(
          Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }

  Widget _buildAyahCard(IslamicQuote quote) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: _GlassCard(
        theme: widget.theme,
        border: Border.all(color: const Color(0x66E8B84B), width: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 10,
                    color: widget.theme.isDark
                        ? const Color(0xFFE8B84B)
                        : widget.theme.gold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'VERSE OF THE DAY',
                    style: AppFonts.text(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: widget.theme.isDark
                          ? const Color(0xFFE8B84B).withValues(alpha: 0.7)
                          : widget.theme.gold.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                quote.arabic,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: AppFonts.arabic(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: widget.theme.isDark
                      ? const Color(0xFFF5D78E)
                      : widget.theme.gold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 1.0,
                color: widget.theme.gold.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 8),
              Text(
                quote.translation,
                textAlign: TextAlign.center,
                style: AppFonts.text(
                  fontSize: 12,
                  color: widget.theme.text2,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                quote.reference,
                textAlign: TextAlign.center,
                style: AppFonts.display(
                  fontSize: 9,
                  color: widget.theme.text3,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tomorrow: Hadith of the Day →',
                style: AppFonts.text(
                  fontSize: 10,
                  color: widget.theme.gold,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHadithCard(IslamicQuote quote) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: _GlassCard(
        theme: widget.theme,
        border: Border.all(
          color: widget.theme.teal.withValues(alpha: 0.4),
          width: 0.5,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border, size: 10, color: widget.theme.teal),
                  const SizedBox(width: 6),
                  Text(
                    'HADITH OF THE DAY',
                    style: AppFonts.text(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: widget.theme.teal.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                quote.arabic,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: AppFonts.arabic(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: widget.theme.isDark
                      ? widget.theme.text1
                      : widget.theme.teal,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 1.0,
                color: widget.theme.teal.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 8),
              Text(
                quote.translation,
                textAlign: TextAlign.center,
                style: AppFonts.text(
                  fontSize: 12,
                  color: widget.theme.text2,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                quote.reference,
                textAlign: TextAlign.center,
                style: AppFonts.display(
                  fontSize: 9,
                  color: widget.theme.text3,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tomorrow: Verse of the Day →',
                style: AppFonts.text(
                  fontSize: 10,
                  color: widget.theme.teal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label, {VoidCallback? onAdd}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3.5,
              height: 16,
              decoration: BoxDecoration(
                color: widget.theme.gold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppFonts.display(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: widget.theme.text1,
              ),
            ),
          ],
        ),
        if (onAdd != null) _HeaderAddButton(onTap: onAdd, theme: widget.theme),
      ],
    ),
  );

  Widget _buildMetricRow(int visibleTaskCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _metricRingCard(
          'Prayers',
          _fardPrayerDone,
          5,
          const Color(0xFFE8B84B),
          _prayersKey,
        ),
        const SizedBox(width: 12),
        _metricRingCard(
          'Tasks',
          _visibleTaskDone,
          visibleTaskCount,
          const Color(0xFF00C896),
          _tasksKey,
        ),
        const SizedBox(width: 12),
        _metricRingCard(
          'Water',
          widget.waterGlasses,
          10,
          const Color(0xFF38BDF8),
          _waterKey,
        ),
      ],
    );
  }

  Widget _metricRingCard(
    String label,
    int val,
    int max,
    Color fallbackColor,
    GlobalKey targetKey,
  ) {
    final progress = max <= 0 ? 0.0 : (val / max).clamp(0.0, 1.0);
    final pct = (progress * 100).round();

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _scrollTo(targetKey),
        child: _GlassCard(
          theme: widget.theme,
          glowColor: fallbackColor,
          radius: 18,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(
                  painter: _MetricRingPainter(
                    progress: progress,
                    color: fallbackColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppFonts.text(
                  fontSize: 11,
                  color: widget.theme.text3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$pct%',
                style: AppFonts.text(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fallbackColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(
    int todayScore,
    double prayerProgress,
    double taskProgress,
    double waterProgress,
  ) {
    final bool hasStarted = todayScore > 0;
    final int displayScore = todayScore;

    return _GlassCard(
      theme: widget.theme,
      glowColor: const Color(0xFFD4A843),
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Daily Momentum",
                  style: AppFonts.compact(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.theme.text3,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasStarted ? '$displayScore / 100' : 'Start Today',
                  style: AppFonts.display(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: widget.theme.text1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasStarted
                      ? '${(todayScore).round()}% daily goals completed'
                      : 'Check off your first prayer or task',
                  style: AppFonts.text(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: hasStarted ? const Color(0xFF2DD4A8) : widget.theme.text3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            height: 56,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: hasStarted ? (displayScore / 100).clamp(0.10, 1.0) : 0.10),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, arcProgress, child) {
                return CustomPaint(
                  painter: _ScoreArcPainter(
                    progress: arcProgress,
                    color: const Color(0xFFD4A843),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerGrid() {
    final fardPrayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final fardDone = fardPrayers.where((p) => widget.record.prayers[p] ?? false).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header for 5 Main Daily Prayers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Prayers',
                style: AppFonts.display(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: widget.theme.text1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8B84B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE8B84B).withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  fardDone == 0 ? '5 Ahead' : '$fardDone of 5 Done',
                  style: AppFonts.compact(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE8B84B),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // 5 Obligatory Prayers Grid: Single edge-to-edge 5-step path
        Row(
          children: fardPrayers
              .map(
                (p) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: _prayerTile(p, _TodayScreenState.arabicNames[p]!),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        // Optional Night Prayer (Tahajjud) Tile
        _buildTahajjudOptionalTile(),
      ],
    );
  }

  Widget _buildTahajjudOptionalTile() {
    final done = widget.record.prayers['Tahajjud'] ?? false;
    final tod = _prayerTimes['Tahajjud'] ?? const TimeOfDay(hour: 3, minute: 4);
    final hour12 = tod.hour == 0
        ? 12
        : (tod.hour > 12 ? tod.hour - 12 : tod.hour);
    final ampm = tod.hour < 12 ? 'AM' : 'PM';
    final timeStr = '$hour12:${tod.minute.toString().padLeft(2, '0')} $ampm';
    const prayer = 'Tahajjud';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTap: () {
          HapticService.tapFeedback();
          widget.onPrayerToggle(prayer);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: widget.theme.isDark
                ? const Color(0x1F2A2A3E)
                : widget.theme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: done
                  ? const Color(0xFF00C896).withValues(alpha: 0.5)
                  : widget.theme.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : widget.theme.border,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    done ? '🌙' : '🌑',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Tahajjud',
                            style: AppFonts.text(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: widget.theme.text1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.theme.isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'OPTIONAL / SUNNAH',
                              style: AppFonts.text(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: widget.theme.text3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Night prayer • $timeStr',
                        style: AppFonts.text(
                          fontSize: 11,
                          color: widget.theme.text3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? const Color(0xFF00C896) : Colors.transparent,
                  border: Border.all(
                    color: done ? const Color(0xFF00C896) : widget.theme.border,
                    width: 1.5,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTasksList() {
    const goldColor = Color(0xFFD4A843);
    final totalTasks = _visibleTasks.length;
    final doneTasks = _visibleTaskDone;
    final isDark = widget.theme.isDark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: goldColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Daily Tasks',
                    style: AppFonts.display(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: widget.theme.text1,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      doneTasks == 0
                          ? '$totalTasks To Do'
                          : '$doneTasks of $totalTasks Done',
                      style: AppFonts.compact(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: goldColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showTaskSheet(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: goldColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Empty State Callout when no tasks
          if (_visibleTasks.isEmpty)
            GestureDetector(
              onTap: () => _showTaskSheet(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 22,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: goldColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: goldColor.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.add_task_rounded,
                      color: goldColor,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "No daily tasks set",
                      style: AppFonts.display(
                        color: widget.theme.text1,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Tap '+' to add your first goal for today",
                      style: AppFonts.text(
                        color: widget.theme.text3,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Task Rows
          ..._visibleTasks.map(
            (entry) => RepaintBoundary(child: _taskRow(entry)),
          ),
        ],
      ),
    );
  }

  static const arabicNames = {
    'Tahajjud': '\u062a\u0647\u062c\u062f',
    'Fajr': '\u0641\u062c\u0631',
    'Dhuhr': '\u0638\u0647\u0631',
    'Asr': '\u0639\u0635\u0631',
    'Maghrib': '\u0645\u063a\u0631\u0628',
    'Isha': '\u0639\u0634\u0627\u0621',
  };
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.theme,
    required this.child,
    this.padding,
    this.border,
    this.radius = 18,
    this.glowColor,
  });
  final ThemeColors theme;
  final Widget child;
  final EdgeInsets? padding;
  final BoxBorder? border;
  final double radius;
  final Color? glowColor;
  final double blurSigma = 12.0;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.isDark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border:
            border ??
            Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.5,
            ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF3C321E).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(radius),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MetricRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _MetricRingPainter({
    required this.progress,
    required this.color,
  }); // Fix 6: Remove const from _GlassPainter

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint() // Background circle: color with 0.12 opacity
          ..color = color.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4; // StrokeWidth 4
    canvas.drawCircle(size.center(Offset.zero), size.width / 2, paint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round; // Using .withValues(alpha: x)
    canvas.drawArc(
      // Foreground arc: strokeCap round, sweep based on progress
      Rect.fromLTWH(0, 0, size.width, size.height),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ScoreArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ScoreArcPainter({
    required this.progress,
    required this.color,
  }); // Fix 6: Remove const from _GlassPainter

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      math.pi,
      math.pi,
      false,
      paint,
    );

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      math.pi,
      math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GlassPainter extends CustomPainter {
  _GlassPainter({
    // Fix 6: Remove const from _GlassPainter
    required this.filled,
    required this.fillColor,
    required this.borderColor,
  });

  final bool filled;
  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.15, 0); // top-left opening
    path.lineTo(
      w * 0.85,
      0,
    ); // top-right opening // Glass icon (38x42, borderRadius 5,5,9,9, border white 0.08 unfilled / azure 0.5 filled)
    path.lineTo(
      w * 0.72,
      h * 0.88,
    ); // bottom-right narrow // Animated fill from bottom (Container h=0%?78%, gradient azure light?azure, borderRadius 0,0,7,7)
    path.quadraticBezierTo(
      w * 0.5,
      h,
      w * 0.28,
      h * 0.88, // bottom curve
    );
    path.lineTo(w * 0.15, 0); // Shadow: azure 0.15 blur 10 when filled
    path.close();

    if (filled) {
      final fillPath = Path();
      fillPath.moveTo(w * 0.22, h * 0.42);
      fillPath.lineTo(w * 0.78, h * 0.42);
      fillPath.lineTo(w * 0.72, h * 0.88);
      fillPath.quadraticBezierTo(
        w * 0.5,
        h,
        w * 0.28,
        h * 0.88,
      ); // Animated fill from bottom (Container h=0%?78%, gradient azure light?azure, borderRadius 0,0,7,7)
      fillPath.close();
      canvas.drawPath(fillPath, Paint()..color = fillColor);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _GlassPainter oldDelegate) {
    return oldDelegate.filled != filled ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}

class StarPatternPainter extends CustomPainter {
  // Islamic geometric star SVG tiled pattern
  const StarPatternPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (double x = 0; x < size.width; x += 40) {
      for (double y = 0; y < size.height; y += 40) {
        _drawStar(canvas, Offset(x, y), paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, Paint paint) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      double angle = i * math.pi / 4;
      double r = (i % 2 == 0) ? 3 : 1;
      path.lineTo(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _HeroArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  _HeroArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 10;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // Active progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HeroArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({super.key, required this.color, this.size = 8});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size * (1.0 + (1.0 - _animation.value) * 0.5),
          height: widget.size * (1.0 + (1.0 - _animation.value) * 0.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _animation.value),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(
                  alpha: 0.5 * (1.0 - _animation.value),
                ),
                blurRadius: widget.size,
                spreadRadius: widget.size * 0.5,
              ),
            ],
          ),
        );
      },
    );
  }
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    super.key,
    required this.theme,
    required this.history,
    required this.onTaskToggle,
    required this.onPrayerToggle,
  });

  final ThemeColors theme;
  final Map<String, DayRecord> history;
  final ValueChanged<int> onTaskToggle;
  final ValueChanged<String> onPrayerToggle;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  int? _markedIndex;

  void _markToday(int taskIndex) {
    HapticFeedback.lightImpact();
    if (taskIndex == -1) {
      for (final prayer in kPrayerNames) {
        if (!(recordFor(widget.history, DateTime.now()).prayers[prayer] ??
            false)) {
          widget.onPrayerToggle(prayer);
        }
      }
    } else if (taskIndex >= 0 &&
        taskIndex < kTodayTasks.length &&
        !recordFor(widget.history, DateTime.now()).tasks[taskIndex]) {
      widget.onTaskToggle(taskIndex);
    }
    setState(() => _markedIndex = taskIndex);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _markedIndex == taskIndex) {
        setState(() => _markedIndex = null);
      }
    });
  }

  Color _getGoalColor(String title) {
    switch (title) {
      case 'Quran Reading':
        return const Color(0xFF00C853);
      case 'TIA Portal Study':
        return const Color(0xFF2979FF);
      case 'Morning Walk':
        return const Color(0xFF00BCD4);
      case 'Workout':
        return const Color(0xFFFF6D00);
      case 'Productive Phone':
        return const Color(0xFFD50000);
      case 'All 7 Prayers':
        return const Color(0xFFFFD600);
      default:
        return kTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    int maxStreak = 0;
    int activeGoals = 0;
    double totalProgress = 0;

    final List<Widget> goalCards = [];
    for (int i = 0; i < kTodayTasks.length; i++) {
      if (kTodayTasks[i].title == 'Drink 2.5L Water') {
        continue;
      }
      final streak = calcStreak(widget.history, i);
      maxStreak = max(maxStreak, streak);
      if (streak > 0) {
        activeGoals++;
      } // No color in TodayTask
      totalProgress += (streak / 30).clamp(0.0, 1.0);
      if (goalCards.any((w) => w.key == ValueKey(i))) {
        continue;
      }
      goalCards.add(_taskGoal(kTodayTasks[i], i));
    }

    final prayerStreak = calcPrayerStreak(widget.history);
    maxStreak = max(maxStreak, prayerStreak);
    if (prayerStreak > 0) {
      activeGoals++;
    }
    totalProgress += (prayerStreak / 30).clamp(0.0, 1.0);
    goalCards.add(
      _taskGoal(
        TodayTask(
          Icons.mosque,
          'All 7 Prayers',
          'Tahajjud to Isha every day',
        ), // No color in TodayTask
        -1,
      ),
    );

    final totalGoals = goalCards.length;
    final avgProgress = totalGoals > 0
        ? (totalProgress / totalGoals * 100).round()
        : 0;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goals',
              style: TextStyle(
                fontSize: 32, // Use Syne
                fontWeight: FontWeight.w800,
                color: theme.text1,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your Today tasks are your goals',
              style: AppFonts.text(
                // Use DM Sans
                fontSize: 14,
                color: theme.text3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // Motivational banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ), // Use cGold and cEmerald
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    // Use cGold and cEmerald
                    const Color(0xFFFF6D00).withValues(alpha: 0.8),
                    const Color(0xFFFFD600).withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    // Use cGold
                    color: const Color(0xFFFF6D00).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, size: 24, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      maxStreak > 0
                          ? '$maxStreak day streak - Keep it going!'
                          : '0 day streak - Start today!',
                      style: AppFonts.display(
                        // Use Syne
                        color: theme.text1,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            ...goalCards,

            const SizedBox(height: 16),

            // Summary row
            _GlassCard(
              theme: theme,
              radius: 16,
              padding: const EdgeInsets.all(16),
              child: Text(
                'Total Progress: $activeGoals/$totalGoals goals active - $avgProgress% this month',
                textAlign: TextAlign.center,
                style: AppFonts.text(
                  // Use DM Sans
                  color: theme.text3,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskGoal(TodayTask task, int taskIndex) {
    final theme = widget.theme;
    final streak = taskIndex == -1
        ? calcPrayerStreak(widget.history)
        : calcStreak(widget.history, taskIndex);
    final progress = (streak / 30).clamp(0.0, 1.0);
    final isDone =
        _markedIndex == taskIndex ||
        (taskIndex == -1
            ? (recordFor(widget.history, DateTime.now()).prayerDone == 7)
            : taskIndex >= 0 &&
                  taskIndex < kTodayTasks.length &&
                  recordFor(widget.history, DateTime.now()).tasks[taskIndex]);
    // The task.color is not used in the new TodayTask definition.
    final goalColor = _getGoalColor(task.title);

    return Container(
      // Positional fix
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.card, // Use cCard
        border: Border.all(color: theme.border, width: 1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left colored accent border
            Container(width: 4, color: goalColor), // Use goalColor
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Icon with matching gradient background
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                goalColor.withValues(alpha: 0.3),
                                goalColor.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: goalColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(
                            task.icon,
                            color: goalColor,
                            size: 22,
                          ), // Use goalColor
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 15, // Use Syne
                                  fontWeight: FontWeight.w800,
                                  color: theme.text1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                task.tag,
                                style: TextStyle(
                                  fontSize: 12, // Use DM Sans
                                  color: theme.text3,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Thicker progress bar with percentage
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              // Use cCardBorder
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    // Use goalColor
                                    colors: [
                                      goalColor.withValues(alpha: 0.5),
                                      goalColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: goalColor.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(progress * 100).round()}%',
                          style: AppFonts.display(
                            // Use Syne
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: goalColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Streak badge
                        Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$streak days',
                              style: AppFonts.display(
                                // Use Syne
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: theme.text1,
                              ),
                            ),
                          ],
                        ),
                        // Mark Done Button
                        GestureDetector(
                          onTap: () => _markToday(taskIndex),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: goalColor, width: 1.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isDone ? 'Done' : 'Mark Done',
                              style: AppFonts.display(
                                // Use Syne
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDone ? goalColor : theme.text1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({
    super.key,
    required this.theme,
    required this.history,
    required this.onPrintPdf,
    required this.lastPdfPath,
    required this.incomeLog,
    required this.expenseLog,
    required this.onSetIncome,
    required this.onSetExpense,
    required this.onResetDay,
    this.onScreenshot,
  });

  final ThemeColors theme;
  final Map<String, DayRecord> history;
  final VoidCallback onPrintPdf;
  final String? lastPdfPath;
  final Map<String, int> incomeLog;
  final Map<String, int> expenseLog;
  final void Function(DateTime, int) onSetIncome;
  final void Function(DateTime, int) onSetExpense;
  final void Function(DateTime) onResetDay;
  final VoidCallback? onScreenshot;

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  DateTime _selectedDate = DateTime.now();
  int _selectedWaterGlasses = 0;
  String _selectedFastStatus = 'none';
  final Map<String, bool> _selectedIslamicHabits = {};

  static const _extraHabitNames = [
    "Quran 1 page",
    "Evening adhkar",
    "No phone 1hr after Fajr",
    "Sleep before midnight",
  ];

  @override
  void initState() {
    super.initState();
    _loadDayData(_selectedDate);
  }

  @override
  void didUpdateWidget(covariant HabitsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload water/fasting data when parent rebuilds (e.g. after tab switch
    // or when Today/Workout screen updates data)
    _loadDayData(_selectedDate);
  }

  Future<void> _loadDayData(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = dayKey(date);

    // 1. Load water glasses
    int waterVal = 0;
    try {
      final MethodChannel channel = const MethodChannel(
        'rayees.history/storage',
      );
      final raw = await channel.invokeMethod<String>(
        'getString',
        'water_$dateStr',
      );
      waterVal = int.tryParse(raw ?? '') ?? 0;
    } catch (_) {}

    // 2. Load fasting status & calculate streak (strictly Opt-In only)
    final fastVal = prefs.getString('fast_status_$dateStr');
    final fastStatus = fastVal ?? 'none';

    // 3. Load extra habits
    final Map<String, bool> habits = {};
    for (var name in _extraHabitNames) {
      habits[name] = prefs.getBool('islamic_habit_${name}_$dateStr') ?? false;
    }

    if (!mounted) return;
    setState(() {
      _selectedWaterGlasses = waterVal.clamp(0, 10);
      _selectedFastStatus = fastStatus;
      _selectedIslamicHabits.clear();
      _selectedIslamicHabits.addAll(habits);
    });
  }

  Future<void> _setWaterGlassesForSelectedDate(int count) async {
    final dateStr = dayKey(_selectedDate);
    final clamped = count.clamp(0, 10);
    HapticService.selection();
    SoundManager.playTapClick();
    setState(() {
      _selectedWaterGlasses = clamped;
    });
    try {
      final MethodChannel channel = const MethodChannel('rayees.history/storage');
      await channel.invokeMethod('setString', {
        'key': 'water_$dateStr',
        'value': '$clamped',
      });
    } catch (_) {}
  }

  bool _isPrayerPassed(String prayer, DateTime selectedDate) {
    if (prayer == 'Tahajjud') return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    if (selDate.isBefore(today)) {
      return true;
    }
    if (selDate.isAfter(today)) {
      return false;
    }

    const nextPrayerMap = {
      'Fajr': 'Dhuhr',
      'Dhuhr': 'Asr',
      'Asr': 'Maghrib',
      'Maghrib': 'Isha',
      'Isha': null,
    };

    final nextPrayer = nextPrayerMap[prayer];
    if (nextPrayer != null) {
      final nextTime = _prayerTimes[nextPrayer];
      if (nextTime == null) return false;
      final nextPrayerDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        nextTime.hour,
        nextTime.minute,
      );
      return now.isAfter(nextPrayerDateTime);
    } else {
      return false;
    }
  }

  String _formatSelectedDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  void _confirmResetDay(BuildContext context, AppColors appColors) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: appColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: appColors.cardBorder, width: 0.5),
          ),
          title: Text(
            'Reset Daily Data',
            style: AppFonts.display(
              fontWeight: FontWeight.w800,
              color: appColors.text1,
            ),
          ),
          content: Text(
            'Reset ALL data for ${_formatSelectedDate(_selectedDate)}?\n\nThis will clear:\n• Tasks\n• Prayers\n• Workout progress\n• Water intake\n• Income entries\n• Fasting log',
            style: AppFonts.text(color: appColors.text2, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: AppFonts.text(
                  fontWeight: FontWeight.w600,
                  color: appColors.text3,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                HapticService.heavy();
                Navigator.pop(dialogContext);
                widget.onResetDay(_selectedDate);
                await _loadDayData(_selectedDate);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: appColors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Reset',
                style: AppFonts.text(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final appColors = AppColors(theme);
    final record = recordFor(widget.history, _selectedDate);

    // 1. Income Data
    final earned = widget.incomeLog[dayKey(_selectedDate)] ?? 0;
    final spent = widget.expenseLog[dayKey(_selectedDate)] ?? 0;
    final netIncome = earned - spent;

    // 2. Fasting status string for header
    String fastingHeaderStatus = 'Not logged';
    if (_selectedFastStatus == 'fasting') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      if (selDate.isBefore(today) ||
          (selDate == today && now.hour >= 18 && now.minute >= 42)) {
        fastingHeaderStatus = 'Logged';
      } else {
        fastingHeaderStatus = 'Fasting';
      }
    } else if (_selectedFastStatus == 'broke') {
      fastingHeaderStatus = 'Broke';
    }

    // 3. Fasting status for card value
    String fastingCardStatus = '—';
    if (_selectedFastStatus == 'fasting') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      if (selDate.isBefore(today) ||
          (selDate == today && now.hour >= 18 && now.minute >= 42)) {
        fastingCardStatus = 'Completed';
      } else {
        fastingCardStatus = 'Fasting';
      }
    } else if (_selectedFastStatus == 'broke') {
      fastingCardStatus = 'Broke';
    }

    // 4. Workout Data
    String workoutStatus = 'Not started';
    String workoutName = 'No workout logged';
    int workoutSetsCompleted = 0;
    int workoutTotalSets = 0;
    if (record.workoutSummary != null) {
      final w = record.workoutSummary!;
      workoutName = w.workoutName;
      workoutSetsCompleted = w.setsCompleted;
      workoutTotalSets = w.totalSets;
      workoutStatus = w.setsCompleted == w.totalSets
          ? 'Completed'
          : 'In progress';
    }

    // 5. Water Data
    final double waterVolume = (_selectedWaterGlasses * 260) / 1000;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatSelectedDate(_selectedDate).toUpperCase(),
                        style: AppFonts.text(
                          fontSize: 10,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w700,
                          color: appColors.gold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Habits & Momentum',
                        style: AppFonts.display(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: appColors.text1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your authentic daily progression',
                        style: AppFonts.text(
                          fontSize: 12,
                          color: appColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Monthly Report Button
                TextButton.icon(
                  onPressed: widget.onPrintPdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFF2DD4A8)),
                  label: Text(
                    'Report',
                    style: AppFonts.text(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2DD4A8),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF2DD4A8).withValues(alpha: 0.1),
                    side: BorderSide(color: const Color(0xFF2DD4A8).withValues(alpha: 0.3), width: 0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. SCORE HERO CARD (Psychology Framed: No 0% shame)
            _GlassCard(
              theme: appColors.theme,
              glowColor: record.percent > 0 ? appColors.gold : appColors.emerald,
              radius: 20,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
              child: Column(
                children: [
                  Text(
                    "TODAY'S MOMENTUM",
                    style: AppFonts.text(
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: appColors.text3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (record.percent == 0) ...[
                    Text(
                      "Let's Start Today",
                      style: AppFonts.display(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: appColors.text1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check off your first habit or prayer to ignite your score',
                      style: AppFonts.text(
                        fontSize: 12,
                        color: appColors.text3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    Text(
                      '${record.percent}%',
                      style: AppFonts.display(
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                        color: record.percent >= 50
                            ? appColors.emerald
                            : appColors.gold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.doneTotal} of 9 core goals completed',
                      style: AppFonts.text(
                        fontSize: 13,
                        color: appColors.text2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Progress Bar
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 6,
                        decoration: BoxDecoration(
                          color: appColors.track,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: record.total == 0
                            ? 0.0
                            : (record.doneTotal / record.total).clamp(0.0, 1.0),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [appColors.emerald, appColors.gold],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. DAY STRIP
            _buildDayStrip(appColors),
            const SizedBox(height: 20),

            // 4. PRAYERS MODULE
            _buildSection(
              title: 'Prayers',
              rightText:
                  "Prayers ${record.prayers.entries.where((e) => e.key != 'Tahajjud' && e.value == true).length}/5 (Fard)",
              rightColor: appColors.emerald,
              appColors: appColors,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final prayer in [
                      'Fajr',
                      'Dhuhr',
                      'Asr',
                      'Maghrib',
                      'Isha',
                      'Tahajjud',
                    ])
                      Container(
                        width: 72,
                        margin: const EdgeInsets.only(right: 6),
                        child: _buildPrayerCard(prayer, record, appColors),
                      ),
                  ],
                ),
              ),
            ),

            // 5. TASKS MODULE
            _buildSection(
              title: 'Tasks',
              rightText: 'Tasks ${record.taskDone}/${kTodayTasks.length}',
              rightColor: appColors.emerald,
              appColors: appColors,
              child: kTodayTasks.isEmpty
                  ? Center(
                      child: Text(
                        'No tasks for today',
                        style: AppFonts.text(
                          fontSize: 13,
                          color: appColors.text3,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (int i = 0; i < kTodayTasks.length; i += 2)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: (i + 2 < kTodayTasks.length) ? 8.0 : 0.0,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildHabitTaskCard(
                                    kTodayTasks[i],
                                    i < record.tasks.length && record.tasks[i] == true,
                                    appColors,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (i + 1 < kTodayTasks.length)
                                  Expanded(
                                    child: _buildHabitTaskCard(
                                      kTodayTasks[i + 1],
                                      (i + 1) < record.tasks.length && record.tasks[i + 1] == true,
                                      appColors,
                                    ),
                                  )
                                else
                                  const Expanded(child: SizedBox.shrink()),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),

            // 6. WORKOUT MODULE (No 0% shame when no workout)
            _buildSection(
              title: 'Workout',
              rightText: workoutTotalSets == 0
                  ? 'Off / Rest Day'
                  : workoutStatus,
              rightColor: workoutTotalSets == 0
                  ? appColors.text3
                  : (workoutStatus == 'Completed'
                      ? appColors.emerald
                      : appColors.gold),
              appColors: appColors,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: appColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: appColors.cardBorder, width: 0.5),
                    ),
                    alignment: Alignment.center,
                    child: workoutTotalSets == 0
                        ? Icon(Icons.fitness_center, size: 20, color: appColors.text3)
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: (workoutSetsCompleted / workoutTotalSets).clamp(0.0, 1.0),
                                strokeWidth: 4,
                                backgroundColor: appColors.track,
                                valueColor: AlwaysStoppedAnimation<Color>(appColors.emerald),
                              ),
                              Text(
                                '${(workoutSetsCompleted / workoutTotalSets * 100).round()}%',
                                style: AppFonts.text(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: appColors.text1,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workoutTotalSets == 0
                              ? 'Rest Day / Off'
                              : workoutName,
                          style: AppFonts.display(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: appColors.text1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          workoutTotalSets == 0
                              ? 'Tap to start or log workout'
                              : '$workoutSetsCompleted of $workoutTotalSets sets completed',
                          style: AppFonts.text(
                            fontSize: 12,
                            color: appColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 7. INCOME MODULE (Compact if zero)
            _buildSection(
              title: 'Income',
              rightText: (earned == 0 && spent == 0)
                  ? 'Tap to log'
                  : 'Net: ${netIncome >= 0 ? '+' : ''}₹$netIncome',
              rightColor: (earned == 0 && spent == 0)
                  ? appColors.text3
                  : (netIncome > 0
                      ? appColors.emerald
                      : (netIncome < 0 ? appColors.red : appColors.text3)),
              appColors: appColors,
              child: (earned == 0 && spent == 0)
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: appColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: appColors.cardBorder, width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined, size: 16, color: appColors.gold),
                              const SizedBox(width: 8),
                              Text(
                                'Tap to log daily cash flow',
                                style: AppFonts.text(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: appColors.text1,
                                ),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: appColors.text3),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        _buildMiniCard(
                          label: 'Earned',
                          value: '₹$earned',
                          valueColor: earned > 0 ? appColors.emerald : appColors.text3,
                          appColors: appColors,
                        ),
                        const SizedBox(width: 8),
                        _buildMiniCard(
                          label: 'Spent',
                          value: '₹$spent',
                          valueColor: spent > 0 ? appColors.red : appColors.text3,
                          appColors: appColors,
                        ),
                        const SizedBox(width: 8),
                        _buildMiniCard(
                          label: 'Net',
                          value: '${netIncome >= 0 ? '+' : ''}₹$netIncome',
                          valueColor: netIncome != 0 ? appColors.gold : appColors.text3,
                          appColors: appColors,
                        ),
                      ],
                    ),
            ),

            // 8. WATER MODULE (Interactive Selectable Glass Icons)
            _buildSection(
              title: 'Water',
              rightText: '${waterVolume.toStringAsFixed(1)} L · 250ml/glass',
              rightColor: appColors.emerald,
              appColors: appColors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildMiniCard(
                        label: 'Target',
                        value: '$_selectedWaterGlasses / 10 glasses',
                        valueColor: const Color(0xFF2DD4A8),
                        appColors: appColors,
                      ),
                      const SizedBox(width: 8),
                      _buildMiniCard(
                        label: 'Intake',
                        value: '${waterVolume.toStringAsFixed(1)} / 2.5 L',
                        valueColor: appColors.text1,
                        appColors: appColors,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 3 Chunked Groups (Morning, Afternoon, Evening)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _setWaterGlassesForSelectedDate(
                              _selectedWaterGlasses >= 3 ? 0 : 3,
                            );
                          },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: _selectedWaterGlasses >= 3
                                  ? const Color(0xFF38BDF8).withValues(alpha: 0.18)
                                  : (appColors.theme.isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : Colors.black.withValues(alpha: 0.03)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedWaterGlasses >= 3
                                    ? const Color(0xFF38BDF8)
                                    : appColors.cardBorder,
                                width: _selectedWaterGlasses >= 3 ? 1.0 : 0.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Morning',
                                  style: AppFonts.compact(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedWaterGlasses >= 3
                                        ? const Color(0xFF38BDF8)
                                        : appColors.text1,
                                  ),
                                ),
                                Text(
                                  '3 gl (0.75L)',
                                  style: AppFonts.compact(
                                    fontSize: 9.5,
                                    color: _selectedWaterGlasses >= 3
                                        ? const Color(0xFF38BDF8)
                                        : appColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _setWaterGlassesForSelectedDate(
                              _selectedWaterGlasses >= 6 ? 3 : 6,
                            );
                          },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: _selectedWaterGlasses >= 6
                                  ? const Color(0xFF38BDF8).withValues(alpha: 0.18)
                                  : (appColors.theme.isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : Colors.black.withValues(alpha: 0.03)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedWaterGlasses >= 6
                                    ? const Color(0xFF38BDF8)
                                    : appColors.cardBorder,
                                width: _selectedWaterGlasses >= 6 ? 1.0 : 0.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Afternoon',
                                  style: AppFonts.compact(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedWaterGlasses >= 6
                                        ? const Color(0xFF38BDF8)
                                        : appColors.text1,
                                  ),
                                ),
                                Text(
                                  '3 gl (1.5L)',
                                  style: AppFonts.compact(
                                    fontSize: 9.5,
                                    color: _selectedWaterGlasses >= 6
                                        ? const Color(0xFF38BDF8)
                                        : appColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _setWaterGlassesForSelectedDate(
                              _selectedWaterGlasses >= 10 ? 6 : 10,
                            );
                          },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: _selectedWaterGlasses >= 10
                                  ? const Color(0xFF38BDF8).withValues(alpha: 0.18)
                                  : (appColors.theme.isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : Colors.black.withValues(alpha: 0.03)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedWaterGlasses >= 10
                                    ? const Color(0xFF38BDF8)
                                    : appColors.cardBorder,
                                width: _selectedWaterGlasses >= 10 ? 1.0 : 0.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Evening',
                                  style: AppFonts.compact(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedWaterGlasses >= 10
                                        ? const Color(0xFF38BDF8)
                                        : appColors.text1,
                                  ),
                                ),
                                Text(
                                  '4 gl (2.5L)',
                                  style: AppFonts.compact(
                                    fontSize: 9.5,
                                    color: _selectedWaterGlasses >= 10
                                        ? const Color(0xFF38BDF8)
                                        : appColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 9. FASTING MODULE
            _buildSection(
              title: 'Fasting',
              rightText: fastingHeaderStatus == 'Not logged'
                  ? 'Opt-in only'
                  : fastingHeaderStatus,
              rightColor: fastingHeaderStatus == 'Logged'
                  ? appColors.emerald
                  : appColors.text3,
              appColors: appColors,
              child: Row(
                children: [
                  _buildMiniCard(
                    label: 'Status',
                    value: fastingCardStatus == '—' || fastingCardStatus == '-'
                        ? 'Not Fasting Today'
                        : fastingCardStatus,
                    valueColor: fastingCardStatus == 'Completed'
                        ? appColors.emerald
                        : (fastingCardStatus == 'Fasting' ? appColors.gold : appColors.text3),
                    appColors: appColors,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    String? rightText,
    Color? rightColor,
    required Widget child,
    required AppColors appColors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppFonts.compact(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: appColors.text1,
              ),
            ),
            if (rightText != null)
              Text(
                rightText,
                style: AppFonts.text(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: rightColor ?? appColors.text2,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _GlassCard(
          theme: appColors.theme,
          radius: 18,
          padding: const EdgeInsets.all(16),
          child: child,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMiniCard({
    required String label,
    required String value,
    required Color valueColor,
    required AppColors appColors,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: appColors.theme.isDark
              ? const Color(0x06FFFFFF)
              : appColors.theme.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: appColors.cardBorder, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: AppFonts.text(
                fontSize: 9.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: appColors.text3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppFonts.display(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerCard(String name, DayRecord record, AppColors appColors) {
    final done = record.prayers[name] == true;
    final missed = !done && _isPrayerPassed(name, _selectedDate);

    Color bgColor;
    Color borderColor;
    Color textColor;
    Widget statusIcon;

    final tod = _prayerTimes[name] ?? const TimeOfDay(hour: 0, minute: 0);
    final timeStr =
        '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';

    if (done) {
      bgColor = appColors.emerald2;
      borderColor = appColors.emerald.withValues(alpha: 0.5);
      textColor = appColors.emerald;
      statusIcon = Icon(
        Icons.check_circle_outline,
        size: 15,
        color: appColors.emerald,
      );
    } else if (missed) {
      bgColor = appColors.theme.isDark
          ? const Color(0x06FFFFFF)
          : appColors.theme.bg;
      borderColor = appColors.cardBorder;
      textColor = appColors.text3;
      statusIcon = Text(
        timeStr,
        style: AppFonts.text(
          fontSize: 9.5,
          color: appColors.text3,
          fontWeight: FontWeight.w500,
        ),
      );
    } else {
      bgColor = appColors.theme.isDark
          ? const Color(0x06FFFFFF)
          : appColors.theme.bg;
      borderColor = appColors.cardBorder;
      textColor = appColors.text3;
      statusIcon = Text(
        timeStr,
        style: AppFonts.text(
          fontSize: 9.5,
          color: appColors.text3,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: AppFonts.text(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          statusIcon,
        ],
      ),
    );
  }

  Widget _buildHabitTaskCard(
    TodayTask task,
    bool done,
    AppColors appColors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFF2DD4A8).withValues(alpha: 0.1)
            : (appColors.theme.isDark
                ? const Color(0x06FFFFFF)
                : appColors.theme.bg),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done
              ? const Color(0xFF2DD4A8).withValues(alpha: 0.5)
              : appColors.cardBorder,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 15,
            color: done ? const Color(0xFF2DD4A8) : appColors.text3,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.text(
                fontSize: 11.5,
                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                color: done ? const Color(0xFF2DD4A8) : appColors.text1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayStrip(AppColors appColors) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(
      7,
      (i) => today.subtract(Duration(days: 6 - i)),
    );

    return Row(
      children: List.generate(7, (index) {
        final date = days[index];
        final isSelected = dayKey(date) == dayKey(_selectedDate);
        final isToday = dayKey(date) == dayKey(today);
        final hasRecord = widget.history.containsKey(dayKey(date));
        final record = recordFor(widget.history, date);
        final percent = record.percent;
        final isTracked = hasRecord && record.doneTotal > 0;

        final shortDayName = [
          'Mon',
          'Tue',
          'Wed',
          'Thu',
          'Fri',
          'Sat',
          'Sun',
        ][date.weekday - 1];
        final dayNumber = date.day.toString();

        String statusLabel;
        Color scoreColor;

        if (isTracked) {
          statusLabel = '$percent%';
          scoreColor = percent >= 50 ? appColors.emerald : appColors.gold;
        } else if (isToday) {
          statusLabel = percent > 0 ? '$percent%' : 'Today';
          scoreColor = percent > 0 ? appColors.emerald : appColors.gold;
        } else {
          statusLabel = '•';
          scoreColor = appColors.text3.withValues(alpha: 0.6);
        }

        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
              _loadDayData(date);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? appColors.card
                    : (appColors.theme.isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.02)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? appColors.gold : appColors.cardBorder,
                  width: isSelected ? 1.5 : 0.5,
                ),
                boxShadow: isSelected ? appColors.shadow : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      shortDayName,
                      style: AppFonts.compact(
                        fontSize: 10.5,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? appColors.gold : appColors.text3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      dayNumber,
                      style: AppFonts.display(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? appColors.text1 : appColors.text2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      statusLabel,
                      style: AppFonts.compact(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: scoreColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class FastingStatusChip extends StatelessWidget {
  final DateTime date;
  final ThemeColors theme;
  const FastingStatusChip({super.key, required this.date, required this.theme});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final prefs = snapshot.data!;
        final status = prefs.getString('fast_status_${dayKey(date)}');

        final isFasting =
            status == 'fasting' || status == 'completed';

        if (isFasting) {
          return StatusChip(
            theme: theme,
            label: 'Fasting',
            done: true,
            color: const Color(0xFFE8B84B), // Gold color for fasting
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class DayHistoryCard extends StatelessWidget {
  const DayHistoryCard({
    super.key,
    required this.theme,
    required this.date,
    required this.record,
    this.income = 0,
    this.expense = 0,
    required this.onSetIncome,
    required this.onSetExpense,
    required this.onResetDay,
  });

  final ThemeColors theme;
  final DateTime date;
  final DayRecord record;
  final int income;
  final int expense;
  final void Function(DateTime, int) onSetIncome;
  final void Function(DateTime, int) onSetExpense;
  final void Function(DateTime) onResetDay;

  void _showIncomeExpenseSheet(BuildContext context) {
    final incomeCtrl = TextEditingController();
    final expenseCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update Income & Expenses',
                style: AppFonts.display(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.text1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                shortDate(date),
                style: AppFonts.text(fontSize: 14, color: theme.text3),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: incomeCtrl,
                keyboardType: TextInputType.number,
                style: AppFonts.text(color: theme.text1, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  labelText: 'Income Earned Today',
                  labelStyle: AppFonts.text(color: theme.text3),
                  prefixIcon: const Icon(Icons.trending_up, color: kTeal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: expenseCtrl,
                keyboardType: TextInputType.number,
                style: AppFonts.text(color: theme.text1, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  labelText: 'Amount Spent Today',
                  labelStyle: AppFonts.text(color: theme.text3),
                  prefixIcon: const Icon(Icons.trending_down, color: kRed),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.gold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final i = int.tryParse(incomeCtrl.text) ?? 0;
                    final e = int.tryParse(expenseCtrl.text) ?? 0;

                    incomeCtrl.clear();
                    expenseCtrl.clear();

                    Navigator.pop(sheetContext);

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      onSetIncome(date, income + i);
                      onSetExpense(date, expense + e);
                    });
                  },
                  child: Text(
                    'Save',
                    style: AppFonts.display(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showWorkoutSummary(BuildContext context, WorkoutSummary summary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workout summary',
                style: AppFonts.display(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.text1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                summary.workoutName,
                style: AppFonts.text(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.text2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${summary.exercisesCompleted}/${summary.totalExercises} exercises - ${summary.setsCompleted}/${summary.totalSets} sets',
                style: AppFonts.text(color: theme.text3, height: 1.5),
              ),
              const SizedBox(height: 16),
              ...summary.setsPerExercise.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: AppFonts.text(color: theme.text1, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        '${entry.value} sets',
                        style: AppFonts.text(color: theme.text3),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.card,
        border: Border.all(
          color: theme.isDark ? const Color(0x17FFFFFF) : Colors.grey.shade200,
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                shortDate(date),
                style: AppFonts.display(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.text1,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${record.doneTotal}/${record.total}',
                    style: AppFonts.display(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: theme.gold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: theme.text3,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            backgroundColor: theme.bg,
                            title: Text(
                              'Reset Day Data?',
                              style: AppFonts.display(color: theme.text1, fontWeight: FontWeight.w700),
                            ),
                            content: Text(
                              'This will permanently clear all tasks, prayers, fasting log, and financial data for ${shortDate(date)}.',
                              style: AppFonts.text(color: theme.text2),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: Text(
                                  'Cancel',
                                  style: AppFonts.text(color: theme.text3),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  onResetDay(date);
                                },
                                child: Text(
                                  'Reset',
                                  style: AppFonts.text(color: Colors.red, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    tooltip: 'Reset Day',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: record.doneTotal / record.total,
              minHeight: 7,
              backgroundColor: const Color(0x10FFFFFF),
              valueColor: AlwaysStoppedAnimation(
                // Use cEmerald
                record.percent >= 80 ? kGreen : theme.teal,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < kTodayTasks.length; i++)
                StatusChip(
                  theme: theme,
                  label: kTodayTasks[i].title,
                  subtitle: kTodayTasks[i].tag,
                  done: i < record.tasks.length && record.tasks[i],
                  color: cEmerald, // Default color for tasks
                ),
              for (final prayer in kPrayerNames)
                StatusChip(
                  theme: theme,
                  label: prayer,
                  done: record.prayers[prayer] ?? false,
                  color: prayerColor(prayer, theme),
                ),
              FastingStatusChip(date: date, theme: theme),
              if (record.workoutSummary != null)
                GestureDetector(
                  onTap: () =>
                      _showWorkoutSummary(context, record.workoutSummary!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      // Use cEmerald
                      color: kTeal.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kTeal.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.fitness_center,
                          size: 12, // Use cEmerald
                          color: kTeal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Workout',
                          style: AppFonts.display(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: theme.text1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showIncomeExpenseSheet(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.currency_rupee,
                        size: 14,
                        color: Color(0xFFD4AF37),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'INCOME',
                        style: AppFonts.text(
                          fontSize: 12,
                          color: kMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap to edit',
                        style: AppFonts.text(
                          fontSize: 12,
                          color: theme.text4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _IncomeMiniCard(
                        label: 'EARNED',
                        amount: income,
                        color: cEmerald,
                        isNet: false,
                        theme: theme,
                      ),
                      const SizedBox(width: 8),
                      _IncomeMiniCard(
                        label: 'SPENT',
                        amount: expense,
                        color: cRose,
                        isNet: false,
                        theme: theme,
                      ),
                      const SizedBox(width: 8),
                      _IncomeMiniCard(
                        label: 'NET',
                        amount: income - expense,
                        color: (income - expense) >= 0 ? cEmerald : cRose,
                        isNet: true,
                        theme: theme,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeMiniCard extends StatelessWidget {
  const _IncomeMiniCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.isNet,
    required this.theme,
  });

  final String label;
  final int amount;
  final Color color;
  final bool isNet;
  final ThemeColors theme;

  @override
  Widget build(BuildContext context) {
    final prefix = isNet ? (amount > 0 ? '+' : (amount < 0 ? '-' : '')) : '';
    final absAmount = amount.abs();
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.navBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.border, width: 0.5),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppFonts.text(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.text4,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$prefix\u20B9${absAmount.toStringAsFixed(0)}',
              style: AppFonts.display(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.theme,
    required this.label,
    this.subtitle,
    required this.done,
    required this.color,
  });

  final ThemeColors theme;
  final String label;
  final String? subtitle;
  final bool done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: done ? color.withValues(alpha: 0.15) : const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: done ? color.withValues(alpha: 0.42) : const Color(0x12FFFFFF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: done ? const Color(0xFF1D9E75) : Colors.red,
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.display(
                    fontSize: 13,
                    color: done ? theme.text1 : theme.text3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.text(
                      fontSize: 12,
                      color: cSub2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MonitorRow extends StatelessWidget {
  const MonitorRow({
    super.key,
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.done,
    this.trailingCircle = false,
  });

  final ThemeColors theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool done;
  final bool trailingCircle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: done ? color.withValues(alpha: 0.07) : theme.card,
        border: Border.all(
          color: done ? color.withValues(alpha: 0.38) : const Color(0x17FFFFFF),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.display(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.text1,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppFonts.text(
                    fontSize: 12,
                    color: theme.text3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            done
                ? Icons.check_circle
                : (trailingCircle
                      ? Icons.radio_button_unchecked
                      : Icons.cancel), // Use cSub2
            color: done
                ? const Color(0xFF1D9E75)
                : (trailingCircle ? Colors.grey : Colors.red),
            size: 25,
          ),
        ],
      ),
    );
  }
}

DayRecord recordFor(Map<String, DayRecord> history, DateTime date) {
  final record = history[dayKey(date)] ?? DayRecord.empty();
  record.syncTaskCount();
  return record;
}

Map<String, TimeOfDay> _prayerTimes = {
  'Tahajjud': const TimeOfDay(hour: 3, minute: 0),
  'Fajr': const TimeOfDay(hour: 5, minute: 12),
  'Dhuhr': const TimeOfDay(hour: 12, minute: 14),
  'Asr': const TimeOfDay(hour: 15, minute: 41),
  'Maghrib': const TimeOfDay(hour: 18, minute: 42),
  'Isha': const TimeOfDay(hour: 20, minute: 0),
};

Map<String, TimeOfDay> calculateDailyPrayerTimes(
  DateTime date,
  double lat,
  double lon, {
  String method = 'MuslimWorldLeague',
  String madhab = 'Shafi',
}) {
  final coordinates = Coordinates(lat, lon);
  final dateComponents = DateComponents.from(date);

  CalculationParameters params;
  switch (method) {
    case 'Karachi':
      params = CalculationMethod.karachi.getParameters();
      break;
    case 'Mecca':
      params = CalculationMethod.umm_al_qura.getParameters();
      break;
    case 'Egypt':
      params = CalculationMethod.egyptian.getParameters();
      break;
    case 'Gulf':
      params = CalculationMethod.dubai.getParameters();
      break;
    case 'NorthAmerica':
      params = CalculationMethod.north_america.getParameters();
      break;
    case 'Singapore':
      params = CalculationMethod.singapore.getParameters();
      break;
    case 'MuslimWorldLeague':
    default:
      params = CalculationMethod.muslim_world_league.getParameters();
      break;
  }

  if (madhab == 'Hanafi') {
    params.madhab = Madhab.hanafi;
  } else {
    params.madhab = Madhab.shafi;
  }

  final p = PrayerTimes(coordinates, dateComponents, params);

  TimeOfDay toTimeOfDay(DateTime dt) {
    final localDt = dt.toLocal();
    return TimeOfDay(hour: localDt.hour, minute: localDt.minute);
  }

  final fajrTime = p.fajr;
  final tahajjudTime = fajrTime.subtract(const Duration(hours: 2));

  return {
    'Tahajjud': toTimeOfDay(tahajjudTime),
    'Fajr': toTimeOfDay(fajrTime),
    'Dhuhr': toTimeOfDay(p.dhuhr),
    'Asr': toTimeOfDay(p.asr),
    'Maghrib': toTimeOfDay(p.maghrib),
    'Isha': toTimeOfDay(p.isha),
  };
}

Future<void> updatePrayerTimesForLocation() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('prayer_latitude') ?? 28.6139;
    final lon = prefs.getDouble('prayer_longitude') ?? 77.2090;
    final method = prefs.getString('prayer_calc_method') ?? 'Karachi';
    final madhab = prefs.getString('prayer_madhab') ?? 'Hanafi';

    final now = DateTime.now();
    final newTimes = calculateDailyPrayerTimes(
      now,
      lat,
      lon,
      method: method,
      madhab: madhab,
    );

    _prayerTimes.clear();
    _prayerTimes.addAll(newTimes);
  } catch (e) {
    debugPrint('Failed to update prayer times: $e');
  }
}

Future<void> detectLocationByIp() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('prayer_latitude')) return;

    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('http://ip-api.com/json'));
    final response = await request.close();
    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      if (data['status'] == 'success') {
        final lat = data['lat'] as double?;
        final lon = data['lon'] as double?;
        final city = data['city'] as String?;
        final country = data['country'] as String?;

        if (lat != null && lon != null) {
          await prefs.setDouble('prayer_latitude', lat);
          await prefs.setDouble('prayer_longitude', lon);
          await prefs.setString(
            'prayer_location_name',
            '${city ?? ""}, ${country ?? ""}',
          );

          String defaultMethod = 'MuslimWorldLeague';
          String defaultMadhab = 'Shafi';
          final timezone = data['timezone'] as String?;
          if (timezone != null &&
              (timezone.contains('Asia/Kolkata') ||
                  timezone.contains('Asia/Karachi') ||
                  timezone.contains('Asia/Dhaka'))) {
            defaultMethod = 'Karachi';
            defaultMadhab = 'Hanafi';
          }
          await prefs.setString('prayer_calc_method', defaultMethod);
          await prefs.setString('prayer_madhab', defaultMadhab);

          await updatePrayerTimesForLocation();
        }
      }
    }
  } catch (e) {
    debugPrint('IP Location detection failed: $e');
  }
}

int calcStreak(Map<String, DayRecord> history, int taskIndex) {
  var streak = 0;
  final today = DateTime.now();
  for (var i = 0; i < 30; i++) {
    final record = recordFor(history, today.subtract(Duration(days: i)));
    if (taskIndex < 0 ||
        taskIndex >= record.tasks.length ||
        !record.tasks[taskIndex]) {
      break;
    }
    streak++;
  }
  return streak;
}

int calcPrayerStreak(Map<String, DayRecord> history) {
  var streak = 0;
  final today = DateTime.now();
  for (var i = 0; i < 30; i++) {
    final record = recordFor(history, today.subtract(Duration(days: i)));
    final allDone = kPrayerNames.every((name) => record.prayers[name] == true);
    if (!allDone) break;
    streak++;
  }
  return streak;
}

bool isTodayWorkout(String freq) {
  const dayLabels = {
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
    DateTime.sunday: 'Sun',
  };
  final todayLabel = dayLabels[DateTime.now().weekday];
  return todayLabel != null && freq.contains(todayLabel);
}

IconData prayerIcon(String p) {
  const map = {
    'Tahajjud': Icons.auto_awesome,
    'Fajr': Icons.dark_mode,
    'Dhuhr': Icons.light_mode,
    'Asr': Icons.sunny,
    'Maghrib': Icons.wb_sunny,
    'Isha': Icons.mosque,
  };
  return map[p] ?? Icons.check_circle_outline;
}

Color prayerColor(String p, ThemeColors theme) {
  final map = {
    'Tahajjud': kPurple,
    'Fajr': theme.teal,
    'Dhuhr': theme.gold,
    'Asr': kBlue,
    'Maghrib': kRed,
    'Isha': theme.gold,
  };
  return map[p] ?? theme.gold;
}

class GlassCard extends StatelessWidget {
  const GlassCard({required this.theme, required this.child, super.key});

  final ThemeColors theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.card.withValues(
            alpha: 0.8,
          ), // Using .withValues(alpha: x)
          border: Border.all(color: theme.border),
          borderRadius: BorderRadius.circular(17),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
        ),
        child: child,
      ),
    );
  }
}

Uint8List buildPdf(List<String> lines) {
  final pages = <List<String>>[];
  for (var i = 0; i < lines.length; i += 45) {
    pages.add(lines.skip(i).take(45).toList());
  }
  if (pages.isEmpty) {
    pages.add(['No data']);
  }

  final objects = <int, String>{};
  objects[1] = '<< /Type /Catalog /Pages 2 0 R >>';
  objects[3] = '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>';

  final kids = <String>[];
  for (var i = 0; i < pages.length; i++) {
    final pageObj = 4 + (i * 2);
    final contentObj = pageObj + 1;
    kids.add('$pageObj 0 R');
    final content = _pageContent(pages[i]);
    objects[pageObj] =
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents $contentObj 0 R >>';
    objects[contentObj] =
        '<< /Length ${latin1.encode(content).length} >>\nstream\n$content\nendstream';
  }
  objects[2] =
      '<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages.length} >>';

  final ordered = objects.keys.toList()..sort();
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  var byteLength = latin1.encode(buffer.toString()).length;
  for (final id in ordered) {
    offsets.add(byteLength);
    final objectText = '$id 0 obj\n${objects[id]}\nendobj\n';
    buffer.write(objectText);
    byteLength += latin1.encode(objectText).length;
  }
  final xrefOffset = byteLength;
  buffer.write('xref\n0 ${ordered.length + 1}\n');
  buffer.write('0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write(
    'trailer\n<< /Size ${ordered.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF\n',
  );
  return Uint8List.fromList(latin1.encode(buffer.toString()));
}

String _pageContent(List<String> lines) {
  final buffer = StringBuffer('BT\n/F1 10 Tf\n40 800 Td\n14 TL\n');
  for (final line in lines) {
    buffer.write('(${_pdfEscape(line)}) Tj\nT*\n');
  }
  buffer.write('ET');
  return buffer.toString();
}

String _pdfEscape(String value) {
  return value
      .replaceAll('\\', '\\\\')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)');
}

class WorkoutDay {
  const WorkoutDay({
    required this.title,
    required this.freq,
    required this.icon,
    required this.color,
    required this.exercises,
  });

  final String title;
  final String freq;
  final IconData icon;
  final Color color;
  final List<List<String>> exercises;

  bool get isToday => isTodayWorkout(freq);
}

class WorkoutExerciseState {
  WorkoutExerciseState({
    required this.exerciseKey,
    required this.totalSets,
    required this.maxReps,
    this.currentSet = 1,
    required this.repsRemaining,
    this.awaitingNextSet = false,
    this.completed = false,
  });

  factory WorkoutExerciseState.initial(
    String exerciseKey,
    int totalSets,
    int maxReps,
  ) {
    return WorkoutExerciseState(
      exerciseKey: exerciseKey,
      totalSets: totalSets,
      maxReps: maxReps,
      currentSet: 1,
      repsRemaining: maxReps,
    );
  }

  factory WorkoutExerciseState.fromJson(Map<String, dynamic> json) {
    return WorkoutExerciseState(
      exerciseKey: json['exerciseKey'] as String,
      totalSets: (json['totalSets'] as num).toInt(),
      maxReps: (json['maxReps'] as num).toInt(),
      currentSet: (json['currentSet'] as num).toInt(),
      repsRemaining: (json['repsRemaining'] as num).toInt(),
      awaitingNextSet: json['awaitingNextSet'] == true,
      completed: json['completed'] == true,
    );
  }

  final String exerciseKey;
  final int totalSets;
  int maxReps;
  int currentSet;
  int repsRemaining;
  bool awaitingNextSet;
  bool completed;

  int get completedSets => completed ? totalSets : currentSet - 1;

  Map<String, dynamic> toJson() {
    return {
      'exerciseKey': exerciseKey,
      'totalSets': totalSets,
      'maxReps': maxReps,
      'currentSet': currentSet,
      'repsRemaining': repsRemaining,
      'awaitingNextSet': awaitingNextSet,
      'completed': completed,
    };
  }
}

/// Removes stray spaces around hyphens in exercise names.
/// e.g. 'Push - ups' → 'Push-ups', 'Archer Push - Up' → 'Archer Push-Up'
String normalizeExerciseName(String name) {
  return name.replaceAll(RegExp(r'\s*-\s*'), '-');
}

int parseSets(String description) {
  final match = RegExp(r'(\d+)\s*x').firstMatch(description);
  if (match != null) {
    return int.tryParse(match.group(1) ?? '') ?? 1;
  }
  return 1;
}

int parseReps(String description) {
  if (description.toLowerCase().contains('max')) {
    return 10;
  }
  final match = RegExp(r'x\s*([0-9]+)').firstMatch(description);
  if (match != null) {
    return int.tryParse(match.group(1) ?? '') ?? 5;
  }
  final anyNumber = RegExp(r'([0-9]+)').firstMatch(description);
  return int.tryParse(anyNumber?.group(1) ?? '') ?? 5;
}

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({
    super.key,
    required this.theme,
    required this.onWorkoutCompleted,
    required this.onWorkoutProgressChanged,
    this.onScreenshot,
    required this.userName,
    required this.onNameChanged,
    required this.userGoalYear,
    required this.userGoalMonth,
    required this.userGoalDay,
  });

  final ThemeColors theme;
  final ValueChanged<WorkoutSummary> onWorkoutCompleted;
  final ValueChanged<WorkoutProgressSnapshot> onWorkoutProgressChanged;
  final VoidCallback? onScreenshot;
  final String userName;
  final void Function(String, int, int, int) onNameChanged;
  final int userGoalYear;
  final int userGoalMonth;
  final int userGoalDay;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  static const _prefsExpandedKey = 'workout_expanded_cards';
  static const _prefsWorkoutStateKey = 'workout_state_v1';
  static const _prefsWorkoutActiveDayKey = 'workout_active_day';
  static const _prefsWorkoutActiveDateKey = 'workout_active_date';
  static const _prefsWorkoutProgressKey = 'workout_today_progress_v1';
  static const _prefsRestEndKey = 'workout_rest_end_ms';
  static const _prefsRestExerciseKey = 'workout_rest_exercise';

  List<WorkoutDay> _plan = [
    WorkoutDay(
      title: 'Upper Body',
      freq: 'Mon / Wed / Sat',
      icon: Icons.fitness_center,
      color: Colors.teal,
      exercises: [
        ['Push-ups', '3 x 5 reps', 'Chest'],
        ['Incline Push-ups', '3 x 5 reps', 'Incline'],
        ['Pike Push-ups', '3 x 5 reps', 'Shoulders'],
        ['Door Rows', '3 x 5 reps', 'Back'],
        ['Arm Circles', '3 x 5 reps', 'Shoulders'],
        ['Plank Hold', '3 x 30 sec', 'Core'],
      ],
    ),
    WorkoutDay(
      title: 'Lower Body',
      freq: 'Tue / Thu / Fri',
      icon: Icons.directions_run,
      color: Colors.teal,
      exercises: [
        ['Bodyweight Squats', '3 x 5 reps', 'Full depth'],
        ['Jump Squats', '3 x 5 reps', 'Explosive'],
        ['Lunges', '3 x 5 reps', 'Each leg'],
        ['Glute Bridges', '3 x 5 reps', 'Posterior chain'],
        ['Calf Raises', '3 x 5 reps', 'Calves'],
        ['Leg Raises', '3 x 5 reps', 'Lower abs'],
      ],
    ),
  ];

  final Map<String, WorkoutExerciseState> _exerciseStates = {};
  final Map<String, bool> _expandedCards = {};
  final ScrollController _scrollController = ScrollController();
  final List<List<String>> _libraryExercises = const [
    ['Lying Leg Curls', '3 x 5 reps', 'Hamstrings'],
    ['Leg Extensions', '3 x 5 reps', 'Quads'],
    ['Dumbbell Lunges', '3 x 5 reps', 'Legs & Glutes'],
    ['Lat Pulldown', '3 x 5 reps', 'Back & Biceps'],
    ['Cable Crossover', '3 x 5 reps', 'Chest & Shoulders'],
    ['Dumbbell Shrugs', '3 x 5 reps', 'Shoulders & Neck'],
  ];
  SharedPreferences? _prefs;
  String? _activeDayTitle;
  String? _activeWorkoutDateKey;
  Timer? _restTimer;
  int _restSeconds = 0;
  int _completedExercises = 0;
  double _setProgress = 0.0;
  bool _isResting = false;
  String? _restExerciseKey;

  // New Workout Screen state variables
  late WorkoutDay _selectedSplit = _plan.first;
  bool _showRepCounter = false;
  WorkoutExerciseState? _activeExerciseState;
  String? _activeExerciseName;
  int _repsRemaining = 0;
  bool _showEditRepsModal = false;
  final TextEditingController _editExerciseNameController = TextEditingController();
  final TextEditingController _editWorkoutTitleController = TextEditingController();
  final TextEditingController _editRepsController = TextEditingController();
  final TextEditingController _editSetsController = TextEditingController();
  int _exerciseTab = 0; // 0 = My Routine, 1 = Exercise Library

  // State variables for Duolingo & Brilliant upgrades
  bool _showExerciseCompleteOverlay = false;
  bool _showWorkoutCompleteOverlay = false;
  bool _isCelebrating = false;
  DateTime? _workoutStartTime;
  bool _showRpeOverlay = false;
  int? _selectedRpe;
  bool _isPaused = false;
  bool _voiceCuesEnabled = true;
  double _skipHoldProgress = 0.0;
  Timer? _skipHoldTimer;
  int _comboCount = 1;
  DateTime? _lastTapTime;
  Timer? _comboResetTimer;
  final List<DateTime> _recentTapTimes = [];
  int _tapCountForEstimate = 0;
  String _timeEstimate = "~5 min left";
  String _motivationalPhrase = "Keep pushing";

  static const _phrases = [
    "Keep pushing",
    "You're doing great",
    "Almost there",
    "Stay focused",
    "Strong mind, strong body",
  ];

  void _selectNewPhrase() {
    final rand = math.Random();
    _motivationalPhrase = _phrases[rand.nextInt(_phrases.length)];
  }

  int get _currentExerciseIndex {
    if (_activeExerciseName == null) return 1;
    final idx = _selectedSplit.exercises.indexWhere(
      (e) => e[0] == _activeExerciseName,
    );
    return idx != -1 ? idx + 1 : 1;
  }

  int get totalRepsDone {
    return _selectedSplit.exercises.fold<int>(0, (sum, exercise) {
      final key = '${_selectedSplit.title}|${exercise[0]}';
      final state = _exerciseStates[key];
      if (state == null) return sum;
      return sum + (state.completedSets * state.maxReps);
    });
  }

  int get minutesSpent {
    if (_workoutStartTime == null) return 12;
    final diff = DateTime.now().difference(_workoutStartTime!).inMinutes;
    return max(1, diff);
  }

  String _calculateTimeEstimate() {
    if (_recentTapTimes.length < 2) return '~5 min left';
    double totalMs = 0;
    int count = 0;
    for (int i = 1; i < _recentTapTimes.length; i++) {
      totalMs += _recentTapTimes[i]
          .difference(_recentTapTimes[i - 1])
          .inMilliseconds;
      count++;
    }
    double avgMsPerRep = totalMs / count;
    if (avgMsPerRep > 3000) avgMsPerRep = 3000;

    final state = _activeExerciseState;
    if (state == null) return '~5 min left';

    int remainingRepsInCurrentSet = _repsRemaining;
    int remainingSetsInCurrentExercise = state.totalSets - state.currentSet;
    int totalRepsInCurrentExercise =
        remainingRepsInCurrentSet +
        (remainingSetsInCurrentExercise * state.maxReps);

    int totalRepsInOtherExercises = 0;
    final currentIndex = _selectedSplit.exercises.indexWhere(
      (e) => e[0] == _activeExerciseName,
    );
    if (currentIndex != -1) {
      for (int i = currentIndex + 1; i < _selectedSplit.exercises.length; i++) {
        final ex = _selectedSplit.exercises[i];
        final key = '${_selectedSplit.title}|${ex[0]}';
        final st = _exerciseStates[key];
        if (st != null && !st.completed) {
          totalRepsInOtherExercises += st.totalSets * st.maxReps;
        }
      }
    }

    int totalRemainingReps =
        totalRepsInCurrentExercise + totalRepsInOtherExercises;
    double totalEstimatedMs = avgMsPerRep * totalRemainingReps;
    double totalMinutes = totalEstimatedMs / (1000 * 60);

    return '~${max(1, totalMinutes.round())} min left';
  }

  // Streak & Weight state
  bool _isEditingBodyWeight = false;
  int _bodyWeight = 68;
  final TextEditingController _bodyWeightController = TextEditingController(
    text: '68',
  );
  final FocusNode _bodyWeightFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _bodyWeightFocusNode.addListener(() {
      if (!_bodyWeightFocusNode.hasFocus) {
        _saveBodyWeight();
      }
    });
    for (final day in _plan) {
      _expandedCards[day.title] = day.isToday;
    }
    _loadPreferences();
  }

  void _recalculateStats() {
    if (!mounted) return;
    final activeSplit = _selectedSplit;
    _completedExercises = _dayCompletedExercises(activeSplit);

    // Progress ring matches completed exercises count
    final totalCount = activeSplit.exercises.length;
    _setProgress = totalCount == 0 ? 0.0 : _completedExercises / totalCount;

    _buttonLabel = _completedExercises == activeSplit.exercises.length
        ? 'Workout complete'
        : _hasProgress(activeSplit)
        ? 'Resume workout'
        : "Start today's workout";

    setState(() {});
  }

  String _buttonLabel = "Start today's workout";

  @override
  void dispose() {
    _restTimer?.cancel();
    _scrollController.dispose();
    _bodyWeightFocusNode.dispose();
    _bodyWeightController.dispose();
    _editRepsController.dispose();
    super.dispose();
  }

  void _startBodyWeightEdit() {
    setState(() {
      _bodyWeightController.text = '$_bodyWeight';
      _isEditingBodyWeight = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _bodyWeightFocusNode.requestFocus();
        _bodyWeightController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _bodyWeightController.text.length,
        );
      }
    });
  }

  void _saveBodyWeight() async {
    final next = int.tryParse(_bodyWeightController.text.trim());
    if (!mounted) return;
    setState(() {
      if (next != null && next > 0) {
        _bodyWeight = next;
      }
      _bodyWeightController.text = '$_bodyWeight';
      _isEditingBodyWeight = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('workout_body_weight', _bodyWeight);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final expanded = _decodeBoolMap(prefs.getString(_prefsExpandedKey));
    final loadedWeight = prefs.getInt('workout_body_weight') ?? 68;
    var activeDayTitle = prefs.getString(_prefsWorkoutActiveDayKey);
    var activeWorkoutDateKey = prefs.getString(_prefsWorkoutActiveDateKey);
    var loadedStates = _decodeWorkoutState(
      prefs.getString(_prefsWorkoutStateKey),
    );
    var restEndMillis = prefs.getInt(_prefsRestEndKey);
    var restExerciseKey = prefs.getString(_prefsRestExerciseKey);
    final todayKey = dayKey(DateTime.now());
    String? savedProgressDateKey;
    final savedProgressRaw = prefs.getString(_prefsWorkoutProgressKey);
    if (savedProgressRaw != null && savedProgressRaw.isNotEmpty) {
      try {
        savedProgressDateKey = WorkoutProgressSnapshot.fromJson(
          jsonDecode(savedProgressRaw) as Map<String, dynamic>,
        ).dateKey;
      } catch (_) {}
    }
    final hasTodayWorkoutState =
        activeWorkoutDateKey == todayKey || savedProgressDateKey == todayKey;
    if (!hasTodayWorkoutState) {
      activeDayTitle = null;
      activeWorkoutDateKey = null;
      loadedStates = {};
      restEndMillis = null;
      restExerciseKey = null;
      await prefs.remove(_prefsWorkoutActiveDayKey);
      await prefs.remove(_prefsWorkoutActiveDateKey);
      await prefs.remove(_prefsWorkoutStateKey);
      await prefs.remove(_prefsWorkoutProgressKey);
      await prefs.remove(_prefsRestEndKey);
      await prefs.remove(_prefsRestExerciseKey);
    }

    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _expandedCards
        ..clear()
        ..addAll(expanded);
      _activeDayTitle = activeDayTitle;
      _activeWorkoutDateKey = activeWorkoutDateKey;
      _bodyWeight = loadedWeight;
      _bodyWeightController.text = '$loadedWeight';
      _exerciseStates
        ..clear()
        ..addAll(loadedStates);
      for (final day in _plan) {
        _expandedCards.putIfAbsent(day.title, () => day.isToday);
        for (final exercise in day.exercises) {
          final key = '${day.title}|${exercise[0]}';
          _exerciseStates.putIfAbsent(
            key,
            () => WorkoutExerciseState.initial(
              key,
              parseSets(exercise[1]),
              parseReps(exercise[1]),
            ),
          );
        }
      }
      for (final exercise in _libraryExercises) {
        final key = 'lib|${exercise[0]}';
        _exerciseStates.putIfAbsent(
          key,
          () => WorkoutExerciseState.initial(
            key,
            parseSets(exercise[1]),
            parseReps(exercise[1]),
          ),
        );
      }

      // Default to show split assigned to today's workout
      final todaySplit = _todayWorkoutDay() ?? _plan.first;
      if (activeDayTitle != null) {
        _selectedSplit = _plan.firstWhere(
          (d) => d.title == activeDayTitle,
          orElse: () => todaySplit,
        );
      } else {
        _selectedSplit = todaySplit;
      }

      if (restEndMillis != null && restExerciseKey != null) {
        final remaining = DateTime.fromMillisecondsSinceEpoch(
          restEndMillis,
        ).difference(DateTime.now()).inSeconds;
        if (remaining > 0) {
          _restSeconds = remaining;
          _restExerciseKey = restExerciseKey;
          _isResting = true;
          _startRestTimer();
        } else {
          _isResting = false;
          _restExerciseKey = null;
          _restSeconds = 0;
          prefs.remove(_prefsRestEndKey);
          prefs.remove(_prefsRestExerciseKey);
        }
      }
      _recalculateStats();
    });
  }

  Map<String, bool> _decodeBoolMap(String? raw) {
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = json.decode(raw);
    if (decoded is Map<Object?, Object?>) {
      return decoded.map((key, value) {
        final keyStr = key is String ? key : key.toString();
        return MapEntry(keyStr, value == true);
      });
    }
    return {};
  }

  Map<String, WorkoutExerciseState> _decodeWorkoutState(String? raw) {
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = json.decode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded.map((key, value) {
        if (value is Map<String, dynamic>) {
          return MapEntry(key, WorkoutExerciseState.fromJson(value));
        }
        return MapEntry(key, WorkoutExerciseState.initial(key, 1, 1));
      });
    }
    return {};
  }

  Future<void> _savePreferences() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    if (!mounted) return;
    _prefs = prefs;
    await prefs.setString(
      _prefsWorkoutStateKey,
      json.encode(
        _exerciseStates.map((key, value) => MapEntry(key, value.toJson())),
      ),
    );
    if (!mounted) return;
    await prefs.setString(_prefsExpandedKey, json.encode(_expandedCards));
    if (!mounted) return;
    if (_activeDayTitle != null) {
      await prefs.setString(_prefsWorkoutActiveDayKey, _activeDayTitle!);
      if (!mounted) return;
    } else {
      await prefs.remove(_prefsWorkoutActiveDayKey);
    }
    if (_activeWorkoutDateKey != null) {
      await prefs.setString(_prefsWorkoutActiveDateKey, _activeWorkoutDateKey!);
    } else {
      await prefs.remove(_prefsWorkoutActiveDateKey);
    }
    if (_isResting && _restExerciseKey != null) {
      final endTime = DateTime.now().add(Duration(seconds: _restSeconds));
      await prefs.setInt(_prefsRestEndKey, endTime.millisecondsSinceEpoch);
      await prefs.setString(_prefsRestExerciseKey, _restExerciseKey!);
    } else {
      await prefs.remove(_prefsRestEndKey);
      await prefs.remove(_prefsRestExerciseKey);
    }
  }

  Future<void> _saveWorkoutProgress(
    WorkoutDay day, {
    bool completed = false,
    String? dateKeyOverride,
  }) async {
    final snapshot = WorkoutProgressSnapshot(
      workoutName: day.title,
      exercisesCompleted: _dayCompletedExercises(day),
      totalExercises: day.exercises.length,
      setsCompleted: _dayCompletedSets(day),
      totalSets: _dayTotalSets(day),
      completed: completed,
      inProgress: !completed && _hasProgress(day),
      dateKey:
          dateKeyOverride ?? _activeWorkoutDateKey ?? dayKey(DateTime.now()),
    );
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    if (!mounted) return;
    _prefs = prefs;
    await prefs.setString(
      _prefsWorkoutProgressKey,
      jsonEncode(snapshot.toJson()),
    );
    if (!mounted) return;
    widget.onWorkoutProgressChanged(snapshot);
  }

  int _dayCompletedSets(WorkoutDay day) {
    return day.exercises.fold(0, (sum, exercise) {
      final key = '${day.title}|${exercise[0]}';
      final state = _exerciseStates[key];
      return sum + (state?.completedSets ?? 0);
    });
  }

  int _dayTotalSets(WorkoutDay day) {
    return day.exercises.fold(0, (sum, exercise) {
      final key = '${day.title}|${exercise[0]}';
      final state = _exerciseStates[key];
      return sum + (state?.totalSets ?? parseSets(exercise[1]));
    });
  }

  int _dayCompletedExercises(WorkoutDay day) {
    return day.exercises.where((exercise) {
      final key = '${day.title}|${exercise[0]}';
      return _exerciseStates[key]?.completed ?? false;
    }).length;
  }

  bool _hasProgress(WorkoutDay day) {
    return day.exercises.any((exercise) {
      final key = '${day.title}|${exercise[0]}';
      final state = _exerciseStates[key];
      return state != null &&
          (state.completed ||
              state.currentSet > 1 ||
              state.repsRemaining < state.maxReps ||
              state.awaitingNextSet);
    });
  }

  void _toggleExercise(String key) {
    final state = _exerciseStates[key];
    if (state == null) return;
    if (!mounted) return;
    setState(() {
      state.completed = !state.completed;
      if (state.completed) {
        state.currentSet = state.totalSets;
        state.repsRemaining = 0;
        state.awaitingNextSet = false;
      } else {
        state.currentSet = 1;
        state.repsRemaining = state.maxReps;
        state.awaitingNextSet = false;
      }
      _recalculateStats();
    });
    _savePreferences();
    final day = _plan.firstWhere(
      (day) =>
          day.exercises.any((exercise) => '${day.title}|${exercise[0]}' == key),
      orElse: () => _todayWorkoutDay() ?? _plan.first,
    );
    _saveWorkoutProgress(
      day,
      completed: _dayCompletedExercises(day) == day.exercises.length,
    );
    _maybeCompleteWorkout();
  }

  void _toggleCard(String title) {
    if (!mounted) return;
    setState(() {
      _expandedCards[title] = !(_expandedCards[title] ?? false);
    });
    _savePreferences();
  }

  WorkoutDay? _todayWorkoutDay() {
    for (final day in _plan) {
      if (day.isToday) {
        return day;
      }
    }
    return null;
  }

  void _startTodayWorkout() {
    _workoutStartTime = DateTime.now();
    final today = _selectedSplit;
    if (!(_expandedCards[today.title] ?? false)) {
      _toggleCard(today.title);
    }
    setState(() {
      _activeDayTitle = today.title;
      _activeWorkoutDateKey ??= dayKey(DateTime.now());
    });
    _savePreferences();
    _saveWorkoutProgress(today);

    // Find first undone exercise and open rep counter
    final undoneExercise = today.exercises.firstWhere((e) {
      final key = '${today.title}|${e[0]}';
      return _exerciseStates[key]?.completed != true;
    }, orElse: () => []);
    if (undoneExercise.isNotEmpty) {
      final key = '${today.title}|${undoneExercise[0]}';
      final state = _exerciseStates[key];
      if (state != null) {
        setState(() {
          _activeExerciseState = state;
          _activeExerciseName = undoneExercise[0];
          _repsRemaining = state.repsRemaining;
          if (_repsRemaining <= 0) {
            _repsRemaining = state.maxReps;
          }
          _showRepCounter = true;
        });
        _MainScreenState.hideBottomNavNotifier.value = true;
      }
    }
  }

  void _startRestTimer() {
    HapticService.medium();
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final nextSeconds = max(0, _restSeconds - 1);
      if (nextSeconds != _restSeconds) {
        setState(() => _restSeconds = nextSeconds);
      }
      if (nextSeconds == 0) {
        timer.cancel();
        if (mounted) {
          _completeRest();
        }
      }
    });
  }

  void _completeRest() {
    _restTimer?.cancel();
    HapticService.restTimerEnd();
    AudioService.playRestTimerEnd();
    _clearRest();
  }

  void _skipRest() {
    _restTimer?.cancel();
    _completeRest();
  }

  void _clearRest() {
    if (!mounted) return;
    setState(() {
      _isResting = false;
      _restExerciseKey = null;
      _restSeconds = 0;
    });
    _prefs?.remove(_prefsRestEndKey);
    _prefs?.remove(_prefsRestExerciseKey);
    _savePreferences();
  }

  void _maybeCompleteWorkout() {
    final today = _selectedSplit;
    final allCompleted = today.exercises.every((exercise) {
      final key = '${today.title}|${exercise[0]}';
      return _exerciseStates[key]?.completed == true;
    });
    if (!allCompleted) {
      return;
    }
    final setsCompleted = today.exercises.fold<int>(0, (sum, exercise) {
      final key = '${today.title}|${exercise[0]}';
      return sum + (_exerciseStates[key]?.totalSets ?? 0);
    });
    final summary = WorkoutSummary(
      workoutName: today.title,
      exercisesCompleted: today.exercises.length,
      totalExercises: today.exercises.length,
      setsCompleted: setsCompleted,
      totalSets: setsCompleted,
      setsPerExercise: {
        for (final exercise in today.exercises)
          exercise[0]:
              _exerciseStates['${today.title}|${exercise[0]}']?.totalSets ?? 0,
      },
    );
    final completionDateKey = _activeWorkoutDateKey ?? dayKey(DateTime.now());
    final completedToday = completionDateKey == dayKey(DateTime.now());

    // We defer clearing activeDayTitle and activeWorkoutDateKey to continue button on overlay
    _savePreferences();
    _saveWorkoutProgress(
      today,
      completed: true,
      dateKeyOverride: completionDateKey,
    );
    if (completedToday) {
      widget.onWorkoutCompleted(summary);
      SoundManager.playWorkoutComplete();
      HapticService.workoutComplete();
    }

    setState(() {
      _showWorkoutCompleteOverlay = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildWorkoutContent(context);
    } catch (error, stackTrace) {
      debugPrint('WorkoutScreen build failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return SafeArea(
        child: Center(
          child: Text(
            'Workout is reloading...',
            style: TextStyle(color: widget.theme.text3),
          ),
        ),
      );
    }
  }

  Widget _buildSessionHeroCard(ThemeColors theme) {
    final exercisesCount = _selectedSplit.exercises.length;
    final firstEx = _selectedSplit.exercises.first;
    final sets = parseSets(firstEx[1]);
    final reps = parseReps(firstEx[1]);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.isDark
                ? const Color(0xFF1C1C1E).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.white.withOpacity(0.9),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.isDark
                    ? Colors.black.withOpacity(0.35)
                    : const Color(0xFF3C321E).withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Apple Fitness+ Segmented Step Indicator
              Row(
                children: List.generate(exercisesCount, (idx) {
                  final ex = _selectedSplit.exercises[idx];
                  final k = '${_selectedSplit.title}|${ex[0]}';
                  final isDone = _exerciseStates[k]?.completed == true;
                  final isCurrent = idx == 0 && !isDone;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: idx < exercisesCount - 1 ? 5 : 0),
                      decoration: BoxDecoration(
                        color: isDone
                            ? (theme.isDark ? const Color(0xFF2DD4A8) : const Color(0xFF0D9488))
                            : (isCurrent
                                ? (theme.isDark ? const Color(0xFF2DD4A8).withValues(alpha: 0.5) : const Color(0xFF0D9488).withValues(alpha: 0.5))
                                : (theme.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06))),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // The Session Focus Title
              Text(
                _selectedSplit.title,
                style: AppFonts.display(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.text1,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$exercisesCount Exercises · Est. 25 min · Bodyweight',
                style: AppFonts.text(
                  fontSize: 13.5,
                  color: theme.isDark ? const Color(0xFFA0A0B5) : const Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),

              // Single Primary Action Button
              GestureDetector(
                onTap: _startTodayWorkout,
                child: Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.isDark ? const Color(0xFF2DD4A8) : const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (theme.isDark ? const Color(0xFF2DD4A8) : const Color(0xFF0D9488)).withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: theme.isDark ? Colors.black : Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Start Workout',
                        style: AppFonts.display(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineConfirmationBar(ThemeColors theme) {
    final otherSplit = _selectedSplit.title == _plan[0].title ? _plan[1] : _plan[0];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: theme.isDark ? const Color(0xFF2DD4A8) : const Color(0xFF0D9488),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedSplit.title} · Bodyweight',
                style: AppFonts.text(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.text1,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              HapticService.tapFeedback();
              SoundManager.playTapClick();
              setState(() {
                _selectedSplit = otherSplit;
                _recalculateStats();
              });
            },
            child: Text(
              'Tomorrow: ${otherSplit.title} ›',
              style: AppFonts.text(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.isDark ? const Color(0xFF8B8B9A) : const Color(0xFF6B6560),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutContent(BuildContext context) {
    final theme = widget.theme;
    final todayCompleted = _dayCompletedExercises(_selectedSplit) == _selectedSplit.exercises.length;
    final currentStreak = todayCompleted ? 1 : 0;
    final exercisesCount = _selectedSplit.exercises.length;

    return SafeArea(
      child: Stack(
        children: [
          // Atmosphere Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.4),
                  radius: 0.8,
                  colors: theme.isDark
                      ? [
                          const Color(0xFF12122A),
                          const Color(0xFF0B0B14),
                        ]
                      : [
                          const Color(0xFFF5F2EB),
                          const Color(0xFFE8E4DB),
                        ],
                ),
              ),
            ),
          ),

          // Main screen view
          AnimatedPositioned(
            duration: Duration(milliseconds: _showRepCounter ? 450 : 350),
            curve: _showRepCounter ? Curves.easeOutCubic : Curves.easeInCubic,
            left: _showRepCounter
                ? -MediaQuery.of(context).size.width * 0.3
                : 0,
            right: _showRepCounter
                ? MediaQuery.of(context).size.width * 0.3
                : 0,
            top: 0,
            bottom: 0,
            child: AnimatedScale(
              scale: _showRepCounter ? 0.95 : 1.0,
              duration: Duration(milliseconds: _showRepCounter ? 450 : 350),
              curve: _showRepCounter ? Curves.easeOutCubic : Curves.easeInCubic,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: _showRepCounter ? 450 : 350),
                curve: _showRepCounter ? Curves.easeOutCubic : Curves.easeInCubic,
                opacity: _showRepCounter ? 0.3 : 1.0,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. HEADER BAR
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TRAINING',
                                  style: AppFonts.text(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.08,
                                    color: theme.isDark ? const Color(0xFF8B8B9A) : const Color(0xFF6B6560),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _weekdayName(DateTime.now()),
                                  style: AppFonts.text(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                    color: theme.isDark ? const Color(0xFFE8E8F0) : const Color(0xFF1C1914),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_selectedSplit.title} · $exercisesCount Exercises · ~25 Min',
                                  style: AppFonts.text(
                                    fontSize: 15,
                                    color: theme.isDark ? const Color(0xFF8B8B9A) : const Color(0xFF6B6560),
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -0.24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 2. SESSION HERO CARD
                      _buildSessionHeroCard(theme),
                      const SizedBox(height: 14),

                      // 3. ROUTINE CONFIRMATION BAR
                      _buildRoutineConfirmationBar(theme),
                      const SizedBox(height: 10),

                      // EXERCISE LIST
                      KeyedSubtree(
                        key: ValueKey(_selectedSplit.title),
                        child: Column(
                          children: List.generate(_selectedSplit.exercises.length, (index) {
                            final exercise = _selectedSplit.exercises[index];
                            final key = '${_selectedSplit.title}|${exercise[0]}';
                            final state = _exerciseStates[key];
                            final completed = state?.completed == true;
                            final sets = parseSets(exercise[1]);
                            final reps = state != null ? state.maxReps : parseReps(exercise[1]);
                            final muscle = exercise.length > 2 ? exercise[2] : '';
                            return _ScrollRevealWidget(
                              index: index,
                              scrollController: _scrollController,
                              child: ExerciseLogRowWidget(
                                index: index,
                                theme: theme,
                                exercise: exercise,
                                isLibrary: false,
                                completed: completed,
                                sets: sets,
                                reps: reps,
                                muscle: muscle,
                                onToggle: () => _toggleExercise(key),
                                onTapReps: () {
                                  if (state != null) {
                                    setState(() {
                                      _selectNewPhrase();
                                      _activeExerciseState = state;
                                      _activeExerciseName = exercise[0];
                                      _repsRemaining = state.repsRemaining;
                                      if (_repsRemaining <= 0) {
                                        _repsRemaining = state.maxReps;
                                      }
                                      _showRepCounter = true;
                                    });
                                    _MainScreenState.hideBottomNavNotifier.value = true;
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 6. REP COUNTER OVERLAY (slides in from right with parallax scale)
          AnimatedPositioned(
            duration: Duration(milliseconds: _showRepCounter ? 450 : 350),
            curve: _showRepCounter ? Curves.easeOutCubic : Curves.easeInCubic,
            left: _showRepCounter ? 0 : MediaQuery.of(context).size.width,
            right: _showRepCounter ? 0 : -MediaQuery.of(context).size.width,
            top: 0,
            bottom: 0,
            child: AnimatedScale(
              scale: _showRepCounter ? 1.0 : 0.98,
              duration: Duration(milliseconds: _showRepCounter ? 450 : 350),
              curve: _showRepCounter ? Curves.easeOutCubic : Curves.easeInCubic,
              child: AnimatedOpacity(
                opacity: _showRepCounter ? 1.0 : 0.0,
                duration: Duration(milliseconds: _showRepCounter ? 450 : 350),
                curve: _showRepCounter
                    ? Curves.easeOutCubic
                    : Curves.easeInCubic,
                child: _buildRepCounterOverlay(theme),
              ),
            ),
          ),

          // 8. REST TIMER OVERLAY
          if (_isResting) Positioned.fill(child: _buildRestTimerOverlay(theme)),

          // 7. EDIT REPS MODAL
          if (_showEditRepsModal)
            Positioned.fill(child: _buildEditRepsModal(theme)),

          // EXERCISE COMPLETE OVERLAY
          if (_showExerciseCompleteOverlay)
            Positioned.fill(
              child: _ExerciseCompleteOverlay(
                exerciseName: _activeExerciseName ?? '',
                theme: theme,
                onFinished: () {
                  setState(() {
                    _showExerciseCompleteOverlay = false;
                    _showRepCounter = false;
                  });
                },
              ),
            ),

          // WORKOUT COMPLETE OVERLAY
          if (_showWorkoutCompleteOverlay)
            Positioned.fill(
              child: _WorkoutCompleteOverlay(
                theme: theme,
                exercisesCompleted: _selectedSplit.exercises.length,
                totalReps: totalRepsDone,
                minutesSpent: minutesSpent,
                onContinue: () {
                  setState(() {
                    _showWorkoutCompleteOverlay = false;
                    _activeDayTitle = null;
                    _activeWorkoutDateKey = null;
                    _recalculateStats();
                  });
                  _savePreferences();
                },
                onDismiss: () {
                  setState(() {
                    _showWorkoutCompleteOverlay = false;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  String _weekdayName(DateTime date) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[date.weekday - 1];
  }

  Widget _workoutStatsGrid(ThemeColors theme, Color workoutPrimary) {
    final todayCompleted =
        _dayCompletedExercises(_selectedSplit) ==
        _selectedSplit.exercises.length;
    final currentStreak = todayCompleted ? 1 : 0;
    final monthSessions = todayCompleted ? 1 : 0;
    final hoursThisWeek = (_dayCompletedSets(_selectedSplit) * 0.18).clamp(
      0.0,
      9.9,
    );

    return Row(
      children: [
        // Streak Card (flex 2, visually dominant, hero)
        Expanded(
          flex: 2,
          child: _StatCardWidget(
            theme: theme,
            backgroundGradient: LinearGradient(
              colors: [
                const Color(0xFFE8B84B).withValues(alpha: 0.05),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (currentStreak > 0)
                          _StreakFireIcon(isActive: true)
                        else
                          const Icon(
                            Icons.bolt_rounded,
                            size: 16,
                            color: Color(0xFFE8B84B),
                          ),
                        const SizedBox(width: 4),
                        _animatedValueText(
                          currentStreak > 0
                              ? '$currentStreak Day Streak'
                              : 'Ready to Start',
                          const Color(0xFFE8B84B),
                          currentStreak > 0 ? 15 : 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      currentStreak > 0 ? 'Daily Momentum' : '1st Session Ahead',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.text3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Sessions Card (flex 1)
        Expanded(
          flex: 1,
          child: _StatCardWidget(
            theme: theme,
            backgroundGradient: LinearGradient(
              colors: [
                const Color(0xFF00C896).withValues(alpha: 0.05),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.fitness_center_rounded,
                          size: 14,
                          color: Color(0xFF00C896),
                        ),
                        const SizedBox(width: 4),
                        _animatedValueText(
                          monthSessions > 0 ? '$monthSessions' : '1 Planned',
                          const Color(0xFF00C896),
                          monthSessions > 0 ? 15 : 11,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Session 1 of 1',
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.text3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Weight Card (flex 1, data only)
        Expanded(
          flex: 1,
          child: _StatCardWidget(
            theme: theme,
            onTap: _startBodyWeightEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_isEditingBodyWeight)
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 42,
                              child: TextField(
                                controller: _bodyWeightController,
                                focusNode: _bodyWeightFocusNode,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: theme.text1,
                                  fontWeight: FontWeight.w800,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => _saveBodyWeight(),
                              ),
                            ),
                            Text(
                              'kg',
                              style: TextStyle(
                                fontSize: 18,
                                color: theme.text1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _animatedValueText(
                          '${_bodyWeight}kg',
                          theme.text1,
                          18,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'BW (Current)',
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.text3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Hours Card (flex 1)
        Expanded(
          flex: 1,
          child: _StatCardWidget(
            theme: theme,
            backgroundGradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.02),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, size: 14, color: theme.text2),
                        const SizedBox(width: 4),
                        _animatedValueText(
                          hoursThisWeek > 0
                              ? hoursThisWeek.toStringAsFixed(1)
                              : '~25m',
                          theme.text1,
                          15,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      hoursThisWeek > 0 ? 'Hours' : 'Est. Time',
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.text3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _splitSelector(ThemeColors theme) {
    final otherSplit = _selectedSplit.title == _plan[0].title ? _plan[1] : _plan[0];
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00C896),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Today: ${_selectedSplit.title}',
                style: AppFonts.text(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.text1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· Bodyweight',
                style: AppFonts.text(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: theme.text3,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              HapticService.tapFeedback();
              SoundManager.playTapClick();
              setState(() {
                _selectedSplit = otherSplit;
                _recalculateStats();
              });
            },
            child: Text(
              'Switch to ${otherSplit.title} →',
              style: AppFonts.text(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinearProgress(ThemeColors theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Today's session",
              style: AppFonts.text(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.text1,
              ),
            ),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: _setProgress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final percent = (value * 100).round();
                  return Text(
                    percent == 0
                        ? 'Ready · ${_selectedSplit.exercises.length} exercises (~25m)'
                        : '$percent% · $_completedExercises/${_selectedSplit.exercises.length} exercises',
                    style: AppFonts.text(
                      fontSize: 12,
                      color: percent == 0
                          ? const Color(0xFF00C896)
                          : theme.text2,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ShimmeringProgressBar(value: _setProgress, theme: theme),
      ],
    );
  }

  Widget _buildStartButton(ThemeColors theme) {
    final isDisabled = _completedExercises == _selectedSplit.exercises.length;
    return GestureDetector(
      onTap: isDisabled ? null : _startTodayWorkout,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                theme.teal,
                const Color(0xFF25A35A), // Accent dark
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.teal.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Start Workout',
                style: AppFonts.text(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exerciseLogSection(
    ThemeColors theme,
    WorkoutDay selectedSplit,
    Color workoutPrimary,
    Color cardBorder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Segmented Tab Toggle (My Routine vs Library)
        Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticService.tapFeedback();
                    setState(() => _exerciseTab = 0);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _exerciseTab == 0
                          ? theme.teal
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'MY ROUTINE (${selectedSplit.exercises.length})',
                      style: AppFonts.text(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: _exerciseTab == 0 ? Colors.white : theme.text3,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticService.tapFeedback();
                    setState(() => _exerciseTab = 1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _exerciseTab == 1
                          ? const Color(0xFFE67E22)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'LIBRARY (24)',
                      style: AppFonts.text(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: _exerciseTab == 1 ? Colors.white : theme.text3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_exerciseTab == 0) ...[
          // Section 1: MY ROUTINE
          ...Iterable.generate(selectedSplit.exercises.length).map((index) {
            final exercise = selectedSplit.exercises[index];
            final key = '${selectedSplit.title}|${exercise[0]}';
            final state = _exerciseStates[key];
            final completed = state?.completed == true;
            final sets = parseSets(exercise[1]);
            final reps = state != null ? state.maxReps : parseReps(exercise[1]);
            final muscle = exercise.length > 2 ? exercise[2] : '';
            return _ScrollRevealWidget(
              index: index,
              scrollController: _scrollController,
              child: ExerciseLogRowWidget(
                index: index,
                theme: theme,
                exercise: exercise,
                isLibrary: false,
                completed: completed,
                sets: sets,
                reps: reps,
                muscle: muscle,
                onToggle: () => _toggleExercise(key),
                onTapReps: () {
                  if (state != null) {
                    setState(() {
                      _selectNewPhrase();
                      _activeExerciseState = state;
                      _activeExerciseName = exercise[0];
                      _repsRemaining = state.repsRemaining;
                      if (_repsRemaining <= 0) {
                        _repsRemaining = state.maxReps;
                      }
                      _showRepCounter = true;
                    });
                    _MainScreenState.hideBottomNavNotifier.value = true;
                  }
                },
              ),
            );
          }),
        ] else ...[
          // Section 2: EXERCISE LIBRARY
          ...Iterable.generate(_libraryExercises.length).map((index) {
            final exercise = _libraryExercises[index];
            final key = 'lib|${exercise[0]}';
            final state = _exerciseStates[key];
            final completed = state?.completed == true;
            final sets = parseSets(exercise[1]);
            final reps = state != null ? state.maxReps : parseReps(exercise[1]);
            final muscle = exercise.length > 2 ? exercise[2] : '';
            return _ScrollRevealWidget(
              index: index + selectedSplit.exercises.length,
              scrollController: _scrollController,
              child: ExerciseLogRowWidget(
                index: index,
                theme: theme,
                exercise: exercise,
                isLibrary: true,
                completed: completed,
                sets: sets,
                reps: reps,
                muscle: muscle,
                onToggle: () => _toggleExercise(key),
                onTapReps: () {
                  if (state != null) {
                    setState(() {
                      _selectNewPhrase();
                      _activeExerciseState = state;
                      _activeExerciseName = exercise[0];
                      _repsRemaining = state.repsRemaining;
                      if (_repsRemaining <= 0) {
                        _repsRemaining = state.maxReps;
                      }
                      _showRepCounter = true;
                    });
                    _MainScreenState.hideBottomNavNotifier.value = true;
                  }
                },
              ),
            );
          }),
        ],
      ],
    );
  }

  String _getTargetMuscleLabel(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('push-up') || lower.contains('push up')) {
      return 'CHEST & TRICEPS';
    }
    if (lower.contains('squat')) return 'QUADS & GLUTES';
    if (lower.contains('lunge')) return 'QUADS & HAMSTRINGS';
    if (lower.contains('bridge')) return 'GLUTES & HAMSTRINGS';
    if (lower.contains('raise')) {
      if (lower.contains('calf')) return 'CALVES';
      if (lower.contains('leg')) return 'ABS & CORE';
      return 'SHOULDERS';
    }
    if (lower.contains('row')) return 'BACK';
    if (lower.contains('circle')) return 'SHOULDERS';
    if (lower.contains('plank')) return 'CORE';
    if (lower.contains('pull')) return 'BACK';
    if (lower.contains('curl')) return 'BICEPS';
    if (lower.contains('press')) {
      if (lower.contains('bench')) return 'CHEST';
      return 'SHOULDERS';
    }
    if (lower.contains('fly')) return 'REAR DELTS';
    if (lower.contains('shrug')) return 'TRAPS';
    return 'TARGET MUSCLES';
  }

  String _getEquipmentForExercise(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('incline')) return 'Table edge';
    if (lower.contains('pike')) return 'Bodyweight';
    if (lower.contains('door')) return 'Doorframe';
    if (lower.contains('bottle') || lower.contains('water'))
      return '2×1L bottles';
    if (lower.contains('towel')) return 'Thick towel';
    if (lower.contains('wall') || lower.contains('handstand')) return 'Wall';
    if (lower.contains('plank')) return 'Floor';
    return 'Bodyweight';
  }

  String _getFormCueForExercise(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('incline')) return 'Hands on table, lower chest to edge';
    if (lower.contains('pike'))
      return 'Hips high, lower crown of head toward floor';
    if (lower.contains('push'))
      return 'Keep core tight — body straight as a plank';
    if (lower.contains('door'))
      return 'Grip doorframe firmly, pull chest to door';
    if (lower.contains('circle'))
      return 'Keep arms horizontal, make controlled circles';
    if (lower.contains('plank'))
      return 'Squeeze glutes & core, don\'t let hips sag';
    if (lower.contains('squat'))
      return 'Keep chest up, knees tracking over toes';
    if (lower.contains('lunge'))
      return 'Step long, drop back knee close to floor';
    return 'Maintain controlled movement & steady breathing';
  }

  int _getPrescribedRestSeconds(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('pike')) return 120;
    if (lower.contains('push') ||
        lower.contains('row') ||
        lower.contains('squat'))
      return 90;
    return 60;
  }

  void _showEndWorkoutConfirmation(ThemeColors theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181B21),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'End workout?',
          style: AppFonts.text(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Progress for completed sets will be saved.',
          style: AppFonts.text(color: const Color(0xFF8B929D)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppFonts.text(color: const Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _showRepCounter = false;
                _isPaused = false;
              });
              _MainScreenState.hideBottomNavNotifier.value = false;
            },
            child: Text(
              'End Workout',
              style: AppFonts.text(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseOverlay(ThemeColors theme) {
    return Container(
      color: const Color(0xFF0A0C10).withValues(alpha: 0.96),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2C94C).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF2C94C).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  size: 36,
                  color: Color(0xFFF2C94C),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'WORKOUT PAUSED',
                style: AppFonts.text(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Take a breath. Timer & progress are frozen.',
                textAlign: TextAlign.center,
                style: AppFonts.text(
                  fontSize: 13,
                  color: const Color(0xFF8B929D),
                ),
              ),
              const SizedBox(height: 32),
              // Resume Button
              ElevatedButton(
                onPressed: () {
                  HapticService.medium();
                  setState(() => _isPaused = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: const Color(0xFF0A0C10),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'RESUME WORKOUT',
                  style: AppFonts.text(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // End Workout Button
              OutlinedButton(
                onPressed: () => _showEndWorkoutConfirmation(theme),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Color(0xFF23262D), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'End Workout',
                  style: AppFonts.text(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRpeRatingOverlay(
    ThemeColors theme,
    WorkoutExerciseState state,
    bool isLastSet,
  ) {
    return Container(
      color: const Color(0xFF0A0C10).withValues(alpha: 0.94),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How hard was that set?',
                style: AppFonts.text(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rate your exertion (RPE)',
                style: AppFonts.text(
                  fontSize: 13,
                  color: const Color(0xFF8B929D),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (i) {
                  final rpeVal = 6 + i;
                  final isSelected = _selectedRpe == rpeVal;
                  return GestureDetector(
                    onTap: () {
                      HapticService.light();
                      setState(() {
                        _selectedRpe = rpeVal;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFF2ECC71)
                            : const Color(0xFF181B21),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2ECC71)
                              : const Color(0xFF23262D),
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2ECC71,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rpeVal',
                        style: AppFonts.text(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF0A0C10)
                              : Colors.white,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Easy',
                    style: AppFonts.text(
                      fontSize: 11,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    'Hard',
                    style: AppFonts.text(
                      fontSize: 11,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    'Max effort',
                    style: AppFonts.text(
                      fontSize: 11,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _selectedRpe == null
                    ? null
                    : () {
                        HapticService.medium();
                        setState(() {
                          _showRpeOverlay = false;
                          if (isLastSet) {
                            state.completed = true;
                            state.repsRemaining = 0;
                            _showExerciseCompleteOverlay = true;
                            _maybeCompleteWorkout();
                          } else {
                            state.currentSet = state.currentSet + 1;
                            state.repsRemaining = state.maxReps;
                            _repsRemaining = state.maxReps;
                            _restSeconds = _getPrescribedRestSeconds(
                              _activeExerciseName!,
                            );
                            _restExerciseKey = state.exerciseKey;
                            _isResting = true;
                            _startRestTimer();
                          }
                        });
                        _savePreferences();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  disabledBackgroundColor: const Color(0xFF23262D),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Start rest timer',
                  style: AppFonts.text(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _selectedRpe == null
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF0A0C10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepCounterOverlay(ThemeColors theme) {
    if (_activeExerciseState == null || _activeExerciseName == null) {
      return const SizedBox.shrink();
    }

    final state = _activeExerciseState!;
    final totalSets = state.totalSets;
    final currentSet = state.currentSet;
    final isLastSet = currentSet >= totalSets;
    final targetReps = state.maxReps;

    final auroraTeal = theme.isDark ? const Color(0xFF2DD4A8) : const Color(0xFF0D9488);
    final textPrim = theme.isDark ? const Color(0xFFE8E8F0) : const Color(0xFF1C1914);
    final textSec = theme.isDark ? const Color(0xFF8B8B9A) : const Color(0xFF6B6560);
    final textMuted = theme.isDark ? const Color(0xFF4A4A5A) : const Color(0xFFA8A29D);
    final solarGold = theme.isDark ? const Color(0xFFD4A843) : const Color(0xFFB48A2A);
    final coralRed = theme.isDark ? const Color(0xFFF87171) : const Color(0xFFDC584C);

    final bgCol = theme.isDark
        ? const Color(0xFF0B0B14).withOpacity(0.96)
        : const Color(0xFFF0EDE6).withOpacity(0.96);

    return Stack(
      children: [
        // Cockpit Glass Container
        ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: bgCol,
              child: SafeArea(
                child: Column(
                  children: [
                    // Top Navigation Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Glass Back Button
                          GestureDetector(
                            onTap: () {
                              HapticService.negative();
                              SoundManager.playTapClick();
                              _showEndWorkoutConfirmation(theme);
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: theme.isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white.withOpacity(0.8),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.06),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                                color: textPrim,
                              ),
                            ),
                          ),

                          // Exercise Name & Set Progress
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                normalizeExerciseName(_activeExerciseName!),
                                style: AppFonts.text(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: textPrim,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Set $currentSet of $totalSets',
                                style: AppFonts.text(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: auroraTeal,
                                ),
                              ),
                            ],
                          ),

                          // Top Right Actions (✎ Edit & Pause)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ✎ Edit Button
                              GestureDetector(
                                onTap: () {
                                  HapticService.selection();
                                  _editExerciseNameController.text = _activeExerciseName ?? 'Push-ups';
                                  _editWorkoutTitleController.text = _selectedSplit.title;
                                  _editRepsController.text = '${state.maxReps}';
                                  _editSetsController.text = '${state.totalSets}';
                                  setState(() => _showEditRepsModal = true);
                                },
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: theme.isDark
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.white.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.black.withOpacity(0.06),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 17,
                                    color: textSec,
                                  ),
                                ),
                              ),

                              // Pause Button
                              GestureDetector(
                                onTap: () {
                                  HapticService.light();
                                  setState(() => _isPaused = true);
                                },
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: theme.isDark
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.white.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.isDark
                                          ? Colors.white.withOpacity(0.1)
                                          : Colors.black.withOpacity(0.06),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.pause_rounded,
                                    size: 18,
                                    color: solarGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Main Scrollable Area
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),

                            // 1. SET TRACKER BUBBLES
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(totalSets, (i) {
                                final setNum = i + 1;
                                final isDone = setNum < currentSet;
                                final isActive = setNum == currentSet;

                                Color bubbleBg;
                                Color bubbleText;
                                BoxBorder? bubbleBorder;
                                List<BoxShadow>? bubbleShadow;

                                if (isDone) {
                                  bubbleBg = auroraTeal;
                                  bubbleText = theme.isDark ? Colors.black : Colors.white;
                                } else if (isActive) {
                                  bubbleBg = auroraTeal.withOpacity(theme.isDark ? 0.12 : 0.08);
                                  bubbleText = auroraTeal;
                                  bubbleBorder = Border.all(color: auroraTeal, width: 1.5);
                                  if (theme.isDark) {
                                    bubbleShadow = [
                                      BoxShadow(
                                        color: auroraTeal.withOpacity(0.2),
                                        blurRadius: 10,
                                      ),
                                    ];
                                  }
                                } else {
                                  bubbleBg = theme.isDark
                                      ? Colors.white.withOpacity(0.04)
                                      : Colors.white.withOpacity(0.7);
                                  bubbleText = textMuted;
                                  bubbleBorder = Border.all(
                                    color: theme.isDark
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.black.withOpacity(0.06),
                                    width: 1,
                                  );
                                }

                                return Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  margin: EdgeInsets.only(left: i > 0 ? 8 : 0),
                                  decoration: BoxDecoration(
                                    color: bubbleBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: bubbleBorder,
                                    boxShadow: bubbleShadow,
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isDone)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 4),
                                          child: Icon(
                                            Icons.check_rounded,
                                            size: 14,
                                            color: bubbleText,
                                          ),
                                        ),
                                      Text(
                                        'Set $setNum',
                                        style: AppFonts.text(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: bubbleText,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 28),

                            // 2. GIANT REP COUNTER WITH ± GLASS BUTTONS
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: theme.isDark
                                    ? const Color(0xFF141423).withOpacity(0.6)
                                    : Colors.white.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: theme.isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.white.withOpacity(0.9),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.isDark
                                        ? Colors.black.withOpacity(0.3)
                                        : const Color(0xFF3C321E).withOpacity(0.06),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'TARGET REPS',
                                    style: AppFonts.text(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2.0,
                                      color: textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Minus Glass Button
                                      GestureDetector(
                                        onTap: () {
                                          HapticService.selection();
                                          SoundManager.playTapClick();
                                          if (_repsRemaining > 1) {
                                            setState(() {
                                              _repsRemaining--;
                                              state.repsRemaining = _repsRemaining;
                                            });
                                          }
                                        },
                                        child: Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: coralRed.withOpacity(theme.isDark ? 0.12 : 0.08),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: coralRed.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.remove_rounded,
                                            size: 26,
                                            color: coralRed,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 28),

                                      // Large Hero Number
                                      Text(
                                        '${_repsRemaining > 0 ? _repsRemaining : state.maxReps}',
                                        style: AppFonts.text(
                                          fontSize: 76,
                                          fontWeight: FontWeight.w200,
                                          color: textPrim,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 28),

                                      // Plus Glass Button
                                      GestureDetector(
                                        onTap: () {
                                          HapticService.selection();
                                          SoundManager.playTapClick();
                                          setState(() {
                                            _repsRemaining++;
                                            state.repsRemaining = _repsRemaining;
                                          });
                                        },
                                        child: Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: auroraTeal.withOpacity(theme.isDark ? 0.12 : 0.08),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: auroraTeal.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.add_rounded,
                                            size: 26,
                                            color: auroraTeal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  Text(
                                    '${state.maxReps} reps prescribed · Tap ± to adjust',
                                    style: AppFonts.text(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: textSec,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 3. RPE SELECTOR (HOW HARD WAS THAT?) - ALL 10 BUTTONS FULLY VISIBLE
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'HOW HARD WAS THAT? (RPE)',
                                        style: AppFonts.text(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                          color: textMuted,
                                        ),
                                      ),
                                      if (_selectedRpe != null)
                                        Text(
                                          _selectedRpe! <= 4
                                              ? 'Light / Warm-up'
                                              : _selectedRpe! <= 6
                                                  ? 'Moderate (3-4 RIR)'
                                                  : _selectedRpe! <= 8
                                                      ? 'Hard (1-2 RIR)'
                                                      : 'Maximum Effort / 10',
                                          style: AppFonts.text(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: solarGold,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: List.generate(10, (idx) {
                                    final rpe = idx + 1;
                                    final isSelected = _selectedRpe == rpe;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticService.selection();
                                          setState(() => _selectedRpe = rpe);
                                          _savePreferences();
                                        },
                                        child: Container(
                                          height: 38,
                                          margin: EdgeInsets.symmetric(horizontal: idx == 0 || idx == 9 ? 1 : 2),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? solarGold.withOpacity(theme.isDark ? 0.3 : 0.2)
                                                : (theme.isDark
                                                    ? Colors.white.withOpacity(0.05)
                                                    : Colors.white.withOpacity(0.85)),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSelected
                                                  ? solarGold
                                                  : (theme.isDark
                                                      ? Colors.white.withOpacity(0.08)
                                                      : Colors.black.withOpacity(0.08)),
                                              width: isSelected ? 1.5 : 0.8,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: solarGold.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '$rpe',
                                            style: AppFonts.text(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              color: isSelected ? solarGold : textSec,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // 4. FORM GUIDANCE
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: theme.isDark
                                    ? Colors.white.withOpacity(0.03)
                                    : Colors.white.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.isDark
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.black.withOpacity(0.05),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.tips_and_updates_outlined,
                                    size: 16,
                                    color: solarGold,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getFormCueForExercise(_activeExerciseName!),
                                      style: AppFonts.text(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: textSec,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // 5. AURORA COMPLETE SET BUTTON
                            GestureDetector(
                              onTap: () {
                                HapticService.medium();
                                SoundManager.playTapClick();

                                if (currentSet < totalSets) {
                                  // Advance set and start rest
                                  setState(() {
                                    state.currentSet++;
                                    _repsRemaining = state.maxReps;
                                    state.repsRemaining = state.maxReps;
                                    _restSeconds = _getPrescribedRestSeconds(_activeExerciseName!);
                                    _isResting = true;
                                  });
                                  _startRestTimer();
                                  _savePreferences();
                                } else {
                                  // Last set completed -> finish exercise
                                  setState(() {
                                    state.completed = true;
                                    state.repsRemaining = 0;
                                  });
                                  _savePreferences();

                                  // Check if whole workout complete
                                  final allDone = _selectedSplit.exercises.every((ex) {
                                    final k = '${_selectedSplit.title}|${ex[0]}';
                                    return _exerciseStates[k]?.completed == true;
                                  });

                                  if (allDone) {
                                    _maybeCompleteWorkout();
                                  } else {
                                    // Move to next exercise
                                    final nextEx = _selectedSplit.exercises.firstWhere(
                                      (ex) {
                                        final k = '${_selectedSplit.title}|${ex[0]}';
                                        return _exerciseStates[k]?.completed != true;
                                      },
                                      orElse: () => _selectedSplit.exercises.first,
                                    );
                                    final nextKey = '${_selectedSplit.title}|${nextEx[0]}';
                                    final nextState = _exerciseStates[nextKey];

                                    setState(() {
                                      _activeExerciseName = nextEx[0];
                                      _activeExerciseState = nextState;
                                      _repsRemaining = nextState?.maxReps ?? parseReps(nextEx[1]);
                                      _restSeconds = _getPrescribedRestSeconds(nextEx[0]);
                                      _isResting = true;
                                    });
                                    _startRestTimer();
                                    _savePreferences();
                                  }
                                }
                              },
                              child: Container(
                                height: 56,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: auroraTeal,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: auroraTeal.withOpacity(theme.isDark ? 0.35 : 0.25),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                    if (theme.isDark)
                                      BoxShadow(
                                        color: auroraTeal.withOpacity(0.12),
                                        blurRadius: 36,
                                      ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  isLastSet ? 'Finish Exercise ▶' : 'Complete Set $currentSet ▶',
                                  style: AppFonts.text(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: theme.isDark ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Pause Overlay
        if (_isPaused) Positioned.fill(child: _buildPauseOverlay(theme)),

        // Antigravity Glass Edit Sheet
        if (_showEditRepsModal)
          Positioned.fill(child: _buildEditRepsModal(theme)),
      ],
    );
  }

  Widget _buildEditRepsModal(ThemeColors theme) {
    final auroraTeal = theme.isDark ? const Color(0xFF2DD4A8) : const Color(0xFF0D9488);
    final textPrim = theme.isDark ? const Color(0xFFE8E8F0) : const Color(0xFF1C1914);
    final textSec = theme.isDark ? const Color(0xFF8B8B9A) : const Color(0xFF6B6560);

    return GestureDetector(
      onTap: () => setState(() => _showEditRepsModal = false),
      child: Container(
        color: Colors.black.withOpacity(0.65),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: BoxDecoration(
              color: theme.isDark
                  ? const Color(0xFF141423).withOpacity(0.96)
                  : Colors.white.withOpacity(0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: theme.isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.9),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: textSec.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Workout & Exercise',
                        style: AppFonts.text(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPrim,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showEditRepsModal = false),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.05),
                          ),
                          child: Icon(Icons.close, size: 16, color: textSec),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customise your routine title, exercise name, and target reps',
                    style: AppFonts.text(
                      fontSize: 13,
                      color: textSec,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 1. Workout Routine Name Field
                  Text(
                    'WORKOUT ROUTINE NAME',
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: textSec,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: theme.isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: auroraTeal.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _editWorkoutTitleController,
                      style: AppFonts.text(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrim,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'e.g. Upper Body, Calisthenics',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Exercise Name Field
                  Text(
                    'EXERCISE NAME',
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: textSec,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: theme.isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: auroraTeal.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _editExerciseNameController,
                      style: AppFonts.text(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrim,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'e.g. Push-ups, Pull-ups',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Target Reps & Sets Steppers Row
                  Row(
                    children: [
                      // Target Reps Stepper
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TARGET REPS',
                              style: AppFonts.text(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: textSec,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: auroraTeal.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      final cur = int.tryParse(_editRepsController.text) ?? 5;
                                      if (cur > 1) {
                                        HapticService.selection();
                                        _editRepsController.text = '${cur - 1}';
                                        setState(() {});
                                      }
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 48,
                                      alignment: Alignment.center,
                                      child: Icon(Icons.remove, size: 18, color: textPrim),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _editRepsController,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      style: AppFonts.text(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: textPrim,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      final cur = int.tryParse(_editRepsController.text) ?? 5;
                                      HapticService.selection();
                                      _editRepsController.text = '${cur + 1}';
                                      setState(() {});
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 48,
                                      alignment: Alignment.center,
                                      child: Icon(Icons.add, size: 18, color: textPrim),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Target Sets Stepper
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL SETS',
                              style: AppFonts.text(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: textSec,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: auroraTeal.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      final cur = int.tryParse(_editSetsController.text) ?? 3;
                                      if (cur > 1) {
                                        HapticService.selection();
                                        _editSetsController.text = '${cur - 1}';
                                        setState(() {});
                                      }
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 48,
                                      alignment: Alignment.center,
                                      child: Icon(Icons.remove, size: 18, color: textPrim),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _editSetsController,
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      style: AppFonts.text(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: textPrim,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      final cur = int.tryParse(_editSetsController.text) ?? 3;
                                      HapticService.selection();
                                      _editSetsController.text = '${cur + 1}';
                                      setState(() {});
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 48,
                                      alignment: Alignment.center,
                                      child: Icon(Icons.add, size: 18, color: textPrim),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // 4. Save Changes CTA
                  GestureDetector(
                    onTap: () {
                      final newRoutineTitle = _editWorkoutTitleController.text.trim();
                      final newExerciseName = _editExerciseNameController.text.trim();
                      final reps = int.tryParse(_editRepsController.text.trim()) ?? 5;
                      final sets = int.tryParse(_editSetsController.text.trim()) ?? 3;

                      if (newExerciseName.isNotEmpty && reps > 0 && sets > 0) {
                        HapticService.medium();
                        SoundManager.playTapClick();

                        final oldExName = _activeExerciseName ?? '';
                        final oldKey = '${_selectedSplit.title}|$oldExName';

                        setState(() {
                          // Update exercises list in _selectedSplit
                          final updatedExercises = _selectedSplit.exercises.map((e) {
                            if (e[0] == oldExName) {
                              final muscle = e.length > 2 ? e[2] : 'Chest';
                              return [newExerciseName, '$sets x $reps reps', muscle];
                            }
                            return e;
                          }).toList();

                          final updatedSplitTitle = newRoutineTitle.isNotEmpty ? newRoutineTitle : _selectedSplit.title;

                          final updatedSplit = WorkoutDay(
                            title: updatedSplitTitle,
                            freq: _selectedSplit.freq,
                            icon: _selectedSplit.icon,
                            color: _selectedSplit.color,
                            exercises: updatedExercises,
                          );

                          // Update in _plan
                          final planIndex = _plan.indexWhere((p) => p.title == _selectedSplit.title);
                          if (planIndex != -1) {
                            _plan[planIndex] = updatedSplit;
                          }
                          _selectedSplit = updatedSplit;
                          _activeExerciseName = newExerciseName;

                          // Update or transfer state
                          final newKey = '$updatedSplitTitle|$newExerciseName';
                          final oldState = _exerciseStates[oldKey];
                          if (oldState != null) {
                            _exerciseStates.remove(oldKey);
                            _exerciseStates[newKey] = WorkoutExerciseState(
                              exerciseKey: newKey,
                              totalSets: sets,
                              maxReps: reps,
                              currentSet: oldState.currentSet <= sets ? oldState.currentSet : sets,
                              repsRemaining: reps,
                              awaitingNextSet: oldState.awaitingNextSet,
                              completed: oldState.completed,
                            );
                            _activeExerciseState = _exerciseStates[newKey];
                          } else if (_activeExerciseState != null) {
                            _activeExerciseState!.maxReps = reps;
                            _activeExerciseState!.repsRemaining = reps;
                          }
                          _repsRemaining = reps;
                          _showEditRepsModal = false;
                          _recalculateStats();
                        });
                        _savePreferences();
                      }
                    },
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: auroraTeal,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: auroraTeal.withOpacity(0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Save Changes',
                        style: AppFonts.text(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestTimerOverlay(ThemeColors theme) {
    var nextExerciseName = 'Workout complete!';
    if (_activeExerciseState != null) {
      final exercises = _selectedSplit.exercises;
      final currentIdx = exercises.indexWhere(
        (e) =>
            '${_selectedSplit.title}|${e[0]}' ==
            _activeExerciseState!.exerciseKey,
      );
      if (currentIdx != -1 && currentIdx < exercises.length - 1) {
        nextExerciseName = exercises[currentIdx + 1][0];
      }
    }

    final bgCol = theme.isDark
        ? const Color(0xFF0B0B14).withOpacity(0.95)
        : const Color(0xFFF0EDE6).withOpacity(0.95);
    final tealCol = theme.isDark ? const Color(0xFF2DD4A8) : const Color(0xFF0D9488);
    final textPrim = theme.isDark ? const Color(0xFFE8E8F0) : const Color(0xFF1C1914);
    final textSec = theme.isDark ? const Color(0xFF8B8B9A) : const Color(0xFF6B6560);
    final textMuted = theme.isDark ? const Color(0xFF4A4A5A) : const Color(0xFFA8A29D);

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: bgCol,
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'RESTING BEFORE',
                    style: AppFonts.text(
                      fontSize: 11,
                      color: textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nextExerciseName == 'Workout complete!'
                        ? 'Finish Line'
                        : nextExerciseName,
                    style: AppFonts.text(
                      fontSize: 20,
                      color: textPrim,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CustomPaint(
                          painter: ProgressRingPainter(
                            progress: (_restSeconds / 90.0).clamp(0.0, 1.0),
                            trackColor: theme.isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.06),
                            progressColor: tealCol,
                          ),
                        ),
                      ),
                      Text(
                        '$_restSeconds',
                        style: AppFonts.text(
                          fontSize: 48,
                          fontWeight: FontWeight.w200,
                          color: textPrim,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  GestureDetector(
                    onTap: () {
                      HapticService.negative();
                      SoundManager.playTapClick();
                      _skipRest();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: theme.isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: theme.isDark
                              ? Colors.white.withOpacity(0.10)
                              : Colors.black.withOpacity(0.08),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.isDark
                                ? Colors.black.withOpacity(0.3)
                                : const Color(0xFF3C321E).withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'Skip Rest ›',
                        style: AppFonts.text(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textSec,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 6;

    final paintTrack = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final paintProgress = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paintTrack);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paintProgress,
    );
  }

  @override
  bool shouldRepaint(covariant ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}

class SavingsGoal {
  final String id;
  final String name;
  final double percentage;
  final int target;
  final String iconName;
  final int colorValue;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.percentage,
    required this.target,
    required this.iconName,
    required this.colorValue,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'percentage': percentage,
    'target': target,
    'iconName': iconName,
    'colorValue': colorValue,
  };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'New Goal',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 10.0,
      target: (json['target'] as num?)?.toInt() ?? 50000,
      iconName: json['iconName'] as String? ?? 'star',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFE8B84B,
    );
  }
}

class _TransactionItem {
  final DateTime date;
  final int amount;
  final bool isIncome;

  _TransactionItem({
    required this.date,
    required this.amount,
    required this.isIncome,
  });
}

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({
    super.key,
    required this.theme,
    required this.incomeLog,
    required this.expenseLog,
    required this.onAddEntry,
    required this.onAddExpense,
    this.onScreenshot,
  });

  final ThemeColors theme;
  final Map<String, int> incomeLog;
  final Map<String, int> expenseLog;
  final ValueChanged<int> onAddEntry;
  final ValueChanged<int> onAddExpense;
  final VoidCallback? onScreenshot;

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen>
    with TickerProviderStateMixin {
  // --- Preserved controllers & state ---
  final TextEditingController _incomeCtrl = TextEditingController();
  final TextEditingController _sourceCtrl = TextEditingController();
  late List<Map<String, dynamic>> _sources = _defaultIncomeSources();
  final int _selectedSourceIndex = 0;

  // --- New state ---
  late int _selectedMonth;
  late int _selectedYear;
  String _filter = 'All';
  bool _isInputIncome = true;

  // --- Editable goals & targets (persisted) ---
  List<SavingsGoal> _savingsGoals = [];
  int _dailyTarget = 1500;
  int _monthlyTarget = 45000;
  String _earningCurrent = '₹1,50,000';
  String _earningTarget = '₹3,00,000';
  String _earningTip = 'Aim: ₹3,00,000/month · Target editable';

  // --- Animation controllers ---
  late AnimationController _fireController;
  late AnimationController _velocityBarController;
  late AnimationController _shimmerController;
  late AnimationController _goalBarsController;
  late AnimationController _chartBarsController;
  late AnimationController _listStaggerController;
  late AnimationController _fabPulseController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;

    _loadIncomeSourcesForMonth();
    _loadEditableGoals();

    // Fire emoji pulse
    _fireController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Velocity bar fill
    _velocityBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Shimmer sweep
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Goal bars stagger
    _goalBarsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Chart bars stagger
    _chartBarsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    // List stagger
    _listStaggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // FAB pulse ring
    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Trigger entry animations after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _velocityBarController.forward();
      _goalBarsController.forward();
      _chartBarsController.forward();
      _listStaggerController.forward();
    });
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _sourceCtrl.dispose();
    _fireController.dispose();
    _velocityBarController.dispose();
    _shimmerController.dispose();
    _goalBarsController.dispose();
    _chartBarsController.dispose();
    _listStaggerController.dispose();
    _fabPulseController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  // PRESERVED DATA METHODS (unchanged logic)
  // ═══════════════════════════════════════════════

  List<Map<String, dynamic>> _defaultIncomeSources() {
    return [
      {
        'name': 'Autonexuz – YouTube',
        'type': 'Ad Revenue + Sponsorship',
        'color': const Color(0xFFE8B84B),
        'amount': 0,
        'editing': false,
      },
      {
        'name': 'Remote PLC Support',
        'type': 'Upwork · 3 clients',
        'color': const Color(0xFF38BDF8),
        'amount': 0,
        'editing': false,
      },
      {
        'name': 'Salary',
        'type': 'Industrial Automation',
        'color': const Color(0xFF00C896),
        'amount': 0,
        'editing': false,
      },
    ];
  }

  String _incomeSourcesKey(DateTime date) {
    return 'income_sources_-';
  }

  Future<void> _loadIncomeSourcesForMonth() async {
    final prefs = await SharedPreferences.getInstance();
    final currentKey = _incomeSourcesKey(DateTime.now());
    final lastKey = prefs.getString('income_sources_active_month');
    if (lastKey != currentKey) {
      await prefs.setString('income_sources_active_month', currentKey);
    }
    final raw = prefs.getString(_incomeSourcesKey(DateTime.now()));
    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      setState(() => _sources = _defaultIncomeSources());
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final loaded = decoded
          .whereType<Map<String, dynamic>>()
          .map(
            (source) => {
              'name': source['name'] as String? ?? 'Income source',
              'type': source['type'] as String? ?? 'Monthly income',
              'color': Color(
                (source['color'] as num?)?.toInt() ??
                    const Color(0xFFE8B84B).toARGB32(),
              ),
              'amount': (source['amount'] as num?)?.toInt() ?? 0,
              'editing': false,
            },
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _sources = loaded.isEmpty ? _defaultIncomeSources() : loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sources = _defaultIncomeSources());
    }
  }

  Future<void> _saveIncomeSourcesForMonth() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _sources
        .map(
          (source) => {
            'name': source['name'] as String,
            'type': source['type'] as String,
            'color': (source['color'] as Color).toARGB32(),
            'amount': source['amount'] as int,
          },
        )
        .toList();
    await prefs.setString(
      _incomeSourcesKey(DateTime.now()),
      jsonEncode(payload),
    );
  }

  int _monthTotal(Map<String, int> log, DateTime ref) {
    var total = 0;
    for (final entry in log.entries) {
      final date = dateFromKey(entry.key);
      if (date.month == ref.month && date.year == ref.year) {
        total += entry.value;
      }
    }
    return total;
  }

  String _money(num amount) {
    final value = amount.round().abs().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '\u20B9$value';
  }

  String formatDayRowDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  String getDayName(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);
    if (compareDate == today) return 'Today';
    if (compareDate == yesterday) return 'Yesterday';
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return weekdays[date.weekday - 1];
  }

  void _submitIncome(int amount, String source) {
    if (amount <= 0) return;
    setState(() {
      if (_selectedSourceIndex < _sources.length) {
        _sources[_selectedSourceIndex]['amount'] =
            (_sources[_selectedSourceIndex]['amount'] as int) + amount;
      }
    });
    _saveIncomeSourcesForMonth();
    widget.onAddEntry(amount);

    // Re-trigger animations
    _velocityBarController.reset();
    _velocityBarController.forward();
    _goalBarsController.reset();
    _goalBarsController.forward();
    _chartBarsController.reset();
    _chartBarsController.forward();
    _listStaggerController.reset();
    _listStaggerController.forward();
  }

  // ═══════════════════════════════════════════════
  // NEW HELPER METHODS
  // ═══════════════════════════════════════════════

  Future<void> _loadEditableGoals() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dailyTarget = prefs.getInt('income_daily_target') ?? 1500;
      _monthlyTarget = prefs.getInt('income_monthly_target') ?? 45000;
      _earningCurrent =
          prefs.getString('income_earning_current') ?? '₹1,50,000';
      _earningTarget = prefs.getString('income_earning_target') ?? '₹3,00,000';
      _earningTip =
          prefs.getString('income_earning_tip') ??
          'Aim: ₹3,00,000/month · Long term';

      final rawGoals = prefs.getString('income_savings_goals_list');
      if (rawGoals != null && rawGoals.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawGoals) as List<dynamic>;
          _savingsGoals = decoded
              .map((g) => SavingsGoal.fromJson(g as Map<String, dynamic>))
              .toList();
        } catch (_) {
          _loadDefaultSavingsGoals();
        }
      } else {
        _loadDefaultSavingsGoals();
      }
    });
  }

  void _loadDefaultSavingsGoals() {
    _savingsGoals = [
      SavingsGoal(
        id: 'nikah',
        name: 'Nikah Fund',
        percentage: 15.0,
        target: 100000,
        iconName: 'favorite',
        colorValue: 0xFFE8B84B, // Gold
      ),
      SavingsGoal(
        id: 'crypto',
        name: 'Crypto & Assets',
        percentage: 10.0,
        target: 50000,
        iconName: 'bitcoin',
        colorValue: 0xFFA78BFA, // Purple
      ),
      SavingsGoal(
        id: 'travel',
        name: 'Travel Fund',
        percentage: 10.0,
        target: 50000,
        iconName: 'flight',
        colorValue: 0xFF60A5FA, // Blue
      ),
    ];
  }

  Future<void> _saveEditableGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('income_daily_target', _dailyTarget);
    await prefs.setInt('income_monthly_target', _monthlyTarget);
    await prefs.setString('income_earning_current', _earningCurrent);
    await prefs.setString('income_earning_target', _earningTarget);
    await prefs.setString('income_earning_tip', _earningTip);

    final encoded = jsonEncode(_savingsGoals.map((g) => g.toJson()).toList());
    await prefs.setString('income_savings_goals_list', encoded);
  }

  void _editDailyTargetDialog() {
    final ctrl = TextEditingController(text: _dailyTarget.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors(widget.theme).bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Daily Income Target',
          style: AppFonts.display(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors(widget.theme).text1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a realistic daily goal (e.g. ₹1,000 - ₹3,000/day):',
              style: AppFonts.text(
                fontSize: 13,
                color: AppColors(widget.theme).text2,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              style: AppFonts.text(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors(widget.theme).text1,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: AppFonts.text(
                  fontSize: 16,
                  color: AppColors(widget.theme).gold,
                  fontWeight: FontWeight.bold,
                ),
                hintText: '1500',
                hintStyle: AppFonts.text(color: AppColors(widget.theme).text3),
                filled: true,
                fillColor: AppColors(widget.theme).card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors(widget.theme).cardBorder),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppFonts.text(color: AppColors(widget.theme).text3),
            ),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val > 0) {
                setState(() {
                  _dailyTarget = val;
                });
                _saveEditableGoals();
                _velocityBarController.reset();
                _velocityBarController.forward();
              }
              Navigator.pop(ctx);
            },
            child: Text(
              'Save',
              style: AppFonts.text(
                color: AppColors(widget.theme).emerald,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _earningStreak() {
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final amt = widget.incomeLog[dayKey(date)] ?? 0;
      if (amt > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  String _hijriApprox() {
    final now = DateTime(_selectedYear, _selectedMonth, 15);
    final jd = (now.millisecondsSinceEpoch / 86400000.0 + 2440587.5).floor();
    final l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    final rem = l - 10631 * n + 354;
    final j =
        ((10985 - rem) ~/ 5316) * ((50 * rem) ~/ 17719) +
        (rem ~/ 5670) * ((43 * rem) ~/ 15238);
    final lp =
        rem -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final m = (24 * lp) ~/ 709;
    final y = 30 * n + j - 30;
    const hijriMonths = [
      'Muharram',
      'Safar',
      "Rabī' al-Awwal",
      "Rabī' ath-Thānī",
      'Jumādā al-Ūlā',
      'Jumādā ath-Thāniyah',
      'Rajab',
      "Sha'bān",
      'Ramaḍān',
      'Shawwāl',
      "Dhū al-Qa'dah",
      "Dhū al-Ḥijjah",
    ];
    final mi = (m - 1).clamp(0, 11);
    return '${hijriMonths[mi]} $y AH';
  }

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  void _prevMonth() {
    HapticService.selection();
    setState(() {
      _selectedMonth--;
      if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
    _velocityBarController.reset();
    _velocityBarController.forward();
    _goalBarsController.reset();
    _goalBarsController.forward();
    _chartBarsController.reset();
    _chartBarsController.forward();
    _listStaggerController.reset();
    _listStaggerController.forward();
  }

  void _nextMonth() {
    HapticService.selection();
    setState(() {
      _selectedMonth++;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      }
    });
    _velocityBarController.reset();
    _velocityBarController.forward();
    _goalBarsController.reset();
    _goalBarsController.forward();
    _chartBarsController.reset();
    _chartBarsController.forward();
    _listStaggerController.reset();
    _listStaggerController.forward();
  }

  Widget _filterChip(String label, AppColors colors) {
    final selected = _filter == label;
    return GestureDetector(
      onTap: () {
        HapticService.selection();
        setState(() {
          _filter = label;
        });
        _listStaggerController.reset();
        _listStaggerController.forward();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? colors.gold3 : colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? colors.gold.withValues(alpha: 0.2)
                : colors.cardBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppFonts.text(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: selected ? colors.gold : colors.text3,
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors(widget.theme).bg,
        title: Text(
          'Delete Goal',
          style: AppFonts.display(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors(widget.theme).text1,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${goal.name}"?',
          style: AppFonts.text(
            fontSize: 14,
            color: AppColors(widget.theme).text2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppFonts.text(color: AppColors(widget.theme).text3),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _savingsGoals.removeWhere((g) => g.id == goal.id);
              });
              _saveEditableGoals();
              Navigator.pop(ctx); // Close confirmation dialog
              Navigator.pop(context); // Close sheet
              _goalBarsController.reset();
              _goalBarsController.forward();
            },
            child: Text(
              'Delete',
              style: AppFonts.text(
                color: AppColors(widget.theme).red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGoalResetConfirmation(AppColors colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.bg,
        title: Text(
          'Reset Savings Goals',
          style: AppFonts.display(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.text1,
          ),
        ),
        content: Text(
          'Are you sure you want to reset all savings goals to default?',
          style: AppFonts.text(fontSize: 14, color: colors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppFonts.text(color: colors.text3),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _loadDefaultSavingsGoals();
              });
              _saveEditableGoals();
              Navigator.pop(ctx);
              _goalBarsController.reset();
              _goalBarsController.forward();
            },
            child: Text(
              'Reset',
              style: AppFonts.text(
                color: colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGoalFormSheet({SavingsGoal? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final targetCtrl = TextEditingController(
      text: existing?.target.toString() ?? '',
    );
    double pct = existing?.percentage ?? 10.0;
    String selectedIcon = existing?.iconName ?? 'star';
    int selectedColor = existing?.colorValue ?? 0xFFE8B84B;

    final colors = AppColors(widget.theme);

    final iconsList = [
      'favorite',
      'bitcoin',
      'flight',
      'home',
      'car',
      'school',
      'star',
    ];
    final iconDataMap = {
      'favorite': Icons.favorite,
      'bitcoin': Icons.currency_bitcoin,
      'flight': Icons.flight,
      'home': Icons.home,
      'car': Icons.directions_car,
      'school': Icons.school,
      'star': Icons.star,
    };

    final colorOptions = [
      0xFFE8B84B, // Gold
      0xFFA78BFA, // Purple
      0xFF60A5FA, // Blue
      0xFF00C896, // Teal/Green
      0xFFF87171, // Rose/Red
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xD906060F),
      builder: (ctx) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return AnimatedPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                duration: const Duration(milliseconds: 200),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                  ),
                  decoration: BoxDecoration(
                    color: colors.theme.isDark
                        ? const Color(0xFF0E0E18)
                        : const Color(0xFFF9F7F2),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              existing == null
                                  ? 'Add Savings Goal'
                                  : 'Edit Savings Goal',
                              style: AppFonts.display(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colors.text1,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.card,
                                  border: Border.all(
                                    color: colors.cardBorder,
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.close,
                                  size: 12,
                                  color: colors.text2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'GOAL NAME',
                          style: AppFonts.text(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: colors.text3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.cardBorder),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          child: TextField(
                            controller: nameCtrl,
                            style: AppFonts.text(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.text1,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. Wedding Fund',
                              hintStyle: AppFonts.text(
                                color: colors.text3,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'TARGET AMOUNT (₹)',
                          style: AppFonts.text(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: colors.text3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.cardBorder),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          child: TextField(
                            controller: targetCtrl,
                            keyboardType: TextInputType.number,
                            style: AppFonts.text(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.text1,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 100000',
                              hintStyle: AppFonts.text(
                                color: colors.text3,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'INCOME PERCENTAGE',
                              style: AppFonts.text(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: colors.text3,
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: AppFonts.text(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.gold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Slider(
                          value: pct,
                          min: 0.0,
                          max: 100.0,
                          divisions: 100,
                          activeColor: colors.gold,
                          inactiveColor: colors.cardBorder,
                          onChanged: (val) {
                            setSheetState(() {
                              pct = val;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'SELECT ICON',
                          style: AppFonts.text(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: colors.text3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: iconsList.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, idx) {
                              final key = iconsList[idx];
                              final icon = iconDataMap[key]!;
                              final isSelected = selectedIcon == key;
                              return GestureDetector(
                                onTap: () {
                                  HapticService.selection();
                                  setSheetState(() {
                                    selectedIcon = key;
                                  });
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.gold3
                                        : colors.card,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.gold
                                          : colors.cardBorder,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 18,
                                    color: isSelected
                                        ? colors.gold
                                        : colors.text2,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'SELECT COLOR',
                          style: AppFonts.text(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: colors.text3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: colorOptions.map((cVal) {
                            final isSelected = selectedColor == cVal;
                            return GestureDetector(
                              onTap: () {
                                HapticService.selection();
                                setSheetState(() {
                                  selectedColor = cVal;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Color(cVal),
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: colors.text1,
                                          width: 3,
                                        )
                                      : Border.all(
                                          color: Colors.transparent,
                                          width: 0,
                                        ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            if (existing != null) ...[
                              Expanded(
                                flex: 1,
                                child: GestureDetector(
                                  onTap: () {
                                    HapticService.light();
                                    _showDeleteConfirmation(existing);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.red2,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: colors.red.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.delete,
                                      color: colors.red,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              flex: 3,
                              child: GestureDetector(
                                onTap: () {
                                  final name = nameCtrl.text.trim();
                                  final target =
                                      int.tryParse(targetCtrl.text.trim()) ?? 0;
                                  if (name.isEmpty || target <= 0) return;

                                  setState(() {
                                    if (existing != null) {
                                      final index = _savingsGoals.indexWhere(
                                        (g) => g.id == existing.id,
                                      );
                                      if (index != -1) {
                                        _savingsGoals[index] = SavingsGoal(
                                          id: existing.id,
                                          name: name,
                                          percentage: pct,
                                          target: target,
                                          iconName: selectedIcon,
                                          colorValue: selectedColor,
                                        );
                                      }
                                    } else {
                                      _savingsGoals.add(
                                        SavingsGoal(
                                          id: DateTime.now()
                                              .millisecondsSinceEpoch
                                              .toString(),
                                          name: name,
                                          percentage: pct,
                                          target: target,
                                          iconName: selectedIcon,
                                          colorValue: selectedColor,
                                        ),
                                      );
                                    }
                                  });
                                  _saveEditableGoals();
                                  _goalBarsController.reset();
                                  _goalBarsController.forward();
                                  Navigator.pop(ctx);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        colors.gold,
                                        colors.theme.isDark
                                            ? colors.gold.withValues(alpha: 0.8)
                                            : const Color(0xFFB8860B),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    existing == null
                                        ? 'Create Goal'
                                        : 'Save Changes',
                                    style: AppFonts.text(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _editStringField(
    String label,
    String current,
    ValueChanged<String> onSave,
  ) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors(widget.theme).bg,
        title: Text(
          'Edit $label',
          style: AppFonts.display(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors(widget.theme).text1,
          ),
        ),
        content: TextField(
          controller: ctrl,
          style: AppFonts.text(
            fontSize: 16,
            color: AppColors(widget.theme).text1,
          ),
          decoration: InputDecoration(
            hintText: 'Enter value',
            hintStyle: AppFonts.text(color: AppColors(widget.theme).text3),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppFonts.text(color: AppColors(widget.theme).text3),
            ),
          ),
          TextButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                onSave(val);
                _saveEditableGoals();
              }
              Navigator.pop(ctx);
            },
            child: Text(
              'Save',
              style: AppFonts.text(
                color: AppColors(widget.theme).gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // CELEBRATION EFFECTS
  // ═══════════════════════════════════════════════

  void _triggerCelebrations(int amount) {
    _showMoneyRain();
    if (amount >= 2000) _showConfetti();
    if (amount >= 1000) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _showFireFlame();
      });
    }
    _showGoldToast(amount);
  }

  void _showMoneyRain() {
    final overlay = Overlay.of(context);
    final rng = math.Random();
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    const symbols = ['₹', '💰', '✨', '🪙'];

    for (int i = 0; i < 12; i++) {
      late OverlayEntry entry;
      final symbol = symbols[rng.nextInt(symbols.length)];
      final startX = rng.nextDouble() * screenW;
      final startY = screenH * 0.3 + rng.nextDouble() * screenH * 0.2;
      final size = 14.0 + rng.nextDouble() * 16;
      final dur = 1000 + rng.nextInt(1000);
      final delay = rng.nextInt(300);

      entry = OverlayEntry(
        builder: (context) {
          return _CelebrationParticle(
            symbol: symbol,
            startX: startX,
            startY: startY,
            fontSize: size,
            duration: dur,
            delay: delay,
            fallDistance: 200,
            onComplete: () {
              entry.remove();
            },
          );
        },
      );
      overlay.insert(entry);
    }
  }

  void _showConfetti() {
    final overlay = Overlay.of(context);
    final rng = math.Random();
    final screenW = MediaQuery.of(context).size.width;
    final colors = AppColors(widget.theme);
    final confettiColors = [
      colors.gold,
      colors.emerald,
      const Color(0xFFA78BFA),
      colors.red,
      const Color(0xFF60A5FA),
      Colors.white,
    ];

    for (int i = 0; i < 25; i++) {
      late OverlayEntry entry;
      final color = confettiColors[rng.nextInt(confettiColors.length)];
      final startX = rng.nextDouble() * screenW;
      final size = 4.0 + rng.nextDouble() * 6;
      final dur = 1200 + rng.nextInt(1500);
      final delay = rng.nextInt(500);
      final isCircle = rng.nextBool();

      entry = OverlayEntry(
        builder: (context) {
          return _IncomeConfettiDot(
            startX: startX,
            size: size,
            color: color,
            duration: dur,
            delay: delay,
            isCircle: isCircle,
            onComplete: () {
              entry.remove();
            },
          );
        },
      );
      overlay.insert(entry);
    }
  }

  void _showFireFlame() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return _FireFlameOverlay(onComplete: () => entry.remove());
      },
    );
    overlay.insert(entry);
  }

  void _showGoldToast(int amount) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    final colors = AppColors(widget.theme);
    entry = OverlayEntry(
      builder: (context) {
        return _GoldToast(
          message: '${_money(amount)} added! 💰',
          goldColor: colors.gold,
          onComplete: () => entry.remove(),
        );
      },
    );
    overlay.insert(entry);
  }

  // ═══════════════════════════════════════════════
  // ADD INCOME BOTTOM SHEET
  // ═══════════════════════════════════════════════

  void _showExpenseToast(int amount) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    final colors = AppColors(widget.theme);
    entry = OverlayEntry(
      builder: (context) {
        return _GoldToast(
          message: '${_money(amount)} expense added! 💸',
          goldColor: colors.red,
          onComplete: () => entry.remove(),
        );
      },
    );
    overlay.insert(entry);
  }

  void _showAddIncomeSheet() {
    _incomeCtrl.clear();
    _sourceCtrl.clear();
    final colors = AppColors(widget.theme);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xD906060F),
      builder: (ctx) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final isAddingIncome = _isInputIncome;

              return AnimatedPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                duration: const Duration(milliseconds: 200),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: colors.theme.isDark
                        ? const Color(0xFF0E0E18)
                        : const Color(0xFFF9F7F2),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isAddingIncome ? 'Add Income' : 'Add Expense',
                              style: AppFonts.display(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: colors.text1,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.card,
                                  border: Border.all(
                                    color: colors.cardBorder,
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.close,
                                  size: 12,
                                  color: colors.text2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticService.selection();
                                  setSheetState(() {
                                    _isInputIncome = true;
                                  });
                                },
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isAddingIncome
                                        ? colors.emerald2
                                        : colors.bg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isAddingIncome
                                          ? colors.emerald.withValues(
                                              alpha: 0.25,
                                            )
                                          : colors.cardBorder,
                                      width: 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Income',
                                    style: AppFonts.text(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isAddingIncome
                                          ? colors.emerald
                                          : colors.text3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticService.selection();
                                  setSheetState(() {
                                    _isInputIncome = false;
                                  });
                                },
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: !isAddingIncome
                                        ? colors.red2
                                        : colors.bg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: !isAddingIncome
                                          ? colors.red.withValues(alpha: 0.25)
                                          : colors.cardBorder,
                                      width: 1,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Expense',
                                    style: AppFonts.text(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: !isAddingIncome
                                          ? colors.red
                                          : colors.text3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        Text(
                          'AMOUNT (₹)',
                          style: AppFonts.text(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: colors.text3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.cardBorder),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          child: TextField(
                            controller: _incomeCtrl,
                            keyboardType: TextInputType.number,
                            style: AppFonts.text(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.text1,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: AppFonts.text(
                                color: colors.text3,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          isAddingIncome ? 'SOURCE' : 'DESCRIPTION',
                          style: AppFonts.text(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: colors.text3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.cardBorder),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          child: TextField(
                            controller: _sourceCtrl,
                            style: AppFonts.text(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.text1,
                            ),
                            decoration: InputDecoration(
                              hintText: isAddingIncome
                                  ? 'e.g. Freelance project'
                                  : 'e.g. Groceries, internet bills',
                              hintStyle: AppFonts.text(
                                color: colors.text3,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          'QUICK ADD',
                          style: AppFonts.text(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: colors.text3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.0,
                          children: [500, 1000, 2000, 5000].map((val) {
                            return GestureDetector(
                              onTap: () {
                                HapticService.selection();
                                setSheetState(() {
                                  _incomeCtrl.text = val.toString();
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colors.card,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colors.cardBorder,
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _money(val),
                                  style: AppFonts.text(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text2,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        GestureDetector(
                          onTap: () {
                            final amount = int.tryParse(
                              _incomeCtrl.text.trim(),
                            );
                            if (amount == null || amount <= 0) return;
                            HapticService.light();
                            Navigator.pop(ctx);

                            if (isAddingIncome) {
                              _submitIncome(amount, _sourceCtrl.text.trim());
                              _triggerCelebrations(amount);
                            } else {
                              widget.onAddExpense(amount);
                              _showExpenseToast(amount);
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isAddingIncome
                                    ? [
                                        colors.gold,
                                        colors.theme.isDark
                                            ? colors.gold.withValues(alpha: 0.8)
                                            : const Color(0xFFB8860B),
                                      ]
                                    : [
                                        colors.red,
                                        colors.theme.isDark
                                            ? colors.red.withValues(alpha: 0.8)
                                            : const Color(0xFFC0392B),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: isAddingIncome
                                      ? colors.gold3
                                      : colors.red2,
                                  blurRadius: 24,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isAddingIncome ? Icons.add : Icons.remove,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isAddingIncome ? 'Add Income' : 'Add Expense',
                                  style: AppFonts.text(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════
  // SECTION BUILDERS
  // ═══════════════════════════════════════════════

  Widget _buildHeader(AppColors colors) {
    final streak = _earningStreak();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: label + compact streak pill badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'INCOME',
                style: AppFonts.text(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.08,
                  color: colors.text3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: streak > 0
                      ? colors.emerald.withValues(alpha: 0.12)
                      : (colors.theme.isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: streak > 0
                        ? colors.emerald.withValues(alpha: 0.3)
                        : colors.cardBorder,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      streak > 0 ? '🌱' : '💼',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      streak > 0 ? '$streak days logged' : 'Log daily',
                      style: AppFonts.compact(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: streak > 0 ? colors.emerald : colors.text2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Month nav row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _prevMonth,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.theme.isDark
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFF2F2F7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.theme.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 0.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.chevron_left,
                    size: 18,
                    color: colors.text1,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '${_monthNames[_selectedMonth - 1]} $_selectedYear',
                style: AppFonts.text(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: colors.text1,
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: _nextMonth,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.theme.isDark
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFF2F2F7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.theme.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 0.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colors.text1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Hijri date
          Center(
            child: Text(
              _hijriApprox(),
              style: AppFonts.arabic(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVelocityMeter(
    AppColors colors,
    int totalEarned,
    int daysInMonth,
  ) {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth == now.month && _selectedYear == now.year;
    final daysSoFar = isCurrentMonth ? now.day : daysInMonth;
    final dailyAvg = daysSoFar > 0 ? totalEarned / daysSoFar : 0.0;
    final todayEarned = isCurrentMonth ? (widget.incomeLog[dayKey(now)] ?? 0) : 0;
    
    // Normalized against user's custom daily target
    final targetVal = _dailyTarget > 0 ? _dailyTarget : 1500;
    final fillPct = (dailyAvg / targetVal).clamp(0.0, 1.0);

    Color statusColor;
    String statusText;
    if (dailyAvg >= targetVal) {
      statusColor = colors.emerald;
      statusText = '${_money(dailyAvg.round())}/day · On track';
    } else if (dailyAvg > 0) {
      statusColor = colors.gold;
      statusText = '${_money(dailyAvg.round())}/day · Target: ${_money(targetVal)}';
    } else {
      statusColor = colors.text3;
      statusText = 'Target: ${_money(targetVal)}/day';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.theme.isDark
            ? const Color(0xFF1C1C1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.theme.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.theme.isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF3C321E).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.speed, size: 14, color: colors.emerald),
                  const SizedBox(width: 6),
                  Text(
                    'DAILY MOMENTUM',
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: colors.text3,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Flexible(
                child: GestureDetector(
                  onTap: _editDailyTargetDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.emerald2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.emerald.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            statusText,
                            style: AppFonts.text(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_outlined, size: 11, color: statusColor),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bar
          AnimatedBuilder(
            animation: _velocityBarController,
            builder: (_, _) {
              final animFill =
                  fillPct *
                  Curves.easeOutCubic.transform(_velocityBarController.value);
              return Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.theme.isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: animFill.clamp(0.01, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.emerald.withValues(alpha: 0.7),
                            colors.emerald,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Comparison text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Today: ${_money(todayEarned)}',
                  style: AppFonts.text(fontSize: 11, color: colors.text3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Avg: ${_money(dailyAvg.round())}/day',
                  style: AppFonts.text(fontSize: 11, color: colors.text2, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: GestureDetector(
                  onTap: _editDailyTargetDialog,
                  child: Text(
                    'Goal: ${_money(targetVal)}/day',
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.emerald,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(AppColors colors, int totalEarned, int daysInMonth) {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth == now.month && _selectedYear == now.year;
    final daysSoFar = isCurrentMonth ? now.day : daysInMonth;
    final dailyAvg = daysSoFar > 0 ? (totalEarned / daysSoFar).round() : 0;
    final projected = (dailyAvg * daysInMonth);

    final ref = DateTime(_selectedYear, _selectedMonth, 1);
    final totalSpent = _monthTotal(widget.expenseLog, ref);
    final netBalance = totalEarned - totalSpent;
    final dailyAvgSpent = daysSoFar > 0 ? (totalSpent / daysSoFar).round() : 0;

    // Count actual days logged
    int daysLogged = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_selectedYear, _selectedMonth, d);
      final amt = widget.incomeLog[dayKey(date)] ?? 0;
      if (amt > 0) daysLogged++;
    }

    final prevRef = DateTime(
      _selectedMonth == 1 ? _selectedYear - 1 : _selectedYear,
      _selectedMonth == 1 ? 12 : _selectedMonth - 1,
      1,
    );
    final prevTotal = _monthTotal(widget.incomeLog, prevRef);
    final changePct = prevTotal > 0
        ? ((totalEarned - prevTotal) / prevTotal * 100)
        : 0.0;
    final isUp = changePct >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.theme.isDark
            ? const Color(0xFF1C1C1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.theme.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.theme.isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF3C321E).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 13,
                    color: colors.emerald,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'NET BALANCE',
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: colors.text3,
                    ),
                  ),
                ],
              ),
              if (prevTotal > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isUp ? colors.emerald2 : colors.theme.isDark ? Colors.white10 : Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${isUp ? "↑" : "↓"} ${changePct.abs().toStringAsFixed(0)}%',
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isUp ? colors.emerald : colors.text2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            key: ValueKey('$_selectedMonth-$_selectedYear-$netBalance'),
            tween: Tween<double>(
              begin: 0.0,
              end: netBalance.toDouble(),
            ),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) {
              final display = value
                  .round()
                  .abs()
                  .toString()
                  .replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (m) => '${m[1]},',
                  );
              final isNegative = netBalance < 0;
              return Text(
                '${isNegative ? "-" : ""}₹${netBalance == 0 ? "0" : display}',
                style: AppFonts.display(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isNegative
                      ? colors.red
                      : (netBalance == 0 ? colors.text3 : colors.text1),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              );
            },
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.theme.isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'INCOME',
                        style: AppFonts.text(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: colors.text3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalEarned > 0 ? _money(totalEarned) : '₹0',
                        style: AppFonts.display(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: totalEarned > 0
                              ? colors.emerald
                              : colors.text3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (totalEarned > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Avg: ${_money(dailyAvg)}/day',
                          style: AppFonts.text(
                            fontSize: 11,
                            color: colors.text2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.theme.isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXPENSES',
                        style: AppFonts.text(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: colors.text3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalSpent > 0 ? _money(totalSpent) : '₹0',
                        style: AppFonts.display(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: totalSpent > 0 ? colors.text1 : colors.text3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (totalSpent > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Avg: ${_money(dailyAvgSpent)}/day',
                          style: AppFonts.text(
                            fontSize: 11,
                            color: colors.text2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Center(
            child: Text(
              daysLogged >= 7
                  ? 'Projected monthly income: ${_money(projected)}'
                  : '${_money(totalEarned)} earned so far · Log ${7 - daysLogged} more days for projection',
              style: AppFonts.text(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: daysLogged >= 7 ? colors.emerald : colors.text3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeAllocationCard(AppColors colors, int totalEarned) {
    final hasIncome = totalEarned > 0;
    final baseAmount = hasIncome ? totalEarned : 0;

    final categories = [
      {
        'label': 'Necessities & Bills',
        'pct': 0.55,
        'pctLabel': '55%',
        'color': const Color(0xFF2DD4A8),
      },
      {
        'label': 'Emergency Buffer',
        'pct': 0.05,
        'pctLabel': '5%',
        'color': const Color(0xFF38BDF8),
      },
      {
        'label': 'Investments & Growth',
        'pct': 0.10,
        'pctLabel': '10%',
        'color': const Color(0xFFA78BFA),
      },
      {
        'label': 'Nikah / Family Fund',
        'pct': 0.15,
        'pctLabel': '15%',
        'color': const Color(0xFFE8B84B),
      },
      {
        'label': 'Personal & Discretionary',
        'pct': 0.15,
        'pctLabel': '15%',
        'color': const Color(0xFFFB923C),
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.theme.isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.theme.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.theme.isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF3C321E).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart_outline, size: 14, color: colors.emerald),
                  const SizedBox(width: 6),
                  Text(
                    'INCOME ALLOCATION',
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: colors.text3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.emerald2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.emerald.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '55/5/10/15/15 Rule',
                  style: AppFonts.text(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Segmented Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 7,
              child: Row(
                children: categories.map((cat) {
                  final flex = ((cat['pct'] as double) * 100).round();
                  final col = cat['color'] as Color;
                  return Expanded(
                    flex: flex,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      color: hasIncome ? col : colors.text3.withValues(alpha: 0.3),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5 Color-coded Rows
          Column(
            children: List.generate(categories.length, (i) {
              final cat = categories[i];
              final col = cat['color'] as Color;
              final pct = cat['pct'] as double;
              final label = cat['label'] as String;
              final pctLabel = cat['pctLabel'] as String;
              final allocatedAmt = (baseAmount * pct).round();

              return Padding(
                padding: EdgeInsets.only(
                  bottom: i < categories.length - 1 ? 10.0 : 0.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: hasIncome
                                ? col
                                : colors.text3.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$label ($pctLabel)',
                          style: AppFonts.text(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: hasIncome ? colors.text2 : colors.text3,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      hasIncome ? _money(allocatedAmt) : '—',
                      style: AppFonts.display(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: hasIncome ? colors.text1 : colors.text3,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsGoals(AppColors colors, int totalEarned) {
    final iconDataMap = {
      'favorite': Icons.favorite,
      'bitcoin': Icons.currency_bitcoin,
      'flight': Icons.flight,
      'home': Icons.home,
      'car': Icons.directions_car,
      'school': Icons.school,
      'star': Icons.star,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: colors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SAVINGS GOALS',
                style: AppFonts.text(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: colors.text3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticService.light();
                  _showGoalResetConfirmation(colors);
                },
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 13, color: colors.red),
                    const SizedBox(width: 4),
                    Text(
                      'Reset',
                      style: AppFonts.text(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () {
                  HapticService.light();
                  _showGoalFormSheet();
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 13,
                      color: colors.emerald,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Add Goal',
                      style: AppFonts.text(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colors.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_savingsGoals.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.cardBorder, width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                'No savings goals created yet.',
                style: AppFonts.text(fontSize: 12, color: colors.text3),
              ),
            )
          else
            ...List.generate(_savingsGoals.length, (i) {
              final g = _savingsGoals[i];
              final current = (totalEarned * (g.percentage / 100)).round();
              final target = g.target;
              final pct = (totalEarned <= 0 || target <= 0)
                  ? 0.0
                  : (current / target).clamp(0.0, 1.0);
              final monthsLeft = current > 0
                  ? ((target - current) / (current > 0 ? current : 1))
                        .ceil()
                        .clamp(0, 999)
                  : 0;

              Color colorVal = Color(g.colorValue);
              Color gradStart;
              Color gradEnd = colorVal;
              if (g.colorValue == 0xFFE8B84B) {
                gradStart = const Color(0xFFB8860B);
                gradEnd = colors.gold;
              } else if (g.colorValue == 0xFFA78BFA) {
                gradStart = const Color(0xFF7C3AED);
              } else if (g.colorValue == 0xFF60A5FA) {
                gradStart = const Color(0xFF2563EB);
              } else if (g.colorValue == 0xFF00C896) {
                gradStart = const Color(0xFF0A7A5A);
              } else if (g.colorValue == 0xFFF87171) {
                gradStart = const Color(0xFFC0392B);
              } else {
                gradStart = colorVal.withValues(alpha: 0.7);
              }

              final staggerStart = (i * 200.0 / 1800.0).clamp(0.0, 1.0);
              final staggerEnd = (staggerStart + 1000.0 / 1800.0).clamp(
                0.0,
                1.0,
              );

              final iconData = iconDataMap[g.iconName] ?? Icons.star;

              return GestureDetector(
                onTap: () {
                  HapticService.light();
                  _showGoalFormSheet(existing: g);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.cardBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: colorVal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(iconData, size: 14, color: colorVal),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.name,
                                  style: AppFonts.text(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.text1,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${g.percentage.toStringAsFixed(0)}% of income',
                                  style: AppFonts.text(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: colors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: AppFonts.text(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.text2,
                              ),
                              children: [
                                TextSpan(
                                  text: _money(current),
                                  style: TextStyle(color: colors.text1),
                                ),
                                TextSpan(text: ' / ${_money(target)}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Progress bar
                      AnimatedBuilder(
                        animation: _goalBarsController,
                        builder: (_, _) {
                          final interval = Interval(
                            staggerStart,
                            staggerEnd,
                            curve: Curves.easeOutCubic,
                          );
                          final animPct =
                              (pct *
                                      interval.transform(
                                        _goalBarsController.value,
                                      ))
                                  .clamp(0.0, 1.0);
                          return Stack(
                            children: [
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colors.theme.isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : Colors.black.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: animPct,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [gradStart, gradEnd],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}% complete',
                            style: AppFonts.text(
                              fontSize: 9,
                              color: colors.text3,
                            ),
                          ),
                          Text(
                            '~$monthsLeft months left',
                            style: AppFonts.text(
                              fontSize: 9,
                              color: colors.text3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEarningPotential(AppColors colors) {
    final now = DateTime.now();
    final monthRef = DateTime(_selectedYear, _selectedMonth, 1);
    final totalEarned = _monthTotal(widget.incomeLog, monthRef);
    final isCurrentMonth =
        _selectedMonth == now.month && _selectedYear == now.year;
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final daysSoFar = isCurrentMonth ? now.day : daysInMonth;
    final dailyAvg = daysSoFar > 0 ? (totalEarned / daysSoFar).round() : 0;

    return GestureDetector(
      onLongPress: () {
        _editStringField('Earning Tip', _earningTip, (v) {
          setState(() => _earningTip = v);
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.theme.isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.theme.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.theme.isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : const Color(0xFF3C321E).withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rocket_launch, size: 14, color: colors.gold),
                const SizedBox(width: 6),
                Text(
                  'ASPIRATIONAL GOALS · LONG TERM',
                  style: AppFonts.text(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: colors.text3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _editStringField('Target Milestone', _earningCurrent, (v) {
                        setState(() => _earningCurrent = v);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.theme.isDark
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _earningCurrent,
                            style: AppFonts.display(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.text1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'TARGET / MONTH',
                            style: AppFonts.text(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: colors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _editStringField('Ultimate Milestone', _earningTarget, (v) {
                        setState(() => _earningTarget = v);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.gold.withValues(alpha: 0.25),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _earningTarget,
                            style: AppFonts.display(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.gold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'FREELANCE POTENTIAL',
                            style: AppFonts.text(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: colors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Translating line bridging the 10x gap
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.theme.isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.theme.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_up_rounded, size: 14, color: colors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dailyAvg > 0
                          ? 'Current pace ${_money(dailyAvg)}/day · Scaling to ₹1.5L/mo translates to ~₹5,000/day across retainers'
                          : 'Milestone bridge: Scaling to ₹1.5L/mo translates to ~₹5,000/day across 3 client retainers',
                      style: AppFonts.text(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.text2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(AppColors colors, int daysInMonth) {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth == now.month && _selectedYear == now.year;
    final today = DateTime(now.year, now.month, now.day);

    // 7-day rolling window or active week
    final days = List.generate(7, (i) {
      if (isCurrentMonth) {
        return today.subtract(Duration(days: 6 - i));
      } else {
        final startDay = (daysInMonth - 7).clamp(1, daysInMonth);
        return DateTime(_selectedYear, _selectedMonth, startDay + i);
      }
    });

    final amounts = days.map((d) => widget.incomeLog[dayKey(d)] ?? 0).toList();
    int max7 = amounts.fold(0, (max, e) => e > max ? e : max);
    if (max7 <= 0) max7 = 1;

    // Total month stats for caption
    int monthEarned = 0;
    int daysLogged = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_selectedYear, _selectedMonth, d);
      final amt = widget.incomeLog[dayKey(date)] ?? 0;
      if (amt > 0) {
        monthEarned += amt;
        daysLogged++;
      }
    }
    final daysSoFar = isCurrentMonth ? now.day : daysInMonth;
    final dailyAvg = daysSoFar > 0 ? (monthEarned / daysSoFar).round() : 0;

    const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.theme.isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.theme.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.theme.isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF3C321E).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 14, color: colors.emerald),
                  const SizedBox(width: 6),
                  Text(
                    'DAILY EARNINGS',
                    style: AppFonts.text(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: colors.text3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: daysLogged > 0 ? colors.emerald2 : colors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: daysLogged > 0
                        ? colors.emerald.withValues(alpha: 0.3)
                        : colors.cardBorder,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  daysLogged > 0 ? '$daysLogged active days' : '7-Day Trend',
                  style: AppFonts.text(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: daysLogged > 0 ? colors.emerald : colors.text3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 7-day bars with real weekday labels
          SizedBox(
            height: 96,
            child: AnimatedBuilder(
              animation: _chartBarsController,
              builder: (_, _) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final date = days[i];
                    final amt = amounts[i];
                    final isToday = isCurrentMonth && dayKey(date) == dayKey(today);
                    final barPct = max7 > 0 ? (amt / max7).clamp(0.0, 1.0) : 0.0;
                    final barH = amt > 0 ? math.max(6.0, barPct * 52.0) : 4.0;
                    final weekday = weekdayShort[date.weekday - 1];

                    final staggerStart = (i * 40.0 / 1300.0).clamp(0.0, 1.0);
                    final staggerEnd = (staggerStart + 800.0 / 1300.0).clamp(0.0, 1.0);
                    final interval = Interval(
                      staggerStart,
                      staggerEnd,
                      curve: Curves.easeOutCubic,
                    );
                    final animH = barH * interval.transform(_chartBarsController.value);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (amt > 0)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _money(amt),
                                  style: AppFonts.compact(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: isToday ? colors.gold : colors.emerald,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 11),
                            const SizedBox(height: 4),
                            Container(
                              height: animH,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: amt > 0
                                    ? (isToday ? colors.gold : colors.emerald)
                                    : (colors.theme.isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.04)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              weekday,
                              style: AppFonts.compact(
                                fontSize: 10,
                                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                color: isToday ? colors.gold : colors.text3,
                              ),
                            ),
                            Text(
                              '${date.day}',
                              style: AppFonts.compact(
                                fontSize: 9,
                                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                                color: isToday ? colors.text1 : colors.text3.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: colors.theme.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 10),

          // Plain informative caption
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 13, color: colors.emerald),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  monthEarned > 0
                      ? 'Average ${_money(dailyAvg)}/day across $daysLogged active earning days this month'
                      : 'Log daily earnings to build momentum towards your monthly target',
                  style: AppFonts.text(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.text2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(AppColors colors) {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth == now.month && _selectedYear == now.year;
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final maxDay = isCurrentMonth ? now.day : daysInMonth;

    final entries = <_TransactionItem>[];
    for (int d = maxDay; d >= 1; d--) {
      final date = DateTime(_selectedYear, _selectedMonth, d);
      final earned = widget.incomeLog[dayKey(date)] ?? 0;
      final spent = widget.expenseLog[dayKey(date)] ?? 0;

      if (_filter == 'All') {
        if (earned > 0) {
          entries.add(
            _TransactionItem(date: date, amount: earned, isIncome: true),
          );
        }
        if (spent > 0) {
          entries.add(
            _TransactionItem(date: date, amount: spent, isIncome: false),
          );
        }
      } else if (_filter == 'Earned') {
        if (earned > 0) {
          entries.add(
            _TransactionItem(date: date, amount: earned, isIncome: true),
          );
        }
      } else if (_filter == 'Spent') {
        if (spent > 0) {
          entries.add(
            _TransactionItem(date: date, amount: spent, isIncome: false),
          );
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'RECENT TRANSACTIONS',
                style: AppFonts.text(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: colors.text3,
                ),
              ),
              const Spacer(),
              if (entries.isNotEmpty)
                Text(
                  '${entries.length} entries',
                  style: AppFonts.text(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.text3,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Apple Native Segmented Control
          Container(
            height: 34,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: colors.theme.isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: ['All', 'Earned', 'Spent'].map((label) {
                final isSelected = _filter == label;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticService.selection();
                      setState(() {
                        _filter = label;
                      });
                      _listStaggerController.reset();
                      _listStaggerController.forward();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (colors.theme.isDark
                                ? const Color(0xFF636366)
                                : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: AppFonts.text(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? colors.text1
                              : colors.text3,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          if (entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: colors.theme.isDark
                    ? const Color(0xFF1C1C1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.theme.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  'Tap + Log to record your first transaction',
                  style: AppFonts.text(
                    fontSize: 13,
                    color: colors.text3,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: colors.theme.isDark
                    ? const Color(0xFF1C1C1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.theme.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.theme.isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : const Color(0xFF3C321E).withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: AnimatedBuilder(
                animation: _listStaggerController,
                builder: (_, _) {
                  return Column(
                    children: List.generate(entries.length, (i) {
                      final e = entries[i];
                      final isInc = e.isIncome;
                      // Color-coding: Coral + ↓ for spend, Teal + ↑ for earned
                      final displayColor = isInc
                          ? const Color(0xFF2DD4A8)
                          : const Color(0xFFFB7185);
                      final iconBgColor = isInc
                          ? const Color(0xFF2DD4A8).withValues(alpha: 0.12)
                          : const Color(0xFFFB7185).withValues(alpha: 0.12);
                      final iconData = isInc
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded;
                      final prefix = isInc ? '+' : '−';

                      return Column(
                        children: [
                          Container(
                            height: 58,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    iconData,
                                    size: 15,
                                    color: displayColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        getDayName(e.date),
                                        style: AppFonts.text(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: colors.text1,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatDayRowDate(e.date),
                                        style: AppFonts.text(
                                          fontSize: 11,
                                          color: colors.text3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$prefix${_money(e.amount)}',
                                  style: AppFonts.display(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: displayColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (i < entries.length - 1)
                            Divider(
                              height: 0.5,
                              thickness: 0.5,
                              indent: 60,
                              color: colors.theme.isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                        ],
                      );
                    }),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFab(AppColors colors) {
    return Positioned(
      bottom: 24,
      right: 20,
      child: GestureDetector(
        onTap: () {
          HapticService.light();
          _showAddIncomeSheet();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.emerald,
                colors.theme.isDark
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF15803D),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors.emerald.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                'Log',
                style: AppFonts.text(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(widget.theme);
    final monthRef = DateTime(_selectedYear, _selectedMonth, 1);
    final totalEarned = _monthTotal(widget.incomeLog, monthRef);
    final totalSpent = _monthTotal(widget.expenseLog, monthRef);
    final netBalance = totalEarned - totalSpent;
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;

    return Stack(
      children: [
        // Background atmosphere orbs
        Positioned(
          top: 60,
          right: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colors.gold.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 200,
          left: -30,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  colors.emerald.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Main content
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(top: 24, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(colors),
                const SizedBox(height: 14),
                _buildVelocityMeter(colors, totalEarned, daysInMonth),
                const SizedBox(height: 14),
                _buildHeroCard(colors, totalEarned, daysInMonth),
                const SizedBox(height: 14),
                _buildIncomeAllocationCard(colors, netBalance),
                const SizedBox(height: 14),
                _buildEarningPotential(colors),
                const SizedBox(height: 14),
                _buildChart(colors, daysInMonth),
                const SizedBox(height: 14),
                _buildTransactionList(colors),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),

        // FAB
        _buildFab(colors),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
// ISLAMIC STAR PAINTER
// ═══════════════════════════════════════════════

class _IslamicStarPainter extends CustomPainter {
  final Color color;
  const _IslamicStarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final outerX = cx + r * math.cos(angle);
      final outerY = cy + r * math.sin(angle);
      final innerAngle = angle + math.pi / 8;
      final innerX = cx + r * 0.4 * math.cos(innerAngle);
      final innerY = cy + r * 0.4 * math.sin(innerAngle);
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _IslamicStarPainter old) => old.color != color;
}

// ═══════════════════════════════════════════════
// GRADIENT TRANSLATION HELPER
// ═══════════════════════════════════════════════

class GradientTranslation extends GradientTransform {
  final double dx;
  const GradientTranslation(this.dx);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}

// ═══════════════════════════════════════════════
// CELEBRATION OVERLAY WIDGETS
// ═══════════════════════════════════════════════

class _CelebrationParticle extends StatefulWidget {
  final String symbol;
  final double startX, startY, fontSize;
  final int duration, delay;
  final double fallDistance;
  final VoidCallback onComplete;

  const _CelebrationParticle({
    required this.symbol,
    required this.startX,
    required this.startY,
    required this.fontSize,
    required this.duration,
    required this.delay,
    required this.fallDistance,
    required this.onComplete,
  });

  @override
  State<_CelebrationParticle> createState() => _CelebrationParticleState();
}

class _CelebrationParticleState extends State<_CelebrationParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.duration),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _ctrl.forward().then((_) {
          if (mounted) widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        return Positioned(
          left: widget.startX,
          top: widget.startY + t * widget.fallDistance,
          child: Opacity(
            opacity: 1 - t,
            child: Transform.scale(
              scale: 1 - t * 0.7,
              child: Transform.rotate(
                angle: t * math.pi,
                child: Text(
                  widget.symbol,
                  style: TextStyle(fontSize: widget.fontSize),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IncomeConfettiDot extends StatefulWidget {
  final double startX, size;
  final Color color;
  final int duration, delay;
  final bool isCircle;
  final VoidCallback onComplete;

  const _IncomeConfettiDot({
    required this.startX,
    required this.size,
    required this.color,
    required this.duration,
    required this.delay,
    required this.isCircle,
    required this.onComplete,
  });

  @override
  State<_IncomeConfettiDot> createState() => _IncomeConfettiDotState();
}

class _IncomeConfettiDotState extends State<_IncomeConfettiDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.duration),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _ctrl.forward().then((_) {
          if (mounted) widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        return Positioned(
          left: widget.startX,
          top: -10 + t * 400,
          child: Opacity(
            opacity: 1 - t,
            child: Transform.rotate(
              angle: t * math.pi * 4,
              child: Container(
                width: widget.size,
                height: widget.isCircle ? widget.size : widget.size / 2,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(
                    widget.isCircle ? widget.size : 1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FireFlameOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const _FireFlameOverlay({required this.onComplete});

  @override
  State<_FireFlameOverlay> createState() => _FireFlameOverlayState();
}

class _FireFlameOverlayState extends State<_FireFlameOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 800),
          )
          ..forward().then((_) {
            if (mounted) widget.onComplete();
          });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        final opacity = t < 0.3
            ? t / 0.3
            : t > 0.7
            ? (1 - t) / 0.3
            : 1.0;
        final scale = Curves.easeOutBack.transform((t * 1.5).clamp(0.0, 1.0));
        return Positioned(
          left: size.width / 2 - 60,
          top: size.height / 2 - 80,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.3 + scale * 0.9,
              child: const Text('🔥', style: TextStyle(fontSize: 120)),
            ),
          ),
        );
      },
    );
  }
}

class _GoldToast extends StatefulWidget {
  final String message;
  final Color goldColor;
  final VoidCallback onComplete;
  const _GoldToast({
    required this.message,
    required this.goldColor,
    required this.onComplete,
  });

  @override
  State<_GoldToast> createState() => _GoldToastState();
}

class _GoldToastState extends State<_GoldToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2600),
          )
          ..forward().then((_) {
            if (mounted) widget.onComplete();
          });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        double opacity;
        double translateY;
        if (t < 0.15) {
          // Enter: 0 -> 0.15 (~400ms)
          final p = Curves.easeOutBack.transform(t / 0.15);
          opacity = p;
          translateY = -20 * (1 - p);
        } else if (t < 0.85) {
          // Hold
          opacity = 1;
          translateY = 0;
        } else {
          // Exit: 0.85 -> 1.0 (~400ms)
          final p = (t - 0.85) / 0.15;
          opacity = 1 - p;
          translateY = -20 * p;
        }
        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 40,
          right: 40,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFB8860B), widget.goldColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.goldColor.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.message,
                  style: AppFonts.text(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlowingPulse extends StatefulWidget {
  final double progress;
  final Color accentColor;

  const _GlowingPulse({required this.progress, required this.accentColor});

  @override
  State<_GlowingPulse> createState() => _GlowingPulseState();
}

class _GlowingPulseState extends State<_GlowingPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * widget.progress;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              left: -50 + (_controller.value * (width + 50)),
              width: 50,
              height: 6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class OdometerCounter extends StatelessWidget {
  final int value;
  final TextStyle style;

  const OdometerCounter({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      transitionBuilder: (Widget child, Animation<double> animation) {
        final inAnimation =
            Tween<Offset>(
              begin: const Offset(0.0, 0.5),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack, // spring
              ),
            );
        final outAnimation = Tween<Offset>(
          begin: const Offset(0.0, -0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeIn));

        if (child.key == ValueKey(value)) {
          return SlideTransition(
            position: inAnimation,
            child: FadeTransition(opacity: animation, child: child),
          );
        } else {
          return SlideTransition(
            position: outAnimation,
            child: FadeTransition(opacity: animation, child: child),
          );
        }
      },
      child: TweenAnimationBuilder<double>(
        key: ValueKey(value),
        tween: Tween<double>(begin: 1.08, end: 1.0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack, // spring
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: Text('$value', key: ValueKey(value), style: style),
      ),
    );
  }
}

class SetProgressDots extends StatefulWidget {
  final int totalSets;
  final int currentSet;
  final bool isCompleted;
  final ThemeColors theme;

  const SetProgressDots({
    super.key,
    required this.totalSets,
    required this.currentSet,
    required this.isCompleted,
    required this.theme,
  });

  @override
  State<SetProgressDots> createState() => _SetProgressDotsState();
}

class _SetProgressDotsState extends State<SetProgressDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.totalSets, (index) {
        final dotNum = index + 1;
        final isFilled = widget.isCompleted || dotNum < widget.currentSet;
        final isCurrent = !widget.isCompleted && dotNum == widget.currentSet;

        return _SetProgressDotItem(
          index: index,
          isFilled: isFilled,
          isCurrent: isCurrent,
          theme: widget.theme,
          pulseController: _pulseController,
          pulseScale: _pulseScale,
          pulseOpacity: _pulseOpacity,
        );
      }),
    );
  }
}

class TapCounterButton extends StatefulWidget {
  final int repsRemaining;
  final ThemeColors theme;
  final VoidCallback onTap;

  const TapCounterButton({
    super.key,
    required this.repsRemaining,
    required this.theme,
    required this.onTap,
  });

  @override
  State<TapCounterButton> createState() => _TapCounterButtonState();
}

class _TapCounterButtonState extends State<TapCounterButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  Offset? _tapPosition;
  double _rippleOpacity = 0.0;
  double _rippleRadius = 0.0;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _triggerRipple(TapUpDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
      _rippleOpacity = 0.2;
      _rippleRadius = 0.0;
    });

    const steps = 15;
    const stepDuration = Duration(milliseconds: 15);
    for (int i = 0; i <= steps; i++) {
      Future.delayed(stepDuration * i, () {
        if (!mounted) return;
        setState(() {
          _rippleRadius = (i / steps) * 60;
          _rippleOpacity = 0.2 * (1 - (i / steps));
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.repsRemaining == 0;
    final theme = widget.theme;

    final duration = const Duration(milliseconds: 300);
    final curve = Curves.easeOutBack; // spring

    final borderThemeColor = isDone ? theme.text3 : theme.teal;
    final bgThemeColor = isDone
        ? theme.card
        : theme.teal.withValues(alpha: 0.1);

    return GestureDetector(
      onTapDown: (_) {
        _pressController.forward();
      },
      onTapUp: (details) {
        _pressController.reverse();
        _triggerRipple(details);
        widget.onTap();
      },
      onTapCancel: () {
        _pressController.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: duration,
          curve: curve,
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgThemeColor,
            border: Border.all(color: borderThemeColor, width: 2.5),
          ),
          child: ClipOval(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: curve,
                  style: AppFonts.text(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDone ? theme.text3 : theme.teal,
                  ),
                  child: Text(isDone ? 'DONE' : 'TAP'),
                ),
                if (_tapPosition != null && _rippleOpacity > 0)
                  Positioned(
                    left: _tapPosition!.dx - _rippleRadius,
                    top: _tapPosition!.dy - _rippleRadius,
                    child: Container(
                      width: _rippleRadius * 2,
                      height: _rippleRadius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: _rippleOpacity),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExerciseLogRowWidget extends StatefulWidget {
  final int index;
  final ThemeColors theme;
  final List<String> exercise;
  final bool isLibrary;
  final bool completed;
  final int sets;
  final int reps;
  final String muscle;
  final VoidCallback onToggle;
  final VoidCallback onTapReps;

  const ExerciseLogRowWidget({
    super.key,
    required this.index,
    required this.theme,
    required this.exercise,
    required this.isLibrary,
    required this.completed,
    required this.sets,
    required this.reps,
    required this.muscle,
    required this.onToggle,
    required this.onTapReps,
  });

  @override
  State<ExerciseLogRowWidget> createState() => _ExerciseLogRowWidgetState();
}

class _ExerciseLogRowWidgetState extends State<ExerciseLogRowWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  String _getEquipmentTag() {
    final name = widget.exercise[0].toLowerCase();
    final desc = (widget.exercise.length > 2 ? widget.exercise[2] : '')
        .toLowerCase();
    if (name.contains('cable') || desc.contains('cable')) return 'CABLE';
    if (name.contains('band') || desc.contains('band')) return 'BAND';
    if (name.contains('machine') ||
        name.contains('press') ||
        desc.contains('machine') ||
        desc.contains('press')) {
      if (name.contains('bench') ||
          name.contains('push-up') ||
          name.contains('push up') ||
          name.contains('pike')) {
        return 'BW';
      }
      return 'MCH';
    }
    if (name.contains('assisted') || desc.contains('assisted')) {
      return 'ASSISTED';
    }
    return 'BW';
  }

  Widget _buildEquipmentTag(String tag) {
    Color bg;
    Color text;
    final isDark = widget.theme.isDark;
    switch (tag) {
      case 'BAND':
        bg = const Color(0x269B59B6);
        text = isDark ? const Color(0xFFBB8FCE) : const Color(0xFF8E44AD);
        break;
      case 'MCH':
        bg = const Color(0x263498DB);
        text = isDark ? const Color(0xFF7FB3D8) : const Color(0xFF2980B9);
        break;
      case 'ASSISTED':
        bg = const Color(0x26F1C40F);
        text = isDark ? const Color(0xFFD4C36A) : const Color(0xFFD35400);
        break;
      case 'CABLE':
        bg = const Color(0x26E74C3C);
        text = isDark ? const Color(0xFFE08880) : const Color(0xFFC0392B);
        break;
      case 'BW':
      default:
        bg = isDark ? const Color(0x0FFFFFFF) : const Color(0x14000000);
        text = widget.theme.text3;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  IconData get _categoryIcon {
    final name = widget.exercise[0].toLowerCase();
    if (name.contains('row') || name.contains('pull'))
      return Icons.sports_gymnastics;
    if (name.contains('plank') ||
        name.contains('raise') ||
        name.contains('crunch'))
      return Icons.self_improvement;
    if (name.contains('squat') || name.contains('lunge'))
      return Icons.directions_run;
    return Icons.fitness_center_outlined;
  }

  bool get _isIsometric {
    final name = widget.exercise[0].toLowerCase();
    return name.contains('plank') ||
        name.contains('hold') ||
        name.contains('wall sit');
  }

  String get primaryMuscle {
    if (widget.muscle.isNotEmpty) {
      final m = widget.muscle;
      return m[0].toUpperCase() + m.substring(1);
    }
    final name = widget.exercise[0].toLowerCase();
    if (name.contains('push-up') ||
        name.contains('push up') ||
        name.contains('bench')) {
      return 'Chest';
    }
    if (name.contains('squat') || name.contains('lunge')) return 'Quads';
    if (name.contains('bridge')) return 'Glutes';
    if (name.contains('row') ||
        name.contains('pull-up') ||
        name.contains('pull up')) {
      return 'Lats';
    }
    if (name.contains('press')) return 'Shoulders';
    if (name.contains('leg raise') || name.contains('plank')) return 'Core';
    if (name.contains('curl')) return 'Biceps';
    return 'Full Body';
  }

  Widget _buildMuscleTag(String muscle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.theme.isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: widget.theme.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Text(
        muscle,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: widget.theme.text3,
        ),
      ),
    );
  }

  int get difficulty {
    final desc = widget.exercise[1].toLowerCase();
    if (desc.contains('second')) return 3; // Hard
    final parsedReps = widget.reps;
    if (parsedReps <= 10) return 3; // Hard
    if (parsedReps <= 15) return 2; // Medium
    return 1; // Easy
  }

  Widget _buildSetIndicator() {
    return Text(
      '${widget.sets} sets',
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: widget.theme.text3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isFirstNextUp = widget.index == 0 && !widget.completed && !widget.isLibrary;

    // Spec Colors
    final dayAccent = const Color(0xFF0D9488);
    final nightAccent = const Color(0xFF2DD4A8);
    final accentCol = theme.isDark ? nightAccent : dayAccent;

    final primaryTextCol = theme.isDark ? const Color(0xFFE8E8F0) : const Color(0xFF1C1914);
    final secondaryTextCol = theme.isDark ? const Color(0xFF8B8B9A) : const Color(0xFF6B6560);
    final mutedTextCol = theme.isDark ? const Color(0xFF4A4A5A) : const Color(0xFFA8A29D);

    // Card background, border and shadow according to spec
    Color baseBg;
    BoxBorder border;
    List<BoxShadow> shadows = [];

    if (isFirstNextUp) {
      baseBg = theme.isDark
          ? nightAccent.withOpacity(0.04)
          : dayAccent.withOpacity(0.04);
      border = Border.all(
          color: theme.isDark
              ? nightAccent.withOpacity(0.25)
              : dayAccent.withOpacity(0.25),
          width: 1.5);
      
      shadows = [
        if (theme.isDark)
          BoxShadow(
            color: nightAccent.withOpacity(0.06),
            blurRadius: 20,
          )
        else
          BoxShadow(
            color: const Color(0xFF3C321E).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
      ];
    } else {
      baseBg = theme.isDark
          ? const Color(0xFF141423).withOpacity(0.55)
          : Colors.white.withOpacity(0.60);
      border = Border.all(
          color: theme.isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.white.withOpacity(0.70),
          width: 1);
      shadows = [
        BoxShadow(
          color: theme.isDark
              ? Colors.black.withOpacity(0.4)
              : const Color(0xFF3C321E).withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        )
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTapDown: (_) => _pressController.forward(),
          onTapUp: (_) {
            _pressController.reverse();
            HapticService.tapFeedback();
            SoundManager.playTapClick();
            widget.onTapReps();
          },
          onTapCancel: () => _pressController.reverse(),
          child: AnimatedBuilder(
            animation: _pressController,
            builder: (context, child) {
              final pressVal = _pressController.value;
              final scale = 1.0 - (0.02 * pressVal);

              return Transform.scale(
                scale: scale,
                child: AnimatedOpacity(
                  opacity: widget.completed ? 0.55 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    height: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: shadows,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: baseBg,
                            borderRadius: BorderRadius.circular(18),
                            border: border,
                          ),
                          child: Stack(
                            children: [
                              // Left Accent Bar (Item 1)
                              if (isFirstNextUp)
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 3,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: accentCol,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(18),
                                        bottomLeft: Radius.circular(18),
                                      ),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Row(
                                  children: [
                                    // Clean Left-Aligned Apple Order Number
                                    SizedBox(
                                      width: 24,
                                      child: Text(
                                        '${widget.index + 1}.',
                                        style: AppFonts.text(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isFirstNextUp
                                              ? accentCol
                                              : (widget.completed
                                                  ? accentCol
                                                  : mutedTextCol),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Name + Sets/Reps · PrimaryMuscle
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            normalizeExerciseName(widget.exercise[0]),
                                            style: AppFonts.text(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.41,
                                              color: primaryTextCol,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${widget.sets} × ${_isIsometric ? '${widget.reps} sec' : '${widget.reps}'} · ${primaryMuscle.split(',').first.trim()}',
                                            style: AppFonts.text(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                              letterSpacing: -0.08,
                                              color: secondaryTextCol,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Target Number + Unit + Last Benchmark Sub-line
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              '${widget.reps}',
                                              style: AppFonts.text(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w300,
                                                letterSpacing: -0.5,
                                                color: primaryTextCol,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              _isIsometric ? 'sec' : 'reps',
                                              style: AppFonts.text(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w400,
                                                letterSpacing: -0.08,
                                                color: mutedTextCol,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Last: ${widget.reps}',
                                          style: AppFonts.text(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: theme.isDark
                                                ? Colors.white38
                                                : Colors.black38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── GAMMA GAMIFICATION WIDGETS & HELPERS ──

Widget _animatedValueText(String text, Color color, double fontSize) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    transitionBuilder: (child, animation) {
      final inAnimation = Tween<Offset>(
        begin: const Offset(0.0, 0.4),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      return SlideTransition(
        position: inAnimation,
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    child: Text(
      text,
      key: ValueKey(text),
      style: AppFonts.text(
        fontSize: fontSize,
        color: color,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _StreakFireIcon extends StatefulWidget {
  final bool isActive;

  const _StreakFireIcon({required this.isActive});

  @override
  State<_StreakFireIcon> createState() => _StreakFireIconState();
}

class _StreakFireIconState extends State<_StreakFireIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _StreakFireIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isActive ? _scaleAnimation.value : 1.0,
          child: Icon(
            Icons.local_fire_department,
            size: 20,
            color: widget.isActive
                ? const Color(0xFFFF6B35)
                : const Color(0xFF5A5A6A),
          ),
        );
      },
    );
  }
}

class _StatCardWidget extends StatefulWidget {
  final Widget child;
  final Gradient? backgroundGradient;
  final ThemeColors theme;
  final VoidCallback? onTap;

  const _StatCardWidget({
    required this.child,
    required this.theme,
    this.backgroundGradient,
    this.onTap,
  });

  @override
  State<_StatCardWidget> createState() => _StatCardWidgetState();
}

class _StatCardWidgetState extends State<_StatCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.97),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.97, end: 1.02),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.02, end: 1.0),
        weight: 30,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: theme.isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.border, width: 0.5),
          gradient: widget.backgroundGradient,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap != null
                ? () {
                    _controller.forward(from: 0.0);
                    HapticService.tapFeedback();
                    SoundManager.playTapClick();
                    widget.onTap!();
                  }
                : () {
                    _controller.forward(from: 0.0);
                    HapticService.tapFeedback();
                    SoundManager.playTapClick();
                  },
            borderRadius: BorderRadius.circular(12),
            splashColor: const Color(0xFF00C896).withValues(alpha: 0.2),
            highlightColor: const Color(0xFF00C896).withValues(alpha: 0.1),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _ScrollRevealWidget extends StatefulWidget {
  final Widget child;
  final int index;
  final ScrollController scrollController;

  const _ScrollRevealWidget({
    required this.child,
    required this.index,
    required this.scrollController,
  });

  @override
  State<_ScrollRevealWidget> createState() => _ScrollRevealWidgetState();
}

class _ScrollRevealWidgetState extends State<_ScrollRevealWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _yOffset;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _yOffset = Tween<double>(
      begin: 15.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    widget.scrollController.addListener(_checkVisibility);

    // Staggered entry for initial items
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted && !_hasAnimated) {
        _triggerAnimation();
      }
    });
  }

  void _checkVisibility() {
    if (_hasAnimated || !mounted) return;
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;

    final size = renderObject.size;
    final position = renderObject.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    if (position.dy < screenHeight - 20 && position.dy + size.height > 0) {
      _triggerAnimation();
    }
  }

  void _triggerAnimation() {
    if (_hasAnimated) return;
    _hasAnimated = true;
    _controller.forward();
    widget.scrollController.removeListener(_checkVisibility);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_checkVisibility);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0.0, _yOffset.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _ShimmeringProgressBar extends StatefulWidget {
  final double value;
  final ThemeColors theme;

  const _ShimmeringProgressBar({required this.value, required this.theme});

  @override
  State<_ShimmeringProgressBar> createState() => _ShimmeringProgressBarState();
}

class _ShimmeringProgressBarState extends State<_ShimmeringProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: widget.value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Container(
          height: 10,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.isDark
                ? const Color(0x14FFFFFF)
                : const Color(0x0F000000),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Stack(
            children: [
              if (value > 0)
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.teal,
                                theme.teal.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, child) {
                            return Positioned.fill(
                              child: FractionallySizedBox(
                                widthFactor: 0.5,
                                alignment: Alignment(
                                  -1.5 + (_shimmerController.value * 3.0),
                                  0.0,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.25),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TapBurstButtonWrapper extends StatefulWidget {
  final int repsRemaining;
  final int totalReps;
  final ThemeColors theme;
  final VoidCallback onTap;

  const _TapBurstButtonWrapper({
    required this.repsRemaining,
    required this.totalReps,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_TapBurstButtonWrapper> createState() => _TapBurstButtonWrapperState();
}

class _TapBurstButtonWrapperState extends State<_TapBurstButtonWrapper>
    with TickerProviderStateMixin {
  final List<_TapParticle> _particles = [];
  final math.Random _random = math.Random();
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _triggerBurst() {
    final count = 6 + _random.nextInt(3);
    for (int i = 0; i < count; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final dist = 30.0 + _random.nextDouble() * 30.0;
      final size = 4.0 + _random.nextDouble() * 4.0;
      final duration = const Duration(milliseconds: 400);
      final opacity = 0.2 + _random.nextDouble() * 0.6;

      final controller = AnimationController(vsync: this, duration: duration);
      final p = _TapParticle(
        angle: angle,
        maxDist: dist,
        size: size,
        opacity: opacity,
        controller: controller,
      );

      setState(() {
        _particles.add(p);
      });

      controller.forward().then((_) {
        setState(() {
          _particles.remove(p);
        });
        controller.dispose();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final double progress = widget.totalReps > 0
        ? widget.repsRemaining / widget.totalReps
        : 0.0;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (_particles.isNotEmpty)
          ..._particles.map((p) {
            return AnimatedBuilder(
              animation: p.controller,
              builder: (context, child) {
                final val = p.controller.value;
                final distance = val * p.maxDist;
                final currentOpacity = (1.0 - val) * p.opacity;
                final dx = math.cos(p.angle) * distance;
                final dy = math.sin(p.angle) * distance;

                return Transform.translate(
                  offset: Offset(dx, dy),
                  child: Opacity(
                    opacity: currentOpacity.clamp(0.0, 1.0),
                    child: Container(
                      width: p.size,
                      height: p.size,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF00C896),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

        SizedBox(
          width: 146,
          height: 146,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 1.0, end: progress),
            duration: const Duration(milliseconds: 200),
            builder: (context, value, child) {
              return CustomPaint(
                painter: _CircularProgressRingPainter(
                  progress: value,
                  color: const Color(0xFF00C896),
                  trackColor: theme.isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x0A000000),
                ),
              );
            },
          ),
        ),

        TapCounterButton(
          repsRemaining: widget.repsRemaining,
          theme: theme,
          onTap: () {
            if (widget.repsRemaining > 0) {
              _triggerBurst();
            }
            widget.onTap();
          },
        ),
      ],
    );
  }
}

class _TapParticle {
  final double angle;
  final double maxDist;
  final double size;
  final double opacity;
  final AnimationController controller;

  _TapParticle({
    required this.angle,
    required this.maxDist,
    required this.size,
    required this.opacity,
    required this.controller,
  });
}

class _CircularProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _CircularProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = 3.0;
    final radius = (size.width - strokeW) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

class _ComboIndicator extends StatefulWidget {
  final int combo;

  const _ComboIndicator({required this.combo});

  @override
  State<_ComboIndicator> createState() => _ComboIndicatorState();
}

class _ComboIndicatorState extends State<_ComboIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(covariant _ComboIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.combo != oldWidget.combo && widget.combo > 1) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.combo <= 1) {
      return const SizedBox(height: 20);
    }
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Text(
        'x${widget.combo} COMBO',
        style: AppFonts.display(
          fontSize: 16,
          color: const Color(0xFFE8B84B),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SetProgressDotItem extends StatefulWidget {
  final int index;
  final bool isFilled;
  final bool isCurrent;
  final ThemeColors theme;
  final AnimationController pulseController;
  final Animation<double> pulseScale;
  final Animation<double> pulseOpacity;

  const _SetProgressDotItem({
    required this.index,
    required this.isFilled,
    required this.isCurrent,
    required this.theme,
    required this.pulseController,
    required this.pulseScale,
    required this.pulseOpacity,
  });

  @override
  State<_SetProgressDotItem> createState() => _SetProgressDotItemState();
}

class _SetProgressDotItemState extends State<_SetProgressDotItem>
    with TickerProviderStateMixin {
  late AnimationController _starController;
  final List<_StarParticle> _stars = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _starController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 600),
          )
          ..addListener(() {
            setState(() {
              final t = _starController.value;
              for (int i = 0; i < _stars.length; i++) {
                final s = _stars[i];
                final y = -t * s.maxY;
                final x = t * s.driftX;
                final op = 1.0 - t;
                _stars[i] = _StarParticle(
                  x: x,
                  y: y,
                  opacity: op,
                  maxY: s.maxY,
                  driftX: s.driftX,
                );
              }
            });
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              setState(() {
                _stars.clear();
              });
            }
          });
  }

  @override
  void didUpdateWidget(covariant _SetProgressDotItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFilled && !oldWidget.isFilled) {
      _triggerStarBurst();
    }
  }

  void _triggerStarBurst() {
    _stars.clear();
    for (int i = 0; i < 3; i++) {
      final maxY = 40.0 + _random.nextDouble() * 40.0;
      final driftX = -15.0 + _random.nextDouble() * 30.0;
      _stars.add(
        _StarParticle(x: 0, y: 0, opacity: 1.0, maxY: maxY, driftX: driftX),
      );
    }
    _starController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (_stars.isNotEmpty)
          ..._stars.map((s) {
            return Positioned(
              left: s.x,
              top: s.y - 12.0,
              child: IgnorePointer(
                child: Opacity(
                  opacity: s.opacity,
                  child: const Text(
                    '★',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE8B84B)),
                  ),
                ),
              ),
            );
          }),

        widget.isCurrent
            ? AnimatedBuilder(
                animation: widget.pulseController,
                builder: (context, child) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14 * widget.pulseScale.value,
                    height: 14 * widget.pulseScale.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.theme.teal.withValues(
                        alpha: widget.pulseOpacity.value,
                      ),
                      border: Border.all(color: widget.theme.teal, width: 2),
                    ),
                  );
                },
              )
            : AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isFilled
                      ? widget.theme.teal
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.isFilled
                        ? widget.theme.teal
                        : widget.theme.text3,
                    width: 2,
                  ),
                ),
              ),
      ],
    );
  }
}

class _StarParticle {
  final double x;
  final double y;
  final double opacity;
  final double maxY;
  final double driftX;

  _StarParticle({
    required this.x,
    required this.y,
    required this.opacity,
    required this.maxY,
    required this.driftX,
  });
}

class _SetTransitionNumberWidget extends StatefulWidget {
  final int value;
  final int currentSet;
  final TextStyle style;

  const _SetTransitionNumberWidget({
    required this.value,
    required this.currentSet,
    required this.style,
  });

  @override
  State<_SetTransitionNumberWidget> createState() =>
      _SetTransitionNumberWidgetState();
}

class _SetTransitionNumberWidgetState extends State<_SetTransitionNumberWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;
  late int _displayValue;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);
    _offset = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -0.5),
    ).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _SetTransitionNumberWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentSet != oldWidget.currentSet) {
      _offset = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0.0, -0.5),
      ).animate(_controller);
      _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);
      _controller.forward(from: 0.0).then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _displayValue = widget.value;
            });
            _offset = Tween<Offset>(
              begin: const Offset(0.0, 0.5),
              end: Offset.zero,
            ).animate(_controller);
            _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
            _controller.forward(from: 0.0);
          }
        });
      });
    } else {
      if (widget.value != _displayValue && !_controller.isAnimating) {
        setState(() {
          _displayValue = widget.value;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _offset.value * 40.0,
            child: Text('$_displayValue', style: widget.style),
          ),
        );
      },
    );
  }
}

class _ExerciseCompleteOverlay extends StatefulWidget {
  final String exerciseName;
  final VoidCallback onFinished;
  final ThemeColors theme;

  const _ExerciseCompleteOverlay({
    required this.exerciseName,
    required this.onFinished,
    required this.theme,
  });

  @override
  State<_ExerciseCompleteOverlay> createState() =>
      _ExerciseCompleteOverlayState();
}

class _ExerciseCompleteOverlayState extends State<_ExerciseCompleteOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _checkController;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeInOut),
    );

    _fadeController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _checkController.forward();
        }
      });

      Future.delayed(const Duration(milliseconds: 2300), () {
        if (mounted) {
          _fadeController.reverse().then((_) {
            widget.onFinished();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.black.withValues(alpha: 0.7),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: widget.theme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.theme.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: AnimatedBuilder(
                  animation: _checkAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _SelfDrawingCheckPainter(
                        progress: _checkAnimation.value,
                        color: const Color(0xFF00C896),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.exerciseName,
                textAlign: TextAlign.center,
                style: AppFonts.text(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.theme.text1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'COMPLETED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Color(0xFF00C896),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelfDrawingCheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SelfDrawingCheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.25, size.height * 0.5);
    path.lineTo(size.width * 0.45, size.height * 0.7);
    path.lineTo(size.width * 0.75, size.height * 0.35);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final drawPath = Path();
    double totalLength = metrics.fold(0.0, (sum, m) => sum + m.length);
    double targetLength = totalLength * progress;

    double currentLength = 0.0;
    for (var metric in metrics) {
      if (currentLength + metric.length <= targetLength) {
        drawPath.addPath(metric.extractPath(0.0, metric.length), Offset.zero);
        currentLength += metric.length;
      } else {
        double remaining = targetLength - currentLength;
        drawPath.addPath(metric.extractPath(0.0, remaining), Offset.zero);
        break;
      }
    }

    canvas.drawPath(drawPath, paint);
  }

  @override
  bool shouldRepaint(covariant _SelfDrawingCheckPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _WorkoutCompleteOverlay extends StatefulWidget {
  final ThemeColors theme;
  final int exercisesCompleted;
  final int totalReps;
  final int minutesSpent;
  final VoidCallback onContinue;
  final VoidCallback onDismiss;

  const _WorkoutCompleteOverlay({
    required this.theme,
    required this.exercisesCompleted,
    required this.totalReps,
    required this.minutesSpent,
    required this.onContinue,
    required this.onDismiss,
  });

  @override
  State<_WorkoutCompleteOverlay> createState() =>
      _WorkoutCompleteOverlayState();
}

class _WorkoutCompleteOverlayState extends State<_WorkoutCompleteOverlay>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _checkmarkController;
  final List<_ConfettiParticle> _particles = [];
  bool _initializedConfetti = false;

  bool _showTitle = false;
  bool _showStat1 = false;
  bool _showStat2 = false;
  bool _showStat3 = false;
  bool _showButton = false;

  @override
  void initState() {
    super.initState();

    _confettiController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addListener(() {
            setState(() {
              for (var p in _particles) {
                p.update();
              }
            });
          });

    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _checkmarkController.forward();
      }
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showTitle = true);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showStat1 = true);
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showStat2 = true);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showStat3 = true);
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showButton = true);
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _checkmarkController.dispose();
    super.dispose();
  }

  void _initConfetti(double width) {
    if (_initializedConfetti) return;
    _initializedConfetti = true;
    for (int i = 0; i < 25; i++) {
      _particles.add(_ConfettiParticle(width));
    }
    _confettiController.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final primaryTeal = theme.isDark ? const Color(0xFF2DD4A8) : const Color(0xFF0D9488);
    final textPrim = theme.isDark ? const Color(0xFFE8E8F0) : const Color(0xFF1C1914);
    final textSec = theme.isDark ? const Color(0xFF8B8B9A) : const Color(0xFF6B6560);

    return LayoutBuilder(
      builder: (context, constraints) {
        _initConfetti(constraints.maxWidth);
        return GestureDetector(
          onTap: widget.onDismiss,
          child: Container(
            color: theme.isDark
                ? const Color(0xFF0B0B14).withOpacity(0.88)
                : const Color(0xFFF0EDE6).withOpacity(0.88),
            alignment: Alignment.center,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _ConfettiPainter(particles: _particles),
                ),

                Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: theme.isDark
                                ? Colors.black.withOpacity(0.5)
                                : const Color(0xFF3C321E).withOpacity(0.12),
                            blurRadius: 36,
                            offset: const Offset(0, 12),
                          ),
                          if (theme.isDark)
                            BoxShadow(
                              color: primaryTeal.withOpacity(0.06),
                              blurRadius: 40,
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: theme.isDark
                                  ? const Color(0xFF141423).withOpacity(0.75)
                                  : Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: theme.isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.white.withOpacity(0.9),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: AnimatedBuilder(
                                    animation: _checkmarkController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        painter: _SelfDrawingCheckPainter(
                                          progress: _checkmarkController.value,
                                          color: primaryTeal,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),

                                AnimatedOpacity(
                                  opacity: _showTitle ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: Column(
                                    children: [
                                      Text(
                                        'WORKOUT COMPLETE!',
                                        textAlign: TextAlign.center,
                                        style: AppFonts.display(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: textPrim,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Session finished · Rest & recover',
                                        textAlign: TextAlign.center,
                                        style: AppFonts.text(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: textSec,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                Row(
                                  children: [
                                    Expanded(
                                      child: AnimatedOpacity(
                                        opacity: _showStat1 ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: _buildSummaryStatCard(
                                          '${widget.exercisesCompleted}',
                                          'exercises',
                                          theme,
                                          primaryTeal,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: AnimatedOpacity(
                                        opacity: _showStat2 ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: _buildSummaryStatCard(
                                          '${widget.totalReps}',
                                          'reps',
                                          theme,
                                          primaryTeal,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: AnimatedOpacity(
                                        opacity: _showStat3 ? 1.0 : 0.0,
                                        duration: const Duration(milliseconds: 300),
                                        child: _buildSummaryStatCard(
                                          '${widget.minutesSpent}m',
                                          'time spent',
                                          theme,
                                          primaryTeal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),

                                AnimatedOpacity(
                                  opacity: _showButton ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: GestureDetector(
                                    onTap: widget.onContinue,
                                    child: Container(
                                      height: 52,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: primaryTeal,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryTeal.withOpacity(0.35),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Back to Home',
                                        style: AppFonts.text(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: theme.isDark ? Colors.black : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryStatCard(String value, String label, ThemeColors theme, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: theme.isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppFonts.display(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppFonts.text(
              fontSize: 10,
              color: theme.isDark ? const Color(0xFF8B8B9A) : const Color(0xFF6B6560),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiParticle {
  late double x;
  late double y;
  late double speed;
  late double angle;
  late double rotationSpeed;
  late Color color;
  late double opacity;
  late bool isCircle;
  late double size;

  _ConfettiParticle(double screenWidth) {
    final random = math.Random();
    x = random.nextDouble() * screenWidth;
    y = -random.nextDouble() * 200.0 - 20.0;
    speed = 2.0 + random.nextDouble() * 3.0;
    angle = random.nextDouble() * 2 * math.pi;
    rotationSpeed = -2.0 + random.nextDouble() * 4.0;
    size = 6.0 + random.nextDouble() * 8.0;
    isCircle = random.nextBool();
    opacity = 0.6 + random.nextDouble() * 0.4;

    final colors = [
      const Color(0xFFE8B84B),
      const Color(0xFF00C896),
      Colors.white,
    ];
    color = colors[random.nextInt(colors.length)];
  }

  void update() {
    y += speed;
    x += math.sin(y / 30) * 0.5;
    angle += rotationSpeed * 0.02;
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.angle);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size / 2,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

class _CompletionCheckWidget extends StatefulWidget {
  final bool completed;
  final VoidCallback onTap;
  final ThemeColors theme;

  const _CompletionCheckWidget({
    required this.completed,
    required this.onTap,
    required this.theme,
  });

  @override
  State<_CompletionCheckWidget> createState() => _CompletionCheckWidgetState();
}

class _CompletionCheckWidgetState extends State<_CompletionCheckWidget>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScale;

  late AnimationController _rippleController;
  late Animation<double> _rippleScale;
  late Animation<double> _rippleOpacity;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _checkScale =
        TweenSequence([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.0, end: 1.2),
            weight: 70,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.2, end: 1.0),
            weight: 30,
          ),
        ]).animate(
          CurvedAnimation(parent: _checkController, curve: Curves.easeOutBack),
        );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _rippleScale = Tween<double>(begin: 1.0, end: 3.5).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    _rippleOpacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    if (widget.completed) {
      _checkController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _CompletionCheckWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed && !oldWidget.completed) {
      _checkController.forward(from: 0.0);
      _rippleController.forward(from: 0.0);
    } else if (!widget.completed && oldWidget.completed) {
      _checkController.reverse();
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, child) {
              if (_rippleController.value == 0 ||
                  _rippleController.value == 1) {
                return const SizedBox.shrink();
              }
              return Container(
                width: 20 * _rippleScale.value,
                height: 20 * _rippleScale.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.theme.teal.withValues(
                    alpha: _rippleOpacity.value,
                  ),
                ),
              );
            },
          ),

          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.completed
                    ? widget.theme.teal
                    : widget.theme.text3,
                width: 2,
              ),
              color: Colors.transparent,
            ),
          ),

          ScaleTransition(
            scale: _checkScale,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.theme.teal,
              ),
              child: const Center(
                child: Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAddButton extends StatefulWidget {
  final VoidCallback onTap;
  final ThemeColors theme;

  const _HeaderAddButton({required this.onTap, required this.theme});

  @override
  State<_HeaderAddButton> createState() => _HeaderAddButtonState();
}

class _HeaderAddButtonState extends State<_HeaderAddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.9), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.9, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: () {
          _controller.forward(from: 0.0);
          HapticService.tapFeedback();
          SoundManager.playTapClick();
          widget.onTap();
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: widget.theme.gold.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.theme.gold.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.theme.gold.withValues(alpha: 0.08),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(Icons.add, color: widget.theme.gold, size: 18),
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  final ThemeColors theme;
  final String userName;
  final int userGoalYear;
  final int userGoalMonth;
  final int userGoalDay;
  final String userDob;
  final Function(String, int, int, int, String)? onProfileChanged;
  final VoidCallback onSaved;
  final VoidCallback? onResetToday;

  const _SettingsSheet({
    required this.theme,
    required this.userName,
    required this.userGoalYear,
    required this.userGoalMonth,
    required this.userGoalDay,
    required this.userDob,
    this.onProfileChanged,
    required this.onSaved,
    this.onResetToday,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  String _locationName = '';
  String _selectedMethod = 'MuslimWorldLeague';
  String _selectedMadhab = 'Shafi';
  bool _detecting = false;

  final Map<String, List<double>> _cityPresets = {
    'Delhi, India': [28.6139, 77.2090],
    'Mumbai, India': [19.0760, 72.8777],
    'Kolkata, India': [22.5726, 88.3639],
    'Chennai, India': [13.0827, 80.2707],
    'Hyderabad, India': [17.3850, 78.4867],
    'Karachi, Pakistan': [24.8607, 67.0011],
    'Dhaka, Bangladesh': [23.8103, 90.4125],
    'Mecca, Saudi Arabia': [21.3891, 39.8579],
    'Medina, Saudi Arabia': [24.4672, 39.6111],
    'Cairo, Egypt': [30.0444, 31.2357],
    'London, UK': [51.5074, -0.1278],
    'New York, US': [40.7128, -74.0060],
    'Jakarta, Indonesia': [-6.2088, 106.8456],
    'Kuala Lumpur, Malaysia': [3.1390, 101.6869],
    'Singapore': [1.3521, 103.8198],
    'Istanbul, Turkey': [41.0082, 28.9784],
  };

  bool _showAdvancedTimings = false;

  int getAgeFromDob(String dobStr) {
    final dob = DateTime.tryParse(dobStr) ?? DateTime(2000, 1, 1);
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _latController.text = (prefs.getDouble('prayer_latitude') ?? 28.6139)
          .toString();
      _lonController.text = (prefs.getDouble('prayer_longitude') ?? 77.2090)
          .toString();
      _locationName = prefs.getString('prayer_location_name') ?? 'Delhi, India';
      _selectedMethod = prefs.getString('prayer_calc_method') ?? 'Karachi';
      _selectedMadhab = prefs.getString('prayer_madhab') ?? 'Shafi';
    });
  }

  Future<void> _detectLocation() async {
    setState(() => _detecting = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('prayer_latitude');
    await detectLocationByIp();
    await _loadCurrentSettings();
    setState(() => _detecting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Detected location: $_locationName'),
          backgroundColor: widget.theme.teal,
        ),
      );
    }
  }

  void _showEditNameDialog(BuildContext context, ThemeColors theme) {
    final nameController = TextEditingController(text: widget.userName);
    DateTime tempDate = DateTime(
      widget.userGoalYear,
      widget.userGoalMonth,
      widget.userGoalDay,
    );
    // FIXED: declared outside builder so it persists across setDialogState() rebuilds
    DateTime tempDob =
        DateTime.tryParse(widget.userDob) ?? DateTime(2000, 1, 1);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            String formatDate(DateTime date) {
              const months = [
                'January',
                'February',
                'March',
                'April',
                'May',
                'June',
                'July',
                'August',
                'September',
                'October',
                'November',
                'December',
              ];
              return '${months[date.month - 1]} ${date.day}, ${date.year}';
            }

            Future<void> pickDialogDate() async {
              final DateTime? picked = await showDatePicker(
                context: dialogContext,
                initialDate: tempDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF1D9E75),
                        onPrimary: Colors.white,
                        surface: Color(0xFF1C1C2E),
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null && picked != tempDate) {
                setDialogState(() {
                  tempDate = picked;
                });
              }
            }

            Future<void> pickDobDate() async {
              final DateTime? picked = await showDatePicker(
                context: dialogContext,
                initialDate: tempDob,
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF1D9E75),
                        onPrimary: Colors.white,
                        surface: Color(0xFF1C1C2E),
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null && picked != tempDob) {
                setDialogState(() {
                  tempDob = picked;
                });
              }
            }

            return AlertDialog(
              backgroundColor: theme.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.border, width: 0.5),
              ),
              title: Text(
                'Edit Profile',
                style: AppFonts.display(
                  fontWeight: FontWeight.w800,
                  color: theme.text1,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Name',
                      style: AppFonts.text(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.text2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameController,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Please enter your name'
                          : null,
                      style: TextStyle(color: theme.text1),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.isDark
                            ? const Color(0x0AFFFFFF)
                            : const Color(0xFFF9F9F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: theme.border,
                            width: 0.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: theme.teal, width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your Date of Birth',
                      style: AppFonts.text(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.text2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: pickDobDate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.isDark
                              ? const Color(0x0AFFFFFF)
                              : const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.border, width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatDate(tempDob),
                              style: TextStyle(
                                color: theme.text1,
                                fontSize: 14,
                              ),
                            ),
                            Icon(Icons.cake, color: theme.gold, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Goal Deadline Date',
                      style: AppFonts.text(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.text2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: pickDialogDate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.isDark
                              ? const Color(0x0AFFFFFF)
                              : const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.border, width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatDate(tempDate),
                              style: TextStyle(
                                color: theme.text1,
                                fontSize: 14,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: theme.gold,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: AppFonts.text(
                      fontWeight: FontWeight.w600,
                      color: theme.text3,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      final name = nameController.text.trim();
                      final dobStr =
                          "${tempDob.year.toString().padLeft(4, '0')}-${tempDob.month.toString().padLeft(2, '0')}-${tempDob.day.toString().padLeft(2, '0')}";
                      if (widget.onProfileChanged != null) {
                        widget.onProfileChanged!(
                          name,
                          tempDate.year,
                          tempDate.month,
                          tempDate.day,
                          dobStr,
                        );
                      }
                      Navigator.pop(dialogContext);
                      HapticService.tapFeedback();
                      SoundManager.playTapClick();
                      widget.onSaved();
                      setState(() {});
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: AppFonts.text(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveSettings() async {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid coordinates'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('prayer_latitude', lat);
    await prefs.setDouble('prayer_longitude', lon);
    await prefs.setString('prayer_location_name', _locationName);
    await prefs.setString('prayer_calc_method', _selectedMethod);
    await prefs.setString('prayer_madhab', _selectedMadhab);

    await updatePrayerTimesForLocation();
    widget.onSaved();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3.5,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A843),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Settings',
                      style: AppFonts.display(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.text1,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                    child: Icon(Icons.close, color: theme.text3, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 1. Profile Settings
            Text(
              'ACCOUNT & PROFILE',
              style: AppFonts.text(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.text3,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.025),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      'Profile Information',
                      style: AppFonts.text(
                        color: theme.text1,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      widget.userName.isNotEmpty
                          ? '${widget.userName} • ${getAgeFromDob(widget.userDob)} y/o'
                          : 'Set name, Date of Birth & goal',
                      style: AppFonts.text(color: theme.text3, fontSize: 11),
                    ),
                    trailing: Icon(Icons.chevron_right, color: theme.text3, size: 18),
                    onTap: () => _showEditNameDialog(context, theme),
                  ),
                  Divider(color: theme.border, height: 0.5, thickness: 0.5),
                  ListTile(
                    title: Text(
                      'Replay Setup (Demo Mode)',
                      style: AppFonts.text(
                        color: theme.text1,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Restart the guided onboarding tour',
                      style: AppFonts.text(color: theme.text3, fontSize: 11),
                    ),
                    trailing: const Icon(Icons.play_circle_outline, color: Color(0xFF2DD4A8), size: 20),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const OnboardingScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Prayer Calculation & Location
            Text(
              'PRAYER CALCULATION & LOCATION',
              style: AppFonts.text(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.text3,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.025),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFFD4A843), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location',
                          style: AppFonts.text(
                            color: theme.text3,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _locationName.isNotEmpty
                              ? _locationName
                              : 'Detecting...',
                          style: AppFonts.text(
                            color: theme.text1,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _detecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFD4A843),
                          ),
                        )
                      : TextButton.icon(
                          onPressed: _detectLocation,
                          icon: const Icon(
                            Icons.my_location,
                            size: 14,
                            color: Color(0xFF2DD4A8),
                          ),
                          label: Text(
                            'Auto Detect',
                            style: AppFonts.text(
                              color: const Color(0xFF2DD4A8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Calculation Method Dropdown (Directly visible)
            Text(
              'Calculation Method',
              style: AppFonts.text(
                color: theme.text2,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.025),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedMethod,
                  dropdownColor: theme.bg,
                  style: AppFonts.text(color: theme.text1, fontSize: 13),
                  items: const [
                    DropdownMenuItem(
                      value: 'Karachi',
                      child: Text('University of Islamic Sciences, Karachi'),
                    ),
                    DropdownMenuItem(
                      value: 'Mecca',
                      child: Text('Umm al-Qura University, Makkah'),
                    ),
                    DropdownMenuItem(
                      value: 'MuslimWorldLeague',
                      child: Text('Muslim World League (MWL)'),
                    ),
                    DropdownMenuItem(
                      value: 'Egypt',
                      child: Text('Egyptian General Authority of Survey'),
                    ),
                    DropdownMenuItem(
                      value: 'Gulf',
                      child: Text('Gulf Region (Dubai)'),
                    ),
                    DropdownMenuItem(
                      value: 'NorthAmerica',
                      child: Text('ISNA (North America)'),
                    ),
                    DropdownMenuItem(
                      value: 'Singapore',
                      child: Text('MUIS (Singapore)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMethod = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Save Settings CTA Button
            GestureDetector(
              onTap: _saveSettings,
              child: Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF2DD4A8),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2DD4A8).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Save Settings',
                  style: AppFonts.text(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            if (widget.onResetToday != null) ...[
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () => _confirmResetToday(context, theme),
                  icon: const Icon(Icons.refresh, size: 14, color: Color(0xFFE54D2E)),
                  label: Text(
                    'Reset Today\'s Progress',
                    style: AppFonts.text(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE54D2E),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmResetToday(BuildContext context, ThemeColors theme) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reset Today\'s Progress?',
          style: AppFonts.display(color: theme.text1, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will clear all tracked prayers, tasks, and water intake for today. This action cannot be undone.',
          style: AppFonts.text(color: theme.text2, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: AppFonts.text(color: theme.text3)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE54D2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              widget.onResetToday?.call();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Today\'s progress has been reset.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text('Reset', style: AppFonts.text(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}