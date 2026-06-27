import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';

class LifeGoal {
  String id;
  String title;
  String deadline;
  double progress;
  Color color;
  bool isDone;

  LifeGoal({
    required this.id,
    required this.title,
    required this.deadline,
    required this.progress,
    required this.color,
    this.isDone = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'deadline': deadline,
    'progress': progress,
    'color': color.toARGB32(),
    'isDone': isDone,
  };

  factory LifeGoal.fromJson(Map<String, dynamic> json) => LifeGoal(
    id: json['id'] as String,
    title: json['title'] as String,
    deadline: json['deadline'] as String,
    progress: (json['progress'] as num).toDouble(),
    color: Color(json['color'] as int),
    isDone: json['isDone'] as bool? ?? false,
  );
}

class LifePlanScreen extends StatefulWidget {
  const LifePlanScreen({super.key, required this.theme});
  final ThemeColors theme;

  @override
  State<LifePlanScreen> createState() => _LifePlanScreenState();
}

class _LifePlanScreenState extends State<LifePlanScreen> {
  List<LifeGoal> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final String? goalsJson = prefs.getString('life_plan_goals');

    if (goalsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(goalsJson);
        final loadedGoals = decoded.map((e) => LifeGoal.fromJson(e)).toList();
        final defaultTitles = [
          'Autonexuz Brand',
          'Upwork Profile',
          'Sunnah Consistency',
          'Fitness Goal',
        ];
        final containsOnlyDefaultFocusAreas =
            loadedGoals.length == defaultTitles.length &&
            List.generate(
              defaultTitles.length,
              (index) => loadedGoals[index].title == defaultTitles[index],
            ).every((matches) => matches);
        if (mounted) {
          setState(() {
            _goals = containsOnlyDefaultFocusAreas ? [] : loadedGoals;
            _isLoading = false;
          });
        }
        if (containsOnlyDefaultFocusAreas) {
          await _saveGoals();
        }
      } catch (e) {
        _setDefaults();
      }
    } else {
      _setDefaults();
    }
  }

  Future<void> _setDefaults() async {
    if (!mounted) return;
    setState(() {
      _goals = [];
      _isLoading = false;
    });
    _saveGoals();
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_goals.map((g) => g.toJson()).toList());
    await prefs.setString('life_plan_goals', encoded);
  }

  Future<void> _incrementProgress(LifeGoal goal) async {
    setState(() {
      double p = goal.progress + 0.05;
      if (p > 1.0) p = 1.0;
      goal.progress = p;
    });
    _saveGoals();
  }

  void _deleteGoal(LifeGoal goal) {
    setState(() {
      _goals.remove(goal);
    });
    _saveGoals();
  }

  void _showAddGoalSheet() {
    final titleCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    double progressVal = 0.0;
    Color selectedColor = kBlue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.theme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext sheetContext, setSheetState) {
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
                    'Add New Goal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.theme.text1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: widget.theme.text1),
                    decoration: InputDecoration(
                      labelText: 'Goal Title',
                      labelStyle: TextStyle(color: widget.theme.text3),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.theme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kGold, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: dateCtrl,
                    style: TextStyle(color: widget.theme.text1),
                    decoration: InputDecoration(
                      labelText: 'Target Date (e.g. Dec 2025)',
                      labelStyle: TextStyle(color: widget.theme.text3),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.theme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kGold, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Progress: ${(progressVal * 100).round()}%',
                    style: TextStyle(color: widget.theme.text3),
                  ),
                  Slider(
                    value: progressVal,
                    onChanged: (val) {
                      if (mounted) {
                        setSheetState(() => progressVal = val);
                      }
                    },
                    activeColor: selectedColor,
                    inactiveColor: widget.theme.border,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children:
                        [
                          kBlue,
                          kGold,
                          kGreen,
                          kTeal,
                          const Color(0xFFf97316),
                          kRed,
                        ].map((c) {
                          return GestureDetector(
                            onTap: () {
                              if (mounted) {
                                setSheetState(() => selectedColor = c);
                              }
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor == c
                                      ? widget.theme.text1
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGold,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        final deadline = dateCtrl.text.trim().isEmpty
                            ? 'Ongoing'
                            : dateCtrl.text.trim();
                        if (title.isEmpty) return;
                        final goal = LifeGoal(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title,
                          deadline: deadline,
                          progress: progressVal,
                          color: selectedColor,
                        );

                        FocusScope.of(sheetContext).unfocus();
                        titleCtrl.clear();
                        dateCtrl.clear();
                        Navigator.pop(sheetContext);

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _goals.add(goal);
                            });
                            _saveGoals();
                          }
                        });
                      },
                      child: const Text(
                        'Add Goal',
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year + 1, 1, 1);
    final totalDays = yearEnd.difference(yearStart).inDays;
    final daysPassed = now.difference(yearStart).inDays + 1;
    final daysRemaining = totalDays - daysPassed;
    final progressPercent = daysPassed / totalDays;

    final isDark = theme.isDark;
    final bgColor = isDark ? const Color(0xFF06060F) : const Color(0xFFF5F0E8);
    final cardBg = isDark ? const Color(0x0AFFFFFF) : const Color(0xFFFFFFFF);
    final cardBorder = isDark ? const Color(0x14FFFFFF) : const Color(0x12000000);

    final goldColor = isDark ? const Color(0xFFE8B84B) : const Color(0xFFA0720A);
    final gold2Color = isDark ? const Color(0xFFFFD573) : const Color(0xFFD49C24);
    final emeraldColor = isDark ? const Color(0xFF00C896) : const Color(0xFF0A7A5A);
    final azureColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF1565A0);
    final purpleColor = isDark ? const Color(0xFFA855F7) : const Color(0xFF7C3AED);
    final redColor = isDark ? const Color(0xFFFF6B6B) : const Color(0xFFC0392B);

    final text1 = theme.text1;
    final text2 = theme.text2;
    final text3 = theme.text3;

    final activeGoals = _goals.where((g) => !g.isDone).toList();
    final completedGoals = _goals.where((g) => g.isDone).toList();

    // Year progress card helper
    Widget buildYearProgressCard() {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder, width: 0.5),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'YEAR PROGRESS',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: text3,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '${(progressPercent * 100).round()}%',
                  style: GoogleFonts.syne(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: goldColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 6,
                width: double.infinity,
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progressPercent,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [goldColor, gold2Color],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day $daysPassed of $totalDays',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: text3,
                  ),
                ),
                Text(
                  '$daysRemaining days left',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: text3,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Empty state helper
    Widget buildEmptyState() {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Opacity(
              opacity: 0.3,
              child: Text(
                '🎯',
                style: TextStyle(fontSize: 48),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No focus areas yet',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: text1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your first goal to start tracking',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: text3,
              ),
            ),
          ],
        ),
      );
    }

    // Focus card helper
    Widget buildGoalCard(LifeGoal goal) {
      final isCompleted = goal.isDone;
      const taskCountTotal = 20;
      final taskCountDone = (goal.progress * taskCountTotal).round();

      final accentGradient = isCompleted
          ? LinearGradient(colors: [emeraldColor, goldColor])
          : LinearGradient(colors: [azureColor, purpleColor]);

      final progressGradient = isCompleted
          ? LinearGradient(colors: [emeraldColor, goldColor])
          : LinearGradient(colors: [azureColor, purpleColor]);

      final pillBg = isCompleted ? emeraldColor.withValues(alpha: 0.12) : azureColor.withValues(alpha: 0.12);
      final pillBorder = isCompleted ? emeraldColor.withValues(alpha: 0.3) : azureColor.withValues(alpha: 0.3);
      final pillText = isCompleted ? emeraldColor : azureColor;
      final pillLabel = isCompleted ? 'Done' : 'Ongoing';

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder, width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 3,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: accentGradient,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _incrementProgress(goal),
                            child: Text(
                              goal.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: text1,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: pillBorder, width: 1),
                          ),
                          child: Text(
                            pillLabel,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: pillText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        height: 4,
                        width: double.infinity,
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: goal.progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: progressGradient,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: text3,
                            ),
                            children: [
                              const TextSpan(text: 'Progress: '),
                              TextSpan(
                                text: '$taskCountDone/$taskCountTotal',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: text1,
                                ),
                              ),
                              const TextSpan(text: ' tasks'),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  goal.isDone = !goal.isDone;
                                });
                                _saveGoals();
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCompleted ? emeraldColor.withValues(alpha: 0.12) : cardBg,
                                  border: Border.all(
                                    color: isCompleted ? emeraldColor.withValues(alpha: 0.3) : cardBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 16,
                                  color: isCompleted ? emeraldColor : text3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    backgroundColor: cardBg,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: cardBorder, width: 0.5),
                                    ),
                                    title: Text(
                                      'Delete Goal',
                                      style: GoogleFonts.syne(
                                        fontWeight: FontWeight.w800,
                                        color: text1,
                                      ),
                                    ),
                                    content: Text(
                                      'Are you sure you want to delete this goal?',
                                      style: GoogleFonts.dmSans(color: text3),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext),
                                        child: Text(
                                          'Cancel',
                                          style: GoogleFonts.dmSans(
                                            fontWeight: FontWeight.w600,
                                            color: text3,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(dialogContext);
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (mounted) _deleteGoal(goal);
                                          });
                                        },
                                        child: Text(
                                          'Delete',
                                          style: GoogleFonts.dmSans(
                                            fontWeight: FontWeight.w600,
                                            color: redColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: redColor.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: redColor.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: redColor,
                                ),
                              ),
                            ),
                          ],
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

    // Quick add card helper
    Widget buildQuickAddCard() {
      return GestureDetector(
        onTap: _showAddGoalSheet,
        child: CustomPaint(
          painter: DashedBorderPainter(color: cardBorder),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  size: 20,
                  color: goldColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add Focus Area',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: text1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Set a new goal for 2026',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: text3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2026 Focus',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: goldColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Plan',
                style: GoogleFonts.syne(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: text1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$daysRemaining days remaining',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: text2,
                ),
              ),
              const SizedBox(height: 24),
              buildYearProgressCard(),
              const SizedBox(height: 24),
              if (_goals.isEmpty)
                buildEmptyState()
              else ...[
                ...activeGoals.map((goal) => buildGoalCard(goal)),
                if (completedGoals.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Completed',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: text3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...completedGoals.map((goal) => buildGoalCard(goal)),
                ],
              ],
              const SizedBox(height: 16),
              buildQuickAddCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  DashedBorderPainter({required this.color, this.radius = 14});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    ));

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final pm = path.computeMetrics().first;
    final dashPath = Path();
    double distance = 0.0;
    while (distance < pm.length) {
      dashPath.addPath(
        pm.extractPath(distance, distance + dashWidth),
        Offset.zero,
      );
      distance += dashWidth + dashSpace;
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
