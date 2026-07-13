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
import 'package:success/services/haptic_service.dart';
import 'package:success/services/audio_service.dart';
import 'package:success/services/sound_manager.dart';
import 'package:success/widgets/stick_figure_painter.dart';

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

final kDefaultTodayTasks = <TodayTask>[];

List<TodayTask> kTodayTasks = List<TodayTask>.from(kDefaultTodayTasks);

const kPrayerNames = [
  'Tahajjud',
  'Fajr',
  'Dhuha',
  'Dhuhr',
  'Asr',
  'Maghrib',
  'Isha',
];

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
  DayRecord({required this.tasks, required this.prayers, this.workoutSummary});

  factory DayRecord.empty() {
    return DayRecord(
      tasks: List<bool>.filled(kTodayTasks.length, false),
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
    return MaterialApp(
      title: 'RAYEES',
      debugShowCheckedModeBanner: false,
      themeMode: themeNotifier.mode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const BootScreen(),
    );
  }
}

final lightTheme = _appTheme(Brightness.light);
final darkTheme = _appTheme(Brightness.dark);

ThemeData _appTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    brightness: brightness,
    fontFamily: 'NotoNaskhArabic',
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF1C1C2E)
        : const Color(0xFFF5F0E8),
    cardColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFFFFFFF),
    primaryColor: const Color(0xFF1D9E75),
    textTheme: _withArabicFallback(
      TextTheme(
        bodyLarge: TextStyle(
          fontSize: 15,
          color: isDark ? const Color(0xFFF2F2FF) : const Color(0xFF1A1A2E),
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFFF2F2FF) : const Color(0xFF1A1A2E),
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF9090BB) : const Color(0xFF8A8580),
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFF2F2FF) : const Color(0xFF1A1A2E),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFF2F2FF) : const Color(0xFF1A1A2E),
        ),
      ),
    ),
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
  int _waterGlasses = 0;

  String _userName = '';
  int _userGoalYear = 2027;
  int _userGoalMonth = 1;
  int _userGoalDay = 1;

  DayRecord get _today => _recordFor(DateTime.now());

  DateTime _lastDate = DateTime.now();

  @override
  void initState() {
    super.initState();
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
    if (mounted) {
      setState(() {
        if (name != null) _userName = name;
        if (year != null) _userGoalYear = year;
        if (month != null) _userGoalMonth = month;
        if (day != null) _userGoalDay = day;
      });
    }
  }

  Future<void> _updateProfile(String name, int year, int month, int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setInt('user_goal_year', year);
    await prefs.setInt('user_goal_month', month);
    await prefs.setInt('user_goal_day', day);
    if (mounted) {
      setState(() {
        _userName = name;
        _userGoalYear = year;
        _userGoalMonth = month;
        _userGoalDay = day;
      });
    }
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
        for (final entry in decoded.entries) {
          _history[entry.key] = DayRecord.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    } catch (_) {}
    _history.putIfAbsent(dayKey(DateTime.now()), DayRecord.empty);
    if (mounted) {
      setState(() => _loaded = true);
    }
  }

  DayRecord _recordFor(DateTime date) {
    return _history.putIfAbsent(dayKey(date), DayRecord.empty);
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
      final value = int.tryParse(raw ?? '') ?? 0;
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
    final isChecked = !_today.tasks[index];
    setState(() => _today.tasks[index] = isChecked);
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
    final pdf = buildPdf(_reportLines());
    final fileName = 'rayees_30_day_report_${dayKey(DateTime.now())}.pdf';
    try {
      final path = await _channel.invokeMethod<String>('savePdfToDownloads', {
        'fileName': fileName,
        'bytes': pdf,
      });
      if (!mounted) {
        return;
      }
      setState(() => _lastPdfPath = path ?? 'Downloads/$fileName');
      messenger.showSnackBar(
        SnackBar(content: Text('PDF saved: ${path ?? fileName}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('PDF save failed: $error')),
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
        lines.add(
          '  ${record.tasks[t] ? '[x]' : '[ ]'} ${kTodayTasks[t].title}',
        );
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
          onProfileChanged: _updateProfile,
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
          onNameChanged: _updateProfile,
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

    return RepaintBoundary(
      key: _screenshotKey,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: List.generate(screens.length, (index) {
              final isCurrent = index == _tab;
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
          bottomNavigationBar: _BottomNavBar(
            selectedIndex: _tab,
            onTap: (i) {
              if (_tab != i) {
                HapticService.selection();
                setState(() => _tab = i);
              }
            },
            theme: _theme,
          ),
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
  final ThemeColors theme; // Not used in this file, but kept for consistency

  @override
  State<_BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<_BottomNavBar>
    with SingleTickerProviderStateMixin {
  static const _icons = [
    Icons.home_outlined,
    Icons.check_circle_outline,
    Icons.fitness_center_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.flag_outlined,
  ];

  static const _labels = ['Today', 'Habits', 'Workout', 'Income', 'Plan'];

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final navBg = theme.isDark ? cBg : theme.navBg;
    final bubbleColor = theme.teal; // matches active theme color
    final inactiveColor = theme.isDark ? Colors.white38 : Colors.black38;

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
              children: List.generate(5, (i) {
                final isSelected = widget.selectedIndex == i;
                return Expanded(
                  child: InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () {
                      HapticService.tapFeedback();
                      widget.onTap(i);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedPadding(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack, // spring easing
                          padding: EdgeInsets.only(bottom: isSelected ? 4 : 0),
                          child: AnimatedScale(
                            scale: isSelected ? 1.15 : 0.95,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutBack, // spring easing
                            child: Icon(
                              _icons[i],
                              size: 22,
                              color: isSelected ? bubbleColor : inactiveColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _labels[i],
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            letterSpacing: 0.3,
                            color: isSelected ? bubbleColor : inactiveColor,
                          ),
                        ),
                      ],
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
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: theme.gold,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DAILY SCORE',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.text4,
                          fontWeight: FontWeight.w700,
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: widget.theme.text1,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            style: TextStyle(color: widget.theme.text1),
            decoration: InputDecoration(
              labelText: 'Task name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tagCtrl,
            style: TextStyle(color: widget.theme.text1),
            decoration: InputDecoration(
              labelText: 'Time / condition subtitle',
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
    this.onProfileChanged,
  });

  final Function(String, int, int, int)? onProfileChanged;

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
  String _fastStatus = 'fasting';
  bool _suhoorAlarmSet = false;
  int get _ayahIndex {
    final now = DateTime.now();
    final day = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(now.year, 1, 1)).inDays;
    return day % _TodayScreenState.ayahs.length;
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

  int get _visibleTaskDone =>
      _visibleTasks.where((entry) => widget.record.tasks[entry.key]).length;

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
        onProfileChanged: widget.onProfileChanged,
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

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Create 8 staggered animation intervals
    for (int i = 0; i < 10; i++) {
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
    final nextDate = '${now.day} ${months[now.month - 1]} ${now.year}';
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
    final time = _prayerTimes[prayer];
    if (time == null) return false;
    final now = DateTime.now();
    final prayerTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return now.isAfter(prayerTime);
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

  Widget _taskRow(MapEntry<int, TodayTask> entry) {
    final task = entry.value;
    final done = widget.record.tasks[entry.key];

    Widget card = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: _GlassCard(
        theme: widget.theme,
        border: Border.all(color: widget.theme.border, width: 0.5),
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => widget.onTaskToggle(entry.key),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: done ? const Color(0xFFFF007F) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: done
                      ? null
                      : Border.all(color: widget.theme.border, width: 1.5),
                  boxShadow: done
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFFF007F,
                            ).withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: done
                    ? Icon(Icons.check, color: widget.theme.bg, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: GoogleFonts.syne(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: done
                          ? const Color(0xFFFF007F).withValues(alpha: 0.6)
                          : widget.theme.text1,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    _taskSubtitle(entry),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: widget.theme.text3,
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
                color: widget.theme.text4,
              ),
            ),
          ],
        ),
      ),
    );

    return done ? Opacity(opacity: 0.6, child: card) : card;
  }

  Widget _suhoorReminderCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.theme.text2.withValues(alpha: 0.22),
            widget.theme.blue.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.theme.blue.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suhoor Tomorrow',
                  style: GoogleFonts.syne(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: widget.theme.text3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '4:38 AM',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: widget.theme.text1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Before Fajr → Mon fast',
                  style: TextStyle(fontSize: 11, color: widget.theme.text3),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _suhoorAlarmSet
                  ? widget.theme.teal
                  : widget.theme.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => setState(() => _suhoorAlarmSet = true),
            child: Text(_suhoorAlarmSet ? '✓ Set' : 'Set Alarm'),
          ),
        ],
      ),
    );
  }

  Widget _waterTracker() {
    final double consumed = (widget.waterGlasses * 260) / 1000;

    return _GlassCard(
      theme: widget.theme,
      glowColor: const Color(0xFF38BDF8),
      radius: 16,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\u{1F4A7} Water Intake',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.theme.text1,
                ),
              ),
              Text(
                '${consumed.toStringAsFixed(1)} L / 2.6 L goal',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: widget.theme.text3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: widget.waterGlasses / 10.0,
              minHeight: 4,
              backgroundColor: widget.theme.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : widget.theme.border,
              valueColor: AlwaysStoppedAnimation(widget.theme.blue),
            ),
          ),
          const SizedBox(height: 14),
          // Glasses grid
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            cacheExtent: 1000,
            padding: EdgeInsets.zero,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.8,
            children: List.generate(10, (i) {
              final full = i < widget.waterGlasses;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onWaterChange(full ? i : i + 1);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 44,
                      child: CustomPaint(
                        painter: _GlassPainter(
                          filled: full,
                          fillColor: widget.theme.blue.withValues(alpha: 0.4),
                          borderColor: full
                              ? widget.theme.blue
                              : (widget.theme.isDark
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : widget.theme.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${i + 1}',
                      style: GoogleFonts.syne(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: widget.theme.text4,
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

  bool _isSunnahDay() {
    final d = DateTime.now().weekday;
    return d == DateTime.monday || d == DateTime.thursday;
  }

  String _fastingDayName() {
    final d = DateTime.now().weekday;
    if (d == DateTime.monday) return 'Monday Fast';
    if (d == DateTime.thursday) return 'Thursday Fast';
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

  Future<void> _loadFastStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fastStatus =
          prefs.getString('fast_status_${dayKey(DateTime.now())}') ??
          (_isSunnahDay() ? 'fasting' : 'none');
    });
  }

  Future<void> _setFastStatus(String status) async {
    HapticFeedback.selectionClick();
    setState(() => _fastStatus = status);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fast_status_${dayKey(DateTime.now())}', status);
  }

  Widget _fastingStatusCard() {
    final isSunnah = _isSunnahDay();
    final countdown = _getCountdown();
    final progress = _fastElapsedProgress();
    const gold = Color(0xFFE8B84B);

    return _GlassCard(
      theme: widget.theme,
      glowColor: const Color(0xFFE8B84B),
      radius: 16,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('\u{1F319}', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSunnah
                      ? _fastingDayName().replaceFirst('Sunnah ', '')
                      : (_fastStatus == 'fasting'
                            ? 'Personal Fast'
                            : 'No Fast Today'),
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.theme.text1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Sub label
          Text(
            'IFTAR IN',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              letterSpacing: 3,
              color: widget.theme.text3,
            ),
          ),
          const SizedBox(height: 10),
          // Timer row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                countdown,
                style: GoogleFonts.syne(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: gold,
                ),
              ),
              // Progress ring
              SizedBox(
                width: 52,
                height: 52,
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
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: gold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Log Fast button
          GestureDetector(
            onTap: () => _setFastStatus(
              _fastStatus == 'fasting'
                  ? (_isSunnahDay() ? 'broke' : 'none')
                  : 'fasting',
            ),
            child: Text(
              isSunnah
                  ? (_fastStatus == 'fasting' ? 'Broke Fast' : '+ Start Fast')
                  : (_fastStatus == 'fasting' ? 'Cancel Fast' : '+ Log Fast'),
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: gold,
                fontWeight: FontWeight.w500,
              ),
            ),
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
    final timeStr =
        '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';

    Color borderColor;
    Color timeColor;
    Widget? iconWidget;

    if (done) {
      borderColor = const Color(0x6600C896); // completed border
      timeColor = const Color(0xFF00C896);
      iconWidget = const Text(
        ' ✓',
        style: TextStyle(
          color: Color(0xFF00C896),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    } else if (isNext) {
      borderColor = const Color(0x99E8B84B); // current border
      timeColor = const Color(0xFFE8B84B);
    } else if (missed) {
      borderColor = const Color(0x4DFF4444); // missed border
      timeColor = const Color(0xFFFF4444);
      iconWidget = const Text(
        ' ✗',
        style: TextStyle(
          color: Color(0x99FF4444),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      borderColor = widget.theme.isDark
          ? Colors.white.withValues(alpha: 0.05)
          : widget.theme.border; // upcoming/default border
      timeColor = widget.theme.text2;
    }

    return GestureDetector(
      onTap: () => widget.onPrayerToggle(prayer),
      child: Container(
        decoration: BoxDecoration(
          color: widget.theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              prayer,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: widget.theme.text3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: timeColor,
                  ),
                ),
                ?iconWidget,
              ],
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
      'Dhuha',
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
    return {'name': 'All Done', 'time': '$completedCount/6 prayed', 'in': '✓'};
  }

  Widget _nextPrayerBanner() {
    final nextPrayer = _getNextPrayer();
    if (nextPrayer['name'] == 'All Done') {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: widget.theme.teal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(50), // full capsule
        border: Border.all(
          color: widget.theme.teal.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              PulsingDot(color: widget.theme.teal, size: 8),
              const SizedBox(width: 10),
              Text(
                nextPrayer['name']!,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: widget.theme.text1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                nextPrayer['time']!,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: widget.theme.teal,
                ),
              ),
            ],
          ),
          Text(
            nextPrayer['in']!,
            style: GoogleFonts.dmSans(fontSize: 12, color: widget.theme.text3),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final displayUserName = widget.userName.trim().isNotEmpty
        ? widget.userName.trim()
        : 'Welcome';
    final parts = displayUserName.split(' ');
    final firstName = parts.isNotEmpty ? parts[0] : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFE8B84B), Color(0xFFF5D78E)],
                  ).createShader(bounds),
                  child: Text(
                    firstName,
                    style: GoogleFonts.syne(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (lastName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    lastName.toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6,
                      color: const Color(0x80E8B84B),
                    ),
                  ),
                ],
              ],
            ),
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
                      style: GoogleFonts.syne(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE8B84B),
                      ),
                    ),
                    Text(
                      'Days to ${widget.userGoalYear}',
                      style: GoogleFonts.dmSans(
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
          style: GoogleFonts.dmSans(
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
                      _wrapWithStaggered(0, _buildHeroCountdown()),
                      const SizedBox(height: 28),
                      _wrapWithStaggered(
                        1,
                        _buildAyahCard(_TodayScreenState.ayahs[_ayahIndex]),
                      ),
                      const SizedBox(height: 24),
                      _wrapWithStaggered(2, _buildMetricRow(visibleTaskCount)),
                      const SizedBox(height: 20),
                      _wrapWithStaggered(
                        3,
                        _buildScoreCard(
                          todayScore,
                          prayerProgress,
                          taskProgress,
                          waterProgress,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _wrapWithStaggered(4, _nextPrayerBanner()),
                      const SizedBox(height: 20),
                      _wrapWithStaggered(
                        5,
                        KeyedSubtree(
                          key: _prayersKey,
                          child: _buildPrayerGrid(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _wrapWithStaggered(
                        6,
                        KeyedSubtree(key: _tasksKey, child: _buildTasksList()),
                      ),
                      const SizedBox(height: 20),
                      _wrapWithStaggered(7, _suhoorReminderCard()),
                      const SizedBox(height: 20),
                      _wrapWithStaggered(
                        8,
                        KeyedSubtree(key: _waterKey, child: _waterTracker()),
                      ),
                      const SizedBox(height: 20),
                      _wrapWithStaggered(9, _fastingStatusCard()),
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

  Widget _buildAyahCard(List<String> ayah) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _GlassCard(
        theme: widget.theme,
        border: Border.all(color: const Color(0x66E8B84B), width: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                ayah[0],
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'NotoNaskhArabic',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: widget.theme.isDark
                      ? const Color(0xFFF5D78E)
                      : widget.theme.gold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 1.5,
                color: widget.theme.gold.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 12),
              Text(
                ayah[1],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.theme.text2,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Quran ${ayah[2]}',
                textAlign: TextAlign.center,
                style: GoogleFonts.syne(
                  fontSize: 10,
                  color: widget.theme.text3,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
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
              style: GoogleFonts.syne(
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
          widget.record.prayerDone,
          7,
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
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: widget.theme.text3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$pct%',
                style: GoogleFonts.dmSans(
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
    return _GlassCard(
      theme: widget.theme,
      glowColor: const Color(0xFFE8B84B),
      radius: 14,
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Today's Score",
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: widget.theme.text3,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$todayScore / 100',
                style: GoogleFonts.syne(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: widget.theme.text1,
                ),
              ),
            ],
          ),
          SizedBox(
            width: 70,
            height: 70,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: todayScore / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, arcProgress, child) {
                return CustomPaint(
                  painter: _ScoreArcPainter(
                    progress: arcProgress,
                    color: const Color(0xFFE8B84B),
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
    return Column(
      children: [
        Row(
          children: kPrayerNames
              .take(4)
              .map(
                (p) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: _prayerTile(p, _TodayScreenState.arabicNames[p]!),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: kPrayerNames
              .skip(4)
              .map(
                (p) => SizedBox(
                  width: (MediaQuery.of(context).size.width - 56) / 4,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: _prayerTile(p, _TodayScreenState.arabicNames[p]!),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTasksList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Daily Tasks", onAdd: () => _showTaskSheet()),
        if (_visibleTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: widget.theme.isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.015),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.theme.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    color: widget.theme.gold.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "No tasks for today. Tap '+' to add one.",
                      style: GoogleFonts.dmSans(
                        color: widget.theme.text3,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ..._visibleTasks.map(
          (entry) => RepaintBoundary(child: _taskRow(entry)),
        ),
      ],
    );
  }

  static const arabicNames = {
    'Tahajjud': '\u062a\u0647\u062c\u062f',
    'Fajr': '\u0641\u062c\u0631',
    'Dhuha': '\u0636\u062d\u0649',
    'Dhuhr': '\u0638\u0647\u0631',
    'Asr': '\u0639\u0635\u0631',
    'Maghrib': '\u0645\u063a\u0631\u0628',
    'Isha': '\u0639\u0634\u0627\u0621',
  };

  static const ayahs = [
    [
      '\u0625\u0650\u0646\u064e\u0651 \u0645\u064e\u0639\u064e \u0627\u0644\u0652\u0639\u064f\u0633\u0652\u0631\u0650 \u064a\u064f\u0633\u0652\u0631\u064b\u0627',
      'Indeed, with hardship comes ease.',
      '94:6',
    ],
    [
      '\u0648\u064e\u0645\u064e\u0646 \u064a\u064e\u062a\u064e\u0651\u0642\u0650 \u0627\u0644\u0644\u064e\u0651\u0647\u064e \u064a\u064e\u062c\u0652\u0639\u064e\u0644 \u0644\u064e\u0651\u0647\u064e \u0645\u064e\u062e\u0652\u0631\u064e\u062c\u064b\u0627',
      'Whoever fears Allah, He makes a way out.',
      '65:2',
    ],
    [
      '\u0641\u064e\u0627\u0630\u0652\u0643\u064f\u0631\u064f\u0648\u0646\u0650\u064a \u0623\u064e\u0630\u0652\u0643\u064f\u0631\u0652\u0643\u064f\u0645\u0652',
      'Remember Me and I will remember you.',
      '2:152',
    ],
    [
      '\u0625\u0650\u0646\u064e\u0651 \u0627\u0644\u0644\u064e\u0651\u0647\u064e \u0645\u064e\u0639\u064e \u0627\u0644\u0635\u064e\u0651\u0627\u0628\u0650\u0631\u0650\u064a\u0646\u064e',
      'Indeed Allah is with the patient.',
      '2:153',
    ],
    [
      '\u0648\u064e\u062a\u064e\u0648\u064e\u0643\u064e\u0651\u0644\u0652 \u0639\u064e\u0644\u064e\u0649 \u0627\u0644\u0644\u064e\u0651\u0647\u0650',
      'And put your trust in Allah.',
      '33:3',
    ],
    [
      '\u0644\u064e\u0627 \u064a\u064f\u0633\u0652\u062a\u064e\u062c\u064e\u0627\u0628\u064f \u0625\u0650\u0644\u0651\u064e\u0627 \u0628\u0650\u0627\u0644\u0635\u0651\u064e\u0628\u0652\u0631\u0650',
      'Allah does not burden a soul beyond that it can bear.',
      '2:286',
    ],
    [
      '\u0641\u064e\u0625\u0650\u0646\u0651\u064e \u0645\u064e\u0639\u064e \u0627\u0644\u0652\u0639\u064f\u0633\u0652\u0631\u0650 \u064a\u064f\u0633\u0652\u0631\u064b\u0627',
      'So verily, with the hardship, there is relief.',
      '94:5',
    ],
    [
      '\u0648\u064e\u0648\u064e\u062c\u064e\u062f\u064e\u0643\u064e \u0636\u064e\u0627\u0644\u0651\u064b\u0627 \u0641\u064e\u0647\u064e\u0625\u064e\u0649',
      'And He found you lost and guided [you].',
      '93:7',
    ],
    [
      '\u0648\u064e\u0631\u064e\u062d\u0652\u0645\u064e\u062a\u0650\u064a \u0648\u064e\u0633\u0650\u0639\u064e\u062a\u0652 \u0643\u064f\u0644\u0651\u064e \u0634\u064e\u064a\u0652\u0621\u064d',
      'My mercy encompasses all things.',
      '7:156',
    ],
    [
      '\u0627\u062f\u0652\u0639\u064f\u0648\u0646\u0650\u064a \u0623\u064e\u0633\u0652\u062a\u064e\u062c\u0650\u0628\u0652 \u0644\u064f\u0633\u0652\u0643\u064f\u0645\u0652',
      'Call upon Me; I will respond to you.',
      '40:60',
    ],
  ];
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.theme,
    required this.child,
    this.padding,
    this.border,
    this.radius = 18,
    this.glowColor,
    this.blurSigma = 18,
  });
  final ThemeColors theme;
  final Widget child;
  final EdgeInsets? padding;
  final BoxBorder? border;
  final double radius;
  final Color? glowColor;
  final double blurSigma;

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
                  ? Colors.white.withValues(alpha: 0.09)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.5,
            ),
        boxShadow: isDark && glowColor != null
            ? [
                BoxShadow(
                  color: glowColor!.withValues(alpha: 0.08),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ]
            : isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
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
    } else if (!recordFor(widget.history, DateTime.now()).tasks[taskIndex]) {
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
              style: GoogleFonts.dmSans(
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
                      style: GoogleFonts.syne(
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
                style: GoogleFonts.dmSans(
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
            : recordFor(widget.history, DateTime.now()).tasks[taskIndex]);
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
                          style: GoogleFonts.syne(
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
                              style: GoogleFonts.syne(
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
                              style: GoogleFonts.syne(
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
  int _fastingStreak = 0;
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

    // 2. Load fasting status & calculate streak
    final fastVal = prefs.getString('fast_status_$dateStr');
    final isSunnah =
        date.weekday == DateTime.monday || date.weekday == DateTime.thursday;
    final fastStatus = fastVal ?? (isSunnah ? 'fasting' : 'none');

    // Fasting streak loop — only count explicitly logged fasts
    int streak = 0;
    final today = DateTime.now();
    final todayVal = prefs.getString('fast_status_${dayKey(today)}');
    final startDayIndex = (todayVal == 'fasting') ? 0 : 1;

    if (todayVal != null && todayVal != 'fasting') {
      // If today is explicitly marked as non-fasting or broke, the streak is 0.
      streak = 0;
    } else {
      for (int i = startDayIndex; i < 30; i++) {
        final d = today.subtract(Duration(days: i));
        final dStr = dayKey(d);
        final fVal = prefs.getString('fast_status_$dStr');
        if (fVal == 'fasting') {
          streak++;
        } else {
          // Any unlogged or non-fasting day in the past breaks the consecutive streak
          break;
        }
      }
    }

    // 3. Load extra habits
    final Map<String, bool> habits = {};
    for (var name in _extraHabitNames) {
      habits[name] = prefs.getBool('islamic_habit_${name}_$dateStr') ?? false;
    }

    if (!mounted) return;
    setState(() {
      _selectedWaterGlasses = waterVal.clamp(0, 10);
      _selectedFastStatus = fastStatus;
      _fastingStreak = streak;
      _selectedIslamicHabits.clear();
      _selectedIslamicHabits.addAll(habits);
    });
  }

  bool _isPrayerPassed(String prayer, DateTime selectedDate) {
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

    final time = _prayerTimes[prayer];
    if (time == null) return false;
    final prayerTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    return now.isAfter(prayerTime);
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
            style: GoogleFonts.syne(
              fontWeight: FontWeight.w800,
              color: appColors.text1,
            ),
          ),
          content: Text(
            'Reset ALL data for ${_formatSelectedDate(_selectedDate)}?\n\nThis will clear:\n• Tasks\n• Prayers\n• Workout progress\n• Water intake\n• Income entries\n• Fasting log',
            style: GoogleFonts.dmSans(color: appColors.text2, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: GoogleFonts.dmSans(
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
                style: GoogleFonts.dmSans(
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
                        'MONITOR',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          letterSpacing: 3.0,
                          fontWeight: FontWeight.w700,
                          color: appColors.gold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Habits',
                        style: GoogleFonts.syne(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: appColors.text1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatSelectedDate(_selectedDate)} · Daily Report',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: appColors.text3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Print Button
                IconButton(
                  onPressed: widget.onPrintPdf,
                  icon: const Icon(Icons.print, size: 20),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    backgroundColor: appColors.card,
                    side: BorderSide(color: appColors.cardBorder, width: 0.5),
                  ),
                  tooltip: 'Print PDF',
                ),

                const SizedBox(width: 8),
                // Theme Toggle
                GestureDetector(
                  onTap: () {
                    final themeNotifier = Provider.of<ThemeNotifier>(
                      context,
                      listen: false,
                    );
                    themeNotifier.toggle();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: appColors.card,
                      border: Border.all(
                        color: appColors.cardBorder,
                        width: 0.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Provider.of<ThemeNotifier>(context).isDark
                          ? Icons.wb_sunny
                          : Icons.nights_stay,
                      size: 18,
                      color: appColors.text1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2. RESET DAY BUTTON
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmResetDay(context, appColors),
                icon: Icon(Icons.refresh, size: 14, color: appColors.red),
                label: Text(
                  'Reset Day',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: appColors.red,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: appColors.red2,
                  side: BorderSide(color: appColors.red, width: 0.5),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. SCORE HERO CARD
            _GlassCard(
              theme: appColors.theme,
              glowColor: appColors.gold,
              radius: 20,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                children: [
                  Text(
                    "TODAY'S SCORE",
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: appColors.text3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${record.percent}%',
                    style: GoogleFonts.syne(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: appColors.emerald,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.doneTotal} of ${record.total} completed',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: appColors.text2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Custom Progress Bar
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

            // 4. DAY STRIP
            _buildDayStrip(appColors),
            const SizedBox(height: 20),

            // 5. PRAYERS MODULE
            _buildSection(
              title: 'Prayers',
              rightText:
                  "Prayers ${record.prayers.entries.where((e) => e.key != 'Tahajjud' && e.value == true).length}/6",
              rightColor: appColors.emerald,
              appColors: appColors,
              child: Row(
                children: [
                  for (final prayer in [
                    'Fajr',
                    'Dhuha',
                    'Dhuhr',
                    'Asr',
                    'Maghrib',
                    'Isha',
                  ])
                    _buildPrayerCard(prayer, record, appColors),
                ],
              ),
            ),

            // 6. TASKS MODULE
            _buildSection(
              title: 'Tasks',
              rightText: 'Tasks ${record.taskDone}/${kTodayTasks.length}',
              rightColor: appColors.emerald,
              appColors: appColors,
              child: kTodayTasks.isEmpty
                  ? Center(
                      child: Text(
                        'No tasks for today',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: appColors.text3,
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(kTodayTasks.length, (i) {
                        final task = kTodayTasks[i];
                        final done = record.tasks[i] == true;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: done
                                ? const Color(
                                    0xFFFF007F,
                                  ).withValues(alpha: 0.08)
                                : appColors.theme.isDark
                                ? const Color(0x06FFFFFF)
                                : appColors.theme.bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: done
                                  ? const Color(
                                      0xFFFF007F,
                                    ).withValues(alpha: 0.4)
                                  : appColors.cardBorder,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: done
                                      ? const Color(0xFFFF007F)
                                      : appColors.text3,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                task.title,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: done
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: done
                                      ? const Color(0xFFFF007F)
                                      : appColors.text2,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
            ),

            // 7. WORKOUT MODULE
            _buildSection(
              title: 'Workout',
              rightText: workoutStatus,
              rightColor: workoutStatus == 'Completed'
                  ? appColors.emerald
                  : appColors.gold,
              appColors: appColors,
              child: Row(
                children: [
                  // Progress Ring
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: workoutTotalSets == 0
                              ? 0.0
                              : (workoutSetsCompleted / workoutTotalSets).clamp(
                                  0.0,
                                  1.0,
                                ),
                          strokeWidth: 4,
                          backgroundColor: appColors.track,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.teal),
                        ),
                        Text(
                          workoutTotalSets == 0
                              ? '0%'
                              : '${(workoutSetsCompleted / workoutTotalSets * 100).round()}%',
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: appColors.text1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Workout details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workoutName,
                          style: GoogleFonts.syne(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: appColors.text1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$workoutSetsCompleted of $workoutTotalSets sets completed',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: appColors.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 8. INCOME MODULE
            _buildSection(
              title: 'Income',
              rightText: 'Net: ${netIncome >= 0 ? '+' : ''}₹$netIncome',
              rightColor: netIncome >= 0 ? appColors.emerald : appColors.red,
              appColors: appColors,
              child: Row(
                children: [
                  _buildMiniCard(
                    label: 'Earned',
                    value: '₹$earned',
                    valueColor: appColors.emerald,
                    appColors: appColors,
                  ),
                  const SizedBox(width: 8),
                  _buildMiniCard(
                    label: 'Spent',
                    value: '₹$spent',
                    valueColor: appColors.red,
                    appColors: appColors,
                  ),
                  const SizedBox(width: 8),
                  _buildMiniCard(
                    label: 'Net',
                    value: '${netIncome >= 0 ? '+' : ''}₹$netIncome',
                    valueColor: appColors.gold,
                    appColors: appColors,
                  ),
                ],
              ),
            ),

            // 9. WATER MODULE
            _buildSection(
              title: 'Water',
              rightText: '${waterVolume.toStringAsFixed(1)} / 2.6 L',
              rightColor: theme.blue,
              appColors: appColors,
              child: Row(
                children: [
                  _buildMiniCard(
                    label: 'Glasses',
                    value: '$_selectedWaterGlasses/10',
                    valueColor: theme.blue,
                    appColors: appColors,
                  ),
                  const SizedBox(width: 8),
                  _buildMiniCard(
                    label: 'Progress',
                    value: '${(_selectedWaterGlasses / 10 * 100).round()}%',
                    valueColor: appColors.text1,
                    appColors: appColors,
                  ),
                ],
              ),
            ),

            // 10. FASTING MODULE
            _buildSection(
              title: 'Fasting',
              rightText: fastingHeaderStatus,
              rightColor: fastingHeaderStatus == 'Logged'
                  ? appColors.emerald
                  : appColors.gold,
              appColors: appColors,
              child: Row(
                children: [
                  _buildMiniCard(
                    label: 'Status',
                    value: fastingCardStatus,
                    valueColor: fastingCardStatus == 'Completed'
                        ? appColors.emerald
                        : appColors.gold,
                    appColors: appColors,
                  ),
                  const SizedBox(width: 8),
                  _buildMiniCard(
                    label: 'Streak',
                    value: '$_fastingStreak days',
                    valueColor: appColors.gold,
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
              title.toUpperCase(),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: appColors.text3,
              ),
            ),
            if (rightText != null)
              Text(
                rightText,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: rightColor ?? appColors.text2,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _GlassCard(
          theme: appColors.theme,
          radius: 16,
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: appColors.theme.isDark
              ? const Color(0x06FFFFFF)
              : appColors.theme.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: appColors.cardBorder, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.dmSans(
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: appColors.text3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.syne(
                fontSize: 14,
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
        size: 14,
        color: appColors.emerald,
      );
    } else if (missed) {
      bgColor = appColors.red2;
      borderColor = appColors.red.withValues(alpha: 0.5);
      textColor = appColors.red;
      statusIcon = Icon(Icons.close_rounded, size: 14, color: appColors.red);
    } else {
      bgColor = appColors.theme.isDark
          ? const Color(0x06FFFFFF)
          : appColors.theme.bg;
      borderColor = appColors.cardBorder;
      textColor = appColors.text3;
      statusIcon = Text(
        timeStr,
        style: GoogleFonts.dmSans(fontSize: 9, color: appColors.text3),
      );
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            statusIcon,
          ],
        ),
      ),
    );
  }

  Widget _buildDayStrip(AppColors appColors) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: 6 - i)),
    );

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final date = days[index];
          final isSelected = dayKey(date) == dayKey(_selectedDate);
          final record = recordFor(widget.history, date);
          final percent = record.percent;

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

          final scoreColor = percent >= 50 ? appColors.emerald : appColors.red;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
              _loadDayData(date);
            },
            child: Container(
              width: 50,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? appColors.card : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? appColors.gold : appColors.cardBorder,
                  width: isSelected ? 1.5 : 0.5,
                ),
                boxShadow: isSelected ? appColors.shadow : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    shortDayName,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: appColors.text3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayNumber,
                    style: GoogleFonts.syne(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? appColors.text1 : appColors.text2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$percent%',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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

        final isSunnah =
            date.weekday == DateTime.monday ||
            date.weekday == DateTime.thursday;
        final isFasting =
            status == 'fasting' ||
            (isSunnah && status != 'broke' && status != 'none');

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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.text1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                shortDate(date),
                style: TextStyle(fontSize: 14, color: theme.text3),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: incomeCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: theme.text1),
                decoration: InputDecoration(
                  labelText: 'Income Earned Today',
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
                style: TextStyle(color: theme.text1),
                decoration: InputDecoration(
                  labelText: 'Amount Spent Today',
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
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.text1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                summary.workoutName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.text2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${summary.exercisesCompleted}/${summary.totalExercises} exercises - ${summary.setsCompleted}/${summary.totalSets} sets',
                style: TextStyle(color: theme.text3, height: 1.5),
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
                          style: TextStyle(color: theme.text1),
                        ),
                      ),
                      Text(
                        '${entry.value} sets',
                        style: TextStyle(color: theme.text3),
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
      margin: const EdgeInsets.only(bottom: 10), // Use cCard
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
                style: TextStyle(
                  fontSize: 15, // Use Syne
                  fontWeight: FontWeight.w600,
                  color: theme.text1,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${record.doneTotal}/${record.total}',
                    style: TextStyle(
                      fontSize: 13, // Use Syne
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
                              style: TextStyle(color: theme.text1),
                            ),
                            content: Text(
                              'This will permanently clear all tasks, prayers, fasting log, and financial data for ${shortDate(date)}.',
                              style: TextStyle(color: theme.text2),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(color: theme.text3),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  onResetDay(date);
                                },
                                child: const Text(
                                  'Reset',
                                  style: TextStyle(color: Colors.red),
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
                  done: record.tasks[i], // No color in TodayTask
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700, // Use Syne
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
                color: theme.card, // Use cCard
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
                      const Text(
                        'INCOME',
                        style: TextStyle(
                          fontSize: 12,
                          color: kMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap to edit',
                        style: TextStyle(
                          fontSize: 12, // Use DM Sans
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
                        amount: income, // Use cEmerald
                        color: cEmerald,
                        isNet: false,
                        theme: theme,
                      ),
                      const SizedBox(width: 8),
                      _IncomeMiniCard(
                        label: 'SPENT',
                        amount: expense, // Use cRose
                        color: cRose,
                        isNet: false,
                        theme: theme,
                      ),
                      const SizedBox(width: 8),
                      _IncomeMiniCard(
                        label: 'NET',
                        amount: income - expense, // Use cEmerald and cRose
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
          borderRadius: BorderRadius.circular(8), // Use cBg
          border: Border.all(color: theme.border, width: 0.5),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12, // Use Syne
                fontWeight: FontWeight.w800,
                color: theme.text4,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$prefix\u20B9${absAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
        borderRadius: BorderRadius.circular(9), // Use cCard
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
                  style: TextStyle(
                    fontSize: 13, // Use Syne
                    color: done ? theme.text1 : theme.text3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: cSub2,
                    ), // Use DM Sans and cSub2
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
          // Use cCardBorder
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
                  style: TextStyle(
                    fontSize: 15, // Use Syne
                    fontWeight: FontWeight.w800,
                    color: theme.text1,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12, // Use DM Sans
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
  return history[dayKey(date)] ?? DayRecord.empty();
}

Map<String, TimeOfDay> _prayerTimes = {
  'Tahajjud': const TimeOfDay(hour: 3, minute: 0),
  'Fajr': const TimeOfDay(hour: 5, minute: 12),
  'Dhuha': const TimeOfDay(hour: 6, minute: 22),
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
  final dhuhaTime = p.sunrise.add(const Duration(minutes: 20));

  return {
    'Tahajjud': toTimeOfDay(tahajjudTime),
    'Fajr': toTimeOfDay(fajrTime),
    'Dhuha': toTimeOfDay(dhuhaTime),
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
    'Tahajjud': Icons.nights_stay,
    'Fajr': Icons.dark_mode,
    'Dhuha': Icons.wb_sunny,
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
    'Dhuha': kAmber,
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

int parseSets(String description) {
  final match = RegExp(r'(\d+)\s*x').firstMatch(description);
  if (match != null) {
    return int.tryParse(match.group(1) ?? '') ?? 1;
  }
  return 1;
}

int parseReps(String description) {
  if (description.toLowerCase().contains('max')) {
    return 12;
  }
  final match = RegExp(r'x\s*([0-9]+)').firstMatch(description);
  if (match != null) {
    return int.tryParse(match.group(1) ?? '') ?? 1;
  }
  final anyNumber = RegExp(r'([0-9]+)').firstMatch(description);
  return int.tryParse(anyNumber?.group(1) ?? '') ?? 1;
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

  final List<WorkoutDay> _plan = const [
    WorkoutDay(
      title: 'Upper Body',
      freq: 'Mon / Wed / Sat',
      icon: Icons.fitness_center,
      color: Colors.teal,
      exercises: [
        ['Push-ups', '3 x 8 reps', 'Chest, shoulders, triceps'],
        ['Incline Push-ups', '3 x 10 reps', 'Feet on chair, upper chest'],
        ['Pike Push-ups', '3 x 6 reps', 'Shoulders, hips high'],
        ['Door Rows', '3 x 12 reps', 'Back & biceps, grip doorframe'],
        ['Arm Circles', '3 x 15 reps', 'Shoulder mobility'],
        ['Plank Hold', '3 x 30 seconds', 'Core stability'],
      ],
    ),
    WorkoutDay(
      title: 'Lower Body',
      freq: 'Tue / Thu / Fri',
      icon: Icons.directions_run,
      color: Colors.teal,
      exercises: [
        ['Bodyweight Squats', '3 x 15 reps', 'Full depth'],
        ['Jump Squats', '3 x 10 reps', 'Explosive'],
        ['Lunges', '3 x 10 reps', 'Each leg'],
        ['Glute Bridges', '3 x 15 reps', 'Posterior chain'],
        ['Calf Raises', '3 x 20 reps', 'Slow down, explode up'],
        ['Leg Raises', '3 x 12 reps', 'Lower abs'],
      ],
    ),
  ];

  final Map<String, WorkoutExerciseState> _exerciseStates = {};
  final Map<String, bool> _expandedCards = {};
  final ScrollController _scrollController = ScrollController();
  final List<List<String>> _libraryExercises = const [
    ['Lying Leg Curls', '3 x 12 reps', 'Hamstrings'],
    ['Leg Extensions', '3 x 15 reps', 'Quads'],
    ['Dumbbell Lunges', '3 x 10 reps', 'Legs & Glutes'],
    ['Lat Pulldown', '3 x 10 reps', 'Back & Biceps'],
    ['Cable Crossover', '3 x 12 reps', 'Chest & Shoulders'],
    ['Dumbbell Shrugs', '3 x 15 reps', 'Shoulders & Neck'],
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
  final TextEditingController _editRepsController = TextEditingController();

  // State variables for Duolingo & Brilliant upgrades
  bool _showExerciseCompleteOverlay = false;
  bool _showWorkoutCompleteOverlay = false;
  bool _isCelebrating = false;
  DateTime? _workoutStartTime;
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

  Widget _buildWorkoutContent(BuildContext context) {
    final theme = widget.theme;
    final cardBorder = theme.border;

    return SafeArea(
      child: Stack(
        children: [
          // Background Atmosphere Glow (soft emerald glow)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.0, -0.4),
                  radius: 0.8,
                  colors: [
                    const Color(0xFF00C896).withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main screen shifting and opacity fade during rep counting (Brilliant Parallax style)
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
                curve: _showRepCounter
                    ? Curves.easeOutCubic
                    : Curves.easeInCubic,
                opacity: _showRepCounter ? 0.3 : 1.0,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. HEADER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TRAINING WORKOUT',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 3.0,
                                    color: theme.text3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _weekdayName(DateTime.now()),
                                  style: GoogleFonts.syne(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: theme.text1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedSplit.title,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    color: theme.text2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Dark/light toggle and Settings cog
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  final themeNotifier =
                                      Provider.of<ThemeNotifier>(
                                        context,
                                        listen: false,
                                      );
                                  themeNotifier.toggle();
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: theme.card,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.border,
                                      width: 0.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    theme.isDark ? '☀️' : '🌙',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 2. STATS ROW
                      _workoutStatsGrid(theme, theme.teal),
                      const SizedBox(height: 18),

                      // 4. SPLIT SELECTOR
                      _splitSelector(theme),
                      const SizedBox(height: 20),

                      // 3. PROGRESS BAR SECTION
                      _buildLinearProgress(theme),
                      const SizedBox(height: 20),

                      // 5. EXERCISE LIST (with animated cross-fade and slide on switch)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            builder: (context, Widget? builderChild) {
                              final val = animation.value;
                              final double yOffset = (1.0 - val) * 10.0;
                              return Opacity(
                                opacity: val,
                                child: Transform.translate(
                                  offset: Offset(0.0, yOffset),
                                  child: builderChild,
                                ),
                              );
                            },
                            child: child,
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(_selectedSplit.title),
                          child: _exerciseLogSection(
                            theme,
                            _selectedSplit,
                            theme.teal,
                            cardBorder,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 9. START BUTTON
                      _buildStartButton(theme),
                      const SizedBox(height: 140),
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
                        _StreakFireIcon(isActive: currentStreak > 0),
                        const SizedBox(width: 6),
                        _animatedValueText(
                          '${currentStreak}d',
                          currentStreak > 0
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFF5A5A6A),
                          24,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Streak',
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
                          Icons.bolt,
                          size: 16,
                          color: Color(0xFF00C896),
                        ),
                        const SizedBox(width: 4),
                        _animatedValueText('$monthSessions', theme.text1, 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Sessions',
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
                      'Weight',
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
                          hoursThisWeek.toStringAsFixed(1),
                          theme.text1,
                          18,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Hours',
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
      ],
    );
  }

  Widget _splitSelector(ThemeColors theme) {
    final activeIndex = _selectedSplit.title == _plan[0].title ? 0 : 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = (constraints.maxWidth - 4) / 2;
        return Container(
          margin: const EdgeInsets.only(top: 20),
          height: 48,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border, width: 0.5),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut, // smooth slide
                left: activeIndex * tabWidth,
                width: tabWidth,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.teal,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: theme.teal.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticService.tapFeedback();
                        SoundManager.playTapClick();
                        setState(() {
                          _selectedSplit = _plan[0];
                          _recalculateStats();
                        });
                      },
                      child: Center(
                        child: Text(
                          _plan[0].title,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: activeIndex == 0
                                ? Colors.white
                                : theme.text3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticService.tapFeedback();
                        SoundManager.playTapClick();
                        setState(() {
                          _selectedSplit = _plan[1];
                          _recalculateStats();
                        });
                      },
                      child: Center(
                        child: Text(
                          _plan[1].title,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: activeIndex == 1
                                ? Colors.white
                                : theme.text3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.text1,
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: _setProgress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Text(
                  '${(value * 100).round()}% · $_completedExercises/${_selectedSplit.exercises.length} exercises',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: theme.text2,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
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
          child: Text(
            _buttonLabel,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
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
        // Section 1: MY ROUTINE (with left green bar accent)
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF00C896),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'MY ROUTINE',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: theme.text1,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'ORIGINAL',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: theme.teal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(height: 1, color: theme.border),
        const SizedBox(height: 10),
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
                }
              },
            ),
          );
        }),
        const SizedBox(height: 24),
        // Section 2: EXERCISE LIBRARY (with left green bar accent)
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF00C896),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'EXERCISE LIBRARY',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: theme.text1,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x26E67E22), // Orange glow
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'FROM FILE',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE67E22),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(height: 1, color: theme.border),
        const SizedBox(height: 10),
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
                }
              },
            ),
          );
        }),
      ],
    );
  }

  String _getTargetMuscleLabel(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('push-up') || lower.contains('push up'))
      return 'CHEST & TRICEPS';
    if (lower.contains('squat')) return 'QUADS & GLUTES';
    if (lower.contains('lunge')) return 'QUADS & HAMSTRINGS';
    if (lower.contains('bridge')) return 'GLUTES & HAMSTRINGS';
    if (lower.contains('raise')) {
      if (lower.contains('calf')) return 'CALVES';
      if (lower.contains('leg')) return 'ABS & CORE';
      return 'SHOULDERS';
    }
    if (lower.contains('row')) return 'BACK & BICEPS';
    if (lower.contains('circle')) return 'SHOULDER MOBILITY';
    if (lower.contains('plank')) return 'CORE STABILITY';
    if (lower.contains('pull')) return 'LATS & BACK';
    if (lower.contains('curl')) return 'BICEPS';
    if (lower.contains('press')) {
      if (lower.contains('bench')) return 'CHEST';
      return 'SHOULDERS';
    }
    if (lower.contains('fly')) return 'REAR DELTS';
    if (lower.contains('shrug')) return 'TRAPS';
    return 'TARGET MUSCLES';
  }

  Widget _buildRepCounterOverlay(ThemeColors theme) {
    if (_activeExerciseState == null || _activeExerciseName == null) {
      return const SizedBox.shrink();
    }

    final state = _activeExerciseState!;
    final totalSets = state.totalSets;
    final currentSet = state.currentSet;
    final isSetDone = _repsRemaining == 0;
    final isLastSet = currentSet == totalSets;

    return Container(
      color: theme.bg,
      child: SafeArea(
        child: Column(
          children: [
            // Top Navigation row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticService.negative();
                      SoundManager.playTapClick();
                      setState(() => _showRepCounter = false);
                    },
                    child: Icon(Icons.arrow_back, color: theme.text1, size: 24),
                  ),
                  Text(
                    'Set $currentSet of $totalSets',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.teal,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Middle Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Exercise Name
                      Text(
                        _activeExerciseName!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.text1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Sets x Reps Target
                      Text(
                        '$totalSets sets × ${state.maxReps} reps',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: theme.text3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Overall exercise progress & estimated time
                      Text(
                        'Exercise $_currentExerciseIndex of ${_selectedSplit.exercises.length}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: theme.text3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeEstimate,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: theme.text3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Stick figure canvas
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: theme.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.border, width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: StickFigureWidget(
                            exerciseName: _isCelebrating
                                ? 'celebrate'
                                : _activeExerciseName!,
                            accentColor: theme.teal,
                            size: 120,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Target Muscle Label below figure
                      Text(
                        _getTargetMuscleLabel(_activeExerciseName!),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: theme.text3,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Set Progress Dots
                      SetProgressDots(
                        totalSets: totalSets,
                        currentSet: currentSet,
                        isCompleted: state.completed,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),

                      // Hero counter number (animated transition)
                      _SetTransitionNumberWidget(
                        value: _repsRemaining,
                        currentSet: currentSet,
                        style: GoogleFonts.syne(
                          fontSize: 96,
                          fontWeight: FontWeight.w900,
                          color: isSetDone ? theme.text3 : theme.teal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _ComboIndicator(combo: _comboCount),
                      const SizedBox(height: 12),

                      Text(
                        isSetDone ? 'Set complete!' : 'Tap to count down',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: const Color(0xFF5A5A6A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // TAP Button with particles & progress ring
                      _TapBurstButtonWrapper(
                        repsRemaining: _repsRemaining,
                        totalReps: state.maxReps,
                        theme: theme,
                        onTap: () {
                          if (_repsRemaining > 0) {
                            final now = DateTime.now();
                            if (_lastTapTime != null) {
                              final diff = now
                                  .difference(_lastTapTime!)
                                  .inMilliseconds;
                              if (diff <= 800) {
                                _comboCount++;
                              } else {
                                _comboCount = 1;
                              }
                            } else {
                              _comboCount = 1;
                            }
                            _lastTapTime = now;

                            _comboResetTimer?.cancel();
                            _comboResetTimer = Timer(
                              const Duration(milliseconds: 800),
                              () {
                                if (mounted) {
                                  setState(() {
                                    _comboCount = 1;
                                  });
                                }
                              },
                            );

                            // Track tap times for time estimation
                            _recentTapTimes.add(now);
                            if (_recentTapTimes.length > 10) {
                              _recentTapTimes.removeAt(0);
                            }
                            _tapCountForEstimate++;
                            if (_tapCountForEstimate % 5 == 0) {
                              _timeEstimate = _calculateTimeEstimate();
                            }

                            setState(() {
                              _repsRemaining--;
                              state.repsRemaining = _repsRemaining;
                            });

                            if (_repsRemaining == 0) {
                              // Current set complete
                              HapticService.workoutRepZero();

                              if (isLastSet) {
                                // Exercise complete
                                SoundManager.playExerciseComplete();
                                HapticService.exerciseComplete();

                                setState(() {
                                  _isCelebrating = true;
                                });

                                Future.delayed(
                                  const Duration(milliseconds: 800),
                                  () {
                                    if (mounted) {
                                      setState(() {
                                        _isCelebrating = false;

                                        // Finalize exercise
                                        state.completed = true;
                                        state.repsRemaining = 0;
                                        _recalculateStats();
                                      });
                                      _savePreferences();
                                      _saveWorkoutProgress(
                                        _selectedSplit,
                                        completed:
                                            _dayCompletedExercises(
                                              _selectedSplit,
                                            ) ==
                                            _selectedSplit.exercises.length,
                                      );
                                      setState(() {
                                        _showExerciseCompleteOverlay = true;
                                      });
                                      _maybeCompleteWorkout();
                                    }
                                  },
                                );
                              } else {
                                // Set complete
                                SoundManager.playSetComplete();
                              }
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Rotating motivational phrase with fade
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _motivationalPhrase,
                          key: ValueKey(_motivationalPhrase),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: const Color(0xFF5A5A6A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),

            // Fixed Footer: Skip | Next Set (if done) | Edit
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip Button (left, dark)
                  TextButton(
                    onPressed: () {
                      HapticService.negative();
                      SoundManager.playTapClick();
                      setState(() => _showRepCounter = false);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: theme.card,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: theme.border, width: 0.5),
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: theme.text2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Next Set / Finish (center, only shows when set done)
                  if (isSetDone)
                    ElevatedButton(
                      onPressed: () {
                        HapticService.medium();
                        SoundManager.playTapClick();

                        if (isLastSet) {
                          // Finalize exercise
                          setState(() {
                            state.completed = true;
                            state.repsRemaining = 0;
                            _recalculateStats();
                          });
                          _savePreferences();
                          _saveWorkoutProgress(
                            _selectedSplit,
                            completed:
                                _dayCompletedExercises(_selectedSplit) ==
                                _selectedSplit.exercises.length,
                          );
                          setState(() {
                            _showExerciseCompleteOverlay = true;
                          });
                          _maybeCompleteWorkout();
                        } else {
                          // Go to next set and start rest timer
                          setState(() {
                            state.currentSet = currentSet + 1;
                            state.repsRemaining = state.maxReps;
                            _repsRemaining = state.maxReps;

                            // Start 90 seconds rest timer
                            _restSeconds = 90;
                            _restExerciseKey = state.exerciseKey;
                            _isResting = true;
                            _startRestTimer();
                          });
                          _savePreferences();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        isLastSet ? 'Finish Exercise' : 'Next Set',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 80), // spacer
                  // Edit Button (right, dark)
                  TextButton(
                    onPressed: () {
                      HapticService.tapFeedback();
                      SoundManager.playTapClick();
                      _editRepsController.text = '${state.maxReps}';
                      setState(() => _showEditRepsModal = true);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: theme.card,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: theme.border, width: 0.5),
                      ),
                    ),
                    child: Text(
                      'Edit',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: theme.text2,
                        fontWeight: FontWeight.bold,
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

  Widget _buildEditRepsModal(ThemeColors theme) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showEditRepsModal = false;
        });
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.border, width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Reps',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.text1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'TARGET REPS',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: theme.text3,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.border, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _editRepsController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.text1,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          HapticService.negative();
                          SoundManager.playTapClick();
                          setState(() {
                            _showEditRepsModal = false;
                          });
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: theme.card,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: theme.border, width: 0.5),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.dmSans(
                            color: theme.text2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () {
                          final reps = int.tryParse(
                            _editRepsController.text.trim(),
                          );
                          if (reps != null && reps > 0) {
                            HapticService.medium();
                            SoundManager.playTapClick();
                            setState(() {
                              _activeExerciseState!.maxReps = reps;
                              _activeExerciseState!.repsRemaining = reps;
                              _repsRemaining = reps;
                              _showEditRepsModal = false;
                              _recalculateStats();
                            });
                            _savePreferences();
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: theme.teal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Save',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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

    return Container(
      color: theme.bg,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Rest between sets',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: theme.text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 40),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CustomPaint(
                      painter: ProgressRingPainter(
                        progress: _restSeconds / 90.0,
                        trackColor: theme.isDark
                            ? theme.border
                            : theme.text4.withValues(alpha: 0.15),
                        progressColor: theme.teal,
                      ),
                    ),
                  ),
                  Text(
                    '$_restSeconds',
                    style: GoogleFonts.syne(
                      fontSize: 64,
                      fontWeight: FontWeight.w800,
                      color: theme.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                nextExerciseName == 'Workout complete!'
                    ? 'Next: Workout complete!'
                    : 'Next: $nextExerciseName',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: theme.text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 50),
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
                    color: theme.card,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: theme.border, width: 1),
                  ),
                  child: Text(
                    'Skip Rest',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.text1,
                    ),
                  ),
                ),
              ),
            ],
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

class _IncomeScreenState extends State<IncomeScreen> {
  final TextEditingController _incomeCtrl = TextEditingController();
  String _filter = 'All'; // 'All', 'Earned', 'Spent'

  // Editable sources state from SharedPreferences
  late List<Map<String, dynamic>> _sources = _defaultIncomeSources();

  bool _isInputIncome = true;
  final int _selectedSourceIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadIncomeSourcesForMonth();
  }

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

  @override
  void dispose() {
    _incomeCtrl.dispose();
    super.dispose();
  }

  int _monthTotal(Map<String, int> log, DateTime now) {
    var total = 0;
    for (final entry in log.entries) {
      final date = dateFromKey(entry.key);
      if (date.month == now.month && date.year == now.year) {
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
    if (compareDate == today) {
      return 'Today';
    } else if (compareDate == yesterday) {
      return 'Yesterday';
    } else {
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
  }

  void _submitAmount() {
    final amount = int.tryParse(_incomeCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    if (_isInputIncome) {
      setState(() {
        if (_selectedSourceIndex < _sources.length) {
          _sources[_selectedSourceIndex]['amount'] =
              (_sources[_selectedSourceIndex]['amount'] as int) + amount;
        }
      });
      _saveIncomeSourcesForMonth();
      widget.onAddEntry(amount);
    } else {
      widget.onAddExpense(amount);
    }
    _incomeCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  Widget _filterChip(String label, AppColors colors) {
    final selected = _filter == label;
    return GestureDetector(
      onTap: () {
        HapticService.selection();
        setState(() => _filter = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
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
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? colors.gold : colors.text3,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors(widget.theme);
    final now = DateTime.now();
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    final totalEarned = _monthTotal(widget.incomeLog, now);
    final totalSpent = _monthTotal(widget.expenseLog, now);
    final netSavings = totalEarned - totalSpent;
    final dailyAvgEarned = (totalEarned / 31).round();
    final dailyAvgSpent = (totalSpent / 31).round();

    final visibleDays =
        List.generate(
          now.day,
          (i) => DateTime(now.year, now.month, now.day - i),
        ).where((date) {
          final earned = widget.incomeLog[dayKey(date)] ?? 0;
          final spent = widget.expenseLog[dayKey(date)] ?? 0;
          if (earned == 0 && spent == 0) return false;
          if (_filter == 'Earned') {
            return earned > 0;
          }
          if (_filter == 'Spent') {
            return spent > 0;
          }
          return true;
        }).toList();

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FINANCE',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.0,
                          color: colors.gold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Income',
                        style: GoogleFonts.syne(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: colors.text1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Automation career to \u20B93L/month',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: colors.text2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => themeNotifier.toggle(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.card,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.cardBorder,
                            width: 0.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          colors.theme.isDark ? '☀️' : '🌙',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. SUMMARY CARD
            Container(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.cardBorder, width: 0.5),
                boxShadow: colors.shadow,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _money(netSavings),
                    style: GoogleFonts.syne(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: colors.gold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'THIS MONTH',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: colors.text3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Left Earned Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.emerald2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.emerald.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _money(totalEarned),
                                style: GoogleFonts.syne(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: colors.emerald,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'EARNED',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: colors.text3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_money(dailyAvgEarned)}/day',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Right Spent Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.red2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.red.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _money(totalSpent),
                                style: GoogleFonts.syne(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SPENT',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: colors.text3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_money(dailyAvgSpent)}/day',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. DAY-BY-DAY LIST
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day by Day',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.text1,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _filterChip('All', colors),
                    const SizedBox(width: 6),
                    _filterChip('Earned', colors),
                    const SizedBox(width: 6),
                    _filterChip('Spent', colors),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (visibleDays.isEmpty)
              Container(
                height: 100,
                alignment: Alignment.center,
                child: Text(
                  'No transactions yet',
                  style: GoogleFonts.dmSans(fontSize: 13, color: colors.text3),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: visibleDays.length,
                itemBuilder: (context, idx) {
                  final date = visibleDays[idx];
                  final earned = widget.incomeLog[dayKey(date)] ?? 0;
                  final spent = widget.expenseLog[dayKey(date)] ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.cardBorder, width: 0.5),
                      boxShadow: colors.shadow,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              getDayName(date),
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.text1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatDayRowDate(date),
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: colors.text3,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _money(earned),
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: earned > 0
                                    ? colors.emerald
                                    : colors.text4,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              spent > 0 ? '−${_money(spent)}' : _money(0),
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: spent > 0 ? colors.red : colors.text4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),

            // 4. INPUT SECTION
            Container(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.cardBorder, width: 0.5),
                boxShadow: colors.shadow,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isInputIncome = true),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: _isInputIncome
                                  ? colors.emerald2
                                  : colors.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isInputIncome
                                    ? colors.emerald.withValues(alpha: 0.25)
                                    : colors.cardBorder,
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Income',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _isInputIncome
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
                          onTap: () => setState(() => _isInputIncome = false),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: !_isInputIncome ? colors.red2 : colors.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !_isInputIncome
                                    ? colors.red.withValues(alpha: 0.25)
                                    : colors.cardBorder,
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Expense',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: !_isInputIncome
                                    ? colors.red
                                    : colors.text3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Input row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: colors.bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.cardBorder,
                              width: 0.5,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _incomeCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              color: colors.text1,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter amount (\u20B9)...',
                              hintStyle: GoogleFonts.dmSans(
                                color: colors.text4,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _submitAmount(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _submitAmount,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _isInputIncome ? colors.emerald : colors.red,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '+',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                  style: GoogleFonts.dmSans(
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
    if (name.contains('assisted') || desc.contains('assisted'))
      return 'ASSISTED';
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

  String get primaryMuscle {
    if (widget.muscle.isNotEmpty) {
      return widget.muscle.toUpperCase();
    }
    final name = widget.exercise[0].toLowerCase();
    if (name.contains('push-up') ||
        name.contains('push up') ||
        name.contains('bench'))
      return 'CHEST';
    if (name.contains('squat') || name.contains('lunge')) return 'QUADS';
    if (name.contains('bridge')) return 'GLUTES';
    if (name.contains('row') ||
        name.contains('pull-up') ||
        name.contains('pull up'))
      return 'LATS';
    if (name.contains('press')) return 'SHOULDERS';
    if (name.contains('leg raise') || name.contains('plank')) return 'CORE';
    if (name.contains('curl')) return 'BICEPS';
    return 'FULL BODY';
  }

  Widget _buildMuscleTag(String muscle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x1400C896), // rgba(0,200,150,0.08)
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        muscle,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: Color(0xB300C896), // #00C896 at 70% opacity
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

  Widget _buildDifficultyDots(int diff) {
    final activeColor = diff == 3
        ? const Color(0xFFEF4444)
        : diff == 2
        ? const Color(0xFFE8B84B)
        : const Color(0xFF00C896);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isActive = i < diff;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? activeColor : const Color(0xFF5A5A6A),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final tag = _getEquipmentTag();

    // Alternating card backgrounds
    final isEven = widget.index % 2 == 0;
    final baseBg = theme.isDark
        ? (isEven
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.white.withValues(alpha: 0.06))
        : (isEven
              ? Colors.white.withValues(alpha: 0.82)
              : Colors.white.withValues(alpha: 0.92));

    final borderCol = theme.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return GestureDetector(
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
          final blur = 32.0 - (16.0 * pressVal);
          final shadowOp = theme.isDark
              ? (0.3 + (0.1 * pressVal))
              : (0.06 + (0.02 * pressVal));
          final offY = 8.0 - (6.0 * pressVal);

          return Transform.scale(
            scale: scale,
            child: AnimatedOpacity(
              opacity: widget.completed ? 0.5 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: baseBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: shadowOp),
                      blurRadius: blur,
                      offset: Offset(0.0, offY),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    if (widget.completed)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.teal,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: widget.isLibrary
                                  ? const Color(0x1FE67E22)
                                  : const Color(0x262ECC71),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              widget.isLibrary
                                  ? Icons.bookmark_added_outlined
                                  : Icons.fitness_center_outlined,
                              color: widget.isLibrary
                                  ? const Color(0xFFE67E22)
                                  : theme.teal,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.exercise[0],
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.text1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: [
                                    Text(
                                      '${widget.sets} sets × ${widget.reps} reps · ',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10,
                                        color: theme.text3,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    _buildEquipmentTag(tag),
                                    const SizedBox(width: 2),
                                    _buildMuscleTag(primaryMuscle),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${widget.reps}',
                                style: GoogleFonts.syne(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: widget.completed
                                      ? theme.teal
                                      : (theme.isDark
                                            ? (widget.isLibrary
                                                  ? const Color(0xFFE67E22)
                                                  : theme.gold)
                                            : const Color(0xFFD35400)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildDifficultyDots(difficulty),
                            ],
                          ),
                          const SizedBox(width: 12),
                          _CompletionCheckWidget(
                            completed: widget.completed,
                            onTap: () {
                              HapticService.tapFeedback();
                              SoundManager.playTapClick();
                              widget.onToggle();
                            },
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
      style: GoogleFonts.syne(
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
        style: GoogleFonts.syne(
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
                style: GoogleFonts.dmSans(
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
    return LayoutBuilder(
      builder: (context, constraints) {
        _initConfetti(constraints.maxWidth);
        return GestureDetector(
          onTap: widget.onDismiss,
          child: Container(
            color: Colors.black.withValues(alpha: 0.85),
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
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: theme.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.border, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 40,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: AnimatedBuilder(
                              animation: _checkmarkController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: _SelfDrawingCheckPainter(
                                    progress: _checkmarkController.value,
                                    color: const Color(0xFF00C896),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          AnimatedOpacity(
                            opacity: _showTitle ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              'WORKOUT COMPLETE!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.syne(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

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
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AnimatedOpacity(
                                  opacity: _showStat3 ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: _buildSummaryStatCard(
                                    '${widget.minutesSpent} min',
                                    'time spent',
                                    theme,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          AnimatedOpacity(
                            opacity: _showButton ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: ElevatedButton(
                              onPressed: widget.onContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C896),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                'Continue',
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildSummaryStatCard(String value, String label, ThemeColors theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: theme.isDark ? const Color(0x0CFFFFFF) : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF00C896),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: theme.text3,
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
  final Function(String, int, int, int)? onProfileChanged;
  final VoidCallback onSaved;

  const _SettingsSheet({
    required this.theme,
    required this.userName,
    required this.userGoalYear,
    required this.userGoalMonth,
    required this.userGoalDay,
    this.onProfileChanged,
    required this.onSaved,
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
      _selectedMadhab = prefs.getString('prayer_madhab') ?? 'Hanafi';
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

            return AlertDialog(
              backgroundColor: theme.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.border, width: 0.5),
              ),
              title: Text(
                'Edit Profile',
                style: GoogleFonts.syne(
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
                      style: GoogleFonts.dmSans(
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
                      'Goal Deadline Date',
                      style: GoogleFonts.dmSans(
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
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      color: theme.text3,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      final name = nameController.text.trim();
                      if (widget.onProfileChanged != null) {
                        widget.onProfileChanged!(
                          name,
                          tempDate.year,
                          tempDate.month,
                          tempDate.day,
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
                    style: GoogleFonts.dmSans(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SETTINGS',
                  style: GoogleFonts.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.text1,
                    letterSpacing: 1.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: theme.text3, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              'APP SETTINGS',
              style: GoogleFonts.syne(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: theme.gold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.015),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Sound Effects',
                      style: TextStyle(
                        color: theme.text1,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Enable workout sound effects',
                      style: TextStyle(color: theme.text3, fontSize: 11),
                    ),
                    activeThumbColor: theme.teal,
                    value: SoundManager.isEnabled,
                    onChanged: (val) async {
                      await SoundManager.setEnabled(val);
                      setState(() {});
                      HapticService.tapFeedback();
                      if (val) SoundManager.playTapClick();
                    },
                  ),
                  Divider(color: theme.border, height: 0.5, thickness: 0.5),
                  SwitchListTile(
                    title: Text(
                      'Haptic Feedback',
                      style: TextStyle(
                        color: theme.text1,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Enable physical feedback on taps',
                      style: TextStyle(color: theme.text3, fontSize: 11),
                    ),
                    activeThumbColor: theme.teal,
                    value: HapticService.isEnabled,
                    onChanged: (val) async {
                      await HapticService.setEnabled(val);
                      setState(() {});
                      if (val) HapticService.tapFeedback();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'PROFILE SETTINGS',
              style: GoogleFonts.syne(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: theme.gold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.015),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: ListTile(
                title: Text(
                  'Profile Settings',
                  style: TextStyle(
                    color: theme.text1,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  widget.userName.isNotEmpty
                      ? widget.userName
                      : 'Set your name & goal',
                  style: TextStyle(color: theme.text3, fontSize: 11),
                ),
                trailing: Icon(Icons.chevron_right, color: theme.text2),
                onTap: () => _showEditNameDialog(context, theme),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'PRAYER TIMINGS SETTINGS',
              style: GoogleFonts.syne(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: theme.gold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.015),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: theme.gold, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Location:',
                          style: TextStyle(
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
                          style: TextStyle(
                            color: theme.text1,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _detecting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.gold,
                          ),
                        )
                      : TextButton.icon(
                          onPressed: _detectLocation,
                          icon: Icon(
                            Icons.my_location,
                            size: 14,
                            color: theme.teal,
                          ),
                          label: Text(
                            'Auto Detect',
                            style: TextStyle(
                              color: theme.teal,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Select City Preset',
              style: TextStyle(
                color: theme.text2,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.015),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _cityPresets.keys.contains(_locationName)
                      ? _locationName
                      : null,
                  hint: Text(
                    'Choose a preset city...',
                    style: TextStyle(color: theme.text3, fontSize: 13),
                  ),
                  dropdownColor: theme.bg,
                  style: TextStyle(color: theme.text1, fontSize: 13),
                  items: _cityPresets.keys.map((city) {
                    return DropdownMenuItem(value: city, child: Text(city));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _locationName = val;
                        _latController.text = _cityPresets[val]![0].toString();
                        _lonController.text = _cityPresets[val]![1].toString();
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Latitude',
                        style: TextStyle(
                          color: theme.text3,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(color: theme.text1, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: theme.isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.black.withValues(alpha: 0.015),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.border,
                              width: 0.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.gold,
                              width: 1.0,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _locationName =
                                'Custom (${double.tryParse(_latController.text)?.toStringAsFixed(2)}, ${double.tryParse(_lonController.text)?.toStringAsFixed(2)})';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Longitude',
                        style: TextStyle(
                          color: theme.text3,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _lonController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(color: theme.text1, fontSize: 13),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: theme.isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.black.withValues(alpha: 0.015),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.border,
                              width: 0.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.gold,
                              width: 1.0,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _locationName =
                                'Custom (${double.tryParse(_latController.text)?.toStringAsFixed(2)}, ${double.tryParse(_lonController.text)?.toStringAsFixed(2)})';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Calculation Method',
              style: TextStyle(
                color: theme.text2,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.015),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedMethod,
                  dropdownColor: theme.bg,
                  style: TextStyle(color: theme.text1, fontSize: 13),
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
            const SizedBox(height: 16),

            Text(
              'Asr Calculation Madhab',
              style: TextStyle(
                color: theme.text2,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.015),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedMadhab,
                  dropdownColor: theme.bg,
                  style: TextStyle(color: theme.text1, fontSize: 13),
                  items: const [
                    DropdownMenuItem(
                      value: 'Shafi',
                      child: Text('Standard (Shafi\'i, Maliki, Hanbali)'),
                    ),
                    DropdownMenuItem(
                      value: 'Hanafi',
                      child: Text('Hanafi (Later Asr)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMadhab = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Save Settings',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
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
}
