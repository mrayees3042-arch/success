import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:math' show max, min; // Fix 1: Add dart:math show max, min
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:success/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:success/providers/theme_provider.dart';
import 'package:success/screens/life_plan_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

final kDefaultTodayTasks = [
  TodayTask(Icons.menu_book, 'Quran Reading', '15-20 mins after Fajr'),
  TodayTask(
    Icons.precision_manufacturing,
    'TIA Portal Study',
    '7-9 AM - 2 hours',
  ),
  TodayTask(Icons.directions_walk, 'Morning Walk', '30 mins - after study'),
  TodayTask(Icons.fitness_center, 'Workout', 'Push / Legs / Back / HIIT'),
  TodayTask(Icons.water_drop, 'Drink 2.5L Water', 'Track throughout day'),
  TodayTask(
    Icons.phone_android,
    'Productive Phone',
    'Use phone only for useful work',
  ),
];

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
    required this.completed,
    required this.inProgress,
    required this.dateKey,
  });

  factory WorkoutProgressSnapshot.fromJson(Map<String, dynamic> json) {
    return WorkoutProgressSnapshot(
      workoutName: json['workoutName'] as String? ?? 'Workout',
      exercisesCompleted: (json['exercisesCompleted'] as num?)?.toInt() ?? 0,
      totalExercises: (json['totalExercises'] as num?)?.toInt() ?? 0,
      completed: json['completed'] == true,
      inProgress: json['inProgress'] == true,
      dateKey: json['dateKey'] as String? ?? '',
    );
  }

  final String workoutName;
  final int exercisesCompleted;
  final int totalExercises;
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
      home: const MainScreen(),
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

  DayRecord get _today => _recordFor(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadAppData();
    _loadIncome();
    _loadExpenses();
    _loadWater();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _themeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _darkOverride == null) {
        final nextTheme = getTheme();
        if (nextTheme.isDark != _theme.isDark) {
          setState(() => _theme = nextTheme);
        }
      }
    });
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
    if (!mounted) return;
    setState(() {
      final key = dayKey(DateTime.now());
      _incomeLog[key] = (_incomeLog[key] ?? 0) + amount;
    });
    _saveIncome();
  }

  void _addExpenseEntry(int amount) {
    if (!mounted) return;
    setState(() {
      final key = dayKey(DateTime.now());
      _expenseLog[key] = (_expenseLog[key] ?? 0) + amount;
    });
    _saveExpenses();
  }

  void _setIncomeForDate(DateTime date, int amount) {
    if (!mounted) return;
    setState(() => _incomeLog[dayKey(date)] = amount);
    _saveIncome();
  }

  void _setExpenseForDate(DateTime date, int amount) {
    if (!mounted) return;
    setState(() => _expenseLog[dayKey(date)] = amount);
    _saveExpenses();
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
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _today.tasks[index] = !_today.tasks[index]);
    _saveHistory();
  }

  void _editTask(int index, TodayTask task) {
    if (index < 0 || index >= kTodayTasks.length) return;
    if (!mounted) return;
    setState(() {
      kTodayTasks[index] = task;
    });
    _saveTaskDefinitions();
  }

  void _addDailyTask(TodayTask task) {
    if (!mounted) return;
    setState(() {
      kTodayTasks.add(task);
      for (final record in _history.values) {
        // Ensure all existing records have a corresponding task entry
        record.tasks.add(false);
      }
    });
    _saveTaskDefinitions();
    _saveHistory();
  }

  void _deleteTask(int index) {
    if (index < 0 || index >= kTodayTasks.length) return;
    if (!mounted) return;
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
    });
    _saveHistory();
  }

  void _togglePrayer(String name) {
    HapticFeedback.lightImpact();
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
      gold: cGold, // Use new gold constant
      teal: cEmerald, // Use new emerald constant
      blue: cAzure, // Use new azure constant
      red: cRose, // Use new rose constant
      green: cEmerald, // Use new emerald constant for general green
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
        ),
      ),
      SizedBox.expand(
        child: WorkoutScreen(
          theme: _theme,
          onWorkoutCompleted: _markWorkoutCompleted,
          onWorkoutProgressChanged: _updateWorkoutProgress,
        ),
      ),
      SizedBox.expand(
        child: IncomeScreen(
          theme: _theme,
          incomeLog: _incomeLog,
          expenseLog: _expenseLog,
          onAddEntry: _addIncomeEntry,
          onAddExpense: _addExpenseEntry,
        ),
      ),
      SizedBox.expand(child: LifePlanScreen(theme: _theme)),
    ];

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: _tab, children: screens),
        bottomNavigationBar: _BottomNavBar(
          selectedIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          theme: _theme,
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
  late AnimationController _ctrl;

  static const _icons = [
    Icons.home_outlined,
    Icons.check_circle_outline,
    Icons.fitness_center_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.flag_outlined,
  ];

  static const _labels = ['Today', 'Habits', 'Workout', 'Income', 'Plan'];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void didUpdateWidget(_BottomNavBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      // This is _BottomNavBar, not _NotchNavBar
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final navBg = theme.isDark ? cBg : theme.navBg;
    // The original code used kTeal for bubbleColor, but the new design uses cGold for active nav.
    // However, the instruction for the new TodayScreen bottom nav is not to touch other screen files.
    final bubbleColor = const Color(0xFF00BFA6);
    final inactiveColor = theme.isDark ? Colors.white38 : Colors.black38;

    return SafeArea(
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(
              color: theme.isDark ? Colors.white12 : Colors.black12,
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
                onTap: () => widget.onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _icons[i],
                      size: 22,
                      color: isSelected ? bubbleColor : inactiveColor,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _labels[i],
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
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
  });

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
  bool _quranReflected = false;
  final int _ayahIndex = 0;
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
    final nextDaysLeft = DateTime(2027, 1, 1).difference(now).inDays;
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
    final isEditing = entry != null;
    final task = entry?.value;
    final titleCtrl = TextEditingController(text: task?.title ?? '');
    final tagCtrl = TextEditingController(text: task?.tag ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.theme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
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
                controller: titleCtrl,
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
                controller: tagCtrl,
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
                  if (isEditing)
                    TextButton.icon(
                      onPressed: () {
                        titleCtrl.dispose();
                        tagCtrl.dispose();

                        Navigator.pop(sheetContext);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) widget.onTaskDelete(entry.key);
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: Text('Delete'),
                    ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.theme.gold,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      final tag = tagCtrl.text.trim();
                      if (title.isEmpty || tag.isEmpty) return;

                      final updatedTask = isEditing
                          ? task!.copyWith(title: title, tag: tag)
                          : TodayTask(
                              Icons
                                  .check_circle_outline, // Fix 3: Too many positional arguments
                              title, // No color in TodayTask
                              tag, // No color in TodayTask
                            );

                      titleCtrl.dispose();
                      tagCtrl.dispose();

                      Navigator.pop(sheetContext);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          if (isEditing) {
                            widget.onTaskEdit(entry.key, updatedTask);
                          } else {
                            widget.onTaskAdd(updatedTask);
                          }
                        }
                      });
                    },
                    child: Text('Save'),
                  ),
                ],
              ),
            ],
          ),
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
                  color: done ? widget.theme.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: done
                      ? null
                      : Border.all(color: widget.theme.border, width: 1.5),
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
                      color: done ? widget.theme.text3 : widget.theme.text1,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    _taskSubtitle(entry),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface,
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
                  'Before Fajr · Mon fast',
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
    final colorScheme = Theme.of(context).colorScheme;
    final emptyGlassColor = colorScheme.outlineVariant;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _GlassCard(
        theme: widget.theme,
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: consumed.toStringAsFixed(1),
                            style: GoogleFonts.syne(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                              shadows: [
                                Shadow(
                                  color: colorScheme.primary,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          TextSpan(
                            text: ' L',
                            style: GoogleFonts.syne(
                              fontSize: 12,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.water_drop_outlined,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '2.6 L goal',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${widget.waterGlasses} / 10 glasses',
                      style: GoogleFonts.syne(
                        fontSize: 16,
                        color: widget.theme.text1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '260 ml each',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: widget.theme.text3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: widget.waterGlasses / 10.0,
                minHeight: 4,
                backgroundColor: widget.theme.border.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation(widget.theme.blue),
              ),
            ),
            const SizedBox(height: 14),
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
                            fillColor: colorScheme.primary,
                            borderColor: full
                                ? colorScheme.primary
                                : emptyGlassColor,
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

  Widget _iftarProgressRing() {
    final progress = _fastElapsedProgress();
    final percent = (progress * 100).round();
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFD4AF37)),
          ),
          Text(
            '$percent',
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFFD4AF37),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadFastStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fastStatus =
          prefs.getString('fast_status_${dayKey(DateTime.now())}') ?? 'fasting';
    });
  }

  Future<void> _setFastStatus(String status) async {
    HapticFeedback.selectionClick();
    setState(() => _fastStatus = status);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fast_status_${dayKey(DateTime.now())}', status);
  }

  Widget _fastingStatusCard() {
    const accent = Color(0xFFD4AF37);
    const mutedRed = Color(0xFFB86A62);
    final isFasting = _fastStatus == 'fasting';
    final isNoFastToday = !_isSunnahDay();
    final title = _fastingDayName().replaceFirst('Sunnah ', '');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        border: Border.all(color: accent.withValues(alpha: 0.2), width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.nightlight_round, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IFTAR IN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: Colors.white.withValues(alpha: 0.52),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getCountdown(),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: accent,
                        letterSpacing: 2,
                        fontFeatures: [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _iftarProgressRing(),
            ],
          ),
          const SizedBox(height: 18),
          if (isNoFastToday)
            GestureDetector(
              onTap: () => _setFastStatus('fasting'),
              child: const Text(
                'Log Fast',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isFasting ? mutedRed : accent,
                  side: BorderSide(color: isFasting ? mutedRed : accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () =>
                    _setFastStatus(isFasting ? 'broke' : 'fasting'),
                child: Text(isFasting ? 'Broke Fast' : 'Start Fast'),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final missedColor = colorScheme.error;
    final doneColor = colorScheme.primary;
    final upcomingColor = isDark ? Colors.grey[400]! : Colors.grey[500]!;
    final arabicColor = done
        ? doneColor
        : missed
        ? missedColor
        : isNext
        ? Theme.of(context).colorScheme.secondary
        : Theme.of(context).textTheme.bodyLarge?.color ?? upcomingColor;
    final icon = done
        ? Icons.check
        : missed
        ? Icons.close_rounded
        : Icons.radio_button_unchecked;
    final iconColor = done ? doneColor : (missed ? missedColor : upcomingColor);
    final statusIcon = missed
        ? Container(
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: colorScheme.error),
          )
        : Icon(icon, size: 16, color: iconColor);

    return GestureDetector(
      onTap: () => widget.onPrayerToggle(prayer),
      child: _GlassCard(
        theme: widget.theme,
        radius: 16,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              arabic,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: arabicColor,
              ),
            ),
            Text(
              prayer,
              style: GoogleFonts.syne(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: widget.theme.text3,
              ),
            ),
            const SizedBox(height: 6),
            statusIcon,
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
    return {'name': 'All Done', 'time': '--:--', 'in': '---'};
  }

  Widget _nextPrayerBanner() {
    final nextPrayer = _getNextPrayer();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT PRAYER',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        nextPrayer['name']!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _TodayScreenState.arabicNames[nextPrayer['name']] ?? '',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    nextPrayer['time']!,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    nextPrayer['in']!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final arabicHeaderColor = Theme.of(context).colorScheme.secondary;
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Container(
      width: double.infinity, // Use padding from instructions
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
      child: SafeArea(
        bottom: false, // Use Row for top bar
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 56), // spacer to center the title
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // This is the Hero Name section
                Text(
                  '\u0628\u0633\u0645 \u0627\u0644\u0644\u0647',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 13,
                    color: arabicHeaderColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  // Use Syne
                  'Rayees',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: widget.theme.text1,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  // Badge row
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: widget.theme.gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.theme.gold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: _buildMuttaqinBadge(),
                ), // Removed days to 2027, date, day from here
                const SizedBox(height: 24),
                Text(
                  '$_daysLeft',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.secondary,
                    height: 1,
                    shadows: [
                      Shadow(
                        // Using .withValues(alpha: x)
                        color: widget.theme.gold.withValues(alpha: 0.6),
                        blurRadius: 20,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'DAYS TO 2027',
                  style: GoogleFonts.syne(
                    // Use Syne
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_date \u2022 $_day', // Use DM Sans
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.topRight,
              child: Switch(
                value: themeNotifier.isDark,
                onChanged: (_) => themeNotifier.toggle(),
                activeThumbColor: Theme.of(context).colorScheme.primary,
                activeTrackColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuttaqinBadge() {
    final arabicBadgeColor = Theme.of(context).colorScheme.secondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '\u0645\u064f\u062a\u064e\u0651\u0642\u0650\u064a\u0646',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: arabicBadgeColor,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: widget.theme.gold,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'MUTTAQIN',
          style: GoogleFonts.syne(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
            color: widget.theme.gold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleTaskCount =
        _visibleTasks.length; // This is used in _buildMetricRow

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // --- Radial Orbs ---
          Positioned(
            top: -80, // Orb 1: top:-80, left:-60
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  // Orb 1 opacity
                  colors: [
                    widget.theme.gold.withValues(alpha: 0.12),
                    Colors.transparent,
                  ], // Orb 1: theme gold overlay
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -50,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.theme.teal.withValues(
                      alpha: 0.07,
                    ), // Orb 2: color emerald opacity 0.07
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  // Orb 3 opacity
                  colors: [
                    widget.theme.blue.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 2. Geometric Pattern
          const Opacity(
            opacity: 0.025,
            child: CustomPaint(
              painter: StarPatternPainter(),
              size: Size.infinite,
            ),
          ),

          // --- Main Content ---
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
                    0,
                    0,
                    0,
                    90,
                  ), // Padded bottom 90px
                  child: Column(
                    children: [
                      _wrapWithStaggered(
                        0,
                        _buildAyahCard(_TodayScreenState.ayahs[_ayahIndex]),
                      ),
                      _wrapWithStaggered(1, _buildMetricRow(visibleTaskCount)),
                      _wrapWithStaggered(2, _nextPrayerBanner()),
                      _wrapWithStaggered(3, _quranDotPill()),
                      _wrapWithStaggered(4, _buildScoreCard()),
                      _wrapWithStaggered(
                        5,
                        KeyedSubtree(
                          key: _prayersKey,
                          child: _buildPrayerGrid(),
                        ),
                      ),
                      _wrapWithStaggered(
                        6,
                        KeyedSubtree(key: _tasksKey, child: _buildTasksList()),
                      ),
                      _wrapWithStaggered(7, _suhoorReminderCard()),
                      _wrapWithStaggered(
                        8,
                        KeyedSubtree(key: _waterKey, child: _waterTracker()),
                      ),
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
        // translateY 16?0
        position: _staggeredAnims[index].drive(
          Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }

  Widget _quranDotPill() {
    final reflected = _quranReflected;
    return GestureDetector(
      onTap: () => setState(() => _quranReflected = true),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: reflected
              ? widget.theme.gold.withValues(alpha: 0.12)
              : widget.theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: reflected ? widget.theme.gold : widget.theme.border,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إِنَّ مَعَ الْعُسْرِ يُسْرًا',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: widget.theme.text1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Quran 94:6',
                    style: GoogleFonts.syne(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: widget.theme.gold,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: reflected ? Colors.white : widget.theme.gold,
                backgroundColor: reflected ? widget.theme.gold : null,
                side: BorderSide(color: widget.theme.gold),
                minimumSize: const Size(78, 34),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              onPressed: () => setState(() => _quranReflected = true),
              child: Text(reflected ? '✓ Done' : 'Reflect'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAyahCard(List<String> ayah) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _GlassCard(
        theme: widget.theme,
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary,
          width: 0.5,
        ),
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
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(width: 40, height: 1.5, color: widget.theme.gold),
              const SizedBox(height: 12),
              Text(
                ayah[1],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Quran ${ayah[2]}',
                textAlign: TextAlign.center,
                style: GoogleFonts.syne(
                  fontSize: 10,
                  color: widget.theme.blue.withValues(alpha: 0.5),
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

  Widget _buildSectionHeader(String label) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      label,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );

  Widget _buildMetricRow(int visibleTaskCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _metricRingCard(
            'Prayers',
            widget.record.prayerDone,
            7,
            widget.theme.gold,
            _prayersKey,
          ),
          const SizedBox(width: 12),
          _metricRingCard(
            'Tasks',
            _visibleTaskDone,
            visibleTaskCount,
            widget.theme.teal,
            _tasksKey,
          ),
          const SizedBox(width: 12),
          _metricRingCard(
            'Water',
            widget.waterGlasses,
            10,
            widget.theme.blue,
            _waterKey,
          ),
        ],
      ),
    );
  }

  Color _completionColor(double progress) {
    if (progress <= 0) return Theme.of(context).colorScheme.onSurface;
    if (progress < 0.5) return widget.theme.gold;
    if (progress < 1) return Theme.of(context).colorScheme.primary;
    return widget.theme.green;
  }

  Widget _metricRingCard(
    String label,
    int val,
    int max,
    Color fallbackColor,
    GlobalKey targetKey,
  ) {
    final progress = max <= 0 ? 0.0 : (val / max).clamp(0.0, 1.0);
    final ringColor = _completionColor(progress);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _scrollTo(targetKey),
        child: _GlassCard(
          theme: widget.theme,
          border: Border.all(
            color: ringColor.withValues(alpha: 0.65),
            width: 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Column(
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CustomPaint(
                    painter: _MetricRingPainter(
                      progress: progress,
                      color: ringColor,
                    ),
                    child: Center(
                      child: Text(
                        '$val',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: ringColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.syne(
                    fontSize: 9,
                    letterSpacing: 0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final totalPrayers = kPrayerNames.length;
    final prayersDone = widget.record.prayerDone;
    final totalTasks = _visibleTasks.length;
    final tasksDone = _visibleTaskDone;
    const waterGoal = 10;
    final waterDone = widget.waterGlasses.clamp(0, waterGoal);

    final prayerProgress = totalPrayers == 0
        ? 0.0
        : (prayersDone / totalPrayers).clamp(0.0, 1.0);
    final taskProgress = totalTasks == 0
        ? 0.0
        : (tasksDone / totalTasks).clamp(0.0, 1.0);
    final waterProgress = waterGoal == 0
        ? 0.0
        : (waterDone / waterGoal).clamp(0.0, 1.0);
    final todayScore =
        ((prayerProgress * 40) + (taskProgress * 40) + (waterProgress * 20))
            .round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _GlassCard(
        theme: widget.theme,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: todayScore / 100),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, arcProgress, child) {
                    return CustomPaint(
                      painter: _ScoreArcPainter(
                        progress: arcProgress,
                        color: widget.theme.gold,
                      ),
                      child: child,
                    );
                  },
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CountUpInt(
                          value: todayScore,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: widget.theme.text1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Today's Score",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$todayScore / 100',
                          style: GoogleFonts.syne(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _scoreProgressRow(
                      'Prayer',
                      widget.theme.gold,
                      prayerProgress,
                    ),
                    const SizedBox(height: 10),
                    _scoreProgressRow('Tasks', widget.theme.teal, taskProgress),
                    const SizedBox(height: 10),
                    _scoreProgressRow(
                      'Water',
                      widget.theme.blue,
                      waterProgress,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreProgressRow(String label, Color color, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label, // Use DM Sans
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: GoogleFonts.syne(
                // Use Syne
                fontSize: 9, // Smaller font size
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600, // Weight 600
              ), // Use widget.theme.gold
            ),
          ],
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return LinearProgressIndicator(
              value: value,
              backgroundColor: widget.theme.border.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPrayerGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        // Two rows using GridView or Row x 2, mx 16, gap 8
        children: [
          Row(
            children: kPrayerNames
                .take(4)
                .map(
                  (p) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: _prayerTile(p, _TodayScreenState.arabicNames[p]!),
                    ), // Each pcell _glassCard(radius:16, padding:11x6, center column)
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            cacheExtent: 1000,
            padding: EdgeInsets.zero,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
            childAspectRatio: 1.25,
            children: kPrayerNames
                .skip(4)
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: _prayerTile(p, _TodayScreenState.arabicNames[p]!),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ), // _sectionHeader("Daily Tasks")
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Daily Tasks"),
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
      '\u0648\u064e\u0645\u064e\u0646 \u064a\u064e\u062a\u064e\u0651\u0642\u0650 \u0627\u0644\u0644\u064e\u0651\u0647\u064e \u064a\u064e\u062c\u0652\u0639\u064e\u0644 \u0644\u064e\u0651\u0647\u064f \u0645\u064e\u062e\u0652\u0631\u064e\u062c\u064b\u0627',
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
  ];
}

class _GlassCard extends StatelessWidget {
  // Renamed from GlassCard to _GlassCard
  const _GlassCard({
    // New _GlassCard helper
    required this.theme,
    required this.child,
    this.padding,
    this.border,
    this.radius = 18,
  });
  // Fix 8: Class constructor
  final ThemeColors theme;
  final Widget child;
  final EdgeInsets? padding;
  final BoxBorder? border;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Fix 8: Class constructor
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: theme.border),
        boxShadow: theme.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: ClipRRect(
        // Fix 8: Class constructor
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Blur 10,10
          child: Container(
            color: Theme.of(context).cardColor,
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _CountUpInt extends StatelessWidget {
  const _CountUpInt({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text(animatedValue.round().toString(), style: style);
      },
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
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
  });

  final ThemeColors theme;
  final Map<String, DayRecord> history;
  final VoidCallback onPrintPdf;
  final String? lastPdfPath;
  final Map<String, int> incomeLog; // Not used in this file
  final Map<String, int> expenseLog;
  final void Function(DateTime, int) onSetIncome;
  final void Function(DateTime, int) onSetExpense;

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final Map<String, bool> _islamicHabits = {};

  static const _extraHabitNames = [
    "Quran 1 page",
    "Evening adhkar",
    "No phone 1hr after Fajr",
    "Sleep before midnight",
  ];

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = dayKey(DateTime.now());
    if (!mounted) return;
    setState(() {
      for (var name in _extraHabitNames) {
        _islamicHabits[name] =
            prefs.getBool('islamic_habit_${name}_$dateStr') ?? false;
      }
    });
  }

  Future<void> _saveHabit(String name, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = dayKey(DateTime.now());
    await prefs.setBool('islamic_habit_${name}_$dateStr', value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final history = widget.history;
    final today = recordFor(history, DateTime.now());

    // Calculate stats
    int streak = 0;
    for (int i = 0; i < 30; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      final r = recordFor(history, d);
      if (r.percent < 50) {
        break;
      }
      streak++;
    }

    double totalPercent = 0;
    int missed = 0;
    for (int i = 0; i < 30; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      final r = recordFor(history, d);
      totalPercent += r.percent;
      if (r.percent == 0) {
        missed++;
      }
    }
    double avgPercent = totalPercent / 30;

    final now = DateTime.now();
    int monthEarned = 0;
    int monthSpent = 0;
    for (int i = 0; i < 30; i++) {
      final d = now.subtract(Duration(days: i));
      if (d.month == now.month && d.year == now.year) {
        monthEarned += widget.incomeLog[dayKey(d)] ?? 0;
        monthSpent += widget.expenseLog[dayKey(d)] ?? 0;
      }
    }
    int monthNet = monthEarned - monthSpent;
    final monthName = [
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
    ][now.month - 1];

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(14, 48, 14, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Use Syne
                        '30 Day Monitor',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: theme.text1,
                        ),
                      ),
                      Text(
                        'Day-wise backup from Today screen',
                        style: GoogleFonts.dmSans(
                          // Use DM Sans
                          fontSize: 14,
                          color: theme.text3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: widget.onPrintPdf,
                  icon: const Icon(Icons.print),
                  tooltip: 'Print PDF',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.card, // Use cCard
                border: Border.all(
                  color: theme.isDark
                      ? const Color(0x17FFFFFF)
                      : Colors.grey.shade200,
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
                        'Today progress',
                        style: TextStyle(
                          fontSize: 16, // Use Syne
                          fontWeight: FontWeight.w800,
                          color: theme.text1,
                        ),
                      ),
                      Text(
                        '${today.percent}%',
                        style: TextStyle(
                          fontSize: 28, // Use Syne
                          fontWeight: FontWeight.w800,
                          color: kTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: today.doneTotal / today.total,
                      minHeight: 8,
                      backgroundColor: const Color(0x10FFFFFF),
                      valueColor: const AlwaysStoppedAnimation(
                        cEmerald,
                      ), // Use cEmerald
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _monitorStat(
                        'Tasks',
                        '${today.taskDone}/${kTodayTasks.length}', // Use cEmerald
                        cEmerald,
                      ),
                      const SizedBox(width: 8),
                      _monitorStat(
                        'Prayers',
                        '${today.prayerDone}/${kPrayerNames.length}',
                        cGold, // Use cGold
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.card, // Use cCard
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$streak',
                          style: TextStyle(
                            fontSize: 22, // Use Syne
                            fontWeight: FontWeight.bold,
                            color: kTeal,
                          ),
                        ),
                        Text(
                          'STREAK',
                          style: TextStyle(fontSize: 13, color: theme.text4),
                        ), // Use Syne
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: theme.border),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${avgPercent.round()}%',
                          style: TextStyle(
                            fontSize: 22, // Use Syne
                            fontWeight: FontWeight.bold,
                            color: kGold,
                          ),
                        ),
                        Text(
                          'AVG',
                          style: TextStyle(fontSize: 13, color: theme.text4),
                        ), // Use Syne
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: theme.border),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$missed',
                          style: TextStyle(
                            fontSize: 22, // Use Syne
                            fontWeight: FontWeight.bold,
                            color: kRed,
                          ),
                        ),
                        Text(
                          'MISSED',
                          style: TextStyle(fontSize: 13, color: theme.text4),
                        ), // Use Syne
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Less',
                  style: TextStyle(fontSize: 12, color: theme.text4),
                ),
                const SizedBox(width: 4), // Heatmap colors
                for (final c
                    in theme.isDark
                        ? [
                            const Color(0x33FFFFFF),
                            const Color(0x55EF4444),
                            const Color(0x88FB923C),
                            const Color(0xAAF5C842),
                            const Color(0xCC2EECC4),
                          ]
                        : [
                            const Color(0xFFE0E0E0),
                            const Color(0xFFFFCDD2),
                            const Color(0xFFFF8A80),
                            const Color(0xFFFBC02D),
                            const Color(0xFF43A047), // Use cEmerald
                          ])
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  'More',
                  style: TextStyle(fontSize: 12, color: theme.text4),
                ),
              ], // Use Syne
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              cacheExtent: 1000,
              children: List.generate(30, (index) {
                final date = DateTime.now().subtract(
                  Duration(days: 29 - index),
                );
                final record = recordFor(history, date);
                final percent = record.percent;
                final isPast = date.isBefore(
                  DateTime.now().copyWith(
                    hour: 0,
                    minute: 0,
                    second: 0,
                    microsecond: 0,
                    millisecond: 0,
                  ),
                );
                final isToday = dayKey(date) == dayKey(DateTime.now());
                Color color;
                if (theme.isDark) {
                  if (percent >= 80) {
                    color = cEmerald.withValues(alpha: 0.85); // Use cEmerald
                  } else if (percent >= 60) {
                    color = cGold.withValues(alpha: 0.75); // Use cGold
                  } else if (percent >= 40) {
                    color = cGold.withValues(alpha: 0.65); // Use cGold
                  } else if (percent > 0) {
                    color = cRose.withValues(alpha: 0.5); // Use cRose
                  } else if (isPast) {
                    color = cRose.withValues(alpha: 0.2); // Use cRose
                  } else {
                    color = cBg; // Use cBg
                  }
                } else {
                  if (percent >= 80) {
                    color = const Color(0xFF43A047);
                  } else if (percent >= 60) {
                    color = const Color(0xFFFBC02D);
                  } else if (percent >= 40) {
                    color = const Color(0xFFFF8A80);
                  } else if (percent > 0) {
                    color = const Color(0xFFFFCDD2);
                  } else if (isPast) {
                    color = const Color(0xFFE0E0E0);
                  } else {
                    color = const Color(0xFFF5F5F5);
                  }
                }
                return Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: color,
                    border: isToday
                        ? Border.all(
                            color: cText.withValues(alpha: 0.6), // Use cText
                            width: 1.5,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            if (widget.lastPdfPath != null) ...[
              const SizedBox(height: 10),
              Text(
                'Last PDF: ${widget.lastPdfPath}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.text3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${monthName.toUpperCase()} 30 DAY DATA',
                  style: TextStyle(
                    fontSize: 12, // Use Syne
                    fontWeight: FontWeight.w800,
                    color: theme.text4,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'Net Income: \u20B9$monthNet',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12, // Use Syne
                    fontWeight: FontWeight.w800,
                    color: monthNet >= 0 ? kTeal : kRed,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(30, (index) {
              final date = DateTime.now().subtract(Duration(days: index));
              return DayHistoryCard(
                theme: theme,
                date: date,
                record: recordFor(history, date),
                income: widget.incomeLog[dayKey(date)] ?? 0,
                expense: widget.expenseLog[dayKey(date)] ?? 0,
                onSetIncome: widget.onSetIncome,
                onSetExpense: widget.onSetExpense,
              );
            }),
            Container(
              margin: const EdgeInsets.only(bottom: 14, top: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.card, // Use cCard
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EXTRA HABITS',
                        style: TextStyle(
                          fontSize: 11, // Use Syne
                          color: theme.text4,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '${_islamicHabits.values.where((v) => v).length}/4 done',
                        style: TextStyle(
                          fontSize: 11, // Use Syne
                          color: kGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _islamicHabits.values.where((v) => v).length / 4,
                    backgroundColor: theme.border,
                    valueColor: const AlwaysStoppedAnimation(
                      cGold,
                    ), // Use cGold
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    ["Quran 1 page", Icons.menu_book_outlined, kGold],
                    ["Evening adhkar", Icons.favorite_outline, kTeal],
                    [
                      "No phone 1hr after Fajr",
                      Icons.phone_disabled_outlined,
                      kRed,
                    ],
                    ["Sleep before midnight", Icons.bedtime_outlined, kBlue],
                  ].map((h) {
                    final done = _islamicHabits[h[0]] ?? false;
                    return GestureDetector(
                      onTap: () => setState(() {
                        final name = h[0] as String;
                        final newVal = !(_islamicHabits[name] ?? false);
                        _islamicHabits[name] = newVal;
                        _saveHabit(name, newVal);
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              done // Use cCard
                              ? (h[2] as Color).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: done
                                ? (h[2] as Color).withValues(alpha: 0.4)
                                : theme.border,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color:
                                    done // Use cCard
                                    ? h[2] as Color
                                    : Colors.transparent,
                                border: Border.all(
                                  color: done ? h[2] as Color : theme.text4,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: done
                                  ? const Icon(
                                      Icons.check_circle,
                                      size: 18,
                                      color: Color(0xFF1D9E75),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              h[1] as IconData,
                              size: 16,
                              color: h[2] as Color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              h[0] as String,
                              style: TextStyle(
                                fontSize: 13, // Use Syne
                                fontWeight: FontWeight.w600,
                                color: done ? theme.text3 : theme.text1,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            _sunnahFastTrackerCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _sunnahFastTrackerCard(ThemeColors theme) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC8C2B8)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sunnah Fast Tracker',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                'Week 22',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7A5C00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E7),
                    border: Border.all(
                      color: const Color(0xFFC89A2E),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'MONDAY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7A5C00),
                        ),
                      ),
                      SizedBox(height: 4),
                      Icon(
                        Icons.nightlight_round,
                        color: Color(0xFF7A5C00),
                        size: 24,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'FASTED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7A5C00),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6F2),
                    border: Border.all(
                      color: const Color(0xFFC8C2B8),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'THURSDAY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A4A4A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Icon(
                        Icons.radio_button_unchecked,
                        color: Color(0xFF4A4A4A),
                        size: 24,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'UPCOMING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A4A4A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This month',
                style: TextStyle(fontSize: 11, color: Color(0xFF4A4A4A)),
              ),
              Text(
                '6 / 8 Sunnah days fasted',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF085041),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              value: 6 / 8,
              backgroundColor: Color(0xFFE8E3DA),
              color: Color(0xFF085041),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE1F5EE),
              border: Border.all(color: const Color(0xFF85C4B5)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current streak',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF085041),
                  ),
                ),
                Text(
                  '12 weeks',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF085041),
                  ),
                ),
              ],
            ),
          ),
          _monthlyFastingHeatmap(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              border: Border.all(color: const Color(0xFFC89A2E)),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              '"Deeds are presented to Allah on Monday and Thursday - I love for my deeds to be presented while I am fasting." - Prophet',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF7A5C00),
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthlyFastingHeatmap() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - DateTime.monday;
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();
    final cellCount = rowCount * 7;

    Color cellColor(DateTime? date) {
      if (date == null) return Colors.transparent;
      if (date.isAfter(DateTime(now.year, now.month, now.day))) {
        return Colors.transparent;
      }
      final sunnahDay =
          date.weekday == DateTime.monday || date.weekday == DateTime.thursday;
      if (sunnahDay) return const Color(0xFFC89A2E);
      final fasted = date.day % 3 != 0;
      return fasted ? const Color(0xFF085041) : const Color(0xFFE8E3DA);
    }

    Widget legendDot(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF4A4A4A)),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F2),
        border: Border.all(color: const Color(0xFFC8C2B8)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MONTHLY FASTING',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: Color(0xFF4A4A4A),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final day in [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ])
                Expanded(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A4A4A),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leadingBlanks + 1;
              final hasDate = dayNumber >= 1 && dayNumber <= daysInMonth;
              final date = hasDate
                  ? DateTime(now.year, now.month, dayNumber)
                  : null;
              final isToday =
                  date != null &&
                  date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;
              final isFuture =
                  date != null &&
                  date.isAfter(DateTime(now.year, now.month, now.day));

              return Opacity(
                opacity: isFuture ? 0.3 : 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: cellColor(date),
                    borderRadius: BorderRadius.circular(5),
                    border: isToday
                        ? Border.all(color: const Color(0xFFC89A2E), width: 2)
                        : null,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              legendDot(const Color(0xFF085041), 'Fasted'),
              legendDot(const Color(0xFFC89A2E), 'Mon/Thu Sunnah'),
              legendDot(const Color(0xFFE8E3DA), 'Skipped'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monitorStat(String label, String value, Color color) {
    final theme = widget.theme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Use cCard
          color: theme.card,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: theme.isDark
                ? const Color(0x17FFFFFF)
                : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12, // Use Syne
                color: theme.text4,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13, // Use Syne
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
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
  });

  final ThemeColors theme;
  final DateTime date;
  final DayRecord record;
  final int income;
  final int expense;
  final void Function(DateTime, int) onSetIncome;
  final void Function(DateTime, int) onSetExpense;

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
              Text(
                '${record.doneTotal}/${record.total}',
                style: TextStyle(
                  fontSize: 13, // Use Syne
                  fontWeight: FontWeight.w800,
                  color: theme.gold,
                ),
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

const _prayerTimes = {
  'Tahajjud': TimeOfDay(hour: 3, minute: 30),
  'Fajr': TimeOfDay(hour: 5, minute: 15),
  'Dhuha': TimeOfDay(hour: 8, minute: 0),
  'Dhuhr': TimeOfDay(hour: 12, minute: 30),
  'Asr': TimeOfDay(hour: 15, minute: 45),
  'Maghrib': TimeOfDay(hour: 18, minute: 30),
  'Isha': TimeOfDay(hour: 20, minute: 0),
};

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
    'Maghrib': Icons.wb_twilight,
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
  final int maxReps;
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
  });

  final ThemeColors theme;
  final ValueChanged<WorkoutSummary> onWorkoutCompleted;
  final ValueChanged<WorkoutProgressSnapshot> onWorkoutProgressChanged;

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
      title: 'Day 1 - Push',
      freq: 'Mon / Thu',
      icon: Icons.fitness_center,
      color: kRed,
      exercises: [
        ['Push-ups', '4 x 20-25 reps', 'Chest, shoulders, triceps'],
        ['Diamond push-ups', '3 x 15 reps', 'Inner chest & triceps'],
        ['Pike push-ups', '4 x 12 reps', 'Shoulders'],
        ['Tricep dips (chair)', '3 x 15 reps', 'Triceps'],
      ],
    ),
    WorkoutDay(
      title: 'Day 2 - Legs & Core',
      freq: 'Tue / Fri',
      icon: Icons.directions_run,
      color: kGreen,
      exercises: [
        ['Bodyweight squats', '4 x 20-25 reps', 'Quads'],
        ['Jump squats', '3 x 15 reps', 'Fat burn'],
        ['Lunges', '3 x 12 each leg', 'Hamstrings'],
        ['Plank hold', '4 x 45-60 seconds', 'Core'],
        ['Leg raises', '3 x 15 reps', 'Lower abs'],
      ],
    ),
    WorkoutDay(
      title: 'Day 3 - Back & Biceps',
      freq: 'Wed / Sat',
      icon: Icons.accessibility_new,
      color: kGold,
      exercises: [
        ['Pull-ups / Chin-ups', '4 x max reps', 'Back & Biceps'],
        ['Inverted rows (table)', '4 x 12 reps', 'Back'],
        ['Towel bicep curls', '3 x 15 each arm', 'Biceps'],
      ],
    ),
    WorkoutDay(
      title: 'Day 4 - HIIT Full Body',
      freq: 'Sun - Max fat burn',
      icon: Icons.local_fire_department,
      color: kRed,
      exercises: [
        ['Burpees', '4 x 10 reps', 'Full body'],
        ['Mountain climbers', '4 x 30 seconds', 'Belly fat'],
        ['Russian twists', '3 x 20 reps', 'Obliques'],
        ['High knees', '4 x 30 seconds', 'Cardio'],
      ],
    ),
  ];

  final Map<String, WorkoutExerciseState> _exerciseStates = {};
  final Map<String, bool> _expandedCards = {};
  final ScrollController _scrollController = ScrollController();
  SharedPreferences? _prefs;
  String? _activeDayTitle;
  String? _activeWorkoutDateKey;
  Timer? _restTimer;
  int _restSeconds = 0;
  int _totalSets = 0;
  int _completedSets = 0;
  int _completedExercises = 0;
  double _setProgress = 0.0;
  bool _isResting = false;
  String? _restExerciseKey;
  late WorkoutDay _todayDay = _plan.first;
  String _buttonLabel = '';
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
    final today = _todayWorkoutDay() ?? _plan.first;
    _todayDay = today;
    _totalSets = _dayTotalSets(today);
    _completedSets = _dayCompletedSets(today);
    _completedExercises = _dayCompletedExercises(today);
    _setProgress = _totalSets == 0 ? 0.0 : _completedSets / _totalSets;
    _buttonLabel = _completedExercises == today.exercises.length
        ? 'Workout complete'
        : _hasProgress(today)
        ? 'Resume Workout'
        : "Start today's workout";

    setState(() {});
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _scrollController.dispose();
    _bodyWeightFocusNode.dispose();
    _bodyWeightController.dispose();
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

  void _saveBodyWeight() {
    final next = int.tryParse(_bodyWeightController.text.trim());
    if (!mounted) return;
    setState(() {
      if (next != null && next > 0) {
        _bodyWeight = next;
      }
      _bodyWeightController.text = '$_bodyWeight';
      _isEditingBodyWeight = false;
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final expanded = _decodeBoolMap(prefs.getString(_prefsExpandedKey));
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

  int _dayTotalSets(WorkoutDay day) {
    return day.exercises.fold(0, (sum, e) => sum + parseSets(e[1]));
  }

  int _dayCompletedSets(WorkoutDay day) {
    return day.exercises.fold(0, (sum, exercise) {
      final key = '${day.title}|${exercise[0]}';
      final state = _exerciseStates[key];
      return sum + (state?.completedSets ?? 0);
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
    final today = _todayWorkoutDay();
    if (today == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workout scheduled for today.')),
      );
      return;
    }
    if (!(_expandedCards[today.title] ?? false)) {
      _toggleCard(today.title);
    }
    setState(() {
      _activeDayTitle = today.title;
      _activeWorkoutDateKey ??= dayKey(DateTime.now());
    });
    _savePreferences();
    _saveWorkoutProgress(today);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Ready for ${today.title}!')));
  }

  void _startRestTimer() {
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
    if (_restExerciseKey == null) {
      _clearRest();
      return;
    }
    final key = _restExerciseKey!;
    final state = _exerciseStates[key];
    if (state != null && !state.completed) {
      state.awaitingNextSet = false;
      state.currentSet = min(state.currentSet + 1, state.totalSets);
      state.repsRemaining = state.maxReps;
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
      _savePreferences();
      _recalculateStats();
      final activeDay = _plan.firstWhere(
        (day) => day.exercises.any(
          (exercise) => '${day.title}|${exercise[0]}' == key,
        ),
        orElse: () => _todayWorkoutDay() ?? _plan.first,
      );
      _saveWorkoutProgress(activeDay);
    }
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
    final today = _todayWorkoutDay();
    if (today == null) {
      return;
    }
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
    setState(() {
      _activeDayTitle = null;
      _activeWorkoutDateKey = null;
    });
    _savePreferences();
    _saveWorkoutProgress(
      today,
      completed: true,
      dateKeyOverride: completionDateKey,
    );
    if (completedToday) {
      widget.onWorkoutCompleted(summary);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Great job! ${today.title} complete.')),
    );
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
    final today = _todayDay;
    final colorScheme = Theme.of(context).colorScheme;
    final workoutPrimary = theme.isDark
        ? theme.teal
        : HSLColor.fromColor(colorScheme.primary).withLightness(0.26).toColor();
    final ringFill = workoutPrimary;
    final buttonColor = theme.isDark ? kTeal : workoutPrimary;
    final cardBorder = theme.border;
    final progressTrack = theme.isDark ? theme.border : theme.text4;

    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              clipBehavior: Clip.none,
              padding: const EdgeInsets.fromLTRB(16, 30, 16, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Training',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: theme.text3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Workout',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: theme.text1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_weekdayName(DateTime.now())} · ${today.title}',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.text3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _workoutStatsGrid(theme, workoutPrimary),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: theme.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cardBorder, width: 0.4),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 84,
                              height: 84,
                              child: CircularProgressIndicator(
                                value: _setProgress,
                                strokeWidth: 10,
                                valueColor: AlwaysStoppedAnimation(ringFill),
                                backgroundColor: progressTrack,
                              ),
                            ),
                            Text(
                              '${(_setProgress * 100).round()}%',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Today's session",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_completedExercises/${today.exercises.length} exercises done',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.text3,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _exerciseLogSection(theme, today, workoutPrimary, cardBorder),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _completedExercises == today.exercises.length
                          ? null
                          : _startTodayWorkout,
                      child: Text(
                        _buttonLabel,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ),
          if (_isResting)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: IgnorePointer(
                ignoring: !_isResting,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rest timer',
                        style: TextStyle(
                          color: theme.text1,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 110,
                            height: 110,
                            child: CircularProgressIndicator(
                              value: _restSeconds / 90,
                              strokeWidth: 10,
                              valueColor: AlwaysStoppedAnimation(theme.gold),
                              backgroundColor: theme.border,
                            ),
                          ),
                          Text(
                            '${_restSeconds}s',
                            style: TextStyle(
                              color: theme.text1,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Next set starts automatically when the rest ends.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.text3, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.text4.withValues(
                              alpha: 0.14,
                            ),
                            foregroundColor: theme.text1,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _skipRest,
                          child: const Text('Skip rest'),
                        ),
                      ),
                    ],
                  ),
                ),
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
        _dayCompletedExercises(_todayDay) == _todayDay.exercises.length;
    final currentStreak = todayCompleted ? 1 : 0;
    final monthSessions = todayCompleted ? 1 : 0;
    final hoursThisWeek = (_dayCompletedSets(_todayDay) * 0.18).clamp(0.0, 9.9);

    return Row(
      children: [
        Expanded(
          child: _statChip(
            theme,
            workoutPrimary,
            label: 'Streak',
            value: '${currentStreak}d',
            icon: Icons.local_fire_department,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statChip(
            theme,
            workoutPrimary,
            label: 'Sessions',
            value: '$monthSessions',
            icon: Icons.fitness_center,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statChip(
            theme,
            workoutPrimary,
            label: 'Weight',
            value: '${_bodyWeight}kg',
            icon: Icons.monitor_weight_outlined,
            editableWeight: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statChip(
            theme,
            workoutPrimary,
            label: 'Hours',
            value: hoursThisWeek.toStringAsFixed(1),
            icon: Icons.timer_outlined,
          ),
        ),
      ],
    );
  }

  Widget _statChip(
    ThemeColors theme,
    Color color, {
    required String label,
    required String value,
    required IconData icon,
    bool editableWeight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          if (editableWeight && _isEditingBodyWeight)
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
                          fontSize: 16,
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
                        fontSize: 16,
                        color: theme.text1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (editableWeight)
            GestureDetector(
              onTap: _startBodyWeightEdit,
              child: SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.text1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.text1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10,
              color: theme.text3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _exerciseLogSection(
    ThemeColors theme,
    WorkoutDay today,
    Color workoutPrimary,
    Color cardBorder,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Exercise log',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.text1,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _startTodayWorkout,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(foregroundColor: workoutPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final exercise in today.exercises)
            _exerciseLogRow(theme, today, exercise, workoutPrimary),
        ],
      ),
    );
  }

  Widget _exerciseLogRow(
    ThemeColors theme,
    WorkoutDay day,
    List<String> exercise,
    Color workoutPrimary,
  ) {
    final key = '${day.title}|${exercise[0]}';
    final state = _exerciseStates[key];
    final completed = state?.completed == true;
    final sets = parseSets(exercise[1]);
    final reps = parseReps(exercise[1]);
    final muscle = exercise.length > 2 ? exercise[2] : '';
    final groupColor = muscle.contains('Bicep')
        ? theme.gold
        : muscle.contains('Back')
        ? Colors.blueAccent
        : workoutPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: groupColor, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _toggleExercise(key),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: completed
                      ? workoutPrimary
                      : Colors.transparent,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: completed
                        ? const Center(
                            child: Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise[0],
                      style: TextStyle(
                        color: theme.text1,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$sets x $reps x bodyweight',
                      style: TextStyle(color: theme.text3, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({
    super.key,
    required this.theme,
    required this.incomeLog,
    required this.expenseLog,
    required this.onAddEntry,
    required this.onAddExpense,
  });

  final ThemeColors theme;
  final Map<String, int> incomeLog;
  final Map<String, int> expenseLog;
  final ValueChanged<int> onAddEntry;
  final ValueChanged<int> onAddExpense;

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  final TextEditingController _incomeCtrl = TextEditingController();
  final TextEditingController _expenseCtrl = TextEditingController();
  String _filter = 'All';
  // Editable sources state
  late List<Map<String, dynamic>> _sources = _defaultIncomeSources();
  final TextEditingController _subtitleCtrl = TextEditingController();
  bool _editingSubtitle = false;
  late FocusNode _subtitleFocusNode;

  @override
  void initState() {
    super.initState();
    _loadIncomeSourcesForMonth();
    _subtitleCtrl.text = 'Automation career to \u20B93 lakhs/month';
    _subtitleFocusNode = FocusNode();
    _subtitleFocusNode.addListener(() {
      if (!_subtitleFocusNode.hasFocus && _editingSubtitle) {
        setState(() => _editingSubtitle = false);
      }
    });
  }

  List<Map<String, dynamic>> _defaultIncomeSources() {
    return [
      {
        'name': 'Autonexuz — YouTube',
        'type': 'Ad Revenue + Sponsorship',
        'color': kGold,
        'amount': 0,
        'editing': false,
      },
      {
        'name': 'Remote PLC Support',
        'type': 'Upwork · 3 clients',
        'color': kBlue,
        'amount': 0,
        'editing': false,
      },
      {
        'name': 'Salary',
        'type': 'Industrial Automation',
        'color': kGreen,
        'amount': 0,
        'editing': false,
      },
    ];
  }

  String _incomeSourcesKey(DateTime date) {
    return 'income_sources_${date.year}-${date.month.toString().padLeft(2, '0')}';
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
                (source['color'] as num?)?.toInt() ?? kGold.toARGB32(),
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

  String _monthYear(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    _expenseCtrl.dispose();
    _subtitleCtrl.dispose();
    _subtitleFocusNode.dispose();
    super.dispose();
  }

  void _addIncome() {
    final amount = int.tryParse(_incomeCtrl.text.trim());
    if (amount != null && amount > 0) {
      setState(() {
        _sources.first['amount'] = (_sources.first['amount'] as int) + amount;
      });
      _saveIncomeSourcesForMonth();
      widget.onAddEntry(amount);
      _incomeCtrl.clear();
    }
  }

  void _addExpense() {
    final amount = int.tryParse(_expenseCtrl.text.trim());
    if (amount != null && amount > 0) {
      widget.onAddExpense(amount);
      _expenseCtrl.clear();
    }
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

  Widget _summaryTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.theme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: widget.theme.text4,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountInput({
    required TextEditingController controller,
    required String hint,
    required Color color,
    required IconData icon,
    required VoidCallback onSubmit,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontFamily: 'Roboto',
              color: widget.theme.text1,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontFamily: 'Roboto',
                color: widget.theme.text4,
              ),
              filled: true,
              fillColor: widget.theme.card,
              prefixIcon: Icon(icon, color: color, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.theme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.theme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color, width: 1.2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 13,
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onSubmit,
          style: IconButton.styleFrom(
            backgroundColor: color.withValues(
              alpha: widget.theme.isDark ? 0.18 : 0.12,
            ),
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.35)),
          ),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _filterChip(String label) {
    final selected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 32),
        decoration: BoxDecoration(
          color: selected
              ? widget.theme.gold.withValues(alpha: 0.14)
              : widget.theme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kGold : widget.theme.border,
            width: selected ? 1 : 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? kGold : widget.theme.text3,
          ),
        ),
      ),
    );
  }

  Widget _amountText({required int amount, required bool income}) {
    final color = amount == 0
        ? Colors.grey.shade500
        : income
        ? widget.theme.teal
        : widget.theme.red;
    final prefix = amount == 0
        ? ''
        : income
        ? '+'
        : '-';
    return Text(
      '$prefix${_money(amount)}',
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _incomeSourcesList(ThemeColors theme, int totalEarned) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border, width: 0.5),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sources',
              style: TextStyle(
                fontSize: 12,
                color: theme.text3,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _sources.length; i++) ...[
            _incomeSourceRow(theme, i),
            if (i != _sources.length - 1)
              Divider(color: theme.border, height: 18),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _sources.add({
                  'name': 'New source',
                  'type': 'Type',
                  'color': kGold,
                  'amount': 0,
                  'editing': true,
                });
                // ensure only this row is editing
                for (var j = 0; j < _sources.length; j++) {
                  _sources[j]['editing'] = j == _sources.length - 1;
                }
              });
              _saveIncomeSourcesForMonth();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.border,
                  width: 1,
                  style: BorderStyle.solid,
                ),
                color: Colors.transparent,
              ),
              child: Center(
                child: Text(
                  '+ Add Source',
                  style: TextStyle(
                    color: theme.text4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _incomeSourceRow(ThemeColors theme, int index) {
    final src = _sources[index];
    final editing = src['editing'] == true;
    final nameCtrl = TextEditingController(text: src['name'] as String);
    final typeCtrl = TextEditingController(text: src['type'] as String);
    final amountCtrl = TextEditingController(
      text: (src['amount'] as int).toString(),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      child: editing
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: src['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: nameCtrl,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: theme.text1,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.04),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: typeCtrl,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.text3,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.04),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 20,
                            color: kGold,
                          ),
                          decoration: InputDecoration(
                            prefixText: '\u20B9',
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            src['name'] = nameCtrl.text.trim();
                            src['type'] = typeCtrl.text.trim();
                            src['amount'] =
                                int.tryParse(amountCtrl.text.trim()) ??
                                (src['amount'] as int);
                            src['editing'] = false;
                          });
                          _saveIncomeSourcesForMonth();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(
                            45,
                            158,
                            107,
                            0.2,
                          ),
                          foregroundColor: const Color(0xFF2D9E6B),
                          side: BorderSide(
                            color: const Color.fromRGBO(45, 158, 107, 0.4),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            src['editing'] = false;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          foregroundColor: theme.text3,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: src['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        src['name'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.text1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        src['type'] as String,
                        style: TextStyle(fontSize: 11, color: theme.text3),
                      ),
                    ],
                  ),
                ),
                Text(
                  _money(src['amount'] as int),
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 20,
                    color: src['color'] as Color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    // open edit for this row and close others
                    setState(() {
                      for (var j = 0; j < _sources.length; j++) {
                        _sources[j]['editing'] = j == index;
                      }
                    });
                  },
                  child: Text('✎', style: TextStyle(color: theme.text4)),
                ),
              ],
            ),
    );
  }

  Widget _annualGoalCard(ThemeColors theme, int totalEarned) {
    const annualGoal = 200000;
    final annualEarned = totalEarned;
    final progress = (annualEarned / annualGoal).clamp(0.0, 1.0);
    final monthsRemaining = 6; // per spec example

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGold.withValues(alpha: 0.12), width: 0.8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Annual Goal',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.text1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  color: kGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: theme.border,
              valueColor: const AlwaysStoppedAnimation(kGold),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_money(annualEarned)} of ${_money(annualGoal)} · $monthsRemaining months remaining',
              style: TextStyle(fontSize: 11, color: theme.text3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final now = DateTime.now();
    // Compute total from editable sources (in-memory)
    final totalEarned = _sources.fold<int>(
      0,
      (sum, s) => sum + (s['amount'] as int),
    );
    final totalSpent = _monthTotal(widget.expenseLog, now);
    final netSavings = totalEarned - totalSpent;
    final dailyAvg = totalEarned / now.day;
    final dailyAvgSpent = totalSpent / now.day;
    final target = 300000;
    final targetProgress = (totalEarned / target).clamp(0.0, 1.0);
    final comparisonMax = max(totalEarned, totalSpent);
    final visibleDays =
        List.generate(
          now.day,
          (i) => DateTime(now.year, now.month, now.day - i),
        ).where((date) {
          final earned = widget.incomeLog[dayKey(date)] ?? 0;
          final spent = widget.expenseLog[dayKey(date)] ?? 0;
          if (_filter == 'Income') {
            return earned > 0;
          }
          if (_filter == 'Expenses') {
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
        padding: const EdgeInsets.fromLTRB(14, 48, 14, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Finance'.toUpperCase(),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: kGold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Income',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: theme.text1,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                setState(() {
                  _editingSubtitle = true;
                });
              },
              child: _editingSubtitle
                  ? TextField(
                      controller: _subtitleCtrl,
                      autofocus: true,
                      style: TextStyle(fontSize: 14, color: theme.text1),
                      decoration: InputDecoration(border: InputBorder.none),
                      onSubmitted: (_) =>
                          setState(() => _editingSubtitle = false),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            _subtitleCtrl.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.text3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('✎', style: TextStyle(color: theme.text4)),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.card,
                border: Border.all(
                  color: kMuted.withValues(alpha: 0.14),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Month · Total · ${_monthYear(now)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.text4,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Transform.translate(
                                offset: const Offset(0, -6),
                                child: Text(
                                  '\u20B9',
                                  style: GoogleFonts.cormorantGaramond(
                                    fontSize: 14,
                                    color: kGold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _money(totalEarned).replaceAll('\u20B9', ''),
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w300,
                                  color: kGold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'of ${_money(200000)} annual goal',
                            style: TextStyle(fontSize: 12, color: theme.text3),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.trending_up,
                                size: 12,
                                color: kTeal,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '▲ 12% vs last month',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: kTeal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.trending_up,
                                size: 12,
                                color: kTeal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_money(dailyAvg)}/day',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: kTeal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.trending_down,
                                size: 12,
                                color: kRed,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_money(dailyAvgSpent)}/day',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: kRed,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'daily avg',
                            style: TextStyle(fontSize: 11, color: theme.text4),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: targetProgress,
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      valueColor: const AlwaysStoppedAnimation(kGold),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(targetProgress * 100).toStringAsFixed(1)}% of ${_money(target)} target',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12,
                      color: kGold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _incomeSourcesList(theme, totalEarned),
            const SizedBox(height: 12),
            _annualGoalCard(theme, totalEarned),
            const SizedBox(height: 12),
            Row(
              children: [
                _summaryTile(
                  'EARNED',
                  _money(totalEarned),
                  totalEarned > 0 ? kTeal : kMuted,
                ),
                const SizedBox(width: 8),
                _summaryTile(
                  'SPENT',
                  _money(totalSpent),
                  totalSpent > 0 ? kRed : kMuted,
                ),
                const SizedBox(width: 8),
                _summaryTile(
                  'SAVINGS',
                  '${netSavings < 0 ? '-' : ''}${_money(netSavings)}',
                  netSavings > 0
                      ? theme.green
                      : netSavings < 0
                      ? theme.red
                      : Colors.grey.shade500,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _summaryTile(
                  'AVG EARNED',
                  '${_money(dailyAvg)}/day',
                  dailyAvg > 0 ? kTeal : kMuted,
                ),
                const SizedBox(width: 8),
                _summaryTile(
                  'AVG SPENT',
                  '${_money(dailyAvgSpent)}/day',
                  dailyAvgSpent > 0 ? kRed : kMuted,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.border, width: 0.5),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      if (comparisonMax > 0)
                        FractionallySizedBox(
                          widthFactor: (totalEarned / comparisonMax).clamp(
                            0.0,
                            1.0,
                          ),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: kTeal,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      if (comparisonMax > 0)
                        Align(
                          alignment: Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: (totalSpent / comparisonMax).clamp(
                              0.0,
                              1.0,
                            ),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: kRed,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Earned',
                        style: TextStyle(fontSize: 11, color: kTeal),
                      ),
                      Text(
                        'Spent',
                        style: TextStyle(fontSize: 11, color: kRed),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _amountInput(
              controller: _incomeCtrl,
              hint: 'Enter today earnings \u20B9',
              color: kTeal,
              icon: Icons.trending_up,
              onSubmit: _addIncome,
            ),
            const SizedBox(height: 8),
            _amountInput(
              controller: _expenseCtrl,
              hint: 'Enter today expense \u20B9',
              color: kRed,
              icon: Icons.trending_down,
              onSubmit: _addExpense,
            ),
            const SizedBox(height: 16),
            Center(child: _filterChip('All')),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DATE | EARNED | SPENT',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.text4,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...visibleDays.map((date) {
              final earned = widget.incomeLog[dayKey(date)] ?? 0;
              final spent = widget.expenseLog[dayKey(date)] ?? 0;
              return RepaintBoundary(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.border, width: 0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        shortDate(date),
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.text2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _amountText(amount: earned, income: true),
                          const SizedBox(width: 14),
                          _amountText(amount: spent, income: false),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
