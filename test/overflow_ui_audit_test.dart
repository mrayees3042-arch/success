import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:success/app_theme.dart';
import 'package:success/main.dart';
import 'package:success/providers/theme_provider.dart';
import 'package:success/screens/life_plan_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    debugPrint('=== FLUTTER ERROR CAUGHT ===');
    debugPrint('Exception: ${details.exception}');
    if (details.informationCollector != null) {
      for (final node in details.informationCollector!()) {
        debugPrint('COLLECTOR NODE: ${node.toStringDeep()}');
      }
    }
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'income_debt_total': 50000,
      'income_debt_paid': 12500,
      'income_debt_owed_to': 'Bank Loan',
      'income_daily_target': 1500,
      'user_name': 'Rayyan',
      'user_goal_year': 2030,
    });
  });

  group('Visual Layout & RenderFlex Overflow Stress Audit', () {
    final viewports = [
      const Size(320, 600), // Ultra compact
      const Size(360, 780), // Typical Android
      const Size(393, 852), // Modern standard
      const Size(412, 915), // Large Android (Vivo V2153)
    ];

    for (int i = 0; i < viewports.length; i++) {
      final size = viewports[i];
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('IncomeScreen on $label (textScale 1.0)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime.now();
        final incomeMap = <String, int>{
          dayKey(now): 1500,
          dayKey(now.subtract(const Duration(days: 1))): 800,
        };
        final expenseMap = <String, int>{dayKey(now): 400};

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: IncomeScreen(
                theme: getTheme(),
                incomeLog: incomeMap,
                expenseLog: expenseMap,
                onAddEntry: (_) {},
                onAddExpense: (_) {},
              ),
            ),
          ),
        );

        for (int step = 0; step < 5; step++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        for (final ro in tester.allRenderObjects.whereType<RenderFlex>()) {
          if (ro.toString().contains('OVERFLOWING') || ro.toString().contains('overflowed')) {
            debugPrint('OVERFLOWING RENDER OBJECT:');
            debugPrint(ro.toStringDeep());
          }
        }

        final err = tester.takeException();
        if (err is FlutterError) {
          debugPrint('FULL FLUTTER ERROR:\n${err.toStringDeep()}');
        }
        expect(err, isNull);
      });

      testWidgets('IncomeScreen on $label (large font scale 1.35)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime.now();
        final incomeMap = <String, int>{
          dayKey(now): 10000,
          dayKey(now.subtract(const Duration(days: 1))): 5000,
        };
        final expenseMap = <String, int>{dayKey(now): 3000};

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.35)),
              child: Scaffold(
                body: IncomeScreen(
                  theme: getTheme(),
                  incomeLog: incomeMap,
                  expenseLog: expenseMap,
                  onAddEntry: (_) {},
                  onAddExpense: (_) {},
                ),
              ),
            ),
          ),
        );

        for (final ro in tester.allRenderObjects.whereType<RenderFlex>()) {
          if (ro.toString().contains('OVERFLOWING') || ro.toString().contains('overflowed')) {
            debugPrint('OVERFLOWING RENDER OBJECT IN 1.35x:');
            debugPrint(ro.toStringDeep());
          }
        }

        final err = tester.takeException();
        if (err is FlutterError) {
          debugPrint('FULL FLUTTER ERROR IN 1.35x:\n${err.toStringDeep()}');
        }
        expect(err, isNull);
      });

      testWidgets('GoalsScreen on $label (large font scale 1.35)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.35)),
              child: Scaffold(
                body: GoalsScreen(
                  theme: getTheme(),
                  history: const {},
                  onTaskToggle: (_) {},
                  onPrayerToggle: (_) {},
                ),
              ),
            ),
          ),
        );

        for (int step = 0; step < 5; step++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.byType(GoalsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('LifePlanScreen on $label (large font scale 1.35)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.35)),
              child: Scaffold(
                body: LifePlanScreen(
                  theme: getTheme(),
                  userGoalYear: 2030,
                ),
              ),
            ),
          ),
        );

        for (int step = 0; step < 5; step++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.byType(LifePlanScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('TodayScreen on $label (large font scale 1.35)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => ThemeNotifier(),
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.35)),
                child: Scaffold(
                  body: TodayScreen(
                    theme: getTheme(),
                    record: DayRecord.empty(),
                    workoutProgress: null,
                    onTaskToggle: (_) {},
                    onTaskEdit: (_, _) {},
                    onTaskAdd: (_) {},
                    onTaskDelete: (_) {},
                    onTaskReorder: (_, _) {},
                    onPrayerToggle: (_) {},
                    onThemeToggle: () {},
                    isDark: true,
                    orbController: AnimationController(
                      vsync: const TestVSync(),
                      duration: const Duration(seconds: 1),
                    ),
                    waterGlasses: 4,
                    onWaterChange: (_) {},
                    userName: 'Rayyan',
                    userGoalYear: 2030,
                    userGoalMonth: 12,
                    userGoalDay: 1,
                    userDob: '2000-01-01',
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(TodayScreen), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('HabitsScreen on $label (large font scale 1.35)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.35)),
              child: Scaffold(
                body: HabitsScreen(
                  theme: getTheme(),
                  history: const {},
                  onPrintPdf: () {},
                  lastPdfPath: null,
                  incomeLog: const {},
                  expenseLog: const {},
                  onSetIncome: (_, _) {},
                  onSetExpense: (_, _) {},
                  onResetDay: (_) {},
                ),
              ),
            ),
          ),
        );

        for (int step = 0; step < 5; step++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.byType(HabitsScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('WorkoutScreen on $label (large font scale 1.35)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.35)),
              child: Scaffold(
                body: WorkoutScreen(
                  theme: getTheme(),
                  onWorkoutCompleted: (_) {},
                  onWorkoutProgressChanged: (_) {},
                  userName: 'Rayyan',
                  onNameChanged: (_, _, _, _) {},
                  userGoalYear: 2030,
                  userGoalMonth: 12,
                  userGoalDay: 1,
                ),
              ),
            ),
          ),
        );

        for (int step = 0; step < 5; step++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        for (final ro in tester.allRenderObjects.whereType<RenderFlex>()) {
          if (ro.toString().contains('OVERFLOWING') || ro.toString().contains('overflowed')) {
            debugPrint('WORKOUT OVERFLOWING RENDER OBJECT:');
            debugPrint(ro.toStringDeep());
          }
        }

        final err = tester.takeException();
        if (err is FlutterError) {
          debugPrint('WORKOUT FULL ERROR:\n${err.toStringDeep()}');
        }

        expect(find.byType(WorkoutScreen), findsOneWidget);
        expect(err, isNull);
      });
    }
  });
}
